// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin_contracts_token_ERC1155_utils_ERC1155Receiver.sol";
import "./openzeppelin_contracts_token_ERC1155_extensions_ERC1155Supply.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_TransferHelper.sol";
import "./contracts_IEthrunes.sol";
import "./contracts_lib_Math.sol";
import "./contracts_lib_SwapLibrary.sol";
import "./contracts_lib_ParamsLib.sol";
import "./contracts_interfaces_IPoolManager.sol";
import "./contracts_interfaces_ISwap.sol";
import "./contracts_interfaces_IReferralConfig.sol";

contract GenericRouter is ISwap, Ownable, ERC1155Receiver, ReentrancyGuard {
    address public immutable poolManager;
    address public immutable ethrunes;
    IReferralConfig public referralConfig;

    event Rebate(
        address indexed referrer,
        uint160 id,
        uint256 amount
    );

    constructor(address _poolManager, address _referralConfig){
        poolManager = _poolManager;
        ethrunes = IPoolManager(_poolManager).ethrunes();
        referralConfig = IReferralConfig(_referralConfig);
    }

    modifier checkDeadline(uint256 deadline) {
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    function setReferralConfig(address _referralConfig) external onlyOwner {
        referralConfig = IReferralConfig(_referralConfig);
    }


    function _transferRunes(address to, uint160 id, uint256 value) internal {
        if(to == address(this)) {
            return;
        }
        if(id == 0) {
            TransferHelper.safeTransferETH(to, value);
        } else {
            IEthrunes(ethrunes).safeTransferFrom(address(this), to, id, value, "");
        }
    }

    function _checkLiquidity(uint160 id0, uint160 id1, uint256 amount0Desired, uint256 amount1Desired, uint256 amount0Min, uint256 amount1Min) internal view returns (uint256 amount0, uint256 amount1) {
        require(amount0Desired >= amount0Min, "INVALID_AMOUNT0");
        require(amount1Desired >= amount1Min, "INVALID_AMOUNT1");
        uint256 poolId = SwapLibrary.getPoolId(id0, id1);
        (uint256 reserve0, uint256 reserve1) = IPoolManager(poolManager).getReserves(poolId);
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 amount1Optimal = SwapLibrary.quote(amount0Desired, reserve0, reserve1);
            if(amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, 'INSUFFICIENT_ID1_AMOUNT');
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = SwapLibrary.quote(amount1Desired, reserve1, reserve0);
                assert(amount0Optimal <= amount0Desired);
                require(amount0Optimal >= amount0Min, 'INSUFFICIENT_ID0_AMOUNT');
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
    }


    function _addLiquidity(AddLiquidityParams memory params) internal checkDeadline(params.deadline) {
        require(params.amount0Desired > 0 && params.amount1Desired > 0, "INVALID_PARAMS");
        (uint256 amount0, uint256 amount1) = _checkLiquidity(params.id0, params.id1, params.amount0Desired, params.amount1Desired, params.amount0Min, params.amount1Min);
        uint256 poolId = SwapLibrary.getPoolId(params.id0, params.id1);

        (uint256 id0, uint256 id1,,,) = IPoolManager(poolManager).pools(poolId);

        _transferRunes(poolManager, params.id0, amount0); // transfer to PoolManager
        _transferRunes(poolManager, params.id1, amount1); // transfer to PoolManager

        IPoolManager(poolManager).mint(params.id0, params.id1, params.recipient);

        // refund id0
        if(params.amount0Desired > amount0) {
            _transferRunes(params.sender, params.id0, params.amount0Desired - amount0);
        }

        // refund id1
        if(params.amount1Desired > amount1) {
            _transferRunes(params.sender, params.id1, params.amount1Desired - amount1);
        }

        emit AddLiquidity(msg.sender, params.id0, params.id1, amount0, amount1, params.recipient);
    }

    function _removeLiquidity(RemoveLiquidityParams memory params) internal checkDeadline(params.deadline) {
        IPoolManager(poolManager).safeTransferFrom(address(this), poolManager, params.poolId, params.liquidity, ""); // send to PoolManager
        (uint160 id0, uint160 id1,,,) = IPoolManager(poolManager).pools(params.poolId);
        (uint256 amount0, uint256 amount1) = IPoolManager(poolManager).burn(params.poolId, params.recipient);
        require(amount0 >= params.amount0Min, "INSUFFICIENT_ID0_AMOUNT");
        require(amount1 >= params.amount1Min, "INSUFFICIENT_ID1_AMOUNT");
        emit RemoveLiquidity(msg.sender, params.liquidity, id0, id1, amount0, amount1, params.recipient);
    }

    function swapExactETHForTokens(
        uint160[] calldata path, 
        address recipient, 
        uint256 amountOutMin, 
        uint256 deadline,
        uint160 referralId
    ) external payable nonReentrant {
        ExactInputParams memory params;
        params.sender = msg.sender;
        params.path = path;
        params.recipient = recipient;
        params.deadline = deadline;
        params.amountIn = msg.value;
        params.amountOutMin = amountOutMin;

        if(referralId == 0) {
            params.referralId = referralConfig.getTraderReferralCode(msg.sender);
        } else {
            params.referralId = referralId;
        }
        _exactInputInternal(params);
    }

    function swapETHForExactTokens(
        uint160[] calldata path, 
        uint256 amountOut, 
        address recipient, 
        uint256 deadline,
        uint160 referralId
    ) external payable nonReentrant {
        ExactOutputParams memory params;
        params.path = path;
        params.sender = msg.sender;
        params.recipient = recipient;
        params.deadline = deadline;
        params.amountOut = amountOut;
        params.amountInMax = msg.value;
        if(referralId == 0) {
            params.referralId = referralConfig.getTraderReferralCode(msg.sender);
        } else {
            params.referralId = referralId;
        }
        _exactOutputInternal(params);
    }

    function _storeReferralInfo(address trader, uint160 referralId) internal returns(uint256 discount, uint256 rebate, address referrer) {
        (discount,  rebate, referrer) = referralConfig.getReferralInfo(referralId);
        if(referrer != address(0x0)) {
            if(referralConfig.getTraderReferralCode(trader) == 0) {
                referralConfig.setTraderReferralCode(trader, referralId);    
            }
        }
    }

    
    function _exactInputInternal(ExactInputParams memory params) internal checkDeadline(params.deadline) {
        (uint256 discount, uint256 rebate, address referrer) = _storeReferralInfo(params.sender, params.referralId);
        
        (uint256[] memory amounts, uint256 rebateAmount) = SwapLibrary.getAmountsOut(poolManager, params.amountIn, params.path, discount, rebate);
        _transferRunes(poolManager, params.path[0], amounts[0] - rebateAmount);
        _rebate(referrer, params.path[0], rebateAmount);

        _swap(params.path, amounts, params.recipient);

        require(amounts[amounts.length - 1] >= params.amountOutMin, 'INSUFFICIENT_OUTPUT_AMOUNT');
    }

    function _exactOutputInternal(ExactOutputParams memory params) internal checkDeadline(params.deadline) {
        (uint256 discount, uint256 rebate, address referrer) = _storeReferralInfo(params.sender, params.referralId);

        (uint256[] memory amounts, uint256 rebateAmount) = SwapLibrary.getAmountsIn(poolManager, params.amountOut, params.path, discount, rebate);
        require(amounts[0] <= params.amountInMax, 'EXCESSIVE_INPUT_AMOUNT');

        _transferRunes(poolManager, params.path[0], amounts[0] - rebateAmount); // transfer to pool
        _rebate(referrer, params.path[0], rebateAmount);
        _swap(params.path, amounts, params.recipient);

        // refund
        if(params.amountInMax > amounts[0]) {
            _transferRunes(params.sender, params.path[0], params.amountInMax - amounts[0]);
        }
    }

    function _swap(uint160[] memory path, uint256[] memory amounts, address to) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (uint160 input, uint160 output) = (path[i], path[i + 1]);
            address recipient = i < path.length - 2 ? poolManager : to;
            IPoolManager(poolManager).swap(input, output, amounts[i + 1], recipient);
        }
    }

    function _rebate(address referrer, uint160 id, uint256 amount) internal {
        if(amount == 0) return;
        _transferRunes(referrer, id, amount);
        emit Rebate(referrer, id, amount);
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public nonReentrant override returns (bytes4) {
        require(id > 0, "INVALID_ID");
        require(amount > 0, "INVALID_INPUT_AMOUNT");

        uint8 command = uint8(data[0]);

        // remove liquidity
        if(command == 0) {
            require(msg.sender == poolManager, "INVALID_SENDER");
            RemoveLiquidityParams memory params = ParamsLib.toRemoveLiquidityParams(data[1:]);
            params.sender = from;
            params.liquidity = amount;
            params.poolId = id;
            _removeLiquidity(params);
        } else if(command == 1) { // add liquidity
            require(msg.sender == ethrunes, "INVALID_SENDER");
            AddLiquidityParams memory params = ParamsLib.toAddLiquidityParams(data[1:]);

            params.sender = from;
            params.id1 = uint160(id);
            params.amount0Desired = address(this).balance;
            params.amount1Desired = amount;

            _addLiquidity(params);

        } else if(command == 2) { // exactInput
            require(msg.sender == ethrunes, "INVALID_SENDER");
            ExactInputParams memory params = ParamsLib.toExactInputParams(data[1:]);
            params.sender = from;
            if(params.referralId == 0) {
                params.referralId = referralConfig.getTraderReferralCode(from);
            }

            uint160[] memory fullpath = new uint160[](params.path.length + 1);
            fullpath[0] = uint160(id);
            for(uint256 i = 0; i < params.path.length; i++) {
                fullpath[1 + i] = params.path[i];
            }
            params.amountIn = amount;
            params.path = fullpath;

            _exactInputInternal(params);
		} else if(command == 3) { // exactOutput
            require(msg.sender == ethrunes, "INVALID_SENDER");
            ExactOutputParams memory params = ParamsLib.toExactOutputParams(data[1:]);
            params.sender = from;
            if(params.referralId == 0) {
                params.referralId = referralConfig.getTraderReferralCode(from);
            }

            uint160[] memory fullpath = new uint160[](params.path.length + 1);
            fullpath[0] = uint160(id);
            for(uint256 i = 0; i < params.path.length; i++) {
                fullpath[1 + i] = params.path[i];
            }
            params.amountInMax = amount;
            params.path = fullpath;

            _exactOutputInternal(params);
        } else {
            revert("INVALID_CALL");
        }

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public nonReentrant override returns (bytes4) {
        require(msg.sender == ethrunes, "INVALID SENDER");
        require(ids.length == 2, "INVALID_IDS_COUNT");
        require(ids[0] < ids[1], "INVALID_IDS_ORDER");
        require(amounts[0] > 0 && amounts[1] > 0, "INVALID_INPUT_AMOUNTS");

        uint8 command = uint8(data[0]);

        if(command == 1) { // addLiquidity
            AddLiquidityParams memory params = ParamsLib.toAddLiquidityParams(data[1:]);

            params.sender = from;
            params.id0 = uint160(ids[0]);
            params.id1 = uint160(ids[1]);
            params.amount0Desired = amounts[0];
            params.amount1Desired = amounts[1];
            _addLiquidity(params);
        } else {
            revert("INVALID_CALL");
        }

        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Receiver) returns (bool) {
        return ERC1155Receiver.supportsInterface(interfaceId);
    }

    receive() external payable {
    }
}
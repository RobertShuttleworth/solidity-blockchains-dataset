// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin_contracts_token_ERC1155_utils_ERC1155Receiver.sol";
import "./openzeppelin_contracts_token_ERC1155_extensions_ERC1155Supply.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_TransferHelper.sol";
import "./contracts_IEthrunes.sol";
import "./contracts_lib_Math.sol";
import "./contracts_interfaces_IPoolManager.sol";

contract GenericPools is Ownable, IPoolManager, ERC1155Supply, ERC1155Receiver, ReentrancyGuard {
    uint256 public constant MINIMUM_LIQUIDITY = 1e3;
    address public constant DEAD = address(0x000000000000000000000000000000000000dEaD);

    string public constant name = "DEX1155";
    string public constant symbol = "LP1155";

    address public ethrunes;
    address public feeRecipient;

    mapping (uint256 => Pool) public override pools;
    mapping (uint160 => uint256) public reserves;

    event Swap(
        address indexed recipient,
        uint160 idIn,
        uint160 idOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event Mint(
        address indexed recipient,
        uint160 id0,
        uint160 id1,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    event Burn(
        address indexed recipient,
        uint256 liquidity,
        uint160 id0,
        uint160 id1,
        uint256 amount0,
        uint256 amount1
    );

    constructor(address _ethrunes) ERC1155("") {
        ethrunes = _ethrunes;
    }

    function setFeeRecipient(address _feeTo) external onlyOwner {
        feeRecipient = _feeTo;
    }

    function getReserves(uint256 poolId) external view returns(uint256 reserve0, uint256 reserve1) {
        Pool memory pool = pools[poolId];
        reserve0 = pool.reserve0;
        reserve1 = pool.reserve1;
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
    // if fee is on, mint liquidity equivalent to 1/6 of the growth in sqrt(k)
    function _mintFee(uint256 poolId) internal returns (bool feeOn) {
        Pool memory pool = pools[poolId];
        feeOn = feeRecipient != address(0);
        uint256 _kLast = pool.kLast;
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(pool.reserve0 * pool.reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply(poolId) * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeRecipient, poolId, liquidity, "");
                }
            }
        } else if (_kLast != 0) {
            pools[poolId].kLast = 0;
        }
    }

    function claimFee(uint256 poolId) external nonReentrant {
        bool feeOn = _mintFee(poolId);
        if(feeOn) {
            Pool storage pool = pools[poolId];
            pool.kLast = pool.reserve0 * pool.reserve1;
        }
    }

    function mint(uint160 id0, uint160 id1, address to) external nonReentrant returns(uint256 liquidity) {
        uint256 poolId = _getPoolId(id0, id1);
        Pool storage pool = pools[poolId];
        require(id1 > 0, "INVALID_ID1");

        if(pool.id1 == 0) {
            pool.id0 = id0;
            pool.id1 = id1;
        } else {
            require(pool.id0 == id0 && pool.id1 == id1, "CHECK_POOL");
        }

        uint256 amount0 = _receivedAmountOf(id0);
        uint256 amount1 = _receivedAmountOf(id1);

        bool feeOn = _mintFee(poolId);

        uint256 _totalSupply = totalSupply(poolId);

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(DEAD, poolId, MINIMUM_LIQUIDITY, "");
        } else {
            liquidity = Math.min(amount0 * _totalSupply / pool.reserve0, amount1 * _totalSupply / pool.reserve1);
        }

        require(liquidity > 0, 'INSUFFICIENT_LIQUIDITY_MINTED');

        pool.reserve0 += amount0;
        pool.reserve1 += amount1;

        if(feeOn) pool.kLast = pool.reserve0 * pool.reserve1;

        _sync(pool.id0);
        _sync(pool.id1);

        _mint(to, poolId, liquidity, "");

        emit Mint(to, pool.id0, pool.id1, amount0, amount1, liquidity);
    }


    function burn(uint256 poolId, address to) external nonReentrant returns(uint256 amount0, uint256 amount1) {
        uint256 liquidity = balanceOf(address(this), poolId);
        Pool storage pool = pools[poolId];
        bool feeOn = _mintFee(poolId);

        uint256 _totalSupply = totalSupply(poolId);

        amount0 = liquidity * pool.reserve0 / _totalSupply;
        amount1 = liquidity * pool.reserve1 / _totalSupply;

        require(amount0 > 0 && amount1 > 0, 'INSUFFICIENT_LIQUIDITY_BURNED');

        if(pool.id0 == 0) {
            _transferRunes(to, pool.id0, amount0);
            _transferRunes(to, pool.id1, amount1);
        } else {
            uint256[] memory ids = new uint256[](2);
            ids[0] = pool.id0;
            ids[1] = pool.id1;
            uint256[] memory amounts = new uint256[](2);
            amounts[0] = amount0;
            amounts[1] = amount1;
            IEthrunes(ethrunes).batchTransfer(to, ids, amounts, "");
        }

        pool.reserve0 -= amount0;
        pool.reserve1 -= amount1;

        if(feeOn) pool.kLast = pool.reserve0 * pool.reserve1;

        _sync(pool.id0);
        _sync(pool.id1);

        _burn(address(this), poolId, liquidity);

        emit Burn(to, liquidity, pool.id0, pool.id1, amount0, amount1);
    }
    
    function swap(uint160 idIn, uint160 idOut, uint256 amountOut, address recipient) external nonReentrant {
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        uint256 amountIn = _receivedAmountOf(idIn);
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");

        bool zeroForOne = idIn < idOut;
        (uint160 id0, uint160 id1) = zeroForOne ? (idIn, idOut) : (idOut, idIn);
        uint256 poolId = _getPoolId(id0, id1);
        Pool storage pool = pools[poolId];
        require(pool.id0 == id0 && pool.id1 == id1, "CHECK_POOL");

        {
            uint256 _reserveOut = idOut == pool.id0 ? pool.reserve0 : pool.reserve1;
            require(amountOut < _reserveOut, "INSUFFICIENT_LIQUIDITY");
        }

        uint256 k0 = pool.reserve0 * pool.reserve1;

        if(zeroForOne) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }

        (uint256 reserveIn, uint256 reserveOut) = idIn == pool.id0 ? (pool.reserve0, pool.reserve1) : (pool.reserve1, pool.reserve0);

        // at least 0.3% fees to LP
        require((1000 * reserveIn - amountIn * 3) * reserveOut >= 1000 * k0, "K");

        _transferRunes(recipient, idOut, amountOut);

        if(recipient == address(this)) {
            reserves[idIn] = idIn == 0 ? address(this).balance : IEthrunes(ethrunes).balanceOf(address(this), idIn);
            reserves[idOut] = reserves[idOut] - amountOut;
        } else {
            _sync(idIn);
            _sync(idOut);
        }
        
        emit Swap(recipient, idIn, idOut, amountIn, amountOut);
    }

    function _getPoolId(uint160 id0, uint160 id1) internal pure returns (uint256 poolId) {
        require(id0 < id1, "INVALID_IDS_ORDER");
        poolId = uint256(keccak256(abi.encodePacked(id0, id1)));
    }

    function _sync(uint160 id) internal {
        if(id == 0) {
            reserves[id] = address(this).balance;
        } else {
            reserves[id] = IEthrunes(ethrunes).balanceOf(address(this), id);
        }
    }

    function _receivedAmountOf(uint160 id) internal view returns(uint256) {
        if(id == 0) {
            return address(this).balance - reserves[id];
        } else {
            return IEthrunes(ethrunes).balanceOf(address(this), id) - reserves[id];
        }
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) public nonReentrant override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public nonReentrant override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Receiver, ERC1155, IERC165) returns (bool) {
        return ERC1155Receiver.supportsInterface(interfaceId) || ERC1155.supportsInterface(interfaceId);
    }

    receive() external payable {
    }
}
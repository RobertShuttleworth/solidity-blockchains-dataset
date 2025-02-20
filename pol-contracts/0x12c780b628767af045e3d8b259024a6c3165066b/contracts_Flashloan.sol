// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./aave_core-v3_contracts_flashloan_base_FlashLoanSimpleReceiverBase.sol";
import "./aave_core-v3_contracts_interfaces_IPoolAddressesProvider.sol";
import "./aave_core-v3_contracts_interfaces_IPool.sol";
import "./uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol";
import "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router02.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_security_Pausable.sol";

/// @title Flashloan Arbitrage Trading Contract
/// @author Original by Liam Goss, improvements by Assistant
/// @notice You can use this contract to perform a decentralized arbitrage trade utilizing AAVE flashloan lending
contract Flashloan is FlashLoanSimpleReceiverBase, Ownable, ReentrancyGuard, Pausable {
    // Custom errors
    error InsufficientBalance(uint256 available, uint256 required);
    error InvalidAddress();
    error SwapFailed(string reason);
    error InvalidParameters();
    error DeadlineExpired();
    error FlashLoanFailed();

    // State variables
    IPoolAddressesProvider public immutable ADDRESS_PROVIDER;
    IPool public immutable LENDINGPOOL;
    uint256 private constant DEADLINE_EXTENSION = 300; // 5 minutes

    // Events
    event FlashLoanExecuted(
        address indexed asset,
        uint256 amount,
        uint256 fee,
        address initiator
    );

    event TradeExecuted(
        address indexed token0,
        address indexed token1,
        uint256 amountIn,
        uint256 amountOut,
        address router
    );

    event EmergencyTokenRecovery(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );

    // Structs
    struct TradeParams {
        address token0;
        address token1;
        uint256 flashAmount;
        address routerA;
        address routerB;
        bool shouldAUseV2;
        bool shouldBUseV2;
    }

    constructor(IPoolAddressesProvider _addressProvider)
        FlashLoanSimpleReceiverBase(_addressProvider)
        Ownable()
    {
        if (address(_addressProvider) == address(0)) revert InvalidAddress();
        ADDRESS_PROVIDER = _addressProvider;
        LENDINGPOOL = IPool(_addressProvider.getPool());
    }

    function executeTrade(
        address _token0,
        address _token1,
        uint256 _flashAmount,
        address _routerA,
        address _routerB,
        bool[] calldata _routerVersions
    ) external whenNotPaused nonReentrant {
        if (_token0 == address(0) || _token1 == address(0)) revert InvalidAddress();
        if (_routerA == address(0) || _routerB == address(0)) revert InvalidAddress();
        if (_routerVersions.length != 2) revert InvalidParameters();
        if (_flashAmount == 0) revert InvalidParameters();

        bytes memory params = abi.encode(
            _token0,
            _token1,
            _flashAmount,
            _routerA,
            _routerB,
            _routerVersions[0],
            _routerVersions[1]
        );

        flashLoanSimple(_token0, _flashAmount, params);
    }

    function executeOperation(
        address _asset,
        uint256 _amount,
        uint256 _fee,
        address _initiator,
        bytes calldata _params
    ) external override nonReentrant returns (bool) {
        // Move decode to a separate function to reduce local variables
        TradeParams memory tradeParams = _decodeParams(_params);

        // Calculate repayment amount
        uint256 amountToReturn = _amount + _fee;

        // Execute trades using a separate function
        _executeTrades(tradeParams, _amount);

        // Approve AAVE to pull repayment
        if (!IERC20(tradeParams.token0).approve(address(LENDINGPOOL), amountToReturn)) {
            revert FlashLoanFailed();
        }

        emit FlashLoanExecuted(_asset, _amount, _fee, _initiator);
        return true;
    }

    function _decodeParams(bytes calldata _params) private pure returns (TradeParams memory) {
        (
            address token0,
            address token1,
            uint256 flashAmount,
            address routerA,
            address routerB,
            bool shouldAUseV2,
            bool shouldBUseV2
        ) = abi.decode(_params, (address, address, uint256, address, address, bool, bool));

        return TradeParams({
            token0: token0,
            token1: token1,
            flashAmount: flashAmount,
            routerA: routerA,
            routerB: routerB,
            shouldAUseV2: shouldAUseV2,
            shouldBUseV2: shouldBUseV2
        });
    }

    function _executeTrades(TradeParams memory params, uint256 flashAmount) private {
        address[] memory path = new address[](2);
        path[0] = params.token0;
        path[1] = params.token1;

        // Execute first trade
        uint256 amountOutMin;
        try this._executeFirstTrade(
            params.shouldAUseV2,
            params.routerA,
            path,
            flashAmount
        ) returns (uint256 amount) {
            amountOutMin = amount;
        } catch Error(string memory reason) {
            revert SwapFailed(reason);
        }

        // Prepare second trade
        path[0] = params.token1;
        path[1] = params.token0;
        uint256 token1Balance = IERC20(params.token1).balanceOf(address(this));

        // Execute second trade
        try this._executeSecondTrade(
            params.shouldBUseV2,
            params.routerB,
            path,
            token1Balance,
            amountOutMin
        ) returns (uint256) {
            // Trade successful
        } catch Error(string memory reason) {
            revert SwapFailed(reason);
        }
    }

    function _executeFirstTrade(
        bool _isV2,
        address _router,
        address[] memory _path,
        uint256 _amountIn
    ) external returns (uint256) {
        if (_isV2) {
            uint[] memory amounts = _swapOnV2Router(_router, _path, _amountIn, 0);
            return amounts[1];
        } else {
            return _swapOnV3Router(_router, _path, _amountIn, 0);
        }
    }

    function _executeSecondTrade(
        bool _isV2,
        address _router,
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minReturn
    ) external returns (uint256) {
        uint256 minReturn = _minReturn + 1; // Ensure profit
        if (_isV2) {
            uint[] memory amounts = _swapOnV2Router(_router, _path, _amountIn, minReturn);
            return amounts[1];
        } else {
            return _swapOnV3Router(_router, _path, _amountIn, minReturn);
        }
    }

    function _swapOnV2Router(
        address _router,
        address[] memory _path,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) internal returns (uint[] memory amounts) {
        uint256 balance = IERC20(_path[0]).balanceOf(address(this));
        if (balance < _amountIn) revert InsufficientBalance(balance, _amountIn);

        if (!IERC20(_path[0]).approve(_router, _amountIn)) {
            revert SwapFailed("Router approval failed");
        }

        uint256 deadline = block.timestamp + DEADLINE_EXTENSION;
        amounts = IUniswapV2Router02(_router).swapExactTokensForTokens(
            _amountIn,
            _amountOutMin,
            _path,
            address(this),
            deadline
        );

        emit TradeExecuted(_path[0], _path[1], _amountIn, amounts[1], _router);
        return amounts;
    }

    function _swapOnV3Router(
        address _router,
        address[] memory _path,
        uint256 _amountIn,
        uint256 _amountOutMin
    ) internal returns (uint256) {
        uint256 balance = IERC20(_path[0]).balanceOf(address(this));
        if (balance < _amountIn) revert InsufficientBalance(balance, _amountIn);

        if (!IERC20(_path[0]).approve(_router, _amountIn)) {
            revert SwapFailed("Router approval failed");
        }

        uint256 deadline = block.timestamp + DEADLINE_EXTENSION;
        uint256 amountOut = ISwapRouter(_router).exactInput(
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(_path),
                recipient: address(this),
                deadline: deadline,
                amountIn: _amountIn,
                amountOutMinimum: _amountOutMin
            })
        );

        emit TradeExecuted(_path[0], _path[1], _amountIn, amountOut, _router);
        return amountOut;
    }

    function withdrawETH() external payable onlyOwner nonReentrant returns (bool) {
        uint256 balance = address(this).balance;
        (bool sent,) = owner().call{value: balance}("");
        if (!sent) revert SwapFailed("ETH transfer failed");
        return true;
    }

    function withdrawToken(
        address _token
    ) external payable onlyOwner nonReentrant returns (bool) {
        uint256 balance = IERC20(_token).balanceOf(address(this));
        if (!IERC20(_token).transfer(owner(), balance)) {
            revert SwapFailed("Token transfer failed");
        }
        return true;
    }

    function emergencyTokenRecovery(
        address _token,
        uint256 _amount
    ) external onlyOwner nonReentrant {
        if (_token == address(0)) revert InvalidAddress();
        if (!IERC20(_token).transfer(owner(), _amount)) {
            revert SwapFailed("Emergency recovery failed");
        }
        emit EmergencyTokenRecovery(_token, owner(), _amount);
    }

    function flashLoanSimple(
        address _asset,
        uint256 _amount,
        bytes memory _params
    ) public nonReentrant {
        if (_asset == address(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidParameters();

        LENDINGPOOL.flashLoanSimple(
            address(this),
            _asset,
            _amount,
            _params,
            0 // referralCode
        );
    }

    function isLendingPoolAccessible() external view returns (uint128) {
        return LENDINGPOOL.FLASHLOAN_PREMIUM_TOTAL();
    }

    receive() external payable {}
}
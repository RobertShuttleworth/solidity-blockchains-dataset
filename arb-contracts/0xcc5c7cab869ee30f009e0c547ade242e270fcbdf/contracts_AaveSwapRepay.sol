// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol";
import "./uniswap_v3-periphery_contracts_libraries_TransferHelper.sol";
import {ICurveRouter} from "./contracts_ICurveRouter.sol";
import {IPool} from "./contracts_IPool.sol";

contract AaveSwapRepay {
    using TransferHelper for IERC20;

    string private constant UnauthorisedError = "Unauthorised call";
    uint24 public constant uniswapFeeTier = 3000;

    address public aaveV3Pool;
    address public keeper;
    address public receiver;
    address public curveRouter;

    modifier onlyKeeper() {
        require(
            msg.sender == keeper || msg.sender == receiver,
            UnauthorisedError
        );
        _;
    }

    constructor(
        address newKeeper,
        address newReceiver,
        address newAaveV3Pool,
        address newCurveRouter
    ) {
        // Step 0: Verify input
        _expectNonZeroAddress(newKeeper, "newKeeper is address zero");
        _expectNonZeroAddress(newReceiver, "newReceiver is address zero");
        _expectContract(newAaveV3Pool, "newAaveV3Pool is not a contract");
        _expectContract(newCurveRouter, "newCurveRouter is not a contract");
        // Step 1: Update storage
        keeper = newKeeper;
        receiver = newReceiver;
        aaveV3Pool = newAaveV3Pool;
        curveRouter = newCurveRouter;
    }

    /// @notice Fetches the relevant aToken address
    /// @dev Reverts if:
    ///                 1. the param asset equals address zero
    ///                 2. the `aToken` received from the AAVE pool is zero
    /// @param asset the address of the underlying AAVE supported asset
    /// @return aToken the address of the relevant aToken
    function extractAToken(address asset) public view returns (address aToken) {
        _expectContract(asset, "asset is not a contract");
        aToken = _getAToken(asset);
        _expectNonZeroAddress(aToken, "Unsupported asset");
    }

    /// @notice Estimates the amount of the final output token received in a CurveFi exchange
    /// @param _route Array of [initial token, pool or zap, token, pool or zap, token, ...]
    /// @param _swap_params Multidimensional array of [i, j, swap_type, pool_type, n_coins]
    /// @param _amount The amount of input token (`_route[0]`) to be sent.
    /// @param _pools Array of pools for swaps via zap contracts. Only required for swap_type = 3.
    /// @return The estimated number of output tokens.
    function getCurveEstimatedOutput(
        address[11] calldata _route,
        uint256[5][5] calldata _swap_params,
        uint256 _amount,
        address[5] calldata _pools
    ) public view returns (uint256) {
        return
            ICurveRouter(curveRouter).get_dy(
                _route,
                _swap_params,
                _amount,
                _pools
            );
    }

    /// @notice Refunds an AAVE loan
    /// @param asset the address of the borrowed assset
    function repay(
        address asset
    ) public returns (uint256) {
        _boilerplate(asset, aaveV3Pool);

        uint256 amount = IERC20(asset).balanceOf(address(this));

        IERC20(asset).approve(aaveV3Pool, amount);

        return
            IPool(aaveV3Pool).repay(asset, amount, 2, receiver);
    }

    /// @notice 
    function uniswapV3(
        ISwapRouter aaveV3Router,
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public onlyKeeper returns (uint256 amountOut) {
        // Step 0: Verify input
        _expectContract(
            address(aaveV3Router),
            "aaveV3Router is not a contract"
        );
        _expectContract(tokenIn, "tokenIn is not a contract");
        _expectContract(tokenOut, "tokenOut is not a contract");

        // Step 1: Withdraw & approve
        _boilerplate(tokenIn, address(aaveV3Router));

        // Step 2: Set limits
        uint256 minOut = /* Calculate min output */ 0;
        uint160 priceLimit = /* Calculate price limit */ 0;

        // Step 3: Populate params
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: uniswapFeeTier,
                recipient: receiver,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: minOut,
                sqrtPriceLimitX96: priceLimit
            });

        // Step 4: Execute the swap
        amountOut = aaveV3Router.exactInputSingle(params);
    }

    /// @notice Exchanges up to 5 tokens
    /// example: https://arbiscan.io/tx/0xa1dc20bd269e868b1198dd72eead35944dd39ac4c3bc8f60b4e3ecd1bc1b05b7
    function swapCurveFi(
        address[11] calldata route,
        uint256[5][5] calldata swapParams,
        address[5] calldata pools
    ) public onlyKeeper returns (uint256 amountOut) {
        // Step 0: Verify input

        // Step 1: Withdraw & approve
        uint256 amountIn = _boilerplate(route[0], curveRouter);

        uint256 minDy = getCurveEstimatedOutput(
            route,
            swapParams,
            amountIn,
            pools
        );

        // Step 3: Perform the token swap
        amountOut = ICurveRouter(curveRouter).exchange(
            route,
            swapParams,
            amountIn,
            minDy,
            pools,
            receiver
        );
    }

    /// @notice Withdraws `source`'s `assets` to `destination`
    /// @param asset the address of the underlying AAVE supported asset
    /// @param source the current aToken holder
    /// @param destination the final asset holder
    function withdrawPosition(
        address asset,
        address source,
        address destination
    ) external onlyKeeper {
        // Input validation
        _expectContract(asset, "asset is not a contract");
        _expectNonZeroAddress(source, "Wrong source address");
        _expectNonZeroAddress(destination, "Wrong destination address");

        // Get the asset's aToken contract address
        address aToken = extractAToken(asset);

        uint256 allowance = IERC20(aToken).allowance(source, address(this));
        if (allowance == 0) revert("Zero aToken allowance");

        uint256 balance = IERC20(aToken).balanceOf(source);
        if (balance == 0) revert("Source has zero aTokens");

        uint256 amount = min(allowance, balance);

        // aToken transfer
        TransferHelper.safeTransferFrom(aToken, source, address(this), amount);

        // Approval
        IERC20(aToken).approve(aaveV3Pool, amount);

        // Withdrawal
        IPool(aaveV3Pool).withdraw(asset, amount, destination);
    }

    /// @notice Withdraws `source`'s `assets` to `destination`
    /// @param asset the address of the underlying AAVE supported asset
    /// @param source the current aToken holder
    /// @param destination the final asset holder
    /// @param amount the number of tokens to withdraw
    function withdrawPositionAmount(
        address asset,
        address source,
        address destination,
        uint256 amount
    ) external onlyKeeper {
        // Input validation
        _expectContract(asset, "asset is not a contract");
        _expectNonZeroAddress(source, "Wrong source address");
        _expectNonZeroAddress(destination, "Wrong destination address");

        // Get the asset's aToken contract address
        address aToken = extractAToken(asset);

        uint256 allowance = IERC20(aToken).allowance(source, address(this));
        if (allowance == 0) revert("Zero aToken allowance");

        uint256 withdrawAmount = min(allowance, amount);

        // aToken transfer
        TransferHelper.safeTransferFrom(aToken, source, address(this), withdrawAmount);

        // Approval
        IERC20(aToken).approve(aaveV3Pool, withdrawAmount);

        // Withdrawal
        IPool(aaveV3Pool).withdraw(asset, withdrawAmount, destination);
    }

    /**
     *                   P R I V A T E   F U N C T I O N S
     */

    /// @dev Withdraws the `token` and approves the `amount` to the spender
    /// @param token the address of the ERC20
    /// @param spender the required swap
    function _boilerplate(
        address token,
        address spender
    ) private returns (uint256 amount) {
        // 1. Get the balance
        amount = IERC20(token).balanceOf(receiver);

        // 2. Check the allowance
        uint256 allowance = IERC20(token).allowance(receiver, address(this));

        // 2.1 Revert on zero allowance
        if (allowance == 0)
            revert("This contract has zero allowance from the owner");
        // 2.2 Withdraw at least the allowance
        if (allowance < amount) amount = allowance;

        // 3. Withdraw shares to this contract
        TransferHelper.safeTransferFrom(token, receiver, address(this), amount);

        // 4. Approval to the spending contract
        TransferHelper.safeApprove(token, spender, amount);
    }

    /// @dev Reverts if `a` is address zero
    function _expectNonZeroAddress(
        address a,
        string memory message
    ) internal pure {
        if (a == address(0)) revert(message);
    }

    /// @notice Fetches an asset's aToken address
    /// @param asset the address of the underlying asset
    /// @return aToken the address of the aToken representing (deposit + rewards)
    function _getAToken(address asset) private view returns (address aToken) {
        (bool success, bytes memory data) = aaveV3Pool.staticcall(
            abi.encodeWithSignature("getReserveData(address)", asset)
        );

        if (success) {
            // Decode the result and return the aToken address
            IPool.ReserveData memory reserveData = abi.decode(
                data,
                (IPool.ReserveData)
            );
            aToken = reserveData.aTokenAddress;
        } else {
            // Return the zero address if the call fails
            aToken = address(0);
        }
    }

    /// @dev Reverts if `a` has no attached code
    function _expectContract(address a, string memory message) internal pure {
        _expectNonZeroAddress(a, message);
    }

    /// @dev returns the minimum of `a` and `b`
    function min(uint256 a, uint256 b) private pure returns (uint256 minimum) {
        minimum = a < b ? a : b;
    }
}
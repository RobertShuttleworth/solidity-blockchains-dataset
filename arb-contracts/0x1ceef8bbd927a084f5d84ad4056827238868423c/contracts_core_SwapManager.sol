// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

import { UUPSUpgradeable } from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import { SafeERC20, IERC20 } from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import { SafeCast } from "./openzeppelin_contracts_utils_math_SafeCast.sol";

import { ConfigurableAddresses } from "./contracts_dependencies_ConfigurableAddresses.sol";

import { DECIMAL_PRECISION } from "./contracts_dependencies_TrenMath.sol";
import { IAdminContract } from "./contracts_interfaces_IAdminContract.sol";
import { ISwapManager } from "./contracts_interfaces_ISwapManager.sol";
import { ITrenBoxManager } from "./contracts_interfaces_ITrenBoxManager.sol";
import { ITrenBoxStorage } from "./contracts_interfaces_ITrenBoxStorage.sol";
import { ISwapperStaker } from "./contracts_interfaces_ISwapper.sol";
import { ICurvePool } from "./contracts_interfaces_ICurvePool.sol";
import { IRouter } from "./contracts_interfaces_IRouter.sol";

/// @title SwapManager
/// @notice The contract to manage swapping of collateral assets (LPs) to underlying assets and/or
/// debt token with possibility of autocompounding. As an example with Curve protocol, we need to
/// stake LP into the Gauge contract to get rewards in CRV token, then we claim rewards (some amount
/// of CRV) and do autocompound by swapping CRV to underlying asset (e.g. USDT / USDC) and again
/// provide this amount of USDT to the Curve Pool to get another LP, which we will stake again into
/// the Gauge contract.
contract SwapManager is ConfigurableAddresses, ISwapManager, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /// @notice The name of contract
    string public constant NAME = "SwapManager";

    /// @notice The address of router
    IRouter public router;

    /// @notice The mapping of collateral address to swapping configuration
    mapping(address coll => SwapConfig swapConfig) public swapConfigs;
    mapping(address coll => DebtSwapConfig debtSwapConfig) public debtSwapConfigs;
    mapping(address rewardToken => address swapPool) public swapPools;

    // ------------------------------------------ Initializer -------------------------------------

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    // ------------------------------------------ Set functions -----------------------------------

    /// @notice Sets the address of swapping router
    /// @param _router The address of swapping router
    function setRouter(address _router) external onlyOwner {
        if (_router == address(0)) revert SwapManager__ZeroAddress();

        router = IRouter(_router);

        emit NewRouterSet(_router);
    }

    /**
     * @notice Sets the configurations for swapping collateral assets
     * @param coll The addresses of collateral assets
     * @param _swapConfig The configuration details for swapping collateral with underlying asset
     * and/or reward token
     * @param _debtSwapConfig The configuration details for swapping collateral with debt token
     */
    function setConfig(
        address coll,
        SwapConfig calldata _swapConfig,
        DebtSwapConfig calldata _debtSwapConfig
    )
        external
        onlyOwner
    {
        if (
            coll == address(0) || _swapConfig.swapper == address(0)
                || _swapConfig.underlyingAsset == address(0)
        ) {
            revert SwapManager__ZeroAddress();
        }
        if (swapConfigs[coll].swapper == address(0)) {
            emit SetConfig(coll, _swapConfig, _debtSwapConfig);
        } else {
            emit UpdateConfig(coll, _swapConfig, _debtSwapConfig);
        }

        swapConfigs[coll] = _swapConfig;
        debtSwapConfigs[coll] = _debtSwapConfig;
    }

    function setSwapPool(address rewardToken, address swapPool) external onlyOwner {
        swapPools[rewardToken] = swapPool;
    }

    /**
     * @notice Removes the configuration for specific swapping collateral asset
     * @param coll The address of collateral asset
     */
    function removeConfig(address coll) external onlyOwner {
        if (swapConfigs[coll].swapper == address(0)) {
            revert SwapManager__ConfigShouldBeSetFirst(coll);
        }

        delete swapConfigs[coll];
        delete debtSwapConfigs[coll];

        emit RemoveConfig(coll);
    }

    /**
     * @notice Function to override renounceOwnership
     * @dev Disabled renounceOwnership()
     */
    function renounceOwnership() public view override onlyOwner {
        revert SwapManager__RenounceOwnershipDisabled();
    }

    function emergencyWithdrawal(address token) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function emergencyWithdrawalFromSwapper(address token, address swapper) external onlyOwner {
        IERC20(token).safeTransferFrom(swapper, msg.sender, IERC20(token).balanceOf(swapper));
    }

    // ------------------------------------------ External functions ------------------------------

    /// @inheritdoc ISwapManager
    function swap(
        address coll,
        uint256 collAmount,
        uint256 debtExpected,
        address recipient
    )
        external
    {
        if (msg.sender != flashLoanAddress) {
            revert SwapManager__CallerIsNotFlashLoan();
        }

        SwapConfig memory swapConfig = swapConfigs[coll];
        _checkConfigSet(swapConfig.swapper);

        // get collaterals from Flashloan contract
        IERC20(coll).safeTransferFrom(msg.sender, swapConfig.swapper, collAmount);

        // swap them for underlying asset
        uint256 _underlyingAssetOut =
            ISwapperStaker(swapConfig.swapper).swap(coll, collAmount, address(this));

        // swap underlying asset for debtToken
        _swapExactOutput(coll, debtToken, swapConfig.swapper, _underlyingAssetOut, debtExpected);

        // If there are any underlyingAsset amount left after the swap, deposit them again via
        // Swapper to get LP and send to the user
        uint256 remainingAmount = IERC20(swapConfig.underlyingAsset).balanceOf(swapConfig.swapper);
        if (remainingAmount > 0) {
            ISwapperStaker(swapConfig.swapper).swap(
                swapConfig.underlyingAsset, remainingAmount, recipient
            );
        }

        emit Swap(msg.sender, coll, collAmount, swapConfig.underlyingAsset, debtExpected);
    }

    /// @inheritdoc ISwapManager
    function stake(address coll, uint256 collAmount) external {
        if (msg.sender != borrowerOperations) {
            revert SwapManager__CallerIsNotBorrowerOperations();
        }

        SwapConfig memory config = swapConfigs[coll];
        _checkConfigSet(config.swapper);

        // get total amount of collateral from BorrowerOperations contract + new amount of
        // collateral after compounding
        uint256 totalCollAmount = collAmount + _compound(coll);

        // send total amount of collateral to Swapper and deposit them
        IERC20(coll).safeTransfer(config.swapper, totalCollAmount);
        ISwapperStaker(config.swapper).deposit(totalCollAmount);

        emit StakedCollateral(coll, collAmount);
    }

    /// @inheritdoc ISwapManager
    function unstake(address coll, uint256 collAmount) external {
        if (msg.sender != trenBoxStorage) {
            revert SwapManager__CallerIsNotTrenBoxStorage();
        }

        SwapConfig memory config = swapConfigs[coll];
        _checkConfigSet(config.swapper);

        // do compound with current amount of collateral and get new amount of collateral
        // after it
        uint256 newAmountToStake = _compound(coll);

        // withdraw specific amount of collateral via Swapper
        ISwapperStaker(config.swapper).withdraw(collAmount);

        // send total amount of collateral to Swapper and deposit them
        IERC20(coll).safeTransfer(config.swapper, newAmountToStake);
        ISwapperStaker(config.swapper).deposit(newAmountToStake);

        // send withdrawn amount of collateral to TrenBoxStorage
        IERC20(coll).safeTransfer(msg.sender, collAmount);

        emit UnstakedCollateral(coll, collAmount);
    }

    // ------------------------------------------ Private functions -------------------------------

    /**
     * @dev Do compound with current amount of collateral and get new amount of collateral after it
     * @param coll The address of collateral asset
     * @return newCollOut The new amount of collateral after compounding
     */
    function _compound(address coll) private returns (uint256 newCollOut) {
        // claim rewards from Swapper
        ISwapperStaker(swapConfigs[coll].swapper).claim_rewards();

        uint256 totalActiveColl = ITrenBoxStorage(trenBoxStorage).getActiveCollateralBalance(coll);
        // check reward token balance
        // if it's a first deposit, nothing will be claimed
        address[] memory rewardTokens = ISwapperStaker(swapConfigs[coll].swapper).reward_tokens();
        uint256 rewardTokensLength = rewardTokens.length;
        for (uint256 i = 0; i < rewardTokensLength; i++) {
            uint256 rewardTokenBalance = IERC20(rewardTokens[i]).balanceOf(address(this));
            if (rewardTokenBalance != 0 && totalActiveColl != 0) {
                SwapConfig memory config = swapConfigs[coll];

                // calculate fee from the received amount of reward token and send it to the
                // Treasury
                uint256 compoundFee = IAdminContract(adminContract).compoundFee();
                uint256 amountWithoutFee =
                    rewardTokenBalance - (rewardTokenBalance * compoundFee / DECIMAL_PRECISION);
                uint256 feeToSend = rewardTokenBalance - amountWithoutFee;
                IERC20(rewardTokens[i]).safeTransfer(treasuryAddress, feeToSend);

                // make a swap from reward token to underlying asset
                uint256 underlyingAssetOut;
                if (swapPools[rewardTokens[i]] != address(0)) {
                    underlyingAssetOut = _swapViaCurve(
                        rewardTokens[i], amountWithoutFee, config.underlyingAsset, config.swapper
                    );
                } else {
                    underlyingAssetOut = _swapExactInput(
                        rewardTokens[i],
                        config.underlyingAsset,
                        config.swapper,
                        amountWithoutFee,
                        config.fee,
                        config.directSwap,
                        config.stablecoin,
                        config.pathFee
                    );
                }

                // stake the received amount of underlying asset via Swapper
                newCollOut += ISwapperStaker(config.swapper).swap(
                    config.underlyingAsset, underlyingAssetOut, address(this)
                );
            }
        }

        if (newCollOut != 0) {
            // increase the collateral volume of each user accordingly, in other words we distribute
            // received amount of collateral among all users in pool based on theirs collateral
            // value
            address collAsset = coll; // to not get error 'Stack too deep'.
            address[] memory ownersList = ITrenBoxManager(trenBoxManager).getTrenBoxOwners(coll);
            uint256 ownersLength = ownersList.length;
            for (uint256 i = 0; i < ownersLength; i++) {
                uint256 userColl =
                    ITrenBoxManager(trenBoxManager).getTrenBoxColl(collAsset, ownersList[i]);
                uint256 userRate = userColl * DECIMAL_PRECISION / totalActiveColl;
                uint256 amountToIncrease = userRate * newCollOut / DECIMAL_PRECISION;

                ITrenBoxManager(trenBoxManager).increaseTrenBoxColl(
                    collAsset, ownersList[i], amountToIncrease
                );
                ITrenBoxManager(trenBoxManager).updateTrenBoxRewardSnapshots(
                    collAsset, ownersList[i]
                );
                ITrenBoxManager(trenBoxManager).updateStakeAndTotalStakes(collAsset, ownersList[i]);
            }

            ITrenBoxStorage(trenBoxStorage).increaseActiveCollateral(coll, newCollOut);
        }

        return newCollOut;
    }

    function _swapViaCurve(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        address receiver
    )
        private
        returns (uint256 _amountOut)
    {
        address poolAddress = swapPools[tokenIn];
        uint256 indexIn = 0;
        uint256 indexOut = indexIn;
        if (ICurvePool(poolAddress).coins(indexIn) == tokenIn) {
            indexOut = 1;
        } else {
            indexIn = 1;
        }

        _amountOut = ICurvePool(poolAddress).exchange(
            int128(uint128(indexIn)), int128(uint128(indexOut)), amountIn, 0, address(this)
        );

        if (IERC20(tokenOut).balanceOf(address(this)) != _amountOut) {
            address tokenToSwap;
            if (indexIn == 0) {
                tokenToSwap = ICurvePool(poolAddress).coins(1);
            } else {
                tokenToSwap = ICurvePool(poolAddress).coins(0);
            }
            uint256[] memory arr;
            _amountOut = _swapExactInput(
                tokenToSwap, tokenOut, receiver, _amountOut, 500, true, address(0), arr
            );
        } else {
            IERC20(tokenOut).safeTransfer(receiver, _amountOut);
        }
    }

    /**
     * @dev Swaps `amountIn` of one token for as much as possible of another token (along
     * the specified path)
     * @param tokenIn The address of input token
     * @param tokenOut The address of output token
     * @param receiver The address of output token to receive
     * @param amountIn The amount of input token to swap
     * @param fee The amount of fee to pay for swap
     * @param directSwap True if the swap is direct, false if it's indirect
     * @param stablecoin The address of stablecoin if the swap is indirect
     * @param pathFee The fees to pay for the path swap
     */
    function _swapExactInput(
        address tokenIn,
        address tokenOut,
        address receiver,
        uint256 amountIn,
        uint256 fee,
        bool directSwap,
        address stablecoin,
        uint256[] memory pathFee
    )
        private
        returns (uint256 _amountOut)
    {
        IERC20(tokenIn).safeIncreaseAllowance(address(router), amountIn);

        if (directSwap) {
            IRouter.ExactInputSingleParams memory params = IRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee.toUint24(),
                recipient: receiver,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

            _amountOut = router.exactInputSingle(params);
        } else {
            if (pathFee.length != 2) revert SwapManager__InvalidPathFeeLength();

            IRouter.ExactInputParams memory params = IRouter.ExactInputParams({
                path: abi.encodePacked(
                    address(tokenOut), pathFee[1].toUint24(), stablecoin, pathFee[0].toUint24(), tokenIn
                ),
                recipient: receiver,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0
            });

            _amountOut = router.exactInput(params);
        }
    }

    /**
     * @dev Swaps as little as possible of one token for `amountOut` of another along the specified
     * path (reversed) via UniswapV3
     * @param coll The address of collateral to get configuration
     * @param tokenOut The address of output token
     * @param tokenInReceiver The address of token in receiver, if the swap did not require the full
     * amountIn to achieve the exact amountOut
     * @param amountIn The amount of input token to swap
     * @param amountOut The amount of output token to receive
     */
    function _swapExactOutput(
        address coll,
        address tokenOut,
        address tokenInReceiver,
        uint256 amountIn,
        uint256 amountOut
    )
        private
    {
        SwapConfig memory swapConfig = swapConfigs[coll];
        DebtSwapConfig memory debtSwapConfig = debtSwapConfigs[coll];

        IERC20(swapConfig.underlyingAsset).safeIncreaseAllowance(address(router), amountIn);

        uint256 _amountIn;
        if (debtSwapConfig.directSwap) {
            IRouter.ExactOutputSingleParams memory params = IRouter.ExactOutputSingleParams({
                tokenIn: swapConfig.underlyingAsset,
                tokenOut: tokenOut,
                fee: debtSwapConfig.fee.toUint24(),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountIn,
                sqrtPriceLimitX96: 0
            });

            _amountIn = router.exactOutputSingle(params);
        } else {
            if (debtSwapConfig.pathFee.length != 2) revert SwapManager__InvalidPathFeeLength();

            IRouter.ExactOutputParams memory params = IRouter.ExactOutputParams({
                path: abi.encodePacked(
                    address(tokenOut),
                    debtSwapConfig.pathFee[1].toUint24(),
                    debtSwapConfig.stablecoin,
                    debtSwapConfig.pathFee[0].toUint24(),
                    swapConfig.underlyingAsset
                ),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountIn
            });

            _amountIn = router.exactOutput(params);
        }

        // If the swap did not require the full amountIn to achieve the exact amountOut then we
        // refund recipient and forceApprove the router to spend 0.
        if (_amountIn < amountIn) {
            IERC20(swapConfig.underlyingAsset).forceApprove(address(router), 0);
            IERC20(swapConfig.underlyingAsset).safeTransfer(tokenInReceiver, amountIn - _amountIn);
        }
    }

    /**
     * @dev Reverts if the address is not set
     * @param addr The address to check
     */
    function _checkConfigSet(address addr) private pure {
        if (addr == address(0)) {
            revert SwapManager__ConfigNotSet(addr);
        }
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
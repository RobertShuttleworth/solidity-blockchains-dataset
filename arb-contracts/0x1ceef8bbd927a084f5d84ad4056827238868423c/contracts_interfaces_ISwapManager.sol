// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

/// @title ISwapManager
/// @notice Defines the basic interface for SwapManager.
interface ISwapManager {
    /**
     * @dev Configuration for swapping collateral
     * @param swapper The address of swapper contract
     * @param underlyingAsset The address of underlying asset of collateral after swap
     * @param fee The amount of fee to pay for swap
     * @param stablecoin The address of stablecoin which using as middle stage to get XY
     * @param directSwap The index that show possibility to swap without or with middle stage
     * (stablecoin) to get XY
     * @param pathFee The amount of fee to pay for swap with middle stage
     */
    struct SwapConfig {
        address swapper;
        address underlyingAsset;
        uint256 fee;
        bool directSwap;
        address stablecoin;
        uint256[] pathFee;
    }

    struct DebtSwapConfig {
        uint256 fee;
        bool directSwap;
        address stablecoin;
        uint256[] pathFee;
    }

    /// @dev Thrown when the caller is not BorrowerOperations contract.
    error SwapManager__CallerIsNotBorrowerOperations();

    /// @dev Thrown when the caller is not TrenBoxStorage contract.
    error SwapManager__CallerIsNotTrenBoxStorage();

    /// @dev Thrown when the caller is not FlashLoan contract.
    error SwapManager__CallerIsNotFlashLoan();

    /// @dev Thrown when one or more provided addresses are zero addresses.
    error SwapManager__ZeroAddress();

    /// @dev Thrown when the config should be set.
    error SwapManager__ConfigShouldBeSetFirst(address coll);

    /// @dev Thrown when the config is not set.
    error SwapManager__ConfigNotSet(address asset);

    /// @dev Thrown when the arrays are not the same length.
    error SwapManager__ArrayMismatch();

    /// @dev Thrown when the path fee length is invalid (more or less than 2).
    error SwapManager__InvalidPathFeeLength();

    /// @dev Thrown when the renounce ownership is disabled.
    error SwapManager__RenounceOwnershipDisabled();

    /// @dev Emitted when the new config is set.
    event SetConfig(address indexed asset, SwapConfig config, DebtSwapConfig debtConfig);

    /// @dev Emitted when the config is updated.
    event UpdateConfig(address indexed asset, SwapConfig config, DebtSwapConfig debtConfig);

    /// @dev Emitted when the config is removed.
    event RemoveConfig(address indexed asset);

    /// @dev Emitted when the new router is set.
    event NewRouterSet(address indexed router);

    /// @dev Emitted when the collateral is staked.
    event StakedCollateral(address indexed coll, uint256 collAmount);

    /// @dev Emitted when the collateral is unstaked.
    event UnstakedCollateral(address indexed coll, uint256 collAmount);

    /// @dev Emitted when the collateral is swapped to XY.
    event Swap(
        address indexed caller,
        address indexed coll,
        uint256 collAmountIn,
        address indexed underlyingAsset,
        uint256 debtAmountOut
    );

    /**
     * @notice Swaps collateral to XY with Flashloan
     * @dev Only Flashloan contract can call
     * @param coll The address of collateral asset
     * @param collAmount The amount of collateral to swap
     * @param debtExpected The expected amount of XY to get after swap
     * @param recipient The address of recipient
     */
    function swap(
        address coll,
        uint256 collAmount,
        uint256 debtExpected,
        address recipient
    )
        external;

    /**
     * @notice Stakes collateral
     * @dev Only BorrowerOperations contract can call
     * As an example with Curve protocol, we need to stake LP into Gauge contract to get rewards in
     * CRV token
     * @param coll The address of collateral asset
     * @param collAmount The amount of collateral to stake
     */
    function stake(address coll, uint256 collAmount) external;

    /**
     * @notice Unstakes collateral
     * @dev Only TrenBoxStorage contract can call
     * We just unstake LP token from Gauge without claiming rewards
     * @param coll The address of collateral asset
     * @param collAmount The amount of collateral to unstake
     */
    function unstake(address coll, uint256 collAmount) external;
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAllowanceTransfer} from "./lib_permit2_src_interfaces_IAllowanceTransfer.sol";
import {PositionId} from "./src_types_PositionId.sol";
import {IPoolPartyPositionStructs, IPoolPartyPositionViewStructs} from "./src_interfaces_IPoolPartyPosition.sol";
import {ISecurityStructs} from "./src_interfaces_ISecurity.sol";
import {IExtsload} from "./src_interfaces_IExtsload.sol";

interface IPoolPartyPositionManagerStructs {
    /// @notice HiddenFields is a struct that contains the fields that can be hidden in the front end
    struct HiddenFields {
        bool showPriceRange;
        bool showTokenPair;
        bool showInOutRange;
    }

    struct FeatureSettings {
        /// @param The name of the pool
        string name;
        /// @param The description of the pool
        string description;
        /// @param The operator fee associated with the pool: between 1000 (10%) and 10000 (100%)
        uint24 operatorFee;
        /// @notice These are parameters for the front end to show/hide certain fields
        HiddenFields hiddenFields;
    }

    struct ConstructorParams {
        /// @param The address of the admin
        address admin;
        /// @param The address of the upgrader
        address upgrader;
        /// @param The address of the pauser
        address pauser;
        /// @param The address of the destroyer
        address destroyer;
        /// @param The address of the INonfungiblePositionManager
        address nonfungiblePositionManager;
        /// @param The address of the Uniswap V3 Factory
        address uniswapV3Factory;
        /// @param The address of the Uniswap V3 Swap Router
        address uniswapV3SwapRouter;
        /// @param The address of Permit2 contract
        address permit2;
        /// @param The address of the WETH9 token
        address WETH9;
        /// @param The address of the StableCurrency token
        address stableCurrency;
        /// @param The address of the poolParty recipient
        address protocolFeeRecipient;
        /// @param The address of the UbitsPoolPositionFactory
        address poolPositionFactory;
        /// @param The root for the operators whitelist
        bytes32 rootForOperatorsWhitelist;
        /// @param The address of the signer security address
        address signerSecurityAddress;
        /// @param The address of the cube3 Router
        address cube3Router;
        /// @param The flag to check protection
        bool cube3CheckProtection;
    }

    struct CreatePositionParams {
        /// @param The proof associated with the operators whitelist
        bytes32[] proof;
        /// @notice Worth noting we expect the currency0 and currency1 to be in the correct order,
        /// as the pool will be created with token at postion 0 as 'currency0' and token at position 1 as 'currency1'
        /// @param The batch permit params necessary to add liquidity to a pool position using permit, encoded as `IAllowanceTransfer.PermitBatch` in calldata
        IAllowanceTransfer.PermitBatch permitBatch;
        /// @param signature The signature necessary to add liquidity to a pool position using permit
        bytes signature;
        /// @param The fee associated with the pool: 100 (0,01%),500 (0,05%), 3000 (0,3%), or 10000 (1%)
        uint24 fee;
        /// @param tickLower The lower end of the tick range for the position
        int24 tickLower;
        /// @param tickUpper The higher end of the tick range for the position
        int24 tickUpper;
        /// @notice Must be calculated in the client side to adjust for slippage tolerance.
        /// @param amount0Min The minimum amount of currency0 to spend, which serves as a slippage check
        uint256 amount0Min;
        /// @notice Must be calculated in the client side to adjust for slippage tolerance.
        /// @param amount1Min The minimum amount of currency1 to spend, which serves as a slippage check
        uint256 amount1Min;
        /// @param deadline The time by which the transaction must be included to effect the change
        uint256 deadline;
        /// @notice Sets the initial price for the pool
        /// @dev Price is represented as a sqrt(amountCurrency1/amountCurrency0) Q64.96 value
        /// @param sqrtPriceX96 the initial sqrt price of the pool as a Q64.96
        uint160 sqrtPriceX96;
        /// @param The params necessary to create a pool position, encoded as `FeatureSettings` in calldata
        FeatureSettings featureSettings;
        /// @param secParams The params necessary to check the security, encoded as `SecurityProtectionParams` in calldata
        ISecurityStructs.SecurityProtectionParams secParams;
    }

    struct AddLiquidityParams {
        /// @param The proof associated with the investors whitelist
        bytes32[] proof;
        /// @param The id of the position for a specific pool
        PositionId positionId;
        /// @param deadline The time by which the transaction must be included to effect the change
        uint256 deadline;
        /// @param swap The params necessary to swap to StableCurrency, encoded as `SwapParams` in calldata
        IPoolPartyPositionStructs.SwapParams swap;
        /// @param permit The permit params necessary to add liquidity to a pool position using permit, encoded as `IAllowanceTransfer.PermitSingle` in calldata
        IAllowanceTransfer.PermitSingle permit;
        /// @param signature The signature necessary to add liquidity to a pool position using permit
        bytes signature;
        /// @param ignoreSlippage The flag to ignore slippage tolerance
        bool ignoreSlippage;
        /// @param secParams The params necessary to check the security, encoded as `SecurityProtectionParams` in calldata
        ISecurityStructs.SecurityProtectionParams secParams;
    }

    struct RemoveLiquidityParams {
        /// @param The id of the position for a specific pool
        PositionId positionId;
        /// @param percentage The percentage of liquidity to be removed
        /// @dev The percentage is represented as 1e15 (1%) - 100e15 (100%)
        uint256 percentage;
        /// @notice Must be calculated in the client side to adjust for slippage tolerance.
        /// @param amount0Min The minimum amount of currency0 to spend, which serves as a slippage check
        uint256 amount0Min;
        /// @notice Must be calculated in the client side to adjust for slippage tolerance.
        /// @param amount1Min The minimum amount of currency1 to spend, which serves as a slippage check
        uint256 amount1Min;
        /// @param deadline The time by which the transaction must be included to effect the change
        uint256 deadline;
        /// @param swap The params necessary to swap to StableCurrency, encoded as `SwapParams` in calldata
        IPoolPartyPositionStructs.SwapParams swap;
        /// @param swapAllToStableCurrency The params necessary to swap all to StableCurrency, encoded as `SwapAllToStableCurrencyParams` in calldata
        IPoolPartyPositionStructs.SwapAllToStableCurrencyParams swapAllToStableCurrency;
        /// @param secParams The params necessary to check the security, encoded as `SecurityProtectionParams` in calldata
        ISecurityStructs.SecurityProtectionParams secParams;
    }

    struct CollectParams {
        /// @param The id of the position for a specific pool
        PositionId positionId;
        /// @param deadline The time by which the transaction must be included to effect the change
        uint256 deadline;
        /// @param swap The params necessary to swap to StableCurrency, encoded as `SwapParams` in calldata
        IPoolPartyPositionStructs.SwapParams swap;
        /// @param secParams The params necessary to check the security, encoded as `SecurityProtectionParams` in calldata
        ISecurityStructs.SecurityProtectionParams secParams;
    }

    struct ClosePoolParams {
        /// @param The id of the position for a specific pool
        PositionId positionId;
        /// @param deadline The time by which the transaction must be included to effect the change
        uint256 deadline;
        /// @param swapAllToStableCurrency The params necessary to swap all to StableCurrency, encoded as `SwapAllToStableCurrencyParams` in calldata
        IPoolPartyPositionStructs.SwapAllToStableCurrencyParams swapAllToStableCurrency;
        /// @param secParams The params necessary to check the security, encoded as `SecurityProtectionParams` in calldata
        ISecurityStructs.SecurityProtectionParams secParams;
    }

    struct WithdrawParams {
        /// @param The id of the position for a specific pool
        PositionId positionId;
        /// @param deadline The time by which the transaction must be included to effect the change
        uint256 deadline;
        /// @param swap The params necessary to swap to StableCurrency, encoded as `SwapParams` in calldata
        IPoolPartyPositionStructs.SwapParams swap;
        /// @param secParams The params necessary to check the security, encoded as `SecurityProtectionParams` in calldata
        ISecurityStructs.SecurityProtectionParams secParams;
    }

    struct MoveRangeParams {
        /// @param The id of the position for a specific pool
        PositionId positionId;
        /// @param tickLower The lower end of the tick range for the position
        int24 tickLower;
        /// @param tickUpper The higher end of the tick range for the position
        int24 tickUpper;
        /// @param swapAmount0 The amount of currency0 to swap to currency1
        uint256 swapAmount0;
        /// @param swapAmount0Minimum The minimum amount of currency0 to swap to currency1
        uint256 swapAmount0Minimum;
        /// @param swapAmount1 The amount of currency1 to swap to currency0
        uint256 swapAmount1;
        /// @param swapAmount1Minimum The minimum amount of currency1 to swap to currency0
        uint256 swapAmount1Minimum;
        /// @param multihopSwapPath0 The path to swap currency0 to currency1
        bytes multihopSwapPath0;
        /// @param multihopSwapPath1 The path to swap currency1 to currency0
        bytes multihopSwapPath1;
        /// @param deadline The time by which the transaction must be included to effect the change
        uint256 deadline;
        /// @param secParams The params necessary to check the security, encoded as `SecurityProtectionParams` in calldata
        ISecurityStructs.SecurityProtectionParams secParams;
        /// @param ignoreSlippage The flag to ignore slippage tolerance
        bool ignoreSlippage;
    }
}

interface IPoolPartyPositionManagerEvents {
    /// @notice Emitted when the manager is destroyed
    event Destroyed();
}

interface IPoolPartyPositionManager is
    IPoolPartyPositionManagerEvents,
    IPoolPartyPositionManagerStructs,
    IExtsload
{
    /// @notice Sets the max investment for the pool party
    function setMaxInvestment(uint256 _maxInvestment) external;

    /// @notice Sets the pool party recipient
    function setPoolPartyRecipient(address _poolPartyRecipient) external;

    /// @notice Pauses the manager
    function pause() external;

    /// @notice Unpauses the manager
    function unpause() external;

    /// @notice Destroys the manager
    function destroy() external;

    /// @notice Creates a new pool position
    /// @param _params The params necessary to create a pool position, encoded as `CreatePositionParams` in calldata
    /// @return positionId The id that represents the position
    /// @dev revert if the position already exists
    function createPosition(
        CreatePositionParams calldata _params
    ) external payable returns (PositionId positionId);

    /// @notice Adds the amount of liquidity in a position, with tokens paid by the `msg.sender`
    /// @param _params The params necessary to add liquidity to a pool position, encoded as `AddLiquidityParams` in calldata
    /// @return liquidity The liquidity amount as a result of the increase
    /// @return amount0 The amount of currency0 to acheive resulting liquidity
    /// @return amount1 The amount of currency1 to acheive resulting liquidity
    function addLiquidity(
        AddLiquidityParams calldata _params
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    /// @notice Removes the amount of liquidity from a position, with tokens sent to the `investor`
    /// @param _params The params necessary to remove liquidity from a pool position, encoded as `RemoveLiquidityParams` in calldata
    /// @return liquidity The liquidity amount as a result of the remove
    /// @return amount0 The amount of currency0 to acheive resulting liquidity
    /// @return amount1 The amount of currency1 to acheive resulting liquidity
    function removeLiquidity(
        RemoveLiquidityParams calldata _params
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1);

    /// @notice Collects up to a maximum amount of rewards owed to a specific position to the `recipient`
    /// @param _params The params necessary to collect rewards from a pool position, encoded as `CollectParams` in calldata
    /// @return amount0 The amount of currency0 fees collected
    /// @return amount1 The amount of currency1 fees collected
    function collectRewards(
        CollectParams calldata _params
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice Closes the pool and returns the liquidity to the `operator`
    /// @param _params The params necessary to close a pool position, encoded as `ClosePoolParams` in calldata
    function closePool(
        ClosePoolParams calldata _params
    ) external returns (uint128, uint256, uint256);

    /// @notice Withdraws all tokens and collected fees owed to a specific position to the `investor`
    /// @param _params The params necessary to withdraw from a pool position, encoded as `WithdrawParams` in calldata
    /// @return The amount of currency0
    /// @return The amount of currency1
    /// @return The net amount of currency0 fees collected
    /// @return The net amount of currency1 fees collected
    /// @dev event Withdrawn is emitted
    function withdraw(
        WithdrawParams calldata _params
    ) external returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Moves the range of the position based on the provided parameters.
     * @param _params The parameters required to move the range.
     */
    function moveRange(MoveRangeParams calldata _params) external;

    /**
     * @notice Checks if the position manager is destroyed.
     * @return bool True if the position manager is destroyed, false otherwise.
     */
    function isDestroyed() external view returns (bool);
}
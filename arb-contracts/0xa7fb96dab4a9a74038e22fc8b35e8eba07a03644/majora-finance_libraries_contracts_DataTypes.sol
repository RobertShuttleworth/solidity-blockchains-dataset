// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title DataTypes
 * @author Majora Development Association
 */
library DataTypes {
    /// @notice A struct that represents the bitmap configuration of a vault
    struct VaultConfigurationMap {
        //bit 0-7: Middleware strategy
        //bit 8-16: Limit Mode
        //bit 17-47: Timelock duration
        //bit 48-63: Creator fee
        //bit 64-79: Harvest fee
        //bit 80-95: Protocol fee
        //bit 96-111: Buffer size
        //bit 112-127: Buffer derivation
        //bit 128-195: Last harvest index
        //bit 196-255 unused
        uint256 data;
    }

    /// @notice Enum representing the different types of block execution
    enum BlockExecutionType {
        ENTER,
        EXIT,
        HARVEST
    }

    /// @notice Enum representing the different types of dynamic parameters
    enum DynamicParamsType {
        NONE,
        PORTAL_SWAP,
        STATIC_CALL,
        MERKL
    }

    /// @notice Enum representing the different types of swap value
    enum SwapValueType {
        INPUT_STRICT_VALUE,
        INPUT_PERCENT_VALUE,
        OUTPUT_STRICT_VALUE
    }

    /// @notice Struct representing the dynamic swap parameters
    /// @param fromToken The address of the token to swap from
    /// @param toToken The address of the token to swap to
    /// @param value The amount of tokens to swap
    /// @param valueType The type of value to swap
    struct DynamicSwapParams {
        address fromToken;
        address toToken;
        uint256 value;
        SwapValueType valueType; 
    }

    /// @notice Struct representing the static call parameters
    /// @param to The address of the contract to call
    /// @param data The data to send to the contract
    struct StaticCallParams {
        address to;
        bytes data;
    }

    /// @notice Struct representing the dynamic swap data
    /// @param route The route to use for the swap
    /// @param sourceAsset The address of the asset to swap from
    /// @param approvalAddress The address to approve for the swap
    /// @param targetAsset The address of the asset to swap to
    /// @param amount The amount of tokens to swap
    /// @param data The data to send to the swap
    struct DynamicSwapData {
        uint8 route;
        address sourceAsset;
        address approvalAddress;
        address targetAsset;
        uint256 amount;
        bytes data;
    }

    /// @notice Struct representing the state of an oracle
    /// @param vault The address of the vault
    /// @param tokens The addresses of the tokens
    /// @param tokensAmount The amounts of the tokens
    struct OracleState {
        address vault;
        address[] tokens;
        uint256[] tokensAmount;
    }

    /// @notice Struct representing the information of a vault
    /// @param owner The address of the vault owner
    /// @param asset The address of the asset
    /// @param totalSupply The total supply of the vault
    /// @param totalAssets The total assets of the vault
    /// @param gasAvailable The gas available for the vault
    /// @param bufferAssetsAvailable The buffer assets available for the vault
    /// @param bufferSize The buffer size for the vault
    /// @param bufferDerivation The buffer derivation for the vault
    /// @param lastHarvestIndex The last harvest index for the vault
    /// @param currentVaultIndex The current vault index for the vault
    /// @param harvestFee The harvest fee for the vault
    /// @param creatorFee The creator fee for the vault
    /// @param minSupplyForActivation The minimum supply for activation for the vault
    struct MajoraVaultInfo {
        address owner;
        address asset;
        uint256 totalSupply;
        uint256 totalAssets;
        uint256 gasAvailable;
        uint256 bufferAssetsAvailable;
        uint256 bufferSize;
        uint256 bufferDerivation;
        uint256 lastHarvestIndex;
        uint256 currentVaultIndex;
        uint256 harvestFee;
        uint256 creatorFee;
        uint256 minSupplyForActivation;
    }

    /// @notice Struct representing the information of a strategy block execution
    /// @param dynParamsNeeded Whether the strategy block execution needs dynamic parameters
    /// @param dynParamsType The type of dynamic parameters needed
    /// @param dynParamsInfo The information of the dynamic parameters needed
    /// @param blockAddr The address of the strategy block
    /// @param oracleStatus The status of the oracle after the block execution
    struct StrategyBlockExecutionInfo {
        bool dynParamsNeeded;
        DynamicParamsType dynParamsType;
        bytes dynParamsInfo;
        address blockAddr;
        OracleState oracleStatus;
    }

    /// @notice Struct representing the information of a vault execution
    /// @param blocksLength The length of the blocks
    /// @param startOracleStatus The status of the oracle before the execution
    /// @param blocksInfo The information of the blocks
    struct MajoraVaultExecutionInfo {
        uint256 blocksLength;
        OracleState startOracleStatus;
        StrategyBlockExecutionInfo[] blocksInfo;
    }

    /// @notice Struct representing the information of a position manager rebalance execution
    /// @param vault The address of the vault
    /// @param blockIndex The index of the block
    /// @param dynParamsType The type of dynamic parameters needed
    /// @param dynParamsInfo The information of the dynamic parameters needed
    /// @param partialExit The partial exit execution info
    /// @param partialEnter The partial enter execution info
    struct PositionManagerRebalanceExecutionInfo {
        address vault;
        uint256 blockIndex;
        DynamicParamsType dynParamsType;
        bytes dynParamsInfo;
        MajoraVaultExecutionInfo partialExit;
        MajoraVaultExecutionInfo partialEnter;
    }

    /// @notice Enum representing the different types of permit
    enum PermitType {
        PERMIT,
        PERMIT2
    }

    /// @notice Struct representing the permit parameters
    /// @param permitType The type of permit
    /// @param parameters The parameters of the permit
    struct PermitParameters {
        PermitType permitType;
        bytes parameters;
    }

    /// @notice Struct representing the parameters of a permit
    /// @param deadline The deadline of the permit
    /// @param v The v of the permit signature
    /// @param r The r of the permit signature
    /// @param s The s of the permit signature
    struct PermitParams {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /// @notice Struct representing the parameters of a permit2
    /// @param deadline The deadline of the permit
    /// @param nonce The nonce of the permit
    /// @param signature The signature of the permit
    struct Permit2Params {
        uint256 deadline;
        uint256 nonce;
        bytes signature;
    }
}
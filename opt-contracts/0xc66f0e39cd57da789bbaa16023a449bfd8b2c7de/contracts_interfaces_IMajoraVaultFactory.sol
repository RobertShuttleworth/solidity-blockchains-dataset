// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IMajoraVault } from "./contracts_interfaces_IMajoraVault.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";

/**
 * @title MajoraVaultFactory
 * @author Majora Development Association
 * @dev Factory contract for deploying MajoraVault instances.
 */
interface IMajoraVaultFactory {

    /**
     * @dev Error thrown when the caller is not the factory contract.
     */
    error NotFactory();

    /**
     * @dev Error thrown when the caller is not the owner.
     */
    error NotOwner();

    /**
     * @dev Error thrown when the caller is not the owner.
     */
    error NotUserInteractions();

    /**
     * @dev Error thrown when the caller is not the vault owner.
     */
    error NotVaultOwner();

    /**
     * @dev Error thrown when the vault passed as parameter doesn't exists
     */
    error InvalidVault();

    /**
     * @dev Error thrown when the caller is not whitelisted.
     */
    error NotWhitelisted();

    /**
     * @dev Error thrown when the harvest fee is not within acceptable parameters.
     */
    error BadHarvestFee();

    /**
     * @dev Error thrown when the creator fee is not within acceptable parameters.
     */
    error BadCreatorFee();

    /**
     * @dev Error thrown when the buffer parameters are not within acceptable parameters.
     */
    error BadBufferParams();

    /**
     * @dev Error thrown when the factory has not been initialized.
     */
    error NotInitialized();

    /**
     * @dev Error thrown when a deposit execution fails.
     * @param returnedData The data returned from the failed deposit execution.
     */
    error DepositExecutionFailed(bytes returnedData);

    /**
     * @dev Error thrown when an invalid position manager address is provided.
     */
    error BadPositionManagerAddress();

    /**
     * @dev Error thrown when inputs arrays length are different.
     */
    error ArrayLengthsMismatch();

    /**
     * @dev Error thrown when vault strategy to set is empty
     */
    error EmptyStrategyIsNotAllowed();

    /**
     * @dev Error thrown when an attempt to edit settings is made before the timelock period has reached.
     */
    error EditParamsQueueTimelockNotReach();

    /**
     * @dev Error thrown when an attempt to edit settings is made before the timelock period has reached.
     */
    error EditParamsQueueIndexOutOfBound();

    /**
     * @dev Error thrown when an invalid protocol fee is set.
     */
    error InvalidProtocolFee();

    /**
     * @dev Emitted when StrategVault is upgraded
     * @param id The new version id.
     * @param addr The address of the new implementation.
     * @param name The address of the new implementation.
     * @param symbol The address of the new implementation.
     * @param asset The address of the new implementation.
     * @param owner The address of the new implementation.
     * @param erc3525 The address of the new implementation.
     * @param implementation The address of the new implementation.
     * @param ipfsHash The address of the new implementation.
     */
    event NewVault(
        uint256 indexed id,
        address indexed addr,
        string name,
        string symbol,
        address asset,
        address indexed owner,
        address erc3525,
        address implementation,
        string ipfsHash
    );

    /**
     * @dev Emitted when MajoraVault is upgraded
     * @param version The new version id.
     * @param implementation The address of the new implementation.
     */
    event NewVaultImplementation(uint256 indexed version, address implementation);
    
    /**
     * @dev Emitted when MajoraERC3525 is upgraded
     * @param version The new version id.
     * @param implementation The address of the new implementation.
     */
    event NewERC2535Implementation(uint256 indexed version, address implementation);

    /**
     * @dev Emitted when middleware is initialized for a vault.
     * @param vault The address of the vault.
     * @param strategy The identifier of the strategy.
     */
    event MiddlewareInit(address indexed vault, uint256 strategy);

    /**
     * @dev Emitted when new timelock parameters are set for a vault.
     * @param vault The address of the vault.
     * @param duration The duration of the timelock in seconds.
     */
    event NewTimelockParams(address indexed vault, uint256 duration);

    /**
     * @dev Emitted when deposit limits are updated for a vault.
     * @param vault The address of the vault.
     * @param minUserDeposit The minimum deposit amount allowed per user.
     * @param maxUserDeposit The maximum deposit amount allowed per user.
     * @param minVaultDeposit The minimum deposit amount allowed for the vault.
     * @param maxVaultDeposit The maximum deposit amount allowed for the vault.
     */
    event NewDepositLimits(
        address indexed vault,
        uint256 minUserDeposit,
        uint256 maxUserDeposit,
        uint256 minVaultDeposit,
        uint256 maxVaultDeposit
    );

    /**
     * @dev Emitted when holding parameters are set for a vault.
     * @param vault The address of the vault.
     * @param token The address of the token being held.
     * @param amount The amount of the token being held.
     */
    event NewHoldingParams(address indexed vault, address token, uint256 amount);

    /**
     * @dev Emitted when buffer parameters are updated for a vault.
     * @param vault The address of the vault.
     * @param bufferSize The size of the buffer.
     * @param bufferDerivation The derivation method of the buffer.
     */
    event NewBufferParams(address indexed vault, uint256 bufferSize, uint256 bufferDerivation);

    /**
     * @dev Emitted when the whitelist is edited for a vault.
     * @param vault The address of the vault.
     * @param add Boolean indicating if the address is being added (true) or removed (false).
     * @param addr The address being added or removed from the whitelist.
     */
    event EditWhitelist(address indexed vault, bool add, address addr);

    /**
     * @dev Emitted when fee parameters are updated for a vault.
     * @param vault The address of the vault.
     * @param creatorFees The fees allocated to the creator.
     * @param harvestFees The fees allocated for harvesting.
     */
    event NewFeeParams(address indexed vault, uint256 creatorFees, uint256 harvestFees);

    /**
     * @dev Emitted when fee parameters are updated for a vault.
     * @param vault The address of the vault.
     * @param index The fees allocated to the creator.
     */
    event NewVaultParametersEditQueueItem(address indexed vault, uint256 index);

    /**
     * @dev Emitted when fee parameters are updated for a vault.
     * @param vault The address of the vault.
     * @param index The fees allocated to the creator.
     */
    event VaultParametersEditQueueItemExecuted(address indexed vault, uint256 index);

    /**
     * @dev Emitted when an edit is canceled.
     * @param vault The address of the vault.
     * @param index The fees allocated to the creator.
     */
    event VaultParametersEditQueueItemCanceled(address indexed vault, uint256 index);

    struct VaultConfigurationStore {
        //ERC3525 address
        address erc3525;

        //configuration Bitmap
        DataTypes.VaultConfigurationMap config;

        //Limit related configurations
        uint256 userMinDeposit;
        uint256 userMaxDeposit;
        uint256 vaultMinDeposit;
        uint256 vaultMaxDeposit;

        //Holding middleware configs
        address holdToken;
        uint256 holdAmount;

        //Whitelist middleware configs
        mapping(address => bool) isWhitelisted; 
    }

    struct VaultParametersEditQueueItem {
        uint256 initializedAt;
        IMajoraVault.MajoraVaultSettings[] settings;
        bytes[] settingsData;
    }

    /**
     * @notice Get the total number of vaults created.
     * @return The total number of vaults.
     */
    function vaultsLength() external view returns (uint256);

    /**
     * @notice Get the address of a vault by its index.
     * @param index The index of the vault.
     * @return The address of the vault.
     */
    function vaults(uint256 index) external view returns (address);

    /**
     * @notice Get the protocol fee.
     * @return The protocol fee.
     */
    function protocolFee() external view returns (uint256);

    /**
     * @notice Set the protocol fee.
     * @param _fee The new protocol fee.
     */
    function setProtocolFee(uint256 _fee) external;

    /**
     * @notice Sets the deposit limits for user and vault.
     * @param _vault Vault address
     * @param _fee The new vault protocol fee
     */
    function setVaultProtocolFee(
        address _vault,
        uint256 _fee
    ) external;

    /**
     * @dev Edit vault configuration.
     * @param _user sender from MajoraUserInteractions.
     * @param _vault Targeted vault
     * @param _assets Array of settings identifier to edits.
     * @param _receiver Array of values corresponding to settings.
     */
    function vaultDeposit(
        address _user,
        address _vault,
        uint256 _assets,
        address _receiver        
    ) external;

    /**
     * @notice Deploy a new StrategVault contract.
     * @param _name The name of the vault.
     * @param _symbol The symbol of the vault.
     * @param _owner The address of the vault owner.
     * @param _asset The address of the underlying asset.
     * @param _strategy The strategy to be used by the vault.
     * @param _creatorFees The creator fees for the vault.
     * @param _harvestFees The harvest fees for the vault.
     * @param _ipfsHash The IPFS hash associated with the vault.
     */
    function deployNewVault(
        string memory _name,
        string memory _symbol,
        address _owner,
        address _asset,
        uint256 _strategy,
        uint256 _creatorFees,
        uint256 _harvestFees,
        string memory _ipfsHash
    ) external;

    /**
     * @dev Set the strategy blocks for the vault.
     * @param _user sender from MajoraUserInteractions.
     * @param _vault Targeted vault
     * @param _positionManagers Array of position managers.
     * @param _stratBlocks Array of strategy blocks.
     * @param _stratBlocksParameters Array of strategy block parameters.
     * @param _harvestBlocks Array of harvest blocks.
     * @param _harvestBlocksParameters Array of harvest block parameters.
     */
    function setVaultStrat(
        address _user,
        address _vault,
        address[] memory _positionManagers,
        address[] memory _stratBlocks,
        bytes[] memory _stratBlocksParameters,
        bool[] memory _isFinalBlock,
        address[] memory _harvestBlocks,
        bytes[] memory _harvestBlocksParameters
    ) external;

    /**
     * @dev Edit vault configuration.
     * @param _user sender from MajoraUserInteractions.
     * @param _vault Targeted vault
     * @param _settings Array of settings identifier to edits.
     * @param _data Array of values corresponding to settings.
     */
    function editVaultParams(
        address _user,
        address _vault,
        IMajoraVault.MajoraVaultSettings[] memory _settings,
        bytes[] calldata _data
    ) external;

    /**
     * @dev Edit vault configuration.
     * @param _vault Targeted vault
     */
    function executeVaultParamsEdit(
        address _vault
    ) external;

    /**
     * @notice Get the batch vault addresses for a given array of indices.
     * @param _indexes The array of vault index.
     * @return An array of vault addresses corresponding to the given indices.
     */
    function getBatchVaultAddresses(uint256[] memory _indexes) external view returns (address[] memory);

    /**
     * @notice Sets the deposit limits for user and vault.
     * @param _vault Vault address
     * @return _config Vault configuration Bitmap
     */
    function getVaultConfiguration(address _vault)
        external
        view
        returns (DataTypes.VaultConfigurationMap memory);


    /**
     * @notice Return separated vault config bitmap value
     * @param _vault Vault address
     * @return _middlewareStrategy The middleware strategy for the vault.
     * @return _limitMode The limit mode for the vault.
     * @return _timelockDuration The timelock duration for the vault.
     * @return _creatorFee The creator fee for the vault.
     * @return _harvestFee The harvest fee for the vault.
     * @return _protocolFee The protocol fee for the vault.
     * @return _bufferSize The buffer size for the vault.
     * @return _bufferDerivation The buffer derivation for the vault.
     * @return _lastHarvestIndex The last harvest index for the vault.
     */
    function getVaultReadableConfiguration(
        address _vault
    ) external view returns (
        uint256 _middlewareStrategy,
        uint256 _limitMode,
        uint256 _timelockDuration,
        uint256 _creatorFee,
        uint256 _harvestFee,
        uint256 _protocolFee,
        uint256 _bufferSize,
        uint256 _bufferDerivation,
        uint256 _lastHarvestIndex
    );

    /**
     * @notice Check if an address is whitelisted on a vault
     * @param _vault Vault address
     * @return whitelisted Boolean returning if a user is whitelisted
     */
    function addressIsWhitelistedOnVault(address _vault, address _addr)
        external
        view
        returns (bool);

    /**
     * @notice Sets the deposit limits for user and vault.
     * @param _vault Vault address
     * @return _minUserDeposit Minimum user deposit
     * @return _maxUserDeposit Maximum user deposit
     * @return _minVaultDeposit Minimum vault deposit
     * @return _maxVaultDeposit Maximum vault deposit
     */
    function getVaultDepositLimits(address _vault)
            external
            view
            returns (
                uint256 _minUserDeposit,
                uint256 _maxUserDeposit,
                uint256 _minVaultDeposit,
                uint256 _maxVaultDeposit
            );

    /**
     * @notice get the min deposit limits for a vault.
     * @param _vault Vault address
     * @return _minVaultDeposit Minimum vault deposit
     */
    function getVaultMinimalDepositLimits(address _vault)
        external
        view
        returns (uint256);

    /**
     * @notice Get holding parameters for a vault
     * @param _vault Vault address
     * @return token Token to hold
     * @return amount Amount to hold
     */
    function getVaultHoldingParams(address _vault)
        external
        view
        returns (address token, uint256 amount);
}
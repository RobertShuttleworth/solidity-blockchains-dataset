// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_interfaces_IERC4626.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_proxy_Clones.sol";
import "./openzeppelin_contracts_access_manager_AccessManaged.sol";

import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import {VaultConfiguration} from "./majora-finance_libraries_contracts_VaultConfiguration.sol";
import {IMajoraAddressesProvider} from "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";

import {IMajoraVault} from "./contracts_interfaces_IMajoraVault.sol";
import {IMajoraVaultFactory} from "./contracts_interfaces_IMajoraVaultFactory.sol";
import {IMajoraERC3525} from "./contracts_interfaces_IMajoraERC3525.sol";
import {IMajoraPositionManagerFactory} from "./contracts_interfaces_IMajoraPositionManagerFactory.sol";

/**
 * @title MajoraVaultFactory
 * @author Majora Development Association
 * @dev Factory contract for deploying MajoraVault instances.
 */
contract MajoraVaultFactory is IMajoraVaultFactory, AccessManaged {
    using VaultConfiguration for DataTypes.VaultConfigurationMap;

    uint256 constant DEFAULT_PROTOCOL_FEE = 10001;
    uint256 constant EDIT_SETTINGS_QUEUE_DURATION = 3 days;
    uint256 constant QUEUE_GUARD = 0;
    
    /**
     * @notice Address provider for the factory, indicating if the factory has been initialized
     */
    IMajoraAddressesProvider public addressProvider;

    /**
     * @notice Indicates if the factory has been initialized
     */
    bool initialized;

    /**
     * @notice The current version of the vault logic contract
     */
    uint256 public VAULT_VERSION;

    /**
     * @notice The current version of the ERC3525 logic contract
     */
    uint256 public ERC3525_VERSION;

    /**
     * @notice The implementation address of the ERC3525 token
     */
    address public erc3525Implementation;

    /**
     * @notice The implementation address of the vault
     */
    address public vaultImplementation;

    /**
     * @notice The protocol fee charged for vault operations
     */
    uint256 public protocolFee;

    /**
     * @notice The total number of vaults created by the factory
     */
    uint256 public vaultsLength;

    /**
     * @notice Mapping from vault index to vault address
     */
    mapping(uint256 => address) public vaults;

    /**
     * @notice Mapping from vault address to settings timelock
     */
    mapping(address => bool) public vaultParamsInitialized;

    /**
     * @notice Mapping from vault address to vault settings update queue
     */
    mapping(address => mapping(uint256 => VaultParametersEditQueueItem)) public vaultParamsChanges;
    mapping(address => mapping(uint256 => uint256)) public nextQueueItem;
    mapping(address => uint256) public totalChangeLength;
    mapping(address => uint256) public queueSize;


    /**
     * @notice Mapping from vault address to vault configuration
     */
    mapping(address => VaultConfigurationStore) vaultConfiguration;

    modifier isValidVault(address _vault) {
        if (vaultConfiguration[_vault].erc3525 == address(0)) revert InvalidVault();
        _;
    }

    modifier onlyVaultOwner(address vault, address user) {
        if (IMajoraVault(vault).owner() != user) revert NotVaultOwner();
        _;
    }

    modifier onlyMajoraUserInteractions() {
        if (addressProvider.userInteractions() != msg.sender)
            revert NotUserInteractions();
        _;
    }

    /**
     * @dev Constructor for the MajoraVaultFactory.
     * @param _authority The address of the authority.
     * @param _addressProvider The address of the address provider.
     */
    constructor(
        address _authority,
        address _addressProvider
    ) AccessManaged(_authority) {
        addressProvider = IMajoraAddressesProvider(_addressProvider);
    }

    /**
     *  ------------ Vault deployment part ------------
     */

    /**
     * @notice Deploy a new MajoraVault contract.
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
    ) external onlyMajoraUserInteractions {
        if (VAULT_VERSION == 0 || ERC3525_VERSION == 0) revert NotInitialized();

        address vaultProxy = Clones.clone(vaultImplementation);
        address erc3525Proxy = Clones.clone(erc3525Implementation);
        uint256 vLength = vaultsLength;

        emit NewVault(
            vLength,
            vaultProxy,
            _name,
            _symbol,
            _asset,
            _owner,
            erc3525Proxy,
            vaultImplementation,
            _ipfsHash
        );

        IMajoraVault(vaultProxy).initialize(
            erc3525Proxy,
            _name,
            _symbol,
            _asset
        );

        IMajoraERC3525(erc3525Proxy).initialize(
            vaultProxy,
            _owner,
            _asset,
            authority()
        );

        vaultConfiguration[vaultProxy].erc3525 = erc3525Proxy;

        DataTypes.VaultConfigurationMap memory c = vaultConfiguration[
            vaultProxy
        ].config;

        c.setMiddlewareStrategy(_strategy);
        c.setProtocolFee(DEFAULT_PROTOCOL_FEE);
        c.setTimelockDuration(0);
        c.setCreatorFee(_creatorFees);
        c.setHarvestFee(_harvestFees);
        c.setBufferSize(1000);
        c.setBufferDerivation(500);
        vaultConfiguration[vaultProxy].config = c;

        emit MiddlewareInit(vaultProxy, _strategy);
        emit NewFeeParams(vaultProxy, _creatorFees, _harvestFees);
        emit NewBufferParams(vaultProxy, 1000, 500);

        if (_strategy == 1) _vaultWhitelist(vaultProxy, true, _owner);

        vaults[vaultsLength] = address(vaultProxy);
        vaultsLength += 1;
    }

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
    ) external onlyMajoraUserInteractions isValidVault(_vault) onlyVaultOwner(_vault, _user) {

        if(_stratBlocks.length == 0) revert EmptyStrategyIsNotAllowed();
        if(_stratBlocks.length != _stratBlocksParameters.length || _stratBlocks.length != _isFinalBlock.length) revert ArrayLengthsMismatch();
        if(_harvestBlocks.length != _harvestBlocksParameters.length) revert ArrayLengthsMismatch();

        uint256 pmLength = _positionManagers.length;
        if (pmLength > 0) {
            IMajoraPositionManagerFactory pmFactory = IMajoraPositionManagerFactory(
                    addressProvider.positionManagerFactory()
                );
            for (uint i = 0; i < pmLength; i++) {
                if (!pmFactory.isPositionManager(_positionManagers[i]))
                    revert BadPositionManagerAddress();
            }
        }

        IMajoraVault(_vault).setStrat(
            _positionManagers,
            _stratBlocks,
            _stratBlocksParameters,
            _isFinalBlock,
            _harvestBlocks,
            _harvestBlocksParameters
        );
    }

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
        bytes[] memory _data
    ) external onlyMajoraUserInteractions isValidVault(_vault) onlyVaultOwner(_vault, _user) {
        if (_settings.length != _data.length) revert ArrayLengthsMismatch();
        if(!vaultParamsInitialized[_vault]) {
            _editVaultParams(
                _vault,
                _settings,
                _data
            );

            vaultParamsInitialized[_vault] = true;
        } else {
            VaultParametersEditQueueItem memory changes = VaultParametersEditQueueItem({
                initializedAt: block.timestamp,
                settings: _settings,
                settingsData: _data
            });

            uint256 index = _addQueueItem(_vault, changes);
            emit NewVaultParametersEditQueueItem(_vault, index);
        }
    }

    /**
     * @dev Edit vault configuration.
     * @param _vault Targeted vault
     */
    function executeVaultParamsEdit(
        address _vault
    ) external onlyMajoraUserInteractions isValidVault(_vault) {
        uint256 queueLength = queueSize[_vault];
        for (uint i = 1; i <= queueLength; i++) {

            uint256 changeIndex = _findChangeIndexByQueueIndex(_vault, i);
            VaultParametersEditQueueItem storage change = vaultParamsChanges[_vault][changeIndex];
            if (change.initializedAt != 0 && change.initializedAt + EDIT_SETTINGS_QUEUE_DURATION <= block.timestamp) {
                _editVaultParams(
                    _vault,
                    change.settings,
                    change.settingsData
                );

                _removeQueueItem(_vault, i);
                emit VaultParametersEditQueueItemExecuted(_vault, i);  

                i -= 1;     
                queueLength -= 1;
            }
        }
    }

    /**
     * @dev Edit vault configuration.
     * @param _user user calling the function
     * @param _vault Targeted vault
     * @param _index Array of settings identifier to edits.
     */
    function cancelVaultParamsEdit(
        address _user,
        address _vault,
        uint256 _index
    ) external onlyMajoraUserInteractions isValidVault(_vault) onlyVaultOwner(_vault, _user) {

        uint256 queueLength = queueSize[_vault];
        if(queueLength == 0 || _index > queueLength - 1)
            revert EditParamsQueueIndexOutOfBound();

        _removeQueueItem(_vault, _index);
        emit VaultParametersEditQueueItemCanceled(_vault, _index);
    }

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
    ) external onlyMajoraUserInteractions isValidVault(_vault) {
        (bool success, bytes memory returndata) = _vault.call(
            abi.encodePacked(
                abi.encodeWithSelector(
                    IERC4626.deposit.selector,
                    _assets,
                    _receiver
                ),
                _user
            )
        );

        if (!success) revert DepositExecutionFailed(returndata);
    }

    /**
     *  ------------ Vault implementation upgrade part ------------
     */

    /**
     * @notice Upgrade the vault implementation contract.
     * @param _implementation The address of the new implementation contract.
     */
    function upgradeVault(address _implementation) external restricted {
        VAULT_VERSION += 1;
        vaultImplementation = _implementation;
        emit NewVaultImplementation(VAULT_VERSION, _implementation);
    }

    /**
     * @notice Upgrade the ERC3525 implementation contract.
     * @param _implementation The address of the new implementation contract.
     */
    function upgradeERC3525(address _implementation) external restricted {
        ERC3525_VERSION += 1;
        erc3525Implementation = _implementation;
        emit NewERC2535Implementation(ERC3525_VERSION, _implementation);
    }

    /**
     *  ------------ Vault getter part ------------
     */

    /**
     * @notice Get the batch vault addresses for a given array of indices.
     * @param _indexes The array of vault index.
     * @return An array of vault addresses corresponding to the given indices.
     */
    function getBatchVaultAddresses(
        uint256[] memory _indexes
    ) external view returns (address[] memory) {
        address[] memory vaultAddresses = new address[](_indexes.length);
        for (uint256 i = 0; i < _indexes.length; i++) {
            vaultAddresses[i] = vaults[_indexes[i]];
        }

        return vaultAddresses;
    }

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
    ) {
        DataTypes.VaultConfigurationMap memory config = vaultConfiguration[
            _vault
        ].config;
        if (config.getProtocolFee() == DEFAULT_PROTOCOL_FEE) {
            config.setProtocolFee(protocolFee);
        }

        return (
            config.getMiddlewareStrategy(),
            config.getLimitMode(),
            config.getTimelockDuration(),
            config.getCreatorFee(),
            config.getHarvestFee(),
            config.getProtocolFee(),
            config.getBufferSize(),
            config.getBufferDerivation(),
            config.getLastHarvestIndex()
        );
    }

    /**
     * @notice Sets the deposit limits for user and vault.
     * @param _vault Vault address
     * @return _config Vault configuration Bitmap
     */
    function getVaultConfiguration(
        address _vault
    ) external view returns (DataTypes.VaultConfigurationMap memory) {
        DataTypes.VaultConfigurationMap memory config = vaultConfiguration[
            _vault
        ].config;
        if (config.getProtocolFee() == DEFAULT_PROTOCOL_FEE) {
            config.setProtocolFee(protocolFee);
        }
        return config;
    }

    /**
     * @notice Sets the deposit limits for user and vault.
     * @param _vault Vault address
     * @return _minUserDeposit Minimum user deposit
     * @return _maxUserDeposit Maximum user deposit
     * @return _minVaultDeposit Minimum vault deposit
     * @return _maxVaultDeposit Maximum vault deposit
     */
    function getVaultDepositLimits(
        address _vault
    )
        external
        view
        returns (
            uint256 _minUserDeposit,
            uint256 _maxUserDeposit,
            uint256 _minVaultDeposit,
            uint256 _maxVaultDeposit
        )
    {
        uint256 mode = vaultConfiguration[_vault].config.getLimitMode();
        _minVaultDeposit = vaultConfiguration[_vault].vaultMinDeposit;
        //No limit set
        if (mode != 0) {
            //Minimum limit set
            if (mode % 2 == 1)
                _minUserDeposit = vaultConfiguration[_vault].userMinDeposit;

            //Vault max limit set
            if (mode >= 4)
                _maxVaultDeposit = vaultConfiguration[_vault].vaultMaxDeposit;

            //User max limit set
            if (mode % 4 > 1)
                _maxUserDeposit = vaultConfiguration[_vault].userMaxDeposit;
        }
    }

    /**
     * @notice get the min deposit limits for a vault.
     * @param _vault Vault address
     * @return _minVaultDeposit Minimum vault deposit
     */
    function getVaultMinimalDepositLimits(
        address _vault
    ) external view returns (uint256) {
        return vaultConfiguration[_vault].vaultMinDeposit;
    }

    /**
     * @notice Check if an address is whitelisted on a vault
     * @param _vault Vault address
     * @return whitelisted Boolean returning if a user is whitelisted
     */
    function addressIsWhitelistedOnVault(
        address _vault,
        address _user
    ) external view returns (bool) {
        return vaultConfiguration[_vault].isWhitelisted[_user] || _user == addressProvider.userInteractions();
    }

    /**
     * @notice Get holding parameters for a vault
     * @param _vault Vault address
     * @return token Token to hold
     * @return amount Amount to hold
     */
    function getVaultHoldingParams(
        address _vault
    ) external view returns (address token, uint256 amount) {
        token = vaultConfiguration[_vault].holdToken;
        amount = vaultConfiguration[_vault].holdAmount;
    }

    /**
     *  ------------ Protocol fee part ------------
     */

    function _editVaultParams(
        address _vault,
        IMajoraVault.MajoraVaultSettings[] memory _settings,
        bytes[] memory _data
    ) internal {
        uint256 changesLength = _settings.length;
        for (uint i = 0; i < changesLength; i++) {
            if (_settings[i] == IMajoraVault.MajoraVaultSettings.TimelockParams) {
                (uint256 _duration) = abi.decode(
                    _data[i],
                    (uint256)
                );
                _setVaultTimelockParams(_vault, _duration);
            }

            if (_settings[i] == IMajoraVault.MajoraVaultSettings.DepositLimits) {
                (
                    uint256 _minUserDeposit,
                    uint256 _maxUserDeposit,
                    uint256 _minVaultDeposit,
                    uint256 _maxVaultDeposit
                ) = abi.decode(_data[i], (uint256, uint256, uint256, uint256));

                _setVaultDepositLimits(
                    _vault,
                    _minUserDeposit,
                    _maxUserDeposit,
                    _minVaultDeposit,
                    _maxVaultDeposit
                );
            }

            if (_settings[i] == IMajoraVault.MajoraVaultSettings.HoldingParams) {
                (address _token, uint256 _amount) = abi.decode(
                    _data[i],
                    (address, uint256)
                );
                _setVaultHoldingParams(_vault, _token, _amount);
            }

            if (_settings[i] == IMajoraVault.MajoraVaultSettings.EditWhitelist) {
                (bool _add, address addr) = abi.decode(
                    _data[i],
                    (bool, address)
                );

                _vaultWhitelist(_vault, _add, addr);
            }

            if (_settings[i] == IMajoraVault.MajoraVaultSettings.FeeParams) {
                (uint256 _creatorFees, uint256 _harvestFees) = abi.decode(
                    _data[i],
                    (uint256, uint256)
                );
                _setVaultFeeParams(_vault, _creatorFees, _harvestFees);
            }

            if (_settings[i] == IMajoraVault.MajoraVaultSettings.BufferParams) {
                (uint256 _bufferSize, uint256 _bufferDerivation) = abi.decode(
                    _data[i],
                    (uint256, uint256)
                );
                _setVaultBufferParams(_vault, _bufferSize, _bufferDerivation);
            }
        }
    }

    /**
     * @notice Set the protocol fee.
     * @param _fee The new protocol fee.
     */
    function setProtocolFee(uint256 _fee) external restricted {
        if(_fee > 2500) revert InvalidProtocolFee();
        protocolFee = _fee;
    }

    /**
     * @notice Sets the deposit limits for user and vault.
     * @param _vault Vault address
     * @param _fee The new vault protocol fee
     */
    function setVaultProtocolFee(
        address _vault,
        uint256 _fee
    ) external restricted isValidVault(_vault) {
        
        DataTypes.VaultConfigurationMap memory config = vaultConfiguration[
            _vault
        ].config;
        config.setProtocolFee(_fee);
        vaultConfiguration[_vault].config = config;
    }

    /**
     *  ------------ Vault configuration storage part ------------
     */

    /**
     * @notice Sets the deposit limits for user and vault.
     * @param _minUserDeposit Minimum user deposit
     * @param _maxUserDeposit Maximum user deposit
     * @param _minVaultDeposit Minimum vault deposit
     * @param _maxVaultDeposit Maximum vault deposit
     */
    function _setVaultDepositLimits(
        address _vault,
        uint256 _minUserDeposit,
        uint256 _maxUserDeposit,
        uint256 _minVaultDeposit,
        uint256 _maxVaultDeposit
    ) internal {
        uint256 mode = 0;

        DataTypes.VaultConfigurationMap memory c = vaultConfiguration[_vault]
            .config;

        vaultConfiguration[_vault].userMinDeposit = _minUserDeposit;
        vaultConfiguration[_vault].userMaxDeposit = _maxUserDeposit;
        vaultConfiguration[_vault].vaultMinDeposit = _minVaultDeposit;
        vaultConfiguration[_vault].vaultMaxDeposit = _maxVaultDeposit;

        if (_minUserDeposit > 0) mode += 1;
        if (_maxUserDeposit > 0) mode += 2;
        if (_maxVaultDeposit > 0) mode += 4;

        c.setLimitMode(mode);
        vaultConfiguration[_vault].config = c;

        emit NewDepositLimits(
            _vault,
            _minUserDeposit,
            _maxUserDeposit,
            _minVaultDeposit,
            _maxVaultDeposit
        );
    }

    function _vaultWhitelist(
        address _vault,
        bool _add,
        address _addr
    ) internal {
        vaultConfiguration[_vault].isWhitelisted[_addr] = _add;
        emit EditWhitelist(_vault, _add, _addr);
    }

    /**
     * @notice Sets the timelock parameters
     * @param _duration timelock duration after a deposit
     */
    function _setVaultTimelockParams(
        address _vault,
        uint256 _duration
    ) internal {
        DataTypes.VaultConfigurationMap memory c = vaultConfiguration[_vault]
            .config;
            
        c.setTimelockDuration(_duration);
        vaultConfiguration[_vault].config = c;

        emit NewTimelockParams(_vault, _duration);
    }

    /**
     * @notice Sets the buffer parameters
     * @param _bufferSize enable the timelock
     * @param _bufferDerivation timelock duration after a deposit
     */
    function _setVaultBufferParams(
        address _vault,
        uint256 _bufferSize,
        uint256 _bufferDerivation
    ) internal {
        if (
            _bufferSize > 9000 ||
            _bufferSize < 300 ||
            _bufferDerivation < 200 ||
            _bufferDerivation > 2000 ||
            _bufferSize < _bufferDerivation
        ) revert BadBufferParams();

        DataTypes.VaultConfigurationMap memory c = vaultConfiguration[_vault]
            .config;
        c.setBufferSize(_bufferSize);
        c.setBufferDerivation(_bufferDerivation);
        vaultConfiguration[_vault].config = c;

        emit NewBufferParams(_vault, _bufferSize, _bufferDerivation);
    }

    /**
     * @notice Sets the holding parameters for the token and amount.
     * @param _token Address of the token
     * @param _amount Amount of the token to be held
     */
    function _setVaultHoldingParams(
        address _vault,
        address _token,
        uint256 _amount
    ) internal {
        vaultConfiguration[_vault].holdToken = _token;
        vaultConfiguration[_vault].holdAmount = _amount;

        emit NewHoldingParams(_vault, _token, _amount);
    }

    /**
     * @notice Sets fees parameters
     * @param _creatorFees creator fees
     * @param _harvestFees tharvester fees
     */
    function _setVaultFeeParams(
        address _vault,
        uint256 _creatorFees,
        uint256 _harvestFees
    ) internal {
        DataTypes.VaultConfigurationMap memory c = vaultConfiguration[_vault]
            .config;
        c.setCreatorFee(_creatorFees);
        c.setHarvestFee(_harvestFees);
        vaultConfiguration[_vault].config = c;

        emit NewFeeParams(_vault, _creatorFees, _harvestFees);
    }

    /**
     * Queue related function
     */
    function _findLastItemQueueIndex(address _vault) internal view returns (uint256 currentItem) { 
        currentItem = QUEUE_GUARD;
        while(true) {
            if(nextQueueItem[_vault][currentItem] == 0)
                return currentItem;

            currentItem = nextQueueItem[_vault][currentItem];
        }
    }

    function _findChangeIndexByQueueIndex(address _vault, uint256 _index) internal view returns(uint256 currentItem) {
        currentItem = QUEUE_GUARD;
        for (uint i = 0; i < _index; i++) {
            currentItem = nextQueueItem[_vault][currentItem];
        }
    }

    function _addQueueItem(address _vault, VaultParametersEditQueueItem memory _item) internal returns (uint256) { 
        totalChangeLength[_vault] += 1;

        uint256 changeIndex = totalChangeLength[_vault];
        uint256 lastQueueIndex = _findLastItemQueueIndex(_vault);

        vaultParamsChanges[_vault][changeIndex] = _item;
        nextQueueItem[_vault][lastQueueIndex] = changeIndex;

        queueSize[_vault] += 1;
        return changeIndex;
    }

    function _removeQueueItem(address _vault, uint256 _index) internal {        
        uint256 prevQueueItem = _findChangeIndexByQueueIndex(_vault, _index - 1);
        nextQueueItem[_vault][prevQueueItem] = nextQueueItem[_vault][_index];
        nextQueueItem[_vault][_index] = uint256(0);
        queueSize[_vault] -= 1;
    }
}
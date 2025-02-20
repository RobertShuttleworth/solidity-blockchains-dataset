// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import {Ownable} from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import {VaultV5} from "./contracts_VaultV5.sol";
import {ERC20} from "./lib_solmate_src_tokens_ERC20.sol";
import {BaseModule} from "./contracts_modules_BaseModule.sol";
import {UniversalOracle} from "./contracts_oracles_UniversalOracle.sol";
import "./hardhat_console.sol";

contract CryptonergyManager is Ownable {
    // ============================================= State =============================================
    /**
     * @notice stores data related to Vault strategies.
     * @param module address of the module to use for this position
     * @param moduleData arbitrary data needed to correclty set up a position
     */
    struct StrategyData {
        address module;
        bytes moduleData;
    }
    /**
     * @notice The unique ID that the next registered contract will have.
     */
    uint256 public nextId;

    /**
     * @notice Get the address associated with an id.
     */
    mapping(uint256 => address) public getAddressById;

    /**
     * @notice Mapping stores whether or not a cellar is paused.
     */
    mapping(address => bool) public isVaultPaused;

    /**
     * @notice Maps an module address to bool indicating whether it has been set up in the CryptonergyManager.
     */
    mapping(address => bool) public isModuleTrusted;

    /**
     * @notice Maps an adaptors identfier to bool, to track if the identifier is unique wrt the CryptonergyManager.
     */
    mapping(bytes32 => bool) public isIdentifierUsed;

    /**
     * @notice Addresses of the positions currently used by the cellar.
     */
    uint256 public constant UNIVERSAL_ORACLE_STORAGE_SLOT = 1;

    /**
     * @notice Maps a strategy hash to a strategy Id.
     * @dev can be used by modules to verify that a certain strategy is open during Vault `callToModule` calls.
     */
    mapping(bytes32 => uint32) public getStrategyHashToStrategyId;

    /**
     * @notice Maps a strategies id to its strategy data.
     * @dev used by Vault when adding new strategies.
     */
    mapping(uint32 => StrategyData) public getStrategyIdToStrategyData;

    /**
     * @notice Maps a Strategy to a bool indicating whether or not it is trusted.
     */
    mapping(uint32 => bool) public isStrategyTrusted;

    // ============================================= Errors =============================================
    /**
     * @notice Attempted to set the address of a contract that is not registered.
     * @param id id of the contract that is not registered
     */
    error ContractNotRegistered(uint256 id);

    /**
     * @notice Attempted to unpause a Vault that was not paused.
     */
    error VaultNotPaused(address vault);

    /**
     * @notice Attempted to pause a Vault that was already paused.
     */
    error VaultAlreadyPaused(address vault);

    /**
     * @notice Attempted to trust an adaptor with non unique identifier.
     */
    error IdentifierNotUnique();

    /**
     * @notice Attempted to use an untrusted module.
     */
    error ModuleNotTrusted(address module);

    /**
     * @notice Attempted to trust an already trusted module.
     */
    error ModuleAlreadyTrusted(address module);
    /**
     * @notice Attempted to trust a position not being used.
     * @param position address of the invalid position
     */
    error StrategyPricingNotSetUp(address position);

    /**
     * @notice Attempted to add a strategy with bad input values.
     */
    error InvalidStrategyInput();

    /**
     * @notice Attempted to add a strategy that does not exist.
     */
    error StrategyDoesNotExist();

    /**
     * @notice Attempted to add a strategy that is not trusted.
     */
    error StrategyIsNotTrusted(uint32 position);

    // ============================================= Events =============================================
    /**
     * @notice Emitted when the address of a contract is changed.
     * @param id value representing the unique ID tied to the changed contract
     * @param oldAddress address of the contract before the change
     * @param newAddress address of the contract after the contract
     */
    event AddressChanged(
        uint256 indexed id,
        address oldAddress,
        address newAddress
    );

    /**
     * @notice Emitted when depositor privilege changes.
     * @param depositor depositor address
     * @param state the new state of the depositor privilege
     */
    event DepositorOnBehalfChanged(address depositor, bool state);

    /**
     * @notice Emitted when a new contract is registered.
     * @param id value representing the unique ID tied to the new contract
     * @param newContract address of the new contract
     */
    event Registered(uint256 indexed id, address indexed newContract);

    /**
     * @notice Emitted when a vault is paused.
     */
    event VaultPaused(address target);

    /**
     * @notice Emitted when a target is unpaused.
     */
    event VaultUnpaused(address target);

    /**
     * @notice Emitted when a new position is added to the registry.
     * @param id the positions id
     * @param adaptor address of the adaptor this position uses
     * @param adaptorData arbitrary bytes used to configure this position
     */
    event StrategyTrusted(uint32 id, address adaptor, bytes adaptorData);

    /**
     * @notice Emitted when a position is distrusted.
     * @param id the positions id
     */
    event StrategyDistrusted(uint32 id);

    // ============================================= Constructor =============================================

    /**
     * @param swapRouter address of SwapRouter contract
     * @param universalOracle address of UniversalOracle contract
     */
    constructor(
        address newOwner,
        address swapRouter,
        address universalOracle
    ) Ownable(newOwner) {
        _register(swapRouter);
        _register(universalOracle);
        transferOwnership(newOwner);
    }

    // ============================================= External functions =============================================

    /**
     * @notice Set the address of the contract at a given id.
     */
    function setAddress(uint256 id, address newAddress) external onlyOwner {
        if (id >= nextId) revert ContractNotRegistered(id);

        emit AddressChanged(id, getAddressById[id], newAddress);

        getAddressById[id] = newAddress;
    }

    /**
     * @notice Register the address of a new contract.
     * @param newContract address of the new contract to register
     */
    function register(address newContract) external onlyOwner {
        _register(newContract);
    }

    /**
     * @notice Allows multisig to pause multiple cellars in a single call.
     */
    function batchPause(address[] calldata targets) external onlyOwner {
        for (uint256 i; i < targets.length; ++i) _pauseTarget(targets[i]);
    }

    /**
     * @notice Allows multisig to unpause multiple cellars in a single call.
     */
    function batchUnpause(address[] calldata targets) external onlyOwner {
        for (uint256 i; i < targets.length; ++i) _unpauseTarget(targets[i]);
    }

    /**
     * @notice Trust an module to be used by Vaults
     * @param module address of the adaptor to trust
     */
    function trustModule(address module) external onlyOwner {
        if (isModuleTrusted[module]) revert ModuleAlreadyTrusted(module);
        bytes32 identifier = BaseModule(module).moduleId();
        if (isIdentifierUsed[identifier]) revert IdentifierNotUnique();
        isModuleTrusted[module] = true;
        isIdentifierUsed[identifier] = true;
    }

    /**
     * @notice Allows registry to distrust adaptors.
     * @dev Doing so prevents Cellars from adding this adaptor to their catalogue.
     */
    function distrustModule(address module) external onlyOwner {
        if (!isModuleTrusted[module]) revert ModuleNotTrusted(module);
        // Set trust to false.
        isModuleTrusted[module] = false;

        // We are NOT resetting `isIdentifierUsed` because if this adaptor is distrusted, then something needs
        // to change about the new one being re-trusted.
    }

    /**
     * @notice Trust a position to be used by the Vault.
     * @param strategyId the position id of the newly added strategy
     * @param module the module address this strategy uses
     * @param moduleData arbitrary bytes used to configure this position
     */
    function trustStrategy(
        uint32 strategyId,
        address module,
        bytes memory moduleData
    ) external onlyOwner {
        bytes32 identifier = BaseModule(module).moduleId();
        bytes32 positionHash = keccak256(abi.encode(identifier, moduleData));

        if (strategyId == 0) revert InvalidStrategyInput();
        // Make sure positionId is not already in use.
        StrategyData storage pData = getStrategyIdToStrategyData[strategyId];
        if (pData.module != address(0)) revert InvalidStrategyInput();

        // Check that...
        // `adaptor` is a non zero address
        // position has not been already set up
        if (
            module == address(0) ||
            getStrategyHashToStrategyId[positionHash] != 0
        ) revert InvalidStrategyInput();

        if (!isModuleTrusted[module]) revert ModuleNotTrusted(module);

        // Set position data.
        pData.module = module;
        pData.moduleData = moduleData;

        // Globally trust the position.
        isStrategyTrusted[strategyId] = true;

        getStrategyHashToStrategyId[positionHash] = strategyId;

        // Check that assets position uses are supported for pricing operations.
        ERC20[] memory assets = BaseModule(module).assetsUsed(moduleData);
        UniversalOracle priceRouter = UniversalOracle(
            getAddressById[UNIVERSAL_ORACLE_STORAGE_SLOT]
        );
        for (uint256 i; i < assets.length; i++) {
            if (!priceRouter.isSupported(assets[i]))
                revert StrategyPricingNotSetUp(address(assets[i]));
        }

        emit StrategyTrusted(strategyId, module, moduleData);
    }

    /**
     * @notice Allows registry to distrust positions.
     * @dev Doing so prevents Cellars from adding this position to their catalogue,
     *      and adding the position to their tracked arrays.
     */
    function distrustStrategy(uint32 positionId) external onlyOwner {
        if (!isStrategyTrusted[positionId])
            revert StrategyIsNotTrusted(positionId);
        isStrategyTrusted[positionId] = false;
        emit StrategyDistrusted(positionId);
    }

    // ============================================= Internal functions =============================================

    function _register(address newContract) internal {
        getAddressById[nextId] = newContract;

        emit Registered(nextId, newContract);

        nextId++;
    }

    /**
     * @notice Helper function to pause some target.
     */
    function _pauseTarget(address target) internal {
        if (isVaultPaused[target]) revert VaultAlreadyPaused(target);
        isVaultPaused[target] = true;
        emit VaultPaused(target);
    }

    /**
     * @notice Helper function to unpause some target.
     */
    function _unpauseTarget(address target) internal {
        if (!isVaultPaused[target]) revert VaultNotPaused(target);
        isVaultPaused[target] = false;
        emit VaultUnpaused(target);
    }

    // ============================================ View functions ============================================
    /**
     * @notice Reverts if `adaptor` is not trusted by the registry.
     */
    function revertIfModuleIsNotTrusted(address module) external view {
        if (!isModuleTrusted[module]) revert ModuleNotTrusted(module);
    }

    /**
     * @notice Called by Cellars to add a new position to themselves.
     * @param strategyId the id of the position the cellar wants to add
     * @return adaptor the address of the adaptor, isDebt bool indicating whether position is
     *         debt or not, and adaptorData needed to interact with position
     */
    function addStrategyToVault(
        uint32 strategyId
    ) external view returns (address adaptor, bytes memory adaptorData) {
        if (strategyId == 0) revert StrategyDoesNotExist();
        StrategyData memory positionData = getStrategyIdToStrategyData[
            strategyId
        ];
        if (positionData.module == address(0)) revert StrategyDoesNotExist();

        revertIfStrategyIsNotTrusted(strategyId);

        return (positionData.module, positionData.moduleData);
    }

    /**
     * @notice Reverts if `positionId` is not trusted by the registry.
     */
    function revertIfStrategyIsNotTrusted(uint32 positionId) public view {
        if (!isStrategyTrusted[positionId])
            revert StrategyIsNotTrusted(positionId);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


/**
 * @title IMajoraAddressesProvider
 * @author Majora Development Association
 * @notice Interface for the Majora Addresses Provider.
 * @dev Provides methods for managing addresses used by the Majora platform.
 */
interface IMajoraAddressesProvider {

    /**
     * @dev Emitted when the treasury address is changed.
     * @param newAddress The new treasury address.
     */
    event TreasuryChanged(address newAddress); 

    /**
     * @dev Emitted when the fee collector address is changed.
     * @param newAddress The new fee collector address.
     */
    event FeeCollectorChanged(address newAddress); 

    /**
     * @dev Emitted when the SOPT address is changed.
     * @param newAddress The new SOPT address.
     */
    event MoptChanged(address newAddress); 

    /**
     * @dev Emitted when the vault factory address is changed.
     * @param newAddress The new vault factory address.
     */
    event VaultFactoryChanged(address newAddress); 

    /**
     * @dev Emitted when the block registry address is changed.
     * @param newAddress The new block registry address.
     */
    event BlockRegistryChanged(address newAddress); 

    /**
     * @dev Emitted when the position manager factory address is changed.
     * @param newAddress The new position manager factory address.
     */
    event PositionManagerFactoryChanged(address newAddress); 

    /**
     * @dev Emitted when the user interactions address is changed.
     * @param newAddress The new user interactions address.
     */
    event UserInteractionsChanged(address newAddress); 

    /**
     * @dev Emitted when the operator proxy address is changed.
     * @param newAddress The new operator proxy address.
     */
    event OperatorProxyChanged(address newAddress); 

    /**
     * @dev Emitted when the operator data aggregator address is changed.
     * @param newAddress The new operator data aggregator address.
     */
    event OperatorDataAggregatorChanged(address newAddress); 

    /**
     * @dev Emitted when the portal address is changed.
     * @param newAddress The new portal address.
     */
    event PortalChanged(address newAddress); 

    /**
     * @dev Emitted when the Permit2 address is changed.
     * @param newAddress The new Permit2 address.
     */
    event Permit2Changed(address newAddress); 

    /**
     * @notice Get the address of the Access Manager.
     * @return address The address of the Access Manager.
     */
    function accessManager() external view returns (address);

    /**
     * @notice Get the address of the Treasury.
     * @return address The address of the Treasury.
     */
    function treasury() external view returns (address);

    /**
     * @notice Get the address of the Fee Collector.
     * @return address The address of the Fee Collector.
     */
    function feeCollector() external view returns (address);

    /**
     * @notice Get the address of the MOPT.
     * @return address The address of the MOPT.
     */
    function mopt() external view returns (address);

    /**
     * @notice Get the address of the Vault Factory.
     * @return address The address of the Vault Factory.
     */
    function vaultFactory() external view returns (address);

    /**
     * @notice Get the address of the Block Registry.
     * @return address The address of the Block Registry.
     */
    function blockRegistry() external view returns (address);

    /**
     * @notice Get the address of the Position Manager Factory.
     * @return address The address of the Position Manager Factory.
     */
    function positionManagerFactory() external view returns (address);

    /**
     * @notice Get the address of the User Interactions.
     * @return address The address of the User Interactions.
     */
    function userInteractions() external view returns (address);

    /**
     * @notice Get the address of the Operator Proxy.
     * @return address The address of the Operator Proxy.
     */
    function operatorProxy() external view returns (address);

    /**
     * @notice Get the address of the Operator Data Aggregator.
     * @return address The address of the Operator Data Aggregator.
     */
    function operatorDataAggregator() external view returns (address);

    /**
     * @notice Get the address of the Portal.
     * @return address The address of the Portal.
     */
    function portal() external view returns (address);

    /**
     * @notice Get the address of the Permit2.
     * @return address The address of the Permit2.
     */
    function permit2() external view returns (address);

    /**
     * @notice Set the address of the Treasury.
     * @param _treasury The new address for the Treasury.
     */
    function setTreasury(address _treasury) external;

    /**
     * @notice Set the address of the Fee Collector.
     * @param _feeCollector The new address for the Fee Collector.
     */
    function setFeeCollector(address _feeCollector) external;

    /**
     * @notice Set the address of the SOPT.
     * @param _mopt The new address for the SOPT.
     */
    function setMopt(address _mopt) external;

    /**
     * @notice Set the address of the Vault Factory.
     * @param _vaultFactory The new address for the Vault Factory.
     */
    function setVaultFactory(address _vaultFactory) external;

    /**
     * @notice Set the address of the Block Registry.
     * @param _blockRegistry The new address for the Block Registry.
     */
    function setBlockRegistry(address _blockRegistry) external;

    /**
     * @notice Set the address of the Position Manager Factory.
     * @param _positionManagerFactory The new address for the Position Manager Factory.
     */
    function setPositionManagerFactory(address _positionManagerFactory) external;

    /**
     * @notice Set the address of the User Interactions.
     * @param _userInteraction The new address for the User Interactions.
     */
    function setUserInteractions(address _userInteraction) external;

    /**
     * @notice Set the address of the Operator Proxy.
     * @param _operatorProxy The new address for the Operator Proxy.
     */
    function setOperatorProxy(address _operatorProxy) external;

    /**
     * @notice Set the address of the Operator Data Aggregator.
     * @param _operatorDataAggregator The new address for the Operator Data Aggregator.
     */
    function setOperatorDataAggregator(address _operatorDataAggregator) external;

    /**
     * @notice Set the address of the Portal.
     * @param _portal The new address for the Portal.
     */
    function setPortal(address _portal) external;

    /**
     * @notice Set the address of the Permit2.
     * @param _permit2 The new address for the Permit2.
     */
    function setPermit2(address _permit2) external;

    /**
     * @notice Get the addresses of all components.
     * @return _treasury The address of the Treasury.
     * @return _feeCollector The address of the Fee Collector.
     * @return _mopt The address of the SOPT.
     * @return _vaultFactory The address of the Vault Factory.
     * @return _blockRegistry The address of the Block Registry.
     * @return _positionManagerFactory The address of the Position Manager Factory.
     * @return _userInteractions The address of the User Interactions.
     * @return _operatorProxy The address of the Operator Proxy.
     * @return _operatorDataAggregator The address of the Operator Data Aggregator.
     * @return _portal The address of the Portal.
     * @return _permit2 The address of the Permit2.
     * @return _accessManager The address of the Access Manager.
     */
    function getAddresses() 
        external 
        view 
        returns (
            address _treasury,
            address _feeCollector,
            address _mopt,
            address _vaultFactory,
            address _blockRegistry,
            address _positionManagerFactory,
            address _userInteractions,
            address _operatorProxy,
            address _operatorDataAggregator,
            address _portal,
            address _permit2,
            address _accessManager
        );
}
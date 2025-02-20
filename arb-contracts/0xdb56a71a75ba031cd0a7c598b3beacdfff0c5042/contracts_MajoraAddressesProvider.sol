// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_manager_AccessManaged.sol";
import "./openzeppelin_contracts_utils_Multicall.sol";
import "./contracts_interfaces_IMajoraAddressesProvider.sol";

/**
 * @title MajoraAddressesProvider
 * @author Majora Development Association
 * @notice A Solidity smart contract extending ERC20 with additional features for payment allowances and execution.
 * @dev This contract allows users to set an operator proxy, approve allowances for specific infrastructure operations, and execute payments with a configurable payment fee.
 */
contract MajoraAddressesProvider is AccessManaged, Multicall, IMajoraAddressesProvider {

    /**
     * @notice Address of the treasury.
     */
    address public treasury;

    /**
     * @notice Address of the fee collector.
     */
    address public feeCollector;

    /**
     * @notice Address of the SOPT.
     */
    address public mopt;

    /**
     * @notice Address of the vault factory.
     */
    address public vaultFactory;

    /**
     * @notice Address of the block registry.
     */
    address public blockRegistry;

    /**
     * @notice Address of the position manager factory.
     */
    address public positionManagerFactory;

    /**
     * @notice Address of the user interactions.
     */
    address public userInteractions;

    /**
     * @notice Address of the operator proxy.
     */
    address public operatorProxy;

    /**
     * @notice Address of the operator data aggregator.
     */
    address public dataAggregator;

    /**
     * @notice Address of the portal.
     */
    address public portal;

    /**
     * @notice Address of the Permit2.
     */
    address public permit2;

    constructor(address _accessManager) AccessManaged(_accessManager) {}

    /**
     * @notice Returns the address of the Access Manager.
     * @return The address of the Access Manager.
     */
    function accessManager() external view returns (address) {
        return authority();
    }

    /**
     * @notice Sets the treasury address.
     * @param _treasury The new treasury address.
     */
    function setTreasury(address _treasury) external restricted {
        treasury = _treasury;
        emit TreasuryChanged(_treasury);
    }

    /**
     * @notice Sets the fee collector address.
     * @param _feeCollector The new fee collector address.
     */
    function setFeeCollector(address _feeCollector) external restricted {
        feeCollector = _feeCollector;
        emit FeeCollectorChanged(_feeCollector);
    }

    /**
     * @notice Sets the MOPT address.
     * @param _mopt The new SOPT address.
     */
    function setMopt(address _mopt) external restricted {
        mopt = _mopt;
        emit MoptChanged(_mopt);
    }

    /**
     * @notice Sets the vault factory address.
     * @param _vaultFactory The new vault factory address.
     */
    function setVaultFactory(address _vaultFactory) external restricted {
        vaultFactory = _vaultFactory;
        emit VaultFactoryChanged(_vaultFactory);
    }

    /**
     * @notice Sets the block registry address.
     * @param _blockRegistry The new block registry address.
     */
    function setBlockRegistry(address _blockRegistry) external restricted {
        blockRegistry = _blockRegistry;
        emit BlockRegistryChanged(_blockRegistry);
    }

    /**
     * @notice Sets the position manager factory address.
     * @param _positionManagerFactory The new position manager factory address.
     */
    function setPositionManagerFactory(address _positionManagerFactory) external restricted {
        positionManagerFactory = _positionManagerFactory;
        emit PositionManagerFactoryChanged(_positionManagerFactory);
    }

    /**
     * @notice Sets the user interactions address.
     * @param _userInteractions The new user interactions address.
     */
    function setUserInteractions(address _userInteractions) external restricted {
        userInteractions = _userInteractions;
        emit UserInteractionsChanged(_userInteractions);
    }

    /**
     * @notice Sets the operator proxy address.
     * @param _operatorProxy The new operator proxy address.
     */
    function setOperatorProxy(address _operatorProxy) external restricted {
        operatorProxy = _operatorProxy;
        emit OperatorProxyChanged(_operatorProxy);
    }

    /**
     * @notice Sets the operator data aggregator address.
     * @param _dataAggregator The new operator data aggregator address.
     */
    function setDataAggregator(address _dataAggregator) external restricted {
        dataAggregator = _dataAggregator;
        emit DataAggregatorChanged(_dataAggregator);
    }

    /**
     * @notice Sets the portal address.
     * @param _portal The new portal address.
     */
    function setPortal(address _portal) external restricted {
        portal = _portal;
        emit PortalChanged(_portal);
    }

    /**
     * @notice Sets the Permit2 address.
     * @param _permit2 The new Permit2 address.
     */
    function setPermit2(address _permit2) external restricted {
        permit2 = _permit2;
        emit Permit2Changed(_permit2);
    }

    /**
     * @notice Returns the addresses of all components.
     * @return _treasury The address of the Treasury.
     * @return _feeCollector The address of the Fee Collector.
     * @return _mopt The address of the SOPT.
     * @return _vaultFactory The address of the Vault Factory.
     * @return _blockRegistry The address of the Block Registry.
     * @return _positionManagerFactory The address of the Position Manager Factory.
     * @return _userInteractions The address of the User Interactions.
     * @return _operatorProxy The address of the Operator Proxy.
     * @return _dataAggregator The address of the Operator Data Aggregator.
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
            address _dataAggregator,
            address _portal,
            address _permit2,
            address _accessManager
        ) {
            _treasury = treasury;
            _feeCollector = feeCollector;
            _mopt = mopt;
            _vaultFactory = vaultFactory;
            _blockRegistry = blockRegistry;
            _positionManagerFactory = positionManagerFactory;
            _userInteractions = userInteractions;
            _operatorProxy = operatorProxy;
            _dataAggregator = dataAggregator;
            _portal = portal;
            _permit2 = permit2;
            _accessManager = authority();
        }
}
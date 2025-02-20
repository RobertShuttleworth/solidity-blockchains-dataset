// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {OwnableUpgradeable} from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import {Create2} from "./openzeppelin_contracts_utils_Create2.sol";
import {ERC1967Proxy} from "./openzeppelin_contracts_proxy_ERC1967_ERC1967Proxy.sol";
import {EnumerableSet} from "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";

/// @title Odyssey positions' registry
/// @notice Allow users to deploy new positions from a set of strategies
contract PositionRegistry is OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Emitted when a strategy is added
    event StrategyAdded(uint256 indexed strategyId, address indexed implementation, address indexed feePolicy);

    /// @notice Emitted when a position is deployed
    event PositionDeployed(address indexed owner, uint256 indexed strategyId, address indexed position);

    /// @notice Emitted when the strategy's fee policy is updated
    event FeePolicyUpdated(uint256 indexed strategyId, address newFeePolicy);

    /// @notice Emitted when the strategy's implementation is updated
    event ImplementationUpdated(uint256 indexed strategyId, address newImplementation);

    /// @notice Emitted when the strategy's active flag is updated
    event IsActiveUpdated(uint256 indexed strategyId, bool isActive);

    /// @notice Emitted when the fee collector is updated
    event FeeCollectorUpdated(address indexed oldFeeCollector, address indexed newFeeCollector);

    /// @notice Emitted when the position's owner is updated
    event PositionOwnerUpdated(address indexed position, address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when a keeper is added
    event KeeperAdded(address indexed keeper);

    /// @notice Emitted when a keeper is removed
    event KeeperRemoved(address indexed keeper);

    error AddressIsNull();
    error StrategyAlreadyExists();
    error StrategyDoesNotExist();
    error StrategyIsNotActive();
    error SenderIsNotAValidPosition();
    error PositionAlreadyCreated(address position);
    error CouldNotSetNewOwner();
    error CouldNotUnsetCurrentOwner();
    error CouldNotAddNewPosition();
    error CouldNotAddKeeper();
    error CouldNotRemoveKeeper();
    error ImplementationAlreadyExists(uint256 at);
    error ImplementationDoesNotExist();

    struct Strategy {
        address[] implementations;
        address feePolicy;
        bool isActive;
    }

    /// @custom:storage-location erc7201:odyssey.storage.PositionRegistry
    struct PositionRegistryStorage {
        address _feeCollector;
        uint256 _nextStrategyId;
        mapping(address latestImplementation => mapping(address feePolicy => uint256 strategyId)) _strategyIds;
        mapping(uint256 strategyId => Strategy strategy) _strategies;
        mapping(uint256 strategyId => mapping(address implementation => uint256 index)) _implementationIndexes;
        EnumerableSet.AddressSet _positions;
        mapping(address owner => EnumerableSet.AddressSet positions) _positionsOf;
        EnumerableSet.AddressSet _keepers;
    }

    bytes32 private constant PositionRegistryStorageLocation =
        keccak256(abi.encode(uint256(keccak256("odyssey.storage.PositionRegistry")) - 1)) & ~bytes32(uint256(0xff));

    function _getPositionRegistryStorage() private pure returns (PositionRegistryStorage storage $) {
        bytes32 location = PositionRegistryStorageLocation;
        assembly {
            $.slot := location
        }
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner_, address feeCollector_) external initializer {
        if (address(owner_) == address(0)) revert AddressIsNull();
        if (address(feeCollector_) == address(0)) revert AddressIsNull();

        __Ownable_init_unchained(owner_);

        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        $._nextStrategyId = 1;
        $._feeCollector = feeCollector_;
    }

    /// @notice Add new strategy to the set
    /// @param implementation_ The strategy implementation
    /// @param feePolicy_ The fee policy
    function addStrategy(address implementation_, address feePolicy_) external onlyOwner returns (uint256 _strategyId) {
        if (implementation_ == address(0)) revert AddressIsNull();
        if (feePolicy_ == address(0)) revert AddressIsNull();
        if (strategyExists(implementation_, feePolicy_)) revert StrategyAlreadyExists();

        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        _strategyId = $._nextStrategyId++;
        $._strategies[_strategyId] = Strategy({
            feePolicy: feePolicy_,
            isActive: true,
            implementations: new address[](0)
        });
        $._strategies[_strategyId].implementations.push(implementation_);
        $._strategyIds[implementation_][feePolicy_] = _strategyId;

        emit StrategyAdded(_strategyId, implementation_, feePolicy_);
    }

    /// @notice Deploy new position
    /// @param owner_ The position's owner (i.e. smart account)
    /// @param strategyId_ The strategy's id
    /// @param salt_ The create2 salt (allows user to have many positions for the same strategy)
    function deployPosition(address owner_, uint256 strategyId_, uint256 salt_) external returns (address _position) {
        if (owner_ == address(0)) revert AddressIsNull();
        if (!isStrategyActive(strategyId_)) revert StrategyIsNotActive();

        _position = getPositionAddress(owner_, strategyId_, salt_);
        if (_position.code.length > 0) revert PositionAlreadyCreated(_position);

        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        if (!$._positions.add(_position)) revert CouldNotAddNewPosition();
        if (!$._positionsOf[owner_].add(_position)) revert CouldNotSetNewOwner();

        new ERC1967Proxy{salt: bytes32(salt_)}(
            implementationOf(strategyId_),
            abi.encodeWithSignature("initialize(uint256,address,address)", strategyId_, owner_, address(this))
        );

        emit PositionDeployed(owner_, strategyId_, _position);
    }

    /// @notice Get position's deterministic address
    /// @param owner_ The position's owner (i.e. smart account)
    /// @param strategyId_ The strategy's id
    /// @param salt_ The create2 salt (allows user to have many positions for the same strategy)
    /// @return The deterministic address for the position params
    function getPositionAddress(address owner_, uint256 strategyId_, uint256 salt_) public view returns (address) {
        return
            Create2.computeAddress(
                bytes32(salt_),
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            implementationOf(strategyId_),
                            abi.encodeWithSignature(
                                "initialize(uint256,address,address)",
                                strategyId_,
                                owner_,
                                address(this)
                            )
                        )
                    )
                )
            );
    }

    /// @notice Get the strategy's fee policy
    /// @param strategyId_ The strategy's id
    /// @return The fee policy's contract
    function feePolicyOf(uint256 strategyId_) external view returns (address) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        return $._strategies[strategyId_].feePolicy;
    }

    /// @notice Get the strategy's implementation versions
    /// @param strategyId_ The strategy's id
    /// @return All the strategy's implementation versions
    function implementationsOf(uint256 strategyId_) external view returns (address[] memory) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        return $._strategies[strategyId_].implementations;
    }

    /// @notice Get the strategy's latest implementation
    /// @param strategyId_ The strategy's id
    /// @return The latest strategy's implementation
    function implementationOf(uint256 strategyId_) public view returns (address) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        address[] memory _implementations = $._strategies[strategyId_].implementations;
        return _implementations[_implementations.length - 1];
    }

    /// @notice Get the implementation's index
    /// @param strategyId_ The strategy's id
    /// @param implementation_ A strategy's implementation contract
    /// @return _index The implementation's versions array index (where `index == length - 1` is the latest version)
    function implementationIndexOf(
        uint256 strategyId_,
        address implementation_
    ) external view returns (uint256 _index) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        Strategy memory _strategy = $._strategies[strategyId_];

        if (_strategy.implementations.length == 0) revert StrategyDoesNotExist();

        _index = $._implementationIndexes[strategyId_][implementation_];

        if (_strategy.implementations[_index] != implementation_) revert ImplementationDoesNotExist();
    }

    /// @notice Get the positions of an account
    /// @dev This function is gas-intensive and should be used off-chain only
    /// @param account_ The position(s) owner
    /// @return The account's positions
    function positionsOf(address account_) external view returns (address[] memory) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        return $._positionsOf[account_].values();
    }

    /// @notice Get all positions
    /// @dev This function is gas-intensive and should be used off-chain only
    /// @return All the positions
    function getPositions() external view returns (address[] memory) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        return $._positions.values();
    }

    /// @notice Get fee collector
    /// @return _feeCollector The fee collector
    function feeCollector() public view returns (address _feeCollector) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        return $._feeCollector;
    }

    /// @notice Check if a position exists
    /// @return `true` if the address is a valid position
    function positionExists(address position_) public view returns (bool) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        return $._positions.contains(position_);
    }

    /// @notice Check if a strategy is active
    /// @param strategyId_ The strategy's id
    /// @return `true` if the strategy is active
    function isStrategyActive(uint256 strategyId_) public view returns (bool) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        return $._strategies[strategyId_].isActive;
    }

    /// @notice Check if a strategy exists
    /// @param implementation_ The strategy's implementation contract
    /// @param feePolicy_ The fee policy contract
    /// @return `true` if there is a `implementation:feePolicy` strategy pair
    function strategyExists(address implementation_, address feePolicy_) public view returns (bool) {
        return getStrategyId(implementation_, feePolicy_) != 0;
    }

    /// @notice Get strategy's id
    /// @param implementation_ The strategy's implementation contract
    /// @param feePolicy_ The fee policy
    /// @return The strategy's id
    function getStrategyId(address implementation_, address feePolicy_) public view returns (uint256) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        return $._strategyIds[implementation_][feePolicy_];
    }

    /// @notice Get all keepers
    /// @return All keepers
    function getKeepers() external view returns (address[] memory) {
        return _getPositionRegistryStorage()._keepers.values();
    }

    /// @notice Check if an address is a keeper
    /// @param keeper_ The keeper address
    /// @return `true` if the address is a keeper
    function isKeeper(address keeper_) external view returns (bool) {
        return _getPositionRegistryStorage()._keepers.contains(keeper_);
    }

    /// @notice Check if a strategy exists
    /// @param strategyId_ The strategy's id
    /// @return `true` if the id corresponds to a valid strategy
    function strategyExists(uint256 strategyId_) public view returns (bool) {
        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        return $._strategies[strategyId_].feePolicy != address(0);
    }

    /// @notice Update a position's owner
    /// @dev This function is called from the position itself and can be only initiated by the owner
    function updateOwnerOf(address owner_, address newOwner_) external {
        if (owner_ == address(0) || newOwner_ == address(0)) revert AddressIsNull();
        address _position = msg.sender;
        if (!positionExists(_position)) revert SenderIsNotAValidPosition();

        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        if (!$._positionsOf[owner_].remove(_position)) revert CouldNotUnsetCurrentOwner();
        if (!$._positionsOf[newOwner_].add(_position)) revert CouldNotSetNewOwner();

        emit PositionOwnerUpdated(_position, owner_, newOwner_);
    }

    /// @notice Add a keeper
    function addKeeper(address keeper_) external onlyOwner {
        if (keeper_ == address(0)) revert AddressIsNull();

        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        if (!$._keepers.add(keeper_)) revert CouldNotAddKeeper();

        emit KeeperAdded(keeper_);
    }

    /// @notice Remove a keeper
    function removeKeeper(address keeper_) external onlyOwner {
        if (keeper_ == address(0)) revert AddressIsNull();

        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        if (!$._keepers.remove(keeper_)) revert CouldNotRemoveKeeper();

        emit KeeperRemoved(keeper_);
    }

    /// @notice Update a strategy's fee policy
    function updateFeePolicy(uint256 strategyId_, address newFeePolicy_) external onlyOwner {
        if (!isStrategyActive(strategyId_)) revert StrategyIsNotActive();
        if (newFeePolicy_ == address(0)) revert AddressIsNull();

        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        address _currentImpl = implementationOf(strategyId_);
        address _currentFeePolicy = $._strategies[strategyId_].feePolicy;

        if (strategyExists(_currentImpl, newFeePolicy_)) revert StrategyAlreadyExists();

        $._strategies[strategyId_].feePolicy = newFeePolicy_;
        $._strategyIds[_currentImpl][newFeePolicy_] = strategyId_;
        delete $._strategyIds[_currentImpl][_currentFeePolicy];

        emit FeePolicyUpdated(strategyId_, newFeePolicy_);
    }

    /// @notice Update a strategy's implementation
    function updateImplementation(uint256 strategyId_, address newImplementation_) external onlyOwner {
        if (!strategyExists(strategyId_)) revert StrategyDoesNotExist();
        if (newImplementation_ == address(0)) revert AddressIsNull();

        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        Strategy memory _strategy = $._strategies[strategyId_];
        uint256 _length = _strategy.implementations.length;

        for (uint256 i; i < _length; ++i) {
            if (newImplementation_ == _strategy.implementations[i]) revert ImplementationAlreadyExists(i);
        }

        address _currentFeePolicy = _strategy.feePolicy;

        if (strategyExists(newImplementation_, _currentFeePolicy)) revert StrategyAlreadyExists();

        $._strategies[strategyId_].implementations.push(newImplementation_);
        $._implementationIndexes[strategyId_][newImplementation_] = _length;
        $._strategyIds[newImplementation_][_currentFeePolicy] = strategyId_;

        address _currentImpl = _strategy.implementations[_length - 1];
        delete $._strategyIds[_currentImpl][_currentFeePolicy];

        emit ImplementationUpdated(strategyId_, newImplementation_);
    }

    /// @notice Update active flag for a strategy
    function updateIsActive(uint256 strategyId_, bool isActive_) external onlyOwner {
        if (!strategyExists(strategyId_)) revert StrategyDoesNotExist();

        PositionRegistryStorage storage $ = _getPositionRegistryStorage();

        $._strategies[strategyId_].isActive = isActive_;

        emit IsActiveUpdated(strategyId_, isActive_);
    }

    /// @notice Update fee collector
    function updateFeeCollector(address newFeeCollector_) external onlyOwner {
        if (newFeeCollector_ == address(0)) revert AddressIsNull();

        PositionRegistryStorage storage $ = _getPositionRegistryStorage();
        address _current = $._feeCollector;
        $._feeCollector = newFeeCollector_;

        emit FeeCollectorUpdated(_current, newFeeCollector_);
    }
}
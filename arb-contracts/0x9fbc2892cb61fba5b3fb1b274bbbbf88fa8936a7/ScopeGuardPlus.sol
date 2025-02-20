// SPDX-License-Identifier: MIXED

// Sources flattened with hardhat v2.6.4 https://hardhat.org

// File @gnosis.pm/safe-contracts/contracts/common/Enum.sol@v1.3.0

// License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/// @title Enum - Collection of enums
/// @author Richard Meissner - <richard@gnosis.pm>
contract Enum {
    enum Operation {Call, DelegateCall}
}


// File @gnosis.pm/safe-contracts/contracts/interfaces/IERC165.sol@v1.3.0

// License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/// @notice More details at https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/introspection/IERC165.sol
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File @gnosis.pm/zodiac/contracts/interfaces/IGuard.sol@v1.0.1

// License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

interface IGuard {
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address msgSender
    ) external;

    function checkAfterExecution(bytes32 txHash, bool success) external;
}


// File @gnosis.pm/zodiac/contracts/guard/BaseGuard.sol@v1.0.1

// License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;



abstract contract BaseGuard is IERC165 {
    function supportsInterface(bytes4 interfaceId)
        external
        pure
        override
        returns (bool)
    {
        return
            interfaceId == type(IGuard).interfaceId || // 0xe6d7a83a
            interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
    }

    /// Module transactions only use the first four parameters: to, value, data, and operation.
    /// Module.sol hardcodes the remaining parameters as 0 since they are not used for module transactions.
    /// This interface is used to maintain compatibilty with Gnosis Safe transaction guards.
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures,
        address msgSender
    ) external virtual;

    function checkAfterExecution(bytes32 txHash, bool success) external virtual;
}


// File @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol@v4.3.1

// License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since a proxied contract can't have a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        require(_initializing || !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }
}


// File @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol@v4.3.1

// License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal initializer {
        __Context_init_unchained();
    }

    function __Context_init_unchained() internal initializer {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
    uint256[50] private __gap;
}


// File @openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol@v4.3.1

// License-Identifier: MIT

pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal initializer {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    uint256[49] private __gap;
}


// File @gnosis.pm/zodiac/contracts/factory/FactoryFriendly.sol@v1.0.1

// License-Identifier: LGPL-3.0-only

/// @title Zodiac FactoryFriendly - A contract that allows other contracts to be initializable and pass bytes as arguments to define contract state
pragma solidity >=0.7.0 <0.9.0;

abstract contract FactoryFriendly is OwnableUpgradeable {
    function setUp(bytes memory initializeParams) public virtual;
}


// File contracts/ScopeGuardPlus.sol

// License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.6;


contract ScopeGuardPlus is FactoryFriendly, BaseGuard {
    event SetTargetAllowed(address target, bool allowed);
    event SetTargetScoped(address target, bool scoped);
    event SetFallbackAllowedOnTarget(address target, bool allowed);
    event SetValueAllowedOnTarget(address target, bool allowed);
    event SetDelegateCallAllowedOnTarget(address target, bool allowed);
    event SetFunctionAllowedOnTarget(
        address target,
        bytes4 functionSig,
        bool allowed
    );
    event SetAllowedParameterOnTarget(
        address target,
        bytes4 functionSig,
        uint8 paramIndex,
        bytes32 allowedAddress,
        bool allowed
    );

    event TargetUpdated(
        address indexed target, 
        bool allowed, bool scoped, 
        bool delegateCallAllowed
    );

    event ScopeGuardSetup(address indexed initiator, address indexed owner);

    constructor(address _owner) {
        bytes memory initializeParams = abi.encode(_owner);
        setUp(initializeParams);
    }

    /// @dev Initialize function, will be triggered when a new proxy is deployed
    /// @param initializeParams Parameters of initialization encoded
    function setUp(bytes memory initializeParams) public override {
        __Ownable_init();
        address _owner = abi.decode(initializeParams, (address));

        transferOwnership(_owner);

        emit ScopeGuardSetup(msg.sender, _owner);
    }

    struct Target {
        bool allowed;
        bool scoped;
        bool delegateCallAllowed;
        bool fallbackAllowed;
        bool valueAllowed;
        mapping(bytes4 => bool) allowedFunctions;
        mapping(bytes4 => mapping(uint8 => mapping(bytes32 => bool))) allowedParameters;
    }

    mapping(address => Target) public allowedTargets;

    /// @dev Set or update target permissions.  Safe smart wallets adopting this guard contract is allowed to call allowed targets (other contract addresses) only.
    /// @param target Address to be updated.
    /// @param allowed Bool to allow or disallow calls to target.
    /// @param scoped Bool to scope or unscope function calls on target.
    /// @param delegateCallAllowed Bool to allow or disallow delegate calls to target.
    function configureTarget(
        address target,
        bool allowed,
        bool scoped,
        bool valueAllowed,
        bool delegateCallAllowed
    ) public onlyOwner {
        allowedTargets[target].allowed = allowed;
        allowedTargets[target].scoped = scoped;
        allowedTargets[target].scoped = valueAllowed;
        allowedTargets[target].delegateCallAllowed = delegateCallAllowed;

        emit TargetUpdated(target, allowed, scoped, delegateCallAllowed);
    }    

    /// @dev Set whether or not calls can be made to an address.
    /// @dev Set whether or not calls can be made to a target contract address.
    /// @param target Address to be allowed/disallowed.
    /// @param allow Bool to allow (true) or disallow (false) calls to target.
    function setTargetAllowed(address target, bool allow) public onlyOwner {
        allowedTargets[target].allowed = allow;
        emit SetTargetAllowed(target, allowedTargets[target].allowed);
    }

    /// @dev Set whether or not delegate calls can be made to a target.
    /// @notice Only callable by owner.
    /// @param target Address to which delegate calls should be allowed/disallowed.
    /// @param allow Bool to allow (true) or disallow (false) delegate calls to target.
    function setDelegateCallAllowedOnTarget(address target, bool allow)
        public
        onlyOwner
    {
        allowedTargets[target].delegateCallAllowed = allow;
        emit SetDelegateCallAllowedOnTarget(
            target,
            allowedTargets[target].delegateCallAllowed
        );
    }

    /// @dev Sets whether or not calls to an address should be scoped to specific function signatures.
    /// @notice Only callable by owner.
    /// @param target Address to be scoped/unscoped.
    /// @param scoped Bool to scope (true) or unscope (false) function calls on target.
    function setScoped(address target, bool scoped) public onlyOwner {
        allowedTargets[target].scoped = scoped;
        emit SetTargetScoped(target, allowedTargets[target].scoped);
    }

    /// @dev Sets whether fallback function can be triggered on target contract when Transaction data is empty
    /// @notice Only callable by owner.
    /// @param target Address to be allow/disallow sends to.
    /// @param allow Bool to allow (true) or disallow (false) sends on target.
    function setFallbackAllowedOnTarget(address target, bool allow)
        public
        onlyOwner
    {
        allowedTargets[target].fallbackAllowed = allow;
        emit SetFallbackAllowedOnTarget(
            target,
            allowedTargets[target].fallbackAllowed
        );
    }

    /// @dev Sets whether or not a non-zero value (of native tokens) can be set in transactions sent to target contract address
    /// @notice Only callable by owner.
    /// @param target Address to be allow/disallow sends to.
    /// @param allow Bool to allow (true) or disallow (false) sends on target.
    function setValueAllowedOnTarget(address target, bool allow)
        public
        onlyOwner
    {
        allowedTargets[target].valueAllowed = allow;
        emit SetValueAllowedOnTarget(
            target,
            allowedTargets[target].valueAllowed
        );
    }

    /// @dev Sets whether or not a specific function signature should be allowed on a scoped target.
    /// @notice Only callable by owner.
    /// @param target Scoped address on which a function signature should be allowed/disallowed.
    /// @param functionSig Function signature to be allowed/disallowed.
    /// @param allow Bool to allow (true) or disallow (false) calls a function signature on target.
    function setAllowedFunction(
        address target,
        bytes4 functionSig,
        bool allow
    ) public onlyOwner {
        allowedTargets[target].allowedFunctions[functionSig] = allow;
        emit SetFunctionAllowedOnTarget(
            target,
            functionSig,
            allowedTargets[target].allowedFunctions[functionSig]
        );
    }

    /// @dev Sets whether or not a specific parameter value should be allowed for a function on a scoped target.
    /// @notice Only callable by owner.
    /// @param target Scoped address on which a function signature and parameter should be allowed/disallowed.
    /// @param functionSig Function signature to be allowed/disallowed.
    /// @param paramIndex Index of the parameter to be allowed/disallowed.
    /// @param allowedAddress Value of the parameter to be allowed/disallowed.
    /// @param allow Bool to allow (true) or disallow (false) parameter value for the function on target.
    function setAllowedParameter(
        address target,
        bytes4 functionSig,
        uint8 paramIndex,
        bytes32 allowedAddress,
        bool allow
    ) public onlyOwner {
        allowedTargets[target].allowedParameters[functionSig][paramIndex][allowedAddress] = allow;
        emit SetAllowedParameterOnTarget(
            target,
            functionSig,
            paramIndex,
            allowedAddress,
            allow
        );
    }

    /// @dev Returns bool to indicate if an address is an allowed target.
    /// @param target Address to check.
    function isAllowedTarget(address target) public view returns (bool) {
        return (allowedTargets[target].allowed);
    }

    /// @dev Returns bool to indicate if an address is scoped.
    /// @param target Address to check.
    function isScoped(address target) public view returns (bool) {
        return (allowedTargets[target].scoped);
    }

    /// @dev Returns bool to indicate if fallback is allowed to a target.
    /// @param target Address to check.
    function isfallbackAllowed(address target) public view returns (bool) {
        return (allowedTargets[target].fallbackAllowed);
    }

    /// @dev Returns bool to indicate if ETH can be sent to a target.
    /// @param target Address to check.
    function isValueAllowed(address target) public view returns (bool) {
        return (allowedTargets[target].valueAllowed);
    }

    /// @dev Returns bool to indicate if a function signature is allowed for a target address.
    /// @param target Address to check.
    /// @param functionSig Signature to check.
    function isAllowedFunction(address target, bytes4 functionSig)
        public
        view
        returns (bool)
    {
        return (allowedTargets[target].allowedFunctions[functionSig]);
    }

    /// @dev Returns bool to indicate if a parameter value is allowed for a function on a target address.
    /// @param target Address to check.
    /// @param functionSig Signature of the function to check.
    /// @param paramIndex Index of the parameter to check.
    /// @param allowedAddress Value of the parameter to check.
    function isAllowedParameter(
        address target,
        bytes4 functionSig,
        uint8 paramIndex,
        bytes32 allowedAddress
    ) public view returns (bool) {
        return (
            allowedTargets[target].allowedParameters[functionSig][paramIndex][allowedAddress]
        );
    }

    /// @dev Returns bool to indicate if delegate calls are allowed to a target address.
    /// @param target Address to check.
    function isAllowedToDelegateCall(address target)
        public
        view
        returns (bool)
    {
        return (allowedTargets[target].delegateCallAllowed);
    }

    // solhint-disallow-next-line payable-fallback
    fallback() external {
        // We don't revert on fallback to avoid issues in case of a Safe upgrade
        // E.g. The expected check method might change and then the Safe would be locked.
    }

    /// @dev Checks if a transaction to be executed by the Safe is allowed according to the defined rules.
    /// @param to Target address of the transaction.
    /// @param value Amount of ETH to be sent.
    /// @param data Transaction data payload.
    /// @param operation Type of operation (call or delegate call).
    /// @notice Reverts if the transaction is not allowed.
    function checkTransaction(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation,
        uint256,
        uint256,
        uint256,
        address,
        // solhint-disallow-next-line no-unused-vars
        address payable,
        bytes memory,
        address
    ) external view override {
        require(
            operation != Enum.Operation.DelegateCall ||
                allowedTargets[to].delegateCallAllowed,
            "Delegate call not allowed to this address"
        );
        require(allowedTargets[to].allowed, "Target address is not allowed");
        
        if (value > 0) {
            require(
                allowedTargets[to].valueAllowed,
                "Cannot send Native Token (e.g. ETH, MATIC) to this target"
            );
        }

        if (data.length >= 4) {
            bytes4 functionSig = bytes4(data);

            require(
                !allowedTargets[to].scoped || allowedTargets[to].allowedFunctions[functionSig],
                "Target function is not allowed"
            );

            if (allowedTargets[to].scoped || allowedTargets[to].allowedFunctions[functionSig]) {
                checkFirstAddress(to, functionSig, data);
            }

        } else {
            require(data.length == 0, "Function signature too short");
            require(
                !allowedTargets[to].scoped || allowedTargets[to].fallbackAllowed,
                "Fallback not allowed for this address"
            );
        }
    }

    /// @dev Checks if the parameters of a function call are allowed according to the defined rules.
    /// @param to Target address of the function call.
    /// @param functionSig Function signature of the function call.
    /// @param data Transaction data payload including function parameters.
    /// @notice Reverts if the parameters are not allowed.    
    function checkFirstAddress(
        address to,
        bytes4 functionSig,
        bytes memory data
    ) internal view {
        bytes32 paramValue;
        assembly {
            // Move pointer 32 bytes to skip length of bytes array
            // Move pointer 4 bytes to skip function selector to the first parameter
            let firstParamPointer := add(data, 36)        
            paramValue := mload(firstParamPointer)            
        }

        require(
            allowedTargets[to].allowedParameters[functionSig][0][paramValue],
            "Parameter value is not allowed"
        );
    }

    /// @dev Bulk add targets with function signatures and parameter values.
    /// @param targets Array of target addresses to be added.
    /// @param scoped Array of booleans indicating whether to scope (true) or unscope (false) the specified configurations.
    /// @param functionSigs Array of function signatures corresponding to each target.
    /// @param paramIndexes Array of parameter indexes corresponding to each function signature.
    /// @param values Array of allowed parameter values corresponding to each function signature and parameter index
    /// @param allow Array of booleans indicating whether to allow or disallow the specified configurations.
    function bulkAddTargets(
        address[] memory targets,
        bool[] memory scoped,
        bool[] memory delegateCallAllowed,
        bool[] memory valueAllowed,
        bytes4[] memory functionSigs,
        uint8[] memory paramIndexes,
        bytes32[] memory values,
        bool[] memory allow
    ) public onlyOwner {
        require(
            targets.length == functionSigs.length &&
            targets.length == scoped.length &&
            targets.length == paramIndexes.length &&
            targets.length == values.length &&
            targets.length == allow.length,
            "Input arrays must have the same length"
        );

        for (uint256 i = 0; i < targets.length; i++) {
            configureTarget(targets[i], true, scoped[i], valueAllowed[i], delegateCallAllowed[i]);
            setAllowedFunction(targets[i], functionSigs[i], allow[i]);
            setAllowedParameter(
                targets[i],
                functionSigs[i],
                paramIndexes[i],
                values[i],
                allow[i]
            );
        }
    }    

    function checkAfterExecution(bytes32, bool) external view override {}

}
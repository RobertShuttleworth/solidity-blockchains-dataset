// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/utils/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

pragma solidity ^0.8.20;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// File: @openzeppelin/contracts/utils/Pausable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (utils/Pausable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    bool private _paused;

    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * @dev The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * @dev The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: @openzeppelin/contracts/interfaces/IERC20.sol


// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC20.sol)

pragma solidity ^0.8.20;


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/IERC165.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/interfaces/IERC165.sol


// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

pragma solidity ^0.8.20;


// File: @openzeppelin/contracts/interfaces/IERC1363.sol


// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/IERC1363.sol)

pragma solidity ^0.8.20;



/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// File: @openzeppelin/contracts/utils/Errors.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}

// File: @openzeppelin/contracts/utils/Address.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/Address.sol)

pragma solidity ^0.8.20;


/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {Errors.FailedCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {Errors.FailedCall}) in case
     * of an unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {Errors.FailedCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;




/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? address(token).code.length > 0 : returnValue == 1);
    }
}

// File: contracts/Coin100PublicSale.sol


pragma solidity ^0.8.28;

// ========== Imports ========== //






/**
 * @title C100PublicSale
 * @notice A public sale contract for C100 tokens supporting multiple payment tokens at specific rates.
 *
 * Features:
 * - 12-month vesting: purchased C100 tokens are locked and claimable after `vestingDuration`.
 * - Per-user cap on the total C100 that can be purchased.
 * - Delay between consecutive purchases to mitigate bot attacks.
 * - Presale duration defined by start/end timestamps.
 * - Allows buying C100 with multiple approved ERC20 tokens at specified rates.
 * - Finalizes by burning only the truly unsold C100 tokens.
 */
contract C100PublicSale is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ---------------------------------------
    // State Variables
    // ---------------------------------------

    /// @notice The C100 token being sold.
    IERC20 public c100Token;

    /// @notice The treasury address where funds are collected.
    address public treasury;

    /// @notice Struct representing an allowed payment token.
    struct AllowedToken {
        IERC20 token;        // ERC20 token used for payment
        uint256 rate;        // Price per 1 C100, scaled by 1e18 (e.g., 1e15 = 0.001 token per C100)
        string symbol;       // Symbol of the payment token
        string name;         // Name of the payment token
        uint8 decimals;      // Decimals of the payment token
    }

    /// @notice Array of allowed payment tokens.
    AllowedToken[] public allowedTokens;

    /// @notice Mapping to check if a token is allowed for payment.
    mapping(address => bool) public isAllowedToken;

    /// @notice Start time of the ICO (Unix timestamp).
    uint256 public startTime;

    /// @notice End time of the ICO (Unix timestamp).
    uint256 public endTime;

    /// @notice Flag indicating whether the ICO has been finalized.
    bool public finalized;

    // ---------------------------------------
    // Vesting & Purchase Control
    // ---------------------------------------

    /// @notice The vesting duration (seconds) for each purchase. (e.g. 12 months = 365 days)
    uint256 public vestingDuration = 365 days;

    /// @notice The minimum delay (seconds) between consecutive purchases by the same user.
    uint256 public purchaseDelay = 300; // 5 minutes

    /// @notice The maximum C100 each user can purchase (1e18 = 1 token if decimals=18).
    uint256 public maxUserCap = 1_000_000 ether;

    /// @notice Tracks the total amount of C100 each user has purchased (enforcing `maxUserCap`).
    mapping(address => uint256) public userPurchases;

    /// @notice Tracks the last purchase timestamp for each user (enforcing `purchaseDelay`).
    mapping(address => uint256) public lastPurchaseTime;

    /// @notice Tracks the total amount of tokens currently locked for vesting across **all** users.
    uint256 public totalLockedTokens;

    /// @notice Struct storing vesting info for each purchase.
    struct VestingSchedule {
        uint256 amount;       // how many C100 tokens locked for this purchase
        uint256 releaseTime;  // when tokens can be claimed
    }

    /// @notice Mapping: user => array of vesting schedules
    mapping(address => VestingSchedule[]) public vestings;

    // ---------------------------------------
    // Events
    // ---------------------------------------

    /// @notice Emitted when a token purchase occurs (tokens are locked, not immediately transferred).
    event TokenPurchased(
        address indexed buyer,
        address indexed paymentToken,
        uint256 paymentAmount,
        uint256 c100Amount
    );

    /// @notice Emitted when a new payment token is added.
    event AllowedTokenAdded(
        address indexed token,
        uint256 rate,
        string symbol,
        string name,
        uint8 decimals
    );

    /// @notice Emitted when a payment token is removed.
    event AllowedTokenRemoved(address indexed token);

    /// @notice Emitted when ICO parameters are updated.
    event ICOParametersUpdated(uint256 newStart, uint256 newEnd);

    /// @notice Emitted when the treasury address is updated.
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Emitted when the ICO is finalized (unsold tokens burned).
    event Finalized(uint256 unsoldTokensBurned);

    /// @notice Emitted when tokens are rescued from the contract.
    event TokensRescued(address indexed token, uint256 amount);

    /// @notice Emitted when the C100 token address is updated.
    event C100TokenUpdated(address oldC100, address newC100);

    /// @notice Emitted when the sale is initialized.
    event SaleInitialized(
        address c100Token,
        address initialPaymentToken,
        uint256 rate,
        string symbol,
        string name,
        uint8 decimals,
        address treasury,
        uint256 startTime,
        uint256 endTime
    );

    /// @notice Emitted when user claims vested tokens.
    event TokensClaimed(address indexed user, uint256 amount);

    /// @notice Emitted when vestingDuration, purchaseDelay, or maxUserCap are updated.
    event VestingConfigUpdated(
        uint256 newVestingDuration,
        uint256 newPurchaseDelay,
        uint256 newMaxUserCap
    );

    // ---------------------------------------
    // Modifiers
    // ---------------------------------------

    /**
     * @notice Modifier to check if the ICO is currently active.
     */
    modifier icoActive() {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "ICO not active"
        );
        require(!finalized, "ICO finalized");
        _;
    }

    /**
     * @notice Modifier to check if the ICO has not started yet.
     */
    modifier icoNotStarted() {
        require(block.timestamp < startTime, "ICO started");
        _;
    }

    /**
     * @notice Modifier to check if the ICO has ended.
     */
    modifier icoEnded() {
        require(block.timestamp > endTime, "ICO not ended");
        _;
    }

    // ---------------------------------------
    // Constructor
    // ---------------------------------------

    /**
     * @notice Constructor to initialize the public sale contract.
     * @param _c100Token Address of the C100 token contract.
     * @param _initialToken Address of the initial payment token.
     * @param _initialRate Price per C100 in the initial token, scaled by 1e18.
     * @param _initialSymbol Symbol of the initial token.
     * @param _initialName Name of the initial token.
     * @param _initialDecimals Decimals of the initial token.
     * @param _treasury Address of the treasury.
     * @param _startTime UNIX timestamp for ICO start.
     * @param _endTime UNIX timestamp for ICO end.
     */
    constructor(
        address _c100Token,
        address _initialToken,
        uint256 _initialRate,
        string memory _initialSymbol,
        string memory _initialName,
        uint8 _initialDecimals,
        address _treasury,
        uint256 _startTime,
        uint256 _endTime
    )
        Ownable(_treasury) // Set the owner as the treasury
        ReentrancyGuard()
        Pausable()
    {
        require(_c100Token != address(0), "C100 token zero address");
        require(_initialToken != address(0), "Initial token zero address");
        require(_treasury != address(0), "Treasury zero address");
        require(_startTime < _endTime, "Invalid time range");
        require(_initialRate > 0, "Initial rate must be > 0");

        c100Token = IERC20(_c100Token);
        treasury = _treasury;
        startTime = _startTime;
        endTime = _endTime;

        // Add the initial allowed payment token
        AllowedToken memory newToken = AllowedToken({
            token: IERC20(_initialToken),
            rate: _initialRate,
            symbol: _initialSymbol,
            name: _initialName,
            decimals: _initialDecimals
        });

        allowedTokens.push(newToken);
        isAllowedToken[_initialToken] = true;

        emit AllowedTokenAdded(_initialToken, _initialRate, _initialSymbol, _initialName, _initialDecimals);
        emit SaleInitialized(
            _c100Token,
            _initialToken,
            _initialRate,
            _initialSymbol,
            _initialName,
            _initialDecimals,
            _treasury,
            _startTime,
            _endTime
        );
    }

    // ---------------------------------------
    // Public Functions
    // ---------------------------------------

    /**
     * @notice Allows users to purchase C100 tokens with any allowed token at a specific rate.
     *         The purchased tokens are locked and claimable after `vestingDuration`.
     * @param paymentToken Address of the token to pay with.
     * @param paymentAmount Amount of the payment token to spend.
     */
    function buyWithToken(address paymentToken, uint256 paymentAmount)
        external
        nonReentrant
        whenNotPaused
        icoActive
    {
        require(isAllowedToken[paymentToken], "Token not allowed");
        require(paymentAmount > 0, "Payment amount must be > 0");

        // Enforce delay between purchases
        require(
            block.timestamp >= lastPurchaseTime[msg.sender] + purchaseDelay,
            "Purchase too soon"
        );

        AllowedToken memory tokenData = getAllowedToken(paymentToken);

        // Calculate how many C100 tokens (1e18 decimals) the user receives
        // c100Amount = (paymentAmount * 1e18) / rate
        uint256 c100Amount = (paymentAmount * 1e18) / tokenData.rate;
        require(
            c100Token.balanceOf(address(this)) >= (totalLockedTokens + c100Amount),
            "Not enough C100 tokens in contract"
        );

        // Enforce per-user cap
        require(
            userPurchases[msg.sender] + c100Amount <= maxUserCap,
            "Exceeds max user cap"
        );

        // Update user purchase info
        lastPurchaseTime[msg.sender] = block.timestamp;
        userPurchases[msg.sender] += c100Amount;

        // Transfer payment from buyer to treasury
        tokenData.token.safeTransferFrom(msg.sender, treasury, paymentAmount);

        // Lock tokens in a vesting schedule
        vestings[msg.sender].push(
            VestingSchedule({
                amount: c100Amount,
                releaseTime: block.timestamp + vestingDuration
            })
        );

        // Increment total locked
        totalLockedTokens += c100Amount;

        emit TokenPurchased(msg.sender, paymentToken, paymentAmount, c100Amount);
    }

    /**
     * @notice Claim all vested C100 tokens for the caller that have passed their release time.
     */
    function claimTokens() external nonReentrant whenNotPaused {
        uint256 totalClaimable = 0;
        VestingSchedule[] storage schedules = vestings[msg.sender];

        for (uint256 i = 0; i < schedules.length; i++) {
            if (
                schedules[i].amount > 0 &&
                block.timestamp >= schedules[i].releaseTime
            ) {
                totalClaimable += schedules[i].amount;
                schedules[i].amount = 0; // Mark as claimed
            }
        }

        require(totalClaimable > 0, "No tokens to claim");

        // Decrement global locked count
        totalLockedTokens -= totalClaimable;

        // Transfer unlocked tokens
        c100Token.safeTransfer(msg.sender, totalClaimable);

        emit TokensClaimed(msg.sender, totalClaimable);
    }

    /**
     * @notice Retrieves the allowed token data.
     * @param token Address of the token.
     * @return AllowedToken struct containing token data.
     */
    function getAllowedToken(address token)
        public
        view
        returns (AllowedToken memory)
    {
        require(isAllowedToken[token], "Token not allowed");
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            if (address(allowedTokens[i].token) == token) {
                return allowedTokens[i];
            }
        }
        revert("Token not found");
    }

    /**
     * @notice Returns all allowed tokens.
     * @return Array of AllowedToken structs.
     */
    function getAllowedTokens() external view returns (AllowedToken[] memory) {
        return allowedTokens;
    }

    // ---------------------------------------
    // Admin Functions
    // ---------------------------------------

    /**
     * @notice Finalizes the ICO by burning any unsold C100 tokens.
     *         "Unsold" = tokens currently in the contract minus totalLockedTokens.
     */
    function finalize() external onlyOwner icoEnded nonReentrant {
        require(!finalized, "Already finalized");
        finalized = true;

        uint256 contractBalance = c100Token.balanceOf(address(this));
        require(contractBalance > totalLockedTokens, "Nothing to burn");

        uint256 unsold = contractBalance - totalLockedTokens;
        if (unsold > 0) {
            c100Token.safeTransfer(
                address(0x000000000000000000000000000000000000dEaD),
                unsold
            );
        }

        emit Finalized(unsold);
    }

    /**
     * @notice Update ICO parameters before it starts.
     * @param newStart UNIX timestamp for new ICO start.
     * @param newEnd UNIX timestamp for new ICO end.
     */
    function updateICOParameters(uint256 newStart, uint256 newEnd)
        external
        onlyOwner
        icoNotStarted
    {
        require(newStart < newEnd, "Invalid time range");
        startTime = newStart;
        endTime = newEnd;
        emit ICOParametersUpdated(newStart, newEnd);
    }

    /**
     * @notice Update the treasury address.
     * @param newTreasury New treasury address.
     */
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "Zero address");
        address old = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(old, newTreasury);
    }

    /**
     * @notice Update the C100 token address.
     * @param newC100 Address of the new C100 token.
     */
    function updateC100Token(address newC100) external onlyOwner {
        require(newC100 != address(0), "Zero address");
        address oldC100 = address(c100Token);
        c100Token = IERC20(newC100);
        emit C100TokenUpdated(oldC100, newC100);
    }

    /**
     * @notice Add a new allowed token for purchasing C100.
     * @param _token Address of the new payment token.
     * @param _rate Price per C100 in the new token, scaled by 1e18.
     * @param _symbol Symbol of the new token.
     * @param _name Name of the new token.
     * @param _decimals Decimals of the new token.
     */
    function addAllowedToken(
        address _token,
        uint256 _rate,
        string memory _symbol,
        string memory _name,
        uint8 _decimals
    ) external onlyOwner {
        require(_token != address(0), "Token zero address");
        require(!isAllowedToken[_token], "Token already allowed");
        require(_rate > 0, "Rate must be > 0");

        AllowedToken memory newToken = AllowedToken({
            token: IERC20(_token),
            rate: _rate,
            symbol: _symbol,
            name: _name,
            decimals: _decimals
        });

        allowedTokens.push(newToken);
        isAllowedToken[_token] = true;

        emit AllowedTokenAdded(_token, _rate, _symbol, _name, _decimals);
    }

    /**
     * @notice Remove an allowed token from purchasing C100.
     * @param _token Address of the token to remove.
     */
    function removeAllowedToken(address _token) external onlyOwner {
        require(isAllowedToken[_token], "Token not allowed");

        // Find the token in the array
        uint256 indexToRemove = allowedTokens.length;
        for (uint256 i = 0; i < allowedTokens.length; i++) {
            if (address(allowedTokens[i].token) == _token) {
                indexToRemove = i;
                break;
            }
        }
        require(indexToRemove < allowedTokens.length, "Token not found in array");

        // Swap with last element and pop
        AllowedToken memory lastToken = allowedTokens[allowedTokens.length - 1];
        allowedTokens[indexToRemove] = lastToken;
        allowedTokens.pop();

        // Update mapping
        isAllowedToken[_token] = false;

        emit AllowedTokenRemoved(_token);
    }

    /**
     * @notice Rescues tokens accidentally sent to the contract, excluding C100 and allowed payment tokens.
     * @param token Address of the token to rescue.
     * @param amount Amount of tokens to rescue.
     */
    function rescueTokens(address token, uint256 amount)
        external
        onlyOwner
    {
        require(token != address(c100Token), "Cannot rescue C100 tokens");
        require(!isAllowedToken[token], "Cannot rescue allowed payment tokens");
        require(token != address(0), "Zero address");

        IERC20(token).safeTransfer(treasury, amount);
        emit TokensRescued(token, amount);
    }

    /**
     * @notice Burn C100 tokens from the treasury (optional utility).
     * @param amount Amount of C100 tokens to burn.
     *
     * Requirements:
     * - The treasury must have approved this contract to spend at least `amount` C100 tokens.
     */
    function burnFromTreasury(uint256 amount)
        external
        onlyOwner
        nonReentrant
    {
        require(
            c100Token.balanceOf(treasury) >= amount,
            "Not enough tokens in treasury"
        );
        c100Token.safeTransferFrom(
            treasury,
            address(0x000000000000000000000000000000000000dEaD),
            amount
        );
    }

    /**
     * @notice Pause the contract, disabling new purchases and claims.
     */
    function pauseContract() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpause the contract, enabling purchases and claims.
     */
    function unpauseContract() external onlyOwner {
        _unpause();
    }

    // ---------------------------------------
    // Vesting/Delay/Cap Configuration
    // ---------------------------------------

    /**
     * @notice Update the vesting duration, purchase delay, and max user cap.  
     * @param _vestingDuration New vesting duration in seconds.
     * @param _purchaseDelay New delay between purchases in seconds.
     * @param _maxUserCap New maximum total C100 a user can purchase (base units).
     */
    function updateVestingConfig(
        uint256 _vestingDuration,
        uint256 _purchaseDelay,
        uint256 _maxUserCap
    ) external onlyOwner {
        require(_vestingDuration > 0, "Vesting must be > 0");
        require(_purchaseDelay <= 7 days, "Delay too large?");
        require(_maxUserCap > 0, "Max cap must be > 0");

        vestingDuration = _vestingDuration;
        purchaseDelay = _purchaseDelay;
        maxUserCap = _maxUserCap;

        emit VestingConfigUpdated(_vestingDuration, _purchaseDelay, _maxUserCap);
    }
}
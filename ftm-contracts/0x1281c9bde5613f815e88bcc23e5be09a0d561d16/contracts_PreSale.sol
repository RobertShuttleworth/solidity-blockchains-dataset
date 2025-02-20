// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/****
 * Contract module that helps prevent reentrant calls to a function.
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
     * Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * Prevents a contract from calling itself, directly or indirectly.
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
     * Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

/**
 * Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * Sets a `value` amount of tokens as the allowance of `spender` over the
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
     * Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/**
 * Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     *  Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     *  Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     *  Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

/**
 * Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/**
 * @title IERC1363
 * Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
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
     * Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

/**
 * Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 */
library Errors {
    /**
     * The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * The deployment failed.
     */
    error FailedDeployment();

    /**
     * A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}

/**
 * Collection of functions related to the address type
 */
library Address {
    /**
     * There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * Replacement for Solidity's `transfer`: sends `amount` wei to
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
     * Performs a Solidity function call using a low level `call`. A
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
     * Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
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
     * Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * Tool to verify that a low level call to smart-contract was successful, and reverts if the target
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
     * Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
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
     * Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}

/**
 * @title SafeERC20
 * Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
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
     * Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
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
     * Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
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
     * Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
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
     * Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
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
     * Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
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

/**
 * Provides information about the current execution context, including the
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

/**
 * Contract module which provides a basic access control mechanism, where
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
     * The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * Contract module which allows children to implement an emergency stop
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
     * Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    /**
     * The operation failed because the contract is paused.
     */
    error EnforcedPause();

    /**
     * The operation failed because the contract is not paused.
     */
    error ExpectedPause();

    /**
     * Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * Modifier to make a function callable only when the contract is not paused.
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
     * Modifier to make a function callable only when the contract is paused.
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
     * Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        if (paused()) {
            revert EnforcedPause();
        }
    }

    /**
     * Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        if (!paused()) {
            revert ExpectedPause();
        }
    }

    /**
     * Triggers stopped state.
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
     * Returns to normal state.
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

abstract contract Whitelist is Context {
    /**
     * Emitted when the whitelist is triggered by `account`.
     */
    event EnableWhitelist(address account);

    /**
     * Emitted when the whitelist is lifted by `account`.
     */
    event DisableWhitelist(address account);

    bool private _whitelist;

    /**
     * Initializes the contract in a disabled whitelist state.
     */
    constructor() {
        _whitelist = false;
    }

    /**
     * Returns true if whitelist is enabled, and false otherwise.
     */
    function whitelist() public view virtual returns (bool) {
        return _whitelist;
    }

    /**
     * Modifier to make a function callable only when whitelist is disabled.
     *
     * Requirements:
     *
     * - The whitelist must be disabled.
     */

    modifier whenDisabledWhitelist() {
        require(!whitelist(), "Whitelist is not disabled");
        _;
    }

    /**
     * Modifier to make a function callable only when whitelist is enabled.
     *
     * Requirements:
     *
     * - The whitelist must be enabled.
     */
    modifier whenEnabledWhitelist() {
        require(whitelist(), "Whitelist is not enabled");
        _;
    }

    /**
     * Triggers enable state.
     *
     * Requirements:
     *
     * - The whitelist must be disabled.
     */
    function _enableWhitelist() internal virtual whenDisabledWhitelist {
        _whitelist = true;
        emit EnableWhitelist(_msgSender());
    }

    /**
     * Triggers disable state.
     *
     * Requirements:
     *
     * - The whitelist must be enabled.
     */
    function _disableWhitelist() internal virtual whenEnabledWhitelist {
        _whitelist = false;
        emit DisableWhitelist(_msgSender());
    }
}

abstract contract Withdraw is Context {
    /**
     * Emitted when the withdraw is triggered by `account`.
     */
    event EnableWithdraw(address account);

    /**
     * Emitted when the withdraw is lifted by `account`.
     */
    event DisableWithdraw(address account);

    bool private _withdraw;

    /**
     * Initializes the contract in a disabled withdraw state.
     */
    constructor() {
        _withdraw = false;
    }

    /**
     * Returns true if withdraw is enabled, and false otherwise.
     */
    function withdraw() public view virtual returns (bool) {
        return _withdraw;
    }

    /**
     * Modifier to make a function callable only when withdraw is disabled.
     *
     * Requirements:
     *
     * - The withdraw must be disabled.
     */

    modifier whenDisabledWithdraw() {
        require(!withdraw(), "Withdraw is not disabled");
        _;
    }

    /**
     * Modifier to make a function callable only when withdraw is enabled.
     *
     * Requirements:
     *
     * - The withdraw must be enabled.
     */
    modifier whenEnabledWithdraw() {
        require(withdraw(), "Withdraw is not enabled");
        _;
    }

    /**
     * Triggers enable state.
     *
     * Requirements:
     *
     * - The withdraw must be disabled.
     */
    function _enableWithdraw() internal virtual whenDisabledWithdraw {
        _withdraw = true;
        emit EnableWithdraw(_msgSender());
    }

    /**
     * Triggers disable state.
     *
     * Requirements:
     *
     * - The withdraw must be enabled.
     */
    function _disableWithdraw() internal virtual whenEnabledWithdraw {
        _withdraw = false;
        emit DisableWithdraw(_msgSender());
    }
}

/**
 * Main Pre-Sale contract
 */
contract Presale is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token;
    IERC20Metadata public tokenMetadata;

    uint256 private totalPaidCoin;
    uint256 private totalBoughtToken;
    uint256 private totalStakedToken;
    uint256 private totalWithdrawCoin;

    enum PreSaleSteps {
        Disable,
        Step1,
        Step2,
        Step3,
        Step4
    }

    struct PreSaleOptions {
        address owner;
        address contractAddress;
        bool isPreSaleActive;
        bool isWithdrawCoinActive;
        bool isClaimActive;
        bool isStakingActive;
        uint256 rateStep1;
        uint256 rateStep2;
        uint256 rateStep3;
        uint256 rateStep4;
        PreSaleSteps activeStep;
        uint256 endStakingTime;
        uint256 stakingRate;
        uint256 stakingRateDecimals;
    }

    PreSaleOptions public preSaleOptions;

    struct User {
        uint256 depositCoinValueStep1;
        uint256 depositCoinValueStep2;
        uint256 depositCoinValueStep3;
        uint256 depositCoinValueStep4;

        uint256 depositTimeStep1;
        uint256 depositTimeStep2;
        uint256 depositTimeStep3;
        uint256 depositTimeStep4;

        uint256 preSaleTokenCheckout;
        uint256 preSaleCoinCheckout;
        uint256 preSaleWithdrawPayout;

        bool isStakingActive;
        bool isOldUser;

        uint256 totalCoinBalance;
        uint256 totalTokenBalance;
        uint256 interestTokenBalance;
        uint256 startTimeTokenAmount;
        uint256 startTimeTime;
    }

    mapping(address => User) public userInfo;

    event WithdrawFund (address, uint256);
    event TransferCoinOwner (address, uint256);
    event TransferTokensOwner (address, uint256);
    event BuyTokens (address, uint256);
    event ClaimTokens(address, uint256, uint256);
    event ClaimTokensAfterStaking(address, uint256);

    constructor (
        uint256 _rateStep1, uint256 _rateStep2, uint256 _rateStep3, uint256 _rateStep4,
        uint256 _endStakingTime, uint256 _stakingRate, uint256 _stakingRateDecimals
    ) Ownable(msg.sender) {
        preSaleOptions.owner = payable(msg.sender);
        preSaleOptions.contractAddress = payable(address(this));
        preSaleOptions.rateStep1 = _rateStep1;
        preSaleOptions.rateStep2 = _rateStep2;
        preSaleOptions.rateStep3 = _rateStep3;
        preSaleOptions.rateStep4 = _rateStep4;
        preSaleOptions.activeStep = PreSaleSteps.Disable;
        preSaleOptions.endStakingTime = _endStakingTime;
        preSaleOptions.stakingRate = _stakingRate;
        preSaleOptions.stakingRateDecimals = _stakingRateDecimals;
    }

    /**
     * Deposits coin to get token.
     */
    function buyTokens(bool _isStakingActive) public payable whenNotPaused nonReentrant returns (bool) {
        require(preSaleOptions.isPreSaleActive, "Presale is not active");

        require(uint(preSaleOptions.activeStep) != uint(PreSaleSteps.Disable), "Pre-Sale is not active yet");

        User storage userCurrentInfo = userInfo[msg.sender];

        require(
            userCurrentInfo.isOldUser == false ||
            (userCurrentInfo.isOldUser == true && userCurrentInfo.isStakingActive == _isStakingActive),
            "You can not change your plan"
        );

        if(uint(preSaleOptions.activeStep) == uint(PreSaleSteps.Step1)) {
            // step 1
            userCurrentInfo.depositCoinValueStep1 += msg.value;
            totalPaidCoin += msg.value;
            userCurrentInfo.depositTimeStep1 = block.timestamp;

            uint256 wantedTokenByUser = msg.value * preSaleOptions.rateStep1;
            if(_isStakingActive) {
                totalStakedToken += wantedTokenByUser;

                if(userCurrentInfo.totalCoinBalance != 0) {
                    // checkout
                    uint256 totalTime = block.timestamp - userCurrentInfo.startTimeTime;
                    uint256 totalInterestToken = userCurrentInfo.startTimeTokenAmount * totalTime;
                    uint256 totalTokenFinal = ( totalInterestToken * preSaleOptions.stakingRate ) / preSaleOptions.stakingRateDecimals;

                    userCurrentInfo.interestTokenBalance = totalTokenFinal;
                    userCurrentInfo.startTimeTokenAmount += wantedTokenByUser;
                    userCurrentInfo.startTimeTime = block.timestamp;
                } else {
                    userCurrentInfo.startTimeTokenAmount += wantedTokenByUser;
                    userCurrentInfo.startTimeTime = block.timestamp;
                }
            } else {
                totalBoughtToken += wantedTokenByUser;
            }

            userCurrentInfo.totalCoinBalance += msg.value;
            userCurrentInfo.totalTokenBalance += wantedTokenByUser;

        } else if(uint(preSaleOptions.activeStep) == uint(PreSaleSteps.Step2)) {
            // step 2
            userCurrentInfo.depositCoinValueStep2 += msg.value;
            totalPaidCoin += msg.value;
            userCurrentInfo.depositTimeStep2 = block.timestamp;

            uint256 wantedTokenByUser = msg.value * preSaleOptions.rateStep2;
            if(_isStakingActive) {
                totalStakedToken += wantedTokenByUser;

                if(userCurrentInfo.totalCoinBalance != 0) {
                    // checkout
                    uint256 totalTime = block.timestamp - userCurrentInfo.startTimeTime;
                    uint256 totalInterestToken = userCurrentInfo.startTimeTokenAmount * totalTime;
                    uint256 totalTokenFinal = ( totalInterestToken * preSaleOptions.stakingRate ) / preSaleOptions.stakingRateDecimals;

                    userCurrentInfo.interestTokenBalance = totalTokenFinal;
                    userCurrentInfo.startTimeTokenAmount += wantedTokenByUser;
                    userCurrentInfo.startTimeTime = block.timestamp;
                } else {
                    userCurrentInfo.startTimeTokenAmount += wantedTokenByUser;
                    userCurrentInfo.startTimeTime = block.timestamp;
                }
            } else {
                totalBoughtToken += wantedTokenByUser;
            }

            userCurrentInfo.totalCoinBalance += msg.value;
            userCurrentInfo.totalTokenBalance += wantedTokenByUser;

        } else if(uint(preSaleOptions.activeStep) == uint(PreSaleSteps.Step3)) {
            // step 3
            userCurrentInfo.depositCoinValueStep3 += msg.value;
            totalPaidCoin += msg.value;
            userCurrentInfo.depositTimeStep3 = block.timestamp;

            uint256 wantedTokenByUser = msg.value * preSaleOptions.rateStep3;
            if(_isStakingActive) {
                totalStakedToken += wantedTokenByUser;

                if(userCurrentInfo.totalCoinBalance != 0) {
                    // checkout
                    uint256 totalTime = block.timestamp - userCurrentInfo.startTimeTime;
                    uint256 totalInterestToken = userCurrentInfo.startTimeTokenAmount * totalTime;
                    uint256 totalTokenFinal = ( totalInterestToken * preSaleOptions.stakingRate ) / preSaleOptions.stakingRateDecimals;

                    userCurrentInfo.interestTokenBalance = totalTokenFinal;
                    userCurrentInfo.startTimeTokenAmount += wantedTokenByUser;
                    userCurrentInfo.startTimeTime = block.timestamp;
                } else {
                    userCurrentInfo.startTimeTokenAmount += wantedTokenByUser;
                    userCurrentInfo.startTimeTime = block.timestamp;
                }
            } else {
                totalBoughtToken += wantedTokenByUser;
            }

            userCurrentInfo.totalCoinBalance += msg.value;
            userCurrentInfo.totalTokenBalance += wantedTokenByUser;

        } else if(uint(preSaleOptions.activeStep) == uint(PreSaleSteps.Step4)) {
            // step 4
            userCurrentInfo.depositCoinValueStep4 += msg.value;
            totalPaidCoin += msg.value;
            userCurrentInfo.depositTimeStep4 = block.timestamp;

            uint256 wantedTokenByUser = msg.value * preSaleOptions.rateStep4;
            if(_isStakingActive) {
                totalStakedToken += wantedTokenByUser;

                if(userCurrentInfo.totalCoinBalance != 0) {
                    // checkout
                    uint256 totalTime = block.timestamp - userCurrentInfo.startTimeTime;
                    uint256 totalInterestToken = userCurrentInfo.startTimeTokenAmount * totalTime;
                    uint256 totalTokenFinal = ( totalInterestToken * preSaleOptions.stakingRate ) / preSaleOptions.stakingRateDecimals;

                    userCurrentInfo.interestTokenBalance = totalTokenFinal;
                    userCurrentInfo.startTimeTokenAmount += wantedTokenByUser;
                    userCurrentInfo.startTimeTime = block.timestamp;
                } else {
                    userCurrentInfo.startTimeTokenAmount += wantedTokenByUser;
                    userCurrentInfo.startTimeTime = block.timestamp;
                }
            } else {
                totalBoughtToken += wantedTokenByUser;
            }

            userCurrentInfo.totalCoinBalance += msg.value;
            userCurrentInfo.totalTokenBalance += wantedTokenByUser;
        }

        userCurrentInfo.isStakingActive = _isStakingActive;
        userCurrentInfo.isOldUser = true;

        emit BuyTokens(msg.sender, msg.value);

        return true;
    }

    /**
     * Claim tokens by users after pre-sale
     */
    function claimTokens() public whenNotPaused nonReentrant returns (bool) {
        require(preSaleOptions.isClaimActive, "Claim token is not active");

        User storage userCurrentInfo = userInfo[msg.sender];
        require(
            userCurrentInfo.totalCoinBalance != 0,
            "You did not pay anything"
        );

        require(
            userCurrentInfo.isStakingActive == false,
            "Your staking plan is active"
        );

        require(
            userCurrentInfo.preSaleTokenCheckout == 0,
            "You are not eligible for staking 2"
        );

        require(address(token) != address(0), "Token not set. Call the admin.");
        require(availableTokens() > 0, "Insufficient liquidity. Call the admin.");
        (uint256 totalCoin,uint256 totalToken,,,,,,) = _tokenPrice(msg.sender);
        require(totalToken <= availableTokens(), "Insufficient liquidity. Call the admin2.");

        userCurrentInfo.preSaleTokenCheckout = totalToken;
        userCurrentInfo.preSaleCoinCheckout = totalCoin;
        token.safeTransfer(msg.sender, totalToken);

        emit ClaimTokens(
            msg.sender,
            totalCoin,
            totalToken
        );

        return true;
    }

    /**
     * Claim tokens by users after staking
     */
    function claimTokensStaking() public whenNotPaused nonReentrant returns(bool) {
        require(preSaleOptions.isStakingActive, "Claim Staking is not active yet");

        User storage userCurrentInfo = userInfo[msg.sender];

        require(
            userCurrentInfo.isStakingActive == true,
            "You are not eligible for staking 1"
        );

        require(
            userCurrentInfo.preSaleTokenCheckout == 0,
            "You are not eligible for staking 2"
        );

        (uint256 totalCoin,,,,,,,) = _tokenPrice(msg.sender);

        uint256 totalTime = preSaleOptions.endStakingTime - userCurrentInfo.startTimeTime;
        uint256 totalInterestToken = userCurrentInfo.startTimeTokenAmount * totalTime;
        uint256 totalTokenFinal = ( totalInterestToken * preSaleOptions.stakingRate ) / preSaleOptions.stakingRateDecimals;

        uint totalF =
            userCurrentInfo.startTimeTokenAmount +
            totalTokenFinal +
            userCurrentInfo.interestTokenBalance;

        require(address(token) != address(0), "Token not set. Call the admin.");
        require(availableTokens() > 0, "Insufficient liquidity. Call the admin.");
        require(totalF <= availableTokens(), "Insufficient liquidity. Buy less tokens");

        userCurrentInfo.preSaleCoinCheckout = totalCoin;
        userCurrentInfo.preSaleTokenCheckout = totalF;
        token.safeTransfer(msg.sender, totalF);

        emit ClaimTokensAfterStaking(msg.sender, totalF);
        return true;
    }

    /**
     * Transfers coin to Token contract address.
     */
    function transferTokens() public onlyOwner nonReentrant {
        if(_presaleContractCoinBalance() > 0) {
            (bool sent,) = msg.sender.call{value: _presaleContractCoinBalance()}('');
            require(sent, "Failed to send FTM");

            emit TransferCoinOwner(msg.sender, _presaleContractCoinBalance());
        }
    }

    /**
     * Transfers remaining tokens to Token contract address.
     */
    function transferTokensTk() public onlyOwner nonReentrant {
        if(availableTokens() > 0) {
            token.safeTransfer(owner(), availableTokens());
            emit TransferTokensOwner(msg.sender, availableTokens());
        }
    }

    /**
     * Transfers coin and remaining tokens to Token contract address.
     */
    function withdrawCoin() public whenNotPaused nonReentrant {
        require(preSaleOptions.isWithdrawCoinActive, "Withdraw coin is not active");

        (uint256 totalCoin,,,,,,,) = _tokenPrice(msg.sender);
        require(totalCoin > 0, "You did not pay");

        User storage userCurrentInfo = userInfo[msg.sender];
        require(
            userCurrentInfo.preSaleWithdrawPayout == 0
            ,
            "Not enought balance to withdraw");

        require(_presaleContractCoinBalance() >= totalCoin, "Not enough balance to withdraw. Call the admin");

        totalWithdrawCoin += totalCoin;
        (bool sent,) = msg.sender.call{value: totalCoin}('');
        require(sent, "Failed to send coin");

        userCurrentInfo.preSaleWithdrawPayout = totalCoin;

        emit WithdrawFund(msg.sender, totalCoin);
    }

    /**
     * Returns the coin balance of presale contract.
     */
    function _presaleContractCoinBalance() private view returns (uint256) {
        return address(this).balance;
    }

    /**
     * Returns the coin balance of presale contract.
     */
    function presaleContractCoinBalance() public view onlyOwner returns (uint256) {
        return _presaleContractCoinBalance();
    }

    /**
     * Returns the tokens balance of presale contract.
     */
    function availableTokens() public view returns (uint256) {
        return token.balanceOf(preSaleOptions.contractAddress);
    }

    /**
     *
     * Receive function
     *
     */
    receive() external payable {
        buyTokens(true);
    }

    /**
     * Returns the equivalent tokens of a coin amount.
     */
    function _tokenPrice(address callerAdress) private view returns (
        uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool) {

        User memory userCurrentInfo = userInfo[callerAdress];
        uint256 totalCoin = 0;
        uint256 totalToken = 0;
        uint256 totalTokenStep1 = 0;
        uint256 totalTokenStep2 = 0;
        uint256 totalTokenStep3 = 0;
        uint256 totalTokenStep4 = 0;
        if(userCurrentInfo.depositCoinValueStep1 != 0) {
            totalCoin += userCurrentInfo.depositCoinValueStep1;
            totalTokenStep1 = userCurrentInfo.depositCoinValueStep1 * preSaleOptions.rateStep1;
            totalToken += totalTokenStep1;
        }

        if(userCurrentInfo.depositCoinValueStep2 != 0) {
            totalCoin += userCurrentInfo.depositCoinValueStep2;
            totalTokenStep2 = userCurrentInfo.depositCoinValueStep2 * preSaleOptions.rateStep2;
            totalToken += totalTokenStep2;
        }

        if(userCurrentInfo.depositCoinValueStep3 != 0) {
            totalCoin += userCurrentInfo.depositCoinValueStep3;
            totalTokenStep3 = userCurrentInfo.depositCoinValueStep3 * preSaleOptions.rateStep3;
            totalToken += totalTokenStep3;
        }

        if(userCurrentInfo.depositCoinValueStep4 != 0) {
            totalCoin += userCurrentInfo.depositCoinValueStep4;
            totalTokenStep4 = userCurrentInfo.depositCoinValueStep4 * preSaleOptions.rateStep4;
            totalToken += totalTokenStep4;
        }

        uint256 totalTime = preSaleOptions.endStakingTime - userCurrentInfo.startTimeTime;
        uint256 totalInterestToken = userCurrentInfo.startTimeTokenAmount * totalTime;
        uint256 totalTokenFinal = ( totalInterestToken * preSaleOptions.stakingRate ) / preSaleOptions.stakingRateDecimals;

        uint totalF =
            userCurrentInfo.startTimeTokenAmount +
            totalTokenFinal +
            userCurrentInfo.interestTokenBalance;

        User memory userFInfo = userInfo[callerAdress];
        bool isFStakingActive = userFInfo.isStakingActive;

        return (
            totalCoin,
            totalToken,
            totalTokenStep1,
            totalTokenStep2,
            totalTokenStep3,
            totalTokenStep4,
            totalF,
            isFStakingActive
        );
    }

    /**
     *
     * Call tokenPrice() with msg sender
     *
     */
    function tokenPrice() public view returns(
        uint256, uint256, uint256, uint256, uint256, uint256, uint256, bool
    ) {
        return _tokenPrice(msg.sender);
    }

    /**
     * Adds tokens tokens liquidity to presale contract.
     */
    function addLiquidityToPresale(address payable _tokenContract, uint256 _amount) public onlyOwner returns (bool) {
        token = IERC20(_tokenContract);
        tokenMetadata = IERC20Metadata(_tokenContract);

        require(token.allowance(preSaleOptions.owner, preSaleOptions.contractAddress) >= _amount,
            "Get token approval first");

        require(token.balanceOf(msg.sender) >= _amount, "Owner balance is not enough");
        token.safeTransferFrom(preSaleOptions.owner, preSaleOptions.contractAddress, _amount);
        return true;
    }

    /**
     * Returns the balance of an address.
     */
    function balanceOf(address _address) public view returns (uint) {
        return token.balanceOf(_address);
    }

    /**
     * Returns the allowance of an address.
     */
    function allowance(address _owner, address _spender) public view returns (uint256) {
        return token.allowance(_owner, _spender);
    }

    /**
     * Allows Default Admin to pause the contract
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     *
     * Allows Default Admin to unpause the contract
     *
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     *
     * Get total paid coin amount
     *
     */
    function getTotalPaidCoin() public view onlyOwner returns(uint256) {
        return totalPaidCoin;
    }

    /**
     *
     * Get total bought token amount
     *
     */
    function getTotalBoughtToken() public view onlyOwner returns(uint256) {
        return totalBoughtToken;
    }

    /**
     *
     * Get total staked token amount
     *
     */
    function getTotalStakedToken() public view onlyOwner returns(uint256) {
        return totalStakedToken;
    }

    /**
     *
     * Get total withdraw coin
     *
     */
    function getTotalWithdrawCoin() public view onlyOwner returns(uint256) {
        return totalWithdrawCoin;
    }

    /**
     *
     * Set is presale active
     *
     */
    function setIsPreSaleActive() public onlyOwner returns(bool) {
        if(preSaleOptions.isPreSaleActive) {
            preSaleOptions.isPreSaleActive = false;
        } else {
            require(
                preSaleOptions.isPreSaleActive == false &&
                preSaleOptions.isWithdrawCoinActive == false &&
                preSaleOptions.isClaimActive == false &&
                preSaleOptions.isStakingActive == false,
                "You can not have two active state"
            );
            preSaleOptions.isPreSaleActive = true;
        }

        return true;
    }

    /**
     *
     * Set is claim active
     *
     */
    function setIsClaimActive() public onlyOwner returns(bool) {
        if(preSaleOptions.isClaimActive) {
            preSaleOptions.isClaimActive = false;
        } else {
            require(
                preSaleOptions.isPreSaleActive == false &&
                preSaleOptions.isWithdrawCoinActive == false &&
                preSaleOptions.isClaimActive == false &&
                preSaleOptions.isStakingActive == false,
                "You can not have two active state"
            );
            preSaleOptions.isClaimActive = true;
        }

        return true;
    }

    /**
     *
     * Set is claim active
     *
     */
    function setIsStakingActive() public onlyOwner returns(bool) {
        if(preSaleOptions.isStakingActive) {
            preSaleOptions.isStakingActive = false;
        } else {
            require(
                preSaleOptions.isPreSaleActive == false &&
                preSaleOptions.isWithdrawCoinActive == false &&
                preSaleOptions.isClaimActive == false &&
                preSaleOptions.isStakingActive == false,
                "You can not have two active state"
            );
            preSaleOptions.isStakingActive = true;
        }

        return true;
    }

    /**
     *
     * Set is claim active
     *
     */
    function setIsWithdrawCoinActive() public onlyOwner returns(bool) {
        if(preSaleOptions.isWithdrawCoinActive) {
            preSaleOptions.isWithdrawCoinActive = false;
        } else {
            require(
                preSaleOptions.isPreSaleActive == false &&
                preSaleOptions.isWithdrawCoinActive == false &&
                preSaleOptions.isClaimActive == false &&
                preSaleOptions.isStakingActive == false,
                "You can not have two active state"
            );
            preSaleOptions.isWithdrawCoinActive = true;
        }

        return true;
    }

    /**
     *
     * Set active step
     *
     */
    function setActiveStep(PreSaleSteps _activeStep) public onlyOwner returns(bool) {
        require(
            _activeStep == PreSaleSteps.Disable ||
            _activeStep == PreSaleSteps.Step1 ||
            _activeStep == PreSaleSteps.Step2 ||
            _activeStep == PreSaleSteps.Step3 ||
            _activeStep == PreSaleSteps.Step4,
            "Unacceptable entry"
        );
        preSaleOptions.activeStep = _activeStep;
        return true;
    }

    /**
     *
     * Set rate step
     *
     */
    function setRateStep(uint256 _rateStep1, uint256 _rateStep2,
        uint256 _rateStep3, uint256 _rateStep4) public onlyOwner returns(bool) {
        require(
            _rateStep1 != 0 &&
            _rateStep2 != 0 &&
            _rateStep3 != 0 &&
            _rateStep4 != 0,
            "Enter not zero values - setRateStep"
        );
        preSaleOptions.rateStep1 = _rateStep1;
        preSaleOptions.rateStep2 = _rateStep2;
        preSaleOptions.rateStep3 = _rateStep3;
        preSaleOptions.rateStep4 = _rateStep4;
        return true;
    }

    /**
     *
     * Set end staking time
     *
     */
    function setStakingEndTime(uint256 _endStakingTime) public onlyOwner returns(bool) {
        require(
            _endStakingTime != 0,
            "Enter not zero values - setStakingEndTime"
        );
        preSaleOptions.endStakingTime = _endStakingTime;
        return true;
    }

    /**
    *
    * Set staking rate
    *
    */
    function setStakingRate(uint256 _stakingRate, uint256 _stakingRateDecimals) public onlyOwner returns(bool) {
        require(
            _stakingRate != 0 &&
            _stakingRateDecimals != 0,
            "Enter not zero values - setStakingRate"
        );
        preSaleOptions.stakingRate = _stakingRate;
        preSaleOptions.stakingRateDecimals = _stakingRateDecimals;
        return true;
    }
}
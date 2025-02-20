// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
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


pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     *
     * CAUTION: See Security Considerations above.
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


pragma solidity ^0.8.20;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

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
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
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
     * {FailedInnerCall} error.
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
            revert AddressInsufficientBalance(address(this));
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
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
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
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
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
            revert FailedInnerCall();
        }
    }
}

pragma solidity ^0.8.20;




/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC20 token failed.
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
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
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
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
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
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return success && (returndata.length == 0 || abi.decode(returndata, (bool))) && address(token).code.length > 0;
    }
}


pragma solidity ^0.8.20;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev The `account` is missing a role.
     */
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    /**
     * @dev The caller of a function is not the expected one.
     *
     * NOTE: Don't confuse with {AccessControlUnauthorizedAccount}.
     */
    error AccessControlBadConfirmation();

    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     */
    function renounceRole(bytes32 role, address callerConfirmation) external;
}


pragma solidity ^0.8.20;


/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerable is IAccessControl {
    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}



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



pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
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
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}



pragma solidity ^0.8.20;


/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}



pragma solidity ^0.8.20;




/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address account => bool) hasRole;
        bytes32 adminRole;
    }

    mapping(bytes32 role => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with an {AccessControlUnauthorizedAccount} error including the required role.
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return _roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `_msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) public virtual {
        if (callerConfirmation != _msgSender()) {
            revert AccessControlBadConfirmation();
        }

        _revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual returns (bool) {
        if (!hasRole(role, account)) {
            _roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual returns (bool) {
        if (hasRole(role, account)) {
            _roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, _msgSender());
            return true;
        } else {
            return false;
        }
    }
}



// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

pragma solidity ^0.8.20;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position is the index of the value in the `values` array plus 1.
        // Position 0 is used to mean a value is not in the set.
        mapping(bytes32 value => uint256) _positions;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._positions[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We cache the value's position to prevent multiple reads from the same storage slot
        uint256 position = set._positions[value];

        if (position != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 valueIndex = position - 1;
            uint256 lastIndex = set._values.length - 1;

            if (valueIndex != lastIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the lastValue to the index where the value to delete is
                set._values[valueIndex] = lastValue;
                // Update the tracked position of the lastValue (that was just moved)
                set._positions[lastValue] = position;
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the tracked position for the deleted slot
            delete set._positions[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._positions[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}


pragma solidity ^0.8.20;




/**
 * @dev Extension of {AccessControl} that allows enumerating the members of each role.
 */
abstract contract AccessControlEnumerable is IAccessControlEnumerable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(bytes32 role => EnumerableSet.AddressSet) private _roleMembers;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view virtual returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view virtual returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Overload {AccessControl-_grantRole} to track enumerable memberships
     */
    function _grantRole(bytes32 role, address account) internal virtual override returns (bool) {
        bool granted = super._grantRole(role, account);
        if (granted) {
            _roleMembers[role].add(account);
        }
        return granted;
    }

    /**
     * @dev Overload {AccessControl-_revokeRole} to track enumerable memberships
     */
    function _revokeRole(bytes32 role, address account) internal virtual override returns (bool) {
        bool revoked = super._revokeRole(role, account);
        if (revoked) {
            _roleMembers[role].remove(account);
        }
        return revoked;
    }
}



pragma solidity ^0.8.0;

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
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
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
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}



pragma solidity ^0.8.20;


/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


//@author 0xPhant0m based on Ohm Bond Depository and Bond Protocol

pragma solidity ^0.8.27;  





contract BondDepository is AccessControlEnumerable, ReentrancyGuard {
  using SafeERC20 for IERC20;

    bytes32 public constant AUCTIONEER_ROLE = keccak256("AUCTIONEER_ROLE");
    bytes32 public constant TOKEN_WHITELISTER_ROLE = keccak256("TOKEN_WHITELISTER_ROLE");
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");

    bool public paused;


    event ContractPaused(address indexed by);
    event ContractUnpaused(address indexed by);
    event newBondCreated(uint256 indexed id, address indexed payoutToken, address indexed quoteToken, uint256 initialPrice );
    event BondEnded(uint256 indexed id);
    event addedAuctioneer(address _auctioneer, address payoutToken);
    event removeAuctioneer(address auctioneer);
    event MarketTransferred( uint256 marketId, address owner, address newAuctioneer);
    event BondDeposited( address indexed user,  uint256 indexed marketId,  uint256 depositAmount, uint256 totalOwed, uint256 bondPrice );
    event QuoteTokensWithdrawn( uint256 indexed marketId, address indexed auctioneer, uint256 amount, uint256 daoFee );
    event FeeUpdated (uint256 oldFee, uint256 basePoints);
    event TokenUnwhitelisted( address _token);
    event TokenWhitelisted( address _token);
 


    uint256 public marketCounter;
    address [] public _payoutTokens;
    Terms[] public terms;
    mapping(uint256 => Adjust) public adjustments;
    mapping (address => bool) _whitelistedAuctioneer;
    mapping (address => bool) _whitelistedToken;
    mapping(uint256 => address) public marketsToAuctioneers;
    mapping(address => uint256[]) public marketsForQuote;
    mapping(address => uint256[]) public marketsForPayout;
    mapping( address => Bond[]) public bondInfo; 
    address public immutable mSig;
    uint256 public feeToDao;
    uint256 public constant MAX_FEE = 1000; 


 // Info for creating new bonds
    struct Terms {
        address quoteToken; //token requested 
        address payoutToken; //token to be redeemed
        uint256 amountToBond; //Amount of payout Tokens dedicated to this request
        uint256 totalDebt;
        uint256 controlVariable; // scaling variable for price
        uint256 minimumPrice; // vs principle value
        uint256 maxDebt; // 9 decimal debt ratio, max % total supply created as debt
        uint256 maxPayout; // in thousandths of a %. i.e. 500 = 0.5%
        uint256 quoteTokensRaised; 
        uint256 lastDecay; 
        uint32 bondEnds; //Unix Timestamp of when the offer ends.
        uint32 vestingTerm; // How long each bond should vest for in seconds
    }

    struct Bond {
        address tokenBonded; //token to be distributed
        uint256 amountOwed; //amount of tokens owed to Bonder
        uint256 pricePaid; //price paid in PayoutToken
        uint256 marketId; //Which market does this belong
        uint32 startTime; // block timestamp
        uint32 endTime; //timestamp


    }

      struct Adjust {
        bool add; // addition or subtraction
        uint rate; // increment
        uint target; // BCV when adjustment finished
        uint buffer; // minimum length (in blocks) between adjustments
        uint lastBlock; // block when last adjustment made
      }


    constructor(address _mSig){
      if (_mSig == address (0)) revert ("Invalid address");
        mSig = _mSig;
     _grantRole(DEFAULT_ADMIN_ROLE, mSig);
       _grantRole(EMERGENCY_ADMIN_ROLE, mSig);
        _grantRole(TOKEN_WHITELISTER_ROLE, mSig);

    }

                                         /*================================= Auctioneer FUNCTIONS =================================*/

    function newBond( 
    address payoutToken_, 
    IERC20 _quoteToken,
    uint256 [4] memory _terms,  // [amountToBond, controlVariable, minimumPrice, maxDebt]
    uint32 [2] memory _vestingTerms  // [bondEnds, vestingTerm]
) external onlyRole(AUCTIONEER_ROLE) whenNotPaused returns (uint256 marketID) {
    // Address validations
    require(payoutToken_ != address(0), "Invalid payout token");
    require(address(_quoteToken) != address(0), "Invalid quote token");
    require(address(_quoteToken) != payoutToken_, "Tokens must be different");
    require(_whitelistedToken[payoutToken_], "Token not whitelisted");
    require(!auctioneerHasMarketForQuote(msg.sender, address(_quoteToken)), "Already has market for quote token");
    
    // Time validations
    require(_vestingTerms[0] > block.timestamp, "Bond end too early");
    require(_vestingTerms[1] > _vestingTerms[0], "Vesting ends before bond");
    
    // Parameter validations
    require(_terms[0] > 0, "Amount must be > 0");
    require(_terms[1] > 0, "Control variable must be > 0");
    require(_terms[2] > 0, "Minimum price must be > 0");
    require(_terms[3] > 0, "Max debt must be > 0");
    
    uint256 secondsToConclusion = _vestingTerms[0] - block.timestamp;
    require(secondsToConclusion > 0, "Invalid vesting period");
    
    // Calculate max payout with better precision
    uint256 _maxPayout = (_terms[3] * 1800) / 10000;  // 18% of max debt
    _maxPayout = (_maxPayout * 1e18) / secondsToConclusion;  // Scale by time
    
    // Transfer payout tokens (use amountToBond, not controlVariable)
    IERC20(payoutToken_).safeTransferFrom(msg.sender, address(this), _terms[0]);
    
    // Create market
    terms.push(Terms({
        quoteToken: address(_quoteToken),
        payoutToken: payoutToken_,
        amountToBond: _terms[0],
        controlVariable: _terms[1],
        minimumPrice: _terms[2],
        maxDebt: _terms[3],
        maxPayout: _maxPayout,
        quoteTokensRaised: 0,
        lastDecay: block.timestamp,
        bondEnds: _vestingTerms[0],
        vestingTerm: _vestingTerms[1],
        totalDebt: 0
    }));
    
    // Market tracking
    uint256 marketId = marketCounter;
    marketsForPayout[payoutToken_].push(marketId);
    marketsForQuote[address(_quoteToken)].push(marketId);
    marketsToAuctioneers[marketId] = msg.sender;
    
    ++marketCounter;
    emit newBondCreated(marketId, payoutToken_, address(_quoteToken), _terms[1]);
    
    return marketId;
}
  
    function closeBond(uint256 _id) external   onlyRole(AUCTIONEER_ROLE) 
        whenNotPaused  {
        if (marketsToAuctioneers[_id] != msg.sender) revert ("Not your Bond");
        terms[_id].bondEnds = uint32(block.timestamp);

        uint256 amountLeft = terms[_id].amountToBond - terms[_id].totalDebt;

         IERC20(terms[_id].payoutToken).safeTransfer(msg.sender, amountLeft);
 
        emit BondEnded(_id);
        }

        function withdrawQuoteTokens(uint256 _id) external onlyRole(AUCTIONEER_ROLE) whenNotPaused {
    // Ensure only the original auctioneer for this market can withdraw
    require(marketsToAuctioneers[_id] == msg.sender, "Not market's auctioneer");

    // Ensure bond has ended
    require(block.timestamp > terms[_id].bondEnds, "Bond not yet concluded");

    // Get the quote token and its balance
    address quoteToken = terms[_id].quoteToken;
    uint256 balance = terms[_id].quoteTokensRaised;

    // Calculate DAO fee if applicable
    uint256 daoFee = 0;
    if (feeToDao > 0) {
        daoFee = (balance * feeToDao) / 10000; // Assuming feeToDao is in basis points
        balance -= daoFee;
    }

    // safeTransfer quote tokens to auctioneer
    IERC20(quoteToken).safeTransfer(msg.sender, balance);

    // safeTransfer DAO fee if applicable
    if (daoFee > 0) {
        IERC20(quoteToken).safeTransfer(mSig, daoFee);
    }

    emit QuoteTokensWithdrawn(_id, msg.sender, balance, daoFee);
}
    
    function transferMarket(uint256 marketId, address newAuctioneer) external {
    require(marketsToAuctioneers[marketId] == msg.sender, "Not market owner");
    require(hasRole(AUCTIONEER_ROLE, newAuctioneer), "Not auctioneer");
    marketsToAuctioneers[marketId] = newAuctioneer;
    emit MarketTransferred(marketId, msg.sender, newAuctioneer);
}

                             /*================================= User FUNCTIONS =================================*/
    function deposit(uint256 _id, uint256 amount, address user) public nonReentrant {
        // Early validation checks
        require(user != address(0), "Invalid user address");
        require(_id < terms.length, "Invalid market ID");
    
        // Retrieve the specific bond terms
        Terms storage term = terms[_id];

        // Comprehensive bond availability checks
        require(block.timestamp <= term.bondEnds, "Bond has ended");
        require(term.totalDebt < term.maxDebt, "Maximum bond capacity reached");

        // Decimal-aware minimum deposit calculation
        uint8 quoteDecimals = IERC20Metadata(address(term.quoteToken)).decimals();
        uint256 minimumDeposit = calculateMinimumDeposit(quoteDecimals);

        // Deposit amount validations
        require(amount >= minimumDeposit, "Deposit below minimum threshold");
        require(amount <= term.maxPayout, "Deposit exceeds maximum allowed");

        // Reentrancy protection pattern
        // Decay debt before any state changes
        _tune(_id);
        _decayDebt(_id);

        // Transfer tokens with safety checks
        IERC20 quoteToken = IERC20(term.quoteToken);
        uint256 balanceBefore = quoteToken.balanceOf(address(this));
        quoteToken.safeTransferFrom(msg.sender, address(this), amount); 
        uint256 balanceAfter = quoteToken.balanceOf(address(this));
        require(balanceAfter - balanceBefore == amount, "Incorrect transfer amount");
        terms[_id].quoteTokensRaised += amount;
        // Calculate bond price with internal function
        uint256 price = _marketPrice(_id);

        // Precise total owed calculation
        uint256 totalOwed = calculateTotalOwed(amount, price);
        address payoutToken = term.payoutToken;

        // Validate total owed against remaining bond capacity
        require(term.totalDebt + totalOwed <= term.maxDebt, "Exceeds maximum bond debt");

        // Create bond record with comprehensive details
        bondInfo[user].push(Bond({
            tokenBonded: payoutToken,
            amountOwed: totalOwed, 
            pricePaid: price,
            marketId: _id,
            startTime: uint32(block.timestamp),
            endTime: uint32(term.vestingTerm + block.timestamp)
        }));

        // Update total debt
        term.totalDebt += totalOwed;

        emit BondDeposited(user, _id, amount, totalOwed, price);
    }

  function redeem(uint256 _id, address user) external nonReentrant returns (uint256 amountRedeemed) {
    uint256 length = bondInfo[user].length; 
    uint256 totalRedeemed = 0;

    // Iterate backwards to safely remove elements
    for (uint256 i = length; i > 0;) {
        i--;  // decrement here to avoid underflow
        
        Bond storage currentBond = bondInfo[user][i];
        if (currentBond.marketId == _id) {
            uint256 amount = calculateLinearPayout(user, i);
            
            if (amount > 0) {
                // Update state before transfer
                currentBond.amountOwed -= amount;
                totalRedeemed += amount;
                
                // Perform transfer
                IERC20(terms[_id].payoutToken).safeTransfer(user, amount);
                
                // If fully redeemed, remove bond
                if (currentBond.amountOwed == 0) {
                    // Move the last element to current position and pop
                    if (i != bondInfo[user].length - 1) {
                        bondInfo[user][i] = bondInfo[user][bondInfo[user].length - 1];
                    }
                    bondInfo[user].pop();
                }
            }
        }
    }
    
    return totalRedeemed;
}



    
  
                           /*================================= ADMIN FUNCTIONS =================================*/

    function grantAuctioneerRole(address _auctioneer) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        // Additional validation
        require(_auctioneer != address(0), "Invalid auctioneer address");
        require(!hasRole(AUCTIONEER_ROLE, _auctioneer), "Already an auctioneer");

        _grantRole(AUCTIONEER_ROLE, _auctioneer);
        _whitelistedAuctioneer[_auctioneer] = true;
        emit RoleGranted(AUCTIONEER_ROLE, _auctioneer, msg.sender);
    }

    function revokeAuctioneerRole(address _auctioneer) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        _revokeRole(AUCTIONEER_ROLE, _auctioneer);
        _whitelistedAuctioneer[_auctioneer] = false;
        emit RoleRevoked(AUCTIONEER_ROLE, _auctioneer, msg.sender);
    }

     function whitelistToken(address _token) 
        external 
        onlyRole(TOKEN_WHITELISTER_ROLE) 
    {
        require(_token != address(0), "Invalid token address");
        require(!_whitelistedToken[_token], "Token already whitelisted");

        // Additional token validation
        try IERC20Metadata(_token).decimals() returns (uint8) {
            _whitelistedToken[_token] = true;
            _payoutTokens.push(_token);
        } catch {
            revert("Invalid ERC20 token");
        }
    }

    function unwhitelistToken(address _token) external onlyRole(TOKEN_WHITELISTER_ROLE) {
    require(_whitelistedToken[_token], "Token not whitelisted");
    _whitelistedToken[_token] = false;
    emit TokenUnwhitelisted(_token);
}
    

     function pauseContract() 
        external 
        onlyRole(EMERGENCY_ADMIN_ROLE) 
    {
        paused = true;
        emit ContractPaused(msg.sender);
    }

    function unpauseContract() 
        external 
        onlyRole(EMERGENCY_ADMIN_ROLE) 
    {
        paused = false;
        emit ContractUnpaused(msg.sender);
    }

   function setFeetoDao(uint32 basePoints) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(basePoints <= MAX_FEE, "Fee too high");
    uint256 oldFee = feeToDao;
    feeToDao = basePoints;
    emit FeeUpdated(oldFee, basePoints);
}

                            /*================================= View Functions =================================*/

    function getMarketsForQuote(address quoteToken) external view returns(uint256[] memory) {
         return marketsForQuote[quoteToken];
    }

    function getMarketsForPayout(address payout) external view returns(uint256[] memory) {
           return marketsForPayout[payout];
    }

    function getMarketsForUser(address user) external view returns(uint256[] memory) {
            uint256[] memory userMarkets = new uint256[](bondInfo[user].length);
    for (uint256 i = 0; i < bondInfo[user].length; i++) {
        userMarkets[i] = bondInfo[user][i].marketId;
    }
    return userMarkets;
    }
    
     function isLive(uint256 id_) public view returns (bool) {
         return block.timestamp <= terms[id_].bondEnds && terms[id_].totalDebt < terms[id_].maxDebt;
}
     
    
    function bondPrice(uint256 id_) public view returns(uint256) {
         return _trueBondPrice(id_);

  }

  
    function isAuctioneer(address account) external view returns (bool) {
        return hasRole(AUCTIONEER_ROLE, account);
    }

    function calculateLinearPayout(address user, uint256 _bondId) public view returns (uint256) {
    Bond memory bond = bondInfo[user][_bondId];
    Terms memory term = terms[bond.marketId];

    // Check if bond is active
    if (block.timestamp < bond.startTime) {
        return 0;
    }

    // Calculate total vesting duration
    uint256 vestingTerm = term.vestingTerm;

    // Calculate time elapsed since bond start
    uint256 timeElapsed = block.timestamp > bond.endTime 
        ? vestingTerm 
        : block.timestamp - bond.startTime;

    // Calculate tokens per second
    uint256 tokensPerSecond = bond.amountOwed / vestingTerm;

    // Calculate current claimable amount
    uint256 currentClaimable = tokensPerSecond * timeElapsed;

    // Ensure we don't claim more than the total owed
    if (currentClaimable > bond.amountOwed) {
        currentClaimable = bond.amountOwed;
    }

    return currentClaimable;
}

  function payoutFor(address user, uint256 _bondId) public view returns (uint256 amount) {
    return calculateLinearPayout(user, _bondId);
}

   function isMature(address user, uint256 _bondId) public view returns (bool) {
    Bond memory bond = bondInfo[user][_bondId];
    return block.timestamp >= bond.endTime;
}
                             /*================================= Internal Functions =================================*/


    function _decayDebt(uint256 _id) internal {
    Terms storage term = terms[_id];

    // Get current debt and control variable
    uint256 currentDebt = term.totalDebt;
    if (currentDebt == 0) return;

    // Get seconds since market was created (block.timestamp - (bondEnds - length))
    uint256 secondsSinceLastDecay = block.timestamp - term.lastDecay;
    
    // Return if market not active
    if (secondsSinceLastDecay == 0) return;

    // Calculate decay rate based on target vesting time
    uint256 decay = currentDebt * secondsSinceLastDecay / term.vestingTerm;
    
    // Update stored debt
    term.totalDebt = currentDebt - decay;
    term.lastDecay = uint32(block.timestamp);
}


        function _tune(uint256 _id) internal{
            if (block.timestamp > adjustments[_id].lastBlock + adjustments[_id].buffer) {
        Terms storage term = terms[_id];
        
        if (adjustments[_id].add) {
            term.controlVariable += adjustments[_id].rate;
            
            if (term.controlVariable >= adjustments[_id].target) {
                term.controlVariable = adjustments[_id].target;
            }
        } else {
            term.controlVariable -= adjustments[_id].rate;
            
            if (term.controlVariable <= adjustments[_id].target) {
                term.controlVariable = adjustments[_id].target;
            }
        }
        
        adjustments[_id].lastBlock = uint32(block.timestamp);
    }

        }

    function _marketPrice(uint256 _id) internal view returns (uint256 price) {
    Terms memory term = terms[_id];
    
    // Get decimals for both tokens for precise calculations
    uint8 payoutDecimals = IERC20Metadata(address(term.payoutToken)).decimals();
    uint8 quoteDecimals = IERC20Metadata(address(term.quoteToken)).decimals();
    
    // Get current control variable and debt ratio
    uint256 currentCV = _currentControlVariable(_id);
    uint256 debtRatio = _debtRatio(_id);
    
    // Scale up before division to maintain precision
    // Use a higher precision factor (1e36) to prevent overflow while maintaining precision
    uint256 scaledPrice = (currentCV * debtRatio) * (10 ** (36 - payoutDecimals - quoteDecimals));
    
    // Perform division last to minimize precision loss
    // Divide by 1e18 twice because debtRatio is scaled by 1e18 and we want final precision of 1e18
    price = scaledPrice / 1e18 / 1e18;
    
    // Apply minimum price check after all calculations
    if (price < term.minimumPrice) {
        price = term.minimumPrice;
    }
    
    // Add safety check for maximum price to prevent unreasonable values
    // This value should be adjusted based on your specific needs
    require(price <= type(uint256).max / 1e18, "Price overflow");
}

        
        function _trueBondPrice(uint256 _id) internal view returns(uint256 price){
            
            price = _marketPrice(_id);
        }

     function _debtRatio(uint256 _id) internal view returns (uint256) {
  
    Terms memory term = terms[_id];
    
    // Get decimals for precise calculation
    uint8 quoteDecimals = uint8(IERC20Metadata(address(term.quoteToken)).decimals());
    uint8 payoutDecimals = uint8(IERC20Metadata(address(term.payoutToken)).decimals());

    // Normalize totalDebt to 18 decimals (totalDebt is in payoutToken)
    uint256 totalDebt = term.totalDebt * (10**(18 - payoutDecimals));
    
    // Normalize quote tokens raised to 18 decimals
    uint256 quoteBalance = term.quoteTokensRaised * (10 ** (18 - quoteDecimals));
    
    // Prevent division by zero
    if (quoteBalance == 0) {
        return type(uint256).max; // Maximum possible debt ratio
    }

    // Calculate debt ratio with high precision
    // Result is scaled to 1e18
    uint256 debtRatio = (totalDebt * 1e18) / quoteBalance;
    
    return debtRatio;
}

         function _currentControlVariable(uint256 _id) internal view returns (uint256) {
    Terms memory term = terms[_id];
    Adjust memory adjustment = adjustments[_id];

    // Base control variable
    uint256 baseCV = term.controlVariable;

    // Market-adaptive decay calculation
    uint256 currentDebtRatio = _debtRatio(_id);
    uint256 timeSinceBondStart = block.timestamp > term.bondEnds 
        ? block.timestamp - term.bondEnds 
        : 0;
    
    // Adaptive decay rate based on debt ratio
    // Higher debt ratio accelerates decay
    uint256 adaptiveDecayRate = (currentDebtRatio * 1e18) / term.maxDebt;
    
    // Calculate decay amount
    uint256 decayAmount = (baseCV * adaptiveDecayRate) / (timeSinceBondStart + 1);

    // Apply ongoing adjustment if within adjustment window
    if (block.timestamp <= adjustment.lastBlock + adjustment.buffer) {
        if (adjustment.add) {
            // Increasing control variable
            baseCV += adjustment.rate;
            
            // Cap at target if exceeded
            if (baseCV > adjustment.target) {
                baseCV = adjustment.target;
            }
        } else {
            // Decreasing control variable
            baseCV -= adjustment.rate;
            
            // Floor at target if fallen below
            if (baseCV < adjustment.target) {
                baseCV = adjustment.target;
            }
        }
    }

    // Apply decay
    if (baseCV > decayAmount) {
        return baseCV - decayAmount;
    }
    
    return 0;
}

    // Helper function for minimum deposit calculation
        function calculateMinimumDeposit(uint8 decimals) internal pure returns (uint256) {
    // Ensures meaningful deposit across different token decimal configurations
          if (decimals > 2) {
          return 10 ** (decimals - 2);  // 1% of smallest token unit
    }
        return 1;  // Fallback for tokens with very few decimals
}

        // Helper function for precise owed calculation
        function calculateTotalOwed(uint256 amount, uint256 price) internal pure returns (uint256) {

         return (amount * price) / 1e18;
}

    function auctioneerHasMarketForQuote(address auctioneer, address quoteToken) public view returns (bool) {
    uint256[] memory markets = marketsForQuote[quoteToken];
    for(uint256 i = 0; i < markets.length; i++) {
        if(marketsToAuctioneers[markets[i]] == auctioneer) {
            return true;
        }
    }
    return false;
}

          modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
 
}
// SPDX-License-Identifier: Apache-2.0
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.20;

import "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_extensions_AccessControlDefaultAdminRulesUpgradeable.sol";

/**
 * @title Blacklistable
 * @dev Contract that allows blacklisting of accounts.
 *  We are using the last bit of the balance to store the blacklist state.
 */
contract Blacklistable is
    AccessControlDefaultAdminRulesUpgradeable,
    ERC20Upgradeable
{
    // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC20")) - 1)) & ~bytes32(uint256(0xff))
    // From OpenZeppelin Contracts
    bytes32 private constant ERC20StorageLocation =
        0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;

    // Constants for bitmask operations
    /**
     * @dev This keeps balance bits (clears blacklist bit).
     */
    uint256 private constant BALANCE_MASK = ~uint256(1 << 255);

    /**
     * @dev This represents blacklist bit.
     */
    uint256 private constant BLACKLIST_MASK = uint256(1 << 255);

    /**
     * @dev This role grants the ability to blacklist addresses, preventing them from
     * performing certain actions or interacting with the contract.
     * Additionally, this role allows the holder to unblacklist addresses,
     * restoring their ability to interact with the contract.
     */
    bytes32 public constant BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");

    // --- Events ---
    /**
     * @dev Emitted when an `account` is blacklisted.
     */
    event Blacklisted(address indexed account);

    /**
     * @dev Emitted when an `account` is removed from the blacklist.
     */
    event Unblacklisted(address indexed account);

    // --- Custom Errors ---
    /**
     * @dev The operation failed because the amount exceeded the allowable range for the specified bit size.
     */
    error AmountOverflowed();

    /**
     * @dev Checks if an account is blacklisted.
     * @param account The address to check.
     * @return A boolean indicating whether the account is blacklisted or not.
     */
    function isBlacklisted(address account) public view returns (bool) {
        ERC20Storage storage $ = getERC20Storage();
        return ($._balances[account] & BLACKLIST_MASK) == BLACKLIST_MASK;
    }

    /**
     * @dev Blacklists an account.
     * @param account The address to blacklist.
     */
    function blacklist(
        address account
    ) external onlyRole(BLACKLISTER_ROLE) {
        _setBlacklistState(account, true);
    }

    /**
     * @dev Blacklists a set of accounts.
     * @param accounts The addresses to blacklist.
     */
    function blacklistBatch(
        address[] memory accounts
    ) external onlyRole(BLACKLISTER_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            _setBlacklistState(accounts[i], true);
        }
    }

    /**
     * @dev Unblacklists an account.
     * @param account The address to unblacklist.
     */
    function unblacklist(
        address account
    ) external onlyRole(BLACKLISTER_ROLE) {
        _setBlacklistState(account, false);
    }

    /**
     * @dev Unblacklists a set of accounts.
     * @param accounts The addresses to unblacklist.
     */
    function unblacklistBatch(
        address[] memory accounts
    ) external onlyRole(BLACKLISTER_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            _setBlacklistState(accounts[i], false);
        }
    }

    /**
     * @dev Fetches the balance of an account.
     * @param account The address to fetch the balance for.
     * @return The balance of the account.
     */
    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        ERC20Storage storage $ = getERC20Storage();
        return $._balances[account] & BALANCE_MASK;
    }

    /**
     * @dev Sets the blacklist state of an account.
     * @param account The address to set the blacklist state for.
     * @param state The blacklist state to set.
     */
    function _setBlacklistState(address account, bool state) internal {
        ERC20Storage storage $ = getERC20Storage();
        if (state) {
            $._balances[account] |= BLACKLIST_MASK; // Set blacklist bit
            emit Blacklisted(account);
        } else {
            $._balances[account] &= BALANCE_MASK; // Clear blacklist bit
            emit Unblacklisted(account);
        }
    }

    /**
     * @dev Updates the balances and total supply when a transfer occurs.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to transfer.
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        ERC20Storage storage $ = getERC20Storage();
        if (from == address(0)) {
            // The rest of the code assumes that totalSupply never overflows
            $._totalSupply += value;

            // Ensure the total supply does not exceed 255 bits, 
            // as the highest bit is reserved for the blacklist flag.
            if ($._totalSupply & BLACKLIST_MASK != 0) {
                revert AmountOverflowed();
            }
        } else {
            uint256 fromBalance = $._balances[from] & BALANCE_MASK;
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance.
                $._balances[from] -= value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                $._totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: totalSupply validation ensures balances remain within limits.
                $._balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Retrieves the storage location of the ERC20 contract.
     * @return $ The storage location of the ERC20 contract.
     */
    function getERC20Storage() private pure returns (ERC20Storage storage $) {
        assembly {
            $.slot := ERC20StorageLocation
        }
    }
}
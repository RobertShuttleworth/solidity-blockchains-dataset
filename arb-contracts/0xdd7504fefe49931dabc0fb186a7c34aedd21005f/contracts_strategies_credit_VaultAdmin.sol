// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IVaultAdmin} from "./contracts_interfaces_IVaultAdmin.sol";
import {MutualConsent} from "./lib_Line-Of-Credit-v2_contracts_utils_MutualConsent.sol";

/**
 * @title  - VaultAdmin
 * @author - Credit Cooperative
 * @notice - Provides functions update vault adminstrative roles including the manager, operator, protocol treasury, and whitelisted addresses.
 * @dev    - State changing functions are only callable by allowed roles.
 */
abstract contract VaultAdmin is MutualConsent, IVaultAdmin {
    // protocol address that accrues fees
    address public protocolTreasury;

    // vault manager who directs funds into lines of credit
    address public manager;

    // addresses by the vault manager to conduct vault operations
    mapping(address => bool) public isOperator;

    mapping(address => bool) public whitelistedAddresses;
    bool public whitelistEnabled = true;

    /* ============ Constants ============ */
    uint256 public constant ONE_YEAR_IN_SECONDS = 365.25 days;
    uint256 public constant FEE_COEFFICIENT = 10000; // 100 bps = 1%; 100% = 10000

    /// @notice The base unit of the underlying token and hence vault.
    /// @dev Equal to 10 ** decimals. Used withdrawfor fixed point arithmetic.
    uint256 public immutable baseUnit;

    /*///////////////////////////////////////////////////////////////
                        ACCESS CONTROL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice - Checks `msg.sender` is `manager`.
     */
    function _onlyVaultManager() internal view {
        if (msg.sender != manager) {
            revert OnlyVaultManager();
        }
    }

    /**
     * @notice - Checks `msg.sender` is `manager` or `operator`.
     */
    function _onlyOperator() internal view {
        if (!isOperator[msg.sender]) {
            revert OnlyOperator();
        }
    }

    /**
     * @notice - Checks `msg.sender` is `protocolTreasury`.
     */
    function _onlyProtocolTreasury() internal view {
        if (msg.sender != protocolTreasury) {
            revert OnlyProtocolTreasury();
        }
    }

    /**
     * @notice - Checks target address is not the zero address.
     */
    function _cannotBeZeroAddress(address target) internal pure {
        if (target == address(0)) {
            revert CannotBeZeroAddress();
        }
    }


    /**
     * @notice - Modifies the `whitelistEnabled` state.
     * @dev    - Only callable by `manager`.
     * @param status - If True then whitelist is enabled, if False then whitelist is disabled.
     */
    function updateWhitelistStatus(bool status) external {
        _onlyVaultManager();
        if (status) {
            whitelistEnabled = true;
        } else {
            whitelistEnabled = false;
        }
        emit SetWhitelistStatus(status);
    }



    /**
     * @notice  - Adds an address to the whitelist.
     * @dev     - Only callable by `manager`.
     * @dev     - Cannot whitelist the zero address.
     * @param depositor - Address to update whitelist status.
     * @param approved  - If True then address is whitelisted, if False then address is not whitelisted.
     */
    function updateWhitelist(address depositor, bool approved) external {
        _onlyVaultManager();
        _cannotBeZeroAddress(depositor);

        emit UpdateWhitelist(depositor, approved);
        whitelistedAddresses[depositor] = approved;
    }

    /**
     * @notice  - Updates the manager of the vault and makes the manager an `operator`.
     * @dev     - Only callable by `manager`.
     * @dev     - The new manager cannot be set to the zero address.
     * @param newManager - Address of the new manager.
     */
    function setManager(address newManager) external {
        _onlyVaultManager();
        _cannotBeZeroAddress(newManager);

        emit SetManager(newManager);
        setOperator(newManager, true);
        manager = newManager;
    }

    /**
     * @notice  - Updates the operator of the vault.
     * @dev     - Only callable by `manager`.
     * @dev     - The new operator cannot be set to the zero address.
     * @param operator - Address of the new operator.
     * @param approved - whether the operator is approved or not
     */
    function setOperator(address operator, bool approved) public {
        _onlyVaultManager();
        _cannotBeZeroAddress(operator);

        emit SetOperator(operator, approved);
        isOperator[operator] = approved;
    }

    /**
     * @notice  - Updates the treasury address of the vault.
     * @dev     - Only callable by `protocolTreasury`.
     * @dev     - The new treasury cannot be set to the zero address.
     * @param newProtocolTreasury - Address of the new treasury.
     */
    function setProtocolTreasury(address newProtocolTreasury) external {
        _onlyProtocolTreasury();
        _cannotBeZeroAddress(newProtocolTreasury);

        emit SetProtocolTreasury(newProtocolTreasury);
        protocolTreasury = newProtocolTreasury;
    }
}
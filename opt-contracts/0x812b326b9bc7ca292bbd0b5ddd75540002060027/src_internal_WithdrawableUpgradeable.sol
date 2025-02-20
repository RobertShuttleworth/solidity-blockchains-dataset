// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { Roles } from "./src_constants_RoleConstants.sol";
import { Currency, CurrencyLibrary } from "./src_libraries_Currency.sol";
import { AccessControlEnumerableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_extensions_AccessControlEnumerableUpgradeable.sol";

import { InvalidFeeRecipient } from "./src_errors_Errors.sol";

/**
 * @title Withrdawable
 * @notice Withrdawable contract is responsible for withdrawing funds from the contract
 */
contract WithdrawableUpgradeable is AccessControlEnumerableUpgradeable {
    /**
     * @notice Withdraws the specified amount of tokens to the owner address
     * @param token_ The address of the token to withdraw
     * @param amount_ The amount to withdraw
     */
    function rescue(Currency token_, uint256 amount_) external onlyRole(Roles.TREASURER_ROLE) {
        address admin = getRoleMember(DEFAULT_ADMIN_ROLE, 0);

        if (admin == address(0)) {
            revert InvalidFeeRecipient();
        }

        if (token_.isNative()) {
            CurrencyLibrary.transferETH(admin, amount_);
        } else {
            token_.transfer(admin, amount_);
        }
    }
}
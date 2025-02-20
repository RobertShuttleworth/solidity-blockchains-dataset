// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "./contracts_token_ERC20_IERC20.sol";
import "./contracts_token_ERC20_utils_SafeERC20.sol";
import "./contracts_Libraries_LibDiamond.sol";
import {Swapper} from "./contracts_Helpers_Swapper.sol";

/// @title Allowance Facet
/// @notice clears allowance for a token
contract AllowanceFacet is Swapper {
    /// Events ///

    event LogClear(address indexed token);

    /// External Methods ///

    /// @notice clears allowance for a token
    /// @param token The token to clear the allowance for
    /// @param spenders The addresses to clear the allowance for
    function clearAllowance(address token, address[] memory spenders) external {
        LibDiamond.enforceIsContractOwner();

        for (uint256 i = 0; i < spenders.length; i++) {
            SafeERC20.safeApprove(IERC20(token), spenders[i], 0);
        }

        emit LogClear(token);
    }
}
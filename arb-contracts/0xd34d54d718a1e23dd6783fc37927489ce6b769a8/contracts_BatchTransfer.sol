// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

/// @title BatchTransfer
/// @dev This contract allows the owner to transfer tokens to multiple address in a single transaction. The point is to save gas.
contract BatchTransfer is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public token;

    constructor(IERC20 _token) Ownable(msg.sender) {
        token = _token;
    }

    /// This function allows the owner to transfer tokens to multiple address in a single transaction.
    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external onlyOwner {
        require(
            recipients.length == amounts.length,
            "Arrays must have the same length"
        );

        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 amount = amounts[i];
            address recipient = recipients[i];

            token.safeTransferFrom(msg.sender, recipient, amount);
        }
    }

    /// This function allows the owner to recover any amount of tokens sent to the contract
    function recoverTokens(uint256 amount, IERC20 _token) external onlyOwner {
        _token.safeTransfer(msg.sender, amount);
    }
}
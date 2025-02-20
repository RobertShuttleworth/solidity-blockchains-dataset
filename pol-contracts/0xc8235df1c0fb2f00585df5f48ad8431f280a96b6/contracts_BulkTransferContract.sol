// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract BulkTransferContract is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    event ERC20Transfer(
        uint64 campaignId,
        uint64 communityId,
        address token,
        address[] recipients,
        uint256[] amounts
    );
    event NativeTransfer(
        uint64 campaignId,
        uint64 communityId,
        address[] recipients,
        uint256[] amounts
    );

    error ArrayLengthMismatch();
    error EmptyTransfersArray();
    error InvalidRecipientAddress();
    error InvalidAmount();
    error TransferFailed();
    error IncorrectTotalAmount();

    constructor() Ownable(msg.sender) {}

    function bulkTransferERC20Token(
        uint64 campaignId,
        uint64 communityId,
        address token,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        if (recipients.length == 0) revert EmptyTransfersArray();
        if (recipients.length != amounts.length) revert ArrayLengthMismatch();

        IERC20 erc20Token = IERC20(token);

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0) || amounts[i] == 0) {
                continue;
            }

            erc20Token.safeTransferFrom(msg.sender, recipients[i], amounts[i]);
        }
        emit ERC20Transfer(campaignId, communityId, token, recipients, amounts);
    }

    function bulkTransferNativeToken(
        uint64 campaignId,
        uint64 communityId,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external payable nonReentrant {
        if (recipients.length == 0) revert EmptyTransfersArray();
        if (recipients.length != amounts.length) revert ArrayLengthMismatch();

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < recipients.length; i++) {
            if (recipients[i] == address(0)) revert InvalidRecipientAddress();
            if (amounts[i] == 0) revert InvalidAmount();
            totalAmount += amounts[i];
            if (totalAmount > msg.value) revert IncorrectTotalAmount();
            (bool success, ) = payable(recipients[i]).call{value: amounts[i]}(
                ""
            );
            if (!success) revert TransferFailed();
        }
        emit NativeTransfer(campaignId, communityId, recipients, amounts);
    }

    function withdrawERC20Token(
        address token,
        uint256 amount
    ) external onlyOwner {
        if (amount == 0) revert InvalidAmount();
        IERC20 erc20Token = IERC20(token);
        erc20Token.safeTransfer(msg.sender, amount);
    }

    function withdrawNativeToken(uint256 amount) external onlyOwner {
        if (amount == 0) revert InvalidAmount();
        if (amount > address(this).balance) revert IncorrectTotalAmount();
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
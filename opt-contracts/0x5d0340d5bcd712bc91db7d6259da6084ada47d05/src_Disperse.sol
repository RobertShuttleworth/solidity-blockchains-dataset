// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";

contract Disperse is Ownable(msg.sender) {
    using SafeERC20 for IERC20;

    receive() external payable {}

    function disperseEther(
        address[] memory recipients,
        uint256[] memory values
    ) external payable {
        for (uint256 i = 0; i < recipients.length; i++) {
            payable(recipients[i]).transfer(values[i]);
        }
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(msg.sender).transfer(balance);
        }
    }

    function disperseToken(
        IERC20 token,
        address[] memory recipients,
        uint256[] memory values
    ) external {
        uint256 total = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            total += values[i];
        }
        token.safeTransferFrom(msg.sender, address(this), total);
        for (uint256 i = 0; i < recipients.length; i++) {
            token.safeTransfer(recipients[i], values[i]);
        }
    }

    function disperseTokenSimple(
        IERC20 token,
        address[] memory recipients,
        uint256[] memory values
    ) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            token.safeTransferFrom(msg.sender, recipients[i], values[i]);
        }
    }

    function disperseEtherSameValue(
        address[] memory recipients,
        uint256 value
    ) external payable {
        for (uint256 i = 0; i < recipients.length; i++) {
            payable(recipients[i]).transfer(value);
        }
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(msg.sender).transfer(balance);
        }
    }

    function disperseTokenSameValue(
        IERC20 token,
        address[] memory recipients,
        uint256 value
    ) external {
        uint256 total = value * recipients.length;
        require(token.transferFrom(msg.sender, address(this), total));
        for (uint256 i = 0; i < recipients.length; i++) {
            require(token.transfer(recipients[i], value));
        }
    }

    function withdraw(IERC20 token) external onlyOwner {
        token.safeTransfer(owner(), token.balanceOf(address(this)));
        payable(owner()).transfer(address(this).balance);
    }
}
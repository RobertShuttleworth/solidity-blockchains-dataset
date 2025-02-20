// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import {ERC20Permit} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_ERC20Permit.sol";
import {ERC20Votes} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_ERC20Votes.sol";
import {ERC20Yield} from "./src_ERC20Yield.sol";
import {Nonces} from "./lib_openzeppelin-contracts_contracts_utils_Nonces.sol";
import {Ownable} from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import {ReentrancyGuard} from "./lib_openzeppelin-contracts_contracts_utils_ReentrancyGuard.sol";

contract TokenETH is ERC20, ReentrancyGuard, Ownable, ERC20Permit, ERC20Votes, ERC20Yield {
    event ETHRefunded(address recipient, uint256 amount);
    event TokensMinted(address recipient, uint256 amount);

    constructor(address defaultAdmin, uint256 yieldInterval, int256 yieldRate)
        ERC20("TokenETH", "TETH")
        Ownable(defaultAdmin)
        ERC20Permit("TokenETH")
        ERC20Yield(yieldInterval, yieldRate)
    {}

    receive() external payable {
        _mintTokensForETH(msg.sender, msg.value);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _calculateBalance(account, super.balanceOf(account));
    }

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    function _mintTokensForETH(address recipient, uint256 amount) internal {
        require(amount > 0, "ETH amount must be greater than zero");

        _mint(recipient, amount);

        emit TokensMinted(recipient, amount);
    }

    function _refundETH(address recipient, uint256 amount) internal nonReentrant {
        require(amount > 0, "Token amount must be greater than zero");
        require(balanceOf(recipient) >= amount, "Insufficient token balance");
        require(address(this).balance >= amount, "Insufficient ETH in contract");

        _burn(recipient, amount);
        (bool success,) = recipient.call{value: amount}("");
        require(success, "ETH transfer failed");

        emit ETHRefunded(recipient, amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes, ERC20Yield) {
        if (to == address(this)) {
            _refundETH(from, value);
        } else {
            super._update(from, to, value);
        }
    }
}
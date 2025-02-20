// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

library Tokens {

    using SafeERC20 for IERC20;

    event TokensReceived(address tokenAddress, address from, uint256 amount);
    event TokensSent(address tokenAddress, address to, uint256 amount);
    event TokensBurnt(address tokenAddress, uint256 amount);

    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    function receiveTokensFrom(IERC20 token, address from, uint256 amount) internal returns (uint256) {
        uint256 startingBalance = token.balanceOf(address(this));
        token.safeTransferFrom(from, address(this), amount);
        uint256 received = token.balanceOf(address(this)) - startingBalance;
        emit TokensReceived(address(token), from, received);
        return received;
    }

    function sendTokensTo(IERC20 token, address to, uint256 amount) internal {
        token.safeTransfer(to, amount);
        emit TokensSent(address(token), to, amount);
    }

    function burnTokens(IERC20 token, uint256 amount) internal {
        token.safeTransfer(DEAD_ADDRESS, amount);
        emit TokensBurnt(address(token), amount);
    }

}
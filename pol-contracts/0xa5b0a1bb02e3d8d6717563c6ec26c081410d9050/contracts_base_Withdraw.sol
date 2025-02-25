// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

contract Withdraw is Ownable, ReentrancyGuard {
    event Withdrawal(address indexed sender, uint256 amount);

    function withdrawToken(
        IERC20 token,
        address _to,
        uint256 _value
    ) public onlyOwner nonReentrant {
        require(token.balanceOf(address(this)) >= _value, "Not enough token");
        SafeERC20.safeTransfer(token, _to, _value);
        emit Withdrawal(_to, _value);
    }
}
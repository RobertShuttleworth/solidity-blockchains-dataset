pragma solidity >=0.6.0 <0.8.0;

import "./openzeppelin_contracts_math_SafeMath.sol";
import "./openzeppelin_contracts_token_ERC20_SafeERC20.sol";

library SafeAmount {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount) internal returns (uint256)  {
        uint256 preBalance = IERC20(token).balanceOf(to);
        IERC20(token).transferFrom(from, to, amount);
        uint256 postBalance = IERC20(token).balanceOf(to);
        return postBalance.sub(preBalance);
    }
}
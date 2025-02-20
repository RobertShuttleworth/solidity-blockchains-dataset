// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_utils_Address.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

library TransferHelper {
 // Add your functions here
 using Address for address payable;

 function transfer(address token, address to, uint256 amount) internal returns (bool) {
  return IERC20(token).transfer(to, amount);
 }
 
 function transferManyTimes(address token, address[] memory tos, uint256[] memory amounts) internal {
  for(uint i=0; i<tos.length; i++) {
   transfer(token, tos[i], amounts[i]);
  }
 }
 function transferEth(address to, uint256 amount) internal {
  payable(to).sendValue(amount);
 }
 function transferEthManyTimes(address[] memory tos, uint256[] memory amounts) internal {
  for(uint i=0; i<tos.length; i++) {
   payable(tos[i]).sendValue(amounts[i]);
  }
 }

 function transferFrom(
  address token, 
  address from, 
  address to, 
  uint256 amount
 ) internal returns (bool) {
  return IERC20(token).transferFrom(from, to, amount);
 }
}
// @author Daosourced
// @date February 11, 2023
pragma solidity ^0.8.0;
import "./openzeppelin_contracts_utils_math_Math.sol";

library Arrays {
  
  using Math for uint256;

  function findMax(uint256[] memory values) internal pure returns (uint256 max) {
      for(uint256 i = 0; i < values.length; i++) {
          max = values[i].max(max);
      }
  }

  function findMin(uint256[] memory values) internal pure returns (uint256 min) {
      for(uint256 i = 0; i < values.length; i++) {
          min = values[i].min(min);
      }
  }

  function containsUint256(uint256[] memory arr, uint256 element) internal pure returns (bool) {
    for(uint256 i = 0; i < arr.length; i++) {
     if(arr[i] == element){
      return true;
     }
    }
    return false;
   }
}
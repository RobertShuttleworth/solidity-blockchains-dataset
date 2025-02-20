// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;
import "./lib_openzeppelin-contracts_contracts_utils_math_Math.sol"; 

contract Helper {
    function uint2str(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    function randomize(uint256 seed) internal view returns (uint128) {
        return uint128(uint256(keccak256(abi.encodePacked(seed, block.timestamp, msg.sender))));
    }
    
    function randConvert(uint128 rand) public pure returns (uint256[3] memory){
        uint256[3] memory rands;
        for (uint256 i = 0; i < 3; ++i) {
            rands[i] = uint256(keccak256(abi.encodePacked(rand+i)))%1000;
        }

        return rands;
    }

}
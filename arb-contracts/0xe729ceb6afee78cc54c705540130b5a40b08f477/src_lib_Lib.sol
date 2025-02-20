// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

library Calculations {
    function getSumOfUintArray(
        uint256[] calldata valueArray
    ) external pure returns (uint128 sum) {
        uint256 length = valueArray.length;
        if (length == 0) return 0;
        for (uint256 i = 0; i < length; ) {
            sum += uint128(valueArray[i]);
            unchecked {
                i++;
            }
        }
    }
}
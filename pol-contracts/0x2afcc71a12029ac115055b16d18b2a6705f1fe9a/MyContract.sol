// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

error TestError(address user, uint amount);

contract MyContract {
    function f1() public pure returns (uint) {
        return 12;
    }

    function f2() public pure {
        revert("test");
    }

    function f3() public pure {
        revert TestError(0x9A4Bd9c2f5cee61bF1e6ab7b261Fe2edBb2F294E, 1234);
    }

    function f4(address user) public pure returns (uint) {
        require(user == 0x9A4Bd9c2f5cee61bF1e6ab7b261Fe2edBb2F294E, "test error");
        return 13;
    }
}
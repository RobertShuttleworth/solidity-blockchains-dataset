// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
 
contract OpContract {
    string public greeting = "Super OP";
 
    function setGreeting(string memory _greeting) public {
        greeting = _greeting;
    }
}
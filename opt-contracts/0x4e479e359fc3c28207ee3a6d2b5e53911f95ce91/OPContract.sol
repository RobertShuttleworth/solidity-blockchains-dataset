// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
 
contract OPContract {
    string public greeting = "Hello, OP!";
 
    function setGreeting(string memory _greeting) public {
        greeting = _greeting;
    }
}
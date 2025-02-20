// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
 
contract InkContract {
    string public greeting = "Hello!";
 
    function setGreeting(string memory _greeting) public {
        greeting = _greeting;
    }
}
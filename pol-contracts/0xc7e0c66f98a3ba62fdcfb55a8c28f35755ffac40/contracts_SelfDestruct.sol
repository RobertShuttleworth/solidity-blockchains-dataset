// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

contract SelfDestruct {
    address public owner;

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function selfDestruct(address payable newOwner) public onlyOwner {
        selfdestruct(newOwner);
    }
}
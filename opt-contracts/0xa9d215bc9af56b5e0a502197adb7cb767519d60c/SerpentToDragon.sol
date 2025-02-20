// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SerpentToDragon {

    // State variable to store the current form
    string public currentForm;

    // Constructor to initialize the form as 'serpent'
    constructor() {
        currentForm = "serpent";
    }

    // Function to transform the form from serpent to dragon
    function transform() public {
        require(keccak256(abi.encodePacked(currentForm)) == keccak256(abi.encodePacked("serpent")), "Already transformed!");
        currentForm = "dragon";
    }

    // Function to check the current form
    function getCurrentForm() public view returns (string memory) {
        return currentForm;
    }
}
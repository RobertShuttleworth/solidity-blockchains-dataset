// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract RecordHash {
    // Hold the stored hash
    bytes32 public storedHash;
    bytes32 public storedNote;
    
    // Flag to track if hash has been set
    bool private hashSet = false;
    
    // Function to store hash that can only be called once
    function storeHash(bytes32 _hash, bytes32 _note) public {
        // Require that the hash has not been set before
        require(!hashSet, "Attribute has been set and is immutable");
        // Store the hash
        storedHash = _hash;
        storedNote = _note;
        // Mark hash as set
        hashSet = true;
    }
    
    // Function to retrieve the hash
    function getHash() public view returns (bytes32) {
        return storedHash;
    }
    
    // Function to retrieve the note
    function getNote() public view returns (bytes32) {
        return storedNote;
    }
    
    // Function to check if hash is already set
    function isHashSet() public view returns (bool) {
        return hashSet;
    }
}
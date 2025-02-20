// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

contract IndexRegistry is Ownable, Pausable, ReentrancyGuard {
    struct Index {
        string name;
        address token;
        bool active;
        uint256 createdAt;
    }

    mapping(string => Index) public indices;
    string[] public indexNames;
    
    event IndexCreated(string name, address token);
    event IndexUpdated(string name, bool active);
    
    constructor() Ownable(msg.sender) {
    }
    
    function createIndex(string memory name, address token) external onlyOwner {
        require(indices[name].token == address(0), "Index already exists");
        require(token != address(0), "Invalid token address");
        
        indices[name] = Index({
            name: name,
            token: token,
            active: true,
            createdAt: block.timestamp
        });
        
        indexNames.push(name);
        emit IndexCreated(name, token);
    }
    
    function setIndexStatus(string memory name, bool status) external onlyOwner {
        require(indices[name].token != address(0), "Index does not exist");
        indices[name].active = status;
        emit IndexUpdated(name, status);
    }
    
    function getAllIndexNames() external view returns (string[] memory) {
        return indexNames;
    }
    
    function getIndexDetails(string memory name) external view returns (
        address token,
        bool active,
        uint256 createdAt
    ) {
        Index memory idx = indices[name];
        require(idx.token != address(0), "Index does not exist");
        return (idx.token, idx.active, idx.createdAt);
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
}
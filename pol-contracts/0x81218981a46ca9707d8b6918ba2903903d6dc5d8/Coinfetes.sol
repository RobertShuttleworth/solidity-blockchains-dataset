// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";
import {Ownable} from "./Ownable.sol";
import {ReentrancyGuard} from "./ReentrancyGuard.sol";

contract Coinfetes is ERC20, Ownable, ReentrancyGuard {
    uint256 private constant MAX_SUPPLY = 999_999_990 * 10 ** 18; // 999M COFTS maximum supply
    uint256 public constant MINING_AMOUNT = 99 * 10 ** 18; // 99 COFTS per mining
    
    event COFTSMinted(address indexed user, uint256 amount, uint256 totalSupply);

    constructor(address initialOwner) Ownable(initialOwner) ERC20("Coinfetes", "COFTS") {}

    // Function to mine COFTS
    function mineCOFTS() external nonReentrant {
        uint256 amount = MINING_AMOUNT;
        
        uint256 currentSupply = super.totalSupply();
        require(currentSupply + amount <= MAX_SUPPLY, "Exceeds max supply");

        // Mint COFTS for the user
        _mint(msg.sender, amount);
        emit COFTSMinted(msg.sender, amount, currentSupply + amount);
    }
}

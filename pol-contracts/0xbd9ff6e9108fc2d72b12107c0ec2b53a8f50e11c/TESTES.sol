// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";
import {Ownable} from "./Ownable.sol";
import {ReentrancyGuard} from "./ReentrancyGuard.sol";

contract TESTES is ERC20, Ownable, ReentrancyGuard {
    uint256 private constant MAX_SUPPLY = 123_456_789 * 10 ** 18; // 123M TESTES máximo de supply
    uint256 public constant MINING_AMOUNT = 50 * 10 ** 18; // 50 COFTS por mineração
    
    event TESTESMinted(address indexed user, uint256 amount, uint256 totalSupply);

    constructor(address initialOwner) Ownable(initialOwner) ERC20("TESTES", "TESTES") {}

    // Função para minerar TESTES
    function mineTESTES() external nonReentrant {
        uint256 amount = MINING_AMOUNT;
        
        uint256 currentSupply = super.totalSupply();
        require(currentSupply + amount <= MAX_SUPPLY, "Exceeds max supply");

        // Emitir TESTES para o usuário
        _mint(msg.sender, amount);
        emit TESTESMinted(msg.sender, amount, currentSupply + amount);
    }
}

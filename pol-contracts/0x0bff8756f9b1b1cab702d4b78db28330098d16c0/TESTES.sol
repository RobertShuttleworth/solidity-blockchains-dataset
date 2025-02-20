// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "./ERC20.sol";
import {Ownable} from "./Ownable.sol";

contract TESTES is ERC20, Ownable {
    uint256 public constant MAX_SUPPLY = 123_456_789 * 10 ** 18; // 123M TESTES máximo de supply
    uint256 public constant MINING_AMOUNT = 50 * 10 ** 18; // 50 COFTS por mineração
    
    event TESTESMinted(address indexed user, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) ERC20("TESTES", "TESTES") {}

    // Função para minerar TESTES
    function mineTESTES() external {
        // Definir a quantidade fixa de TESTES a ser minerada
        uint256 amount = MINING_AMOUNT;

        // Verificar se o total de TESTES mintados não ultrapassa o supply máximo
        uint256 currentSupply = ERC20.totalSupply();
        require(currentSupply + amount <= MAX_SUPPLY, "Exceeds max supply");

        // Emitir TESTES para o usuário
        _mint(msg.sender, amount);
        emit TESTESMinted(msg.sender, amount);
    }
}

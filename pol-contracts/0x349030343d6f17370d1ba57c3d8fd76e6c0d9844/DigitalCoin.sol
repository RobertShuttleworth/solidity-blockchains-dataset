// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DigitalCoin {
    string public name = "DigitalCoin";
    string public symbol = "DGC";
    uint8 public decimals = 18; // 18 casas decimais
    uint256 public totalSupply; // Total de tokens

    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor() {
        // Define o total de 40 milhões de tokens
        totalSupply = 40_000_000 * (10 ** uint256(decimals));
        // Atribui todos os tokens ao criador do contrato
        balanceOf[msg.sender] = totalSupply;

        // Emite o evento de transferência inicial
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Saldo insuficiente");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
}
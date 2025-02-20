// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract StoreContract {

    // Define a estrutura do contrato
    struct Contract {
        string name;
        string hashDocumento;
        string status;
        string data;
    }

    // Mapeia o id para o contrato
    mapping(uint32 => Contract) public contracts;

    // Contador para os contratos
    uint32 public count;

    // Construtor
    constructor() {
        count = 0; // Inicializa o contador
    }

    // Função para assinar um contrato
    function signContract(Contract memory contractData) public {
        contracts[count] = contractData;
        count++;
    }

    // Função para editar um contrato existente
    function editContract(uint32 id, Contract memory newContract) public {
        contracts[id] = newContract;
    }

    // Função para obter um contrato por id
    function getContract(uint32 id) public view returns (Contract memory) {
        return contracts[id];
    }

    // Função para remover um contrato por id
    function removeContract(uint32 id) public {
        delete contracts[id];
    }
}
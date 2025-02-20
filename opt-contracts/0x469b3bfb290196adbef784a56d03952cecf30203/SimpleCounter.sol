// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract SimpleCounter {
    uint256 public counter;

    // Evento per monitorare cambiamenti al counter
    event CounterUpdated(uint256 newCounter);

    // Funzione per incrementare il contatore
    function increment() public {
        counter += 1;
        emit CounterUpdated(counter); // Emissione evento quando il contatore viene incrementato
    }

    // Funzione per resettare il contatore a zero
    function resetCounter() public {
        counter = 0;
        emit CounterUpdated(counter); // Emissione evento quando il contatore viene resettato
    }

    // Funzione per ottenere il valore attuale del contatore
    function getCounter() public view returns (uint256) {
        return counter;
    }
}
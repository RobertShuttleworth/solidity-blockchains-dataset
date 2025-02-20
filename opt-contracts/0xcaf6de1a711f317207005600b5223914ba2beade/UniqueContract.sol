// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UniqueContract {

    // Déclaration d'une variable publique qui contient un message
    string public message;

    // Adresse du créateur du contrat
    address public owner;

    // Un événement pour notifier quand le message est modifié
    event MessageChanged(string oldMessage, string newMessage);

    // Constructeur du contrat qui initialise l'adresse du propriétaire et un message initial
    constructor(string memory initialMessage) {
        owner = msg.sender;  // L'adresse du créateur du contrat devient l'owner
        message = initialMessage;  // Le message initial est défini
    }

    // Modificateur pour s'assurer que seule l'adresse du propriétaire peut appeler certaines fonctions
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    // Fonction pour changer le message
    function changeMessage(string memory newMessage) public onlyOwner {
        string memory oldMessage = message;
        message = newMessage;
        emit MessageChanged(oldMessage, newMessage);  // Emission de l'événement pour notifier le changement
    }

    // Fonction pour récupérer l'adresse du propriétaire
    function getOwner() public view returns (address) {
        return owner;
    }

}
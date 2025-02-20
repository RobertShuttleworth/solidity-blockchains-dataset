// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ArbitrumWallet {
    address public owner; // L'administrateur (propriétaire)
    mapping(address => uint256) public balances; // Solde de chaque utilisateur
    mapping(address => bool) public isAdmin; // Liste des administrateurs

    event Deposit(address indexed user, uint256 amount); // Événement pour un dépôt
    event Withdrawal(address indexed user, uint256 amount); // Événement pour un retrait
    event Transfer(address indexed from, address indexed to, uint256 amount); // Événement pour un transfert
    event AdminAdded(address indexed admin); // Événement pour ajout d'un administrateur
    event AdminRemoved(address indexed admin); // Événement pour suppression d'un administrateur

    modifier onlyOwner() {
        require(msg.sender == owner, "Vous n'etes pas l'administrateur.");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender] == true, "Vous devez etre administrateur.");
        _;
    }

    modifier hasBalance(uint256 amount) {
        require(balances[msg.sender] >= amount, "Solde insuffisant.");
        _;
    }

    // Constructeur pour initialiser l'administrateur du contrat
    constructor() {
        owner = msg.sender;
        isAdmin[owner] = true; // Le propriétaire est automatiquement un administrateur
    }

    // Fonction pour déposer des fonds dans le portefeuille
    function deposit() public payable {
        require(msg.value > 0, "Le montant doit etre superieur a zero.");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // Fonction pour retirer des fonds du portefeuille
    function withdraw(uint256 amount) public hasBalance(amount) {
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawal(msg.sender, amount);
    }

    // Fonction pour transférer des fonds entre utilisateurs (uniquement pour les administrateurs)
    function transfer(address to, uint256 amount) public onlyAdmin hasBalance(amount) {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
    }

    // Fonction pour ajouter un administrateur
    function addAdmin(address admin) public onlyOwner {
        require(!isAdmin[admin], "Cet utilisateur est deja un administrateur.");
        isAdmin[admin] = true;
        emit AdminAdded(admin);
    }

    // Fonction pour retirer un administrateur
    function removeAdmin(address admin) public onlyOwner {
        require(isAdmin[admin], "Cet utilisateur n'est pas un administrateur.");
        isAdmin[admin] = false;
        emit AdminRemoved(admin);
    }

    // Fonction pour voir le solde d'un utilisateur
    function getBalance(address user) public view returns (uint256) {
        return balances[user];
    }

    // Fonction pour retirer tous les fonds de ce contrat (uniquement pour le propriétaire)
    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner).transfer(balance);
    }
}
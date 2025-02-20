// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract OwnableContract {
    address public owner;

    // Събитие за прехвърляне на собствеността
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Конструктор: Настройва адреса на създателя като собственик
    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // Модификатор: Проверка дали извикващият е собственик
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Функция за прехвърляне на собствеността към нов адрес
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Примерна функция, достъпна само за собственика
    function ownerOnlyFunction() public view onlyOwner returns (string memory) {
        return "This function can only be executed by the owner.";
    }
}
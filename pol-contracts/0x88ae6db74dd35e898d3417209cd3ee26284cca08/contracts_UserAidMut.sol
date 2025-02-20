// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import './openzeppelin_contracts_access_Ownable.sol';
struct UserStruct {
    bool registered;
    address level1;
    address level2;
    address level3;
    address level4;
    address level5;
    address level6;
    address level7;
    address level8;
    address level9;
    address level10;
    address level11;
    address level12;
    address level13;
    address level14;
    address level15;
    address level16;
    address level17;
    address level18;
    address level19;
    address level20;
}

contract UserAidMut is Ownable {
    event UserAdded(address indexed user, uint indexed timestamp);
    event ChangedBot(address indexed user);

    address walletBot = 0x5Dddf31bA5e84170981A14F2acA6654878eB7568;

    mapping(address => UserStruct) private users;
    mapping(address => bool) private whitelist;
    mapping(address => bool) private blacklist;

    constructor(address _owner) Ownable(_owner) {
        users[_owner].registered = true;
    }

    function createUser(address level1) external {
        address user = msg.sender;
        require(
            !users[user].registered,
            'This user has already been registered'
        );

        if (!users[level1].registered) {
            level1 = owner();
        }

        UserStruct memory sponsor = users[level1];
        users[user].registered = true;
        users[user].level1 = level1;
        addLevels(user, sponsor);

        emit UserAdded(user, block.timestamp);
    }

    function addLevels(address user, UserStruct memory sponsor) internal {
        users[user].level2 = sponsor.level1;
        users[user].level3 = sponsor.level2;
        users[user].level4 = sponsor.level3;
        users[user].level5 = sponsor.level4;
        users[user].level6 = sponsor.level5;
        users[user].level7 = sponsor.level6;
        users[user].level8 = sponsor.level7;
        users[user].level9 = sponsor.level8;
        users[user].level10 = sponsor.level9;
        users[user].level11 = sponsor.level10;
        users[user].level12 = sponsor.level11;
        users[user].level13 = sponsor.level12;
        users[user].level14 = sponsor.level13;
        users[user].level15 = sponsor.level14;
        users[user].level16 = sponsor.level15;
        users[user].level17 = sponsor.level16;
        users[user].level18 = sponsor.level17;
        users[user].level19 = sponsor.level18;
        users[user].level20 = sponsor.level19;
    }

    function getUser(
        address _address
    ) external view returns (UserStruct memory) {
        return users[_address];
    }

    modifier onlyBot() {
        require(msg.sender == walletBot, 'Only bot can call this function');
        _;
    }

    function setWalletBot(address _address) external onlyOwner {
        walletBot = _address;
        emit ChangedBot(_address);
    }

    function addToWhitelist(address user) external onlyBot {
        whitelist[user] = true;
    }

    function removeFromWhitelist(address user) external onlyBot {
        whitelist[user] = false;
    }

    function addToBlacklist(address user) external onlyBot {
        blacklist[user] = true;
    }

    function removeFromBlacklist(address user) external onlyBot {
        blacklist[user] = false;
    }

    function isBlacklisted(address user) external view returns (bool) {
        return blacklist[user];
    }
    function isWhitelisted(address user) external view returns (bool) {
        return whitelist[user];
    }
}
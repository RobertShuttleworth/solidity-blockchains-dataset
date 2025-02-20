// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IUserAidMut {
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

    function getUser(
        address _address
    ) external view returns (UserStruct memory);

    function isBlacklisted(address user) external view returns (bool);

    function isWhitelisted(address user) external view returns (bool);

    function createUser(address level1) external;
}
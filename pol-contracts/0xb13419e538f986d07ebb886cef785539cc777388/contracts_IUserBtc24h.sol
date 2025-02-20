// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUserBtc24h {
    struct UserStruct {
        bool registered;
        uint8 totalLevels;
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
        address level21;
        address level22;
        address level23;
        address level24;
        address level25;
        address level26;
        address level27;
        address level28;
        address level29;
        address level30;
        address level31;
        address level32;
        address level33;
        address level34;
        address level35;
        address level36;
        address level37;
        address level38;
        address level39;
        address level40;
    }
    function getUser(
        address _address
    ) external view returns (UserStruct memory);
    function createUser(address level1) external;
}
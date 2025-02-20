
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @author Eto Vass
 */

contract CuratedManager {
    uint16[] private curatedTokens;
    uint private unusedCuratedLenght;

    constructor() {
        uint numTokens = 400;

        for (uint i = 0; i < numTokens; i++) {
            curatedTokens.push(uint16(i));
        }
        unusedCuratedLenght = curatedTokens.length;
    }

    // could be useful for future analysis and for frontends to show the curated tokens
    function getCurratedCount() public view returns (uint) {
        return curatedTokens.length;
    }

    function getCurratedToken(uint index) public view returns (uint32) {
        return curatedTokens[index];
    }

    function getCurratedTokens() public view returns (uint16[] memory) {
        return curatedTokens;
    }

    function getUnusedCuratedLength() public view returns (uint) {
        return unusedCuratedLenght;
    }

    function hasUnusedCurated() internal view returns (bool) {
        return unusedCuratedLenght > 0;
    }

    function getRandomCuratedToken(uint randomNumber) internal returns (int result) {
        if (unusedCuratedLenght == 0) {
            return -1;
        }

        uint curratedId = uint(randomNumber % unusedCuratedLenght);

        result = int(uint(curatedTokens[curratedId]));

        if (curatedTokens.length > 1) {
            curatedTokens[curratedId] = curatedTokens[unusedCuratedLenght - 1];
        }
        unusedCuratedLenght--;
    }
}
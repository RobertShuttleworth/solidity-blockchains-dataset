// SPDX-License-Identifier: MIT

pragma solidity 0.8.28;

struct Year {
    uint256 number;
    uint256 endTimestamp;
}

function yearDuration(uint256 yearNumber) pure returns (uint256) {
    bool isLeapYear = yearNumber % 4 == 0 && yearNumber % 100 != 0 || yearNumber % 400 == 0;
    return isLeapYear ? 366 days : 365 days;
}

/// @author Audittens
contract NewYearCelebrator {
    Year public storedYear = Year({number: 1969, endTimestamp: 0});

    event HappyNewYear(uint256 year, string wish);
    event CelebrateNewYear(uint256 year, address sender);

    constructor() {
        storedYear = calculateCurrentYear();
    }

    function calculateCurrentYear() public view returns (Year memory year) {
        year = storedYear;
        while (year.endTimestamp <= block.timestamp) {
            year.number++;
            year.endTimestamp += yearDuration(year.number);
        }
    }

    function update() external {
        Year memory currentYear = calculateCurrentYear();
        require(currentYear.number != storedYear.number, "Calm down! It's still the same year.");
        storedYear = currentYear;
        emit HappyNewYear(currentYear.number, "Another year, another block added to the chain of life. Happy New Year from Audittens! May your systems be as solid as Solidity and your decisions as smart as smart contracts. Wishing you a secure and successful year ahead!");
    }

    function celebrate() external {
        Year memory currentYear = calculateCurrentYear();
        require(currentYear.number == storedYear.number, "Hey, we're still stuck in previous year! Call update() to bring us to the present.");
        uint256 beginTimestamp = currentYear.endTimestamp - yearDuration(currentYear.number);
        require(block.timestamp <= beginTimestamp + 2 weeks, "Too late to the party! Come back next year.");
        emit CelebrateNewYear(currentYear.number, msg.sender);
    }

    function secondsUntilNewYear() external view returns (int256) {
        return int256(storedYear.endTimestamp) - int256(block.timestamp);
    }
}
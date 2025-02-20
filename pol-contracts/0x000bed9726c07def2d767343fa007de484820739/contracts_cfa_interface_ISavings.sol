// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISavings {
    struct System {
        uint256 idCounter; // The total number of CFAs minted
        uint256 minLife;
        uint256 maxLife;
        uint256 totalActiveCfa;
    }

    struct Attributes {
        uint256 timeCreated; // The time the CFA was minted in unix timestamp
        uint256 cfaLifeTimestamp; // maturity date, adjusted for loan
        uint256 cfaLife; // The duration of the CFA in number of years
        uint256 effectiveInterestTime; // time created basically, but adjusted
        uint256 principal; // The amount of B&B tokens locked
        uint256 marker; // Current marker when CFA was created
        uint256 discountGiven; // The discount given to the user
        // uint256 totalPossibleReward;
    }

    struct Loan {
        bool onLoan;
        uint256 loanBalance;
        uint256 timeWhenLoaned;
    }

    struct Metadata {
        string name; // The name of the CFA
        string description; // The description of the CFA
        string image; // The image of the CFA
        string loanImage;
    }
}
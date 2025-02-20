// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

interface IInterestRateCredit {
    struct Rate {
        // The interest rate charged to a Borrower on borrowed / drawn down funds
        // in bps, 4 decimals
        uint128 dRate;
        // The interest rate charged to a Borrower on the remaining funds available, but not yet drawn down (rate charged on the available headroom)
        // in bps, 4 decimals
        uint128 fRate;
        // The time stamp at which accrued interest was last calculated on an ID and then added to the overall interestAccrued (interest due but not yet repaid)
        uint256 lastAccrued;
    }

    function getRates(uint256 id) external view returns (uint128, uint128);
}
// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {IInterestRateCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IInterestRateCredit.sol";

/**
 * @title   - InterestRateCredit
 * @author  - Credit Cooperative
 * @notice  - Contract for calculating interest owed to credit positions
 */
contract InterestRateCredit is IInterestRateCredit {
    // 1 Julian astronomical year in seconds to use in calculations for rates = 31557600 seconds
    uint256 constant ONE_YEAR_IN_SECONDS = 365.25 days;
    // Must divide by 100 too offset bps in numerator and divide by another 100 to offset % and get actual token amount
    uint256 constant BASE_DENOMINATOR = 10000;
    // uint256 constant INTEREST_DENOMINATOR = ONE_YEAR_IN_SECONDS * BASE_DENOMINATOR;
    // = 31557600 * 10000 = 315576000000;
    uint256 constant INTEREST_DENOMINATOR = 315_576_000_000;

    mapping(uint256 => Rate) public rates; // position id -> lending rates

    /**
     * @notice - accrue interest for a credit position
     * @dev    - calculates interest owed based the drawn balance, facility balance, and time since last accrued.
     * @param  id              - credit position id
     * @param  drawnBalance    - balance drawn from the facility
     * @param  facilityBalance - total balance in the facility
     * @return accrued         - total interest accrued
     */
    function _accrueInterest(uint256 id, uint256 drawnBalance, uint256 facilityBalance)
        internal
        returns (uint256 accrued)
    {
        accrued = _getAccruedInterest(id, drawnBalance, facilityBalance);
        // update last timestamp in storage
        rates[id].lastAccrued = block.timestamp;
    }

    function _getAccruedInterest(uint256 id, uint256 drawnBalance, uint256 facilityBalance)
        internal
        view
        returns (uint256)
    {
        Rate memory rate = rates[id];

        // get time since interest was last accrued iwth these balances
        uint256 timespan = block.timestamp - rate.lastAccrued;

        return (
            _calculateInterestOwed(rate.dRate, drawnBalance, timespan)
                + _calculateInterestOwed(rate.fRate, (facilityBalance - drawnBalance), timespan)
        );
    }

    /**
     * @notice - total interest to accrue based on apr, balance, and length of time
     * @dev    - r = APR in bps, x = # tokens, t = time
     *         - interest = (r * x * t) / 1yr / 100
     * @param  bpsRate  - interest rate (APR) to charge against balance in bps (4 decimals)
     * @param  balance  - current balance for interest rate tier to charge interest against
     * @param  timespan - total amount of time that interest should be charged for
     *
     * @return interestOwed
     */
    function _calculateInterestOwed(uint256 bpsRate, uint256 balance, uint256 timespan)
        internal
        pure
        returns (uint256)
    {
        return (bpsRate * balance * timespan) / INTEREST_DENOMINATOR;
    }

    function _setRate(uint256 id, uint128 dRate, uint128 fRate) internal {
        rates[id] = Rate({dRate: dRate, fRate: fRate, lastAccrued: block.timestamp});
    }

    function getRates(uint256 id) public view returns (uint128, uint128) {
        return (rates[id].dRate, rates[id].fRate);
    }
}
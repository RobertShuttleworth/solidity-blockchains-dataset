// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";

/**
 * @title   - FeesLib
 * @author  - Credit Cooperative
 * @notice  - Core logic for calculating origination, early withdrawal, servicing, and swap fees.
 */
library FeesLib {
    // 1 Julian astronomical year in seconds to use in calculations for rates = 31557600 seconds
    // uint256 constant ONE_YEAR_IN_SECONDS = 365.25 days;
    // Must divide by 100 too offset bps in numerator and divide by another 100 to offset % and get actual token amount
    uint256 constant BASE_DENOMINATOR = 10000;
    // uint256 constant INTEREST_DENOMINATOR = ONE_YEAR_IN_SECONDS * BASE_DENOMINATOR;
    // = 31557600 * 10000 = 315576000000;
    uint256 constant INTEREST_DENOMINATOR = 315_576_000_000;

    function _calculateOriginationFee(ILineOfCredit.Fees memory fees, uint256 amount, uint256 deadline)
        internal
        view
        returns (uint256)
    {
        return (amount * fees.originationFee * (deadline - block.timestamp)) / INTEREST_DENOMINATOR;
    }

    function _calculateEarlyWithdrawalFee(uint16 fee, uint256 amount) internal pure returns (uint256) {
        return ((amount * fee) / BASE_DENOMINATOR);
    }

    function _calculateServicingFee(ILineOfCredit.Fees memory fees, uint256 amount) internal pure returns (uint256) {
        return (amount * fees.servicingFee) / (BASE_DENOMINATOR);
    }

    function _calculateSwapFee(ILineOfCredit.Fees memory fees, uint256 amount) internal pure returns (uint256) {
        return (amount * fees.swapFee) / (BASE_DENOMINATOR);
    }

    function _calculateServicingFeeFromAmount(ILineOfCredit.Fees memory fees, uint256 amount)
        internal
        pure
        returns (uint256)
    {
        return (amount * fees.servicingFee) / (BASE_DENOMINATOR + fees.servicingFee);
    }
}
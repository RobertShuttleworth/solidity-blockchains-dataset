// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library DataTypes {
    /// @notice Struct representing issuance cycle
    struct IssuanceCycle {
        uint8 coupon;
        uint256 strikePrice1;
        uint256 strikePrice2;
        uint256 strikePrice3;
        uint256 strikePrice4;
        uint256 tr1;
        uint256 tr2;
        uint256 issuanceDate;
        uint256 maturityDate;
        string apy;
        uint8 underlyingSpotRef;
        uint8 optionMinOrderSize;
        string subAccountId;
        uint8 participation;
    }

    /// @notice Enum representing product status
    enum Status {
        Pending,
        Accepted,
        Locked,
        Issued,
        Mature
    }
}
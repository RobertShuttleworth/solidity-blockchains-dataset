// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library DataTypes {
    struct SupplyParams {
        address sender;
        address asset;
        uint256 amount;
        address onBehalfOf;
        uint16 referralCode;
    }

    struct WithdrawParams {
        address sender;
        address asset;
        uint256 amount;
        address to;
    }

    struct BorrowParams {
        address sender;
        address asset;
        uint256 amount;
        uint256 interestRateMode;
        uint16 referralCode;
        address onBehalfOf;
    }

    struct RepayParams {
        address sender;
        address asset;
        uint256 amount;
        uint256 interestRateMode;
        address onBehalfOf;
    }
}
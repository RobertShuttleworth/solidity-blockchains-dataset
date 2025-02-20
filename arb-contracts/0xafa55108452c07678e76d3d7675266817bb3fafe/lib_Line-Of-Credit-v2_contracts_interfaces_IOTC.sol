// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

interface IOTC {

    struct OTC {
        address counterparty;
        address tokenGoingOut;
        uint256 tokenGoingOutAmount;
        address tokenComingIn;
        uint256 tokenComingInAmount;
        uint256 expiration;
    }

}
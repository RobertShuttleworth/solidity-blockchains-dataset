// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./contracts_token_oft_v2_ProxyOFTV2.sol";

/// @title A LayerZero OmnichainFungibleToken for ECO on FANTOM
contract EcoProxyOFTV2 is ProxyOFTV2 {
    constructor() ProxyOFTV2(0xB8a32897016C1B2ee0797090162eAFe58f032795, 6, 0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7) {
    }
}
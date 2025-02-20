// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import './contracts_utils_Admin.sol';

abstract contract ProtocolFeeManagerStorage is Admin {
    address public implementation;

    mapping(address => bool) public isOperator;

}
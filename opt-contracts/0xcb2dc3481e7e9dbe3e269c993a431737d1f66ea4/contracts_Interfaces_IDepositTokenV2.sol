// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./contracts_Interfaces_IDepositToken.sol";

interface IDepositTokenV2 is IDepositToken {
    function initialize(
        address _owner,
        address _operator,
        address _lptoken
    ) external;
}
// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity ^0.8.24;

import { Ownable2Step as OZOwnable2Step } from "./lib_openzeppelin-contracts_contracts_access_Ownable2Step.sol";

abstract contract Ownable2Step is OZOwnable2Step {
    error CannotRenounce();

    function renounceOwnership() public view override onlyOwner {
        revert CannotRenounce();
    }
}
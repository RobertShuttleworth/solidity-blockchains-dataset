// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

interface IBaseComboOption {
    error LOK();
    error swapComboNotImplemented();
    error zeroOptionBalance();
    error incorrectOptionType();
    error notOwner();
    error incorrectDirections();
    
    error notExpiredYet();

    error SpecifiedAndReturnedAmountNotRelated();

}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IPaymentManager {
    function incrementBalance(uint256 amount, address tokenContract) external;
}
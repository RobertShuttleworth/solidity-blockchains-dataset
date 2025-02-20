// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./contracts_helpers_ERC20Helper.sol";

interface Locker {
    function deposit(uint256 sellAmount, bool lock, address stakeAddress) external;
}

contract LockerModeler is ERC20Helper {
    function depositLocker(Locker locker, uint256 sellAmount, bool lock, address stakeAddress, address buyToken)
        external
        returns (uint256 buyAmount)
    {
        uint256 startBalance = getBalance(buyToken, address(this));
        locker.deposit(sellAmount, lock, stakeAddress);
        uint256 endBalance = getBalance(buyToken, address(this));
        buyAmount = endBalance - startBalance;
    }
}
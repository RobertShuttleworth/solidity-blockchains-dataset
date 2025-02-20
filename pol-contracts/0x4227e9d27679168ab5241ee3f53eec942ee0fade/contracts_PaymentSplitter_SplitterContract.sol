// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "./openzeppelin_contracts_finance_PaymentSplitter.sol";

contract SplitterContract is PaymentSplitter {
    constructor(
        address[] memory payees,
        uint256[] memory shares_
    ) payable PaymentSplitter(payees, shares_) {}

    /**
     * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function release(address payable account) public virtual override {
        require(msg.sender == account, "Access denied to the caller");
        super.release(account);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_interfaces_IFlashBorrower.sol";

interface ILendingPool {
    function flashLoan(
        IFlashBorrower borrower,
        address receiver,
        IERC20 token,
        uint256 amount,
        bytes calldata data
    ) external;
}
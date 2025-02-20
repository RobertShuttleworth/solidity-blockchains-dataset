// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IFlashBorrower {
    function onFlashLoan(
        address sender,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}
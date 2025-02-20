// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IstETH is IERC20 {
    function submit(address _referral) external payable returns (uint256);
}
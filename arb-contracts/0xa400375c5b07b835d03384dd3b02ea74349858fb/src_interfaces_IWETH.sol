// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

interface IWETH is IERC20 {

    function deposit() external payable;
    function withdraw(uint256 amount) external;

}
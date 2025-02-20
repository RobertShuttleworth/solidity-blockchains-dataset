// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

interface IFiat24Token is IERC20 {
    function tokenTransferAllowed(address from, address to, uint256 amount) external view returns(bool);
}
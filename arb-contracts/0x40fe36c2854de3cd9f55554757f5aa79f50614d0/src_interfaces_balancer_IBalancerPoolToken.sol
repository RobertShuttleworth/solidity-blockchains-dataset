// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IVault} from './balancer-labs_v2-interfaces_contracts_vault_IVault.sol';
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IBalancerPoolToken is IERC20 {

    function getVault() external view returns (IVault);

}
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {IDataStore} from "./src_interfaces_gmx_IDataStore.sol";
import {IRoleStore} from "./src_interfaces_gmx_IRoleStore.sol";

interface IGlvVault {
    function tokenBalances(address asset) external view returns (uint256);

    function dataStore() external view returns (IDataStore);
    function roleStore() external view returns (IRoleStore);
}
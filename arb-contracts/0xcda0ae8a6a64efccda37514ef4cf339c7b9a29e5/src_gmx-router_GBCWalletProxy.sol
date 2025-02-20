// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { BeaconProxy } from "./node_modules_openzeppelin_contracts_proxy_beacon_BeaconProxy.sol";

contract GBCWalletProxy is BeaconProxy {
    constructor(address beacon) BeaconProxy(beacon, "") { }
}
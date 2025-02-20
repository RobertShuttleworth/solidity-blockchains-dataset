// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.16;

import "./openzeppelin_contracts_proxy_beacon_BeaconProxy.sol";

contract BeaconProxyContract is BeaconProxy {
    constructor(address beacon, bytes memory data) BeaconProxy(beacon,data){
    }
}
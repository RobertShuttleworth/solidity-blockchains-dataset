// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_proxy_beacon_BeaconProxy.sol";
import "./openzeppelin_contracts_proxy_beacon_UpgradeableBeacon.sol";
import "./openzeppelin_contracts_proxy_ERC1967_ERC1967Proxy.sol";
import "./openzeppelin_contracts_proxy_transparent_TransparentUpgradeableProxy.sol";
import "./openzeppelin_contracts_proxy_transparent_ProxyAdmin.sol";

// Kept for backwards compatibility with older versions of Hardhat and Truffle plugins.
contract AdminUpgradeabilityProxy is TransparentUpgradeableProxy {
    constructor(address logic, address admin, bytes memory data) payable TransparentUpgradeableProxy(logic, admin, data) {}
}
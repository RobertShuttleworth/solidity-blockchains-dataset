// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import { UpgradeableBeacon } from "./node_modules_openzeppelin_contracts_proxy_beacon_UpgradeableBeacon.sol";

contract GBCWalletBeacon is UpgradeableBeacon {
    constructor(address implementation_, address initialOwner) UpgradeableBeacon(implementation_, initialOwner) { }
}
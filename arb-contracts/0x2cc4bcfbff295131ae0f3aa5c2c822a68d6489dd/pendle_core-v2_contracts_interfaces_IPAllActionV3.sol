// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import "./pendle_core-v2_contracts_interfaces_IPActionAddRemoveLiqV3.sol";
import "./pendle_core-v2_contracts_interfaces_IPActionSwapPTV3.sol";
import "./pendle_core-v2_contracts_interfaces_IPActionSwapYTV3.sol";
import "./pendle_core-v2_contracts_interfaces_IPActionMiscV3.sol";
import "./pendle_core-v2_contracts_interfaces_IPActionCallbackV3.sol";
import "./pendle_core-v2_contracts_interfaces_IPActionStorageV4.sol";

interface IPAllActionV3 is
    IPActionAddRemoveLiqV3,
    IPActionSwapPTV3,
    IPActionSwapYTV3,
    IPActionMiscV3,
    IPActionCallbackV3,
    IPActionStorageV4
{}
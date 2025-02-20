// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "./pendle_core-v2_contracts_interfaces_IPMarketSwapCallback.sol";
import "./pendle_core-v2_contracts_interfaces_IPLimitRouter.sol";

interface IPActionCallbackV3 is IPMarketSwapCallback, IPLimitRouterCallback {}
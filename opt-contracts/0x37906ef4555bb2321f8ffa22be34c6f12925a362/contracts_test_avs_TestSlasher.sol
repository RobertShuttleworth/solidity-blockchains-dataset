// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

import {ISlasher} from "./contracts_interfaces_avs_vendored_ISlasher.sol";

contract TestSlasher is ISlasher {
    function freezeOperator(address toBeFrozen) external {}
}
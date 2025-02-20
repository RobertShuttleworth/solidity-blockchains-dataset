// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC5805.sol)

pragma solidity ^0.8.20;

import {IVotes} from "./openzeppelin_contracts5.0.0_governance_utils_IVotes.sol";
import {IERC6372} from "./openzeppelin_contracts5.0.0_interfaces_IERC6372.sol";

interface IERC5805 is IERC6372, IVotes {}
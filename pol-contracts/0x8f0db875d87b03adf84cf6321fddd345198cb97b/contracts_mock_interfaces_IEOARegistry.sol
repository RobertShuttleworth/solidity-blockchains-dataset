// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { IERC165 } from "./openzeppelin_contracts_interfaces_IERC165.sol";

interface IEOARegistry is IERC165 {
	function isVerifiedEOA(address account) external view returns (bool);
}
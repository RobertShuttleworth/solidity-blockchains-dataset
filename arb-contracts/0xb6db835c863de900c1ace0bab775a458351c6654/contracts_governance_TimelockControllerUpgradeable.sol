// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "./openzeppelin_contracts-upgradeable_governance_TimelockControllerUpgradeable.sol";

contract MyTimelockControllerUpgradeable is TimelockControllerUpgradeable {
	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(
		uint256 minDelay,
		address[] memory proposers,
		address[] memory executors,
		address admin
	) public initializer {
		__TimelockController_init(minDelay, proposers, executors, admin);
	}
}
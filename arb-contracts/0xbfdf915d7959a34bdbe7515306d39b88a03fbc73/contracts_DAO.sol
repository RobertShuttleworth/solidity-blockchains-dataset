// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {GovernorUpgradeable} from "./openzeppelin_contracts-upgradeable_governance_GovernorUpgradeable.sol";
import {GovernorCountingSimpleUpgradeable} from "./openzeppelin_contracts-upgradeable_governance_extensions_GovernorCountingSimpleUpgradeable.sol";
import {GovernorSettingsUpgradeable} from "./openzeppelin_contracts-upgradeable_governance_extensions_GovernorSettingsUpgradeable.sol";
import {GovernorVotesUpgradeable} from "./openzeppelin_contracts-upgradeable_governance_extensions_GovernorVotesUpgradeable.sol";
import {IVotes} from "./openzeppelin_contracts_governance_utils_IVotes.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";

/// @custom:security-contact info@onchainaustria.at
contract DAO is
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IVotes _token) public initializer {
        __Governor_init("onchainaustria_dao");
        __GovernorSettings_init(3 hours, 1 weeks, 10000e18);
        __GovernorCountingSimple_init();
        __GovernorVotes_init(_token);
    }

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(
        uint256 blockNumber
    ) public pure override returns (uint256) {
        return 1e25; // set to 10% of fixed total supply
    }

    function proposalThreshold()
        public
        view
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }
}
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.19;

import {IAllo} from "./lib_allo-v2_contracts_core_interfaces_IAllo.sol";
import {Metadata} from "./lib_allo-v2_contracts_core_interfaces_IRegistry.sol";

interface FAllo {
    function createPoolWithCustomStrategy(
        bytes32 _profileId,
        address _strategy,
        bytes memory _initStrategyData,
        address _token,
        uint256 _amount,
        Metadata memory _metadata,
        address[] memory _managers
    ) external payable returns (uint256 poolId);

    function getRegistry() external view returns (address);
    function getPool(uint256 _poolId) external view returns (IAllo.Pool memory);
}
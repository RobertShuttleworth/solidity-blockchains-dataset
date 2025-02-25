// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import { Semver } from "./contracts_universal_Semver.sol";
import { FeeVault } from "./contracts_universal_FeeVault.sol";

/**
 * @custom:proxied
 * @custom:predeploy 0x420000000000000000000000000000000000001A
 * @title L1FeeVault
 * @notice The L1FeeVault accumulates the L1 portion of the transaction fees.
 */
contract L1FeeVault is FeeVault, Semver {
    /**
     * @custom:semver 1.0.0
     *
     * @param _recipient Address that will receive the accumulated fees.
     */
    constructor(address _recipient) FeeVault(_recipient, 10 ether) Semver(1, 0, 0) {}
}
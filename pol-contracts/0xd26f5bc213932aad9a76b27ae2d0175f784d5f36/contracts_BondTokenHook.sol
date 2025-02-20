// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import {Hook} from "./contracts_HookSystem.sol";

abstract contract BondTokenHook is Hook {
    function notify(bytes memory data) external override {
        (uint256 continuousRebaseIndexDeltaPerSecond, uint256 rebaseIndex, uint256 runawayEndTime) = abi.decode(
            data,
            (uint256, uint256, uint256)
        );
        onRebase(continuousRebaseIndexDeltaPerSecond, rebaseIndex, runawayEndTime);
    }

    function onRebase(
        uint256 continuousRebaseIndexDeltaPerSecond,
        uint256 rebaseIndex,
        uint256 runawayEndTime
    ) public virtual {}
}
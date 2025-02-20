// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
import { PayoutManager } from "./contracts_PayoutManager.sol";

contract ArbitrumPayoutManager is PayoutManager {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _remoteHub, address _rewardWallet) public initializer {
        __PayoutManager_init(_remoteHub, _rewardWallet);
    }
}
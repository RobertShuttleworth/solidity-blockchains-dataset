// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { IXusdToken } from "./contracts_interfaces_IXusdToken.sol";
import { IExchange } from "./contracts_interfaces_IExchange.sol";
import { IPayoutManager } from "./contracts_interfaces_IPayoutManager.sol";
import { IRoleManager } from "./contracts_interfaces_IRoleManager.sol";
import { IRemoteHub } from "./contracts_interfaces_IRemoteHub.sol";
import { IRemoteHubUpgrader } from "./contracts_interfaces_IRemoteHubUpgrader.sol";
import { IWrappedXusdToken } from "./contracts_interfaces_IWrappedXusdToken.sol";
import { IMarket } from "./contracts_interfaces_IMarket.sol";

struct ChainItem {
    uint64 chainSelector;
    address xusd;
    address exchange;
    address payoutManager;
    address roleManager;
    address remoteHub;
    address remoteHubUpgrader;
    address market;
    address wxusd;
    address ccipPool;
}

interface IRemoteHub {
    function execMultiPayout(uint256 newDelta) external payable;

    function chainSelector() external view returns (uint64);

    function getChainItemById(uint64 key) external view returns (ChainItem memory);

    function ccipPool() external view returns (address);

    function xusd() external view returns (IXusdToken);

    function exchange() external view returns (IExchange);

    function payoutManager() external view returns (IPayoutManager);

    function roleManager() external view returns (IRoleManager);

    function remoteHub() external view returns (IRemoteHub);

    function remoteHubUpgrader() external view returns (IRemoteHubUpgrader);

    function wxusd() external view returns (IWrappedXusdToken);

    function market() external view returns (IMarket);
}
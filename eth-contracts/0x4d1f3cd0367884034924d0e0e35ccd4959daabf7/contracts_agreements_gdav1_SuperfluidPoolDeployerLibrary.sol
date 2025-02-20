// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.23;

import { BeaconProxy } from "./openzeppelin_contracts_proxy_beacon_BeaconProxy.sol";
import { ISuperfluidToken } from "./contracts_interfaces_superfluid_ISuperfluidToken.sol";
import { SuperfluidPool } from "./contracts_agreements_gdav1_SuperfluidPool.sol";
import { PoolConfig, PoolERC20Metadata } from "./contracts_interfaces_agreements_gdav1_IGeneralDistributionAgreementV1.sol";

library SuperfluidPoolDeployerLibrary {
    function deploy(
        address beacon,
        address admin,
        ISuperfluidToken token,
        PoolConfig memory config,
        PoolERC20Metadata memory poolERC20Metadata
    ) external returns (SuperfluidPool pool) {
        bytes memory initializeCallData = abi.encodeWithSelector(
            SuperfluidPool.initialize.selector,
            admin,
            token,
            config.transferabilityForUnitsOwner,
            config.distributionFromAnyAddress,
            poolERC20Metadata.name,
            poolERC20Metadata.symbol,
            poolERC20Metadata.decimals
        );
        BeaconProxy superfluidPoolBeaconProxy = new BeaconProxy(
            beacon,
            initializeCallData
        );
        pool = SuperfluidPool(address(superfluidPoolBeaconProxy));
    }
}
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { PeripherySigningLib } from "./contracts_libraries_PeripherySigningLib.sol";
import { SpokePoolV3PeripheryProxyInterface, SpokePoolV3PeripheryInterface } from "./contracts_interfaces_SpokePoolV3PeripheryInterface.sol";
import { SpokePoolV3Periphery } from "./contracts_SpokePoolV3Periphery.sol";

contract MockHashUtils {
    function hashDepositData(SpokePoolV3PeripheryInterface.DepositData calldata depositData)
        external
        pure
        returns (bytes32)
    {
        return PeripherySigningLib.hashDepositData(depositData);
    }

    function hashSwapAndDepositData(SpokePoolV3Periphery.SwapAndDepositData calldata swapAndDepositData)
        external
        pure
        returns (bytes32)
    {
        return PeripherySigningLib.hashSwapAndDepositData(swapAndDepositData);
    }
}
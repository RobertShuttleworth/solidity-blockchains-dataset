// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IFarmConnector, Farm } from "./contracts_interfaces_IFarmConnector.sol";
import { IRamsesGauge } from "./contracts_interfaces_external_ramses_IRamsesGauge.sol";
import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import { SafeTransferLib } from "./lib_solmate_src_utils_SafeTransferLib.sol";

struct RamsesClaimExtraData {
    address[] rewardTokens;
}

contract RamsesGaugeConnector is IFarmConnector {
    function deposit(
        Farm calldata farm,
        address token,
        bytes memory // _extraData
    ) external payable override {
        uint256 amount = IERC20(token).balanceOf(address(this));
        SafeTransferLib.safeApprove(token, farm.stakingContract, amount);
        IRamsesGauge(farm.stakingContract).deposit(amount, 0);
    }

    function withdraw(
        Farm calldata farm,
        uint256 amount,
        bytes memory // _extraData
    ) external override {
        IRamsesGauge(farm.stakingContract).withdraw(amount);
    }

    function claim(
        Farm calldata farm,
        bytes memory _extraData
    ) external override {
        RamsesClaimExtraData memory extraData =
            abi.decode(_extraData, (RamsesClaimExtraData));
        IRamsesGauge(farm.stakingContract).claimFees();
        IRamsesGauge(farm.stakingContract).getReward(
            address(this), extraData.rewardTokens
        );
    }
}
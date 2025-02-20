// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IPheasantNetworkSwapParameters } from "./contracts_swap_IPheasantNetworkSwapParameters.sol";
import { Types } from "./contracts_libraries_types_Types.sol";

contract PheasantNetworkSwapParameters is IPheasantNetworkSwapParameters {
    event FeeListUpdateEvent(Types.FeeList newFeeList);

    // ========================= Storage variables =========================

    address public relayerAddress;
    Types.FeeList public feeList;

    // ========================= Constructor =========================

    constructor(Types.FeeList memory _feeList, address _relayerAddress) {
        feeList = _feeList;
        relayerAddress = _relayerAddress;
    }

    // ========================= Modifiers =========================

    modifier onlyRelayer() {
        require(msg.sender == relayerAddress, "PheasantNetworkSwapParameters: not relayer");
        _;
    }

    // ========================= Functions =========================

    function getFee() external view returns (uint256) {
        if (tx.gasprice > feeList.gasPriceThresholdHigh) {
            return feeList.high;
        } else if (tx.gasprice < feeList.gasPriceThresholdLow) {
            return feeList.low;
        } else {
            return feeList.medium;
        }
    }

    function getMinimumFee() external view returns (uint256) {
        return feeList.low;
    }

    function executeFeeListUpdate(Types.FeeList calldata newFeeList) external onlyRelayer {
        feeList = newFeeList;
        emit FeeListUpdateEvent(newFeeList);
    }
}
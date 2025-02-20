// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DataTypes} from "./src_libraries_types_DataTypes.sol";

library Intents {
    error IntentTypeMismatch();

    enum DeliveryMethod {
        Wormhole,
        LayerZero
    }

    enum Type {
        Supply,
        Withdraw,
        Borrow,
        Repay
    }

    enum Status {
        Null,
        Created,
        Received,
        HubSuccess,
        HubFailed,
        Executed
    }

    struct Intent {
        Type intentType;
        address sender;
        address asset;
        address to_onBehalfOf;
        uint16 referralCode;
        uint256 amount;
        uint256 interestRateMode;
    }

    function encodeSpokePayload(uint256 id, Intent memory intent) internal pure returns (bytes memory) {
        return abi.encode(id, intent);
    }

    function decodeSpokePayload(bytes memory payload) internal pure returns (uint256, Intent memory) {
        return abi.decode(payload, (uint256, Intent));
    }

    function encodeHubPayload(uint256 id, Status status) internal pure returns (bytes memory) {
        return abi.encode(id, status);
    }

    function decodeHubPayload(bytes memory payload) internal pure returns (uint256, Status) {
        return abi.decode(payload, (uint256, Status));
    }

    function toSupplyParams(Intent memory intent) internal pure returns (DataTypes.SupplyParams memory) {
        if (intent.intentType != Type.Supply) revert IntentTypeMismatch();
        return DataTypes.SupplyParams({
            sender: intent.sender,
            asset: intent.asset,
            amount: intent.amount,
            onBehalfOf: intent.to_onBehalfOf,
            referralCode: intent.referralCode
        });
    }

    function toWithdrawParams(Intent memory intent) internal pure returns (DataTypes.WithdrawParams memory) {
        if (intent.intentType != Type.Withdraw) revert IntentTypeMismatch();
        return DataTypes.WithdrawParams({
            sender: intent.sender,
            asset: intent.asset,
            amount: intent.amount,
            to: intent.to_onBehalfOf
        });
    }

    function toBorrowParams(Intent memory intent) internal pure returns (DataTypes.BorrowParams memory) {
        if (intent.intentType != Type.Borrow) revert IntentTypeMismatch();
        return DataTypes.BorrowParams({
            sender: intent.sender,
            asset: intent.asset,
            amount: intent.amount,
            interestRateMode: intent.interestRateMode,
            referralCode: intent.referralCode,
            onBehalfOf: intent.to_onBehalfOf
        });
    }

    function toRepayParams(Intent memory intent) internal pure returns (DataTypes.RepayParams memory) {
        if (intent.intentType != Type.Repay) revert IntentTypeMismatch();
        return DataTypes.RepayParams({
            sender: intent.sender,
            asset: intent.asset,
            amount: intent.amount,
            interestRateMode: intent.interestRateMode,
            onBehalfOf: intent.to_onBehalfOf
        });
    }

    function fromSupplyParams(DataTypes.SupplyParams memory params) internal pure returns (Intent memory) {
        return Intent({
            intentType: Type.Supply,
            sender: params.sender,
            asset: params.asset,
            to_onBehalfOf: params.onBehalfOf,
            referralCode: params.referralCode,
            amount: params.amount,
            interestRateMode: 0
        });
    }

    function fromWithdrawParams(DataTypes.WithdrawParams memory params) internal pure returns (Intent memory) {
        return Intent({
            intentType: Type.Withdraw,
            sender: params.sender,
            asset: params.asset,
            to_onBehalfOf: params.to,
            referralCode: 0,
            amount: params.amount,
            interestRateMode: 0
        });
    }

    function fromBorrowParams(DataTypes.BorrowParams memory params) internal pure returns (Intent memory) {
        return Intent({
            intentType: Type.Borrow,
            sender: params.sender,
            asset: params.asset,
            to_onBehalfOf: params.onBehalfOf,
            referralCode: params.referralCode,
            amount: params.amount,
            interestRateMode: params.interestRateMode
        });
    }

    function fromRepayParams(DataTypes.RepayParams memory params) internal pure returns (Intent memory) {
        return Intent({
            intentType: Type.Repay,
            sender: params.sender,
            asset: params.asset,
            to_onBehalfOf: params.onBehalfOf,
            referralCode: 0,
            amount: params.amount,
            interestRateMode: params.interestRateMode
        });
    }
}
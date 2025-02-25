// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.8.0;

import {HypNative} from "./contracts_token_HypNative.sol";
import {TokenRouter} from "./contracts_token_libs_TokenRouter.sol";

/**
 * @title Hyperlane Native Token that scales native value by a fixed factor for consistency with other tokens.
 * @dev The scale factor multiplies the `message.amount` to the local native token amount.
 *      Conversely, it divides the local native `msg.value` amount by `scale` to encode the `message.amount`.
 * @author Abacus Works
 */
contract HypNativeScaled is HypNative {
    uint256 public immutable scale;

    constructor(uint256 _scale, address _mailbox) HypNative(_mailbox) {
        scale = _scale;
    }

    /**
     * @inheritdoc HypNative
     * @dev Sends scaled `msg.value` (divided by `scale`) to `_recipient`.
     */
    function transferRemote(
        uint32 _destination,
        bytes32 _recipient,
        uint256 _amount
    ) external payable override returns (bytes32 messageId) {
        require(msg.value >= _amount, "Native: amount exceeds msg.value");
        uint256 _hookPayment = msg.value - _amount;
        uint256 _scaledAmount = _amount / scale;
        return
            _transferRemote(
                _destination,
                _recipient,
                _scaledAmount,
                _hookPayment
            );
    }

    /**
     * @dev Sends scaled `_amount` (multiplied by `scale`) to `_recipient`.
     * @inheritdoc TokenRouter
     */
    function _transferTo(
        address _recipient,
        uint256 _amount,
        bytes calldata metadata // no metadata
    ) internal override {
        uint256 scaledAmount = _amount * scale;
        HypNative._transferTo(_recipient, scaledAmount, metadata);
    }
}
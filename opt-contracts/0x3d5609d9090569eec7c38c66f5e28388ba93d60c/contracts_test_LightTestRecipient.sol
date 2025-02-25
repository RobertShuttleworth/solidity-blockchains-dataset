// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.6.11;

import "./contracts_test_TestRecipient.sol";

contract LightTestRecipient is TestRecipient {
    // solhint-disable-next-line no-empty-blocks
    function handle(
        uint32 _origin,
        bytes32 _sender,
        bytes calldata _data
    ) external payable override {
        // do nothing
    }
}
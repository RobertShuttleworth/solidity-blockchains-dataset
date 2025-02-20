// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { FuegoOFTAdapter } from "./contracts_FuegoOFTAdapter.sol";

// @dev WARNING: This is for testing purposes only
contract FuegoOFTAdapterMock is FuegoOFTAdapter {
    constructor(
        address _token,
        address _lzEndpoint,
        address _delegate
    ) FuegoOFTAdapter(_token, _lzEndpoint, _delegate) {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MBToken} from "./contracts_MBToken.sol";

contract MetaDEUS is MBToken {
    constructor(
        address _layerZeroEndpoint, // local endpoint address
        address _owner // token owner used as a delegate in LayerZero Endpoint
    ) MBToken("MetaDEUS", "mbDEUS", _layerZeroEndpoint, _owner) {}
}
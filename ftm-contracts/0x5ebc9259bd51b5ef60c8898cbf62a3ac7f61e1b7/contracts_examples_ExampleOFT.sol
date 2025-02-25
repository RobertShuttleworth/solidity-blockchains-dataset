// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./layerzerolabs_lz-evm-oapp-v2_contracts_oft_OFT.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";

contract ExampleOFT is OFT {
    constructor(
        address _layerZeroEndpoint, // local endpoint address
        address _owner // token owner used as a delegate in LayerZero Endpoint
    ) OFT("Example OFT", "EOFT", _layerZeroEndpoint, _owner) Ownable(_owner) {
        // your contract logic here
        _mint(msg.sender, 100 ether); // mints 100 tokens to the deployer
    }
}
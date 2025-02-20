// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Ownable } from "./openzeppelin_contracts_access_Ownable.sol";
import { OFT } from "./layerzerolabs_oft-evm_contracts_OFT.sol";

// @dev WARNING: This is for testing purposes only
contract MyOFTMock is OFT {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        address _delegate
    ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {}

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}
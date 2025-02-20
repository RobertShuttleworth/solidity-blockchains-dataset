
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_proxy_ERC1967_ERC1967Proxy.sol";

contract UUPSProxy is ERC1967Proxy {
    constructor(address _implementation, bytes memory _data)
        ERC1967Proxy(_implementation, _data)
    {}
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {EarthmetaERC721V2} from "./contracts_lib_EarthmetaERC721V2.sol";

contract TestNFT is EarthmetaERC721V2 {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _earthmeta) public initializer {
        __init_EarthmetaERC721(_earthmeta);
        __ERC721Enumerable_init_unchained();
        __ERC721URIStorage_init_unchained();
        __ERC721_init_unchained("Test NFT", "TNFT");
    }
}
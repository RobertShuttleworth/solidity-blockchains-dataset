// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";

contract BattlemonLineaPark is ERC721 {
    uint256 private _nextTokenId;

    constructor() ERC721("BattlemonLineaPark", "PARK") {}

    function _baseURI() internal pure override returns (string memory) {
        return
            "https://bafybeibrljiwya5jtaiprgmler6apmngt2l5e37zis4mk5gwl3um4yqecq.ipfs.nftstorage.link/json.json";
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return _baseURI();
    }

    function safeMint() public {
        require(block.timestamp <= 1712264400, "Too late");
        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);
    }
}
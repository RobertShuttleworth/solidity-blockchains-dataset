// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import { Ownable } from "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Strings.sol";


contract NFT is ERC721, Ownable {
    using Strings for uint256;

    string public uri;

    constructor(string memory name_,string memory symbol_,string memory uri_, uint256 numOfNFTs) ERC721(name_, symbol_) {
        for (uint256 i; i < numOfNFTs;) {
            _mint(msg.sender, 1 + i);
            unchecked {
                ++i;
            }
        }
        uri = uri_;
    }

    function changeURI(string memory newURI) external onlyOwner {
        uri = newURI;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {

        string memory baseURI = _baseURI();
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    function _baseURI() internal view override returns (string memory) {
        return uri;
    }

} 
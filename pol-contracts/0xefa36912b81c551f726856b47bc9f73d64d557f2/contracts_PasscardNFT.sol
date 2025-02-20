// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

contract PasscardNFT is ERC721, ReentrancyGuard {
    constructor() ERC721("PasscardNFT Test", "PSCT") {}

    uint256 tokenId;

    function batchMint(address to, uint256 amount) nonReentrant public {
        for (uint256 i = 0; i < amount; i++) {
            tokenId += 1;
            _mint(to, tokenId);
        }
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./openzeppelin_contracts_token_ERC721_IERC721.sol";

interface IERC721Burnable is IERC721 {
    function burn(uint256 tokenId) external;
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;


interface IAggregator {

    struct ERC20Pair {
        address token;
        uint256 amount;
    }

    struct ERC721Pair {
        address nft;
        uint256 id;
    }
    
    struct ERC1155Pair {
        address nft;
        uint256 id;
        uint256 amount;
    }

    function batchBuyWithETH(bytes calldata tradeBytes) external payable;

    function batchBuyWithERC20s(
        ERC20Pair[] memory erc20Pairs,
        bytes calldata tradeBytes,
        address[] memory dustTokens
    ) external payable;

    function acceptWithERC721(
         ERC721Pair[] calldata erc721Pairs,
        ERC20Pair[] calldata erc20Pairs,
        address[] calldata dustTokens,
        bytes calldata tradeBytes
    ) external payable;

    function acceptWithERC1155(
        ERC1155Pair[] calldata erc1155Pairs,
        ERC20Pair[] calldata erc20Pairs,
        address[] calldata dustTokens,
        bytes calldata tradeBytes
    ) external  payable;
}
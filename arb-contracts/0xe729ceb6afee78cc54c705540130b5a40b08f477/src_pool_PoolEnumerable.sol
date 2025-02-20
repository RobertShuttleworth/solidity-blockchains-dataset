// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721Enumerable} from "./openzeppelin_contracts_token_ERC721_extensions_IERC721Enumerable.sol";
import {IERC1155} from "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {Pool} from "./src_pool_Pool.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";

/**
    @title An NFT/Token pair for an NFT that implements ERC721Enumerable
    @author boredGenius and 0xmons
 */
abstract contract PoolEnumerable is Pool {
    /// @inheritdoc Pool
    function _sendSpecificNFTsToRecipient(
        address _nft,
        address nftRecipient,
        uint256[] memory nftIds,
        uint256[] memory quantities
    ) internal override {
        // Send NFTs to caller
        // If missing enumerable, update pool's own ID set
        uint256 numNFTs = nftIds.length;
        if (poolManager.is721Contract(_nft)) {
            IERC721 _nftContract = IERC721(_nft);
            for (uint256 i; i < numNFTs; ) {
                _nftContract.safeTransferFrom(
                    address(this),
                    nftRecipient,
                    nftIds[i]
                );
                unchecked {
                    ++i;
                }
            }
        } else {
            IERC1155 _nftContract = IERC1155(_nft);
            for (uint256 i; i < numNFTs; ) {
                _nftContract.safeTransferFrom(
                    address(this),
                    nftRecipient,
                    nftIds[i],
                    quantities[i],
                    "0x"
                );
                unchecked {
                    ++i;
                }
            }
        }
    }

    function _addNftReceivedIds(uint256) internal pure override {
        return;
    }

    /// @inheritdoc Pool
    function getAllHeldIds() external view override returns (uint256[] memory) {
        IERC721 _nft = IERC721(nft());
        uint256 numNFTs = _nft.balanceOf(address(this));
        uint256[] memory ids = new uint256[](numNFTs);
        for (uint256 i; i < numNFTs; ) {
            ids[i] = IERC721Enumerable(address(_nft)).tokenOfOwnerByIndex(
                address(this),
                i
            );

            unchecked {
                ++i;
            }
        }
        return ids;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        //revert();
        return this.onERC721Received.selector;
    }

    // /// @inheritdoc Pool
    // function withdrawERC721(IERC721 a, uint256[] calldata nftIds)
    //     external
    //     override
    //     onlyOwner
    // {
    //     uint256 numNFTs = nftIds.length;
    //     for (uint256 i; i < numNFTs; ) {
    //         a.safeTransferFrom(address(this), msg.sender, nftIds[i]);

    //         unchecked {
    //             ++i;
    //         }
    //     }

    //     emit NFTWithdrawal();
    // }
}
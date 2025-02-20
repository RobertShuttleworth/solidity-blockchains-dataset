// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {IERC1155} from "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";

import {EnumerableSet} from "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";
import {Pool} from "./src_pool_Pool.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";

/**
    @title An NFT/Token pair for an NFT that does not implement ERC721Enumerable
    @author boredGenius and 0xmons
 */
abstract contract PoolMissingEnumerable is Pool {
    using EnumerableSet for EnumerableSet.UintSet;

    // Used for internal ID tracking
    EnumerableSet.UintSet private idSet;

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
                // Remove from id set only for outgoing nfts
                idSet.remove(nftIds[i]);
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
                // Remove from id set only for outgoing nfts
                idSet.remove(nftIds[i]);
                unchecked {
                    ++i;
                }
            }
        }
    }

    /// @inheritdoc Pool
    function getAllHeldIds() external view override returns (uint256[] memory) {
        uint256 numNFTs = idSet.length();
        uint256[] memory ids = new uint256[](numNFTs);
        for (uint256 i; i < numNFTs; ) {
            ids[i] = idSet.at(i);

            unchecked {
                ++i;
            }
        }
        return ids;
    }

    /**
        @dev When safeTransfering an ERC721 in, we add ID to the idSet
        if it's the same collection used by pool. (As it doesn't auto-track because no ERC721Enumerable)
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
        @dev When safeTransfering an ERC721 in, we add ID to the idSet
        if it's the same collection used by pool. (As it doesn't auto-track because no ERC721Enumerable)
     */
    function _addNftReceivedIds(uint256 id) internal override {
        idSet.add(id);
    }
}
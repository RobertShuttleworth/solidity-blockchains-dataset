// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.20;

import {IERC721Receiver} from "./openzeppelin_contracts_token_ERC721_IERC721Receiver.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or
 * {IERC721-setApprovalForAll}.
 */
abstract contract ERC721HolderUpgradeable is Initializable, IERC721Receiver {
    function __ERC721Holder_init() internal onlyInitializing {
    }

    function __ERC721Holder_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
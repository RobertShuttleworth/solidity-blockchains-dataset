// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {VaultAdmin} from "./contracts_strategies_credit_VaultAdmin.sol";
import {IERC721} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC721.sol";

/**
 * @title  - ERC721Manager
 * @author - Credit Cooperative
 * @notice - Provides functions to interact with ERC-721 credit positions from Line-Of-Credit-v2.
 * @dev    - All external and public state changing functions are only callable by the vault manager or operator roles.
 */
abstract contract ERC721Manager is VaultAdmin {
    // See IERC721.balanceOf
    function balanceOfTokenId(address creditPositionToken, address owner) external view returns (uint256 balance) {
        return IERC721(creditPositionToken).balanceOf(owner);
    }

    // See IERC721.ownerOf
    function ownerOfTokenId(address creditPositionToken, uint256 tokenId) public view returns (address owner) {
        return IERC721(creditPositionToken).ownerOf(tokenId);
    }

    // See IERC721.getApproved
    function getApprovedTokenId(address creditPositionToken, uint256 tokenId)
        external
        view
        returns (address operator)
    {
        return IERC721(creditPositionToken).getApproved(tokenId);
    }

    // See IERC721.isApprovedForAll
    function isApprovedForAllTokenId(address creditPositionToken, address owner, address operator)
        external
        view
        returns (bool)
    {
        return IERC721(creditPositionToken).isApprovedForAll(owner, operator);
    }

    /*///////////////////////////////////////////////////////////////
                    State Changing Functions
    //////////////////////////////////////////////////////////////*/

    // See IERC721.safeTransferFrom
    function safeTransferFromTokenId(
        address creditPositionToken,
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external {
        _onlyVaultManager();
        IERC721(creditPositionToken).safeTransferFrom(from, to, tokenId, data);
    }

    // See IERC721.safeTransferFrom
    function safeTransferFromTokenId(address creditPositionToken, address from, address to, uint256 tokenId) external {
        _onlyVaultManager();
        IERC721(creditPositionToken).safeTransferFrom(from, to, tokenId);
    }

    // See IERC721.transferFrom
    function transferFromTokenId(address creditPositionToken, address from, address to, uint256 tokenId) external {
        _onlyVaultManager();
        IERC721(creditPositionToken).transferFrom(from, to, tokenId);
    }

    // See IERC721.approve
    function approveTokenId(address creditPositionToken, address to, uint256 tokenId) external {
        _onlyVaultManager();
        IERC721(creditPositionToken).approve(to, tokenId);
    }

    // See IERC721.setApproval
    function setApprovalForAllTokenId(address creditPositionToken, address operator, bool approved) external {
        _onlyVaultManager();
        IERC721(creditPositionToken).setApprovalForAll(operator, approved);
    }
}
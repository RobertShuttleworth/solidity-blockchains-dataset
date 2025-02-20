// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./contracts_ERC721_ViciERC721.sol";

/**
 * @title Vici ERC721
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 *
 * @dev Tokens created by this contract cannot be transferred except by the
 * contract owner or an account with the CUSTOMER_SERVICE role.
 */
contract ViciNontransferableERC721 is ViciERC721 {
    function _pre_transfer(
        address fromAddress,
        uint256 tokenId
    ) internal virtual {
        address tokenOwner = ownerOf(tokenId);
        if (_is_owner_or_creator(_msgSender())) {
            if (tokenOwner != _msgSender()) {
                tokenData.approve(this, fromAddress, _msgSender(), tokenId);
            }

            return;
        }

        require(_is_owner_or_creator(tokenOwner), "not transferable");
    }

    function _is_owner_or_creator(
        address account
    ) internal view virtual returns (bool) {
        return owner() == account || hasRole(CUSTOMER_SERVICE, account);
    }


    /**
     * @notice an `operator` with the CUSTOMER_SERVICE role is automatically 
     * approved for all.
     * @inheritdoc IERC721
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) public view virtual override returns (bool) {
        return
            _is_owner_or_creator(operator) ||
            super.isApprovedForAll(owner, operator);
    }

    /**
     * @notice Regular users are not allowed to transfer tokens.
     *
     * Requirements:
     * - `tokenId` MUST exist
     * - `fromAddress` and `toAddress` MUST NOT be banned or OFAC sanctioned
     *    addresses. Use `recoverSanctionedAsset()` instead.
     * - One of the following MUST be true:
     *   - Caller is the contract owner or has the CREATOR role
     *   - The token is owned by the contract owner or an account with the
     *     CREATOR role, AND the caller is authorized to transfer the token
     *     on their behalf.
     */
    function transferFrom(
        address fromAddress,
        address toAddress,
        uint256 tokenId
    ) public virtual override {
        _pre_transfer(fromAddress, tokenId);
        super.transferFrom(fromAddress, toAddress, tokenId);
    }

    /**
     * @notice Regular users are not allowed to transfer tokens.
     *
     * Requirements:
     * - `tokenId` MUST exist
     * - `fromAddress` and `toAddress` MUST NOT be banned or OFAC sanctioned
     *    addresses. Use `recoverSanctionedAsset()` instead.
     * - One of the following MUST be true:
     *   - Caller is the contract owner or has the CREATOR role
     *   - The token is owned by the contract owner or an account with the
     *     CREATOR role, AND the caller is authorized to transfer the token
     *     on their behalf.
     */
    function safeTransferFrom(
        address fromAddress,
        address toAddress,
        uint256 tokenId
    ) public virtual override {
        _pre_transfer(fromAddress, tokenId);
        super.safeTransferFrom(fromAddress, toAddress, tokenId);
    }

    /**
     * @notice Regular users are not allowed to transfer tokens.
     *
     * Requirements:
     * - `tokenId` MUST exist
     * - `fromAddress` and `toAddress` MUST NOT be banned or OFAC sanctioned
     *    addresses. Use `recoverSanctionedAsset()` instead.
     * - One of the following MUST be true:
     *   - Caller is the contract owner or has the CREATOR role
     *   - The token is owned by the contract owner or an account with the
     *     CREATOR role, AND the caller is authorized to transfer the token
     *     on their behalf.
     */
    function safeTransferFrom(
        address fromAddress,
        address toAddress,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        _pre_transfer(fromAddress, tokenId);
        super.safeTransferFrom(fromAddress, toAddress, tokenId, _data);
    }

    /**
     * @notice Regular users are not allowed to grant approvals.
     *
     * Requirements:
     * - Caller MUST be the contract owner or have the CUSTOMER_SERVICE role.
     */
    function approve(
        address operator,
        uint256 tokenId
    ) public virtual override onlyOwnerOrRole(CUSTOMER_SERVICE) {
        super.approve(operator, tokenId);
    }

    /**
     * @notice Regular users are not allowed to grant approvals.
     *
     * Requirements:
     * - Caller MUST be the contract owner or have the CUSTOMER_SERVICE role.
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override onlyOwnerOrRole(CUSTOMER_SERVICE) {
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
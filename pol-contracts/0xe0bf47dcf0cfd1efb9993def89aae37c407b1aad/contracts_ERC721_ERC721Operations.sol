// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./contracts_token_ERC721_IERC721Receiver.sol";
import "./contracts_utils_Strings.sol";

import "./contracts_access_IViciAccess.sol";
import "./contracts_common_OwnerOperator.sol";
import "./contracts_lib_ViciAddressUtils.sol";
import "./contracts_ERC721_IERC721Operations.sol";

/**
 * @title ERC721 Operations
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 * 
 * @dev This contract implements most ERC721 behavior on behalf of a main 
 * ERC721 contract, to reduce the bytecode size of the main contract.
 * @dev The main contract MUST be the owner of this contract.
 * @dev Main contracts SHOULD refer to this contract via the IERC721Operations
 * interface.
 */
contract ERC721Operations is OwnerOperator, IERC721Operations {
    using ViciAddressUtils for address;
    using Strings for string;

    /**
     * Tracks all information for an NFT collection.
     * ` tracks who owns which NFT, and who is approved to act on which
     *     accounts behalf.
     * `maxSupply` is the total maximum possible size for the collection.
     * `requireCategory` can be set to `true` to prevent tokens from being
     *     minted outside of a drop (i.e. with empty category name).
     * `dynamicURI` is the address of a contract that can override the default
     *     mechanism for generating tokenURIs.
     * `baseURI` is the string prefixed to the token id to build the token URI
     *     for tokens minted outside of a drop.
     * `allDropNames` is the collection of every drop that has been started.
     * `tokensReserved` is the count of all unminted tokens reserved by all
     *     active drops.
     * `customURIs` contains URI overrides for individual tokens.
     * `dropByName` is a lookup for the ManagedDrop.
     * `dropNameByTokenId` is a lookup to match a token to the drop it was
     *     minted in.
     * `maxRecallPeriod` is the maximum amount of time after minting, in
     *     seconds, that the contract owner or other authorized user can
     *     "recall" the NFT.
     * `bornOnDate` is the block timestamp when the token was minted.
     */
    uint256 public override maxRecallPeriod;
    mapping(uint256 => uint256) bornOnDate;

    /* ################################################################
     * Initialization
     * ##############################################################*/

    function initialize(uint256 maxRecall) public virtual initializer {
        __ERC721Operations_init(maxRecall);
    }

    function __ERC721Operations_init(uint256 maxRecall)
        internal
        onlyInitializing
    {
        __OwnerOperator_init();
        __ERC721Operations_init_unchained(maxRecall);
    }

    function __ERC721Operations_init_unchained(uint256 maxRecall)
        internal
        onlyInitializing
    {
        maxRecallPeriod = maxRecall;
    }

    // @dev see ViciAccess
    modifier notBanned(IViciAccess ams, address account) {
        ams.enforceIsNotBanned(account);
        _;
    }

    // @dev see OwnerOperatorApproval
    modifier tokenExists(uint256 tokenId) {
        enforceItemExists(tokenId);
        _;
    }

    // @dev see ViciAccess
    modifier onlyOwnerOrRole(
        IViciAccess ams,
        address account,
        bytes32 role
    ) {
        ams.enforceOwnerOrRole(role, account);
        _;
    }

    /**
     * @dev reverts if the current time is past the recall window for the token
     *     or if the token has been made unrecallable.
     */
    modifier recallable(uint256 tokenId) {
        requireRecallable(tokenId);
        _;
    }

    /**
     * @dev revert if `account` is not the owner of the token or is not
     *      approved to transfer the token on behalf of its owner.
     */
    function enforceAccess(address account, uint256 tokenId)
        public
        view
        virtual
        override
    {
        enforceAccess(account, ownerOf(tokenId), tokenId, 1);
    }

    /**
     * @dev see IERC721
     */
    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address owner)
    {
        return ownerOfItemAtIndex(tokenId, 0);
    }

    /* ################################################################
     * Minting
     * ##############################################################*/

    /**
     * @dev Safely mints a new token and transfers it to the specified address.
     * @dev Validates drop and available quantities
     * @dev Updates available quantities
     * @dev Deactivates drop when last one is minted
     *
     * Requirements:
     *
     * - `mintData.operator` MUST be owner or have the required role.
     * - `mintData.operator` MUST NOT be banned.
     * - `mintData.category` MAY be an empty string, in which case the token will
     *      be minted in the default category.
     * - If `mintData.category` is an empty string, `requireCategory`
     *      MUST NOT be `true`.
     * - If `mintData.category` is not an empty string it MUST refer to an
     *      existing, active drop with sufficient supply.
     * - `mintData.toAddress` MUST NOT be 0x0.
     * - `mintData.toAddress` MUST NOT be banned.
     * - If `mintData.toAddress` refers to a smart contract, it must implement
     *      {IERC721Receiver-onERC721Received}, which is called upon a safe
     *      transfer.
     * - `mintData.tokenId` MUST NOT exist.
     */
    function mint(IViciAccess ams, ERC721MintData memory mintData)
        public
        virtual
        override
        onlyOwner
        onlyOwnerOrRole(ams, mintData.operator, mintData.requiredRole)
        notBanned(ams, mintData.toAddress)
    {
        _mint(mintData);
    }

    /**
     * @dev Safely mints the new tokens and transfers them to the specified
     *     addresses.
     * @dev Validates drop and available quantities
     * @dev Updates available quantities
     * @dev Deactivates drop when last one is minted
     *
     * Requirements:
     *
     * - `mintData.operator` MUST be owner or have the required role.
     * - `mintData.operator` MUST NOT be banned.
     * - `mintData.category` MAY be an empty string, in which case the token will
     *      be minted in the default category.
     * - If `mintData.category` is an empty string, `requireCategory`
     *      MUST NOT be `true`.
     * - If `mintData.category` is not an empty string it MUST refer to an
     *      existing, active drop with sufficient supply.
     * - `mintData.toAddress` MUST NOT be 0x0.
     * - `mintData.toAddress` MUST NOT be banned.
     * - `_toAddresses` MUST NOT contain 0x0.
     * - `_toAddresses` MUST NOT contain any banned addresses.
     * - The length of `_toAddresses` must equal the length of `_tokenIds`.
     * - If any of `_toAddresses` refers to a smart contract, it must implement
     *      {IERC721Receiver-onERC721Received}, which is called upon a safe
     *      transfer.
     * - `mintData.tokenIds` MUST NOT exist.
     */
    function batchMint(IViciAccess ams, ERC721BatchMintData memory mintData)
        public
        virtual
        override
        onlyOwner
        onlyOwnerOrRole(ams, mintData.operator, mintData.requiredRole)
    {
        require(
            mintData.toAddresses.length == mintData.tokenIds.length,
            "array length mismatch"
        );

        for (uint256 i = 0; i < mintData.tokenIds.length; i++) {
            ams.enforceIsNotBanned(mintData.toAddresses[i]);

            _mint(
                ERC721MintData(
                    mintData.operator,
                    mintData.requiredRole,
                    mintData.toAddresses[i],
                    mintData.tokenIds[i],
                    "",
                    ""
                )
            );
        }
    }

    function _mint(ERC721MintData memory mintData) internal virtual {
        require(
            mintData.toAddress != address(0),
            "ERC721: mint to the zero address"
        );
        require(!exists(mintData.tokenId), "ERC721: token already minted");

        doTransfer(
            mintData.operator,
            address(0),
            mintData.toAddress,
            mintData.tokenId,
            1
        );
        setBornOnDate(mintData.tokenId);
        checkOnERC721Received(
            mintData.operator,
            address(0),
            mintData.toAddress,
            mintData.tokenId,
            mintData.data
        );
    }

    /* ################################################################
     * Burning
     * ##############################################################*/

    /**
     * @dev Burns the identified token.
     * @dev Updates available quantities
     * @dev Will not reactivate the drop.
     *
     * Requirements:
     *
     * - `burnData.operator` MUST be owner or have the required role.
     * - `burnData.operator` MUST NOT be banned.
     * - `burnData.operator` MUST own the token or be authorized by the
     *     owner to transfer the token.
     * - `burnData.tokenId` must exist
     */
    function burn(IViciAccess ams, ERC721BurnData memory burnData)
        public
        virtual
        override
        onlyOwner
        onlyOwnerOrRole(ams, burnData.operator, burnData.requiredRole)
    {
        _burn(burnData);
    }

    function _burn(ERC721BurnData memory burnData) internal virtual {
        address tokenowner = ownerOf(burnData.tokenId);

        doTransfer(
            burnData.operator,
            tokenowner,
            address(0),
            burnData.tokenId,
            1
        );
        clearBornOnDate(burnData.tokenId);
    }

    /* ################################################################
     * Transferring
     * ##############################################################*/

    /**
     * @dev See {IERC721-transferFrom}.
     * @dev See {safeTransferFrom}.
     *
     * - `transferData.fromAddress` and `transferData.toAddress` MUST NOT be
     *     the zero address.
     * - `transferData.toAddress`, `transferData.fromAddress`, and
     *     `transferData.operator` MUST NOT be banned.
     * - `transferData.tokenId` MUST belong to `transferData.fromAddress`.
     * - Calling user must be `transferData.fromAddress` or be approved by
     *     `transferData.fromAddress`.
     * - `transferData.tokenId` must exist
     */
    function transfer(IViciAccess ams, ERC721TransferData memory transferData)
        public
        virtual
        override
        onlyOwner
        notBanned(ams, transferData.operator)
        notBanned(ams, transferData.fromAddress)
        notBanned(ams, transferData.toAddress)
    {
        _transfer(transferData);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     * @dev See {safeTransferFrom}.
     *
     * - `transferData.fromAddress` and `transferData.toAddress` MUST NOT be
     *     the zero address.
     * - `transferData.toAddress`, `transferData.fromAddress`, and
     *     `transferData.operator` MUST NOT be banned.
     * - `transferData.tokenId` MUST belong to `transferData.fromAddress`.
     * - Calling user must be the `transferData.fromAddress` or be approved by
     *     the `transferData.fromAddress`.
     * - `transferData.tokenId` must exist
     */
    function safeTransfer(
        IViciAccess ams,
        ERC721TransferData memory transferData
    )
        public
        virtual
        override
        onlyOwner
        notBanned(ams, transferData.operator)
        notBanned(ams, transferData.fromAddress)
        notBanned(ams, transferData.toAddress)
    {
        _safeTransfer(transferData);
    }

    function _safeTransfer(ERC721TransferData memory transferData)
        internal
        virtual
    {
        _transfer(transferData);
        checkOnERC721Received(
            transferData.operator,
            transferData.fromAddress,
            transferData.toAddress,
            transferData.tokenId,
            transferData.data
        );
    }

    function _transfer(ERC721TransferData memory transferData)
        internal
        virtual
    {
        require(
            transferData.fromAddress != address(0),
            "ERC721: transfer from the zero address"
        );
        require(
            transferData.toAddress != address(0),
            "ERC721: transfer to the zero address"
        );

        doTransfer(
            transferData.operator,
            transferData.fromAddress,
            transferData.toAddress,
            transferData.tokenId,
            1
        );
    }

    /* ################################################################
     * Approvals
     * ##############################################################*/

    /**
     * Requirements
     *
     * - caller MUST be the token owner or be approved for all by the token
     *     owner.
     * - `operator` MUST NOT be the zero address.
     * - `operator` and calling user MUST NOT be banned.
     *
     * @dev see IERC721
     */
    function approve(
        IViciAccess ams,
        address caller,
        address operator,
        uint256 tokenId
    )
        public
        override
        onlyOwner
        notBanned(ams, caller)
        notBanned(ams, operator)
        tokenExists(tokenId)
    {
        address owner = ownerOf(tokenId);
        require(
            caller == owner || isApprovedForAll(owner, caller),
            "not authorized"
        );
        approveForItem(owner, operator, tokenId);
    }

    /**
     * @dev see IERC721
     */
    function getApproved(uint256 tokenId)
        public
        view
        override
        returns (address)
    {
        return getApprovedForItem(ownerOf(tokenId), tokenId);
    }

    /**
     * Requirements
     *
     * - Contract MUST NOT be paused.
     * - `caller` and `operator` MUST NOT be the same address.
     * - `caller` MUST NOT be banned.
     * - `operator` MUST NOT be the zero address.
     * - If `approved` is `true`, `operator` MUST NOT be banned.
     *
     * @dev see IERC721
     */
    function setApprovalForAll(
        IViciAccess ams,
        address caller,
        address operator,
        bool approved
    ) public override onlyOwner notBanned(ams, caller) {
        if (approved) {
            ams.enforceIsNotBanned(operator);
        }
        setApprovalForAll(caller, operator, approved);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function isApprovedOrOwner(address spender, uint256 tokenId)
        public
        view
        override
        tokenExists(tokenId)
        returns (bool)
    {
        return isApproved(spender, ownerOf(tokenId), tokenId, 1);
    }

    /* ################################################################
     * Recall
     * ##############################################################*/

    /**
     * @dev revert if the recall period has expired.
     */
    function requireRecallable(uint256 tokenId) internal view {
        require(_recallTimeRemaining(tokenId) > 0, "not recallable");
    }

    /**
     * @dev If the bornOnDate for `tokenId` + `_maxRecallPeriod` is later than
     * the current timestamp, returns the amount of time remaining, in seconds.
     * @dev If the time is past, or if `tokenId`  doesn't exist in `_tracker`,
     * returns 0.
     */
    function recallTimeRemaining(uint256 tokenId)
        public
        view
        override
        returns (uint256)
    {
        return _recallTimeRemaining(tokenId);
    }

    /**
     * @dev Returns the `bornOnDate` for `tokenId` as a Unix timestamp.
     * @dev If `tokenId` doesn't exist in `_tracker`, returns 0.
     */
    function getBornOnDate(uint256 tokenId)
        public
        view
        override
        returns (uint256)
    {
        return bornOnDate[tokenId];
    }

    /**
     * @dev Returns true if `tokenId` exists in `_tracker`.
     */
    function hasBornOnDate(uint256 tokenId)
        public
        view
        override
        returns (bool)
    {
        return bornOnDate[tokenId] != 0;
    }

    /**
     * @dev Sets the `bornOnDate` for `tokenId` to the current timestamp.
     * @dev This should only be called when the token is minted.
     */
    function setBornOnDate(uint256 tokenId) internal {
        require(!hasBornOnDate(tokenId));
        bornOnDate[tokenId] = block.timestamp;
    }

    /**
     * @dev Remove `tokenId` from `_tracker`.
     * @dev This should be called when the token is burned, or when the end
     * customer has confirmed that they can access the token.
     */
    function clearBornOnDate(uint256 tokenId) internal {
        bornOnDate[tokenId] = 0;
    }

    /**
     * @notice An NFT minted on this contact can be "recalled" by the contract
     * owner for an amount of time defined here.
     * @notice An NFT cannot be recalled once this amount of time has passed
     * since it was minted.
     * @notice The purpose of the recall function is to support customers who
     * have supplied us with an incorrect address or an address that doesn't
     * support Polygon (e.g. Coinbase custodial wallet).
     * @notice Divide the recall period by 86400 to convert from seconds to days.
     *
     * Requirements:
     *
     * - `transferData.operator` MUST be the contract owner or have the
     *      required role.
     * - The token must exist.
     * - The current timestamp MUST be within `maxRecallPeriod` of the token's
     *    `bornOn` date.
     * - `transferData.toAddress` MAY be 0, in which case the token is burned
     *     rather than recalled to a wallet.
     */
    function recall(
        IViciAccess ams,
        ERC721TransferData memory transferData,
        bytes32 requiredRole
    )
        public
        override
        onlyOwner
        notBanned(ams, transferData.toAddress)
        tokenExists(transferData.tokenId)
        recallable(transferData.tokenId)
        onlyOwnerOrRole(ams, transferData.operator, requiredRole)
    {
        _doRecall(transferData, requiredRole);
    }

    /**
     * @notice recover assets in banned or sanctioned accounts
     *
     * Requirements
     * - `transferData.operator` MUST be the contract owner.
     * - The owner of `transferData.tokenId` MUST be banned or OFAC sanctioned
     * - `transferData.destination` MAY be the zero address, in which case the
     *     asset is burned.
     */
    function recoverSanctionedAsset(
        IViciAccess ams,
        ERC721TransferData memory transferData,
        bytes32 requiredRole
    )
        public
        override
        onlyOwner
        notBanned(ams, transferData.toAddress)
        tokenExists(transferData.tokenId)
        onlyOwnerOrRole(ams, transferData.operator, requiredRole)
    {
        require(
            ams.isBanned(transferData.fromAddress) ||
                ams.isSanctioned(transferData.fromAddress),
            "Not banned or sanctioned"
        );
        _doRecall(transferData, requiredRole);
    }

    /**
     * @notice Prematurely ends the recall period for an NFT.
     * @notice This action cannot be reversed.
     *
     * Requirements:
     *
     * - `caller` MUST be one of the following:
     *    - the contract owner.
     *    - the a user with customer service role.
     *    - the token owner.
     *    - an address authorized by the token owner.
     * - `caller` MUST NOT be banned or on the OFAC sanctions list
     */
    function makeUnrecallable(
        IViciAccess ams,
        address caller,
        bytes32 serviceRole,
        uint256 tokenId
    ) public override onlyOwner notBanned(ams, caller) tokenExists(tokenId) {
        if (caller != ams.owner() && !ams.hasRole(serviceRole, caller)) {
            enforceAccess(caller, ownerOf(tokenId), tokenId, 1);
        }

        clearBornOnDate(tokenId);
    }

    function _recallTimeRemaining(uint256 tokenId)
        internal
        view
        returns (uint256)
    {
        uint256 currentTimestamp = block.timestamp;
        uint256 recallDeadline = bornOnDate[tokenId] + maxRecallPeriod;
        if (currentTimestamp >= recallDeadline) {
            return 0;
        }

        return recallDeadline - currentTimestamp;
    }

    function _doRecall(
        ERC721TransferData memory transferData,
        bytes32 requiredRole
    ) internal {
        approveForItem(
            transferData.fromAddress,
            transferData.operator,
            transferData.tokenId
        );

        if (transferData.toAddress == address(0)) {
            _burn(
                ERC721BurnData(
                    transferData.operator,
                    requiredRole,
                    transferData.fromAddress,
                    transferData.tokenId
                )
            );
        } else {
            _safeTransfer(transferData);
        }
    }

    /* ################################################################
     * Hooks
     * ##############################################################*/

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param fromAddress address representing the previous owner of the given token ID
     * @param toAddress target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     */
    function checkOnERC721Received(
        address operator,
        address fromAddress,
        address toAddress,
        uint256 tokenId,
        bytes memory data
    ) internal {
        if (toAddress.isContract()) {
            try
                IERC721Receiver(toAddress).onERC721Received(
                    operator,
                    fromAddress,
                    tokenId,
                    data
                )
            returns (bytes4 retval) {
                require(
                    retval == IERC721Receiver.onERC721Received.selector,
                    "ERC721: transfer to non ERC721Receiver implementer"
                );
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
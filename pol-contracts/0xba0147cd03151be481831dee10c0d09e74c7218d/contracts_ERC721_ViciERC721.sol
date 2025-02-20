// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./contracts_token_ERC721_IERC721Receiver.sol";
import "./contracts_token_ERC721_extensions_IERC721Enumerable.sol";
import "./contracts_token_ERC721_extensions_IERC721Metadata.sol";
import "./contracts_utils_introspection_IERC165.sol";
import "./contracts_utils_Strings.sol";

import "./contracts_common_BaseViciContract.sol";
import "./contracts_metadata_DynamicURI.sol";

import "./contracts_ERC721_extensions_IDropManagement.sol";
import "./contracts_ERC721_extensions_Recallable.sol";
import "./contracts_ERC721_Mintable.sol";
import "./contracts_ERC721_IERC721Operations.sol";

/**
 * @title Vici ERC721
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 *
 * @dev This contract provides base functionality for an ERC721 token.
 * @dev It adds support for recall, multiple drops, pausible, ownable, access
 *      roles, and OFAC sanctions compliance.
 * @dev default recall period is 14 days from minting. Once you have received
 *      your NFT and have verified you can access it, you can call
 *      `makeUnrecallable(uint256)` with your token id to turn off recall for 
 *      your token.
 * @dev Roles used by the access management are
 *      - DEFAULT_ADMIN_ROLE: administers the other roles
 *      - MODERATOR_ROLE_NAME: administers the banned role
 *      - CREATOR_ROLE_NAME: can mint/burn tokens and manage URIs/content
 *      - CUSTOMER_SERVICE: can recall tokens sent to invalid/inaccessible 
 *        addresses within a limited time window.
 *      - BANNED_ROLE: cannot send or receive tokens
 * @dev A "drop" is a pool of reserved tokens with a common base URI,
 *      representing a subset within a collection.
 * @dev If you want an NFT that can evolve through various states, support for
 *      that is available here, but it will be more convenient to extend from
 *      ViciMultiStateERC721
 * @dev the tokenURI function returns the URI for the token metadata. The token 
 *      URI returned is determined by these methods, in order of precedence: 
 *      Custom URI > Dynamic URI > BaseURI/tokenId
 * @dev the Custom URI is set for individual tokens
 * @dev Dynamic URIs are set at the drop level, or at the contract level for 
 *      tokens minted outside of a drop.
 * @dev BaseURIs are set at the drop level, at the state level if using the 
 *      state machine features, and at the contract level for tokens minted 
 *      outside of a drop.
 */
contract ViciERC721 is BaseViciContract, Mintable, Recallable {
    using Strings for string;

    /**
     * @notice emitted when a new drop is started.
     */
    event DropAnnounced(Drop drop);

    /**
     * @dev emitted when a drop ends manually or by selling out.
     */
    event DropEnded(Drop drop);

    /**
     * @dev emitted when a token has its URI overridden via `setCustomURI`.
     * @dev not emitted when the URI changes via state changes, changes to the
     *     base uri, or by whatever tokenData.dynamicURI might do.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev emitted when a token changes state.
     */
    event StateChange(
        uint256 indexed tokenId,
        bytes32 fromState,
        bytes32 toState
    );

    bytes32 public constant INITIAL_STATE = "NEW";
    bytes32 public constant INVALID_STATE = "INVALID";

    string public name;
    string public symbol;

    string public contractURI;

    IERC721Operations public tokenData;
    IDropManagement public dropManager;

    /* ################################################################
     * Initialization
     * ##############################################################*/

    /**
     * @dev the initializer function
     * @param _accessServer The Access Server contract
     * @param _tokenData The ERC721 Operations contract. You MUST set this 
     * contract as the owner of that contract.
     * @param _dropManager The Drop Management contract. You MUST set this 
     * contract as the owner of that contract.
     * @param _name the name of the collection.
     * @param _symbol the token symbol.
     */
    function initialize(
        IAccessServer _accessServer,
        IERC721Operations _tokenData,
        IDropManagement _dropManager,
        string calldata _name,
        string calldata _symbol
    ) public virtual initializer {
        __ViciERC721_init(
            _accessServer,
            _tokenData,
            _dropManager,
            _name,
            _symbol
        );
    }

    function __ViciERC721_init(
        IAccessServer _accessServer,
        IERC721Operations _tokenData,
        IDropManagement _dropManager,
        string calldata _name,
        string calldata _symbol
    ) internal virtual onlyInitializing {
        __BaseViciContract_init(_accessServer);
        __ViciERC721_init_unchained(_tokenData, _dropManager, _name, _symbol);
    }

    function __ViciERC721_init_unchained(
        IERC721Operations _tokenData,
        IDropManagement _dropManager,
        string calldata _name,
        string calldata _symbol
    ) internal virtual onlyInitializing {
        name = _name;
        symbol = _symbol;
        tokenData = _tokenData;
        dropManager = _dropManager;
    }

    // @inheritdoc ERC721
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override(ViciAccess, IERC165)
        returns (bool)
    {
        return (_interfaceId == type(IERC721Enumerable).interfaceId ||
            _interfaceId == type(IERC721).interfaceId ||
            _interfaceId == type(IERC721Metadata).interfaceId ||
            _interfaceId == type(Mintable).interfaceId ||
            ViciAccess.supportsInterface(_interfaceId) ||
            super.supportsInterface(_interfaceId));
    }

    /* ################################################################
     * Queries
     * ##############################################################*/

    // @dev see OwnerOperatorApproval
    modifier tokenExists(uint256 tokenId) {
        tokenData.enforceItemExists(tokenId);
        _;
    }

    /**
     * @notice Returns the total maximum possible size for the collection.
     */
    function maxSupply() public view virtual returns (uint256) {
        return dropManager.getMaxSupply();
    }

    /**
     * @dev Indicates whether any token exist with a given id, or not.
     * @param tokenId the token id
     * @return true if the token exists.
     */
    function exists(uint256 tokenId) public view virtual returns (bool) {
        return tokenData.exists(tokenId);
    }

    /**
     * @inheritdoc IERC721Enumerable
     */
    function totalSupply() public view virtual returns (uint256) {
        return tokenData.itemCount();
    }

    /**
     * @dev returns the amount available to be minted outside of any drops, or
     *     the amount available to be reserved in new drops.
     * @dev {total available} = {max supply} - {amount minted so far} -
     *      {amount remaining in pools reserved for drops}
     */
    function totalAvailable() public view virtual returns (uint256) {
        return dropManager.totalAvailable();
    }

    /**
     * @inheritdoc IERC721Enumerable
     */
    function tokenOfOwnerByIndex(address owner, uint256 index)
        public
        view
        virtual
        returns (uint256)
    {
        return tokenData.itemOfOwnerByIndex(owner, index);
    }

    /**
     * @inheritdoc IERC721Enumerable
     */
    function tokenByIndex(uint256 index) public view virtual returns (uint256) {
        return tokenData.itemAtIndex(index);
    }

    /**
     * @inheritdoc IERC721
     */
    function balanceOf(address owner)
        public
        view
        virtual
        returns (uint256 balance)
    {
        return tokenData.ownerItemCount(owner);
    }

    /**
     * @inheritdoc IERC721
     */
    function ownerOf(uint256 tokenId)
        public
        view
        virtual
        returns (address owner)
    {
        return tokenData.ownerOfItemAtIndex(tokenId, 0);
    }

    /**
     * @notice Returns a list of all the token ids owned by an address.
     */
    function userWallet(address user)
        public
        view
        virtual
        returns (uint256[] memory)
    {
        return tokenData.userWallet(user);
    }

    /* ################################################################
     * URI Management
     * ##############################################################*/

    /**
     * @notice sets a uri pointing to metadata about this token collection.
     * @dev OpenSea honors this. Other marketplaces might honor it as well.
     * @param newContractURI the metadata uri
     *
     * Requirements:
     *
     * - Contract MUST NOT be paused.
     * - Calling user MUST be owner or have the creator role.
     * - Calling user MUST NOT be banned.
     */
    function setContractURI(string calldata newContractURI)
        public
        virtual
        noBannedAccounts
        onlyOwnerOrRole(CREATOR_ROLE_NAME)
    {
        contractURI = newContractURI;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        tokenExists(tokenId)
        returns (string memory)
    {
        return dropManager.getTokenURI(tokenId);
    }

    /**
     * @notice This sets the baseURI for any tokens minted outside of a drop.
     * @param baseURI the new base URI.
     *
     * Requirements:
     *
     * - Calling user MUST be owner or have the uri manager role.
     */
    function setBaseURI(string calldata baseURI)
        public
        virtual
        onlyOwnerOrRole(CREATOR_ROLE_NAME)
    {
        dropManager.setBaseURI(baseURI);
    }

    /**
     * @dev Change the base URI for the named drop.
     * Requirements:
     *
     * - Calling user MUST be owner or URI manager.
     * - `dropName` MUST refer to a valid drop.
     * - `baseURI` MUST be different from the current `baseURI` for the named drop.
     * - `dropName` MAY refer to an active or inactive drop.
     */
    function setBaseURI(bytes32 dropName, string calldata baseURI)
        public
        virtual
        onlyOwnerOrRole(CREATOR_ROLE_NAME)
    {
        dropManager.setBaseURIForDrop(dropName, baseURI);
    }

    /**
     * @notice Sets a custom uri for a token
     * @param tokenId the token id
     * @param newURI the new base uri
     *
     * Requirements:
     *
     * - Calling user MUST be owner or have the creator role.
     * - Calling user MUST NOT be banned.
     * - `tokenId` MAY be for a non-existent token.
     * - `newURI` MAY be an empty string.
     */
    function setCustomURI(uint256 tokenId, string calldata newURI)
        public
        virtual
        noBannedAccounts
        onlyOwnerOrRole(CREATOR_ROLE_NAME)
    {
        dropManager.setCustomURI(tokenId, newURI);
        emit URI(newURI, tokenId);
    }

    /**
     * @notice Use this contract to override the default mechanism for
     *     generating token ids.
     *
     * Requirements:
     * - `dynamicURI` MAY be the null address, in which case the override is
     *     removed and the default mechanism is used again.
     * - If `dynamicURI` is not the null address, it MUST be the address of a
     *     contract that implements the DynamicURI interface (0xc87b56dd).
     */
    function setDynamicURI(bytes32 dropName, DynamicURI dynamicURI)
        public
        virtual
        noBannedAccounts
        onlyOwnerOrRole(CREATOR_ROLE_NAME)
    {
        dropManager.setDynamicURI(dropName, dynamicURI);
    }

    /* ################################################################
     * Minting
     * ##############################################################*/

    /**
     * @notice Safely mints a new token and transfers it to `toAddress`.
     * @param dropName Type, group, option name etc.
     * @param toAddress The account to receive the newly minted token.
     * @param tokenId The id of the new token.
     *
     * Requirements:
     *
     * - Contract MUST NOT be paused.
     * - Calling user MUST be owner or have the creator role.
     * - Calling user MUST NOT be banned.
     * - `dropName` MAY be an empty string, in which case the token will be
     *     minted in the default category.
     * - If `dropName` is an empty string, `tokenData.requireCategory` MUST
     *     NOT be `true`.
     * - If `dropName` is not an empty string it MUST refer to an existing,
     *     active drop with sufficient supply.
     * - `toAddress` MUST NOT be 0x0.
     * - `toAddress` MUST NOT be banned.
     * - If `toAddress` refers to a smart contract, it must implement
     *     {IERC721Receiver-onERC721Received}, which is called upon a safe
     *     transfer.
     * - `tokenId` MUST NOT exist.
     */
    function mint(
        bytes32 dropName,
        address toAddress,
        uint256 tokenId
    ) public virtual whenNotPaused {
        tokenData.mint(
            this,
            ERC721MintData(
                _msgSender(),
                CREATOR_ROLE_NAME,
                toAddress,
                tokenId,
                "",
                ""
            )
        );

        dropManager.onMint(dropName, tokenId, "");

        _post_mint_hook(toAddress, tokenId);
    }

    /**
     * @notice Safely mints a new token with a custom URI and transfers it to
     *      `toAddress`.
     * @param dropName Type, group, option name etc.
     * @param toAddress The account to receive the newly minted token.
     * @param tokenId The id of the new token.
     * @param customURI the custom URI.
     *
     * Requirements:
     *
     * - Contract MUST NOT be paused.
     * - Calling user MUST be owner or have the creator role.
     * - `dropName` MAY be an empty string, in which case the token will be
     *     minted in the default category.
     * - If `dropName` is an empty string, `tokenData.requireCategory` MUST
     *     NOT be `true`.
     * - If `dropName` is not an empty string it MUST refer to an existing,
     *     active drop with sufficient supply.
     * - `toAddress` MUST NOT be 0x0.
     * - `toAddress` MUST NOT be banned.
     * - If `toAddress` refers to a smart contract, it must implement
     *      {IERC721Receiver-onERC721Received}, which is called upon a safe
     *      transfer.
     * - `tokenId` MUST NOT exist.
     * - `customURI` MAY be empty, in which case it will be ignored.
     */
    function mintCustom(
        bytes32 dropName,
        address toAddress,
        uint256 tokenId,
        string calldata customURI
    ) public virtual whenNotPaused {
        tokenData.mint(
            this,
            ERC721MintData(
                _msgSender(),
                CREATOR_ROLE_NAME,
                toAddress,
                tokenId,
                customURI,
                ""
            )
        );

        dropManager.onMint(dropName, tokenId, customURI);

        _post_mint_hook(toAddress, tokenId);
    }

    /**
     * @notice Safely mints a new token and transfers it to `toAddress`.
     * @param dropName Type, group, option name etc.
     * @param toAddress The account to receive the newly minted token.
     * @param tokenId The id of the new token.
     * @param customURI the custom URI.
     * @param _data bytes optional data to send along with the call
     *
     * Requirements:
     *
     * - Contract MUST NOT be paused.
     * - Calling user MUST be owner or have the creator role.
     * - Calling user MUST NOT be banned.
     * - `dropName` MAY be an empty string, in which case the token will be
     *     minted in the default category.
     * - If `dropName` is an empty string, `tokenData.requireCategory` MUST
     *     NOT be `true`.
     * - If `dropName` is not an empty string it MUST refer to an existing,
     *     active drop with sufficient supply.
     * - `toAddress` MUST NOT be 0x0.
     * - `toAddress` MUST NOT be banned.
     * - If `toAddress` refers to a smart contract, it must implement
     *      {IERC721Receiver-onERC721Received}, which is called upon a safe
     *      transfer.
     * - `tokenId` MUST NOT exist.
     * - `customURI` MAY be empty, in which case it will be ignored.
     */
    function safeMint(
        bytes32 dropName,
        address toAddress,
        uint256 tokenId,
        string calldata customURI,
        bytes calldata _data
    ) public virtual whenNotPaused {
        tokenData.mint(
            this,
            ERC721MintData(
                _msgSender(),
                CREATOR_ROLE_NAME,
                toAddress,
                tokenId,
                customURI,
                _data
            )
        );

        dropManager.onMint(dropName, tokenId, customURI);

        _post_mint_hook(toAddress, tokenId);
    }

    /**
     * @notice Safely mints a batch of new tokens and transfers them to the
     *      `toAddresses`.
     * @param dropName Type, group, option name etc.
     * @param toAddresses The accounts to receive the newly minted tokens.
     * @param tokenIds The ids of the new tokens.
     *
     * Requirements:
     *
     * - Contract MUST NOT be paused.
     * - Calling user MUST be owner or have the creator role.
     * - Calling user MUST NOT be banned.
     * - `dropName` MAY be an empty string, in which case the token will be
     *     minted in the default category.
     * - If `dropName` is an empty string, `tokenData.requireCategory` MUST
     *     NOT be `true`.
     * - If `dropName` is not an empty string it MUST refer to an existing,
     *     active drop with sufficient supply.
     * - `toAddresses` MUST NOT contain 0x0.
     * - `toAddresses` MUST NOT contain any banned addresses.
     * - The length of `toAddresses` must equal the length of `tokenIds`.
     * - If any of `toAddresses` refers to a smart contract, it must implement
     *      {IERC721Receiver-onERC721Received}, which is called upon a safe
     *      transfer.
     * - `tokenIds` MUST NOT exist.
     */
    function batchMint(
        bytes32 dropName,
        address[] calldata toAddresses,
        uint256[] calldata tokenIds
    ) public virtual whenNotPaused {
        tokenData.batchMint(
            this,
            ERC721BatchMintData(
                _msgSender(),
                CREATOR_ROLE_NAME,
                toAddresses,
                tokenIds
            )
        );

        dropManager.onBatchMint(dropName, tokenIds);

        for (uint256 i = 0; i < toAddresses.length; i++) {
            _post_mint_hook(toAddresses[i], tokenIds[i]);
        }
    }

    /* ################################################################
     * Burning
     * ##############################################################*/

    /**
     * @notice Burns the identified token.
     * @param tokenId The token to be burned.
     *
     * Requirements:
     *
     * - Contract MUST NOT be paused.
     * - Calling user MUST be owner or have the creator role.
     * - Calling user MUST NOT be banned.
     * - Calling user MUST own the token or be authorized by the owner to
     *     transfer the token.
     * - `tokenId` must exist
     */
    function burn(uint256 tokenId) public virtual whenNotPaused {
        _burn(tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address tokenowner = ownerOf(tokenId);
        tokenData.burn(
            this,
            ERC721BurnData(_msgSender(), CREATOR_ROLE_NAME, tokenowner, tokenId)
        );

        _post_burn_hook(tokenowner, tokenId);
    }

    /* ################################################################
     * Transferring
     * ##############################################################*/

    /**
     * @dev See {IERC721-transferFrom}.
     * @dev See {safeTransferFrom}.
     *
     * Requirements
     *
     * - Contract MUST NOT be paused.
     * - `fromAddress` and `toAddress` MUST NOT be the zero address.
     * - `toAddress`, `fromAddress`, and calling user MUST NOT be banned.
     * - `tokenId` MUST belong to `fromAddress`.
     * - Calling user must be the `fromAddress` or be approved by the `fromAddress`.
     * - `tokenId` must exist
     *
     * @inheritdoc IERC721
     */
    function transferFrom(
        address fromAddress,
        address toAddress,
        uint256 tokenId
    ) public virtual override whenNotPaused {
        tokenData.transfer(
            this,
            ERC721TransferData(
                _msgSender(),
                fromAddress,
                toAddress,
                tokenId,
                ""
            )
        );

        _post_transfer_hook(fromAddress, toAddress, tokenId);
    }

    /**
     * Requirements
     *
     * - Contract MUST NOT be paused.
     * - `fromAddress` and `toAddress` MUST NOT be the zero address.
     * - `toAddress`, `fromAddress`, and calling user MUST NOT be banned.
     * - `tokenId` MUST belong to `fromAddress`.
     * - Calling user must be the `fromAddress` or be approved by the `fromAddress`.
     * - If `toAddress` refers to a smart contract, it must implement
     *      {IERC721Receiver-onERC721Received}, which is called upon a safe
     *      transfer.
     * - `tokenId` must exist
     *
     * @inheritdoc IERC721
     */
    function safeTransferFrom(
        address fromAddress,
        address toAddress,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(fromAddress, toAddress, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     * @dev See {safeTransferFrom}.
     *
     * - Contract MUST NOT be paused.
     * - `fromAddress` and `toAddress` MUST NOT be the zero address.
     * - `toAddress`, `fromAddress`, and calling user MUST NOT be banned.
     * - `tokenId` MUST belong to `fromAddress`.
     * - Calling user must be the `fromAddress` or be approved by the `fromAddress`.
     * - If `toAddress` refers to a smart contract, it must implement
     *      {IERC721Receiver-onERC721Received}, which is called upon a safe
     *      transfer.
     * - `tokenId` must exist
     *
     * @inheritdoc IERC721
     */
    function safeTransferFrom(
        address fromAddress,
        address toAddress,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override whenNotPaused {
        tokenData.safeTransfer(
            this,
            ERC721TransferData(
                _msgSender(),
                fromAddress,
                toAddress,
                tokenId,
                _data
            )
        );

        _post_transfer_hook(fromAddress, toAddress, tokenId);
    }

    /* ################################################################
     * Approvals
     * ##############################################################*/

    /**
     * Requirements
     *
     * - Contract MUST NOT be paused.
     * - caller MUST be the token owner or be approved for all by the token
     *     owner.
     * - `operator` MUST NOT be the zero address.
     * - `operator` and calling user MUST NOT be banned.
     *
     * @inheritdoc IERC721
     */
    function approve(address operator, uint256 tokenId)
        public
        virtual
        override
        whenNotPaused
    {
        tokenData.approve(this, _msgSender(), operator, tokenId);
        emit Approval(ownerOf(tokenId), operator, tokenId);
    }

    /**
     * @inheritdoc IERC721
     */
    function getApproved(uint256 tokenId)
        public
        view
        virtual
        override
        returns (address)
    {
        return tokenData.getApproved(tokenId);
    }

    /**
     * Requirements
     *
     * - Contract MUST NOT be paused.
     * - Calling user and `operator` MUST NOT be the same address.
     * - Calling user MUST NOT be banned.
     * - `operator` MUST NOT be the zero address.
     * - If `approved` is `true`, `operator` MUST NOT be banned.
     *
     * @inheritdoc IERC721
     */
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
        whenNotPaused
    {
        tokenData.setApprovalForAll(this, _msgSender(), operator, approved);
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @inheritdoc IERC721
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return tokenData.isApprovedForAll(owner, operator);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     * - `tokenId` must exist.
     */
    function isApprovedOrOwner(address spender, uint256 tokenId)
        public
        view
        virtual
        returns (bool)
    {
        return tokenData.isApprovedOrOwner(spender, tokenId);
    }

    /* ################################################################
     * Drop Management
     * --------------------------------------------------------------
     * If you need amountRemainingInDrop(bytes32), dropMintCount(bytes32),
     * dropCount(), dropNameForIndex(uint256), dropForIndex(uint256),
     * dropForName(bytes32), isDropActive(bytes32), getBaseURI(), or
     * getBaseURIForDrop(bytes32), please use the drop manager contract
     * directly.
     * ##############################################################*/

    /**
     * @notice If categories are required, attempts to mint with an empty drop
     * name will revert.
     */
    function setRequireCategory(bool required) public virtual onlyOwner {
        dropManager.setRequireCategory(required);
    }

    /**
     * @notice Starts a new drop.
     * @param dropName The name of the new drop
     * @param dropStartTime The unix timestamp of when the drop is active
     * @param dropSize The number of NFTs in this drop
     * @param baseURI The base URI for the tokens in this drop
     *
     * Requirements:
     *
     * - Calling user MUST be owner or have the drop manager role.
     * - There MUST be sufficient unreserved tokens for the drop size.
     * - The drop size MUST NOT be empty.
     * - The drop name MUST NOT be empty.
     * - The drop name MUST be unique.
     */
    function startNewDrop(
        bytes32 dropName,
        uint32 dropStartTime,
        uint32 dropSize,
        string calldata baseURI
    ) public virtual onlyOwnerOrRole(CREATOR_ROLE_NAME) {
        dropManager.startNewDrop(
            dropName,
            dropStartTime,
            dropSize,
            INITIAL_STATE,
            baseURI
        );

        emit DropAnnounced(Drop(dropName, dropStartTime, dropSize, baseURI));
    }

    /**
     * @notice Ends the named drop immediately. It's not necessary to call this.
     * The current drop ends automatically once the last token is sold.
     *
     * @param dropName The name of the drop to deactivate
     *
     * Requirements:
     *
     * - Calling user MUST be owner or have the drop manager role.
     * - There MUST be an active drop with the `dropName`.
     */
    function deactivateDrop(bytes32 dropName)
        public
        virtual
        onlyOwnerOrRole(CREATOR_ROLE_NAME)
    {
        dropManager.deactivateDrop(dropName);
    }

    /* ################################################################
     *                          State Management
     * --------------------------------------------------------------
     * Internal functions are here in the base class. If you want to
     *      expose these functions, you may want to extend from
     *                        ViciMultiStateERC721.
     * ##############################################################*/

    /**
     * @dev Returns the token's current state
     * @dev Returns empty string if the token is not managed by a state machine.
     * @param tokenId the tokenId
     *
     * Requirements:
     * - `tokenId` MUST exist
     */
    function getState(uint256 tokenId)
        public
        view
        virtual
        tokenExists(tokenId)
        returns (bytes32)
    {
        return dropManager.getState(tokenId);
    }

    function _setState(
        uint256 tokenId,
        bytes32 stateName,
        bool requireValidTransition
    ) internal virtual tokenExists(tokenId) {
        dropManager.setState(tokenId, stateName, requireValidTransition);
        emit StateChange(tokenId, getState(tokenId), stateName);
    }

    /* ################################################################
     *                             Recall
     * ##############################################################*/

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
     * @dev The maximum amount of time after minting, in seconds, that the contract
     * owner or other authorized user can "recall" the NFT.
     */
    function maxRecallPeriod() public view virtual returns (uint256) {
        return tokenData.maxRecallPeriod();
    }

    /**
     * @notice Returns the amount of time remaining before a token can be recalled.
     * @notice Divide the recall period by 86400 to convert from seconds to days.
     * @notice This will return 0 if the token cannot be recalled.
     * @notice Due to the way block timetamps are determined, there is a 15
     * second margin of error in the result.
     *
     * @param tokenId the token id.
     *
     * Requirements:
     *
     * - This function MAY be called with a non-existent `tokenId`. The
     *   function will return 0 in this case.
     */
    function recallTimeRemaining(uint256 tokenId)
        public
        view
        virtual
        returns (uint256)
    {
        return tokenData.recallTimeRemaining(tokenId);
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
     * @param toAddress The address where the token will go after it has been recalled.
     * @param tokenId The token to be recalled.
     *
     * Requirements:
     *
     * - The caller MUST be the contract owner or have the customer service role.
     * - The token must exist.
     * - The current timestamp MUST be within `maxRecallPeriod` of the token's
     *    `bornOn` date.
     * - `toAddress` MAY be 0, in which case the token is burned rather than
     *    recalled to a wallet.
     */
    function recall(address toAddress, uint256 tokenId)
        public
        virtual
        onlyOwnerOrRole(CUSTOMER_SERVICE)
    {
        address currentOwner = ownerOf(tokenId);

        tokenData.recall(
            this,
            ERC721TransferData(
                _msgSender(),
                currentOwner,
                toAddress,
                tokenId,
                ""
            ),
            CUSTOMER_SERVICE
        );

        _post_recall_hook(currentOwner, toAddress, tokenId);
    }

    /**
     * @notice recover assets in banned or sanctioned accounts
     * @param toAddress the location to send the asset
     * @param tokenId the token id
     *
     * Requirements
     * - Caller MUST be the contract owner.
     * - The owner of `tokenId` MUST be banned or OFAC sanctioned
     * - `toAddress` MAY be the zero address, in which case the asset is
     *      burned.
     */
    function recoverSanctionedAsset(address toAddress, uint256 tokenId)
        public
        virtual
        onlyOwner
    {
        address currentOwner = ownerOf(tokenId);

        tokenData.recoverSanctionedAsset(
            this,
            ERC721TransferData(
                _msgSender(),
                currentOwner,
                toAddress,
                tokenId,
                ""
            ),
            CUSTOMER_SERVICE
        );

        _post_recall_hook(currentOwner, toAddress, tokenId);
    }

    /**
     * @notice Prematurely ends the recall period for an NFT.
     * @notice This action cannot be reversed.
     *
     * @param tokenId The token to be recalled.
     *
     * Requirements:
     *
     * - The caller MUST be one of the following:
     *    - the contract owner.
     *    - the a user with customer service role.
     *    - the token owner.
     *    - an address authorized by the token owner.
     * - The caller MUST NOT be banned or on the OFAC sanctions list
     */
    function makeUnrecallable(uint256 tokenId) public virtual {
        tokenData.makeUnrecallable(
            this,
            _msgSender(),
            CUSTOMER_SERVICE,
            tokenId
        );
    }

    /* ################################################################
     * Hooks
     * ##############################################################*/

    function _post_mint_hook(address toAddress, uint256 tokenId)
        internal
        virtual
    {
        _post_transfer_hook(address(0), toAddress, tokenId);
    }

    function _post_burn_hook(address fromAddress, uint256 tokenId)
        internal
        virtual
    {
        dropManager.postBurnUpdate(tokenId);
        _post_transfer_hook(fromAddress, address(0), tokenId);
    }

    function _post_transfer_hook(
        address fromAddress,
        address toAddress,
        uint256 tokenId
    ) internal virtual {
        emit Transfer(fromAddress, toAddress, tokenId);
    }

    function _post_recall_hook(
        address fromAddress,
        address toAddress,
        uint256 tokenId
    ) internal virtual {
        if (toAddress == address(0)) {
            _post_burn_hook(fromAddress, tokenId);
        } else {
            _post_transfer_hook(fromAddress, toAddress, tokenId);
        }

        emit TokenRecalled(tokenId, toAddress);
        emit Transfer(fromAddress, toAddress, tokenId);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[46] private __gap;
}
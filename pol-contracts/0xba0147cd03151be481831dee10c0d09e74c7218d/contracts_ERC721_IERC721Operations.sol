// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./contracts_common_IOwnerOperator.sol";
import "./contracts_access_IViciAccess.sol";

/**
 * Information needed to mint a single token.
 */
struct ERC721MintData {
    address operator;
    bytes32 requiredRole;
    address toAddress;
    uint256 tokenId;
    string customURI;
    bytes data;
}

/**
 * Information needed to mint a batch of tokens.
 */
struct ERC721BatchMintData {
    address operator;
    bytes32 requiredRole;
    address[] toAddresses;
    uint256[] tokenIds;
}

/**
 * Information needed to transfer a token.
 */
struct ERC721TransferData {
    address operator;
    address fromAddress;
    address toAddress;
    uint256 tokenId;
    bytes data;
}

/**
 * Information needed to burn a token.
 */
struct ERC721BurnData {
    address operator;
    bytes32 requiredRole;
    address fromAddress;
    uint256 tokenId;
}

/**
 * @title ERC721 Operations Interface
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 * 
 * @dev Interface for ERC721 Operations.
 * @dev Main contracts SHOULD refer to the ops contract via this interface.
 */
interface IERC721Operations is IOwnerOperator {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    /**
     * @dev emitted when a token is recalled during the recall period.
     * @dev emitted when a token is recovered from a banned or OFAC sanctioned
     *     user.
     */
    event TokenRecalled(uint256 tokenId, address recallWallet);

    /**
     * @dev revert if `account` is not the owner of the token or is not
     *      approved to transfer the token on behalf of its owner.
     */
    function enforceAccess(address account, uint256 tokenId) external view;

    /**
     * @dev see IERC721
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

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
    function mint(IViciAccess ams, ERC721MintData memory mintData) external;

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
        external;

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
    function burn(IViciAccess ams, ERC721BurnData memory burnData) external;

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
        external;

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
    ) external;

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
    ) external;

    /**
     * @dev see IERC721
     */
    function getApproved(uint256 tokenId) external view returns (address);

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
    ) external;

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function isApprovedOrOwner(address spender, uint256 tokenId)
        external
        view
        returns (bool);

    /* ################################################################
     * Recall
     * ##############################################################*/

    /**
     * @dev the maximum amount of time after minting, in seconds, that the
     * contract owner or other authorized user can "recall" the NFT.
     */
    function maxRecallPeriod() external view returns (uint256);

    /**
     * @dev If the bornOnDate for `tokenId` + `_maxRecallPeriod` is later than
     * the current timestamp, returns the amount of time remaining, in seconds.
     * @dev If the time is past, or if `tokenId`  doesn't exist in `_tracker`,
     * returns 0.
     */
    function recallTimeRemaining(uint256 tokenId)
        external
        view
        returns (uint256);

    /**
     * @dev Returns the `bornOnDate` for `tokenId` as a Unix timestamp.
     * @dev If `tokenId` doesn't exist in `_tracker`, returns 0.
     */
    function getBornOnDate(uint256 tokenId) external view returns (uint256);

    /**
     * @dev Returns true if `tokenId` exists in `_tracker`.
     */
    function hasBornOnDate(uint256 tokenId) external view returns (bool);

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
    ) external;

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
    ) external;

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
    ) external;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;


import {AccessControlUpgradeable} from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {UUPSUpgradeable} from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import {MulticallUpgradeable} from "./openzeppelin_contracts-upgradeable_utils_MulticallUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_ERC721EnumerableUpgradeable.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {ERC721HolderUpgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC721_utils_ERC721HolderUpgradeable.sol";

import "./contracts_relocation_interfaces_IExchangeBillManager.sol";
import "./contracts_relocation_interfaces_IExchangeBillTokenDescriptor.sol";
import './contracts_relocation_base_ERC721PermitUpgradeable.sol';
import './contracts_relocation_base_ExchangeBillPaymentsUpgradeable.sol';
import "./contracts_relocation_libraries_Dates.sol";

/**
 * @notice Contract module which provide an implementation of the ZicoDAOs relocations to NFT wrapper.
 *
 * @custom:website https://nft.poczta-polska.pl
 * @author rutilicus.eth (ArchXS)
 * @custom:security-contact contact@archxs.com 
 */
contract ExchangeBillManager is Initializable, MulticallUpgradeable, ERC721PermitUpgradeable, ExchangeBillPaymentsUpgradeable, ERC721EnumerableUpgradeable, ERC721HolderUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, IExchangeBillManager {
    // Add the library methods
    using SafeERC20 for IERC20;

    /**
     * @dev Structure used to store drafts of bill notes.
     */
    struct DraftedNote {
        BillNote note;
        uint256 timestamp;
        string series;
        uint16 tranche;
    }

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    uint256 private constant BASE_TIMESTAMP = 1727678520; // 30.09.2024 08:42:00

    /// Default currency for refunds.
    IERC20 public currency;

    /// @dev The address of the token descriptor contract, which handles generating token URIs for position tokens
    address private _tokenDescriptor;

    /// @dev The ID of the next token that will be minted.
    uint256 private _nextTokenId;

    /// @dev The tranche number to be alocated
    uint16 private _nextTranche;

    /// @dev Mapping that holds bills mapped to NFTs
    mapping(uint256 => BillNote) private _bills;

    /// @dev Mapping token ID liability data
    mapping(uint256 => Promissory) private _promissories;

    /// @dev Mapping token ID liability data
    mapping(address => mapping(uint16 => DraftedNote)) private _drafts;

    /// @dev Emitted whetn token bill issued
    event BillTokenIssued(uint256 tokenId, address recipient, uint256 amount);

    /**
     * @dev Emit when discount successfully applid.
     */
    event BillTokenWithdrawn(uint256 tokenId, address recipient, uint256 amount);

    /**
     * @dev Emit when bill tolen has been burned.
     */
    event BillTokenBurned(uint256 tokenId);

    /**
     * @dev When sender call is not authorized.
     * 
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     */
    error TokenNotApproved(address sender, uint256 tokenId);

    /**
     * @dev When liability is not cleared.
     * 
     * @param tokenId Identifier number of a token.
     */
    error LiabilityNotCleared(address sender, uint256 tokenId);

    /**
     * @dev When draft data is invalid.
     */
    error InvalidBillDrafts();

    /**
     * @dev When draft data is invalid.
     */
    error BillAlreadyIssued(uint256 tokenId);

    /**
     * @dev When caller is not allowed to mint a bill token.
     */
    error InvalidRemitent(address sender);

    /**
     * @dev When given token ID has no associated promissory.
     */
    error InvalidTokenID();

    /**
     * @dev When claim period is missed.
     */
    error ClaimDeadlineMissed(uint256 deadline);

    /**
     * @dev When payout deadline is missed.
     */
    error PayoutDeadlineMissed(uint256 deadline);

    /**
     * @dev When payout is not active yet.
     */
    error PayoutNotActive();

    bytes32 public constant PAYEE_ROLE = keccak256("PAYEE_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _initialAdmin, string memory _name, string memory _symbol, string memory _version, address _descriptor, address _currency) public initializer {
        __ExchangeBillManager_init(_initialAdmin, _name, _symbol, _version, _descriptor, _currency);
    }

    function __ExchangeBillManager_init(address _initialAdmin, string memory _name, string memory _symbol, string memory _version, address _descriptor, address _currency) internal onlyInitializing {
        __ERC721Permit_init(_name, _symbol, _version);
        __ERC721Enumerable_init();
        __ERC721Holder_init();
        __ExchangeBillPayments_init();
        __AccessControl_init();
        __Multicall_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
        _grantRole(UPGRADER_ROLE, _initialAdmin);
        _grantRole(ISSUER_ROLE, _initialAdmin);

        __ExchangeBillManager_init_unchained(_descriptor, _currency); 
    }

    function __ExchangeBillManager_init_unchained(address tokenDescriptor, address _currency) internal onlyInitializing {
        _tokenDescriptor = tokenDescriptor;
        currency = IERC20(_currency);

        _nextTokenId = 1;
        _nextTranche = 1;
    }

    function draw(uint16 tranche, DraftedNote[] calldata notes) external onlyRole(ISSUER_ROLE) {
        if (notes.length == 0) {
            revert InvalidBillDrafts();
        }

        uint256 _trancheSupply = 0;
        for (uint256 i = 0; i < notes.length; i++) {
            DraftedNote memory draft = notes[i];

            if (draft.note.currency != address(currency)) {
                revert InvalidBillDrafts();
            }

            if (draft.timestamp == 0) {
                draft.timestamp = block.timestamp;
            }

            _drafts[draft.note.remitent][tranche] = draft;

            unchecked {
                _trancheSupply += draft.note.amount;
            }
        }

        currency.approve(address(this), _trancheSupply);
    }
    
    /**
     * @dev See {IExchangeBillManager-present}.
     */
    function present(uint256 tokenId) public view returns (BillNote memory, Promissory memory) {
        BillNote storage note = _bills[tokenId];
        Promissory storage promissory = _promissories[tokenId];

        if (note.remitent == address(0) || promissory.tranche == 0) {
            revert InvalidTokenID();
        }

        return (note, promissory);
    }

    /**
     * @dev Allows for administrative issuance.
     */
    function issue(address[] calldata remitents, uint16 tranche, uint256 timestamp) external onlyRole(ISSUER_ROLE) returns (uint256 count) {
        for (uint256 i = 0; i < remitents.length; i++) {
            _claim(tranche, remitents[i], timestamp);
            count++;
        }
    }

    /**
     * @dev Allows for administrative amendment.
     */
    function amendNotes(uint256[] calldata tokenIds, BillNote[] calldata notes) external onlyRole(ISSUER_ROLE) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _bills[tokenIds[i]] = notes[i];
        }
    }

    /**
     * @dev Allows for administrative amendment.
     */
    // function amendSeries(uint256[] calldata tokenIds, string calldata series) external onlyRole(ISSUER_ROLE) {
    //     for (uint256 i = 0; i < tokenIds.length; i++) {
    //         _promissories[i].series = series;
    //     }
    // }

    /**
     * @dev See {IExchangeBillManager-claim}.
     */
    function claim(uint16 tranche) external payable returns (uint256 tokenId) {
        tokenId = _claim(tranche, address(0), 0);
    }

    /**
     * @dev See {IExchangeBillManager-exchange}.
     */
    function exchange(uint256 tokenId) external payable override onlyForAuthorized(tokenId) {
        BillNote storage note = _bills[tokenId];
        Promissory storage promissory = _promissories[tokenId];

        if (note.remitent == address(0) || promissory.tranche == 0) {
            revert InvalidTokenID();
        }

        uint256 _lockDeadline = promissory.issuance + (note.lockingPeriod * 24 * 60 * 60);
        if (_lockDeadline > block.timestamp) {
            revert PayoutNotActive();
        }

        // uint256 _payoutDeadline = promissory.issuance + (note.payoutPeriod * 24 * 60 * 60);
        // if (block.timestamp > _payoutDeadline) {
        //     revert PayoutDeadlineMissed(_payoutDeadline);
        // }

        // IERC20 _currency = (note.currency != address(0)) ? IERC20(note.currency) : currency;
        uint256 _payoutAmount = note.amount;
        uint256 _periods = Dates.diffMonths(_lockDeadline, block.timestamp);

        for (uint256 i = 0; i < _periods; i++) {
            uint256 interest = (_payoutAmount * (note.interests / 100));
            _payoutAmount += interest;
        }

        address owner = ownerOf(tokenId);

        currency.safeTransferFrom(address(currency), address(this), _payoutAmount);
        currency.safeTransfer(owner, _payoutAmount);

        promissory.exchange = block.timestamp;
        _safeTransfer(owner, address(this), tokenId);

        emit BillTokenWithdrawn(tokenId, owner, _payoutAmount);
    }

    /**
     * @dev See {IExchangeBillManager-burn}.
     */
    function burn(uint256 tokenId) public payable override onlyForAuthorized(tokenId) {
        _burnNote(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721Upgradeable, IERC721Metadata) returns (string memory) {
        _requireOwned(tokenId);

        return IExchangeBillTokenDescriptor(_tokenDescriptor).tokenURI(this, tokenId);
    }

    function getCurrentNonce(uint256 tokenId) internal virtual override returns (uint256) {
        unchecked {
            return _promissories[tokenId].nonce++;
        }
    }

    // ************************************* 
    // Modifiers
    // *************************************

    modifier onlyForAuthorized(uint256 tokenId) {
        address _sender = _msgSender();
        if (!_isAuthorized(_ownerOf(tokenId), _sender, tokenId)) {
             revert TokenNotApproved(_sender, tokenId);
        }
        _;
    }

    // ************************************* 
    // Utility methods
    // *************************************

    function _burnNote(uint256 tokenId) internal virtual {
        BillNote storage note = _bills[tokenId];
        Promissory storage promissory = _promissories[tokenId];

        if (note.remitent == address(0) || promissory.tranche == 0) {
            revert InvalidTokenID();
        }

        delete _bills[tokenId];
        delete _promissories[tokenId];

        _burn(tokenId);

        emit BillTokenBurned(tokenId);
    }

    function _claim(uint16 tranche, address remitent, uint256 timestamp) internal virtual returns (uint256 tokenId) {
        address _remitent = (remitent == address(0) ? _msgSender() : remitent); 
        DraftedNote storage _draft = _drafts[_remitent][tranche];

        if (_draft.note.amount == 0 || _remitent != _draft.note.remitent) {
            revert InvalidRemitent(_remitent);
        }

        uint256 _deadline = _draft.timestamp + (_draft.note.lockingPeriod * 24 * 60 * 60);
        if (_deadline < block.timestamp) {
            revert ClaimDeadlineMissed(_deadline);
        }

        tokenId = _useNextTokenId();
        _safeMint(_draft.note.remitent, tokenId);

        _bills[tokenId] = _draft.note;

        uint256 _timestamp = ((timestamp >= BASE_TIMESTAMP) ? timestamp : block.timestamp);
        _promissories[tokenId] = Promissory(tranche, 0, _draft.note.remitent, _timestamp, 0, _draft.series);

        delete _drafts[_draft.note.remitent][tranche];

        emit BillTokenIssued(tokenId, _draft.note.remitent, _draft.note.amount);
    }

    /**
     * @dev Consumes a next token ID.
     *
     * Returns the current value and increments token ids.
     */
    function _useNextTokenId() internal virtual returns (uint256) {
        unchecked {
            return _nextTokenId++;
        }
    }

    /**
     * @dev Consumes a next tranche seqence number.
     *
     * Returns the current value and increments tranche.
     */
    function _useNextTranche() internal virtual returns (uint16) {
        unchecked {
            return _nextTranche++;
        }
    }

    // The following functions are overrides required by Solidity.

    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256 tokenId, bytes memory) public virtual override returns (bytes4) {
        _burnNote(tokenId);

        return this.onERC721Received.selector;
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view override(ERC721Upgradeable, IERC721) returns (address) {
        _requireOwned(tokenId);

        return _promissories[tokenId].operator;
    }

    function _approve(address to, uint256 tokenId, address, bool) internal override(ERC721Upgradeable) {
        _promissories[tokenId].operator = to;

        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC721Upgradeable, ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

}
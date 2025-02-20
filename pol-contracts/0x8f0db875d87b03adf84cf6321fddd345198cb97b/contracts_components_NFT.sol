// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

// NFT
import { ERC721WithERC2981 } from "./contracts_ERC721C_extentions_ERC721WithERC2981.sol";
import { ERC721Upgradeable } from "./openzeppelin_contracts-upgradeable_token_ERC721_ERC721Upgradeable.sol";
import { ERC721BurnableUpgradeable } from "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_ERC721BurnableUpgradeable.sol";

// interfaces
import { IERC4906 } from "./openzeppelin_contracts_interfaces_IERC4906.sol";
import { IERC165 } from "./openzeppelin_contracts_interfaces_IERC165.sol";
import { IERC721 } from "./openzeppelin_contracts_token_ERC721_IERC721.sol";

// Access
import { AccessControlUpgradeable } from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import { OwnableUpgradeable } from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";

// Components
import { ECDSASignature } from "./contracts_components_ECDSASignature.sol";

abstract contract NFT is
	OwnableUpgradeable,
	AccessControlUpgradeable,
	ERC721WithERC2981,
	ERC721BurnableUpgradeable,
	ECDSASignature,
	IERC4906
{
	// =============================================================
	//                           ERROR
	// =============================================================

	error AmountExceeded();
	error NonExecutable(address sender);
	error MaxIdentifierRevealAmountExceeded();
	error InvalidLength();
	error NotOwner(uint256 tokenId, address signer);
	error AlreadyCustomInitialized();

	// =============================================================
	//                           EVENT
	// =============================================================

	event MaxRevealAmountUpdated(string identifier, uint256 indexed maxAmount);

	// =============================================================
	//                           STRUCT
	// =============================================================

	struct IdentifiersAmount {
		uint256 maxRevealAmount;
		uint256 currentSupply;
	}

	struct RevealType {
		string headRevealType;
		string bodyRevealType;
	}

	// =============================================================
	//                           STORAGE
	// =============================================================

	uint256 public maxSupply;
	uint256 internal _nextTokenId;
	bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
	bytes32 public constant INITIALIZER_ROLE = keccak256("INITIALIZER_ROLE");
	string public baseURI;
	address public saleContractAddress;
	uint256 public currentSupply;
	bool private _customInitialized;

	// identifier => IdentifiersAmount
	mapping(string => IdentifiersAmount) public identifiersAmounts;

	// tokenId => RevealType
	mapping(uint256 => RevealType) public revealTypes;

	// =============================================================
	//                          MODIFIERS
	// =============================================================

	/// @notice Custom initialize
	modifier checkCustomInitialized() {
		if (_customInitialized) revert AlreadyCustomInitialized();
		_customInitialized = true;
		_;
	}

	/// @notice Only operator or sale contract can execute
	modifier saleContractOrOperator() {
		if (
			!hasRole(OPERATOR_ROLE, msg.sender) &&
			msg.sender != saleContractAddress
		) revert NonExecutable(msg.sender);
		_;
	}

	// =============================================================
	//                          INITIALIZER
	// =============================================================

	function __NFT_init(
		string memory _name,
		string memory _symbol,
		string memory _baseURI,
		address _admin,
		address _owner,
		address _initializer,
		address[] memory _operators,
		address _royaltyReceiver,
		uint96 _royaltyFee,
		address _defaultTransferValidator
	) internal initializer {
		__Ownable_init(_owner);
		__AccessControl_init();
		__ERC721WithERC2981_init(
			_name,
			_symbol,
			_admin,
			_royaltyReceiver,
			_royaltyFee,
			_defaultTransferValidator
		);
		_grantRole(DEFAULT_ADMIN_ROLE, _admin);
		for (uint256 i = 0; i < _operators.length; i++) {
			_grantRole(OPERATOR_ROLE, _operators[i]);
		}
		_grantRole(INITIALIZER_ROLE, _initializer);
		baseURI = _baseURI;
	}

	// =============================================================
	//                          EXTERNAL WRITE
	// =============================================================

	/// @notice Burns multiple tokens
	/// @dev only operator can burn
	///      max 100 tokens can be burned at a time
	/// @param tokenIds The token IDs to burn
	function bulkBurn(
		uint256[] calldata tokenIds
	) external onlyRole(OPERATOR_ROLE) {
		for (uint256 i = 0; i < tokenIds.length; i++) {
			burn(tokenIds[i]);
		}
	}

	/// @notice Set the sale contract address
	/// @dev only operator can set
	/// @param _saleContractAddress The address of the sale contract
	function setSaleContractAddress(
		address _saleContractAddress
	) external onlyRole(OPERATOR_ROLE) {
		saleContractAddress = _saleContractAddress;
	}

	/// @notice Set the reveal type of a token
	/// @dev only operator can set
	/// @param tokenId The token ID
	/// @param _revealType The reveal type
	function setRevealType(
		uint256 tokenId,
		RevealType calldata _revealType
	) external onlyRole(OPERATOR_ROLE) {
		revealTypes[tokenId] = _revealType;
	}

	// =============================================================
	//                          INTERNAL VIEW
	// =============================================================

	function _checkMaxSupply(uint256 amount) internal view {
		if (currentSupply + amount > maxSupply) revert AmountExceeded();
	}

	// =============================================================
	//                          ERC721
	// =============================================================

	/// @notice Check if the contract supports the interface
	/// @param interfaceId The interface ID
	function supportsInterface(
		bytes4 interfaceId
	)
		public
		view
		virtual
		override(
			ERC721WithERC2981,
			ERC721Upgradeable,
			AccessControlUpgradeable,
			IERC165
		)
		returns (bool)
	{
		return super.supportsInterface(interfaceId);
	}

	function _update(
		address to,
		uint256 tokenId,
		address auth
	)
		internal
		override(ERC721Upgradeable, ERC721WithERC2981)
		returns (address)
	{
		address from = super._update(to, tokenId, auth);
		if (from == address(0)) currentSupply++;
		if (to == address(0)) currentSupply--;
		return from;
	}

	function transferFrom(
		address from,
		address to,
		uint256 tokenId
	) public virtual override(ERC721Upgradeable, IERC721) {
		super.transferFrom(from, to, tokenId);
	}

	function safeTransferFrom(
		address from,
		address to,
		uint256 tokenId,
		bytes memory data
	) public virtual override(ERC721Upgradeable, IERC721) {
		super.safeTransferFrom(from, to, tokenId, data);
	}

	// =============================================================
	//                          ERC2981
	// =============================================================

	/// @dev only DEFAULT_ADMIN_ROLE can set default royalty
	function setDefaultRoyalty(
		address receiver,
		uint96 feeNumerator
	) external override onlyRole(DEFAULT_ADMIN_ROLE) {
		_setDefaultRoyalty(receiver, feeNumerator);
	}

	/// @notice Set the base URI
	/// @dev only operator can set
	/// @param _baseURI The base URI
	function setBaseURI(
		string memory _baseURI
	) external onlyRole(OPERATOR_ROLE) {
		baseURI = _baseURI;
	}

	// =============================================================
	//                          IDENTIFIER
	// =============================================================

	function bulkSetIdentifier(
		string[] memory _identifiers,
		uint256[] memory _identifierAmounts
	) external virtual onlyRole(OPERATOR_ROLE) {}

	function _setIdentifier(
		string memory _identifier,
		uint256 _identifierAmount
	) internal virtual {
		// get the identifier amount
		IdentifiersAmount storage idAmount = identifiersAmounts[_identifier];

		// check if the identifier amount is exceeded
		if (idAmount.currentSupply >= _identifierAmount)
			revert MaxIdentifierRevealAmountExceeded();

		// update the max supply
		maxSupply -= idAmount.maxRevealAmount;
		maxSupply += _identifierAmount;

		// update the identifier amount
		idAmount.maxRevealAmount = _identifierAmount;
		idAmount.currentSupply = idAmount.currentSupply;

		// emit the event
		emit MaxRevealAmountUpdated(_identifier, _identifierAmount);
	}
}
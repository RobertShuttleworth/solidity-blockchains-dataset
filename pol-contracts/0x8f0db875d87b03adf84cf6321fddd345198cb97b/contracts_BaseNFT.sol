// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { NFT } from "./contracts_components_NFT.sol";

// Components
import { ECDSA } from "./solady_utils_ECDSA.sol";
import { LibString } from "./solady_utils_LibString.sol";
// Interfaces
import { IBaseNFTTBA } from "./contracts_ERC6551_interfaces_IBaseNFTTBA.sol";
import { IPartsNFT } from "./contracts_interfaces_IPartsNFT.sol";
import { IBaseNFT } from "./contracts_interfaces_IBaseNFT.sol";
import "./forge-std_console.sol";

contract BaseNFT is NFT, IBaseNFT {
	using ECDSA for bytes32;

	// =============================================================
	//                           STORAGE
	// =============================================================

	address public tbaContract;
	address public erc6551AccountContract;
	address public partsNFTContract;

	// tokenId => character identifier
	mapping(uint256 => string) public characterIdentifiers;

	// tokenId => bool
	mapping(uint256 => bool) public isRevealed;

	// tokenId => bool
	mapping(uint256 => bool) public isLock;

	// =============================================================
	//                          MODIFIERS
	// =============================================================

	/// @notice Check if the token is locked
	/// @param tokenId The token ID
	modifier checkLock(uint256 tokenId) {
		if (isLock[tokenId] && !hasRole(OPERATOR_ROLE, _msgSender())) {
			revert Locked(tokenId);
		}
		_;
	}

	// =============================================================
	//                          CONSTRUCTOR
	// =============================================================

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	// =============================================================
	//                          INITIALIZER
	// =============================================================

	/// @notice Initialize the contract
	/// @param _name The name of the contract
	/// @param _symbol The symbol of the contract
	/// @param _baseURI The base URI of the contract
	/// @param _tbaContract The TBA contract
	/// @param _erc6551Account The ERC6551 account contract logic
	/// @param _admin The admin address
	/// @param _owner The owner address
	/// @param _initializer The initializer address
	/// @param _operators The operators address
	/// @param _royaltyReceiver The royalty receiver
	/// @param _royaltyFee The royalty fee
	/// @param _defaultTransferValidator The default transfer validator
	function initialize(
		string memory _name,
		string memory _symbol,
		string memory _baseURI,
		address _tbaContract,
		address _erc6551Account,
		address _admin,
		address _owner,
		address _initializer,
		address[] memory _operators,
		address _royaltyReceiver,
		uint96 _royaltyFee,
		address _defaultTransferValidator
	) public virtual initializer {
		__NFT_init(
			_name,
			_symbol,
			_baseURI,
			_admin,
			_owner,
			_initializer,
			_operators,
			_royaltyReceiver,
			_royaltyFee,
			_defaultTransferValidator
		);
		tbaContract = _tbaContract;
		erc6551AccountContract = _erc6551Account;
	}

	/// @notice Custom initialize
	/// @param _partsNFTContract The parts NFT contract
	/// @param _saleContractAddress The sale contract address
	function customInitialize(
		address _partsNFTContract,
		address _saleContractAddress
	) external onlyRole(INITIALIZER_ROLE) checkCustomInitialized {
		partsNFTContract = _partsNFTContract;
		saleContractAddress = _saleContractAddress;
		emit CustomInitialized(_partsNFTContract, _saleContractAddress);
	}

	// =============================================================
	//                         EXTERNAL WRITE
	// =============================================================

	/// @notice Mint a bundle
	/// @param to The recipient
	/// @param headRevealType The reveal type of the head
	/// @param bodyRevealType The reveal type of the body
	/// @return tokenId The token ID
	/// @return partsTokenIds The parts token IDs
	function bundleMint(
		address to,
		string memory headRevealType,
		string memory bodyRevealType
	)
		public
		override
		saleContractOrOperator
		returns (uint256, uint256[] memory)
	{
		// check if the max supply is exceeded
		_checkMaxSupply(1);

		uint256 tokenId = ++_nextTokenId;
		_safeMint(to, tokenId);

		revealTypes[tokenId] = RevealType({
			headRevealType: headRevealType,
			bodyRevealType: bodyRevealType
		});

		// Create TBA account
		address tbaAccount = IBaseNFTTBA(tbaContract).createAccount(
			erc6551AccountContract,
			bytes32(tokenId),
			block.chainid,
			address(this),
			tokenId
		);

		// set the reveal types
		RevealType[2] memory _revealTypes;
		_revealTypes[0] = RevealType({
			headRevealType: headRevealType,
			bodyRevealType: bodyRevealType
		});
		_revealTypes[1] = RevealType({
			headRevealType: headRevealType,
			bodyRevealType: bodyRevealType
		});
		// Mint 3 parts NFT to the TBA account
		uint256[] memory partsTokenIds = IPartsNFT(partsNFTContract).bundleMint(
			tbaAccount,
			tokenId,
			_revealTypes
		);
		return (tokenId, partsTokenIds);
	}

	/// @notice Mint a bundle
	/// @param tos The recipients
	/// @param headRevealTypes The reveal types of the heads
	/// @param bodyRevealTypes The reveal types of the bodies
	function bulkBundleMint(
		address[] calldata tos,
		string[] calldata headRevealTypes,
		string[] calldata bodyRevealTypes
	) external override onlyRole(OPERATOR_ROLE) {
		// check if the length of the reveal types is valid
		if (
			headRevealTypes.length != tos.length ||
			bodyRevealTypes.length != tos.length
		) {
			revert InvalidLength();
		}
		for (uint256 i = 0; i < tos.length; i++) {
			bundleMint(tos[i], headRevealTypes[i], bodyRevealTypes[i]);
		}
	}

	/// @notice Reveal a bundle
	/// @param characterTokenId The character token ID
	/// @param characterIdentifier The character identifier
	/// @param partsTokenIds The parts token IDs
	/// @param partsIdentifiers The parts identifiers
	function reveal(
		uint256 characterTokenId,
		string calldata characterIdentifier,
		uint256[] calldata partsTokenIds,
		string[] calldata partsIdentifiers,
		bytes32 hash,
		bytes calldata signature
	) public override onlyRole(OPERATOR_ROLE) {
		// check if the identifier amount is exceeded
		checkIdentifierAmount(characterIdentifier);
		// check if the identifier length is valid
		checkIdentifierLength(characterIdentifier);
		// Verify the signature
		(address signer, bool isValid) = verifySignature(
			address(this),
			characterTokenId,
			hash,
			signature
		);
		// check if the signer is the owner of the nft
		if (!isValid) revert NotOwner(characterTokenId, signer);

		// reveal the nft
		_reveal(
			characterTokenId,
			characterIdentifier,
			partsTokenIds,
			partsIdentifiers
		);
	}

	/// @notice Bulk reveal mint bundles
	/// @param tos The recipients
	/// @param _characterIdentifiers The character identifiers
	/// @param _partsIdentifiers The parts identifiers
	function bulkBundleMintReveal(
		address[] calldata tos,
		string[] calldata _characterIdentifiers,
		string[][] calldata _partsIdentifiers
	) external override onlyRole(OPERATOR_ROLE) {
		for (uint256 i = 0; i < tos.length; i++) {
			// check if the identifier length is valid
			checkIdentifierLength(_characterIdentifiers[i]);
			// mint the nft
			(uint256 tokenId, uint256[] memory partsTokenIds) = bundleMint(
				tos[i],
				"",
				""
			);
			// update the identifier amount
			identifiersAmounts[_characterIdentifiers[i]].maxRevealAmount++;

			// reveal the nft
			_reveal(
				tokenId,
				_characterIdentifiers[i],
				partsTokenIds,
				_partsIdentifiers[i]
			);
		}
	}

	/// @notice Toggle the lock status
	/// @param tokenId The token ID
	/// @param hash The hash of the token ID
	/// @param signature The signature of the token ID
	function toggleLock(
		uint256 tokenId,
		bytes32 hash,
		bytes calldata signature
	) public override onlyRole(OPERATOR_ROLE) {
		// verify the signature
		bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(hash);
		address signer = ECDSA.recover(ethSignedMessageHash, signature);
		// check if the signer is the owner of the nft
		if (ownerOf(tokenId) != signer) {
			revert NotOwner(tokenId, signer);
		}

		// toggle the lock status
		isLock[tokenId] = !isLock[tokenId];

		emit Lock(tokenId, isLock[tokenId]);
	}

	/// @notice Set the parts NFT contract
	/// @param _partsNFTContract The parts NFT contract
	function setPartsNFTContract(
		address _partsNFTContract
	) external override onlyRole(OPERATOR_ROLE) {
		partsNFTContract = _partsNFTContract;
	}

	/// @notice Emit the metadata update event
	/// @param tokenId The token ID
	function emitMetadataUpdate(uint256 tokenId) external override {
		if (msg.sender != partsNFTContract) {
			revert OnlyPartsNFT();
		}
		emit MetadataUpdate(tokenId);
	}

	/// @notice Approve the operator
	/// @param signature The signature
	/// @param messageHash The message hash
	/// @param tokenId The token ID
	/// @param operator The operator
	function operatorApprove(
		bytes calldata signature,
		bytes32 messageHash,
		uint256 tokenId,
		address operator
	) external override onlyRole(OPERATOR_ROLE) {
		if (!hasRole(OPERATOR_ROLE, operator)) {
			revert AccessControlUnauthorizedAccount(operator, OPERATOR_ROLE);
		}
		bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
		address signer = ECDSA.recover(ethSignedMessageHash, signature);
		if (ownerOf(tokenId) != signer) {
			revert NotOwner(tokenId, signer);
		}
		_approve(operator, tokenId, address(0), false);
	}

	// =============================================================
	//                          INTERNAL WRITE
	// =============================================================

	/// @notice Reveal a bundle
	/// @param characterTokenId The character token ID
	/// @param characterIdentifier The character identifier
	/// @param partsTokenIds The parts token IDs
	/// @param partsIdentifiers The parts identifiers
	function _reveal(
		uint256 characterTokenId,
		string calldata characterIdentifier,
		uint256[] memory partsTokenIds,
		string[] calldata partsIdentifiers
	) internal {
		// Set the revealed status
		isRevealed[characterTokenId] = true;
		// set the lock status
		isLock[characterTokenId] = true;
		// set the identifier
		characterIdentifiers[characterTokenId] = characterIdentifier;
		// update the identifier amount
		identifiersAmounts[characterIdentifier].currentSupply++;

		// Reveal the parts
		IPartsNFT(partsNFTContract).bundleReveal(
			characterTokenId,
			partsTokenIds,
			partsIdentifiers
		);

		emit BaseReveal(
			characterTokenId,
			characterIdentifier,
			partsTokenIds,
			partsIdentifiers
		);
	}

	// =============================================================
	//                          EXTERNAL VIEW
	// =============================================================

	/// @notice Get the token URI
	/// @param tokenId The token ID
	/// @return The token URI
	function tokenURI(
		uint256 tokenId
	) public view override returns (string memory) {
		return
			string.concat(
				baseURI,
				"token_id=",
				LibString.toString(tokenId),
				"&identifier=",
				characterIdentifiers[tokenId]
			);
	}

	/// @param interfaceId The interface ID
	function supportsInterface(
		bytes4 interfaceId
	) public view override(IBaseNFT, NFT) returns (bool) {
		return super.supportsInterface(interfaceId);
	}

	// =============================================================
	//                          INTERNAL VIEW
	// =============================================================

	/// @notice Check if the character identifier length is valid
	/// @param characterIdentifier The character identifier
	function checkIdentifierLength(
		string calldata characterIdentifier
	) internal pure {
		// Character identifier always 2-digit.
		if (bytes(characterIdentifier).length != 2) revert InvalidLength();
	}

	/// @notice Check if the identifier is valid
	/// @param identifier The identifier to check
	function checkIdentifierAmount(string calldata identifier) internal view {
		IdentifiersAmount storage idAmount = identifiersAmounts[identifier];
		if (idAmount.currentSupply + 1 > idAmount.maxRevealAmount) {
			revert MaxIdentifierRevealAmountExceeded();
		}
	}

	// =================================================================
	//                          IDENTIFIER
	// =============================================================

	/// @notice Set the identifier for a given parts identifier
	/// @param _identifiers The identifiers to set
	/// @param _identifierAmounts The identifier amounts to set
	function bulkSetIdentifier(
		string[] memory _identifiers,
		uint256[] memory _identifierAmounts
	) public override onlyRole(OPERATOR_ROLE) {
		if (_identifiers.length != _identifierAmounts.length)
			revert InvalidLength();
		for (uint256 i = 0; i < _identifiers.length; i++) {
			_setIdentifier(_identifiers[i], _identifierAmounts[i]);
		}
	}

	// =============================================================
	//                          ERC721
	// =============================================================

	/// @dev check if the token is locked
	function safeTransferFrom(
		address from,
		address to,
		uint256 tokenId,
		bytes memory data
	) public override checkLock(tokenId) {
		super.safeTransferFrom(from, to, tokenId, data);
	}

	/// @dev check if the token is locked
	function transferFrom(
		address from,
		address to,
		uint256 tokenId
	) public override checkLock(tokenId) {
		super.transferFrom(from, to, tokenId);
	}
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IBaseNFT {
	// =============================================================
	//                          EVENT
	// =============================================================

	event CustomInitialized(
		address indexed partsNFTContract,
		address indexed saleContractAddress
	);

	event BaseReveal(
		uint256 indexed tokenId,
		string characterIdentifier,
		uint256[] partsTokenIds,
		string[] partsIdentifiers
	);

	event Lock(uint256 tokenId, bool locked);

	// =============================================================
	//                          ERROR
	// =============================================================

	error Locked(uint256 tokenId);

	error OnlyPartsNFT();

	// =============================================================
	//                          EXTERNAL WRITE
	// =============================================================

	/// @notice Mints a new token to the specified address
	/// @param to The address to mint the token to
	/// @param headRevealType The reveal type of the head
	/// @param bodyRevealType The reveal type of the body
	function bundleMint(
		address to,
		string calldata headRevealType,
		string calldata bodyRevealType
	) external returns (uint256, uint256[] memory);

	/// @notice Mints multiple tokens to the specified addresses
	/// @param tos The addresses to mint the tokens to
	/// @param headRevealTypes The reveal types of the heads
	/// @param bodyRevealTypes The reveal types of the bodies
	function bulkBundleMint(
		address[] calldata tos,
		string[] calldata headRevealTypes,
		string[] calldata bodyRevealTypes
	) external;

	/// @notice Sets the PartsNFT contract address
	/// @param _partsNFTContract The address of the PartsNFT contract
	function setPartsNFTContract(address _partsNFTContract) external;

	/// @notice Reveals the character and parts for a given token ID
	/// @param characterTokenId The token ID of the character
	/// @param characterIdentifier The character identifier
	/// @param partsTokenIds The token IDs of the parts
	/// @param partsIdentifiers The identifiers of the parts
	/// @param hash The hash of the character and parts
	/// @param signature The signature of the hash
	function reveal(
		uint256 characterTokenId,
		string calldata characterIdentifier,
		uint256[] calldata partsTokenIds,
		string[] calldata partsIdentifiers,
		bytes32 hash,
		bytes calldata signature
	) external;

	/// @notice Bulk reveal mint bundles
	/// @param tos The recipients
	/// @param _characterIdentifiers The character identifiers
	/// @param _partsIdentifiers The parts identifiers
	function bulkBundleMintReveal(
		address[] calldata tos,
		string[] calldata _characterIdentifiers,
		string[][] calldata _partsIdentifiers
	) external;

	function toggleLock(
		uint256 tokenId,
		bytes32 hash,
		bytes calldata signature
	) external;

	/// @notice Emits the metadata update event
	/// @param tokenId The token ID
	function emitMetadataUpdate(uint256 tokenId) external;

	function operatorApprove(
		bytes calldata signature,
		bytes32 messageHash,
		uint256 tokenId,
		address operator
	) external;

	// =============================================================
	//                          EXTERNAL VIEW
	// =============================================================

	/// @notice Returns the character identifier for a given token ID
	/// @param tokenId The token ID to query
	/// @return The character identifier
	function characterIdentifiers(
		uint256 tokenId
	) external view returns (string memory);

	/// @notice Returns the reveal status for a given token ID
	/// @param tokenId The token ID to query
	/// @return The reveal status
	function isRevealed(uint256 tokenId) external view returns (bool);

	/// @notice Checks if the contract supports a given interface
	/// @param interfaceId The interface ID to check
	/// @return True if the interface is supported, false otherwise
	function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { NFT } from "./contracts_components_NFT.sol";

interface IPartsNFT {
	// =============================================================
	//                           EVENT
	// ============================================================

	event CustomInitialized(
		address indexed saleContractAddress
	);

	event PartsReveal(uint256 indexed tokenId, string partsIdentifier);

	event SetParts(uint256 indexed tokenId, uint256 indexed baseNftTokenId);

	event ChangeParts(
		uint256 indexed setTokenId,
		uint256 indexed removeTokenId,
		string setPartsIdentifier,
		string removePartsIdentifier
	);

	// =============================================================
	//                           ERROR
	// =============================================================

	error InvalidIdentifier();

	error NotRevealed(uint256 tokenId);

	error BaseNFTLocked();

	error NotTBAAccount(address tbaAddress);

	error NotTransfer(address from, address to, uint256 tokenId);

	error InvalidSignature();

	// =============================================================
	//                         EXTERNAL WRITE
	// =============================================================

	/// @notice Mints a token and reveals it
	/// @param tos The address to mint the token to
	/// @param _partsIdentifiers The parts identifiers
	/// @param revealTypes The reveal types
	function mintReveal(
		address[] memory tos,
		string[] calldata _partsIdentifiers,
		NFT.RevealType[] memory revealTypes
	) external returns (uint256[] memory tokenIds);

	/// @notice Mints a token bundle
	/// @param to The address to mint the token to
	/// @param baseNftTokenId The token ID of the base NFT
	function bundleMint(
		address to,
		uint256 baseNftTokenId,
		NFT.RevealType[2] memory _revealTypes
	) external returns (uint256[] memory tokenIds);

	/// @notice Reveals the parts for a given token ID
	/// @param baseNftTokenId The token ID of the base NFT
	/// @param tokenIds The token IDs of the parts
	/// @param partsIdentifiers The identifiers of the parts
	function bundleReveal(
		uint256 baseNftTokenId,
		uint256[] calldata tokenIds,
		string[] calldata partsIdentifiers
	) external;

	/// @notice Changes the parts for a given token ID
	/// @param tbaAddress The address of the TBA account
	/// @param eoaAddress The address of the EOA account
	/// @param addTokenId The token ID to add
	/// @param removeTokenId The token ID to remove
	/// @param hash The hash of the parts
	/// @param signature The signature of the parts
	/// @param adminHash The hash of the admin
	/// @param adminSignature The signature of the admin
	function changeParts(
		address tbaAddress,
		address eoaAddress,
		uint256 addTokenId,
		uint256 removeTokenId,
		bytes32 hash,
		bytes calldata signature,
		bytes32 adminHash,
		bytes calldata adminSignature
	) external;

	/// @notice Reveals the parts for a given token ID
	/// @param tokenId The token ID of the parts
	/// @param partsIdentifier The identifier of the parts
	function reveal(uint256 tokenId, string calldata partsIdentifier) external;

	/// @notice Transfers a token from a TBA account
	/// @param from The address of the sender
	/// @param to The address of the recipient
	/// @param tokenId The token ID to transfer
	function tbaTransferFrom(
		address from,
		address to,
		uint256 tokenId
	) external;

	// =============================================================
	//                         EXTERNAL VIEW
	// =============================================================

	/// @notice Returns the address of the base NFT contract
	function baseNFTContract() external view returns (address);

	/// @notice Returns if the parts are revealed for a given token ID
	function isRevealed(uint256 tokenId) external view returns (bool);

	/// @notice Returns if the interface is supported
	function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
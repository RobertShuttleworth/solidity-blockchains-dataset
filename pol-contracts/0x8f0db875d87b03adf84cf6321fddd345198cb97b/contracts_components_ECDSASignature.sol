// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ECDSA } from "./solady_utils_ECDSA.sol";
import { IERC721 } from "./openzeppelin_contracts_token_ERC721_IERC721.sol";

contract ECDSASignature {
	// =============================================================
	//                           CONSTANTS
	// =============================================================

	using ECDSA for bytes32;

	/// @notice Verify the signature of a given hash
	/// @param nftContract The address of the NFT contract
	/// @param tokenId The token ID of the NFT
	/// @param hash The hash to verify
	/// @param signature The signature to verify
	/// @return The address of the signer and a boolean indicating if the signer is the owner of the NFT
	function verifySignature(
		address nftContract,
		uint256 tokenId,
		bytes32 hash,
		bytes calldata signature
	) internal view returns (address, bool) {
		// get the signer
		bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(hash);
		address signer = ECDSA.recover(ethSignedMessageHash, signature);

		// check if the signer is the owner of the NFT
		return (signer, IERC721(nftContract).ownerOf(tokenId) == signer);
	}
}
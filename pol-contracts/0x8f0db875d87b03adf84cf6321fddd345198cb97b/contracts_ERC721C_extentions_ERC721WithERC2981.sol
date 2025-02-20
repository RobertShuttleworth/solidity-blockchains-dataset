// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ERC2981Upgradeable } from "./openzeppelin_contracts-upgradeable_token_common_ERC2981Upgradeable.sol";
import { ERC721C } from "./contracts_ERC721C_ERC721C.sol";

contract ERC721WithERC2981 is ERC2981Upgradeable, ERC721C {
	function __ERC721WithERC2981_init(
		string memory name_,
		string memory symbol_,
		address admin,
		address royaltyReceiver,
		uint96 royaltyFraction,
		address defaultTransferValidator
	) internal initializer {
		__ERC721C_init(name_, symbol_, admin, defaultTransferValidator);
		__ERC2981_init();
		_setDefaultRoyalty(royaltyReceiver, royaltyFraction);
	}

	// =============================================================
	//                         EXTERNAL WRITE
	// =============================================================

	/// @notice Sets the default royalty receiver and fee numerator
	/// @param receiver The address of the royalty receiver
	/// @param feeNumerator The numerator of the royalty fee
	function setDefaultRoyalty(
		address receiver,
		uint96 feeNumerator
	) external virtual {
		_setDefaultRoyalty(receiver, feeNumerator);
	}

	/// @notice Sets the royalty receiver and fee numerator for a given token ID
	function setTokenRoyalty(
		uint256, // tokenId
		address, // receiver
		uint96 // feeNumerator
	) external virtual {
		// revert if the function is disabled
		revert("!DISABLED");
	}

	// =============================================================
	//                         INTERNAL VIEW
	// =============================================================

	function _update(
		address to,
		uint256 tokenId,
		address auth
	) internal virtual override returns (address) {
		address from = super._update(to, tokenId, auth);
		return from;
	}

	// =============================================================
	//                         EXTERNAL VIEW
	// =============================================================

	/// @notice Overrides the supportsInterface function to include the ERC2981 interface
	/// @param interfaceId The interface ID to check
	/// @return True if the interface is supported, false otherwise
	function supportsInterface(
		bytes4 interfaceId
	) public view virtual override(ERC721C, ERC2981Upgradeable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
}
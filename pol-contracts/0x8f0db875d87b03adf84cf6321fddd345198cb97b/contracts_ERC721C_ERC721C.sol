// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { CreatorTokenBaseUpgradeable } from "./contracts_ERC721C_utils_CreatorTokenBaseUpgradeable.sol";
import { ERC721Upgradeable } from "./openzeppelin_contracts-upgradeable_token_ERC721_ERC721Upgradeable.sol";
import { AccessControlUpgradeable } from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";

// interfaces
import { ICreatorToken } from "./contracts_ERC721C_interfaces_ICreatorToken.sol";

abstract contract ERC721C is ERC721Upgradeable, CreatorTokenBaseUpgradeable {
	function __ERC721C_init(
		string memory name_,
		string memory symbol_,
		address admin,
		address defaultTransferValidator
	) internal initializer {
		__ERC721_init(name_, symbol_);
		__CreatorTokenBaseUpgradeable_init(admin, defaultTransferValidator);
	}

	function supportsInterface(
		bytes4 interfaceId
	)
		public
		view
		virtual
		override(ERC721Upgradeable, AccessControlUpgradeable)
		returns (bool)
	{
		return
			interfaceId == type(ICreatorToken).interfaceId ||
			super.supportsInterface(interfaceId);
	}

	function _update(
		address to,
		uint256 tokenId,
		address auth
	) internal virtual override returns (address) {
		_validateBeforeTransfer(msg.sender, to, tokenId);
		return super._update(to, tokenId, auth);
	}
}
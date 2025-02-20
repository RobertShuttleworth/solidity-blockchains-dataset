//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./solvprotocol_contracts-v3-sft-core_contracts_BaseSFTConcreteUpgradeable.sol";
import "./solvprotocol_contracts-v3-sft-abilities_contracts_issuable_ISFTIssuableDelegate.sol";
import "./solvprotocol_contracts-v3-sft-abilities_contracts_issuable_ISFTIssuableConcrete.sol";

abstract contract SFTIssuableConcrete is ISFTIssuableConcrete, BaseSFTConcreteUpgradeable {

	function __SFTIssuableConcrete_init() internal onlyInitializing {
		__BaseSFTConcrete_init();
	}

	function __SFTIssuableConcrete_init_unchained() internal onlyInitializing {
	}

    function createSlotOnlyDelegate(address txSender_, bytes calldata inputSlotInfo_) external virtual override onlyDelegate returns (uint256 slot_)  {
		slot_  = _createSlot(txSender_, inputSlotInfo_);
		require(slot_ != 0, "SFTIssuableConcrete: invalid slot");
	}

    function mintOnlyDelegate(address txSender_, address currency_, address mintTo_, uint256 slot_, uint256 tokenId_, uint256 amount_) 
		external virtual override onlyDelegate {
		_mint(txSender_, currency_, mintTo_, slot_, tokenId_, amount_);
	}

	function _createSlot(address txSender_, bytes memory inputSlotInfo_) internal virtual returns (uint256 slot_);
	function _mint(address txSender_, address currency_, address mintTo_, uint256 slot_, uint256 tokenId_, uint256 amount_) internal virtual;

	uint256[50] private __gap;
}
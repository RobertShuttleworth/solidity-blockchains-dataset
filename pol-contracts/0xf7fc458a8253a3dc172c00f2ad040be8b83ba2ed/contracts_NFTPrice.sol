// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

// access
import { AccessControlUpgradeable } from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";

// interfaces
import { INFTPrice } from "./contracts_interfaces_INFTPrice.sol";

// upgradeable
import { Initializable } from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import { UUPSUpgradeable } from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";

contract NFTPrice is
	INFTPrice,
	Initializable,
	AccessControlUpgradeable,
	UUPSUpgradeable
{
	// =============================================================
	//                           STORAGE
	// =============================================================

	uint256 public basePrice;

	bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
	bytes32 public constant UPGRADEABLE_ROLE = keccak256("UPGRADEABLE_ROLE");

	// =============================================================
	//                           INITIALIZER
	// =============================================================

	function initialize(
		address _admin,
		address[] memory _operators,
		address _upgradeable,
		uint256 _basePrice
	) public initializer {
		_grantRole(DEFAULT_ADMIN_ROLE, _admin);
		for (uint256 i = 0; i < _operators.length; i++) {
			_grantRole(OPERATOR_ROLE, _operators[i]);
		}
		_grantRole(UPGRADEABLE_ROLE, _upgradeable);
		basePrice = _basePrice;
	}

	// =============================================================
	//                         EXTERNAL WRITE
	// =============================================================

	function setNFTPrice(uint256 _price) external onlyRole(OPERATOR_ROLE) {
		if (_price == 0) {
			revert PriceError(_price);
		}
		basePrice = _price;
		emit SetPrice(_price);
	}

	// =============================================================
	//                          GRANT ROLE
	// =============================================================

	/// @notice Grant role to an account
	/// @param role The role to grant
	/// @param account The account to grant the role to
	function grantRole(
		bytes32 role,
		address account
	) public override onlyRole(DEFAULT_ADMIN_ROLE) {
		_grantRole(role, account);
	}

	/// @notice Revoke role from an account
	/// @param role The role to revoke
	/// @param account The account to revoke the role from
	function revokeRole(
		bytes32 role,
		address account
	) public override onlyRole(DEFAULT_ADMIN_ROLE) {
		_revokeRole(role, account);
	}

	// =============================================================
	//                          UUPS UPGRADE
	// =============================================================

	function _authorizeUpgrade(
		address
	) internal override onlyRole(UPGRADEABLE_ROLE) {}
}
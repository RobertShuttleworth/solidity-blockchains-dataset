// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { ERC6551Registry } from "./contracts_ERC6551_ERC6551Registry.sol";
import { IERC6551Registry } from "./contracts_ERC6551_interfaces_IERC6551Registry.sol";
import { IBaseNFTTBA } from "./contracts_ERC6551_interfaces_IBaseNFTTBA.sol";
import { AccessControlUpgradeable } from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";

// upgradeable
import { UUPSUpgradeable } from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";

contract BaseNFTTBA is
	IBaseNFTTBA,
	ERC6551Registry,
	UUPSUpgradeable,
	AccessControlUpgradeable
{
	bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
	bytes32 public constant UPGRADEABLE_ROLE = keccak256("UPGRADEABLE_ROLE");

	// base nft contract => tba => is tba
	mapping(address => mapping(address => bool)) public accounts;
	// base nft contract => tokenId => tba
	mapping(address => mapping(uint256 => address)) public tokenIdToAccount;
	// base nft contract => tba => tokenId
	mapping(address => mapping(address => uint256)) public accountToTokenId;

	// =============================================================
	//                          INITIALIZER
	// =============================================================

	function initialize(
		address _admin,
		address _upgradeable
	) public initializer {
		_grantRole(DEFAULT_ADMIN_ROLE, _admin);
		_grantRole(UPGRADEABLE_ROLE, _upgradeable);
	}

	// =============================================================
	//                          EXTERNAL FUNCTIONS
	// =============================================================

	/// @notice Creates a new account for a base nft tba
	/// @dev Register a TBA account only when an account could be generated.
	/// @param implementation The implementation address
	/// @param salt The salt for the account
	/// @param chainId The chain ID
	/// @param tokenContract The token contract address
	/// @param tokenId The token ID
	function createAccount(
		address implementation,
		bytes32 salt,
		uint256 chainId,
		address tokenContract,
		uint256 tokenId
	)
		public
		override(IBaseNFTTBA, ERC6551Registry)
		onlyRole(OPERATOR_ROLE)
		returns (address)
	{
		assembly {
			// Memory Layout:
			// ----
			// 0x00   0xff                           (1 byte)
			// 0x01   registry (address)             (20 bytes)
			// 0x15   salt (bytes32)                 (32 bytes)
			// 0x35   Bytecode Hash (bytes32)        (32 bytes)
			// ----
			// 0x55   ERC-1167 Constructor + Header  (20 bytes)
			// 0x69   implementation (address)       (20 bytes)
			// 0x5D   ERC-1167 Footer                (15 bytes)
			// 0x8C   salt (uint256)                 (32 bytes)
			// 0xAC   chainId (uint256)              (32 bytes)
			// 0xCC   tokenContract (address)        (32 bytes)
			// 0xEC   tokenId (uint256)              (32 bytes)

			// Silence unused variable warnings
			pop(chainId)

			// Copy bytecode + constant data to memory
			calldatacopy(0x8c, 0x24, 0x80) // salt, chainId, tokenContract, tokenId
			mstore(0x6c, 0x5af43d82803e903d91602b57fd5bf3) // ERC-1167 footer
			mstore(0x5d, implementation) // implementation
			mstore(0x49, 0x3d60ad80600a3d3981f3363d3d373d3d3d363d73) // ERC-1167 constructor + header

			// Copy create2 computation data to memory
			mstore8(0x00, 0xff) // 0xFF
			mstore(0x35, keccak256(0x55, 0xb7)) // keccak256(bytecode)
			mstore(0x01, shl(96, address())) // registry address
			mstore(0x15, salt) // salt

			// Compute account address
			let computed := keccak256(0x00, 0x55)

			// If the account has not yet been deployed
			if iszero(extcodesize(computed)) {
				// Deploy account contract
				let deployed := create2(0, 0x55, 0xb7, salt)

				// Revert if the deployment fails
				if iszero(deployed) {
					mstore(0x00, 0x20188a59) // `AccountCreationFailed()`
					revert(0x1c, 0x04)
				}

				// Store account address in memory before salt and chainId
				mstore(0x6c, deployed)

				// Emit the ERC6551AccountCreated event
				log4(
					0x6c,
					0x60,
					// `ERC6551AccountCreated(address,address,bytes32,uint256,address,uint256)`
					0x79f19b3655ee38b1ce526556b7731a20c8f218fbda4a3990b6cc4172fdf88722,
					implementation,
					tokenContract,
					tokenId
				)

				// Update mapping arrays
				// accounts[tokenContract][deployed] = true
				mstore(0x00, tokenContract)
				mstore(0x20, 0) // slot of 'accounts' mapping
				let slot1 := keccak256(0x00, 0x40)
				mstore(0x00, deployed)
				mstore(0x20, slot1)
				let slot1Final := keccak256(0x00, 0x40)
				sstore(slot1Final, 1) // true is represented as 1

				// tokenIdToAccount[tokenContract][tokenId] = deployed
				mstore(0x00, tokenContract)
				mstore(0x20, 1) // slot of 'tokenIdToAccount' mapping
				let slot2 := keccak256(0x00, 0x40)
				mstore(0x00, tokenId)
				mstore(0x20, slot2)
				let slot2Final := keccak256(0x00, 0x40)
				sstore(slot2Final, deployed)

				// accountToTokenId[tokenContract][deployed] = tokenId
				mstore(0x00, tokenContract)
				mstore(0x20, 2) // slot of 'accountToTokenId' mapping
				let slot3 := keccak256(0x00, 0x40)
				mstore(0x00, deployed)
				mstore(0x20, slot3)
				let slot3Final := keccak256(0x00, 0x40)
				sstore(slot3Final, tokenId)

				// Return the account address
				return(0x6c, 0x20)
			}

			// Otherwise, return the computed account address
			mstore(0x00, shr(96, shl(96, computed)))
			return(0x00, 0x20)
		}
	}

	// =============================================================
	//                          VIEW FUNCTIONS
	// =============================================================

	/// @notice Checks if an account is registered
	/// @param contractAddress The contract address
	/// @param accountAddress The account address
	/// @return True if the account is registered, false otherwise
	function checkAccount(
		address contractAddress,
		address accountAddress
	) external view override returns (bool) {
		return accounts[contractAddress][accountAddress];
	}

	/// @notice Gets the account from the token ID
	/// @param contractAddress The contract address
	/// @param tokenId The token ID
	/// @return The account address
	function getAccountFromTokenId(
		address contractAddress,
		uint256 tokenId
	) external view override returns (address) {
		return tokenIdToAccount[contractAddress][tokenId];
	}

	/// @notice Gets the token ID from the account
	/// @param contractAddress The contract address
	/// @param accountAddress The account address
	/// @return The token ID
	function getTokenIdFromAccount(
		address contractAddress,
		address accountAddress
	) external view override returns (uint256) {
		return accountToTokenId[contractAddress][accountAddress];
	}

	// =============================================================
	//                          UUPS UPGRADE
	// =============================================================

	function _authorizeUpgrade(
		address
	) internal override onlyRole(UPGRADEABLE_ROLE) {}
}
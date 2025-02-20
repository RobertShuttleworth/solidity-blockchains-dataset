// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { AccessControlUpgradeable } from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import { ICreatorToken } from "./contracts_ERC721C_interfaces_ICreatorToken.sol";
import { ICreatorTokenTransferValidator } from "./contracts_ERC721C_interfaces_ICreatorTokenTransferValidator.sol";
import { TransferValidationUpgradeable } from "./contracts_ERC721C_utils_TransferValidationUpgradeable.sol";
import { IERC165 } from "./openzeppelin_contracts_utils_introspection_IERC165.sol";
import { Initializable } from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./contracts_ERC721C_utils_TransferPolicy.sol";

/**
 * @title CreatorTokenBaseUpgradeable
 * @notice CreatorTokenBaseUpgradeable is an abstract contract that provides basic functionality for managing token
 * transfer policies through an implementation of ICreatorTokenTransferValidator. This contract is intended to be used
 * as a base for creator-specific token contracts, enabling customizable transfer restrictions and security policies.
 */
abstract contract CreatorTokenBaseUpgradeable is
	Initializable,
	AccessControlUpgradeable,
	TransferValidationUpgradeable,
	ICreatorToken
{
	error CreatorTokenBase__InvalidTransferValidatorContract();
	error CreatorTokenBase__SetTransferValidatorFirst();

	address public DEFAULT_TRANSFER_VALIDATOR;
	TransferSecurityLevels public constant DEFAULT_TRANSFER_SECURITY_LEVEL =
		TransferSecurityLevels.One;
	uint120 public constant DEFAULT_OPERATOR_WHITELIST_ID = uint120(1);

	ICreatorTokenTransferValidator private _transferValidator;

	/**
	 * @notice Initialize function for the upgradeable contract.
	 */
	function __CreatorTokenBaseUpgradeable_init(
		address _admin,
		address _defaultTransferValidator
	) internal initializer {
		__AccessControl_init();
		_grantRole(DEFAULT_ADMIN_ROLE, _admin);
		DEFAULT_TRANSFER_VALIDATOR = _defaultTransferValidator;
		setTransferValidator(_defaultTransferValidator);
	}

	/**
	 * @notice Allows the contract owner to set the transfer validator to the official validator contract
	 *         and set the security policy to the recommended default settings.
	 * @dev    May be overridden to change the default behavior of an individual collection.
	 */
	function setToDefaultSecurityPolicy()
		public
		virtual
		onlyRole(DEFAULT_ADMIN_ROLE)
	{
		setTransferValidator(DEFAULT_TRANSFER_VALIDATOR);
		ICreatorTokenTransferValidator(DEFAULT_TRANSFER_VALIDATOR)
			.setTransferSecurityLevelOfCollection(
				address(this),
				DEFAULT_TRANSFER_SECURITY_LEVEL
			);
		ICreatorTokenTransferValidator(DEFAULT_TRANSFER_VALIDATOR)
			.setOperatorWhitelistOfCollection(
				address(this),
				DEFAULT_OPERATOR_WHITELIST_ID
			);
	}

	/**
	 * @notice Allows the contract owner to set the transfer validator to a custom validator contract
	 *         and set the security policy to their own custom settings.
	 */
	function setToCustomValidatorAndSecurityPolicy(
		address validator,
		TransferSecurityLevels level,
		uint120 operatorWhitelistId,
		uint120 permittedContractReceiversAllowlistId
	) public onlyRole(DEFAULT_ADMIN_ROLE) {
		setTransferValidator(validator);

		ICreatorTokenTransferValidator(validator)
			.setTransferSecurityLevelOfCollection(address(this), level);

		ICreatorTokenTransferValidator(validator)
			.setOperatorWhitelistOfCollection(
				address(this),
				operatorWhitelistId
			);

		ICreatorTokenTransferValidator(validator)
			.setPermittedContractReceiverAllowlistOfCollection(
				address(this),
				permittedContractReceiversAllowlistId
			);
	}

	/**
	 * @notice Allows the contract owner to set the security policy to their own custom settings.
	 * @dev    Reverts if the transfer validator has not been set.
	 */
	function setToCustomSecurityPolicy(
		TransferSecurityLevels level,
		uint120 operatorWhitelistId,
		uint120 permittedContractReceiversAllowlistId
	) public onlyRole(DEFAULT_ADMIN_ROLE) {
		ICreatorTokenTransferValidator validator = getTransferValidator();
		if (address(validator) == address(0)) {
			revert CreatorTokenBase__SetTransferValidatorFirst();
		}

		validator.setTransferSecurityLevelOfCollection(address(this), level);
		validator.setOperatorWhitelistOfCollection(
			address(this),
			operatorWhitelistId
		);
		validator.setPermittedContractReceiverAllowlistOfCollection(
			address(this),
			permittedContractReceiversAllowlistId
		);
	}

	/**
	 * @notice Sets the transfer validator for the token contract.
	 *
	 * @dev    Throws when provided validator contract is not the zero address and doesn't support
	 *         the ICreatorTokenTransferValidator interface.
	 * @dev    Throws when the caller is not the contract owner.
	 *
	 * @dev    <h4>Postconditions:</h4>
	 *         1. The _transferValidator address is updated.
	 *         2. The `TransferValidatorUpdated` event is emitted.
	 *
	 * @param transferValidator_ The address of the transfer validator contract.
	 */
	function setTransferValidator(
		address transferValidator_
	) public onlyRole(DEFAULT_ADMIN_ROLE) {
		bool isValidTransferValidator = false;

		if (transferValidator_.code.length > 0) {
			try
				IERC165(transferValidator_).supportsInterface(
					type(ICreatorTokenTransferValidator).interfaceId
				)
			returns (bool supportsInterface) {
				isValidTransferValidator = supportsInterface;
			} catch {}
		}

		if (transferValidator_ != address(0) && !isValidTransferValidator) {
			revert CreatorTokenBase__InvalidTransferValidatorContract();
		}

		_transferValidator = ICreatorTokenTransferValidator(transferValidator_);

		emit TransferValidatorUpdated(
			address(_transferValidator),
			transferValidator_
		);
	}

	/**
	 * @notice Returns the transfer validator contract address for this token contract.
	 */
	function getTransferValidator()
		public
		view
		override
		returns (ICreatorTokenTransferValidator)
	{
		return _transferValidator;
	}

	/**
	 * @notice Returns the security policy for this token contract, which includes:
	 *         Transfer security level, operator whitelist id, permitted contract receiver allowlist id.
	 */
	function getSecurityPolicy()
		public
		view
		override
		returns (CollectionSecurityPolicy memory)
	{
		if (address(_transferValidator) != address(0)) {
			return
				_transferValidator.getCollectionSecurityPolicy(address(this));
		}

		return
			CollectionSecurityPolicy({
				transferSecurityLevel: TransferSecurityLevels.Zero,
				operatorWhitelistId: 0,
				permittedContractReceiversId: 0
			});
	}

	/**
	 * @notice Returns the list of all whitelisted operators for this token contract.
	 * @dev    This can be an expensive call and should only be used in view-only functions.
	 */
	function getWhitelistedOperators()
		public
		view
		override
		returns (address[] memory)
	{
		if (address(_transferValidator) != address(0)) {
			return
				_transferValidator.getWhitelistedOperators(
					_transferValidator
						.getCollectionSecurityPolicy(address(this))
						.operatorWhitelistId
				);
		}

		return new address[](0);
	}

	/**
	 * @notice Returns the list of permitted contract receivers for this token contract.
	 * @dev    This can be an expensive call and should only be used in view-only functions.
	 */
	function getPermittedContractReceivers()
		public
		view
		override
		returns (address[] memory)
	{
		if (address(_transferValidator) != address(0)) {
			return
				_transferValidator.getPermittedContractReceivers(
					_transferValidator
						.getCollectionSecurityPolicy(address(this))
						.permittedContractReceiversId
				);
		}

		return new address[](0);
	}

	/**
	 * @notice Checks if an operator is whitelisted for this token contract.
	 * @param operator The address of the operator to check.
	 */
	function isOperatorWhitelisted(
		address operator
	) public view override returns (bool) {
		if (address(_transferValidator) != address(0)) {
			return
				_transferValidator.isOperatorWhitelisted(
					_transferValidator
						.getCollectionSecurityPolicy(address(this))
						.operatorWhitelistId,
					operator
				);
		}

		return false;
	}

	/**
	 * @notice Checks if a contract receiver is permitted for this token contract.
	 * @param receiver The address of the receiver to check.
	 */
	function isContractReceiverPermitted(
		address receiver
	) public view override returns (bool) {
		if (address(_transferValidator) != address(0)) {
			return
				_transferValidator.isContractReceiverPermitted(
					_transferValidator
						.getCollectionSecurityPolicy(address(this))
						.permittedContractReceiversId,
					receiver
				);
		}

		return false;
	}

	/**
	 * @notice Determines if a transfer is allowed based on the token contract's security policy.  Use this function
	 *         to simulate whether or not a transfer made by the specified `caller` from the `from` address to the `to`
	 *         address would be allowed by this token's security policy.
	 *
	 * @notice This function only checks the security policy restrictions and does not check whether token ownership
	 *         or approvals are in place.
	 *
	 * @param caller The address of the simulated caller.
	 * @param from   The address of the sender.
	 * @param to     The address of the receiver.
	 * @return       True if the transfer is allowed, false otherwise.
	 */
	function isTransferAllowed(
		address caller,
		address from,
		address to
	) public view override returns (bool) {
		if (address(_transferValidator) != address(0)) {
			try
				_transferValidator.applyCollectionTransferPolicy(
					caller,
					from,
					to
				)
			{
				return true;
			} catch {
				return false;
			}
		}
		return true;
	}

	/**
	 * @dev Pre-validates a token transfer, reverting if the transfer is not allowed by this token's security policy.
	 *      Inheriting contracts are responsible for overriding the _beforeTokenTransfer function, or its equivalent
	 *      and calling _validateBeforeTransfer so that checks can be properly applied during token transfers.
	 *
	 * @dev Throws when the transfer doesn't comply with the collection's transfer policy, if the _transferValidator is
	 *      set to a non-zero address.
	 *
	 * @param caller  The address of the caller.
	 * @param from    The address of the sender.
	 * @param to      The address of the receiver.
	 */
	function _preValidateTransfer(
		address caller,
		address from,
		address to,
		uint256 /*tokenId*/,
		uint256 /*value*/
	) internal virtual override {
		if (address(_transferValidator) != address(0)) {
			_transferValidator.applyCollectionTransferPolicy(caller, from, to);
		}
	}
}
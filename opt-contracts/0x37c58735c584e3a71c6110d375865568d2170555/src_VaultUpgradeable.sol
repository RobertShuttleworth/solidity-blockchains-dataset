// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// internal
import { BaseUpgradeable } from "./src_internal_BaseUpgradeable.sol";

// interfaces
import { IVault } from "./src_interfaces_internal_IVault.sol";

// internal
import { ClaimableUpgradeable } from "./src_internal_ClaimableUpgradeable.sol";
import { FeeSplitterUpgradeable } from "./src_internal_FeeSplitterUpgradeable.sol";
import { PaymentProcessorUpgradeable } from "./src_internal_PaymentProcessorUpgradeable.sol";
import { SignatureVerifierUpgradeable } from "./src_internal_SignatureVerifierUpgradeable.sol";

// constants
import { Roles } from "./src_constants_RoleConstants.sol";

// libraries
import { Currency } from "./src_libraries_Currency.sol";
import { Types } from "./src_libraries_Types.sol";

contract VaultUpgradeable is
    IVault,
    BaseUpgradeable,
    ClaimableUpgradeable,
    FeeSplitterUpgradeable,
    PaymentProcessorUpgradeable,
    SignatureVerifierUpgradeable
{
    using Types for Types.Claim;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        address admin_,
        address[] calldata recipients_,
        uint256[] calldata percents_,
        address[] calldata signers_,
        address fiat_,
        address oracle_
    )
        external
        initializer
    {
        __BaseUpgradeable_init(admin_);
        __FeeSplitterUpgradeable_init(200, recipients_, percents_);
        __SignatureVerifier_init(name_, "1", signers_.length, signers_);
        __PaymentProcessor_init(fiat_, oracle_, 1_000_000 ether, 1_000_000 ether);
    }

    function claim(Types.Claim calldata claim_, Types.Signature[] calldata signatures_) external nonReentrant {
        _setClaimed(claim_.claimId);

        _setNonce(claim_.userId, claim_.nonce);

        bytes32 claimHash = claim_.hash();

        uint256 amount = getTokenAmount(claim_.token, claim_.value);

        Currency paymentToken = Currency.wrap(claim_.token);

        _validateDeadline(claim_.deadline);

        _verifySignatures(claimHash, signatures_);

        _processTransfer(paymentToken, claim_.recipient, amount, claim_.userId, claim_.value);

        // transfer service fee
        _slittingFee(paymentToken, amount);

        emit Claimed(claim_.claimId, claim_.userId, claim_.nonce, claim_.recipient, claim_.token, claim_.value, amount);
    }
}
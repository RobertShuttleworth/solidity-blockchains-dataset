// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import {AccessControlDefaultAdminRules} from './openzeppelin_contracts_access_extensions_AccessControlDefaultAdminRules.sol';
import {ISciRegistry} from './contracts_SciRegistry_ISciRegistry.sol';
import {IVerifier} from './contracts_Verifiers_IVerifier.sol';

/**
 * @title SciRegistrar
 * @dev This contract allows addresses with REGISTER_DOMAIN_ROLE role to register a domain
 * in the SCI Registry. This will be use by the SCI team to register domains until the protocol
 * became widly used and we don't need to be registering domains for protocols.
 *
 * The address with REGISTER_DOMAIN_ROLE and DEFAULT_ADMIN_ROLE should be a multisig.
 *
 * @custom:security-contact security@sci.domains
 */
contract SciRegistrar is AccessControlDefaultAdminRules {
    // Role that allows registering domains
    bytes32 public constant REGISTER_DOMAIN_ROLE = keccak256('REGISTER_DOMAIN_ROLE');

    ISciRegistry public immutable registry;

    /**
     * @dev Initializes the contract by setting up the SCI Registry reference and defining the admin rules.
     * @param _sciRegistryAddress Address of the custom domain registry contract.
     * @param initialDelay The {defaultAdminDelay}. See AccessControlDefaultAdminRules for more information.
     */
    constructor(
        address _sciRegistryAddress,
        uint48 initialDelay
    ) AccessControlDefaultAdminRules(initialDelay, _msgSender()) {
        registry = ISciRegistry(_sciRegistryAddress);
    }

    /**
     * @dev Registers a domain in the SCI Registry contract.
     * @param owner Address expected to be the domain owner.
     * @param domainHash Namehash of the domain.
     *
     * Requirements:
     *
     * - The caller must have the REGISTER_DOMAIN_ROLE role.
     */
    function registerDomain(
        address owner,
        bytes32 domainHash
    ) external onlyRole(REGISTER_DOMAIN_ROLE) {
        registry.registerDomain(owner, domainHash);
    }

    /**
     * @dev Registers a domain with a verifier in the SCI Registry contract.
     * @param owner Address expected to be the domain owner.
     * @param domainHash Namehash of the domain.
     * @param verifier Address of the verifier contract.
     *
     * Requirements:
     *
     * - The caller must have the REGISTER_DOMAIN_ROLE role.
     *
     * Note: This contract must only be handle by the SCI Team so we assume
     * it's safe to receive the owner.
     */
    function registerDomainWithVerifier(
        address owner,
        bytes32 domainHash,
        IVerifier verifier
    ) external onlyRole(REGISTER_DOMAIN_ROLE) {
        registry.registerDomainWithVerifier(owner, domainHash, verifier);
    }
}
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import {ISciRegistry} from './contracts_SciRegistry_ISciRegistry.sol';

/**
 * @title DomainManager
 * @dev Contract module that implement access
 * control only to owners of a domain in the SCI Registry.
 * @custom:security-contact security@sci.domains
 */
abstract contract DomainManager {
    ISciRegistry public immutable registry;

    /**
     * @dev Thrown when the `account` is not the owner of the domainhash.
     */
    error AccountIsNotDomainOwner(address account, bytes32 domainHash);

    /**
     * @dev Modifier that checks if the provided address is the owner of the SCI domain.
     * @param domainHash The namehash of the domain.
     *
     * Note: Reverts with `AccountIsNotDomainOwner` error if the check fails.
     */
    modifier onlyDomainOwner(address account, bytes32 domainHash) {
        _checkDomainOwner(account, domainHash);
        _;
    }

    /**
     * @dev Initializes the contract with references to the SCI Registry.
     * @param _sciRegistryAddress Address of the SCI Registry contract.
     */
    constructor(address _sciRegistryAddress) {
        registry = ISciRegistry(_sciRegistryAddress);
    }

    /**
     * @dev Reverts with an {AccountIsNotDomainOwner} error if the caller
     * is not the owner of the domain.
     * @param domainHash The namehash of the domain.
     *
     * Note: Overriding this function changes the behavior of the {onlyDomainOwner} modifier.
     */
    function _checkDomainOwner(address account, bytes32 domainHash) private view {
        if (registry.domainOwner(domainHash) != account) {
            revert AccountIsNotDomainOwner(account, domainHash);
        }
    }
}
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import {IVerifier} from './contracts_Verifiers_IVerifier.sol';
import {ISciRegistry} from './contracts_SciRegistry_ISciRegistry.sol';
import {Initializable} from './openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol';
import {Ownable2StepUpgradeable} from './openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol';

/**
 * @title SCI
 * @dev This contract facilitates interaction with the SCI protocol, offering a simplified interface
 * for apps and wallets. Apps and wallets can also directly interact with the
 * Registry and verifiers directly if desired, bypassing this contract.
 * @custom:security-contact security@sci.domains
 */
contract SCI is Initializable, Ownable2StepUpgradeable {
    ISciRegistry public registry;

    /**
     *  @dev Emitted when the Registry is changed.
     */
    event RegistrySet(address indexed oldRegistryAddress, address indexed newRegistryAddress);

    /**
     * @dev Initializes the SCI contract with the owner and registry address.
     * Can only be called once during contract deployment.
     *
     * @param owner The owner of this contract.
     * @param registryAddress The address of the registry to be used by the contract.
     */
    function initialize(address owner, address registryAddress) external initializer {
        __Ownable2Step_init();
        __Ownable_init(owner);
        setRegistry(registryAddress);
    }

    /**
     * @dev Returns info from the domain.
     *
     * @param domainHash The namehash of the domain.
     */
    function domainHashToRecord(
        bytes32 domainHash
    )
        external
        view
        returns (
            address owner,
            IVerifier verifier,
            uint256 lastOwnerSetTime,
            uint256 lastVerifierSetTime
        )
    {
        return registry.domainHashToRecord(domainHash);
    }

    /**
     * @dev Same as isVerifiedForDomainHash but for multiple domains.
     *
     * @param domainHashes An array of domain hashes.
     * @param contractAddress The address of the contract is being verified.
     * @param chainId The id of the chain the contract is deployed in.
     * @return an array of uint256 representing the time when the contract was verified for each domain
     * or 0 if it wasn't.
     *
     * Note: If there is no verifier set then it returns false for that `domainHash`.
     */
    function isVerifiedForMultipleDomainHashes(
        bytes32[] memory domainHashes,
        address contractAddress,
        uint256 chainId
    ) external view returns (uint256[] memory) {
        uint256[] memory domainsVerification = new uint256[](domainHashes.length);
        uint256 domainHashesLength = domainHashes.length;
        for (uint256 i; i < domainHashesLength; ) {
            domainsVerification[i] = isVerifiedForDomainHash(
                domainHashes[i],
                contractAddress,
                chainId
            );
            unchecked {
                ++i;
            }
        }
        return domainsVerification;
    }

    /**
     * @dev Returns if the `contractAddress` deployed in the chain with id `chainId` is verified.
     * to interact with the domain with namehash `domainHash`.
     * @param domainHash The namehash of the domain the contract is interacting with
     * @param contractAddress The address of the contract is being verified.
     * @param chainId The id of the chain the contract is deployed in.
     * @return a uint256 representing the time when the contract was verified.
     * If the contract is not verified, it returns 0.
     *
     * Note: If there is no verifier set then it returns 0.
     */
    function isVerifiedForDomainHash(
        bytes32 domainHash,
        address contractAddress,
        uint256 chainId
    ) public view returns (uint256) {
        (, IVerifier verifier, , ) = registry.domainHashToRecord(domainHash);

        if (address(verifier) == address(0)) {
            return 0;
        }

        return verifier.isVerified(domainHash, contractAddress, chainId);
    }

    /**
     * @dev Sets a new registry.
     *
     * @param newRegistry The address of the new SCI Registry.
     *
     * May emit a {RegistrySet} event.
     */
    function setRegistry(address newRegistry) public onlyOwner {
        address oldRegistryAddress = address(registry);
        registry = ISciRegistry(newRegistry);
        emit RegistrySet(oldRegistryAddress, newRegistry);
    }
}
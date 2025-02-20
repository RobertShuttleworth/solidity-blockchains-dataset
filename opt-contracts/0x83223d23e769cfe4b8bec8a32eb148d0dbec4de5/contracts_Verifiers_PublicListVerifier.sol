// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

import {IVerifier} from './contracts_Verifiers_IVerifier.sol';
import {DomainManager} from './contracts_DomainMangager_DomainManager.sol';
import {Context} from './openzeppelin_contracts_utils_Context.sol';

/**
 * @title PublicListVerifier
 * @dev This contract implements the Verifier interface.
 * Domain owners can add or remove addresses that can interact within their domain.
 *
 * If the owner of the domain sets a contract address with MAX_INT as chain id then it assumes
 * this contract is verified for all chains for that domain.
 * @custom:security-contact security@sci.domains
 */
contract PublicListVerifier is IVerifier, Context, DomainManager {
    uint256 private constant MAX_INT = 2 ** 256 - 1;

    // Domain hash -> contract address -> chain id -> true/false.
    mapping(bytes32 domainHash => mapping(address contractAddress => mapping(uint256 chainId => uint256 registerTimestamp)))
        public verifiedContracts;

    /**
     *  @dev Emitted when the `msgSender` removes an address to a `domainHash` for a `chainId`.
     */
    event AddressRemoved(
        bytes32 indexed domainHash,
        uint256 indexed chainId,
        address indexed contractAddress,
        address msgSender
    );

    /**
     *  @dev Emitted when the `msgSender` adds an address to a `domainHash` for a `chainId`.
     */
    event AddressAdded(
        bytes32 indexed domainHash,
        uint256 indexed chainId,
        address indexed contractAddress,
        address msgSender
    );

    constructor(address _registry) DomainManager(_registry) {}

    /**
     * @dev Adds multiple addresses in multiple chains to the domain.
     *
     * Requirements:
     *
     * - The caller must be the owner of the domain.
     */
    function addAddresses(
        bytes32 domainHash,
        address[] calldata contractAddresses,
        uint256[][] calldata chainIds
    ) external onlyDomainOwner(_msgSender(), domainHash) {
        for (uint256 i; i < contractAddresses.length; ) {
            for (uint256 j; j < chainIds[i].length; ) {
                verifiedContracts[domainHash][contractAddresses[i]][chainIds[i][j]] = block
                    .timestamp;
                emit AddressAdded(domainHash, chainIds[i][j], contractAddresses[i], _msgSender());
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Removes multiple addresses in multiple chains to the domain.
     *
     * Requirements:
     *
     * - The caller must be the owner of the domain.
     */
    function removeAddresses(
        bytes32 domainHash,
        address[] calldata contractAddresses,
        uint256[][] calldata chainIds
    ) external onlyDomainOwner(_msgSender(), domainHash) {
        for (uint256 i; i < contractAddresses.length; ) {
            for (uint256 j; j < chainIds[i].length; ++j) {
                verifiedContracts[domainHash][contractAddresses[i]][chainIds[i][j]] = 0;
                emit AddressRemoved(domainHash, chainIds[i][j], contractAddresses[i], _msgSender());
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IVerifier-isVerified}.
     */
    function isVerified(
        bytes32 domainHash,
        address contractAddress,
        uint256 chainId
    ) external view returns (uint256) {
        uint256 verifiedContract = verifiedContracts[domainHash][contractAddress][chainId];

        if (verifiedContract != 0) {
            return verifiedContract;
        }

        verifiedContract = verifiedContracts[domainHash][contractAddress][MAX_INT];
        if (verifiedContract != 0) {
            return verifiedContract;
        }

        // Return 0 if no match is found
        return 0;
    }
}
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.28;

/**
 * @title IVerifier
 * @dev Required interface of a Verifier compliant contract for the SCI Registry.
 * @custom:security-contact security@sci.domains
 */
interface IVerifier {
    /**
     * @dev Verifies if a contract in a specific chain is authorized
     * to interact within a domain.
     * @param domainHash The domain's namehash.
     * @param contractAddress The address of the contract trying to be verified.
     * @param chainId The chain where the contract is deployed.
     * @return a uint256 representing the time when the contract was verified.
     * If the contract is not verified, it returns 0.
     *
     * Note: The return timestamp is a best effor approach to provide the time when the contract
     * was verified. For verifiers that can't know when the contract was verified they could
     * return when the verifier was deployed.
     */
    function isVerified(
        bytes32 domainHash,
        address contractAddress,
        uint256 chainId
    ) external view returns (uint256);
}
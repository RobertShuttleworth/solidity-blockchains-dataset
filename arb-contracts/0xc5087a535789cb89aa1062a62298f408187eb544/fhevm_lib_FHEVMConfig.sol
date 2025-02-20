// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "./fhevm-core-contracts_addresses_ACLAddress.sol";
import "./fhevm-core-contracts_addresses_FHEPaymentAddress.sol";
import "./fhevm-core-contracts_addresses_KMSVerifierAddress.sol";
import "./fhevm-core-contracts_addresses_TFHEExecutorAddress.sol";

/**
 * @title   FHEVMConfig
 * @notice  This library returns all addresses for the ACL, TFHEExecutor, FHEPayment,
 *          and KMSVerifier contracts.
 */
library FHEVMConfig {
    struct FHEVMConfigStruct {
        address ACLAddress;
        address TFHEExecutorAddress;
        address FHEPaymentAddress;
        address KMSVerifierAddress;
    }
    /**
     * @notice This function returns a struct containing all contract addresses.
     * @dev    It returns an immutable struct.
     */
    function defaultConfig() internal pure returns (FHEVMConfigStruct memory) {
        return
            FHEVMConfigStruct({
                ACLAddress: aclAdd,
                TFHEExecutorAddress: tfheExecutorAdd,
                FHEPaymentAddress: fhePaymentAdd,
                KMSVerifierAddress: kmsVerifierAdd
            });
    }
}
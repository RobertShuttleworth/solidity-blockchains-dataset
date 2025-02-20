// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;
// ============ Internal Imports ============
import {AbstractMultisigIsm} from "./contracts_isms_multisig_AbstractMultisigIsm.sol";
import {AbstractMerkleRootMultisigIsm} from "./contracts_isms_multisig_AbstractMerkleRootMultisigIsm.sol";
import {AbstractMessageIdMultisigIsm} from "./contracts_isms_multisig_AbstractMessageIdMultisigIsm.sol";
import {MetaProxy} from "./contracts_libs_MetaProxy.sol";
import {StaticThresholdAddressSetFactory} from "./contracts_libs_StaticAddressSetFactory.sol";

/**
 * @title AbstractMetaProxyMultisigIsm
 * @notice Manages per-domain m-of-n Validator set that is used
 * to verify interchain messages.
 */
abstract contract AbstractMetaProxyMultisigIsm is AbstractMultisigIsm {
    /**
     * @inheritdoc AbstractMultisigIsm
     */
    function validatorsAndThreshold(
        bytes calldata
    ) public pure override returns (address[] memory, uint8) {
        return abi.decode(MetaProxy.metadata(), (address[], uint8));
    }
}

// solhint-disable no-empty-blocks

/**
 * @title StaticMerkleRootMultisigIsm
 * @notice Manages per-domain m-of-n validator set that is used
 * to verify interchain messages using a merkle root signature quorum
 * and merkle proof of inclusion.
 */
contract StaticMerkleRootMultisigIsm is
    AbstractMerkleRootMultisigIsm,
    AbstractMetaProxyMultisigIsm
{}

/**
 * @title StaticMessageIdMultisigIsm
 * @notice Manages per-domain m-of-n validator set that is used
 * to verify interchain messages using a message ID signature quorum.
 */
contract StaticMessageIdMultisigIsm is
    AbstractMessageIdMultisigIsm,
    AbstractMetaProxyMultisigIsm
{}

// solhint-enable no-empty-blocks

contract StaticMerkleRootMultisigIsmFactory is
    StaticThresholdAddressSetFactory
{
    function _deployImplementation() internal override returns (address) {
        return address(new StaticMerkleRootMultisigIsm());
    }
}

contract StaticMessageIdMultisigIsmFactory is StaticThresholdAddressSetFactory {
    function _deployImplementation() internal override returns (address) {
        return address(new StaticMessageIdMultisigIsm());
    }
}
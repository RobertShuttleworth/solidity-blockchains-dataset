// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {IVault} from "./src_interfaces_IVault.sol";
import {IVaultSupervisor} from "./src_interfaces_IVaultSupervisor.sol";
import {IDelegationSupervisor} from "./src_interfaces_IDelegationSupervisor.sol";
import {ECDSA} from "./node_modules_openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import {IERC20} from "./node_modules_openzeppelin_contracts_interfaces_IERC20.sol";
import {IERC20Permit} from "./node_modules_openzeppelin_contracts_token_ERC20_extensions_IERC20Permit.sol";
import "./src_interfaces_Constants.sol";
import "./src_interfaces_Errors.sol";
import "./src_interfaces_ILimiter.sol";
import "./src_interfaces_ICore.sol";

import {ISwapper} from "./src_interfaces_ISwapper.sol";

library VaultSupervisorLib {
    /// @custom:storage-location erc7201:vaultsupervisor.storage
    struct Storage {
        mapping(address staker => mapping(IVault vault => uint256 shares)) stakerShares;
        mapping(address staker => IVault[] vaults) stakersVaults;
        mapping(address staker => uint256 nonce) userNonce;
        mapping(address vault => address implementation) vaultToImplMap;
        IVault[] vaults;
        address vaultImpl;
        IDelegationSupervisor delegationSupervisor;
        ILimiter limiter;
        mapping(IERC20 inputAsset => mapping(IERC20 outputAsset => ISwapper swapper)) inputToOutputToSwapper;
        mapping(address v1Vaults => mapping(address v2Vaults => bool isAllowlisted)) __deprecated__allowlistedRoutes;
        ICore v2CoreAddress;
    }

    function initOrUpdate(Storage storage self, address _delegationSupervisor, address _vaultImpl, ILimiter _limiter)
        internal
    {
        if (_vaultImpl == address(0) || _delegationSupervisor == address(0)) {
            revert ZeroAddress();
        }
        self.delegationSupervisor = IDelegationSupervisor(_delegationSupervisor);
        self.vaultImpl = _vaultImpl;
        self.limiter = _limiter;
    }

    function verifySignatures(
        IVault vault,
        address user,
        uint256 value,
        uint256 minSharesOut,
        uint256 deadline,
        IVaultSupervisor.Signature calldata permit,
        IVaultSupervisor.Signature calldata vaultAllowance,
        uint256 nonce
    ) internal {
        try IERC20Permit(address(vault.asset())).permit(
            user, address(vault), value, deadline, permit.v, permit.r, permit.s
        ) {} catch {
            if (IERC20(vault.asset()).allowance(user, address(vault)) < value) revert PermitFailed();
        }
        verifyVaultSign({
            vault: address(vault),
            user: user,
            value: value,
            minSharesOut: minSharesOut,
            deadline: deadline,
            vaultSign: vaultAllowance,
            nonce: nonce
        });
    }

    function verifyVaultSign(
        address vault,
        address user,
        uint256 value,
        uint256 minSharesOut,
        uint256 deadline,
        IVaultSupervisor.Signature calldata vaultSign,
        uint256 nonce
    ) internal view {
        if (deadline < block.timestamp) revert ExpiredSign();
        bytes32 EIP712DomainHash = keccak256(
            abi.encode(
                Constants.DOMAIN_TYPEHASH,
                keccak256(bytes("Karak_Vault_Sup")),
                keccak256(bytes("v1")),
                block.chainid,
                address(this)
            )
        );
        bytes32 vaultHash =
            keccak256(abi.encodePacked(Constants.SIGNED_DEPOSIT_TYPEHASH, vault, deadline, value, minSharesOut, nonce));
        bytes32 combinedHash = keccak256(abi.encodePacked("\x19\x01", EIP712DomainHash, vaultHash));
        address signer = ECDSA.recover(combinedHash, vaultSign.v, vaultSign.r, vaultSign.s);
        if (signer != user) revert InvalidSignature();
    }
}
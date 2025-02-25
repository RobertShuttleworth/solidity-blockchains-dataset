// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2024 Tokemak Foundation. All rights reserved.
pragma solidity ^0.8.24;

import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

/**
 *  @title Validates and distributes Vault token rewards based on the
 *  the signed and submitted payloads
 */
interface IRewards {
    struct Recipient {
        uint256 chainId;
        uint256 cycle;
        address wallet;
        uint256 amount;
    }

    event SignerSet(address newSigner);
    event Claimed(uint256 cycle, address recipient, uint256 amount);

    /// @notice Get the underlying token rewards are paid in
    /// @return Token address
    function rewardToken() external view returns (IERC20);

    /// @notice Get the current payload signer;
    /// @return Signer address
    function rewardsSigner() external view returns (address);

    /// @notice Check the amount an account has already claimed
    /// @param account Account to check
    /// @return Amount already claimed
    function claimedAmounts(
        address account
    ) external view returns (uint256);

    /// @notice Get the amount that is claimable based on the provided payload
    /// @param recipient Published rewards payload
    /// @return Amount claimable if the payload is signed
    function getClaimableAmount(
        Recipient calldata recipient
    ) external view returns (uint256);

    /// @notice Change the signer used to validate payloads
    /// @param newSigner The new address that will be signing rewards payloads
    function setSigner(
        address newSigner
    ) external;

    /// @notice Claim your rewards
    /// @param recipient Published rewards payload
    /// @param v v component of the payload signature
    /// @param r r component of the payload signature
    /// @param s s component of the payload signature
    function claim(Recipient calldata recipient, uint8 v, bytes32 r, bytes32 s) external returns (uint256);

    /// @notice Claim rewards on behalf of another account , invoked primarily by the router
    /// @param recipient Published rewards payload
    /// @param v v component of the payload signature
    /// @param r r component of the payload signature
    /// @param s s component of the payload signature
    function claimFor(Recipient calldata recipient, uint8 v, bytes32 r, bytes32 s) external returns (uint256);

    /// @notice Generate the hash of the payload
    /// @param recipient Published rewards payload
    /// @return Hash of the payload
    function genHash(
        Recipient memory recipient
    ) external view returns (bytes32);
}
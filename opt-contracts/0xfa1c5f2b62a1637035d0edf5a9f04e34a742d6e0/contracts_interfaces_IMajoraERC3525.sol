// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "./majora-finance_erc-3525_contracts_ERC3525Upgradeable.sol";

/**
 * @title Interface of MajoraERC3525
 * @author Majora Development Association
 * @notice Interface for the MajoraERC3525 contract
 */
interface IMajoraERC3525 is IERC3525Upgradeable {

    enum MajoraERC3525UpdateType {
        Transfer,        // Represents a transfer update
        ReceiveRewards,  // Represents an update when rewards are received
        Redeem           // Represents a redeem update
    }

    /**
     * @notice Error thrown when the caller is not the token owner
     */
    error NotTokenOwner();

    /**
     * @notice Error thrown when the token balance is zero
     */
    error ZeroBalanceToken();

    /**
     * @notice Error thrown when the caller is not the vault
     */
    error NotVault();

    /**
     * @notice Error thrown when the claim delay is not reached
     */
    error ClaimDelayNotReached();

    /**
     * @notice Event triggered when the contract is updated
     * @param update The type of update
     * @param data The data of the update
     */
    event MajoraERC3525Update(
        MajoraERC3525UpdateType indexed update,
        bytes data
    );

    /**
     * @dev Initializes the contract with the specified vault, owner, tokenFee and treasury.
     * @param _vault The address of the vault.
     * @param _owner The address of the contract owner.
     * @param _tokenFee The address of the ERC20 token to redeem for a proportional share.
     * @param _authority The address of the access manager
     */
    function initialize(address _vault, address _owner, address _tokenFee, address _authority) external;

    /**
     * @dev Redeems tokens in the specified token ID.
     * @param _tokenId The ID of the token to redeem.
     */
    function redeem(uint256 _tokenId) external;

    /**
     * @dev Adds rewards to the contract.
     * @param _amount The amount of tokens to add as rewards.
     */
    function addRewards(uint256 _amount) external;

    /**
     * @dev Redeems tokens in the treseaury address if token ID not claimed after 6 months.
     * @param _tokenId The ID of the token to redeem.
     */
    function pullUnclaimedToken(uint256 _tokenId) external;
}
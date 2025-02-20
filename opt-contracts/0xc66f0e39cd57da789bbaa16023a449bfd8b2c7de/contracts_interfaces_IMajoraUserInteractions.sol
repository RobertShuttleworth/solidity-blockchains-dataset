// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import { IMajoraVault } from "./contracts_interfaces_IMajoraVault.sol";

/**
 * @title Majora interactions helper
 * @author Majora Development Association
 * @notice Additional contract to implement permit1, permit2 and Gelato relay
 */
interface IMajoraUserInteractions {

    /**
     * @notice Triggered when functions inputs are invalid
     */
    error BadInput();

    /**
     * @notice Triggered when function caller is not the portal
     */
    error NotPortal();

    /**
     * @notice Deploys a new vault with the specified parameters.
     * @dev This function calls the factory contract to create a new vault.
     * @param _name The name of the new vault.
     * @param _symbol The symbol of the new vault.
     * @param _asset The address of the asset token for the vault.
     * @param _strategy The identifier for the strategy to be used by the vault.
     * @param _creatorFees The fees to be paid to the creator of the vault.
     * @param _harvestFees The fees to be paid for harvesting the vault.
     * @param _ipfsHash The IPFS hash containing additional information about the vault.
     */
    function deployNewVault(
        string memory _name,
        string memory _symbol,
        address _asset,
        uint256 _strategy,
        uint256 _creatorFees,
        uint256 _harvestFees,
        string memory _ipfsHash
    ) external;

    /**
     * @notice Sets the strategy for a given vault.
     * @dev This function configures the strategy for a vault by specifying position managers, strategy blocks, their parameters, and harvest blocks.
     * @param vault The address of the vault for which the strategy is being set.
     * @param _positionManagers An array of addresses for the position managers associated with the strategy.
     * @param _stratBlocks An array of addresses for the strategy blocks to be used in the strategy.
     * @param _stratBlocksParameters An array of bytes representing the parameters for each strategy block.
     * @param _isFinalBlock An array of booleans indicating whether each corresponding strategy block is a final block in the strategy.
     * @param _harvestBlocks An array of addresses for the harvest blocks to be used in the strategy.
     * @param _harvestBlocksParameters An array of bytes representing the parameters for each harvest block.
     */
    function setVaultStrategy(
        address vault,
        address[] memory _positionManagers,
        address[] memory _stratBlocks,
        bytes[] memory _stratBlocksParameters,
        bool[] memory _isFinalBlock,
        address[] memory _harvestBlocks,
        bytes[] memory _harvestBlocksParameters
    ) external;

    /**
     * @notice Edits the parameters of an existing vault.
     * @param _vault The address of the vault to be edited.
     * @param settings An array of MajoraVaultSettings indicating which settings to edit.
     * @param data An array of bytes data corresponding to each setting in `settings`.
     */
    function editVaultParams(
        address _vault,
        IMajoraVault.MajoraVaultSettings[] memory settings,
        bytes[] memory data
    ) external;

    /**
     * @notice Allows a user to deposit assets into a vault.
     * @param _vault The address of the vault where assets will be deposited.
     * @param _assets The amount of assets to deposit.
     * @param _permitParams The permit parameters for approving the vault to spend assets on behalf of the sender.
     */
    function vaultDeposit(
        address _vault,
        uint256 _assets,
        address _receiver,
        bytes memory _permitParams
    ) external;

    /**
     * @notice Allows a user to deposit assets into a vault after a portal swap.
     * @param _sender The address of the vault where assets will be deposited.
     * @param _vault The address of the vault where assets will be deposited.
     * @param _assets The amount of assets to deposit.
     * @param _receiver The vault shares receiver
     */
    function portalVaultDeposit(
        address _sender,
        address _vault,
        uint256 _assets,
        address _receiver
    ) external;

    /**
     * @notice Redeems shares from the vault and sends the underlying assets to the sender.
     * @param _vault The address of the vault from which to redeem shares.
     * @param _shares The amount of shares to redeem.
     * @param _permitParams The permit parameters for approving the vault to spend shares on behalf of the sender.
     */
    function vaultRedeem(
        address _vault,
        uint256 _shares,
        bytes memory _permitParams
    ) external;

    /**
     * @notice Performs a withdrawal rebalance operation on the vault.
     * @param _vault The address of the vault to perform the withdrawal rebalance on.
     * @param _deadline The deadline by which the operation must be completed.
     * @param _amount The amount to withdraw from the vault.
     * @param _signature The signature for permit-based withdrawals.
     * @param _portalPayload The payload for interacting with external protocols during the rebalance.
     * @param _permitParams The permit parameters for approving the vault to spend tokens on behalf of the sender.
     * @param _dynParamsIndexExit Dynamic parameters index for exiting strategies.
     * @param _dynParamsExit Dynamic parameters for exiting strategies.
     */
    function vaultWithdrawalRebalance(
        address _vault,
        uint256 _deadline,
        uint256 _amount,
        bytes memory _signature,
        bytes memory _portalPayload,
        bytes memory _permitParams,
        uint256[] memory _dynParamsIndexExit,
        bytes[] memory _dynParamsExit
    ) external payable returns (uint256 returnedAssets);

    /**
     * @notice Claims rewards for ERC3525 tokens.
     * @param _erc3525s The addresses of the ERC3525 tokens for which to claim rewards.
     * @param _tokenIds The token IDs for which to claim rewards.
     */
    function claimERC3525Rewards(
        address[] memory _erc3525s,
        uint256[] memory _tokenIds
    ) external;
}
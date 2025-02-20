// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./src_interfaces_ILiquidationCalculator.sol";

/**
 * @title HubSpokeEvents
 * @notice Events emitted by the Hub and Spoke contracts
 */
contract HubSpokeEvents {
    event Liquidation(address indexed liquidator, address indexed vault, ILiquidationCalculator.DenormalizedLiquidationAsset[] liquidationAssets);
    event Deposit(address indexed vault, address indexed asset, uint256 amount, uint256 vaultTotalDeposited);
    event Withdraw(address indexed vault, address indexed asset, uint256 amount, uint256 vaultTotalDeposited);
    event Borrow(address indexed vault, address indexed asset, uint256 amount, uint256 vaultTotalBorrowed);
    event Repay(address indexed vault, address indexed asset, uint256 amount, uint256 vaultTotalBorrowed);
    event ReservesWithdrawn(address indexed asset, uint256 amount, address destination);
    // TODO: address should be bytes32 in SpokeRegistered
    // ideally, we'd change Spoke address to wormhole format bytes32, but this might not be trivial given the existing events
    // we could maybe change the event, ignore previous events and re-register all spokes after the upgrade
    // afaik we don't have any external consumers of this event
    // this needs to be fixed before we can support Solana and other non-EVM chains
    event SpokeRegistered(uint16 chainId, address spoke);
    event AssetRegistered(
        address asset,
        uint256 collateralizationRatioDeposit,
        uint256 collateralizationRatioBorrow,
        uint256 borrowLimit,
        uint256 supplyLimit,
        address interestRateCalculator,
        uint256 maxLiquidationPortion,
        uint256 maxLiquidationBonus
    );
    event SetAssetParams(
        address asset,
        uint256 borrowLimit,
        uint256 supplyLimit,
        uint256 maxLiquidationPortion,
        uint256 maxLiquidationBonus,
        address interestRateCalculator
    );
    event CollateralizationRatiosChanged(
        address asset,
        uint256 collateralizationRatioDeposit,
        uint256 collateralizationRatioBorrow
    );
    event SetLiquidationFee(uint256 value, uint256 precision);
    event AssetPythIdChanged(address asset, bytes32 oldPythId, bytes32 newPythId);
    event AccrualIndexUpdated(address indexed asset, uint256 deposit, uint256 borrow, uint256 timestamp);

    event SpokeCreditCreated(address indexed user, address indexed asset, uint256 amount, uint256 nonce);
    event SpokeCreditLost(address indexed user, address indexed asset, uint256 amount, uint256 nonce);
    event SpokeCreditRefundable(address indexed user, address indexed asset, uint256 amount, uint256 nonce);
    event SpokeCreditConfirmed(uint256 nonce);
    event SpokeCreditFinalized(uint256 nonce);
    event SpokeCreditRefunded(address indexed user, address indexed asset, uint256 amount, uint256 nonce);
    event SpokeLimitsChanged(address indexed asset, uint256 creditLimit, uint256 custodyLimit, uint256 transactionLimit);
    event SpokeFeesChanged(uint256 inboundTokenFee, uint256 outboundTokenFee);
    event SpokeFundsReleased(address indexed user, address indexed asset, uint256 amount, uint256 nonce);
    event SpokeTopUpReceived(address indexed asset, uint256 amount);

    event HubCreditCreated(uint16 indexed chainId, bytes32 indexed user, bytes32 indexed asset, uint256 amount, uint256 nonce);
    event HubCreditLost(uint16 indexed chainId, bytes32 indexed user, bytes32 indexed asset, uint256 amount, uint256 nonce);
    event HubCreditRefundable(uint16 indexed chainId, bytes32 indexed user, bytes32 indexed asset, uint256 amount, uint256 nonce);
    event HubCreditFinalized(uint16 indexed chainId, uint256 nonce);

    event PossibleHubMisconfiguration(address assetSentAsWeth, address realWeth);
}
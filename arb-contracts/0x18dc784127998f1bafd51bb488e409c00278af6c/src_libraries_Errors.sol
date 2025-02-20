// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                GMX FACTORY ERRORS
    //////////////////////////////////////////////////////////////////////////*/
    error GmxFactory_NotPlatformLogic();
    error GmxFactory_TransactionFailedOnTokenTransfer();
    error GmxFactory_InsufficientGmxExecutionFee();
    error GmxFactory_TokenNotAllowed();
    error GmxFactory_DifferentCollateralToken();
    error GmxFactory_IncorrectGrossFeeAmount();
    error GmxFactory_HigherSizeDelta();
    error GmxFactory_NotOwner();
    error GmxFactory_NotAdapterOwner();
    error GmxFactory_PositionNotOpened();
    error GmxFactory_TransferFailed();
    error GmxFactory_NotNftHandler();
    error GmxFactory_NotPositionRouter();
    error GmxFactory_NotAdapter();
    error GmxFactory_NotGmxPositionRouter();
    error GmxFactory_NotCallBackReceiver();
    error GmxFactory_NotEnoughFeeFunds();
    error GmxFactory_SameIndexToken();
    error GmxFactory_NotComptrollerAdmin();
    error GmxFactory_DifferentPath();
    error GmxFactory_EntityCannotBe0Address();
    error GmxFactory_NotProposedComptroller();
    error GmxFactory_PreviosOrderPending();
    error GmxFactory_NotPositionNFT();
    error GmxFactory_UnknownOrderKey();
    error GmxFactory_BeaconAlreadySet();

    /*//////////////////////////////////////////////////////////////////////////
                               VERTEX FACTORY ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error VertexFactory_NotPlatformLogic();
    error VertexFactory_TokenNotAllowed();
    error VertexFactory_NotComptrollerAdmin();
    error VertexFactory_NotProposedComptroller();
    error VertexFactory_EntityCannotBe0Address();
    error VertexFactory_WrongValueSent(
        uint256 valueSent, uint256 expectedFeeAmount
    );
    error VertexFactory_NotCallbackWallet();
    error VertexFactoryCallback_FailedToSendFundsToUser();
    error VertexFactoryCallback_FailedToSendFundsToCallbackWallet();

    /*//////////////////////////////////////////////////////////////////////////
                                PLATFORM LOGIC ERRORS
    //////////////////////////////////////////////////////////////////////////*/
    error PlatformLogic_Unavailable();
    error PlatformLogic_NotFactory();
    error PlatformLogic_WrongFeeAmount();
    error PlatformLogic_GivenZeroAddress();
    error PlatformLogic_ExceedsAllowance(uint256 feeAmount);
    error PlatformLogic_NotEnoughBalance();
    error PlatformLogic_AddressSetInComptrollerIsNotThisOne();
    error PlatformLogic_FeeAmountCannotBeNull();
    error PlatformLogic_NotComptrollerAdmin();
    error PlatformLogic_InvalidSigner();
    error PlatformLogic_CodeCreatorIsNotMsgSender();
    error PlatformLogic_RefereeNotMsgSender();
    error PlatformLogic_ComptrollerCannot0BeAddress();
    error PlatformLogic_TransactionFailed();
    error PlatformLogic_WrongValueSent(
        uint256 expectedFeeAmount, uint256 feeAmountSent
    );
    error PlatformLogic_ExceedingBps();
    error PlatformLogic_NotPositionNFT();

    /*//////////////////////////////////////////////////////////////////////////
                                  GXM ADAPTER ERRORS
    //////////////////////////////////////////////////////////////////////////*/
    error GmxAdapter_IncorrectFeeAmount();
    error GmxAdapter_WithdrawFailed();
    error GmxAdapter_Unauthorized();
    error GmxAdapter_CannotBeZeroAddress();
    error GmxAdapter_NotComptrollerAdmin();
    error GmxAdapter_NotAdapterOwner();
    error GmxAdapter_NotGmxFactory();
    error GmxAdapter_NotPositionNFT();

    /*//////////////////////////////////////////////////////////////////////////
                                COMPTROLLER ERRORS
    //////////////////////////////////////////////////////////////////////////*/
    error Comptroller_CallerNotAdmin();
    error Comptroller_AddressNotSet();
    error Comptroller_AdminCannotBe0Address();
    error Comptroller_UnauthorizedAccount(address unauthorizedUser);
    error Comptroller_AddressGivenIsZeroAddress();

    /*//////////////////////////////////////////////////////////////////////////
                                REWARDSCLAIMER ERRORS
    //////////////////////////////////////////////////////////////////////////*/
    error RewardsClaimer_NotOwner();
    error RewardsClaimer_NotPlatformLogic();
    error RewardsClaimer_UserHasNoRewardsToClaimOrHasExceededClaimingAmount();
    error RewardsClaimer_CannotClaimRewardsInTheSameBlock();
    error RewardsClaimer_CannotSendTo0Address();
    error RewardsClaimer_NotWhitelistedPlatform();
    error RewardsClaimer_ExceedsMaxClaimForPlatform();
    error RewardsClaimer_TransferFailed();

    /*//////////////////////////////////////////////////////////////////////////
                                 POSITIONNFT ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error PositionNFT_CallerIsNotNftHandler();
    error PositionNft_NotComptrollerAdmin();
    error PositionNFT_NotAdapterOwner();
    error PositionNFT_PositionNonExistantOrAlreadyClosed();
    error PositionNFT_PositionAlreadyMinted();
    error PositionNFT_NotNftOwner();
    error PositionNFT_PositionNotClosed();
    error PositionNFT_NotPositionOwner(address positionOwner);
    error PositionNFT_NotOwner();
    error PositionNFT_NotComptrollerAdmin();
    error PositionNFT_ComptrollerCannot0BeAddress();
    error PositionNFT_NotProposedComptroller();
    error PositionNFT_TokenNotAllowed();
    error PositonNFT_UserHasAPendingPosition();

    /*//////////////////////////////////////////////////////////////////////////
                                 PEARSTAKER ERRORS
    //////////////////////////////////////////////////////////////////////////*/
    error PearStaker_TransferFailed();
    error PearStaker_ExitFeeTransferFailed();
    error PearStaker_InsufficientBalance(uint256 balance, uint256 amount);
    error PearStaker_InsufficientStakeAmount(uint256 amount);
    error StakingRewards_NotPlatformLogic();
    error PearStaker_ZeroEarnedAmount();
    error PearStaker_StakesAreNotTransferable();
    error PearStaker_PearTokenAlreadyInitialized();
    error PearStaker_NotComptrollerAdmin();
    error StakingRewards_NotPlatformLogicOrComptrollerAdmin();

    /*//////////////////////////////////////////////////////////////////////////
                                 FEEREBATEMANAGER ERRORS
    //////////////////////////////////////////////////////////////////////////*/
    error FeeRebateManager_InvalidTier();
    error FeeRebateManager_InvalidRebateTier();
    error FeeRebateManager_InvalidDiscountTier();
    error FeeRebateManager_AlreadyClaimed();
    error FeeRebateManager_NoRebateAvailable();
    error FeeRebateManager_InsufficientFunds();
    error FeeRebateManager_NotComptrollerAdmin();
    error FeeRebateManager_NotFactory();
    error FeeRebateManager_NotPlatformLogic();
    error FeeRebateManager_TransferFailed();
    error FeeRebateManager_RebatesDisabled();
    error FeeRebateManager_CantClaimForCurrentMonth();

    error SymmFactory_NotComptrollerAdmin();
    error SymmFactory_NotBackendWallet();
    error SymmFactoryFailedToSendFundsToUser();
    error SymmFactoryNoClaimableDiscount();
    error SymmFactoryIncorrectAmountSent();
    error SymmFactoryNoAmountToDistribute();
    error SymmFactoryFailedToWithdrawUSDC();

    error PearVesting_NotAdmin();
    error PearVesting_ZeroAmount();
    error PearVesting_ZeroAddress();
    error PearVesting_InvalidEndTime();
    error PearVesting_InvalidCliffTime();
    error PearVesting_VestingNotRelease();
    error PearVesting_NotRecipient();
    error PearVesting_CliffNotReached();
    error PearVesting_NothingToClaim();
    error PearVesting_TransferFailed();
    error PearVesting_InvalidPlanId();
    error PearVesting_LowerAmount();
    error PearVesting_InvalidInputLength();

    error Airdrop_ALREADY_CLAIMED();
    error Airdrop_NOT_ELIGIBLE();
    error Airdrop_NotComptrollerAdmin();
}
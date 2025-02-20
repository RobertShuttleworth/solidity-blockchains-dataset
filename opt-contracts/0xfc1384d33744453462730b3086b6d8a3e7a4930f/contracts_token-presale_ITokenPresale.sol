// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ITokenPresale {
    enum Status {
        None,
        Opened,
        Closed
    }

    struct PresaleStep {
        bool defined;
        Status status;
        uint256 price;
        uint256 sold;
        uint256 supply;
    }

    struct Participant {
        bool defined;
        bool enabled;
        uint256 firstParticipantRate;
        uint256 secondParticipantRate;
    }

    struct PaymentBonus {
        uint256 bonus;
        uint256 payment;
    }

    event StatusUpdated(Status status);
    event PresaleStepOpened(uint256 indexed presaleStep);
    event PresaleStepClosed(uint256 indexed presaleStep);
    event PresaleStepAdded(uint256 price, uint256 supply);
    event PresaleStepPriceUpdated(uint256 indexed presaleStep, uint256 price);
    event PresaleStepSupplyUpdated(uint256 indexed presaleStep, uint256 supply);
    event Erc20Recovered(address token, uint256 amount);
    event ETHRecovered(uint256 amount);
    event MinUsdValueUpdated(uint256 amount);
    event BankUpdated(address indexed treasury);
    event ParticipantRateSetup(uint256 firstParticipantRate, uint256 secondParticipantRate);
    event ParticipantSetup(string participant, uint256 firstParticipantRate, uint256 secondParticipantRate);
    event ParticipantEnabled(string participant);
    event ParticipantDisabled(string participant);
    event ParticipantRewardsClaimed(string participant, address indexed token, uint256 amount);
    event ClaimApproverUpdated(address claimApprover);

    error ParamsInvalidERR();
    error OpenedERR();
    error ClosedERR();
    error ZeroAddressERR();
    error PresaleStepUndefinedERR();
    error PresaleStepStartedERR();
    error PresaleStepClosedERR();
    error PresaleStepSupplyERR();
    error MinUsdValueERR();
    error DefaultRateERR();
    error ParticipantUndefinedERR();
    error ParticipantEnabledERR();
    error ParticipantDisabledERR();
    error TokenUndefinedERR();
    error ClaimApproverNotSetERR();
    error TransactionExpiredERR();
    error InvalidClaimApproverERR();
    error HashAlreadyUsedERR();
    error InvalidArrayLengthERR();
    error EthCallERR();
    error InvalidPaymentBonusArraysERR();

    function startPresale() external;
    function stopPresale() external;
    function addNewPresaleStep(uint256 price_, uint256 supply_) external;
    function setDefaultRates(uint256 firstParticipantRate_, uint256 secondParticipantRate_) external;
    function setupParticipant(
        string[] calldata refs_,
        uint256[] calldata firstParticipantRate_,
        uint256[] calldata secodParticipantFunds_
    ) external;
    function updatePresaleStepPrice(uint256 index_, uint256 price_) external;
    function updatePresaleStepSupply(uint256 index_, uint256 supply_) external;
    function openPresaleStep(uint256 index_) external;
    function closePresaleStep(uint256 index_) external;
    function setMinUsdValue(uint256 amount_) external;
    function setBank(address bank_) external;
    function setData(
        address user_,
        address token_,
        uint256 amount_,
        uint256 sold_,
        string calldata participant_,
        uint256 fReward_,
        uint256 sReward_
    ) external;
    function enableParticipant(string calldata participant_) external;
    function disableParticipant(string calldata participant_) external;
    function claimParticipant(address[] memory tokens_, string memory participant_, uint256 deadline_, uint8 v, bytes32 r, bytes32 s) external;
    function recoverETH() external;
    function recoverERC20(address token_, uint256 amount_) external;
    function getBank() external view returns (address);
    function getMinUsdValue() external view returns (uint256);
    function getPresaleStepsCount() external view returns (uint256);
    function getCurrent() external view returns (uint256);
    function getPresaleStep(uint256 index_) external view returns (PresaleStep memory);
    function getTotal() external view returns (uint256);
    function getUserAllocation(uint256 turn_, address user_) external view returns (uint256);
    function getParticipantsAllocation(address token_, string calldata user_) external view returns (uint256);
    function getRates() external view returns (uint256, uint256);
    function getParticipant(address user_, string calldata participant_) external view returns (string memory);
    function getParticipantRates(string calldata participant_) external view returns (uint256, uint256);
    function getPrice() external view returns (uint256);
    function getStatus() external view returns (ITokenPresale.Status);
    function setTrustParticipant(bool value) external;
    function getPaymentBonus() external view returns(PaymentBonus[] memory);
    function setPaymentBonus(uint256[] calldata percents_, uint256[] calldata limits_) external;
    function calculatePaymentBonus(uint256 usdAmount_, uint256 tokenAmount_) external view returns(uint256);
}
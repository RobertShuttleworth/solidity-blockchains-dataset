// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDCAManagement {
    struct DCAPlan {
        uint256 id;
        address userPlanVaultAddress;
        bool isPaused;
        uint256 eachTimeInvestAmount;
        uint256 eachTimePeriod;
        uint256 startTimestamp;
        uint256 cancelTimestamp;
        uint256 firstInvestTimestamp;
        uint256 lastReinvestTimestamp;
        DCAPlanDetail planDetail;
        DCAPeriodData periodData;
    }

    struct DCAPlanDetail {
        address strategy;
        address inputToken;
        uint256 costOfDCA;
        uint256 userReceivedToken0Amount;
        uint256 userReceivedToken1Amount;
        uint256 rewardAccumulated;
    }

    struct DCAPeriodData {
        uint8 month;
        uint8 week;
        uint8 day;
        uint8 hour;
        uint8 minute;
    }

    struct ExecutionData {
        address userPlanVaultAddress;
        address inputToken;
        uint256 inputAmount;
        address token0;
        address token1;
        uint256 shareBefore;
        uint256 shareAfter;
    }

    event DCAPlanCreated(
        address indexed strategy,
        address indexed user,
        address indexed userVault,
        uint256 planId,
        address inputToken,
        uint256 eachTimeInvestAmount,
        uint256 eachTimePeriod
    );

    event DCAPlanExecuted(
        address indexed strategy,
        address indexed user,
        address indexed userVault,
        uint256 planId,
        address inputToken,
        uint256 inputAmount
    );

    event DCAPlanCancelled(
        address indexed strategy,
        address indexed user,
        address indexed userVault,
        uint256 planId,
        address token0Address,
        address token1Address,
        uint256 userReceivedToken0Amount,
        uint256 userReceivedToken1Amount,
        uint256 cancelTimestamp
    );

    event DCAPlanUpdated(
        address indexed strategy,
        address indexed user,
        uint256 planId,
        uint256 eachTimeInvestAmount,
        uint256 eachTimePeriod,
        bool isPaused
    );

    event DCARewardClaimed(
        address indexed strategy, address indexed user, address indexed userVault, uint256 planId, uint256 reward
    );

    event FeeNumeratorUpdated(uint24 oldNumerator, uint24 newNumerator);
    event MaxPlanAmountUpdated(uint256 oldMaxPlanAmount, uint256 newMaxPlanAmount);

    ///@dev Create the DCA plan for the strategy
    function createDCAPlan(
        address _strategy,
        address _inputToken,
        uint256 _eachTimeInvestAmount,
        uint256 _eachTimePeriod,
        DCAPeriodData calldata _periodData
    ) external;

    ///@dev Execute the DCA plan
    function executeDCAPlan(
        address _userAddress,
        address _strategyContract,
        uint256 _planIndex,
        uint256 _swapInAmount,
        uint256 _minimumSwapOutAmount
    ) external;

    ///@dev Update the DCA plan
    function updateDCAPlan(
        address _strategy,
        uint256 _planIndex,
        uint256 _planId,
        address _inputToken,
        uint256 _eachTimeInvestAmount,
        uint256 _eachTimePeriod,
        bool _isPaused,
        DCAPeriodData calldata _periodData
    ) external;

    ///@dev Cancel the DCA plan and transfer the remaining token to the user
    function cancelDCAPlan(address _strategy, uint256 _planIndex, uint256 _planId) external;

    ///@dev Claim the DCA plan reward
    function claimPlanReward(address _strategy, uint256 _planIndex, uint256 _planId) external;

    function isUserExist(address _user) external view returns (bool);

    function getAllUsers() external view returns (address[] memory);

    function getUserAllStrategies(address _user) external view returns (address[] memory);

    function getUserStrategyDCAPlans(address _user, address _strategy) external view returns (DCAPlan[] memory);

    function allowExecPlan(address _user, address _strategy, uint256 _planIndex) external view returns (bool);
}
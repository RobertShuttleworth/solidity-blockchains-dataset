//SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router02.sol";
import "./uniswap_v2-core_contracts_interfaces_IUniswapV2Factory.sol";
import "./uniswap_v2-core_contracts_interfaces_IUniswapV2Pair.sol";
import "./contracts_Structs.sol";

/**
 * @title IChainLinkV3Aggregator
 * @dev Interface for ChainLink Price Feed V3
 */
interface IChainLinkV3Aggregator {
    function latestAnswer() external view returns (int256);
    function decimals() external view returns (uint8);

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/**
 * @title IERC20_EXT
 * @dev Extended interface for ERC20 tokens with additional standard methods
 */
interface IERC20_EXT is IERC20 {
    function decimals() external view returns (uint8);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
}

/**
 * @title IDefaultsUpgradeable
 * @dev Interface for the DefaultsUpgradeable contract managing system configurations
 */
interface IDefaultsUpgradeable {
    // Initialization
    function initialize() external;

    // Token Management
    function nativeTokenIdentifier() external view returns (address);
    function setNativeToken(StructSupportedToken calldata token_) external;
    function setProjectToken(StructSupportedToken calldata token_) external;
    function setStableToken(StructSupportedToken calldata token_) external;
    function getSupportedTokenByAddress(
        address token_
    ) external view returns (StructSupportedToken memory);

    // Investment Plan Management
    function getInvestmentPlanById(
        InvestmentType investmentType_,
        uint256 id_
    ) external view returns (StructInvestmentPlan memory);

    function setInvestmentPlan(
        InvestmentType investmentType_,
        uint256 planId_,
        StructInvestmentPlan calldata plan_
    ) external;

    // Liquidity and Swap Settings
    function setCreateLiquidityPer(
        InvestmentType investmentType_,
        StructPerWithDivision calldata per_
    ) external;

    function setSwapPer(
        InvestmentType investmentType_,
        StructPerWithDivision calldata per_
    ) external;

    // Contract Management
    function getContractById(
        ContractType contractType_
    ) external view returns (address);
    function getImplementationById(
        ContractType contractType_
    ) external view returns (address);
    function setImplementationById(
        ContractType contractType_,
        address implementation_
    ) external;
    function updateContracts(
        address contract_,
        ContractType contractType_
    ) external;

    // Referral System
    function setReferralRates(
        InvestmentType investmentType_,
        uint256[] calldata referralRates_
    ) external;
    function setCalLevelsLimit(
        InvestmentType investmentType_,
        uint256 calLevelsLimit_
    ) external;
    function setDefaultReferrer(address user_) external;

    // Fees Management
    function setPreUnStakeFees(
        InvestmentType investmentType_,
        uint256[] calldata preUnStakeFees_
    ) external;
    function setClaimFees(
        InvestmentType investmentType_,
        uint256[] calldata claimFees_
    ) external;
    function setInactiveUserFees(uint256 inactiveUserFees_) external;

    // Reward System
    function setRewardObjectDefaults(
        InvestmentType investmentType_,
        RewardType rewardType_,
        uint256 id_,
        StructRewardObjectDefaults calldata rewardObject_
    ) external;

    // Access Control
    function isAdmin(address userAddress_) external view returns (bool);
    function setProvider(
        address provider_,
        InvestmentType investmentType_
    ) external;
    function setBeneficiary(
        address beneficiary_,
        InvestmentType investmentType_
    ) external;

    // CustomSwapRouter Managemen
    function getCustomSwapRouter() external view returns (ICustomSwapRouter);

    // View Functions
    function getDefaults(
        InvestmentType investmentType_
    ) external view returns (StructDefaultsReturn memory defaultsReturn);
}

/**
 * @title IRegistrationUpgradeable
 * @dev Interface for the RegistrationUpgradeable contract managing user registrations
 */
interface IRegistrationUpgradeable {
    function getUserAccount(
        address user_,
        InvestmentType investmentType_
    ) external view returns (StructUserAccountReturn memory userAccountReturn);

    function checkInactiveFeesDeduction(
        address user_,
        uint256 value_,
        StructPerWithDivision memory inactiveUserFees_
    )
        external
        view
        returns (bool isFeesDeducted, uint256 valueAfterFees, uint256 fees);

    function getSubscriptionStatus(
        address user_
    )
        external
        view
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256 timeRemaining,
            bool isActive
        );
}

/**
 * @title IRewardsUpgradeable
 * @dev Interface for the RewardsUpgradeable contract managing reward distributions
 */
interface IRewardsUpgradeable {
    function updateUserClubRewardId(
        address user_
    ) external returns (uint256 clubIdUpdated);

    function distributeClubRewards(
        uint256 valueInUSD_,
        InvestmentType investmentType_,
        address token_,
        uint256 valueInWei_
    ) external payable returns (uint256 rewardDistributed);

    function getTokenValueToDistributeClubReward(
        uint256 valueInUSD_,
        InvestmentType investmentType_,
        address token_
    ) external view returns (uint256 rewardDistributed, uint256 tokenValue);

    function claimPendingClubRewardSubscription(
        address user_,
        address token_
    ) external returns (uint256 rewardInUSD);
}

interface ICustomSwapRouter {
    function swapETHForTokens(
        IUniswapV2Router02 IUniswapV2Router_,
        address tokenAddress_,
        address receiver_
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForETH(
        IUniswapV2Router02 IUniswapV2Router_,
        address tokenAddress_,
        uint256 valueInWei_,
        address receiver_
    ) external returns (uint256[] memory amounts);

    function createLiquidityETH(
        IUniswapV2Router02 IUniswapV2Router_,
        uint256 ethValue_,
        address tokenAddress_,
        uint256 tokenAmount_,
        address lpReceiver_
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);

    function amountOutUniswapV2ReserveInWei(
        IUniswapV2Router02 uniswapV2Router_,
        address token0_,
        uint256 valueInWei_,
        address token1_
    ) external view returns (uint256 token1Value);
}

/**
 * @title IInvest
 * @dev Interface for the Invest contract managing investments
 */
interface IInvest {
    function invest(
        address user_,
        address token_,
        uint256 valueInWei_
    ) external payable returns (uint256 currentInvestmentId);
}
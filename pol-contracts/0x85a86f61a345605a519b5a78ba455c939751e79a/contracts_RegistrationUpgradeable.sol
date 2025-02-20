// Compatible with OpenZeppelin Contracts ^5.0.0
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./contracts_Structs.sol";
import "./contracts_CommonEventsAndErrors.sol";
import "./contracts_Interfaces.sol";
import "./contracts_EventsRegistration.sol";
import "./contracts_UtilFunctions.sol";
import "./contracts_Storage.sol";

contract RegistrationUpgradeable is
    Storage,
    UtilFunctions,
    Initializable,
    PausableUpgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    receive() external payable {}
    fallback() external payable {}

    // function initialize(
    //     address defaultsContract_,
    //     address beneficiary_
    // ) public initializer {
    //     address msgSender = msg.sender;

    //     __Ownable_init(msgSender);
    //     __Ownable2Step_init();
    //     __UUPSUpgradeable_init();

    //     StructAnalytics storage analytics = _analytics;

    //     analytics.defaultsContract = defaultsContract_;
    //     emit DefaultsContractUpdated(defaultsContract_);

    //     StructUserAccount storage beneficiaryAccount = analytics.userAccount[
    //         beneficiary_
    //     ];

    //     beneficiaryAccount.subscriptionStartTime[
    //         InvestmentType.subscription
    //     ] = block.timestamp;

    //     beneficiaryAccount.subscriptionDuration[
    //         InvestmentType.subscription
    //     ] = 1000000000 days;
    //     beneficiaryAccount.user = beneficiary_;

    //     StructUserAccount storage providerAccount = analytics.userAccount[
    //         msgSender
    //     ];

    //     providerAccount.subscriptionStartTime[
    //         InvestmentType.subscription
    //     ] = block.timestamp;
    //     providerAccount.subscriptionDuration[
    //         InvestmentType.subscription
    //     ] = 1000000000 days;
    //     providerAccount.user = msgSender;
    //     providerAccount.referrer = beneficiary_;
    // }

    modifier onlyAdmin() {
        IDefaultsUpgradeable iDefaults = IDefaultsUpgradeable(
            _analytics.defaultsContract
        );

        if (!iDefaults.isAdmin(msg.sender))
            revert CommonError("Only admin can call this function");
        _;
    }

    // function updateDefaultsContract(
    //     address defaultsContractAddress_
    // ) external onlyAdmin {
    //     _analytics.defaultsContract = defaultsContractAddress_;
    //     emit DefaultsContractUpdated(defaultsContractAddress_);
    // }

    function _addReferrer(
        StructUserAccount storage userAccount_,
        StructUserAccount storage referrerAccount_,
        StructAnalytics storage analytics_,
        uint256 referralRatesLength_
    ) private returns (bool isReferrerAdded) {
        if (userAccount_.referrer != address(0)) {
            emit CommonEvent("Referrer is already added.");
            return false;
        }

        if (referrerAccount_.user == address(0)) {
            emit CommonEvent("Referrer address is zero.");
            return false;
        }

        if (userAccount_.user == referrerAccount_.user)
            revert CommonError("Referrer and user cannot be same.");

        if (userAccount_.user == referrerAccount_.referrer)
            revert CommonError("Referee cannot be referrer upline");

        userAccount_.referrer = referrerAccount_.user;
        referrerAccount_.referees.push(userAccount_.user);
        referrerAccount_.teams.push(StructTeam(userAccount_.user, 1));

        emit ReferrerAdded(referrerAccount_.user, userAccount_.user);

        StructUserAccount storage parentAccount = analytics_.userAccount[
            referrerAccount_.referrer
        ];

        for (uint256 i = 1; i < referralRatesLength_; i++) {
            if (parentAccount.user == address(0)) {
                break;
            }

            parentAccount.teams.push(StructTeam(userAccount_.user, i + 1));
            emit TeamAdded(parentAccount.user, userAccount_.user);

            parentAccount = analytics_.userAccount[parentAccount.referrer];
        }
    }

    // function addReferrer(
    //     address[] memory referrer_,
    //     address[] memory user_
    // ) external onlyAdmin {
    //     StructAnalytics storage analytics = _analytics;
    //     IDefaultsUpgradeable iDefaults = IDefaultsUpgradeable(
    //         analytics.defaultsContract
    //     );

    //     if (referrer_.length != user_.length)
    //         revert CommonError(
    //             "Array length mismatch. Please double check the array length"
    //         );

    //     for (uint256 i; i < user_.length; i++) {
    //         if (referrer_[i] == address(0))
    //             revert CommonError("Invalid referrer address");

    //         if (user_[i] == address(0))
    //             revert CommonError("Invalid user address");

    //         StructUserAccount storage referrerAccount = analytics.userAccount[
    //             referrer_[i]
    //         ];

    //         if (referrerAccount.user == address(0))
    //             _updateUser(referrerAccount, referrer_[i], analytics);

    //         StructUserAccount storage userAccount = analytics.userAccount[
    //             user_[i]
    //         ];

    //         if (userAccount.user == address(0))
    //             _updateUser(userAccount, user_[i], analytics);

    //         _addReferrer(
    //             userAccount,
    //             referrerAccount,
    //             analytics,
    //             iDefaults
    //                 .getDefaults(InvestmentType.subscription)
    //                 .referralRates
    //                 .length
    //         );
    //     }
    // }

    function _updateBusiness(
        StructUserAccount storage userAccount_,
        StructUserInvestments memory userInvestment_,
        StructAnalytics storage analytics_,
        uint256 calLevelLimits_
    ) private returns (uint256 businessUpdated) {
        if (userInvestment_.valueInUSD == 0) {
            emit CommonEvent("Business not updated. Invested value is zero");
        }

        uint256 valueInUSD = userInvestment_.valueInUSD;
        InvestmentType investmentType = userInvestment_
            .investmentPlan
            .investmentType;

        userAccount_.business[investmentType].totalBusinessByType[
            BusinessType.self
        ] += valueInUSD;

        emit BusinessUpdated(
            userAccount_.referrer,
            BusinessType.self,
            valueInUSD,
            0
        );

        userAccount_.investedWithTokens[investmentType][
            userInvestment_.tokenAccount.contractAddress
        ] += userInvestment_.tokenValueInWei;

        if (userAccount_.referrer == address(0)) {
            return 0;
        }

        StructUserAccount storage referrerAccount = analytics_.userAccount[
            userAccount_.referrer
        ];

        referrerAccount.business[investmentType].totalBusinessByType[
            BusinessType.direct
        ] += valueInUSD;

        emit BusinessUpdated(
            referrerAccount.user,
            BusinessType.direct,
            valueInUSD,
            1
        );

        for (uint256 i; i < calLevelLimits_; i++) {
            if (referrerAccount.user == address(0)) {
                break;
            }

            referrerAccount.business[investmentType].totalBusinessByType[
                BusinessType.team
            ] += valueInUSD;

            referrerAccount.business[investmentType].teamBusinessTypeCount++;

            emit BusinessUpdated(
                referrerAccount.user,
                BusinessType.team,
                valueInUSD,
                i + 1
            );

            referrerAccount = analytics_.userAccount[referrerAccount.referrer];
        }
    }

    /// @notice Distributes referral rewards to upline users
    /// @param userAccount_ User account struct of the investor
    /// @param investAccount_ Investment details struct
    /// @param analytics_ Analytics struct for tracking
    /// @param defaults_ Default contract settings
    /// @param transfers_ Whether to process token transfers
    /// @return referralDistributedInUSD Total USD value of distributed referral rewards
    function _payReferral(
        StructUserAccount storage userAccount_,
        StructUserInvestments memory investAccount_,
        StructAnalytics storage analytics_,
        StructDefaultsReturn memory defaults_,
        uint256 valueInWei_,
        bool transfers_
    ) private returns (uint256 referralDistributedInUSD) {
        // Early return if no referrer
        if (userAccount_.referrer == address(0)) {
            emit CommonEvent("Referral not distributed, no upline");
            return 0;
        }

        // Get referral rates
        StructReferralRates[] memory referralRates = defaults_.referralRates;
        uint256 referralLength = referralRates.length;

        // Track current referrer for upline traversal
        StructUserAccount storage referrerAccount = analytics_.userAccount[
            userAccount_.referrer
        ];

        // Process each level of referral
        for (uint256 i; i < referralLength; i++) {
            // Validate referrer account
            if (referrerAccount.user == address(0)) {
                emit ReferralNotPaid(
                    referrerAccount.user,
                    userAccount_.user,
                    i + 1,
                    "Referrer account does not exist",
                    investAccount_.investmentPlan.investmentType
                );

                break;
            }

            // Get referral rate for current level
            StructReferralRates memory referralRate = referralRates[i];

            uint256 rewardInWei = (valueInWei_ *
                referralRate.referralRate.per) /
                referralRate.referralRate.division;
            // Calculate reward
            uint256 rewardValue = (investAccount_.valueInUSD *
                referralRate.referralRate.per) /
                referralRate.referralRate.division;

            if (
                rewardValue == 0 ||
                rewardInWei == 0 ||
                rewardInWei > valueInWei_
            ) {
                return 0;
            }

            if (transfers_) {
                _transferFunds(
                    investAccount_.tokenAccount,
                    referrerAccount.user,
                    rewardInWei
                );

                // Need to update rewardClaimedInTokens mapping
                referrerAccount.rewardClaimedInTokens[
                    investAccount_.investmentPlan.investmentType
                ][
                        address(investAccount_.tokenAccount.contractAddress)
                    ] += rewardInWei;
            }

            // Update referrer's pending rewards
            referrerAccount.rewardsClaimed[
                investAccount_.investmentPlan.investmentType
            ][RewardType.referral] += rewardValue;

            // Update analytics
            analytics_.rewardsDistributed[
                investAccount_.investmentPlan.investmentType
            ][RewardType.referral] += rewardValue;

            emit ReferralPaid(
                referrerAccount.user,
                userAccount_.user,
                i + 1,
                address(investAccount_.tokenAccount.contractAddress),
                rewardInWei,
                rewardValue,
                investAccount_.investmentPlan.investmentType
            );

            referralDistributedInUSD += rewardValue;

            // Move to next upline referrer
            referrerAccount = analytics_.userAccount[referrerAccount.referrer];
        }

        return referralDistributedInUSD;
    }

    function _createLiquidityAndReBuyV2(
        StructDefaultsReturn memory defaultsReturn_,
        IUniswapV2Router02 uniswapV2Router_,
        address lpReceiver_,
        address swappedTokenReceiver_,
        uint256 currentTime_
    ) private returns (bool) {
        uint256 nativeValueInWei_ = address(this).balance;

        if (nativeValueInWei_ == 0) {
            emit CommonEvent("Liquidity not created as Native value is zero.");
            return false;
        }

        StructPerWithDivision memory createLiquidityPer_ = defaultsReturn_
            .createLiquidityPer;

        // IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);
        address weth = uniswapV2Router_.WETH();

        if (weth == address(0)) {
            revert CommonError("UniswapV2Router weth is invalid");
        }

        IUniswapV2Factory factory = IUniswapV2Factory(
            uniswapV2Router_.factory()
        );

        address pairAddress = factory.getPair(
            weth,
            defaultsReturn_.projectToken.contractAddress
        );

        bool isPairExists = pairAddress != address(0);

        uint256 reserve0;
        uint256 reserve1;
        bool isReserveExists = false;

        if (isPairExists) {
            IUniswapV2Pair pair = IUniswapV2Pair(pairAddress);
            (reserve0, reserve1, ) = pair.getReserves();

            address token0 = pair.token0();
            if (token0 != weth) {
                (reserve0, reserve1) = (reserve1, reserve0);
            }

            isReserveExists = reserve0 > 0 && reserve1 > 0;
        }

        address projectToken = defaultsReturn_.projectToken.contractAddress;
        uint256 projectTokenBalance = IERC20_EXT(projectToken).balanceOf(
            address(this)
        );

        uint256 deadline = currentTime_ + 60;

        // Calculate liquidity amount if percentage is greater than 0
        if (createLiquidityPer_.per > 0) {
            uint256 liquidityAmount = (nativeValueInWei_ *
                createLiquidityPer_.per) / createLiquidityPer_.division;

            if (liquidityAmount == 0) {
                emit CommonEvent("liquidityAmount is zero.");

                return false;
            }

            uint256 tokenValue;

            if (!isPairExists || !isReserveExists) {
                uint256 ethPrice = _getPriceInUSD(
                    IChainLinkV3Aggregator(
                        defaultsReturn_.nativeToken.chainLinkAggregatorV3Address
                    )
                );

                tokenValue =
                    (liquidityAmount * ethPrice) /
                    defaultsReturn_.initialUsdValueOfProjectToken;

                if (projectTokenBalance < tokenValue) {
                    emit CommonEvent(
                        "projectTokenBalance is less than liquidity creation value"
                    );

                    return false;
                }

                IERC20_EXT(projectToken).approve(
                    address(uniswapV2Router_),
                    _weiToTokens(
                        tokenValue,
                        defaultsReturn_.projectToken.decimals
                    )
                );

                uniswapV2Router_.addLiquidityETH{value: liquidityAmount}(
                    projectToken,
                    _weiToTokens(
                        tokenValue,
                        defaultsReturn_.projectToken.decimals
                    ),
                    0,
                    0,
                    lpReceiver_,
                    deadline
                );
            } else {
                // If the pair exists and reserves are available
                if (reserve0 == 0) {
                    revert CommonError(
                        "Cannot calculate token value: zero reserve0"
                    );
                    // return false;
                }

                // Calculate with overflow checking and better precision
                tokenValue = (reserve1 * liquidityAmount) / reserve0;

                if (tokenValue == 0) {
                    revert CommonError("Calculated token value is zero");
                    // return false;
                }

                if (projectTokenBalance < tokenValue) {
                    revert CommonError(
                        "projectTokenBalance is less than liquidity creation value. reserve already there"
                    );
                    // return false;
                }

                IERC20_EXT(projectToken).approve(
                    address(uniswapV2Router_),
                    _weiToTokens(
                        tokenValue,
                        defaultsReturn_.projectToken.decimals
                    )
                );

                uniswapV2Router_.addLiquidityETH{value: liquidityAmount}(
                    projectToken,
                    _weiToTokens(
                        tokenValue,
                        defaultsReturn_.projectToken.decimals
                    ),
                    0,
                    0,
                    lpReceiver_,
                    deadline
                );
            }
        }

        // Calculate swap amount if percentage is greater than 0

        StructPerWithDivision memory swapPer_ = defaultsReturn_.swapPer;
        if (swapPer_.per > 0 && isPairExists && isReserveExists) {
            uint256 swapAmount = (nativeValueInWei_ * swapPer_.per) /
                swapPer_.division;

            if (swapAmount == 0) {
                revert CommonError("Swap amount is zero.");
                // return false;
            }

            address[] memory path = new address[](2);
            path[0] = weth;
            path[1] = projectToken;

            try
                uniswapV2Router_
                    .swapExactETHForTokensSupportingFeeOnTransferTokens{
                    value: swapAmount
                }(
                    0, // Min output amount (we're already checking reserves)
                    path,
                    swappedTokenReceiver_,
                    deadline
                )
            {
                // Swap successful
            } catch Error(string memory reason) {
                emit CommonEvent(string.concat("Swap failed: ", reason));
                return false;
            } catch {
                emit CommonEvent("Swap failed with unknown error");
                return false;
            }
        }
    }

    /// @notice Process an investment for a user with optional referral
    /// @param user_ Address of the investing user
    /// @param referrer_ Address of the referrer (optional)
    /// @param token_ Token address being invested
    /// @param valueInWei_ Investment amount in wei
    /// @param planId_ ID of the investment plan
    /// @param investmentType_ Type of investment (subscription/investment)
    /// @param transfers_ Whether to process token transfers
    /// @dev Emits InvestmentProcessed and related reward events on success

    function _invest(
        address user_,
        address referrer_,
        address token_,
        uint256 valueInWei_,
        uint256 planId_,
        InvestmentType investmentType_,
        bool transfers_
    ) private {
        require(valueInWei_ > 0, "Investment amount must be greater than 0");
        require(token_ != address(0), "Token address cannot be zero");
        uint256 currentTime = block.timestamp;
        address addressThis = address(this);

        if (user_ == address(0)) {
            revert CommonError("UserAddress is invalid");
        }

        StructAnalytics storage analytics = _analytics;
        IDefaultsUpgradeable iDefaults = IDefaultsUpgradeable(
            analytics.defaultsContract
        );

        StructDefaultsReturn memory defaultsReturn = iDefaults.getDefaults(
            investmentType_
        );

        StructSupportedToken memory tokenAccount = iDefaults
            .getSupportedTokenByAddress(token_);

        if (!tokenAccount.isActive)
            revert CommonError("Token is not active or supported");

        StructInvestmentPlan memory investmentPlan = iDefaults
            .getInvestmentPlanById(investmentType_, planId_);

        if (investmentPlan.id == 0)
            revert CommonError("Invalid investment plan");

        StructUserAccount storage userAccount = analytics.userAccount[user_];

        (, , , bool isSubscriptionActive) = _getSubscriptionStatus(
            userAccount.subscriptionStartTime[InvestmentType.subscription],
            userAccount.subscriptionDuration[InvestmentType.subscription],
            currentTime
        );

        if (!investmentPlan.requireSubscription && isSubscriptionActive) {
            revert CommonError("Investment: Subscription already active");
        }

        if (investmentPlan.requireSubscription && !isSubscriptionActive) {
            revert CommonError("Investment: Active subscription required");
        }

        _updateUser(userAccount, user_, analytics);

        if (referrer_ == address(0)) {
            referrer_ = defaultsReturn.beneficiary.adminAddress;
        }

        require(referrer_ != user_, "Cannot refer yourself");

        StructUserAccount storage referrerAccount = analytics.userAccount[
            referrer_
        ];

        if (referrerAccount.user == address(0)) {
            _updateUser(referrerAccount, referrer_, analytics);
        }

        (, , , bool isReferrerSubscriptionActive) = _getSubscriptionStatus(
            referrerAccount.subscriptionStartTime[InvestmentType.subscription],
            referrerAccount.subscriptionDuration[InvestmentType.subscription],
            currentTime
        );

        if (!isReferrerSubscriptionActive)
            revert CommonError("Referrer is not active");

        if (transfers_) {
            _proceedTransferFrom(tokenAccount, valueInWei_);
            if (
                defaultsReturn
                    .beneficiary
                    .transferPer[uint256(investmentType_)]
                    .transferPer
                    .per > 0
            ) {
                uint256 beneficiaryReward = (valueInWei_ *
                    defaultsReturn
                        .beneficiary
                        .transferPer[uint256(investmentType_)]
                        .transferPer
                        .per) /
                    defaultsReturn
                        .beneficiary
                        .transferPer[uint256(investmentType_)]
                        .transferPer
                        .division;

                _transferFunds(
                    tokenAccount,
                    defaultsReturn.beneficiary.adminAddress,
                    beneficiaryReward
                );

                // Need to update rewardClaimedInTokens mapping
                emit BeneficiaryRewardPaid(
                    defaultsReturn.beneficiary.adminAddress,
                    token_,
                    beneficiaryReward
                );
            }
        }

        uint256 valueInUSD = _tokensToUSD(
            IChainLinkV3Aggregator(tokenAccount.chainLinkAggregatorV3Address),
            valueInWei_
        );

        if (investmentPlan.fixedValueInUSD > 0) {
            if (valueInUSD < ((investmentPlan.fixedValueInUSD * 97) / 100))
                revert CommonError("Value less than plan value");
            else if (valueInUSD > (investmentPlan.fixedValueInUSD * 103) / 100)
                revert CommonError("Value greater than plan value");
        }

        if (investmentPlan.minContribution > 0) {
            if (((valueInUSD * 102) / 100) < investmentPlan.minContribution)
                revert CommonError("Value less than min contribution");
        }

        if (investmentType_ == InvestmentType.subscription) {
            userAccount.subscriptionStartTime[
                InvestmentType.subscription
            ] = currentTime;

            userAccount.subscriptionDuration[
                InvestmentType.subscription
            ] = investmentPlan.duration;
        }

        uint256 investmentsLength = analytics.investmentsArray.length;

        userAccount.investments[investmentType_].push();
        uint256 userInvestmentsLength = userAccount
            .investments[investmentType_]
            .length;

        StructUserInvestments storage userInvestments = userAccount.investments[
            investmentType_
        ][userInvestmentsLength - 1];

        userInvestments.id = investmentsLength;
        userInvestments.user = user_;
        userInvestments.investmentPlan = investmentPlan;
        userInvestments.tokenAccount = tokenAccount;
        userInvestments.valueInUSD = valueInUSD;
        userInvestments.timestamp = currentTime;

        analytics.investmentsArray.push(userInvestments);

        _addReferrer(
            userAccount,
            referrerAccount,
            analytics,
            defaultsReturn.referralRates.length
        );

        _updateBusiness(
            userAccount,
            userInvestments,
            analytics,
            defaultsReturn.calLevelsLimit
        );

        if (investmentPlan.isPayReferral) {
            _payReferral(
                userAccount,
                userInvestments,
                analytics,
                defaultsReturn,
                valueInWei_,
                transfers_
            );
        }

        analytics.totalBusiness[InvestmentType.subscription] += valueInUSD;
        analytics.tokensCollected[InvestmentType.subscription][
            token_
        ] += valueInWei_;

        if (transfers_) {
            IUniswapV2Router02 iuniswapV2 = IUniswapV2Router02(
                defaultsReturn.contracts[uint256(ContractType.uniswapV2Router)]
            );

            if (!tokenAccount.isNative) {
                uint256 balanceThisBalance = IERC20_EXT(
                    tokenAccount.contractAddress
                ).balanceOf(addressThis);

                address[] memory path = new address[](2);
                path[0] = token_;
                path[1] = iuniswapV2.WETH();

                IERC20_EXT(tokenAccount.contractAddress).approve(
                    address(iuniswapV2),
                    balanceThisBalance
                );

                iuniswapV2.swapExactTokensForETH(
                    balanceThisBalance,
                    0,
                    path,
                    addressThis,
                    currentTime + 300
                );
            }

            _createLiquidityAndReBuyV2(
                defaultsReturn,
                iuniswapV2,
                addressThis,
                addressThis,
                currentTime
            );
        }

        uint256 balanceThis;

        if (tokenAccount.isNative) {
            balanceThis = addressThis.balance;
        } else {
            balanceThis = IERC20_EXT(tokenAccount.contractAddress).balanceOf(
                addressThis
            );
        }

        if (balanceThis > 0) {
            _transferFunds(
                tokenAccount,
                defaultsReturn.beneficiary.adminAddress,
                balanceThis
            );
        }

        emit Invested(userInvestments);
    }

    function investAdmin(
        address user_,
        address referrer_,
        address token_,
        uint256 valueInWei_,
        uint256 planId_,
        InvestmentType investmentType_,
        bool transfer_
    ) external payable onlyAdmin nonReentrant {
        _invest(
            user_,
            referrer_,
            token_,
            valueInWei_,
            planId_,
            investmentType_,
            transfer_
        );
    }

    function invest(
        address user_,
        address referrer_,
        address token_,
        uint256 valueInWei_,
        uint256 planId_,
        InvestmentType investmentType_
    ) external payable nonReentrant {
        _invest(
            user_,
            referrer_,
            token_,
            valueInWei_,
            planId_,
            investmentType_,
            true
        );
    }

    // function _addCalReward(
    //     uint256 userBusiness_,
    //     StructAnalytics storage analytics_,
    //     StructUserInvestments storage investAccount_
    // ) private returns (uint256 userCallReward) {
    //     StructCalRewardWithBusiness memory calReward = analytics_.calReward[
    //         investAccount_.investmentPlan.investmentType
    //     ];

    //     if (calReward.reward == 0) {
    //         emit CommonEvent("CalReward not added. Check calReward.");
    //         return 0;
    //     }

    //     if (calReward.business == 0) {
    //         emit CommonEvent("CalReward not added. Check calBusiness");
    //         return 0;
    //     }

    //     userCallReward =
    //         (calReward.reward * userBusiness_) /
    //         calReward.business;

    //     investAccount_.calRewardClaimed += userCallReward;

    //     emit CalRewardUpdated(userCallReward, investAccount_.user);
    // }

    // function distributeInvestmentReward(
    //     address token_,
    //     uint256 valueInWei_
    // ) external {
    //     StructAnalytics storage analytics = _analytics;

    //     analytics.calReward[InvestmentType.investment].reward += valueInWei_;
    //     analytics.calReward[InvestmentType.investment].business = analytics
    //         .totalBusiness[InvestmentType.investment];

    //     emit InvestmentRewardDistributed(token_, valueInWei_);
    // }

    // function _getInvestmentRewardByInvestAccount(
    //     StructUserInvestments memory investAccount_,
    //     StructCalRewardWithBusiness storage calReward_
    // ) private view returns (uint256 investmentReward) {
    //     if (investAccount_.investmentPlan.isActive) {
    //         investmentReward =
    //             (calReward_.reward * investAccount_.valueInUSD) /
    //             calReward_.business;
    //         investmentReward -=
    //             investAccount_.rewardClaimed +
    //             investAccount_.calRewardClaimed;
    //     }
    // }

    // function getUserInvestmentReward(
    //     address user_,
    //     InvestmentType investmentType_
    // ) external view returns (uint256 totalInvestmentReward) {
    //     StructAnalytics storage analytics = _analytics;
    //     StructUserAccount storage userAccount = analytics.userAccount[user_];

    //     StructUserInvestments[] memory userInvestments = userAccount
    //         .investments[investmentType_];

    //     uint256 userInvestLength = userInvestments.length;

    //     if (userInvestLength == 0) return 0;

    //     StructCalRewardWithBusiness storage calReward = analytics.calReward[
    //         investmentType_
    //     ];

    //     if (calReward.reward == 0 || calReward.business == 0) return 0;

    //     for (uint256 i; i < userInvestLength; i++) {
    //         StructUserInvestments memory investAccount = userInvestments[i];

    //         if (investAccount.investmentPlan.duration > 0) {
    //             uint256 endTime = investAccount.timestamp +
    //                 investAccount.investmentPlan.duration;
    //             if (block.timestamp > endTime) continue;
    //         }

    //         totalInvestmentReward += _getInvestmentRewardByInvestAccount(
    //             investAccount,
    //             calReward
    //         );
    //     }
    // }

    // function claimInvestmentReward(address user_) external {}

    // function getUsersRewards(
    //     address user_,
    //     InvestmentType investmentType_,
    //     RewardType rewardType_
    // ) external view returns (uint256) {
    //     StructUserAccount storage userAccount = _analytics.userAccount[user_];
    //     return userAccount.rewardsClaimed[investmentType_][rewardType_];
    // }

    function _swapFromLiquidity(
        StructDefaultsReturn memory defaultsReturn_,
        uint256 valueInUSD_,
        address tokenReceivedOut_,
        address to_
    ) private returns (uint256[] memory amountsOut) {
        if (valueInUSD_ == 0) {
            revert CommonError("valueInUSD is zero");
        }

        if (tokenReceivedOut_ == address(0)) {
            revert CommonError("tokenReceivedOut is zero");
        }

        if (to_ == address(0)) {
            revert CommonError("to is zero");
        }

        uint256 usdToNative = _usdToTokens(
            valueInUSD_,
            defaultsReturn_.nativeToken
        );

        IUniswapV2Router02 iuniswapV2 = IUniswapV2Router02(
            defaultsReturn_.contracts[uint256(ContractType.uniswapV2Router)]
        );

        address[] memory path = new address[](2);

        path[0] = defaultsReturn_.projectToken.contractAddress;
        path[1] = iuniswapV2.WETH();

        amountsOut = iuniswapV2.getAmountsIn(usdToNative, path);

        uint256 projectTokensRequired = amountsOut[0];

        IERC20_EXT ierc20ProjectToken = IERC20_EXT(
            defaultsReturn_.projectToken.contractAddress
        );

        uint256 projectTokenBalanceThis = IERC20_EXT(
            defaultsReturn_.projectToken.contractAddress
        ).balanceOf(address(this));

        if (projectTokenBalanceThis < projectTokensRequired) {
            revert CommonError(
                "projectTokenBalanceThis is less than projectTokensRequired."
            );
        }

        ierc20ProjectToken.approve(address(iuniswapV2), projectTokensRequired);

        uint256 deadline = block.timestamp + 30;

        if (tokenReceivedOut_ == defaultsReturn_.nativeToken.contractAddress) {
            amountsOut = iuniswapV2.swapExactTokensForETH(
                projectTokensRequired,
                0,
                path,
                to_,
                deadline
            );

            if (amountsOut[1] == 0)
                revert CommonError("Project token to eth swap failed.");
        } else {
            amountsOut = iuniswapV2.swapExactTokensForETH(
                projectTokensRequired,
                0,
                path,
                address(this),
                deadline
            );

            if (amountsOut[1] == 0)
                revert CommonError("Project token to eth swap failed.");

            path[0] = iuniswapV2.WETH();
            path[1] = tokenReceivedOut_;

            amountsOut = iuniswapV2.swapExactETHForTokens{value: amountsOut[1]}(
                0,
                path,
                to_,
                deadline
            );

            if (amountsOut[1] == 0)
                revert CommonError("Eth to provided token swap failed.");
        }
    }

    function _getInvestmentInterestByInvestAccount(
        StructUserInvestments memory investAccount_
    ) private view returns (uint256 investmentInterest) {
        if (!investAccount_.investmentPlan.isActive) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - investAccount_.timestamp;

        investmentInterest =
            (timeElapsed *
                investAccount_.valueInUSD *
                investAccount_.investmentPlan.perApy.per) /
            (investAccount_.investmentPlan.perApy.division * 365 * 86400);

        investmentInterest -= investAccount_.rewardClaimed;
    }

    function _claimInterestByInvestmentAccount(
        StructUserInvestments storage investAccount_,
        address token_
    ) private returns (uint256 pendingReward) {
        if (token_ == address(0))
            revert CommonError("Invalid or unsupported Token address.");

        address user = investAccount_.user;

        if (
            investAccount_.investmentPlan.duration == 0 ||
            investAccount_.investmentPlan.perApy.per == 0 ||
            investAccount_.valueInUSD == 0 ||
            user == address(0)
        ) {
            revert CommonError("Invalid investment plan.");
        }

        pendingReward = _getInvestmentInterestByInvestAccount(investAccount_);

        if (pendingReward == 0) {
            revert CommonError("No interest to claim");
        }

        investAccount_.rewardClaimed += pendingReward;
        emit InvestmentInterestDistributed(investAccount_.id, pendingReward);

        StructAnalytics storage analytics = _analytics;
        StructUserAccount storage userAccount = analytics.userAccount[user];

        IDefaultsUpgradeable iDefaults = IDefaultsUpgradeable(
            analytics.defaultsContract
        );

        StructDefaultsReturn memory defaultsReturn = iDefaults.getDefaults(
            investAccount_.investmentPlan.investmentType
        );

        StructSupportedToken memory tokenAccount = iDefaults
            .getSupportedTokenByAddress(token_);

        if (!tokenAccount.isActive) {
            revert CommonError("Token is not active.");
        }

        uint256[] memory amountsOut = _swapFromLiquidity(
            defaultsReturn,
            pendingReward,
            token_,
            user
        );

        userAccount.rewardsClaimed[
            investAccount_.investmentPlan.investmentType
        ][RewardType.investmentROI] += pendingReward;

        userAccount.rewardClaimedInTokens[
            investAccount_.investmentPlan.investmentType
        ][token_] += _tokensToWei(amountsOut[1], tokenAccount.decimals);

        analytics.rewardsDistributed[
            investAccount_.investmentPlan.investmentType
        ][RewardType.investmentROI] += pendingReward;

        analytics.rewardDistributedInTokens[
            investAccount_.investmentPlan.investmentType
        ][token_] += _tokensToWei(amountsOut[1], tokenAccount.decimals);
    }

    function claimInvestmentInterestById(
        address user_,
        InvestmentType investmentType_,
        uint256 investmentIdIndex_,
        address token_
    ) external nonReentrant returns (uint256 rewardClaimed) {
        if (user_ == address(0)) revert CommonError("Invalid User address.");
        if (token_ == address(0))
            revert CommonError("Invalid or unsupported Token address.");

        StructAnalytics storage analytics = _analytics;
        StructUserInvestments storage investmentAccount = analytics
            .userAccount[user_]
            .investments[investmentType_][investmentIdIndex_];

        if (investmentAccount.valueInUSD == 0)
            revert CommonError("Invalid Investment value.");

        rewardClaimed = _claimInterestByInvestmentAccount(
            investmentAccount,
            token_
        );
    }

    function _withdrawInvestmentById(
        uint256 investmentIdIndex_,
        address token_
    ) private returns (uint256 totalValueToTransfer) {
        if (token_ == address(0))
            revert CommonError("Invalid or unsupported Token address.");
        address msgSender = msg.sender;
        uint256 currentTime = block.timestamp;

        StructAnalytics storage analytics = _analytics;
        StructUserAccount storage userAccount = analytics.userAccount[
            msgSender
        ];

        StructUserInvestments storage investAccount = userAccount.investments[
            InvestmentType.investment
        ][investmentIdIndex_];

        if (!investAccount.investmentPlan.isActive) {
            revert CommonError("Investment is not active.");
        }
        if (investAccount.user == address(0))
            revert CommonError("Invalid Investment Owner address.");
        if (investAccount.valueInUSD == 0)
            revert CommonError("Invalid Investment value.");

        uint256 pendingReward = _claimInterestByInvestmentAccount(
            investAccount,
            token_
        );

        totalValueToTransfer = investAccount.valueInUSD;

        IDefaultsUpgradeable iDefaults = IDefaultsUpgradeable(
            analytics.defaultsContract
        );

        StructDefaultsReturn memory defaultsReturn = iDefaults.getDefaults(
            investAccount.investmentPlan.investmentType
        );

        uint256 investmentDuration = currentTime - investAccount.timestamp;

        StructFeesWithTimeline[] memory feesWithTimeline = defaultsReturn
            .preUnStakeFees;

        for (uint256 i; i < feesWithTimeline.length; i++) {
            StructFeesWithTimeline memory feeWithTimeline = feesWithTimeline[i];

            if (investmentDuration < feeWithTimeline.durationBefore) {
                uint256 fees = (totalValueToTransfer *
                    feeWithTimeline.feesPer.per) /
                    feeWithTimeline.feesPer.division;
                totalValueToTransfer -= fees;
                emit PreUnStakeFeedDeducted(investAccount.id, fees);
                break;
            }
        }

        if (totalValueToTransfer == 0)
            revert CommonError("No value to transfer");

        if (pendingReward > 0) {
            totalValueToTransfer += pendingReward;
        }

        StructSupportedToken memory tokenAccount = iDefaults
            .getSupportedTokenByAddress(token_);

        if (!tokenAccount.isActive) {
            revert CommonError("Token is not active.");
        }

        _swapFromLiquidity(
            defaultsReturn,
            totalValueToTransfer,
            token_,
            investAccount.user
        );

        investAccount.investmentPlan.isActive = false;
        emit InvestmentDisabled(investAccount.id);
    }

    function withdrawInvestmentById(
        uint256 investmentIdIndex_,
        address token_
    ) external nonReentrant returns (uint256 totalValueToTransfer) {
        totalValueToTransfer = _withdrawInvestmentById(
            investmentIdIndex_,
            token_
        );
    }

    function getUserAccount(
        address user_,
        InvestmentType investmentType_
    ) external view returns (StructUserAccountReturn memory userAccountReturn) {
        require(user_ != address(0), "Invalid user address");
        require(
            uint256(investmentType_) <= uint256(InvestmentType.investment),
            "Invalid investment type"
        );

        StructAnalytics storage analytics = _analytics;
        IDefaultsUpgradeable iDefaults = IDefaultsUpgradeable(
            analytics.defaultsContract
        );
        require(address(iDefaults) != address(0), "Defaults contract not set");

        StructDefaultsReturn memory defaultsReturn = iDefaults.getDefaults(
            investmentType_
        );

        StructUserAccount storage userAccount = analytics.userAccount[user_];

        // Return empty struct if user doesn't exist
        if (userAccount.user == address(0)) {
            return userAccountReturn;
        }

        // Basic user info
        userAccountReturn.user = userAccount.user;
        userAccountReturn.referrer = userAccount.referrer;
        userAccountReturn.referees = userAccount.referees;
        userAccountReturn.teams = userAccount.teams;

        // Business info
        userAccountReturn.business = StructBusinessReturn(
            userAccount.business[investmentType_].totalBusinessByType[
                BusinessType.self
            ],
            userAccount.business[investmentType_].totalBusinessByType[
                BusinessType.direct
            ],
            userAccount.business[investmentType_].totalBusinessByType[
                BusinessType.team
            ],
            userAccount.business[investmentType_].teamBusinessTypeCount,
            userAccount.business[investmentType_].calBusiness
        );

        // Rewards info
        uint256 rewardsLength = uint256(type(RewardType).max) + 1;
        uint256[] memory rewardWithValues = new uint256[](rewardsLength);
        uint256[] memory pendingRewardValues = new uint256[](rewardsLength);
        uint256[] memory rewardIds = new uint256[](rewardsLength);

        for (uint256 i; i < rewardsLength; i++) {
            rewardWithValues[i] = userAccount.rewardsClaimed[investmentType_][
                RewardType(i)
            ];
            pendingRewardValues[i] = userAccount.pendingRewards[
                investmentType_
            ][RewardType(i)];
            rewardIds[i] = userAccount.rewardId[investmentType_][RewardType(i)];
        }

        userAccountReturn.rewardsClaimed = rewardWithValues;
        userAccountReturn.pendingRewards = pendingRewardValues;
        userAccountReturn.rewardIds = rewardIds;

        // Token info
        uint256 supportedTokensLength = defaultsReturn
            .supportedTokensArray
            .length;
        StructTokenWithValue[]
            memory supportedTokensWithValue = new StructTokenWithValue[](
                supportedTokensLength
            );

        // Claimed tokens
        for (uint256 i; i < supportedTokensLength; i++) {
            address tokenAddr = defaultsReturn
                .supportedTokensArray[i]
                .contractAddress;
            supportedTokensWithValue[i] = StructTokenWithValue({
                tokenAddress: tokenAddr,
                tokenValue: userAccount.rewardClaimedInTokens[investmentType_][
                    tokenAddr
                ]
            });
        }
        userAccountReturn.rewardClaimedInTokens = supportedTokensWithValue;

        // Invested tokens
        StructTokenWithValue[]
            memory investedTokensWithValue = new StructTokenWithValue[](
                supportedTokensLength
            );
        for (uint256 i; i < supportedTokensLength; i++) {
            address tokenAddr = defaultsReturn
                .supportedTokensArray[i]
                .contractAddress;
            investedTokensWithValue[i] = StructTokenWithValue({
                tokenAddress: tokenAddr,
                tokenValue: userAccount.investedWithTokens[investmentType_][
                    tokenAddr
                ]
            });
        }
        userAccountReturn.investedWithTokens = investedTokensWithValue;

        uint256 investmentsLength = userAccount
            .investments[investmentType_]
            .length;

        StructUserInvestments[]
            memory userInvestmentsWithReward = new StructUserInvestments[](
                investmentsLength
            );

        for (uint256 i; i < investmentsLength; i++) {
            userInvestmentsWithReward[i] = userAccount.investments[
                investmentType_
            ][i];

            userInvestmentsWithReward[i]
                .pendingReward = _getInvestmentInterestByInvestAccount(
                userAccount.investments[investmentType_][i]
            );
        }

        // Investment info
        userAccountReturn.investments = userInvestmentsWithReward;

        userAccountReturn.subscriptionStartTime = userAccount
            .subscriptionStartTime[investmentType_];
        userAccountReturn.subscriptionDuration = userAccount
            .subscriptionDuration[investmentType_];

        return userAccountReturn;
    }

    function getAnalytics(
        InvestmentType investmentType_
    ) external view returns (StructAnalyticsReturn memory analyticsReturn) {
        require(
            uint256(investmentType_) <= uint256(InvestmentType.investment),
            "Invalid investment type"
        );

        StructAnalytics storage analytics = _analytics;
        IDefaultsUpgradeable iDefaults = IDefaultsUpgradeable(
            analytics.defaultsContract
        );
        require(address(iDefaults) != address(0), "Defaults contract not set");

        StructDefaultsReturn memory defaultsReturn = iDefaults.getDefaults(
            investmentType_
        );

        // Basic analytics data
        analyticsReturn.users = analytics.users;
        analyticsReturn.investmentsArray = analytics.investmentsArray;

        analyticsReturn.totalBusiness = analytics.totalBusiness[
            investmentType_
        ];
        analyticsReturn.defaultsContract = analytics.defaultsContract;

        // Calculate rewards distribution
        uint256 rewardsLength = uint256(type(RewardType).max) + 1;
        uint256[] memory rewardWithValue = new uint256[](rewardsLength);
        for (uint256 i; i < rewardsLength; i++) {
            rewardWithValue[i] = analytics.rewardsDistributed[investmentType_][
                RewardType(i)
            ];
        }
        analyticsReturn.rewardsDistributed = rewardWithValue;

        // Token analytics
        StructSupportedToken[] memory supportedTokensArray = defaultsReturn
            .supportedTokensArray;
        uint256 tokensLength = supportedTokensArray.length;

        // Tokens collected
        StructTokenWithValue[]
            memory tokensCollected = new StructTokenWithValue[](tokensLength);
        for (uint256 i; i < tokensLength; i++) {
            address tokenAddress = supportedTokensArray[i].contractAddress;
            require(tokenAddress != address(0), "Invalid token address");

            tokensCollected[i] = StructTokenWithValue({
                tokenAddress: tokenAddress,
                tokenValue: analytics.tokensCollected[investmentType_][
                    tokenAddress
                ]
            });
        }

        analyticsReturn.tokensCollected = tokensCollected;

        // Rewards distributed in tokens
        StructTokenWithValue[]
            memory rewardsInTokens = new StructTokenWithValue[](tokensLength);
        for (uint256 i; i < tokensLength; i++) {
            address tokenAddress = supportedTokensArray[i].contractAddress;
            rewardsInTokens[i] = StructTokenWithValue({
                tokenAddress: tokenAddress,
                tokenValue: analytics.rewardDistributedInTokens[
                    investmentType_
                ][tokenAddress]
            });
        }
        analyticsReturn.rewardDistributedInTokens = rewardsInTokens;

        // Reward calculation data
        analyticsReturn.calReward = analytics.calReward[investmentType_];

        return analyticsReturn;
    }

    function _getSubscriptionStatus(
        uint256 startTime_,
        uint256 subscriptionDuration_,
        uint256 currentTime_
    )
        private
        pure
        returns (
            uint256 startTime,
            uint256 endTime,
            uint256 timeRemaining,
            bool isActive
        )
    {
        if (startTime_ > 0) {
            startTime = startTime_;
            endTime = startTime_ + subscriptionDuration_;

            if (endTime > currentTime_) {
                timeRemaining = endTime - currentTime_;
            }

            if (timeRemaining > 0) {
                isActive = true;
            }
        }
    }

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
        )
    {
        StructUserAccount storage userAccount = _analytics.userAccount[user_];

        (startTime, endTime, timeRemaining, isActive) = _getSubscriptionStatus(
            userAccount.subscriptionStartTime[InvestmentType.subscription],
            userAccount.subscriptionDuration[InvestmentType.subscription],
            block.timestamp
        );
    }

    function transferFunds(
        address token_,
        address to_,
        uint256 valueInWei_
    ) external onlyAdmin {
        StructAnalytics storage analytics = _analytics;

        StructSupportedToken memory tokenAccount = IDefaultsUpgradeable(
            analytics.defaultsContract
        ).getSupportedTokenByAddress(token_);

        _transferFunds(tokenAccount, to_, valueInWei_);
    }

    // function pause() public onlyOwner {
    //     _pause();
    // }

    // function unpause() public onlyOwner {
    //     _unpause();
    // }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
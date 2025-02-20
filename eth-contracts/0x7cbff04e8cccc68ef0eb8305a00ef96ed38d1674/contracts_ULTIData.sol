// SPDX-License-Identifier: MIT
// author: @0xStef
pragma solidity ^0.8.28;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {ULTIShared} from "./contracts_ULTIShared.sol";

interface IULTI {
    // Core data
    function totalSupply() external view returns (uint256);
    function launchTimestamp() external view returns (uint64);
    function inputTokenAddress() external view returns (address);
    function initialRatio() external view returns (uint256);
    function minimumDepositAmount() external view returns (uint256);

    // Price and liquidity data
    function getSpotPrice() external view returns (uint256);
    function getTWAP() external view returns (uint256);
    function getLiquidityAmounts() external view returns (uint256, uint256, uint256, uint256);

    // Global/cycle data
    function nextPumpTimestamp() external view returns (uint256);
    function topContributorsBonuses(uint32 cycle) external view returns (uint256);
    function getCurrentCycle() external view returns (uint32);
    function getCurrentDayInCycle() external view returns (uint8);
    function getSnipingProtectionFactor(uint8 dayInCycle) external view returns (uint32);
    function isTopContributor(uint32 cycle, address user) external view returns (bool);
    function getTopContributors(uint32 cycle) external view returns (ULTIShared.TopContributor[] memory);
    function getPumpers(uint32 cycle) external view returns (address[] memory);
    function getActivePumpers(uint32 cycle) external view returns (address[] memory);
    function getReferralBonusPercentage(uint32 cycle) external view returns (uint256);

    // User data
    function claimableUlti(address user) external view returns (uint256);
    function claimableBonuses(address user) external view returns (uint256);
    function nextDepositOrClaimTimestamp(address user) external view returns (uint256);
    function nextAllBonusesClaimTimestamp(address user) external view returns (uint256);
    function totalUltiAllocatedEver(address user) external view returns (uint256);
    function accumulatedReferralBonuses(address user) external view returns (uint256);
    function streakCounts(uint32 cycle, address user) external view returns (uint32);
    function referrers(address user) external view returns (address);
    function pumpCounts(uint32 cycle, address user) external view returns (uint256);
    function totalInputTokenDeposited(uint32 cycle, address user) external view returns (uint256);
    function totalInputTokenReferred(uint32 cycle, address user) external view returns (uint256);
    function totalUltiAllocated(uint32 cycle, address user) external view returns (uint256);
    function discountedContributions(uint32 cycle, address user) external view returns (uint256);
}

/**
 * @title ULTIData
 * @notice This is a read-only contract that does not modify any protocol state
 * @dev Data aggregation contract for the ULTI protocol that bundles constants and variables
 * into structured views. This contract serves as a convenient way to access multiple
 * protocol states and configurations in single calls, reducing the number of RPC requests
 * needed by front-end applications and integrations.
 *
 * The contract provides four main data views:
 * - GlobalData: Current protocol-wide state variables
 * - CycleData: Cycle-specific information
 * - UserData: User-specific states and metrics
 * - Constants: Protocol configuration constants
 *
 */
contract ULTIData {
    IULTI public immutable ulti;

    constructor(address _ulti) {
        ulti = IULTI(_ulti);
    }

    function _getSkinInTheGameCap(address user) internal view returns (uint256) {
        return ulti.totalUltiAllocatedEver(user) * ULTIShared.REFERRAL_SKIN_IN_THE_GAME_CAP_MULTIPLIER;
    }

    function _isActivePumper(uint32 cycle, address user) internal view returns (bool) {
        return ulti.pumpCounts(cycle, user) >= ULTIShared.MIN_PUMPS_FOR_ACTIVE_PUMPERS;
    }

    /**
     * @dev Struct to hold global ULTI contract data
     * @param launchTimestamp Unix timestamp when contract was launched
     * @param totalSupply Total supply of ULTI tokens in circulation
     * @param cycle Current cycle number (increments every 33 days)
     * @param spotPrice Current spot price of ULTI in input token from Uniswap V3 pool
     * @param twap Time-weighted average price of ULTI in input token over MIN_TWAP_INTERVAL period
     * @param inputTokenBalance Contract's input token balance available for pumping
     * @param inputTokenInPosition Amount of input token currently in Uniswap V3 liquidity position
     * @param ultiInPosition Amount of ULTI currently in Uniswap V3 liquidity position
     * @param inputTokenInPool Amount of input token currently in Uniswap V3 liquidity pool
     * @param ultiInPool Amount of ULTI currently in Uniswap V3 liquidity pool
     * @param nextPumpTimestamp Unix timestamp when next pump action will be allowed
     */
    struct GlobalData {
        uint64 launchTimestamp;
        uint256 totalSupply;
        uint32 cycle;
        uint256 spotPrice;
        uint256 twap;
        uint256 inputTokenBalance;
        uint256 inputTokenInPosition;
        uint256 ultiInPosition;
        uint256 inputTokenInPool;
        uint256 ultiInPool;
        uint256 nextPumpTimestamp;
    }

    /**
     * @dev Returns global contract data for dynamic state variables
     * @return GlobalData struct
     */
    function getGlobalData() external view returns (GlobalData memory) {
        (uint256 inputTokenInPosition, uint256 ultiInPosition, uint256 inputTokenInPool, uint256 ultiInPool) =
            ulti.getLiquidityAmounts();

        return GlobalData({
            launchTimestamp: ulti.launchTimestamp(),
            totalSupply: ulti.totalSupply(),
            cycle: ulti.getCurrentCycle(),
            spotPrice: ulti.getSpotPrice(),
            twap: ulti.getTWAP(),
            inputTokenBalance: IERC20(ulti.inputTokenAddress()).balanceOf(address(ulti)),
            inputTokenInPosition: inputTokenInPosition,
            ultiInPosition: ultiInPosition,
            inputTokenInPool: inputTokenInPool,
            ultiInPool: ultiInPool,
            nextPumpTimestamp: ulti.nextPumpTimestamp()
        });
    }

    /**
     * @dev Struct to hold cycle-specific ULTI contract data
     * @param cycle Current cycle number
     * @param dayInCycle Current day within the cycle (1-33)
     * @param snipingProtectionFactor Current sniping protection factor (scaled by 1e6)
     * @param topContributors Array of top contributors for the cycle
     * @param topContributorsBonuses Total bonuses allocated to top contributors
     * @param pumpers Array of all pumpers for the cycle
     * @param activePumpers Array of active pumpers for the cycle
     * @param referralBonusPercentage Current referral bonus percentage (scaled by 1e6)
     */
    struct CycleData {
        uint8 dayInCycle;
        uint32 snipingProtectionFactor;
        ULTIShared.TopContributor[] topContributors;
        uint256 topContributorsBonuses;
        address[] pumpers;
        address[] activePumpers;
        uint256 referralBonusPercentage;
    }

    /**
     * @dev Returns cycle-specific contract data
     * @param cycle The cycle number to get data for
     * @return CycleData struct containing cycle data
     * @notice The dayInCycle and snipingProtectionFactor values always reflect the current cycle's day,
     * regardless of which cycle is requested in the parameters
     */
    function getCycleData(uint32 cycle) external view returns (CycleData memory) {
        uint8 dayInCycle = ulti.getCurrentDayInCycle();
        return CycleData({
            dayInCycle: dayInCycle,
            snipingProtectionFactor: ulti.getSnipingProtectionFactor(dayInCycle),
            topContributors: ulti.getTopContributors(cycle),
            topContributorsBonuses: ulti.topContributorsBonuses(cycle),
            pumpers: ulti.getPumpers(cycle),
            activePumpers: ulti.getActivePumpers(cycle),
            referralBonusPercentage: ulti.getReferralBonusPercentage(cycle) // scaled up by 1e6 for precision
        });
    }

    /**
     * @dev Struct to hold user-specific ULTI contract data for a given cycle.
     * @param claimableUlti Amount of ULTI tokens allocated to user from deposits that are not claimed yet
     * @param claimableBonuses Amount of bonus ULTI tokens allocated to user from referrals, streaks, and top contributor rewards that are not claimed yet
     * @param nextDepositOrClaimTimestamp Unix timestamp when user can next deposit or claim ULTI
     * @param nextAllBonusesClaimTimestamp Unix timestamp when user can next claim all accumulated bonuses
     * @param streakCount Number of consecutive cycles this user has participated in
     * @param streakInputTokenAmountBoundaries Tuple of (min, max) input token amounts needed to maintain streak in next cycle [1X-10X]
     * @param referrer Address of the user's referrer
     * @param skinInTheGameCap Maximum ULTI allocation based on user's total contribution
     * @param isTopContributor Whether the user is currently a top contributor for the cycle
     * @param pumpCount Number of times this user has pumped in the cycle
     * @param totalInputTokenDeposited Total amount of input tokens deposited by user in the cycle
     * @param totalInputTokenReferred Total amount of input tokens referred by user in the cycle
     * @param totalUltiAllocated Total amount of ULTI tokens allocated to user in the cycle
     * @param discountedContribution Total discounted contribution value for ranking in the cycle
     */
    struct UserData {
        uint256 claimableUlti;
        uint256 claimableBonuses;
        uint256 nextDepositOrClaimTimestamp;
        uint256 nextAllBonusesClaimTimestamp;
        uint32 streakCount;
        uint256[2] streakInputTokenAmountBoundaries;
        address referrer;
        uint256 skinInTheGameCap;
        bool isTopContributor;
        bool isActivePumper;
        uint256 pumpCount;
        uint256 totalInputTokenDeposited;
        uint256 totalInputTokenReferred;
        uint256 totalUltiAllocated;
        uint256 discountedContribution;
    }

    /**
     * @dev Retrieves comprehensive data about the ULTI contract state.
     * @param cycle The cycle number to get data for
     * @param user The user address to get data for
     * @return A UserData struct containing various contract state information.
     */
    function getUserData(uint32 cycle, address user) external view returns (UserData memory) {
        uint256[2] memory streakInputTokenAmountBoundaries;
        uint32 streakCount = ulti.streakCounts(cycle, user);

        // For cycle 1, there are no streak requirements
        // Set min to 0 and max to max uint256 to indicate no upper limit
        if (cycle == 1) {
            streakInputTokenAmountBoundaries = [ulti.minimumDepositAmount(), type(uint256).max];
        }
        // For cycles > 1, calculate boundaries based on previous cycle's deposits
        else {
            uint256 inputTokenDepositedPreviousCycle = ulti.totalInputTokenDeposited(cycle - 1, user);
            uint256 minimumDepositAmount = ulti.minimumDepositAmount();
            uint256 inputTokenDepositedPreviousCycleWithMinimum = inputTokenDepositedPreviousCycle
                < minimumDepositAmount ? minimumDepositAmount : inputTokenDepositedPreviousCycle;
            streakInputTokenAmountBoundaries =
                [inputTokenDepositedPreviousCycleWithMinimum, inputTokenDepositedPreviousCycleWithMinimum * 10];

            // Mitigate the loose tracking of streakCounts by returning the streak count
            // from the previous cycle if the user didn't deposit in the current cycle
            uint256 currentCycleDeposits = ulti.totalInputTokenDeposited(cycle, user);
            if (currentCycleDeposits == 0) {
                streakCount = ulti.streakCounts(cycle - 1, user);
            }
        }

        return UserData({
            claimableUlti: ulti.claimableUlti(user),
            claimableBonuses: ulti.claimableBonuses(user),
            nextDepositOrClaimTimestamp: ulti.nextDepositOrClaimTimestamp(user),
            nextAllBonusesClaimTimestamp: ulti.nextAllBonusesClaimTimestamp(user),
            streakCount: streakCount,
            streakInputTokenAmountBoundaries: streakInputTokenAmountBoundaries,
            referrer: ulti.referrers(user),
            skinInTheGameCap: _getSkinInTheGameCap(user),
            isTopContributor: ulti.isTopContributor(cycle, user),
            isActivePumper: _isActivePumper(cycle, user),
            pumpCount: ulti.pumpCounts(cycle, user),
            totalInputTokenDeposited: ulti.totalInputTokenDeposited(cycle, user),
            totalInputTokenReferred: ulti.totalInputTokenReferred(cycle, user),
            totalUltiAllocated: ulti.totalUltiAllocated(cycle, user),
            discountedContribution: ulti.discountedContributions(cycle, user)
        });
    }

    /**
     * @dev Struct to hold all public constants used in the ULTI contract.
     */
    struct Constants {
        // Core constants
        uint256 ULTI_NUMBER;
        uint256 MAX_TOP_CONTRIBUTORS;
        // Time-related constants
        uint256 CYCLE_INTERVAL;
        uint256 DEPOSIT_CLAIM_INTERVAL;
        uint256 EARLY_BIRD_PRICE_DURATION;
        uint32 MIN_TWAP_INTERVAL;
        uint256 ALL_BONUSES_CLAIM_INTERVAL;
        // Economic constants (immutable variables)
        uint256 INITIAL_RATIO;
        uint256 MINIMUM_DEPOSIT_AMOUNT;
        // Liquidity pool constants
        uint256 LP_CONTRIBUTION_PERCENTAGE;
        uint24 LP_FEE;
        int24 LP_MIN_TICK;
        int24 LP_MAX_TICK;
        uint256 MAX_ADD_LP_SLIPPAGE_BPS;
        uint256 MAX_SWAP_SLIPPAGE_BPS;
        // Bonus-related constants
        uint256 TOP_CONTRIBUTOR_BONUS_PERCENTAGE;
        uint256 STREAK_BONUS_COUNT_START;
        uint256 STREAK_BONUS_MAX_PERCENTAGE;
        uint256 REFERRAL_BONUS_FOR_REFERRED_PERCENTAGE;
        uint256 REFERRAL_SKIN_IN_THE_GAME_CAP_MULTIPLIER;
        // Pump-related constants
        uint256 PUMP_INTERVAL;
        uint256 PUMP_FACTOR_NUMERATOR;
        uint256 PUMP_FACTOR_DENOMINATOR;
        uint256 MIN_PUMPS_FOR_ACTIVE_PUMPERS;
        uint256 MAX_PUMPS_FOR_ACTIVE_PUMPERS;
        uint256 ACTIVE_PUMPERS_BONUS_PERCENTAGE;
        // Utility constants
        uint256 PRECISION_FACTOR_1E6;
    }

    /**
     * @dev Returns all public constants used in the ULTI contract.
     * @return A Constants struct containing all public constants.
     */
    function getConstants() external view returns (Constants memory) {
        return Constants({
            ULTI_NUMBER: ULTIShared.ULTI_NUMBER,
            MAX_TOP_CONTRIBUTORS: ULTIShared.MAX_TOP_CONTRIBUTORS,
            CYCLE_INTERVAL: ULTIShared.CYCLE_INTERVAL,
            DEPOSIT_CLAIM_INTERVAL: ULTIShared.DEPOSIT_CLAIM_INTERVAL,
            EARLY_BIRD_PRICE_DURATION: ULTIShared.EARLY_BIRD_PRICE_DURATION,
            MIN_TWAP_INTERVAL: ULTIShared.MIN_TWAP_INTERVAL,
            ALL_BONUSES_CLAIM_INTERVAL: ULTIShared.ALL_BONUSES_CLAIM_INTERVAL,
            INITIAL_RATIO: ulti.initialRatio(),
            MINIMUM_DEPOSIT_AMOUNT: ulti.minimumDepositAmount(),
            LP_CONTRIBUTION_PERCENTAGE: ULTIShared.LP_CONTRIBUTION_PERCENTAGE,
            LP_FEE: ULTIShared.LP_FEE,
            LP_MIN_TICK: ULTIShared.LP_MIN_TICK,
            LP_MAX_TICK: ULTIShared.LP_MAX_TICK,
            MAX_ADD_LP_SLIPPAGE_BPS: ULTIShared.MAX_ADD_LP_SLIPPAGE_BPS,
            MAX_SWAP_SLIPPAGE_BPS: ULTIShared.MAX_SWAP_SLIPPAGE_BPS,
            TOP_CONTRIBUTOR_BONUS_PERCENTAGE: ULTIShared.TOP_CONTRIBUTOR_BONUS_PERCENTAGE,
            STREAK_BONUS_COUNT_START: ULTIShared.STREAK_BONUS_COUNT_START,
            STREAK_BONUS_MAX_PERCENTAGE: ULTIShared.STREAK_BONUS_MAX_PERCENTAGE,
            REFERRAL_BONUS_FOR_REFERRED_PERCENTAGE: ULTIShared.REFERRAL_BONUS_FOR_REFERRED_PERCENTAGE,
            REFERRAL_SKIN_IN_THE_GAME_CAP_MULTIPLIER: ULTIShared.REFERRAL_SKIN_IN_THE_GAME_CAP_MULTIPLIER,
            PUMP_INTERVAL: ULTIShared.PUMP_INTERVAL,
            PUMP_FACTOR_NUMERATOR: ULTIShared.PUMP_FACTOR_NUMERATOR,
            PUMP_FACTOR_DENOMINATOR: ULTIShared.PUMP_FACTOR_DENOMINATOR,
            MIN_PUMPS_FOR_ACTIVE_PUMPERS: ULTIShared.MIN_PUMPS_FOR_ACTIVE_PUMPERS,
            MAX_PUMPS_FOR_ACTIVE_PUMPERS: ULTIShared.MAX_PUMPS_FOR_ACTIVE_PUMPERS,
            ACTIVE_PUMPERS_BONUS_PERCENTAGE: ULTIShared.ACTIVE_PUMPERS_BONUS_PERCENTAGE,
            PRECISION_FACTOR_1E6: ULTIShared.PRECISION_FACTOR_1E6
        });
    }
}
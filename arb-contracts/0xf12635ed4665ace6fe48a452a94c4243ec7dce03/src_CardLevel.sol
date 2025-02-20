// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import {AccessControlUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {IFiat24Account} from "./src_interfaces_IFiat24Account.sol";
import {IReferralStorage} from "./src_interfaces_IReferralStorage.sol";

contract CardLevel is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    // Level details (0-MAX_LEVEL)
    mapping(uint256 => Level) public levels;
    
    // User's current level
    mapping(uint256 => uint256) public userLevels;
    
    // Treasury address to receive upgrade payments
    address public treasury;

    IReferralStorage public referralStorage;

    uint256 public uniCoupon; // in USDC unit

    struct Level {
        uint256 upgradePrice;    // Price to upgrade to this level
        uint256 cashbackRate;    // In basis points (1/10000)
        uint256 rebateRate;      // In basis points (1/10000)
        uint256 requiredReferrals; // Number of referrals needed for free upgrade
    }

    uint256 public constant BASIS_POINTS_PRECISION = 1e4;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    // Payment token, Arbitrum USDC
    IERC20 public constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    uint256 public constant USDC_PRECISION = 1e6;
    IFiat24Account public constant FIAT24ACCOUNT = IFiat24Account(0x133CAEecA096cA54889db71956c7f75862Ead7A0);
    uint256 public constant MAX_LEVEL = 4;

    /**
     * paymentType: 0 - no payment, 1 - by referrals, 2 - by USDC
     */
    enum PaymentType {
        NO_PAYMENT,
        BY_REFERRALS,
        BY_USDC
    }
    event LevelUpgraded(uint256 indexed userTokenID, uint256 fromLevel, uint256 toLevel, uint256 value, PaymentType paymentType);
    event LevelConfigured(uint256 level, uint256 upgradePrice, uint256 cashbackRate, uint256 rebateRate, uint256 requiredReferrals);
    event TreasuryUpdated(address newTreasury);

    function initialize(
        address _treasury,
        address _referralStorage
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        
        require(_treasury != address(0), "Invalid treasury");
        require(_referralStorage != address(0), "Invalid referral storage");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        treasury = _treasury;
        referralStorage = IReferralStorage(_referralStorage);

        // Initialize default levels with referral requirements
        uint256 onePercent = BASIS_POINTS_PRECISION / 100;
        _configureLevel(0, 0, 0, 20 * onePercent, 0);           // Level 0: No requirements, 20% Referral Commission
        _configureLevel(1, 20 * USDC_PRECISION, 20 * onePercent, 40 * onePercent, 2);    // Level 1: 2 referrals, 20% cashback, 40% Referral Commission
        _configureLevel(2, 40 * USDC_PRECISION, 40 * onePercent, 60 * onePercent, 5); // Level 2: 5 referrals, 40% cashback, 60% Referral Commission
        _configureLevel(3, 80 * USDC_PRECISION, 60 * onePercent, 80 * onePercent, 10); // Level 3: 10 referrals, 60% cashback, 80% Referral Commission
        _configureLevel(4, 5000 * USDC_PRECISION, 80 * onePercent, 90 * onePercent, 1000); // Level 4: 100 referrals, 80% cashback, 90% Referral Commission
    }

    function getLiveReferralsCount(uint256 refererTokenID) public view returns (uint256) {
        uint256 offset = 0;
        uint256 limit = 100;
        uint256 liveReferrals = 0;
        
        while (true) {
            (uint256[] memory users, uint256 total) = referralStorage.getUsersByReferrer(refererTokenID, offset, limit);
            
            // Break if no more users
            if (users.length == 0) break;
            
            // Check status of each referred user
            for (uint256 i = 0; i < users.length; i++) {
                // Check if their status is Live
                if (FIAT24ACCOUNT.status(users[i]) == IFiat24Account.Status.Live) {
                    liveReferrals++;
                }
            }
            
            offset += users.length;
            
            // Break if we've processed all users
            if (offset >= total) break;
        }
        
        return liveReferrals;
    }

    function upgradeLevelByReferral(uint256 newLevel) external {
        require(newLevel > 0 && newLevel <= MAX_LEVEL, "Invalid level");
        uint256 userTokenId = FIAT24ACCOUNT.tokenOfOwnerByIndex(msg.sender, 0);
        uint256 currentLevel = userLevels[userTokenId];
        require(newLevel > currentLevel, "Current level");

        Level memory targetLevel = levels[newLevel];

        // Check if user has enough referrals for free upgrade  
        uint256 liveReferrals = getLiveReferralsCount(userTokenId);
       require(liveReferrals >= targetLevel.requiredReferrals, "not enough live referrals");

        userLevels[userTokenId] = newLevel;
        emit LevelUpgraded(userTokenId, currentLevel, newLevel, liveReferrals, PaymentType.BY_REFERRALS);
    }

    function upgradeLevelByUSDC(uint256 newLevel) external {
        require(newLevel > 0 && newLevel <= MAX_LEVEL, "Invalid level");
        uint256 userTokenId = FIAT24ACCOUNT.tokenOfOwnerByIndex(msg.sender, 0);
        uint256 currentLevel = userLevels[userTokenId];
        require(newLevel > currentLevel, "Current level");

        Level memory currentLevelInfo = levels[currentLevel];
        Level memory targetLevel = levels[newLevel];
        uint256 paymentAmount = targetLevel.upgradePrice - currentLevelInfo.upgradePrice;
        if(FIAT24ACCOUNT.walletProvider(userTokenId) == 8010 && currentLevel == 0){
            paymentAmount = paymentAmount > uniCoupon ? paymentAmount - uniCoupon : 0;
        }
        if(paymentAmount > 0){
            USDC.safeTransferFrom(msg.sender, treasury, paymentAmount);
        }

        userLevels[userTokenId] = newLevel;
        emit LevelUpgraded(userTokenId, currentLevel, newLevel, paymentAmount, PaymentType.BY_USDC);
    }


    function configureLevel(
        uint256 level,
        uint256 upgradePrice,
        uint256 cashbackRate,
        uint256 rebateRate,
        uint256 requiredReferrals
    ) external onlyRole(ADMIN_ROLE) {
        require(level <= MAX_LEVEL, "Invalid level");
        require(cashbackRate <= BASIS_POINTS_PRECISION, "Cashback rate too high"); // Max 100%
        require(rebateRate <= BASIS_POINTS_PRECISION, "Rebate rate too high");      // Max 100%
        
        _configureLevel(level, upgradePrice, cashbackRate, rebateRate, requiredReferrals);
    }

    function _configureLevel(
        uint256 level,
        uint256 upgradePrice,
        uint256 cashbackRate,
        uint256 rebateRate,
        uint256 requiredReferrals
    ) internal {
        levels[level] = Level({
            upgradePrice: upgradePrice,
            cashbackRate: cashbackRate,
            rebateRate: rebateRate,
            requiredReferrals: requiredReferrals
        });
        
        emit LevelConfigured(level, upgradePrice, cashbackRate, rebateRate, requiredReferrals);
    }

    function setTreasury(address _treasury) external onlyRole(ADMIN_ROLE) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        emit TreasuryUpdated(_treasury);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}

    /**
     * @notice Allows admin to upgrade multiple users' levels without checks
     * @param userTokenIDs Array of users' token IDs to upgrade
     * @param newLevel Target level to upgrade to
     */
    function batchUpgradeLevel(
        uint256[] calldata userTokenIDs,
        uint256 newLevel
    ) external onlyRole(OPERATOR_ROLE) {
        // Basic validation
        require(newLevel > 0 && newLevel <= MAX_LEVEL, "Invalid level");
        require(userTokenIDs.length > 0, "Empty users array");
        require(userTokenIDs.length <= 100, "Batch too large"); // Gas limit protection

        // Process each user
        for (uint256 i = 0; i < userTokenIDs.length; i++) {
            uint256 user = userTokenIDs[i];
            require(user != 0, "Invalid address");
            
            uint256 currentLevel = userLevels[user];
            userLevels[user] = newLevel;
            
            // Use the existing LevelUpgraded event
            emit LevelUpgraded(user, currentLevel, newLevel, 0, PaymentType.NO_PAYMENT);
        }
    }

    function setUniCoupon(uint256 _uniCoupon) external onlyRole(OPERATOR_ROLE){
        uniCoupon = _uniCoupon;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_math_SafeMath.sol";

interface IDiamondBites is IERC20 {
    function mint(address to, uint256 amount) external;
}


contract DiamondShares {
    using SafeMath for uint256;
    IERC20 public USDT;
    IDiamondBites public $DMB;

    //DMB Token declarations
    uint256 public constant INITIAL_TOKEN_RATE = 100; // 100 tokens per 1 USDT initially
    uint256 public constant RATE_REDUCTION_THRESHOLD = 1000000e6; // 1 million tokens threshold for rate reduction
    uint256 public constant RATE_REDUCTION_FACTOR = 2; // Reduce rate by half at each threshold
    uint256 public totalTokensMinted;

    uint256 public constant UNIT_PRICE = 10e6;
    uint256[] private UNIT_RANGE = [1, 2, 5, 10, 20, 30, 40, 50, 100, 200, 500, 1000];
    uint256 public constant CONST_DIVIDER = 10000;
    uint256 public constant DIVIDEND_LIMIT = 15000;
    uint256 public constant DDF_PERCENT = 5000;
    uint256 public constant MAX_LEVEL = 10;
    uint256[] public LEVEL_PERCENT = [1000, 500, 200, 100, 50, 50, 25, 25, 25, 25];
    uint256 public constant LBS_PERCENT = 2000;
    uint256 private constant CIF_PERCENT = 2000;
    uint256 public constant MIN_WITHDRAWAL_AMOUNT = 1e6;
    address private cif1_address;
    address private cif2_address;
    address public defaultReferrer;
    address private misDiv_address;
    address public lpManager;
    uint256 public totalUsers;
    mapping(uint256 => address) public userAddresses;
    uint256 public totalDeposited;
    uint256 public totalWithdrawn;
    uint256 public liveShares;
    uint256 public latestShare;
    
    
    
    struct UserInfo {
        address referrer;
        uint256 totalDeposit;
        uint256 directCount;
        uint256 totalDirectDeposit;
        uint256 lastPurchasedUnits;
        uint256 claimedDDF;
        uint256 lastProcessedDdfIndex;
        uint256 lastPurchaseIndex;
    }
    mapping(address => UserInfo) public userInfos;
    mapping(address => address[]) public directReferrals;

    struct DdfDistribution {
        uint256 amount;
        uint256 totalShares;
        uint256 accumulatedDdfPerShare;
    }

    DdfDistribution[] public ddfDistributions;

    struct RewardInfo {
        uint256 ddf;
        uint256 lbs;
        uint256 totalRewards;
        uint256 withdrawnRewards;
        uint256 availableRewards;
    }
    mapping(address => RewardInfo) public rewardInfos;

    struct LpInfo {
        uint256 totalUsdtTokens;
        uint256 totalDmbTokens;
        uint256 availableUsdtTokens;
        uint256 availableDmbTokens;
    }
    LpInfo public lpInfo;

    // Events
    event UnitsPurchased(address indexed user, uint256 units, address indexed referrer);
    event DDFClaimed(address indexed user, uint256 amount);
    event RewardsWithdrawnEvent(address indexed user, uint256 amount);
    constructor(
        address _usdt,
        address _dmb,
        address _cif1,
        address _cif2,
        address _defaultReferrer,
        address _misDiv,
        address _lpManager
   ) {
        USDT = IERC20(_usdt);
        $DMB = IDiamondBites(_dmb);
        cif1_address = _cif1;
        cif2_address = _cif2;
        defaultReferrer = _defaultReferrer;
        misDiv_address = _misDiv;
        lpManager = _lpManager;
    }


    // Add this function to calculate token amount based on current supply
    function calculateTokenAmount(uint256 usdtAmount) public view returns (uint256) {
        uint256 currentRate = INITIAL_TOKEN_RATE;
        uint256 supplyThreshold = RATE_REDUCTION_THRESHOLD;
        
        // Reduce rate based on total supply
        while (totalTokensMinted >= supplyThreshold) {
            currentRate = currentRate / RATE_REDUCTION_FACTOR;
            supplyThreshold = supplyThreshold * 2;
        }
        
        // Calculate tokens to mint (10% of USDT value * current rate)
            return (usdtAmount * currentRate * 20) / 100;
    }

    function buyUnits(uint256 _units, address _referrer) external {
        _checkUnitPurchaseEligibility(msg.sender);
        _validateUnitAmount(_units);
        address referrer = _setReferrer(_referrer);
        
        uint256 totalAmount = _units.mul(UNIT_PRICE);
        uint256 tokensToMint = calculateTokenAmount(totalAmount);
        
        // Mint DMB tokens
        $DMB.mint(msg.sender, tokensToMint/2);
        $DMB.mint(address(this), tokensToMint/2);
        totalTokensMinted += tokensToMint;
        
        // Calculate 10% USDT for LP
        uint256 usdtForLp = totalAmount.mul(10).div(100);
        uint256 dmbForLp = tokensToMint/2;
        // Update LP info - add to existing values
        lpInfo.totalUsdtTokens += usdtForLp;
        lpInfo.totalDmbTokens += dmbForLp;
        lpInfo.availableUsdtTokens += usdtForLp;
        lpInfo.availableDmbTokens += dmbForLp;
        
        _processDeposit(totalAmount);
        _distributeCIF(totalAmount);
        _updateUserDeposit(msg.sender, totalAmount);
        _updateShares(msg.sender, _units);
        _updateReferrerInfo(referrer, totalAmount);
        _distributeLevelBonus(totalAmount);
        _updateDDFInfo(totalAmount);
        
        emit UnitsPurchased(msg.sender, _units, referrer);
    }

    function manageLp() external {
        require(msg.sender == lpManager, "Only lpManager can manage LP");
        // TODO: Implement LP management logic
        // withdraw tokens and usdt to lpManager
        USDT.transfer(lpManager, lpInfo.availableUsdtTokens);
        $DMB.transfer(lpManager, lpInfo.availableDmbTokens);
        // reset lp info
        lpInfo.availableUsdtTokens = 0;
        lpInfo.availableDmbTokens = 0;
    }


    function _checkUnitPurchaseEligibility(address _user) private view {
        if (_user != defaultReferrer) {
            (,, uint256 availableLimit) = this.userRewardLimit(_user);
            require(availableLimit == 0, "Cannot buy new units while Last is active");
        }
    }

    function _validateUnitAmount(uint256 _units) private view {
        bool validUnit = false;
        for (uint256 i = 0; i < UNIT_RANGE.length; i++) {
            if (_units == UNIT_RANGE[i]) {
                validUnit = true;
                break;
            }
        }
        require(validUnit, "Invalid unit amount");
    }

    function _setReferrer(address _referrer) private returns (address) {
        UserInfo storage userInfo = userInfos[msg.sender];
        if (userInfo.referrer == address(0)) {
            require(userInfos[_referrer].totalDeposit > 0 || _referrer == defaultReferrer, "invalid referrer");
            userInfos[msg.sender].referrer = _referrer;
            directReferrals[_referrer].push(msg.sender);
            return _referrer;
        } else {
            return userInfos[msg.sender].referrer;
        }
    }

    function _processDeposit(uint256 _amount) private {
        USDT.transferFrom(msg.sender, address(this), _amount);
    }

    function _distributeCIF(uint256 _amount) private {
        uint256 cifAmount = _amount.mul(CIF_PERCENT).div(CONST_DIVIDER);
        USDT.transfer(cif1_address, cifAmount.div(2));
        USDT.transfer(cif2_address, cifAmount.div(2));
    }

    function _updateUserDeposit(address _user, uint256 _amount) private {
        userInfos[_user].totalDeposit = userInfos[_user].totalDeposit.add(_amount);
        totalDeposited = totalDeposited.add(_amount);
    }

    function _updateShares(address _user, uint256 _units) private {
        if (userInfos[_user].lastPurchasedUnits > 0) {
            uint256 previousShares = userInfos[_user].lastPurchasedUnits;
            liveShares = liveShares.sub(previousShares);
        }
        userInfos[_user].lastPurchasedUnits = _units;
        liveShares = liveShares.add(_units);
        latestShare = _units;
    }

    function _updateReferrerInfo(address _referrer, uint256 _amount) private {
        UserInfo storage referrerInfo = userInfos[_referrer];
        UserInfo storage senderInfo = userInfos[msg.sender];
        if (senderInfo.totalDeposit == _amount) {
            userAddresses[totalUsers] = msg.sender;
            totalUsers = totalUsers.add(1);
            referrerInfo.directCount = referrerInfo.directCount.add(1);
        }
        referrerInfo.totalDirectDeposit = referrerInfo.totalDirectDeposit.add(_amount);
    }

    function _updateDDFInfo(uint256 _amount) private {
        uint256 ddfAmount = _amount.mul(DDF_PERCENT).div(CONST_DIVIDER);
        uint256 newDdfPerShare = 0;
        if (liveShares > 0) {
            newDdfPerShare = ddfAmount.mul(1e12).div(liveShares);
        }
        uint256 accumulatedDdfPerShare = ddfDistributions.length > 0 
            ? ddfDistributions[ddfDistributions.length - 1].accumulatedDdfPerShare.add(newDdfPerShare)
            : newDdfPerShare;
        
        ddfDistributions.push(DdfDistribution({
            amount: ddfAmount,
            totalShares: liveShares,
            accumulatedDdfPerShare: accumulatedDdfPerShare
        }));
    }

    function getUserDDFShare(address _user) public view returns (uint256 userShare) {
        UserInfo memory user = userInfos[_user];
        uint256 userShares = user.lastPurchasedUnits;
        
        if (ddfDistributions.length == 0 || userShares == 0) {
            return 0;
        }
        
        uint256 totalDdf = 0;
        uint256 startIndex = user.lastProcessedDdfIndex;
        
        // Calculate DDF for all distributions since last processed
        for (uint256 i = startIndex; i < ddfDistributions.length; i++) {
            DdfDistribution memory dist = ddfDistributions[i];
            if (dist.totalShares > 0) {
                uint256 newDdf = userShares.mul(dist.amount).div(dist.totalShares);
                totalDdf = totalDdf.add(newDdf);
            }
        }
        
        // Add previously claimed DDF to total
        totalDdf = totalDdf.add(user.claimedDDF);
        
        // Return unclaimed DDF
        if (totalDdf > user.claimedDDF) {
            return totalDdf.sub(user.claimedDDF);
        } else {
            return 0;
        }
    }

    function claimDDF(address _user) external {
        uint256 pendingDDF = getUserDDFShare(_user);
        require(pendingDDF >= 1e6, "Claim amount is too low");
        
        (,, uint256 availableLimit) = userRewardLimit(_user);
        uint256 claimAmount = pendingDDF > availableLimit ? availableLimit : pendingDDF;
        
        UserInfo storage userInfo = userInfos[_user];
        userInfo.claimedDDF = userInfo.claimedDDF.add(claimAmount);
        userInfo.lastProcessedDdfIndex = ddfDistributions.length;
        
        if (claimAmount > 0) {
            _updateDividendRewardInfo(_user, claimAmount);
        }
        
        uint256 remainingAmount = pendingDDF.sub(claimAmount);
        if (remainingAmount > 0) {
            USDT.transfer(misDiv_address, remainingAmount);
        }
        
        if(availableLimit == 0) {
            uint256 lastShare = userInfos[_user].lastPurchasedUnits;
            liveShares = liveShares.sub(lastShare);
            userInfos[_user].lastPurchasedUnits = 0;
        }

        emit DDFClaimed(_user, pendingDDF);
    }

    function _updateDividendRewardInfo(address user, uint256 amount) private {
        rewardInfos[user].ddf = rewardInfos[user].ddf.add(amount);
        rewardInfos[user].totalRewards = rewardInfos[user].totalRewards.add(amount);
        rewardInfos[user].availableRewards = rewardInfos[user].availableRewards.add(amount);
    }

    function userRewardLimit(address _user) public view returns (uint256 rewardLimit, uint256 usedLimit, uint256 availableLimit) {
        if (_user == defaultReferrer) {
            rewardLimit = 1000000e6;
            usedLimit = rewardInfos[_user].totalRewards;
            availableLimit = rewardLimit; // Always keep the full limit available
        } else {
            rewardLimit = userInfos[_user].totalDeposit.mul(DIVIDEND_LIMIT).div(CONST_DIVIDER);
            usedLimit = rewardInfos[_user].totalRewards;
            availableLimit = rewardLimit > usedLimit ? rewardLimit.sub(usedLimit) : 0;
        }
        
        return (rewardLimit, usedLimit, availableLimit);
    }

    function _distributeLevelBonus(uint256 _totalAmount) private {
        uint256 lbsAmount = _totalAmount.mul(LBS_PERCENT).div(CONST_DIVIDER);
        address upline = userInfos[msg.sender].referrer;
        uint256 distributedAmount = 0;

        for (uint256 level = 1; level <= MAX_LEVEL && upline != address(0); ) {
            uint256 percentage = LEVEL_PERCENT[level.sub(1)];
            uint256 bonus = _totalAmount.mul(percentage).div(CONST_DIVIDER);
            (,, uint256 availableLimit) = userRewardLimit(upline);

            bonus = bonus > availableLimit ? availableLimit : bonus;
            if (bonus > 0) {
                _updateLbsRewardInfo(upline, bonus);
                distributedAmount = distributedAmount.add(bonus);
            }

            if (upline == defaultReferrer) break;
            upline = userInfos[upline].referrer;
            unchecked { level = level.add(1); }
        }

        // Add any remaining amount to defaultReferrer's reward info
        uint256 remainingAmount = lbsAmount.sub(distributedAmount);
        if (remainingAmount > 0) {
            USDT.transfer(defaultReferrer, remainingAmount);
        }
    }

    function _updateLbsRewardInfo(address user, uint256 amount) private {
        rewardInfos[user].lbs = rewardInfos[user].lbs.add(amount);
        rewardInfos[user].totalRewards = rewardInfos[user].totalRewards.add(amount);
        rewardInfos[user].availableRewards = rewardInfos[user].availableRewards.add(amount);
    }

    function withdrawRewards(address _user) external {
        uint256 rewardAmount = rewardInfos[_user].availableRewards;
        require(rewardAmount > 0, "No rewards to withdraw");
        require(rewardAmount >= MIN_WITHDRAWAL_AMOUNT, "Withdrawal amount is too low");
        // Update reward info and totalWithdrawn
        rewardInfos[_user].withdrawnRewards = rewardInfos[_user].withdrawnRewards.add(rewardAmount);
        totalWithdrawn = totalWithdrawn.add(rewardAmount);
        rewardInfos[_user].availableRewards = 0;
        // update Last Purchased Units
        (,, uint256 availableLimit) = this.userRewardLimit(_user);
        if(availableLimit == 0) {
            uint256 lastShare = userInfos[_user].lastPurchasedUnits;
            liveShares = liveShares.sub(lastShare);
            userInfos[_user].lastPurchasedUnits = 0;
        }

        // Transfer service charge and remaining amount
        USDT.transfer(_user, rewardAmount);

        emit RewardsWithdrawnEvent(_user, rewardAmount);
    }


    function getReferrals(address _user, uint256 _level) public view returns (address[] memory _userAddresses, address[] memory _referrerAddresses, uint256[] memory _lastPurchasedUnits) {
        require(_level > 0 && _level <= 10, "Level must be between 1 and 10");

        address[] memory levelReferrals = getLowerLevelReferrals(_user, _level);

        uint256 count = levelReferrals.length;
        _userAddresses = new address[](count);
        _referrerAddresses = new address[](count);
        _lastPurchasedUnits = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            address currentUser = levelReferrals[i];
            _userAddresses[i] = currentUser;
            _referrerAddresses[i] = userInfos[currentUser].referrer;
            _lastPurchasedUnits[i] = userInfos[currentUser].lastPurchasedUnits;
        }

        return (_userAddresses, _referrerAddresses, _lastPurchasedUnits);
    }

    function getLowerLevelReferrals(address _user, uint256 _level) private view returns (address[] memory) {
        if (_level == 1) {
            return directReferrals[_user];
        }

        address[] memory previousLevelReferrals = getLowerLevelReferrals(_user, _level - 1);
        address[] memory allPreviousReferrals = new address[](0);

        for (uint256 i = 1; i < _level; i++) {
            address[] memory currentLevelReferrals = getLowerLevelReferrals(_user, i);
            address[] memory newAllPreviousReferrals = new address[](allPreviousReferrals.length + currentLevelReferrals.length);
            uint256 k = 0;
            for (uint256 j = 0; j < allPreviousReferrals.length; j++) {
                newAllPreviousReferrals[k++] = allPreviousReferrals[j];
            }
            for (uint256 j = 0; j < currentLevelReferrals.length; j++) {
                newAllPreviousReferrals[k++] = currentLevelReferrals[j];
            }
            allPreviousReferrals = newAllPreviousReferrals;
        }

        return getUniqueReferrals(previousLevelReferrals, allPreviousReferrals);
    }

    function getUniqueReferrals(address[] memory previousLevelReferrals, address[] memory allPreviousReferrals) private view returns (address[] memory) {
        uint256 totalReferrals = 0;
        
        for (uint256 i = 0; i < previousLevelReferrals.length; i++) {
            address[] memory tempReferrals = directReferrals[previousLevelReferrals[i]];
            for (uint256 j = 0; j < tempReferrals.length; j++) {
                bool isNew = true;
                for (uint256 k = 0; k < allPreviousReferrals.length; k++) {
                    if (tempReferrals[j] == allPreviousReferrals[k]) {
                        isNew = false;
                        break;
                    }
                }
                if (isNew) totalReferrals++;
            }
        }
        
        address[] memory levelReferrals = new address[](totalReferrals);
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < previousLevelReferrals.length; i++) {
            address[] memory tempReferrals = directReferrals[previousLevelReferrals[i]];
            for (uint256 j = 0; j < tempReferrals.length; j++) {
                bool isNew = true;
                for (uint256 k = 0; k < allPreviousReferrals.length; k++) {
                    if (tempReferrals[j] == allPreviousReferrals[k]) {
                        isNew = false;
                        break;
                    }
                }
                if (isNew) {
                    levelReferrals[currentIndex] = tempReferrals[j];
                    currentIndex++;
                }
            }
        }
        
        return levelReferrals;
    }

}
// SPDX-License-Identifier: BSD 3-Clause

pragma solidity 0.8.9;

import "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router02.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./contracts_abstracts_BaseContract.sol";
import "./contracts_interfaces_ICitizen.sol";
import "./contracts_libs_zeppelin_token_BEP20_IBEP20.sol";
import "./contracts_interfaces_ILPToken.sol";
import "./contracts_interfaces_IVault.sol";

contract LSDfi is BaseContract, ReentrancyGuardUpgradeable {
  struct Config {
    uint secondsInADay;
    address treasury;
    uint minStakeAmount;
    uint minStakeDurationForRefBonus;
    uint zeroTimestamp;
    uint refLevels;
    uint[] refBonusPercentages;
    uint[4] bonusRates;
    mapping (uint => uint) baseStakeRate;
  }

  struct SystemData {
    uint totalStakedValue;
    uint totalMember;
    uint totalClaimed;
  }

  struct Round {
    uint id; // remove on production
    uint startAt; // remove on production
    uint endAt; // remove on production
    uint totalShares;
    uint totalReward;
  }

  struct User {
    uint joinAt;
    uint stakedAt;
    uint unlockableAt;
    uint totalStaked;
    uint totalLPStaked;
    uint shares;
    uint referralReward;
    bool activated;
    bool freezeReward;
    bool freezeReferral;
    mapping (uint => uint) checkInShares;
    uint[] bonusRates;
    bool leader;
    bool out;
  }

  modifier notInCheckinPeriod() {
    require(block.timestamp - (config.zeroTimestamp + (_getCheckinRound() + 1) * CHECKIN_INTERVAL * config.secondsInADay) >= config.secondsInADay, "LSDfi: in checkin period");
    _;
  }

  modifier inCheckinPeriod() {
    require(block.timestamp - (config.zeroTimestamp + (_getCheckinRound() + 1) * CHECKIN_INTERVAL * config.secondsInADay) < config.secondsInADay, "LSDfi: not in checkin period");
    _;
  }

  Config public config;
  SystemData public systemData;
  ICitizen public citizen;
  IBEP20 public menToken;
  IBEP20 public usdtToken;
  ILPToken public lpToken;
  IVault public vault;
  IUniswapV2Router02 public uniswapV2Router;
  mapping (address => User) public users;
  mapping (uint => Round) public rounds;
  uint private constant POOL_VALUE_RATIO = 2;
  uint private constant CHECKIN_INTERVAL = 28;
  uint private constant DECIMAL3 = 1000;
  uint private constant ONE_HUBDRED_DECIMAL3 = 100000;
  uint private constant DECIMAL9 = 1000000000;
  uint private minStakingDuration;

  event BaseStakingRateUpdated(uint duration, uint shareRate);
  event BonusRateUpdated(uint[4] bonusRates);
  event CheckedIn(address indexed user, uint round, uint shares, uint timestamp);
  event CheckinFailed(address indexed user, uint round, uint timestamp);
  event ConfigUpdated(uint secondsInADay, address treasury, uint minStakeAmount, uint minStakeDurationForRefBonus);
  event LeaderSet(address indexed user, bool status);
  event ReNewed(address indexed user, uint duration, uint timestamp);
  event RewardClaimed(address indexed user, uint round, uint reward, uint timestamp);
  event ReferralRewardClaimed(address indexed user, uint reward, uint timestamp);
  event RefBonusSent(address[31] refAddresses, uint[31] refAmounts, uint timestamp, address sender);
  event RefConfigUpdated(uint refLevels, uint[] refBonusPercentages);
  event StakedViaToken(address indexed user, uint usdtAmount, uint menAmount, uint duration, uint unlockableAt, uint menPrice, uint stakeValue, uint timestamp);
  event StakedViaLP(address indexed user, uint lpAmount, uint duration, uint unlockableAt, uint menPrice, uint stakeValue, uint timestamp);
  event UnActivated(address indexed user);
  event TokenFunded(address indexed user, uint round, uint amount, uint timestamp);
  event UnstakedLP(address indexed user, uint lpAmount, uint timestamp);
  event UnstakedToken(address indexed user, uint lpAmount, uint menTokenOut, uint usdtTokenOut, uint timestamp);

  function initialize() public initializer {
    BaseContract.init();
    __ReentrancyGuard_init();
    config.secondsInADay = 86_400;
    for (uint i = 0; i < 5; i++) {
      uint duration = (i + 1) * 30;
      uint shareRate = (i + 1) * 1000;
      config.baseStakeRate[duration] = shareRate;
      emit BaseStakingRateUpdated(duration, shareRate);
    }
    config.bonusRates = [20000, 15000, 10000, 5000];
    emit BonusRateUpdated(config.bonusRates);
    minStakingDuration = 60;
    config.refLevels = 20;
    config.refBonusPercentages = [0, 300, 200, 100, 50, 50, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  }

  function addAndStake(uint _usdtAmount, uint _duration) external notInCheckinPeriod {
    uint stakeValue = _usdtAmount * POOL_VALUE_RATIO;
    require(stakeValue >= config.minStakeAmount, "LSDfi: insufficient usdt amount");
    User storage user = users[msg.sender];
    _validateUserOut(user);
    uint tokenPrice = vault.getTokenPrice();
    uint menNeededAmount = _usdtAmount * DECIMAL9 / tokenPrice;
    _takeToken(menToken, menNeededAmount);
    _takeToken(usdtToken, _usdtAmount);
    _assignStakingInfo(user, _duration, stakeValue);
    uint lpBalanceBefore = lpToken.balanceOf(address(this));
    uniswapV2Router.addLiquidity(
      address(menToken),
      address(usdtToken),
      menNeededAmount,
      _usdtAmount,
      0,
      0,
      address(this),
      block.timestamp
    );
    user.totalLPStaked += lpToken.balanceOf(address(this)) - lpBalanceBefore;
    emit StakedViaToken(msg.sender, _usdtAmount, menNeededAmount, _duration, user.unlockableAt, tokenPrice, stakeValue, block.timestamp);
  }

  function stake(uint _lpAmount, uint _duration) external notInCheckinPeriod {
    uint stakeValue = getStakeAmount(_lpAmount);
    require(stakeValue >= config.minStakeAmount, "LSDfi: insufficient stake amount");
    User storage user = users[msg.sender];
    _validateUserOut(user);
    _takeToken(lpToken, _lpAmount);
    _assignStakingInfo(user, _duration, stakeValue);
    user.totalLPStaked += _lpAmount;
    emit StakedViaLP(msg.sender, _lpAmount, _duration, user.unlockableAt, vault.getTokenPrice(), stakeValue, block.timestamp);
  }

  function renew(uint _duration) external notInCheckinPeriod {
    User storage user = users[msg.sender];
    require(user.stakedAt > 0, "LSDfi: not staked yet");
    require(user.unlockableAt < block.timestamp, "LSDfi: still locked");
    _validateUserOut(user);
    _validateNewDuration(user, _duration);
    _reloadStakeTime(user, _duration);
    user.activated = true;
    user.shares = (user.totalStaked * config.baseStakeRate[_duration] / DECIMAL3) * (ONE_HUBDRED_DECIMAL3 + getBonusRate()) / ONE_HUBDRED_DECIMAL3;
    user.bonusRates = [_getRate(_duration)];
   emit ReNewed(msg.sender, _duration, block.timestamp);
  }

  function unstake(bool _getLP) external nonReentrant {
    User storage user = users[msg.sender];
    require(user.stakedAt > 0, "LSDfi: not staked yet");
    require(user.unlockableAt < block.timestamp, "LSDfi: still locked");
    user.activated = false;
    user.stakedAt = 0;
    user.unlockableAt = 0;
    user.totalStaked = 0;
    user.shares = 0;
    uint lpAmount = user.totalLPStaked;
    user.totalLPStaked = 0;
    delete user.bonusRates;
    if (_getLP) {
      lpToken.transfer(msg.sender, lpAmount);
      emit UnstakedLP(msg.sender, lpAmount, block.timestamp);
    } else {
      (uint menTokenOut, uint usdtTokenOut) = uniswapV2Router.removeLiquidity(
        address(menToken),
        address(usdtToken),
        lpAmount,
        0,
        0,
        address(this),
        block.timestamp
      );
      menToken.transfer(msg.sender, menTokenOut);
      usdtToken.transfer(msg.sender, usdtTokenOut);
      emit UnstakedToken(msg.sender, lpAmount, menTokenOut, usdtTokenOut, block.timestamp);
    }
    systemData.totalStakedValue -= getStakeAmount(lpAmount);
    systemData.totalMember--;
  }

  function checkin() external inCheckinPeriod {
    require(config.zeroTimestamp > 0, "LSDfi: not started yet");
    uint currentRound = getCurrentRound();
    uint checkinRound = currentRound > 0 ? currentRound - 1 : 0;
    User storage user = users[msg.sender];
    _validateUserOut(user);
    if (user.unlockableAt < block.timestamp) {
      user.activated = false;
      emit CheckinFailed(msg.sender, checkinRound, block.timestamp);
      return;
    }
    require(user.checkInShares[checkinRound] == 0, "LSDfi: already checked in");
    user.checkInShares[checkinRound] += user.shares;
    rounds[checkinRound].totalShares += user.shares;
    emit CheckedIn(msg.sender, checkinRound, user.shares, block.timestamp);
  }

  function claimReward(uint _round) external nonReentrant notInCheckinPeriod {
    User storage user = users[msg.sender];
    _validateUserOut(user);
    require(user.unlockableAt > block.timestamp, "LSDfi: not activated yet");
    require(user.checkInShares[_round] > 0, "LSDfi: no reward");
    require(!user.freezeReward, "LSDfi: reward frozen");
    uint userReward = rounds[_round].totalReward * 3 / 4 * user.checkInShares[_round] / rounds[_round].totalShares;
    user.checkInShares[_round] = 0;
    menToken.transfer(msg.sender, userReward);
    _calculateRereferralReward(msg.sender, userReward * 4 / 3);
    systemData.totalClaimed += userReward;
    emit RewardClaimed(msg.sender, _round, userReward, block.timestamp);
  }

  function claimAffiliateReward() external nonReentrant {
    User storage user = users[msg.sender];
    _validateUserOut(user);
    if (!user.leader) {
      require(user.unlockableAt > block.timestamp, "LSDfi: not activated yet");
    }
    require(user.referralReward > 0, "LSDfi: no reward");
    require(!user.freezeReferral, "LSDfi: referral reward frozen");
    uint reward = user.referralReward;
    user.referralReward = 0;
    menToken.transfer(msg.sender, reward);
    systemData.totalClaimed += reward;
    emit ReferralRewardClaimed(msg.sender, reward, block.timestamp);
  }

  function fund(uint _amount) external {
    _takeToken(menToken, _amount);
    uint currentRound = getCurrentRound() - 1;
    rounds[currentRound].totalReward += _amount;
    emit TokenFunded(msg.sender, currentRound, _amount, block.timestamp);
  }

  function getCurrentRound() public view returns (uint) {
    return (block.timestamp - config.zeroTimestamp) / (CHECKIN_INTERVAL * config.secondsInADay);
  }

  function getUserCheckinShares(address _user, uint _round) external view returns (uint) {
    return users[_user].checkInShares[_round];
  }

  function getUserBonusRate(address _user) external view returns (uint) {
    uint totalBonusRate;
    for (uint i = 0; i < users[_user].bonusRates.length; i++) {
      totalBonusRate += users[_user].bonusRates[i];
    }
    if (users[_user].bonusRates.length == 0) {
      return 0;
    }
    return totalBonusRate / users[_user].bonusRates.length;
  }

  function getUserBonusRates(address _user) external view returns (uint[] memory) {
    return users[_user].bonusRates;
  }

  function getBonusRate() public view returns (uint) {
    uint currentRound = getCurrentRound();
    uint currentDateInRound = (block.timestamp - (config.zeroTimestamp + currentRound * CHECKIN_INTERVAL * config.secondsInADay)) / config.secondsInADay + 1;
    if (currentDateInRound > 21) {
      return config.bonusRates[3];
    } else if (currentDateInRound > 14) {
      return config.bonusRates[2];
    } else if (currentDateInRound > 7) {
      return config.bonusRates[1];
    }
    return config.bonusRates[0];
  }

  function getStakeAmount(uint _lpAmount) public view returns (uint) {
    uint usdtBalance = usdtToken.balanceOf(address(lpToken)); // 10041004034198
    uint amountRate = _lpAmount * 1e18 / lpToken.totalSupply();
    return usdtBalance * POOL_VALUE_RATIO * amountRate / 1e18;
  }

  function getArrayConfigs() external view returns (uint[4] memory bonusRates, uint[] memory refBonusPercentages) {
    return (config.bonusRates, config.refBonusPercentages);
  }

  function getBaseStakeRate(uint _duration) external view returns (uint) {
    return config.baseStakeRate[_duration];
  }

  // AUTH FUNCTIONS

  function start() external onlyMn {
    config.zeroTimestamp = 1723248000;
  }

  function updateConfig(uint _secondsInADay, address _treasury, uint _minStakeAmount, uint _minStakeDurationForRefBonus) external onlyMn {
    require(_minStakeDurationForRefBonus >= minStakingDuration, "LSDfi: minStakeDurationForRefBonus invalid");
    require(citizen.isCitizen(_treasury), "LSDfi: treasury invalid");
    config.secondsInADay = _secondsInADay;
    config.treasury = _treasury;
    config.minStakeAmount = _minStakeAmount;
    config.minStakeDurationForRefBonus = _minStakeDurationForRefBonus;
    emit ConfigUpdated(_secondsInADay, _treasury, _minStakeAmount, _minStakeDurationForRefBonus);
  }

  function updateRefConfig(uint _refLevels, uint[] calldata _refBonusPercentages) external onlyMn {
    require(_refLevels > 0 && _refLevels <= 30, "LSDfi: _refLevels invalid");
    uint totalPercentage;
    for (uint i = 0; i < _refBonusPercentages.length; i++) {
      totalPercentage += _refBonusPercentages[i];
    }
    require(totalPercentage == DECIMAL3 / 4, "LSDfi: invalid total ref bonus percentage");
    config.refLevels = _refLevels;
    config.refBonusPercentages = _refBonusPercentages;
    emit RefConfigUpdated(_refLevels, _refBonusPercentages);
  }

  function updateBonusRates(uint[4] calldata _bonusRates) external onlyMn {
    config.bonusRates = _bonusRates;
    emit BonusRateUpdated(_bonusRates);
  }

  function updateBaseStakingRate(uint _duration, uint _shareRate) external onlyMn {
    if (_duration < minStakingDuration) {
      minStakingDuration = _duration;
    }
    config.baseStakeRate[_duration] = _shareRate;
    emit BaseStakingRateUpdated(_duration, _shareRate);
  }

  function unActive(address _address) external onlyMn {
    users[_address].activated = false;
    users[_address].unlockableAt = block.timestamp;
    users[_address].out = true;
    emit UnActivated(_address);
  }

  function freezeReward(address _address, bool _status) external onlyMn {
    users[_address].freezeReward = _status;
  }

  function freezeReferral(address _address, bool _status) external onlyMn {
    users[_address].freezeReferral = _status;
  }

  function setLeader(address _address, bool _status) external onlyMn {
    users[_address].leader = _status;
    emit LeaderSet(_address, _status);
  }

  // PRIVATE FUNCTIONS

  function _getCheckinRound() private view returns (uint) {
    uint currentRound = getCurrentRound();
    return currentRound > 0 ? currentRound - 1 : 0;
  }

  function _calculateRereferralReward(address _userAddress, uint _reward) private {
    address[31] memory refAddresses;
    uint[31] memory refAmounts;
    address inviterAddress;
    address senderAddress = _userAddress;
    uint refBonusAmount;
    uint treasuryBonusAmount = 0;
    User storage inviter;
    for (uint i = 1; i <= config.refLevels; i++) {
      inviterAddress = citizen.getInviter(_userAddress);
      if (inviterAddress == address(0)) {
        break;
      }
      refBonusAmount = (_reward * config.refBonusPercentages[i] / DECIMAL3);
      inviter = users[inviterAddress];
      uint currentDuration = _getUserCurrentDuration(inviter);
      if (inviter.activated && inviter.unlockableAt < block.timestamp) {
        inviter.activated = false;
      }
      if (
        (inviter.leader || (inviter.activated && currentDuration >= config.minStakeDurationForRefBonus)) && 
        (i == 1 || vault.getUserLevel(inviterAddress) >= i) &&
        (inviterAddress != config.treasury)
      ) {
        refAddresses[i - 1] = inviterAddress;
        refAmounts[i - 1] = refBonusAmount;
        inviter.referralReward += refBonusAmount;
      } else {
        treasuryBonusAmount += refBonusAmount;
      }
      _userAddress = inviterAddress;
    }
    if (treasuryBonusAmount > 0 && users[config.treasury].activated) {
      users[config.treasury].referralReward += treasuryBonusAmount;
      refAddresses[30] = config.treasury;
      refAmounts[30] = treasuryBonusAmount;
    }
    emit RefBonusSent(refAddresses, refAmounts, block.timestamp, senderAddress);
  }

  function _getUserCurrentDuration(User storage _user) private view returns (uint) {
    return (_user.unlockableAt - _user.stakedAt) / config.secondsInADay;
  }

  function _reloadStakeTime(User storage _user, uint _duration) private {
    _user.stakedAt = block.timestamp;
    _user.unlockableAt = _user.stakedAt + _duration * config.secondsInADay;
  }

  function _takeToken(IBEP20 _token, uint _amount) private {
    require(_token.allowance(msg.sender, address(this)) >= _amount, "LSDfi: allowance invalid");
    require(_token.balanceOf(msg.sender) >= _amount, "LSDfi: insufficient balance");
    _token.transferFrom(msg.sender, address(this), _amount);
  }

  function _validateNewDuration(User storage _user, uint _duration) private view {
    require(_duration >= _getUserCurrentDuration(_user) && config.baseStakeRate[_duration] > 0, "LSDfi: invalid new duration");
  }

  function _assignStakingInfo(User storage _user, uint _duration, uint _stakeValue) private {
    if (_user.stakedAt == 0) {
      require(config.baseStakeRate[_duration] > 0, "LSDfi: invalid duration");
      _reloadStakeTime(_user, _duration);
      _user.totalStaked = _stakeValue;
      systemData.totalMember++;
    } else {
      _validateNewDuration(_user, _duration);
      _reloadStakeTime(_user, _duration);
      _user.totalStaked += _stakeValue;
    }
    uint additionalShares = (_stakeValue * config.baseStakeRate[_duration] / DECIMAL3) * (ONE_HUBDRED_DECIMAL3 + getBonusRate()) / ONE_HUBDRED_DECIMAL3;
    _user.shares += additionalShares;
    _user.bonusRates.push(_getRate(_duration));
    if (_user.joinAt == 0) {
      _user.joinAt = block.timestamp;
    }
    _user.activated = true;
    systemData.totalStakedValue += _stakeValue;
  }

  function _getRate(uint _duration) private view returns (uint) {
    uint base = config.baseStakeRate[_duration] * 100;
    return (base + base * getBonusRate() / ONE_HUBDRED_DECIMAL3) / 100;
  }

  function _validateUserOut(User storage _user) private view {
    require(!_user.out, "LSDfi: user out");
  }

  function _initDependentContracts() override internal {
    citizen = ICitizen(addressBook.get("citizen"));
    uniswapV2Router = IUniswapV2Router02(addressBook.get("uniswapV2Router"));
    menToken = IBEP20(addressBook.get("menToken"));
    menToken.approve(address(uniswapV2Router), type(uint).max);
    usdtToken = IBEP20(addressBook.get("usdtToken"));
    usdtToken.approve(address(uniswapV2Router), type(uint).max);
    lpToken = ILPToken(addressBook.get("lpToken"));
    lpToken.approve(address(uniswapV2Router), type(uint).max);
    vault = IVault(addressBook.get("vault"));
  }
}
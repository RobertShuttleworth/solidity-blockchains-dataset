// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import './openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol';
import './openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol';

import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol';

import './contracts_util_ProxyAdminManagerUpgradeable.sol';

contract TkoStaking is
  Initializable,
  UUPSUpgradeable,
  OwnableUpgradeable,
  PausableUpgradeable,
  ProxyAdminManagerUpgradeable
{
  using SafeERC20 for IERC20Metadata;

  uint256 internal constant yearInSeconds = 365 * 86400;

  uint128 public minStaking;
  uint64 public lockNumber;
  uint64 public workerNumber;

  address[] public staker;

  bool public isUnstakePaused;

  address public dev;
  address public tkoToken;
  address public burnedTkoCollector;
  address public savior; // crucial feature

  enum CompoundTypes {
    NoCompound,
    PrincipalOnly,
    PrincipalAndReward
  }

  struct Lock {
    uint128 lockPeriodInSeconds;
    uint64 apy_d2;
    uint64 feeInPercent_d2;
    uint256 tkoStaked;
    uint256 pendingReward;
  }

  struct Stake {
    uint64 lockIndex;
    uint184 userStakedIndex;
    CompoundTypes compoundType;
    uint256 amount;
    uint256 reward;
    uint128 stakedAt;
    uint128 endedAt;
  }

  struct StakeData {
    uint256 stakedAmount;
    uint256 stakerPendingReward;
  }

  mapping(address => Stake[]) internal staked;
  mapping(address => uint184) internal stakerIndex;
  mapping(uint64 => Lock) internal lock;

  mapping(address => bool) public isWorker;
  mapping(address => bool) public isTrustedForwarder;

  mapping(address => StakeData) public stakerDetail;
  mapping(address => address) public pendingStakership;
  mapping(address => address) public originStakership;

  /* ========== EVENTS ========== */
  event Staked(
    address stakerAddress,
    uint128 lockPeriodInDays,
    CompoundTypes compoundType,
    uint256 amount,
    uint256 reward,
    uint128 stakedAt,
    uint128 endedAt
  );
  event Unstaked(
    address stakerAddress,
    uint128 lockPeriodInDays,
    CompoundTypes compoundType,
    uint256 amount,
    uint256 reward,
    uint256 prematurePenalty,
    uint128 stakedAt,
    uint128 endedAt,
    uint128 unstakedAt,
    bool isPremature
  );

  function init(
    address _tkoToken,
    uint128[] calldata _lockPeriodInDays,
    uint64[] calldata _apy_d2,
    uint64[] calldata _feeInPercent_d2,
    address _savior
  ) external initializer proxied {
    __UUPSUpgradeable_init();
    __Pausable_init();
    __Ownable_init(_msgSender());
    __ProxyAdminManager_init(_msgSender());

    require(
      _lockPeriodInDays.length == _apy_d2.length &&
        _lockPeriodInDays.length == _feeInPercent_d2.length &&
        _tkoToken != address(0) &&
        _savior != address(0),
      'misslength'
    );

    tkoToken = _tkoToken;
    lockNumber = uint64(_lockPeriodInDays.length);
    savior = _savior;

    uint64 i;
    do {
      lock[i] = Lock({
        lockPeriodInSeconds: _lockPeriodInDays[i] * 86400,
        apy_d2: _apy_d2[i],
        feeInPercent_d2: _feeInPercent_d2[i],
        tkoStaked: 0,
        pendingReward: 0
      });

      ++i;
    } while (i < _lockPeriodInDays.length);

    minStaking = uint128(10 * (10 ** IERC20Metadata(_tkoToken).decimals()));
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override proxied {}

  function _onlySavior() internal view virtual {
    require(_msgSender() == savior, '!savior');
  }

  function _onlyEligible() internal view virtual {
    require(_msgSender() == dev || _msgSender() == savior || _msgSender() == owner(), '!eligible');
  }

  function totalPendingReward() external view virtual returns (uint256 total) {
    for (uint64 i = 0; i < lockNumber; ++i) {
      total += lock[i].pendingReward;
    }
  }

  function totalKomStaked() external view virtual returns (uint256 total) {
    for (uint64 i = 0; i < lockNumber; ++i) {
      total += lock[i].tkoStaked;
    }
  }

  function stakerLength() external view virtual returns (uint256 length) {
    length = staker.length;
  }

  function locked(
    uint64 _lockIndex
  )
    external
    view
    virtual
    returns (uint128 lockPeriodInDays, uint64 apy_d2, uint64 feeInPercent_d2, uint256 tkoStaked, uint256 pendingReward)
  {
    lockPeriodInDays = lock[_lockIndex].lockPeriodInSeconds / 86400;
    apy_d2 = lock[_lockIndex].apy_d2;
    feeInPercent_d2 = lock[_lockIndex].feeInPercent_d2;
    tkoStaked = lock[_lockIndex].tkoStaked;
    pendingReward = lock[_lockIndex].pendingReward;
  }

  function userStakedLength(address _staker) public view virtual returns (uint256 length) {
    length = staked[_staker].length;
  }

  function getStakedDetail(
    address _staker,
    uint184 _userStakedIndex
  )
    external
    view
    virtual
    returns (
      uint128 lockPeriodInDays,
      CompoundTypes compoundType,
      uint256 amount,
      uint256 reward,
      uint256 prematurePenalty,
      uint128 stakedAt,
      uint128 endedAt
    )
  {
    // get stake data
    Stake memory stakeDetail = staked[_staker][_userStakedIndex];

    lockPeriodInDays = lock[stakeDetail.lockIndex].lockPeriodInSeconds / 86400;
    compoundType = stakeDetail.compoundType;
    amount = stakeDetail.amount;
    reward = stakeDetail.reward;
    prematurePenalty = (stakeDetail.amount * lock[stakeDetail.lockIndex].feeInPercent_d2) / 10000;
    stakedAt = stakeDetail.stakedAt;
    endedAt = stakeDetail.endedAt;
  }

  function getTotalWithdrawableTokens(address _staker) external view virtual returns (uint256 withdrawableTokens) {
    for (uint184 i = 0; i < staked[_staker].length; ++i) {
      if (staked[_staker][i].endedAt >= block.timestamp) continue;
      withdrawableTokens += staked[_staker][i].amount + staked[_staker][i].reward;
    }
  }

  function getTotalLockedTokens(address _staker) external view virtual returns (uint256 lockedTokens) {
    for (uint184 i = 0; i < staked[_staker].length; ++i) {
      if (staked[_staker][i].endedAt < block.timestamp) continue;
      lockedTokens += staked[_staker][i].amount + staked[_staker][i].reward;
    }
  }

  function getUserNextUnlock(
    address _staker
  ) external view virtual returns (uint128 nextUnlockTime, uint256 nextUnlockRewards) {
    for (uint184 i = 0; i < staked[_staker].length; ++i) {
      Stake memory stakeDetail = staked[_staker][i];

      if (stakeDetail.endedAt < block.timestamp) continue;
      if (nextUnlockTime > 0 && (nextUnlockTime <= stakeDetail.endedAt)) continue;

      nextUnlockTime = stakeDetail.endedAt;
      nextUnlockRewards = stakeDetail.reward;
    }
  }

  function getUserStakedTokensBeforeDate(
    address _staker,
    uint128 _beforeAt
  ) external view virtual returns (uint256 lockedTokens) {
    for (uint184 i = 0; i < staked[_staker].length; ++i) {
      Stake memory stakeDetail = staked[_staker][i];
      if (stakeDetail.stakedAt > _beforeAt) continue;
      lockedTokens += stakeDetail.amount;
    }
  }

  function getTotalStakedAmountBeforeDate(uint128 _beforeAt) external view virtual returns (uint256 totalStaked) {
    for (uint256 i = 0; i < staker.length; ++i) {
      for (uint184 j = 0; j < staked[staker[i]].length; ++j) {
        if (staked[staker[i]][j].stakedAt > _beforeAt) continue;
        totalStaked += staked[staker[i]][j].amount;
      }
    }
  }

  function calculateReward(uint256 _amount, uint64 _lockIndex) public view virtual returns (uint256 reward) {
    Lock memory lockDetail = lock[_lockIndex];

    uint256 effectiveAPY = lockDetail.apy_d2 * lockDetail.lockPeriodInSeconds;
    reward = (_amount * effectiveAPY) / (yearInSeconds * 10000);
  }

  function _msgSender() internal view virtual override returns (address sender) {
    if (!isTrustedForwarder[msg.sender]) {
      return super._msgSender();
    }

    // The assembly code is more direct than the Solidity version using `abi.decode`.
    /// @solidity memory-safe-assembly
    assembly {
      sender := shr(96, calldataload(sub(calldatasize(), 20)))
    }
  }

  function _msgData() internal view virtual override returns (bytes calldata) {
    if (!isTrustedForwarder[msg.sender]) {
      return super._msgData();
    }

    return msg.data[:msg.data.length - 20];
  }

  function getStakerIndex(address _staker) external view virtual returns (uint184) {
    return stakerIndex[_staker];
  }

  function _stake(address _sender, uint256 _amount, uint64 _lockIndex, CompoundTypes _compoundType) internal virtual {
    require(
      _lockIndex < lockNumber, // validate existance of lock index
      '!lockIndex'
    );

    // calculate reward
    uint256 reward = calculateReward(_amount, _lockIndex);

    // add staked amount & pending reward to sender
    stakerDetail[_sender].stakedAmount += _amount;
    stakerDetail[_sender].stakerPendingReward += reward;

    // add tkoStaked & pending reward to lock index
    lock[_lockIndex].tkoStaked += _amount;
    lock[_lockIndex].pendingReward += reward;

    // push stake struct to staked mapping
    staked[_sender].push(
      Stake({
        lockIndex: _lockIndex,
        userStakedIndex: uint184(staked[_sender].length),
        compoundType: _compoundType,
        amount: _amount,
        reward: reward,
        stakedAt: uint128(block.timestamp),
        endedAt: uint128(block.timestamp) + lock[_lockIndex].lockPeriodInSeconds
      })
    );

    // emit staked event
    emit Staked(
      _sender,
      lock[_lockIndex].lockPeriodInSeconds / 86400,
      _compoundType,
      _amount,
      reward,
      uint128(block.timestamp),
      uint128(block.timestamp) + lock[_lockIndex].lockPeriodInSeconds
    );
  }

  function _compound(
    address _sender,
    uint256 _amount,
    uint64 _lockIndex,
    CompoundTypes _compoundType
  ) internal virtual {
    if (_compoundType == CompoundTypes.PrincipalOnly) {
      _stake(_sender, _amount, _lockIndex, _compoundType);
    } else if (_compoundType == CompoundTypes.PrincipalAndReward) {
      uint256 reward = calculateReward(_amount, _lockIndex);
      _stake(_sender, _amount + reward, _lockIndex, _compoundType);
    }
  }

  function _unstake(address _sender, uint184 _userStakedIndex, bool _isPremature) internal virtual {
    // get stake data
    Stake memory stakeDetail = staked[_sender][_userStakedIndex];

    // subtract staked amount & pending reward to sender
    stakerDetail[_sender].stakedAmount -= stakeDetail.amount;
    stakerDetail[_sender].stakerPendingReward -= stakeDetail.reward;

    // subtract tkoStaked & pending reward to lock index
    lock[stakeDetail.lockIndex].tkoStaked -= stakeDetail.amount;
    lock[stakeDetail.lockIndex].pendingReward -= stakeDetail.reward;

    // shifts struct from lastIndex to currentIndex & pop lastIndex from staked mapping
    staked[_sender][_userStakedIndex] = staked[_sender][staked[_sender].length - 1];
    staked[_sender][_userStakedIndex].userStakedIndex = _userStakedIndex;
    staked[_sender].pop();

    // remove staker if eligible
    if (staked[_sender].length == 0 && staker[stakerIndex[_sender]] == _sender) {
      uint184 indexToDelete = stakerIndex[_sender];
      address stakerToMove = staker[staker.length - 1];

      staker[indexToDelete] = stakerToMove;
      stakerIndex[stakerToMove] = indexToDelete;

      delete stakerIndex[_sender];
      staker.pop();
    }

    // set withdrawable amount to transfer
    uint256 withdrawableAmount = stakeDetail.amount + stakeDetail.reward;

    if (_isPremature) {
      // calculate penalty & staked amount to withdraw
      uint256 penaltyAmount = (stakeDetail.amount * lock[stakeDetail.lockIndex].feeInPercent_d2) / 10000;
      withdrawableAmount = stakeDetail.amount - penaltyAmount;

      // burn penalty
      _burnToken(tkoToken, penaltyAmount);
    } else {
      if (stakeDetail.compoundType == CompoundTypes.PrincipalOnly) {
        withdrawableAmount = stakeDetail.reward;
      } else if (stakeDetail.compoundType == CompoundTypes.PrincipalAndReward) {
        emit Unstaked(
          _sender,
          lock[stakeDetail.lockIndex].lockPeriodInSeconds / 86400,
          stakeDetail.compoundType,
          stakeDetail.amount,
          stakeDetail.reward,
          0,
          stakeDetail.stakedAt,
          stakeDetail.endedAt,
          uint128(block.timestamp),
          _isPremature
        );
        return;
      }
    }

    // send staked + reward to sender
    IERC20Metadata(tkoToken).safeTransfer(_sender, withdrawableAmount);

    // emit unstaked event
    emit Unstaked(
      _sender,
      lock[stakeDetail.lockIndex].lockPeriodInSeconds / 86400,
      stakeDetail.compoundType,
      stakeDetail.amount,
      stakeDetail.reward,
      _isPremature ? (stakeDetail.amount * lock[stakeDetail.lockIndex].feeInPercent_d2) / 10000 : 0,
      stakeDetail.stakedAt,
      stakeDetail.endedAt,
      uint128(block.timestamp),
      _isPremature
    );
  }

  function _burnToken(address _token, uint256 _amount) internal virtual {
    IERC20Metadata(_token).safeTransfer(burnedTkoCollector, _amount);
  }

  function _transferStakership(address _oldStakerAddress, address _newStakerAddress) internal virtual {
    // get index
    uint256 index = stakerIndex[_oldStakerAddress];

    // assign old data to new staker address
    staker[index] = _newStakerAddress;
    stakerIndex[_newStakerAddress] = uint184(index);
    stakerDetail[_newStakerAddress] = stakerDetail[_oldStakerAddress];
    staked[_newStakerAddress] = staked[_oldStakerAddress];

    // remove old data
    delete stakerIndex[_oldStakerAddress];
    delete stakerDetail[_oldStakerAddress];
    delete staked[_oldStakerAddress];
  }

  function stake(uint256 _amount, uint64 _lockIndex, CompoundTypes _compoundType) external virtual whenNotPaused {
    require(
      _amount >= minStaking, // validate min amount to stake
      '<min'
    );

    // fetch sender
    address sender = _msgSender();

    // push staker if eligible
    if (staked[sender].length == 0) {
      staker.push(sender);
      stakerIndex[sender] = uint184(staker.length - 1);
    }

    // stake
    _stake(sender, _amount, _lockIndex, _compoundType);

    // take out tkoToken
    IERC20Metadata(tkoToken).safeTransferFrom(sender, address(this), _amount);
  }

  function unstake(uint184 _userStakedIndex, uint256 _amount, address _staker) external virtual {
    require(!isUnstakePaused, 'paused');

    // worker check
    if (isWorker[_msgSender()]) {
      require(block.timestamp > staked[_staker][_userStakedIndex].endedAt, 'premature');
    } else {
      _staker = _msgSender();
    }

    // validate existance of staker stake index
    require(staked[_staker].length > _userStakedIndex, 'bad');

    // get stake data
    Stake memory stakeDetail = staked[_staker][_userStakedIndex];

    if (block.timestamp > stakeDetail.endedAt) {
      _amount = stakeDetail.amount;
      // compound
      _compound(_staker, _amount, stakeDetail.lockIndex, stakeDetail.compoundType);
    } else if (stakeDetail.amount > _amount) {
      uint256 remainderAmount = stakeDetail.amount - _amount;

      // stake remainder
      _stake(_staker, remainderAmount, stakeDetail.lockIndex, stakeDetail.compoundType);

      // adjust new staking amount to be partially withdrawn
      uint256 newPartialReward = calculateReward(_amount, stakeDetail.lockIndex);
      staked[_staker][_userStakedIndex].amount = _amount;
      staked[_staker][_userStakedIndex].reward = newPartialReward;

      // subtract staked amount & pending reward to staker
      stakerDetail[_staker].stakedAmount -= remainderAmount;
      stakerDetail[_staker].stakerPendingReward -= (stakeDetail.reward - newPartialReward);

      // subtract tkoStaked & pending reward to lock index
      lock[stakeDetail.lockIndex].tkoStaked -= remainderAmount;
      lock[stakeDetail.lockIndex].pendingReward -= (stakeDetail.reward - newPartialReward);
    }

    // unstake
    _unstake(_staker, _userStakedIndex, stakeDetail.endedAt >= block.timestamp);
  }

  function changeCompoundType(uint184 _userStakedIndex, CompoundTypes _newCompoundType) external virtual {
    // owner validation
    address _staker = _msgSender();

    // get stake data
    Stake memory stakeDetail = staked[_staker][_userStakedIndex];

    require(
      staked[_staker].length > _userStakedIndex && // user staked index validation
        stakeDetail.compoundType != _newCompoundType, // compound type validation
      'bad'
    );

    // assign new compound type
    staked[_staker][_userStakedIndex].compoundType = _newCompoundType;
  }

  function acceptStakerShip() external virtual {
    address sender = _msgSender();

    // get origin
    address originStaker = originStakership[sender];

    // get pending
    address pendingStaker = pendingStakership[originStaker];

    require(pendingStaker == sender, '!pendingStaker');

    // shifting old address to new address
    _transferStakership(originStaker, pendingStaker);
    delete originStakership[sender];
    delete pendingStakership[originStaker];
  }

  function transferStakership(address _newStakerAddress) external virtual {
    address stakerAddress = _msgSender();

    require(userStakedLength(stakerAddress) > 0 && userStakedLength(_newStakerAddress) == 0, '!staker');

    // delete oldPendingStaker if exists
    address currentPendingStakership = pendingStakership[stakerAddress];
    if (originStakership[currentPendingStakership] == stakerAddress) delete originStakership[currentPendingStakership];

    // save to pendingStakership
    pendingStakership[stakerAddress] = _newStakerAddress;
    originStakership[_newStakerAddress] = stakerAddress;
  }

  function addWorker(address _worker) external virtual onlyOwner {
    require(_worker != address(0) && !isWorker[_worker], 'bad');
    isWorker[_worker] = true;
    ++workerNumber;
  }

  function removeWorker(address _worker) external virtual onlyOwner {
    require(_worker != address(0) && isWorker[_worker], 'bad');
    isWorker[_worker] = false;
    --workerNumber;
  }

  function changeWorker(address _oldWorker, address _newWorker) external virtual onlyOwner {
    require(
      _oldWorker != address(0) && _newWorker != address(0) && isWorker[_oldWorker] && !isWorker[_newWorker],
      'bad'
    );
    isWorker[_oldWorker] = false;
    isWorker[_newWorker] = true;
  }

  function toggleTrustedForwarder(address _forwarder) external virtual onlyOwner {
    require(_forwarder != address(0), '0x0');
    isTrustedForwarder[_forwarder] = !isTrustedForwarder[_forwarder];
  }

  function setMinStaking(uint128 _minStaking) external virtual whenPaused onlyOwner {
    require(_minStaking > 0 && minStaking != _minStaking, 'bad');

    minStaking = _minStaking;
    _unpause();
  }

  function setPeriodInDays(uint64 _lockIndex, uint128 _newLockPeriodInDays) external virtual onlyOwner {
    require(lockNumber > _lockIndex && _newLockPeriodInDays >= 1 && _newLockPeriodInDays <= (5 * 365), 'bad');
    lock[_lockIndex].lockPeriodInSeconds = _newLockPeriodInDays * 86400;
  }

  function setPenaltyFee(uint64 _lockIndex, uint64 _feeInPercent_d2) external virtual onlyOwner {
    require(lockNumber > _lockIndex && _feeInPercent_d2 >= 100 && _feeInPercent_d2 < 10000, 'bad');
    lock[_lockIndex].feeInPercent_d2 = _feeInPercent_d2;
  }

  function setAPY(uint64 _lockIndex, uint64 _apy_d2) external virtual onlyOwner {
    require(lockNumber > _lockIndex && _apy_d2 < 10000, 'bad');
    lock[_lockIndex].apy_d2 = _apy_d2;
  }

  function setSavior(address _savior) external virtual onlyOwner {
    require(_savior != address(0) && savior != _savior && _savior != dev, 'bad');
    savior = _savior;
  }

  function setDev(address _dev) external virtual onlyOwner {
    require(_dev != address(0) && dev != _dev && _dev != savior, 'bad');
    dev = _dev;
  }

  function setBurnedTkoCollector(address _burnedTkoCollector) external virtual onlyOwner {
    require(_burnedTkoCollector != address(0) && burnedTkoCollector != _burnedTkoCollector, '0x0');
    burnedTkoCollector = _burnedTkoCollector;
  }

  function togglePause() external virtual {
    _onlyEligible();
    if (paused()) {
      _unpause();
    } else {
      _pause();
    }
  }

  function toggleUnstakePause() external virtual {
    _onlyEligible();
    isUnstakePaused = !isUnstakePaused;
  }

  function emergencyWithdraw(address _token, uint256 _amount, address _receiver) external virtual {
    _onlySavior();

    // adjust amount to wd
    uint256 balance = IERC20Metadata(_token).balanceOf(address(this));
    if (_amount > balance) _amount = balance;

    IERC20Metadata(_token).safeTransfer(_receiver, _amount);
  }
}
// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_utils_SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_security_ReentrancyGuardUpgradeable.sol";

import { IHMXStaking } from "./src_staking_interfaces_IHMXStaking.sol";
import { IStakingLocker } from "./src_staking_interfaces_IStakingLocker.sol";

contract StakingLocker is OwnableUpgradeable, ReentrancyGuardUpgradeable, IStakingLocker {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IHMXStaking public hmxStaking;
  mapping(address stakingToken => uint256 cooldownPeriod) public unstakingCooldownPeriod;
  mapping(address user => mapping(uint256 index => UnstakingPosition position))
    public unstakingPositions;
  mapping(address => uint256) public unstakingPositionLastIndex;

  function initialize(address _hmxStaking) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    hmxStaking = IHMXStaking(_hmxStaking);
  }

  modifier onlyHmxStaking() {
    if (address(hmxStaking) != msg.sender) revert StakingLocker_Unauthorized();
    _;
  }

  function setUnstakingCooldownPeriod(
    address _stakingToken,
    uint256 _cooldownPeriod
  ) external onlyOwner {
    emit LogSetUnstakingCooldownPeriod(_stakingToken, _cooldownPeriod);
    unstakingCooldownPeriod[_stakingToken] = _cooldownPeriod;
  }

  function lock(address account, address stakingToken, uint256 amount) external onlyHmxStaking {
    if (amount == 0) return;

    UnstakingPosition memory position = UnstakingPosition({
      token: stakingToken,
      amount: amount,
      lockEndTimestamp: block.timestamp + unstakingCooldownPeriod[stakingToken],
      status: UnstakingStatus.Cooldown
    });

    uint256 positionIndex = unstakingPositionLastIndex[account];
    unstakingPositions[account][positionIndex] = position;
    unstakingPositionLastIndex[account]++;

    IERC20Upgradeable(position.token).transferFrom(msg.sender, address(this), amount);

    emit LogLock(account, stakingToken, amount, position.lockEndTimestamp);
  }

  function cancelLocks(uint256[] memory positionIndexes) external {
    for (uint256 i = 0; i < positionIndexes.length; ) {
      UnstakingPosition storage position = unstakingPositions[msg.sender][positionIndexes[i]];

      if (position.status != UnstakingStatus.Cooldown) revert StakingLocker_InvalidStatus();

      position.status = UnstakingStatus.Cancelled;

      IERC20Upgradeable(position.token).safeIncreaseAllowance(address(hmxStaking), position.amount);
      hmxStaking.deposit(msg.sender, position.token, position.amount);

      emit LogCancelLock(
        positionIndexes[i],
        msg.sender,
        position.token,
        position.amount,
        position.lockEndTimestamp
      );

      unchecked {
        ++i;
      }
    }
  }

  function claimLocks(uint256[] memory positionIndexes) external {
    for (uint256 i = 0; i < positionIndexes.length; ) {
      UnstakingPosition storage position = unstakingPositions[msg.sender][positionIndexes[i]];

      if (position.status != UnstakingStatus.Cooldown) revert StakingLocker_InvalidStatus();
      if (position.lockEndTimestamp > block.timestamp) revert StakingLocker_CooldownNotOver();

      position.status = UnstakingStatus.Claimed;

      IERC20Upgradeable(position.token).safeTransfer(msg.sender, position.amount);

      emit LogClaimLock(
        positionIndexes[i],
        msg.sender,
        position.token,
        position.amount,
        position.lockEndTimestamp
      );

      unchecked {
        ++i;
      }
    }
  }

  function getUnstakingPosition(
    address user,
    uint256 _limit,
    uint256 _offset
  ) external view returns (UnstakingPosition[] memory itemList) {
    uint256 _len = unstakingPositionLastIndex[user];
    uint256 _startIndex = _offset;
    uint256 _endIndex = _offset + _limit;
    if (_startIndex > _len) return itemList;
    if (_endIndex > _len) {
      _endIndex = _len;
    }

    itemList = new UnstakingPosition[](_endIndex - _startIndex);

    for (uint256 i = _startIndex; i < _endIndex; ) {
      UnstakingPosition memory _item = unstakingPositions[user][i];

      itemList[i - _offset] = _item;
      unchecked {
        ++i;
      }
    }

    return itemList;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
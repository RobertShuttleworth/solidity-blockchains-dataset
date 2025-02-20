// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import { SafeERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_utils_SafeERC20Upgradeable.sol";
import { IERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_IERC20Upgradeable.sol";
import { IRewarder } from "./src_staking_interfaces_IRewarder.sol";
import { IStaking } from "./src_staking_interfaces_IStaking.sol";
import { IPool } from "./src_interfaces_aerodrome_IPool.sol";

interface IStakingExtended is IStaking {
  // stFDXLPStaking Contract
  function stakingToken() external view returns (address);

  // FDXStaking Contract
  function getRewarderStakingTokens(address rewarder) external view returns (address[] memory);
}

/**
 * @title FDXLPRewardSplitter
 * @notice This contract splits rewards between two staking pools: `fdxStaking` and `stFDXLPStaking`
 * based on their respective values in the FDX token.
 */
contract FDXLPRewardSplitter is OwnableUpgradeable, IRewarder {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  // Public variables
  string public name;
  address public wethToken;
  address public rewardToken;
  address public feeder;

  IStakingExtended public fdxStaking;
  IRewarder public fdxStakingRewarder;

  IStakingExtended public stFDXLPStaking;
  IRewarder public stFDXLPStakingRewarder;

  // Events
  event LogSetFeeder(address indexed oldFeeder, address indexed newFeeder);
  event LogFeedReward(
    uint256 feedAmount,
    uint256 fdxStakingFeedAmount,
    uint256 stFDXLPStakingFeedAmount,
    uint256 duration
  );

  // Errors
  error FDXLPRewardSplitter_NotFeeder();
  error FDXLPRewardSplitter_FeedAmountDecayed();
  error FDXLPRewardSplitter_NotImplemented();

  /// @dev Modifier to restrict access to the feeder (owner)
  modifier onlyFeeder() {
    if (msg.sender != feeder) revert FDXLPRewardSplitter_NotFeeder();
    _;
  }

  /**
   * @notice Initializes the FDXLPRewardSplitter contract.
   * @dev This function sets up the staking contracts and rewarder addresses.
   * @param name_ The name of the reward splitter.
   * @param rewardToken_ The address of the reward token to distribute.
   * @param fdxStaking_ The address of the FDX staking contract.
   * @param fdxStakingRewarder_ The address of the rewarder for FDX staking.
   * @param stFDXLPStaking_ The address of the stFDXLP staking contract.
   * @param stFDXLPStakingRewarder_ The address of the rewarder for stFDXLP staking.
   */
  function initialize(
    string memory name_,
    address rewardToken_,
    address wethToken_,
    address fdxStaking_,
    address fdxStakingRewarder_,
    address stFDXLPStaking_,
    address stFDXLPStakingRewarder_
  ) external virtual initializer {
    OwnableUpgradeable.__Ownable_init();

    // Sanity check to ensure the reward token is valid
    IERC20Upgradeable(rewardToken_).totalSupply();

    name = name_;
    rewardToken = rewardToken_;
    wethToken = wethToken_;

    fdxStaking = IStakingExtended(fdxStaking_);
    fdxStakingRewarder = IRewarder(fdxStakingRewarder_);
    stFDXLPStaking = IStakingExtended(stFDXLPStaking_);
    stFDXLPStakingRewarder = IRewarder(stFDXLPStakingRewarder_);

    // Assume the contract owner is the initial feeder
    feeder = super.owner();
  }

  /**
   * @notice Sets the feeder address.
   * @param feeder_ The address of the new feeder.
   */
  function setFeeder(address feeder_) external onlyOwner {
    emit LogSetFeeder(feeder, feeder_);
    feeder = feeder_;
  }

  /**
   * @notice Feeds the reward token to the staking rewarders based on their share of the total value.
   * @param feedAmount The amount of reward token to feed.
   * @param duration The duration for which to distribute the reward.
   */
  function feed(uint256 feedAmount, uint256 duration) external onlyFeeder {
    _feed(feedAmount, duration);
  }

  /**
   * @notice Feeds the reward token to the staking rewarders based on their share of the total value, with an expiration time.
   * @param feedAmount The amount of reward token to feed.
   * @param expiredAt The timestamp at which the reward feeding expires.
   */
  function feedWithExpiredAt(uint256 feedAmount, uint256 expiredAt) external onlyFeeder {
    _feed(feedAmount, expiredAt - block.timestamp);
  }

  /**
   * @dev Internal function to split and feed rewards based on staking pool values.
   * @param feedAmount The amount of reward token to feed.
   * @param duration The duration for which to distribute the reward.
   */
  function _feed(uint256 feedAmount, uint256 duration) internal {
    {
      // Transfer token, with decay check
      uint256 balanceBefore = IERC20Upgradeable(rewardToken).balanceOf(address(this));
      IERC20Upgradeable(rewardToken).safeTransferFrom(msg.sender, address(this), feedAmount);

      if (IERC20Upgradeable(rewardToken).balanceOf(address(this)) - balanceBefore != feedAmount)
        revert FDXLPRewardSplitter_FeedAmountDecayed();
    }

    uint256 fdxStakingValue = _calculateFDXStakingValueInFDX();
    uint256 stFDXLPStakingValue = _calculateStFDXLPStakingValueInFDX();
    uint256 totalFDXValue = fdxStakingValue + stFDXLPStakingValue;

    uint256 fdxStakingFeedAmount = totalFDXValue == 0
      ? feedAmount / 2
      : (feedAmount * fdxStakingValue) / totalFDXValue;
    uint256 stFDXLPStakingFeedAmount = feedAmount - fdxStakingFeedAmount;

    // Feed the sstaking rewarders
    IERC20Upgradeable(rewardToken).approve(address(fdxStakingRewarder), fdxStakingFeedAmount);
    fdxStakingRewarder.feed(fdxStakingFeedAmount, duration);
    IERC20Upgradeable(rewardToken).approve(
      address(stFDXLPStakingRewarder),
      stFDXLPStakingFeedAmount
    );
    stFDXLPStakingRewarder.feed(stFDXLPStakingFeedAmount, duration);

    // Emit the LogFeedReward event
    emit LogFeedReward(feedAmount, fdxStakingFeedAmount, stFDXLPStakingFeedAmount, duration);
  }

  /**
   * @dev Calculates the FDX value in the FDX staking pool.
   * @return stakingShares The total shares in the FDX staking pool.
   */
  function _calculateFDXStakingValueInFDX() internal view returns (uint256 stakingShares) {
    stakingShares = fdxStaking.calculateTotalShare(address(fdxStakingRewarder));
  }

  /**
   * @dev Calculates the FDX value in the stFDXLP staking pool.
   * @return The calculated FDX value.
   */
  function _calculateStFDXLPStakingValueInFDX() internal view returns (uint256) {
    uint256 stakingShares = stFDXLPStaking.calculateTotalShare(address(stFDXLPStakingRewarder));
    address poolAddress = stFDXLPStaking.stakingToken();
    IPool pool = IPool(poolAddress);

    (uint256 reserve0, uint256 reserve1, ) = pool.getReserves();
    uint256 totalShares = IERC20Upgradeable(poolAddress).totalSupply();
    uint256 token0Amount = (reserve0 * stakingShares) / totalShares;
    uint256 token1Amount = (reserve1 * stakingShares) / totalShares;
    uint256 fdxAmount = wethToken == pool.token0() ? token1Amount : token0Amount;
    return fdxAmount * 2;
  }

  // ----------------- Unimplemented Functions -----------------

  /**
   * @notice Returns the current reward rate.
   * @return rewardRate The current reward rate.
   */
  function rewardRate() external view returns (uint256) {
    revert FDXLPRewardSplitter_NotImplemented();
  }

  /**
   * @notice Called when a user deposits into the staking contract.
   * @param user The address of the user.
   * @param shareAmount The amount of shares the user deposits.
   */
  function onDeposit(address user, uint256 shareAmount) external {
    revert FDXLPRewardSplitter_NotImplemented();
  }

  /**
   * @notice Called when a user withdraws from the staking contract.
   * @param user The address of the user.
   * @param shareAmount The amount of shares the user withdraws.
   */
  function onWithdraw(address user, uint256 shareAmount) external {
    revert FDXLPRewardSplitter_NotImplemented();
  }

  /**
   * @notice Called when a user harvests rewards from the staking contract.
   * @param user The address of the user.
   * @param receiver The address that will receive the rewards.
   */
  function onHarvest(address user, address receiver) external {
    revert FDXLPRewardSplitter_NotImplemented();
  }

  /**
   * @notice Returns the pending reward for a user.
   * @param user The address of the user.
   * @return The pending reward for the user.
   */
  function pendingReward(address user) external view returns (uint256) {
    revert FDXLPRewardSplitter_NotImplemented();
  }

  /**
   * @notice Returns the accumulated reward per share.
   * @return accReward The accumulated reward per share.
   */
  function accRewardPerShare() external view returns (uint128) {
    revert FDXLPRewardSplitter_NotImplemented();
  }

  /**
   * @notice Returns the reward debts for a user.
   * @param user The address of the user.
   * @return The reward debts for the user.
   */
  function userRewardDebts(address user) external view returns (int256) {
    revert FDXLPRewardSplitter_NotImplemented();
  }

  /**
   * @notice Returns the last reward time.
   * @return lastRewardTime The timestamp of the last reward distribution.
   */
  function lastRewardTime() external view returns (uint64) {
    revert FDXLPRewardSplitter_NotImplemented();
  }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import { OwnableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_IERC20Upgradeable.sol";
import { SafeCastUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_math_SafeCastUpgradeable.sol";
import { SafeERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_utils_SafeERC20Upgradeable.sol";

import { IRewarder } from "./src_staking_interfaces_IRewarder.sol";
import { IStaking } from "./src_staking_interfaces_IStaking.sol";
import { MintableTokenInterface } from "./src_staking_interfaces_MintableTokenInterface.sol";
import { IPool } from "./src_interfaces_aerodrome_IPool.sol";

/**
 * @title stFDXLPMintRewarder
 * @notice Handles minting and distribution of rewards based on staking activities.
 * @dev Implements an upgradeable contract using OpenZeppelin's OwnableUpgradeable.
 */
contract StFDXLPMintRewarder is OwnableUpgradeable {
  using SafeCastUpgradeable for uint256;
  using SafeCastUpgradeable for uint128;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /// @notice The name of the rewarder.
  string public name;

  /// @notice Address of the reward token contract.
  address public rewardToken;

  /// @notice Address of the StFDXLPStaking contract.
  address public staking;

  /// @notice Address of the FDXStaking contract.
  address public fdxStaking;

  /// @notice Address of the WETH token contract.
  address public wethToken;

  /// @notice Address of the liquidity pool token contract.
  address public poolToken;

  /// @notice Reward calculation constants and parameters.
  uint64 public constant YEAR = 365 days;
  uint256 public constant APR = 1e4; // Annual Percentage Rate in Bips (1e4 equals 100%)
  uint256 public constant MAGNITUDE = 1e18; // Decimals of `accRewardPerShare`
  uint256 public accRewardPerShare; // Accumulated rewards per share, scaled to `MAGNITUDE` for precision.
  uint256 public lastUpdateTime; // Timestamp of the last reward update.

  /// @notice Cached reserves for WETH and FDX tokens.
  uint256 public cachedWethReserve;
  uint256 public cachedFdxReserve;
  uint256 public cachedTotalShares;

  /// @notice Tracks user-specific reward details.
  mapping(address => uint64) public userLastRewards;
  mapping(address => uint256) public userAccRewards;
  mapping(address => uint256) public userRewardDebt; // User reward debt for accurate reward calculation.

  /// @notice Reward rate per second based on the APR.
  uint256 public rewardRate;

  // Events
  event LogOnDeposit(address indexed user, uint256 shareAmount);
  event LogOnWithdraw(address indexed user, uint256 shareAmount);
  event LogHarvest(address indexed user, uint256 pendingRewardAmount);

  /// @dev Error thrown when a function is called by a non-staking contract.
  error stFDXLPMintRewarderError_NotStakingContract();

  /// @dev Modifier to restrict function access to only the staking contract.
  modifier onlyStakingContract() {
    if (msg.sender != staking && msg.sender != fdxStaking) revert stFDXLPMintRewarderError_NotStakingContract();
    _;
  }

  /**
   * @notice Initializes the contract with the specified parameters.
   * @param name_ Name of the rewarder.
   * @param rewardToken_ Address of the reward token contract.
   * @param wethToken_ Address of the WETH token contract.
   * @param poolToken_ Address of the liquidity pool token contract.
   * @param staking_ Address of the StFDXLPStaking contract.
   * @param fdxStaking_ Address of the FDXStaking contract.
   */
  function initialize(
    string memory name_,
    address rewardToken_,
    address wethToken_,
    address poolToken_,
    address staking_,
    address fdxStaking_
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();

    // Sanity check
    IERC20Upgradeable(rewardToken_).totalSupply();
    IStaking(staking_).isRewarder(address(this));

    name = name_;
    rewardToken = rewardToken_;
    wethToken = wethToken_;
    poolToken = poolToken_;
    staking = staking_;
    fdxStaking = fdxStaking_;

    rewardRate = (APR * 1 ether) / 1e4 / YEAR; // = 31709791983 wei when 100%

    _updateRewardInfo();
  }

  /**
   * @dev Updates accumulated rewards per share and the last update timestamp, cache pool reserves.
   */
  function updateRewardInfo() public {
    _updateRewardInfo();
  }

  /**
   * @notice Called when a user deposits shares.
   * @dev We assume OnDeposit is called before share balance update
   * @param user The address of the user depositing.
   * @param shareAmount The amount of shares being deposited.
   */
  function onDeposit(address user, uint256 shareAmount) external onlyStakingContract {
    _updateRewardInfo();

    uint256 userShares = IStaking(staking).calculateShare(address(this), user);
    userAccRewards[user] += ((userShares * accRewardPerShare) / MAGNITUDE) - userRewardDebt[user];

    // Reward moved to userAccRewards
    uint256 newShares = userShares + shareAmount;
    userRewardDebt[user] = (newShares * accRewardPerShare) / MAGNITUDE;

    emit LogOnDeposit(user, shareAmount);
  }

  /**
   * @notice Called when a user withdraws shares.
   * @dev Harvest logic is very crucial. In case we don't harvest before
   * withdraw, then we need to change reward param calculation, as well 
   * as the type of rewardDebt to signed integer
   * @param user The address of the user withdrawing.
   * @param shareAmount The amount of shares being withdrawn.
   */
  function onWithdraw(address user, uint256 shareAmount) external onlyStakingContract {
    _updateRewardInfo();

    // Reset user reward
    // The rule is whenever withdraw occurs, no matter the size, reward calculation should restart.
    uint256 newShares = IStaking(staking).calculateShare(address(this), user) - shareAmount;
    userRewardDebt[user] = (newShares * accRewardPerShare) / MAGNITUDE;
    userAccRewards[user] = 0;

    emit LogOnWithdraw(user, shareAmount);
  }

  /**
   * @notice Called when a user harvests rewards.
   * @param user The address of the user harvesting rewards.
   * @param receiver The address to send the harvested rewards to.
   */
  function onHarvest(address user, address receiver) external onlyStakingContract {
    _updateRewardInfo();

    // Calculate total pending rewards
    uint256 userShares = IStaking(staking).calculateShare(address(this), user);
    uint256 pending = userAccRewards[user];
    pending += ((userShares * accRewardPerShare) / MAGNITUDE) - userRewardDebt[user];

    if (pending == 0) {
      return;
    }

    // Reset user reward tracking
    userAccRewards[user] = 0;
    userRewardDebt[user] = (userShares * accRewardPerShare) / MAGNITUDE;

    // Distribute rewards
    _harvestToken(receiver, pending);

    emit LogHarvest(user, pending);
  }

  /**
   * @dev Converts LP token to the FDX.
   * @return The calculated FDX value.
   */
  function convertLPtoFDX(uint256 lpAmount) public view returns (uint256) {
    uint256 fdxAmount = (cachedFdxReserve * lpAmount) / cachedTotalShares;
    return fdxAmount * 2;
  }

  /**
   * @notice Calculates the pending rewards for a user.
   * @param user The address of the user.
   * @return The amount of pending rewards.
   */
  function pendingReward(address user) external view returns (uint256) {
    uint256 totalShares = IStaking(staking).calculateTotalShare(address(this));
    uint256 newAccRewardPerShare = accRewardPerShare;

    if (totalShares > 0) {
      uint256 timeElapsed = block.timestamp - lastUpdateTime;
      newAccRewardPerShare +=
        (convertLPtoFDX(totalShares) * APR * timeElapsed * MAGNITUDE) /
        1e4 /
        YEAR /
        totalShares;
    }

    uint256 userShares = IStaking(staking).calculateShare(address(this), user);
    return
      userAccRewards[user] + ((userShares * newAccRewardPerShare) / MAGNITUDE) - userRewardDebt[user];
  }

  /**
   * @dev Updates accumulated rewards per share and the last update timestamp.
   */
  function _updateRewardInfo() internal {
    uint256 totalShares = IStaking(staking).calculateTotalShare(address(this));
    if (totalShares > 0) {
      uint256 timeElapsed = block.timestamp - lastUpdateTime;
      accRewardPerShare +=
        (convertLPtoFDX(totalShares) * APR * timeElapsed * MAGNITUDE) /
        1e4 /
        YEAR /
        totalShares;
    }

    (uint256 reserve0, uint256 reserve1, ) = IPool(poolToken).getReserves();
    cachedFdxReserve = wethToken == IPool(poolToken).token0() ? reserve1 : reserve0;
    cachedWethReserve = wethToken == IPool(poolToken).token0() ? reserve0 : reserve1;
    cachedTotalShares = IERC20Upgradeable(poolToken).totalSupply();

    lastUpdateTime = block.timestamp;
  }

  /**
   * @notice Mints rewards to the user.
   * @param receiver The address to send the rewards to.
   * @param pendingRewardAmount The amount of rewards to mint.
   */
  function _harvestToken(address receiver, uint256 pendingRewardAmount) internal {
    MintableTokenInterface(rewardToken).mint(receiver, pendingRewardAmount);
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
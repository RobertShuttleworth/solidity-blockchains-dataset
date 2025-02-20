// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.
pragma solidity 0.8.18;

import { IERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_interfaces_IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_utils_SafeERC20Upgradeable.sol";
import { OwnableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";

import { MerkleAirdrop } from "./src_airdrop_MerkleAirdrop.sol";

// Interfaces
import { IVaultStorage } from "./src_staking_interfaces_IVaultStorage.sol";
import { IUniswapV3Router } from "./src_staking_interfaces_IUniswapV3Router.sol";
import { IRewarder } from "./src_staking_interfaces_IRewarder.sol";
import { IGmxRewardRouterV2 } from "./src_staking_interfaces_IGmxRewardRouterV2.sol";
import { ISwitchCollateralRouter } from "./src_staking_interfaces_ISwitchCollateralRouter.sol";
import { IGmxV2ExchangeRouter } from "./src_interfaces_gmx-v2_IGmxV2ExchangeRouter.sol";
import { IWNative } from "./src_interfaces_IWNative.sol";
import { Transfer as TransferLib } from "./src_libraries_Transfer.sol";
import { IGasService } from "./src_interfaces_IGasService.sol";
import { IERC20 } from "./lib_forge-std_src_interfaces_IERC20.sol";

contract RewardDistributor is OwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * Events
   */
  event LogSetFeeder(address oldValue, address newValue);
  event LogSetUniV3SwapFee(uint24 oldValue, uint24 newValue);
  event LogProtocolFee(uint256 weekTimestamp, uint256 stakingAmount);
  event LogSetUniFeeBps(address[] rewardTokens, address[] swapTokens, uint24[] uniV3FeeBps);
  event LogSetParams(
    address rewardToken,
    address vaultStorage,
    address poolRouter,
    address rewardRouter,
    address hlpStakingProtocolRevenueRewarder,
    address hmxStakingProtocolRevenueRewarder,
    uint256 plpStakingBps,
    address merkleAirdrop,
    address switchCollateralRouter
  );
  event LogSetReferralRevenueMaxThreshold(uint256 oldThreshold, uint256 newThreshold);
  event LogSetTokenSwapPath(address[] token, address[][] path);
  event LogGMWithdrawalCreated(bytes32 gmxOrderKey, WithdrawalParams withdrawParam);
  event LogSetGmConfigs(address _gmxV2ExchangeRouter, address _gmxV2WithdrawalVault, address _weth);
  event LogSetDistributionBpsParams(
    uint256 hlpStakingBps,
    uint256 protocolOwnedLiquidityBps,
    address protocolOwnedLiquidityTreasury
  );
  event LogSetGasService(address _gasService);
  event LogSetTreasury(address _treasury);

  /**
   * Errors
   */
  error RewardDistributor_NotFeeder();
  error RewardDistributor_BadParams();
  error RewardDistributor_InvalidArray();
  error RewardDistributor_InvalidSwapFee();
  error RewardDistributor_ReferralRevenueExceedMaxThreshold();
  error RewardDistributor_BadReferralRevenueMaxThreshold();
  error RewardDistributor_UnevenTokenSwapPath();

  /**
   * Struct
   */
  struct WithdrawalParams {
    address market;
    uint256 amount;
    uint256 minLongTokenAmount;
    uint256 minShortTokenAmount;
    uint256 gasLimit;
    bool withdrawProtocolRevenue;
  }

  /**
   * States
   */

  uint256 public constant BPS = 10000;

  /// @dev Token addreses
  address public rewardToken; // the token to be fed to rewarder
  address public sglp;

  /// @dev Pool and its companion addresses
  address public poolRouter;
  address public hlpStakingProtocolRevenueRewarder;

  address public vaultStorage;
  address public feeder;
  MerkleAirdrop public merkleAirdrop;
  IGmxRewardRouterV2 public rewardRouter;

  /// @dev Distribution weights
  uint256 public hlpStakingBps;

  // rewardToken => swapToken => feeBps
  mapping(address => mapping(address => uint24)) public uniswapV3SwapFeeBPSs;

  address public hmxStakingProtocolRevenueRewarder;

  uint256 public referralRevenueMaxThreshold; // in BPS (10000)

  // For SwitchCollateral
  mapping(address token => address[] path) public tokenSwapPath;
  ISwitchCollateralRouter public switchCollateralRouter;

  // GMX V2
  IGmxV2ExchangeRouter public gmxV2ExchangeRouter;
  address public gmxV2WithdrawalVault;
  IWNative public weth;

  uint256 public protocolOwnedLiquidityBps;
  address public protocolOwnedLiquidityTreasury;

  address public treasury;
  IGasService public gasService;

  /**
   * Modifiers
   */
  modifier onlyFeeder() {
    if (msg.sender != feeder) revert RewardDistributor_NotFeeder();
    _;
  }

  /**
   * Initialize
   */

  function initialize(
    address _rewardToken,
    address _vaultStorage,
    address _poolRouter,
    address _sglp,
    IGmxRewardRouterV2 _rewardRouter,
    address _hlpStakingProtocolRevenueRewarder,
    address _hmxStakingProtocolRevenueRewarder,
    uint256 _hlpStakingBps,
    MerkleAirdrop _merkleAirdrop,
    uint256 _referralRevenueMaxThreshold,
    ISwitchCollateralRouter _switchCollateralRouter
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();

    rewardToken = _rewardToken;
    vaultStorage = _vaultStorage;
    sglp = _sglp;
    poolRouter = _poolRouter;
    rewardRouter = _rewardRouter;
    switchCollateralRouter = _switchCollateralRouter;
    hlpStakingProtocolRevenueRewarder = _hlpStakingProtocolRevenueRewarder;
    hmxStakingProtocolRevenueRewarder = _hmxStakingProtocolRevenueRewarder;
    hlpStakingBps = _hlpStakingBps;
    merkleAirdrop = _merkleAirdrop;

    referralRevenueMaxThreshold = _referralRevenueMaxThreshold;
  }

  /**
   * Core Functions
   */

  function claimAndSwap(address[] memory tokens) external onlyFeeder {
    _claimAndSwap(tokens);
  }

  function feedProtocolRevenue(
    uint256 feedingExpiredAt,
    uint256 weekTimestamp,
    uint256 referralRevenueAmount,
    bytes32 merkleRoot
  ) external onlyFeeder {
    _feedProtocolRevenue(feedingExpiredAt, weekTimestamp, referralRevenueAmount, merkleRoot);
  }

  function claimAndFeedProtocolRevenue(
    address[] memory tokens,
    uint256 feedingExpiredAt,
    uint256 weekTimestamp,
    uint256 referralRevenueAmount,
    bytes32 merkleRoot
  ) external onlyFeeder {
    _claimAndSwap(tokens);
    _feedProtocolRevenue(feedingExpiredAt, weekTimestamp, referralRevenueAmount, merkleRoot);
  }

  /**
   * Internal Functions
   */

  function _claimAndSwap(address[] memory tokens) internal {
    uint256 length = tokens.length;
    for (uint256 i = 0; i < length; ) {
      if (IVaultStorage(vaultStorage).protocolFees(tokens[i]) > 0) {
        // 1. Withdraw protocol revenue
        _withdrawProtocolRevenue(tokens[i]);
      }
      uint256 tokenBalance = IERC20Upgradeable(tokens[i]).balanceOf(address(this));
      if (tokenBalance > 0) {
        // 2. Swap those revenue (along with surplus) to RewardToken Token
        _swapTokenToRewardToken(tokens[i], tokenBalance);
      }

      unchecked {
        i++;
      }
    }
  }

  function _withdrawProtocolRevenue(address _token) internal {
    // Withdraw the all max amount revenue from the pool
    IVaultStorage(vaultStorage).withdrawFee(
      _token,
      IVaultStorage(vaultStorage).protocolFees(_token),
      address(this)
    );
  }

  function _swapTokenToRewardToken(address token, uint256 amount) internal {
    // If no token, no need to swap
    if (amount == 0) return;

    // If token is already reward token, no need to swap
    if (token == rewardToken) return;

    // Use SwitchCollateralRouter for every swap
    IERC20Upgradeable(token).safeTransfer(address(switchCollateralRouter), amount);
    switchCollateralRouter.execute(amount, tokenSwapPath[token]);
  }

  function _feedProtocolRevenue(
    uint256 feedingExpiredAt,
    uint256 weekTimestamp,
    uint256 referralRevenueAmount,
    bytes32 merkleRoot
  ) internal {
    // Transfer referral revenue to merkle airdrop address for distribution
    uint256 totalProtocolRevenue = IERC20Upgradeable(rewardToken).balanceOf(address(this));

    // totalProtocolRevenue * referralRevenueMaxThreshold / 10000 < referralRevenueAmount
    if (totalProtocolRevenue * referralRevenueMaxThreshold < referralRevenueAmount * 10000)
      revert RewardDistributor_ReferralRevenueExceedMaxThreshold();

    if (referralRevenueAmount > 0) {
      merkleAirdrop.init(weekTimestamp, merkleRoot);
      IERC20Upgradeable(rewardToken).safeTransfer(address(merkleAirdrop), referralRevenueAmount);
    }

    // At this point, we got a portion of reward tokens for protocol revenue.
    // Feed reward to both rewarders
    uint256 totalRewardAmount = _feedRewardToRewarders(feedingExpiredAt);

    emit LogProtocolFee(weekTimestamp, totalRewardAmount);
  }

  function _feedRewardToRewarders(uint256 feedingExpiredAt) internal returns (uint256) {
    uint256 totalRewardAmount = IERC20Upgradeable(rewardToken).balanceOf(address(this));

    // Normalize into the decimals of reward token
    // Reward token is stablecoin USDC. We assume 1 USDC = 1 USD here.
    uint256 decimalsDiff = 30 - IERC20(rewardToken).decimals();
    uint256 subsidizedExecutionFeeAmount = gasService.subsidizedExecutionFeeValue() /
      (10 ** decimalsDiff);

    // If we can subsidize, then deduct from the total reward
    if (subsidizedExecutionFeeAmount < totalRewardAmount) {
      unchecked {
        totalRewardAmount -= subsidizedExecutionFeeAmount;
      }
    } else {
      // If the reward is not enough, we don't subsudize at all
      subsidizedExecutionFeeAmount = 0;
    }
    uint256 hlpStakingRewardAmount = (totalRewardAmount * hlpStakingBps) / BPS;
    uint256 protocolOwnedLiquidityAmount = (totalRewardAmount * protocolOwnedLiquidityBps) / BPS;
    uint256 hmxStakingRewardAmount = totalRewardAmount -
      hlpStakingRewardAmount -
      protocolOwnedLiquidityAmount;

    // Approve and feed to HLPStaking
    IERC20Upgradeable(rewardToken).approve(
      hlpStakingProtocolRevenueRewarder,
      hlpStakingRewardAmount
    );
    IRewarder(hlpStakingProtocolRevenueRewarder).feedWithExpiredAt(
      hlpStakingRewardAmount,
      feedingExpiredAt
    );

    // Approve and feed to HMXStaking
    IERC20Upgradeable(rewardToken).approve(
      hmxStakingProtocolRevenueRewarder,
      hmxStakingRewardAmount
    );
    IRewarder(hmxStakingProtocolRevenueRewarder).feedWithExpiredAt(
      hmxStakingRewardAmount,
      feedingExpiredAt
    );

    // Send to Protocol Owned Liquidity treasury
    IERC20Upgradeable(rewardToken).safeTransfer(
      protocolOwnedLiquidityTreasury,
      protocolOwnedLiquidityAmount
    );

    // Send the subsidized execution fee to dev treasury
    if (subsidizedExecutionFeeAmount != 0) {
      gasService.adjustSubsidizedExecutionFeeValue(
        -int256(subsidizedExecutionFeeAmount * (10 ** decimalsDiff))
      );
      IERC20Upgradeable(rewardToken).safeTransfer(treasury, subsidizedExecutionFeeAmount);
    }

    return totalRewardAmount;
  }

  function createGmWithdrawalOrders(
    WithdrawalParams[] calldata _withdrawParams,
    uint256 _executionFee
  ) external payable onlyFeeder returns (bytes32[] memory _gmxOrderKeys) {
    uint256 _withdrawParamsLen = _withdrawParams.length;
    _gmxOrderKeys = new bytes32[](_withdrawParamsLen);

    WithdrawalParams memory _withdrawParam;
    bytes32 _gmxOrderKey;
    for (uint256 i = 0; i < _withdrawParamsLen; ) {
      _withdrawParam = _withdrawParams[i];

      // withdraw GM(x) from protocol revenue
      if (_withdrawParam.withdrawProtocolRevenue) {
        _withdrawProtocolRevenue(_withdrawParam.market);
      }

      // Send GM token to GMX V2 Vault for withdrawal
      IERC20Upgradeable(_withdrawParam.market).safeTransfer(
        gmxV2WithdrawalVault,
        _withdrawParam.amount == 0
          ? IERC20Upgradeable(_withdrawParam.market).balanceOf(address(this))
          : _withdrawParam.amount
      );

      // Taken WETH from caller and send to gmxV2WithdrawalVault for execution fee
      weth.deposit{ value: _executionFee }();
      IERC20Upgradeable(address(weth)).safeTransfer(gmxV2WithdrawalVault, _executionFee);
      // Create a withdrawal order
      _gmxOrderKey = gmxV2ExchangeRouter.createWithdrawal(
        IGmxV2ExchangeRouter.CreateWithdrawalParams({
          receiver: address(this),
          callbackContract: address(0),
          uiFeeReceiver: address(0),
          market: _withdrawParam.market,
          longTokenSwapPath: new address[](0),
          shortTokenSwapPath: new address[](0),
          minLongTokenAmount: _withdrawParam.minLongTokenAmount,
          minShortTokenAmount: _withdrawParam.minShortTokenAmount,
          shouldUnwrapNativeToken: false,
          executionFee: _executionFee,
          callbackGasLimit: _withdrawParam.gasLimit
        })
      );
      // Update returner
      _gmxOrderKeys[i] = _gmxOrderKey;

      emit LogGMWithdrawalCreated(_gmxOrderKey, _withdrawParam);

      unchecked {
        ++i;
      }
    }
  }

  function recoverToken(address _token, address _to, uint256 _amount) external onlyOwner {
    TransferLib.nativeOrToken(_token, _to, _amount);
  }

  /**
   * Setter
   */

  function setFeeder(address newFeeder) external onlyOwner {
    emit LogSetFeeder(feeder, newFeeder);
    feeder = newFeeder;
  }

  function setUniFeeBps(
    address[] memory rewardTokens,
    address[] memory swapTokens,
    uint24[] memory uniV3FeeBpses
  ) external onlyOwner {
    if (rewardTokens.length != swapTokens.length || swapTokens.length != uniV3FeeBpses.length)
      revert RewardDistributor_InvalidArray();

    uint256 len = rewardTokens.length;
    for (uint256 i = 0; i < len; ) {
      uniswapV3SwapFeeBPSs[rewardTokens[i]][swapTokens[i]] = uniV3FeeBpses[i];

      unchecked {
        ++i;
      }
    }

    emit LogSetUniFeeBps(rewardTokens, swapTokens, uniV3FeeBpses);
  }

  function setParams(
    address _rewardToken,
    address _vaultStorage,
    address _poolRouter,
    address _sglp,
    IGmxRewardRouterV2 _rewardRouter,
    address _hlpStakingProtocolRevenueRewarder,
    address _hmxStakingProtocolRevenueRewarder,
    uint256 _hlpStakingBps,
    MerkleAirdrop _merkleAirdrop,
    ISwitchCollateralRouter _switchCollateralRouter
  ) external onlyOwner {
    if (_hlpStakingBps > BPS) revert RewardDistributor_BadParams();

    rewardToken = _rewardToken;
    vaultStorage = _vaultStorage;
    sglp = _sglp;
    poolRouter = _poolRouter;
    rewardRouter = _rewardRouter;
    hlpStakingProtocolRevenueRewarder = _hlpStakingProtocolRevenueRewarder;
    hmxStakingProtocolRevenueRewarder = _hmxStakingProtocolRevenueRewarder;
    hlpStakingBps = _hlpStakingBps;
    merkleAirdrop = _merkleAirdrop;
    switchCollateralRouter = _switchCollateralRouter;

    emit LogSetParams(
      _rewardToken,
      _vaultStorage,
      _poolRouter,
      address(_rewardRouter),
      _hlpStakingProtocolRevenueRewarder,
      _hmxStakingProtocolRevenueRewarder,
      _hlpStakingBps,
      address(_merkleAirdrop),
      address(_switchCollateralRouter)
    );
  }

  function setDistributionBpsParams(
    uint256 _hlpStakingBps,
    uint256 _protocolOwnedLiquidityBps,
    address _protocolOwnedLiquidityTreasury
  ) external onlyOwner {
    hlpStakingBps = _hlpStakingBps;
    protocolOwnedLiquidityBps = _protocolOwnedLiquidityBps;
    protocolOwnedLiquidityTreasury = _protocolOwnedLiquidityTreasury;

    emit LogSetDistributionBpsParams(
      _hlpStakingBps,
      _protocolOwnedLiquidityBps,
      _protocolOwnedLiquidityTreasury
    );
  }

  function setReferralRevenueMaxThreshold(
    uint256 newReferralRevenueMaxThreshold
  ) external onlyOwner {
    if (newReferralRevenueMaxThreshold > 5000) {
      // should not exceed 50% of total revenue
      revert RewardDistributor_BadReferralRevenueMaxThreshold();
    }
    emit LogSetReferralRevenueMaxThreshold(
      referralRevenueMaxThreshold,
      newReferralRevenueMaxThreshold
    );
    referralRevenueMaxThreshold = newReferralRevenueMaxThreshold;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function setTokenSwapPath(
    address[] calldata token,
    address[][] calldata path
  ) external onlyOwner {
    if (token.length != path.length) {
      revert RewardDistributor_UnevenTokenSwapPath();
    }
    emit LogSetTokenSwapPath(token, path);
    for (uint8 i; i < token.length; i++) {
      tokenSwapPath[token[i]] = path[i];
    }
  }

  function setGmConfigs(
    address _gmxV2ExchangeRouter,
    address _gmxV2WithdrawalVault,
    address _weth
  ) external onlyOwner {
    gmxV2ExchangeRouter = IGmxV2ExchangeRouter(_gmxV2ExchangeRouter);
    gmxV2WithdrawalVault = _gmxV2WithdrawalVault;
    weth = IWNative(_weth);

    emit LogSetGmConfigs(_gmxV2ExchangeRouter, _gmxV2WithdrawalVault, _weth);
  }

  function setGasService(address _gasService) external onlyOwner {
    gasService = IGasService(_gasService);
    emit LogSetGasService(_gasService);
  }

  function setTreasury(address _treasury) external onlyOwner {
    treasury = _treasury;
    emit LogSetTreasury(_treasury);
  }
}
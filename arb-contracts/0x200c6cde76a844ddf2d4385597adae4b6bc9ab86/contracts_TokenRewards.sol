// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './openzeppelin_contracts_access_Ownable.sol';
import './openzeppelin_contracts_token_ERC20_IERC20.sol';
import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_utils_Context.sol';
import './uniswap_v3-core_contracts_libraries_FixedPoint96.sol';
import './contracts_interfaces_IDecentralizedIndex.sol';
import './contracts_interfaces_IDexAdapter.sol';
import './contracts_interfaces_IPEAS.sol';
import './contracts_interfaces_IRewardsWhitelister.sol';
import './contracts_interfaces_IProtocolFees.sol';
import './contracts_interfaces_IProtocolFeeRouter.sol';
import './contracts_interfaces_ITokenRewards.sol';
import './contracts_interfaces_IV3TwapUtilities.sol';
import './contracts_libraries_BokkyPooBahsDateTimeLibrary.sol';

contract TokenRewards is ITokenRewards, Context {
  using SafeERC20 for IERC20;

  uint256 constant PRECISION = 10 ** 36;
  uint24 constant REWARDS_POOL_FEE = 10000; // 1%
  address immutable INDEX_FUND;
  address immutable PAIRED_LP_TOKEN;
  IProtocolFeeRouter immutable PROTOCOL_FEE_ROUTER;
  IRewardsWhitelister immutable REWARDS_WHITELISTER;
  IDexAdapter immutable DEX_HANDLER;
  IV3TwapUtilities immutable V3_TWAP_UTILS;

  struct Reward {
    uint256 excluded;
    uint256 realized;
  }

  address public immutable override trackingToken;
  address public immutable override rewardsToken; // main rewards token
  uint256 public override totalShares;
  uint256 public override totalStakers;
  mapping(address => uint256) public shares;
  // reward token => user => Reward
  mapping(address => mapping(address => Reward)) public rewards;

  uint256 _rewardsSwapSlippage = 20; // 2%
  // reward token => amount
  mapping(address => uint256) _rewardsPerShare;
  // reward token => amount
  mapping(address => uint256) public rewardsDistributed;
  // reward token => amount
  mapping(address => uint256) public rewardsDeposited;
  // reward token => month => amount
  mapping(address => mapping(uint256 => uint256)) public rewardsDepMonthly;
  // all deposited rewards tokens
  address[] _allRewardsTokens;
  mapping(address => bool) _depositedRewardsToken;

  constructor(
    IProtocolFeeRouter _feeRouter,
    IRewardsWhitelister _rewardsWhitelist,
    IDexAdapter _dexHandler,
    IV3TwapUtilities _v3TwapUtilities,
    address _indexFund,
    address _pairedLpToken,
    address _trackingToken,
    address _rewardsToken
  ) {
    PROTOCOL_FEE_ROUTER = _feeRouter;
    REWARDS_WHITELISTER = _rewardsWhitelist;
    DEX_HANDLER = _dexHandler;
    V3_TWAP_UTILS = _v3TwapUtilities;
    INDEX_FUND = _indexFund;
    PAIRED_LP_TOKEN = _pairedLpToken;
    trackingToken = _trackingToken;
    rewardsToken = _rewardsToken;
  }

  function setShares(
    address _wallet,
    uint256 _amount,
    bool _sharesRemoving
  ) external override {
    require(_msgSender() == trackingToken, 'UNAUTHORIZED');
    _setShares(_wallet, _amount, _sharesRemoving);
  }

  function _setShares(
    address _wallet,
    uint256 _amount,
    bool _sharesRemoving
  ) internal {
    _processFeesIfApplicable();
    if (_sharesRemoving) {
      _removeShares(_wallet, _amount);
      emit RemoveShares(_wallet, _amount);
    } else {
      _addShares(_wallet, _amount);
      emit AddShares(_wallet, _amount);
    }
  }

  function _addShares(address _wallet, uint256 _amount) internal {
    if (shares[_wallet] > 0) {
      _distributeReward(_wallet);
    }
    uint256 sharesBefore = shares[_wallet];
    totalShares += _amount;
    shares[_wallet] += _amount;
    if (sharesBefore == 0 && shares[_wallet] > 0) {
      totalStakers++;
    }
    _resetExcluded(_wallet);
  }

  function _removeShares(address _wallet, uint256 _amount) internal {
    require(shares[_wallet] > 0 && _amount <= shares[_wallet], 'RE');
    _distributeReward(_wallet);
    totalShares -= _amount;
    shares[_wallet] -= _amount;
    if (shares[_wallet] == 0) {
      totalStakers--;
    }
    _resetExcluded(_wallet);
  }

  function _processFeesIfApplicable() internal {
    IDecentralizedIndex(INDEX_FUND).processPreSwapFeesAndSwap();
  }

  function depositFromPairedLpToken(
    uint256 _amountTknDepositing,
    uint256 _slippageOverride
  ) public override {
    require(PAIRED_LP_TOKEN != rewardsToken, 'R');
    require(_slippageOverride <= 200, 'MS'); // 20%
    if (_amountTknDepositing > 0) {
      IERC20(PAIRED_LP_TOKEN).safeTransferFrom(
        _msgSender(),
        address(this),
        _amountTknDepositing
      );
    }
    uint256 _amountTkn = IERC20(PAIRED_LP_TOKEN).balanceOf(address(this));
    require(_amountTkn > 0, 'A');
    uint256 _adminAmt = _getAdminFeeFromAmount(_amountTkn);
    _amountTkn -= _adminAmt;
    (address _token0, address _token1) = PAIRED_LP_TOKEN < rewardsToken
      ? (PAIRED_LP_TOKEN, rewardsToken)
      : (rewardsToken, PAIRED_LP_TOKEN);
    address _pool = DEX_HANDLER.getV3Pool(_token0, _token1, REWARDS_POOL_FEE);
    uint160 _rewardsSqrtPriceX96 = V3_TWAP_UTILS
      .sqrtPriceX96FromPoolAndInterval(_pool);
    uint256 _rewardsPriceX96 = V3_TWAP_UTILS.priceX96FromSqrtPriceX96(
      _rewardsSqrtPriceX96
    );
    uint256 _amountOut = _token0 == PAIRED_LP_TOKEN
      ? (_rewardsPriceX96 * _amountTkn) / FixedPoint96.Q96
      : (_amountTkn * FixedPoint96.Q96) / _rewardsPriceX96;

    uint256 _slippage = _slippageOverride > 0
      ? _slippageOverride
      : _rewardsSwapSlippage;
    _swapForRewards(
      _amountTkn,
      _amountOut,
      _slippage,
      _slippageOverride > 0,
      _adminAmt
    );
  }

  function depositRewards(address _token, uint256 _amount) external override {
    _depositRewardsFromToken(_msgSender(), _token, _amount, true);
  }

  function depositRewardsNoTransfer(
    address _token,
    uint256 _amount
  ) external override {
    require(_msgSender() == INDEX_FUND, 'AUTH');
    _depositRewardsFromToken(_msgSender(), _token, _amount, false);
  }

  function _depositRewardsFromToken(
    address _user,
    address _token,
    uint256 _amount,
    bool _shouldTransfer
  ) internal {
    require(_amount > 0, 'A');
    require(_isValidRewardsToken(_token), 'V');
    uint256 _finalAmt = _amount;
    if (_shouldTransfer) {
      uint256 _balBefore = IERC20(_token).balanceOf(address(this));
      IERC20(_token).safeTransferFrom(_user, address(this), _finalAmt);
      _finalAmt = IERC20(_token).balanceOf(address(this)) - _balBefore;
    }
    uint256 _adminAmt = _getAdminFeeFromAmount(_finalAmt);
    if (_adminAmt > 0) {
      IERC20(_token).safeTransfer(
        Ownable(address(V3_TWAP_UTILS)).owner(),
        _adminAmt
      );
      _finalAmt -= _adminAmt;
    }
    _depositRewards(_token, _finalAmt);
  }

  function _depositRewards(address _token, uint256 _amountTotal) internal {
    if (!_depositedRewardsToken[_token]) {
      _depositedRewardsToken[_token] = true;
      _allRewardsTokens.push(_token);
    }
    if (_amountTotal == 0) {
      return;
    }
    if (totalShares == 0) {
      require(_token == rewardsToken, 'R');
      _burnRewards(_amountTotal);
      return;
    }

    uint256 _depositAmount = _amountTotal;
    if (_token == rewardsToken) {
      (, uint256 _yieldBurnFee) = _getYieldFees();
      if (_yieldBurnFee > 0) {
        uint256 _burnAmount = (_amountTotal * _yieldBurnFee) /
          PROTOCOL_FEE_ROUTER.protocolFees().DEN();
        if (_burnAmount > 0) {
          _burnRewards(_burnAmount);
          _depositAmount -= _burnAmount;
        }
      }
    }
    rewardsDeposited[_token] += _depositAmount;
    rewardsDepMonthly[_token][
      beginningOfMonth(block.timestamp)
    ] += _depositAmount;
    _rewardsPerShare[_token] += (PRECISION * _depositAmount) / totalShares;
    emit DepositRewards(_msgSender(), _token, _depositAmount);
  }

  function _distributeReward(address _wallet) internal {
    if (shares[_wallet] == 0) {
      return;
    }
    for (uint256 _i; _i < _allRewardsTokens.length; _i++) {
      address _token = _allRewardsTokens[_i];
      uint256 _amount = getUnpaid(_token, _wallet);
      rewards[_token][_wallet].realized += _amount;
      rewards[_token][_wallet].excluded = _cumulativeRewards(
        _token,
        shares[_wallet]
      );
      if (_amount > 0) {
        rewardsDistributed[_token] += _amount;
        IERC20(_token).safeTransfer(_wallet, _amount);
        emit DistributeReward(_wallet, _token, _amount);
      }
    }
  }

  function _resetExcluded(address _wallet) internal {
    for (uint256 _i; _i < _allRewardsTokens.length; _i++) {
      address _token = _allRewardsTokens[_i];
      rewards[_token][_wallet].excluded = _cumulativeRewards(
        _token,
        shares[_wallet]
      );
    }
  }

  function _burnRewards(uint256 _burnAmount) internal {
    try IPEAS(rewardsToken).burn(_burnAmount) {} catch {
      IERC20(rewardsToken).safeTransfer(address(0xdead), _burnAmount);
    }
  }

  function _isValidRewardsToken(address _token) internal view returns (bool) {
    return _token == rewardsToken || REWARDS_WHITELISTER.whitelist(_token);
  }

  function _getAdminFeeFromAmount(
    uint256 _amount
  ) internal view returns (uint256) {
    (uint256 _yieldAdminFee, ) = _getYieldFees();
    if (_yieldAdminFee == 0) {
      return 0;
    }
    return
      (_amount * _yieldAdminFee) / PROTOCOL_FEE_ROUTER.protocolFees().DEN();
  }

  function _getYieldFees()
    internal
    view
    returns (uint256 _admin, uint256 _burn)
  {
    IProtocolFees _fees = PROTOCOL_FEE_ROUTER.protocolFees();
    if (address(_fees) != address(0)) {
      _admin = _fees.yieldAdmin();
      _burn = _fees.yieldBurn();
    }
  }

  function _swapForRewards(
    uint256 _amountIn,
    uint256 _amountOut,
    uint256 _slippage,
    bool _isSlipOverride,
    uint256 _adminAmt
  ) internal {
    uint256 _balBefore = IERC20(rewardsToken).balanceOf(address(this));
    IERC20(PAIRED_LP_TOKEN).safeIncreaseAllowance(
      address(DEX_HANDLER),
      _amountIn
    );
    try
      DEX_HANDLER.swapV3Single(
        PAIRED_LP_TOKEN,
        rewardsToken,
        REWARDS_POOL_FEE,
        _amountIn,
        (_amountOut * (1000 - _slippage)) / 1000,
        address(this)
      )
    {
      if (_adminAmt > 0) {
        IERC20(PAIRED_LP_TOKEN).safeTransfer(
          Ownable(address(V3_TWAP_UTILS)).owner(),
          _adminAmt
        );
      }
      _rewardsSwapSlippage = 20;
      _depositRewards(
        rewardsToken,
        IERC20(rewardsToken).balanceOf(address(this)) - _balBefore
      );
    } catch {
      if (!_isSlipOverride && _rewardsSwapSlippage < 200) {
        _rewardsSwapSlippage += 10;
      }
      IERC20(PAIRED_LP_TOKEN).safeDecreaseAllowance(
        address(DEX_HANDLER),
        _amountIn
      );
    }
  }

  function beginningOfMonth(uint256 _timestamp) public pure returns (uint256) {
    (, , uint256 _dayOfMonth) = BokkyPooBahsDateTimeLibrary.timestampToDate(
      _timestamp
    );
    return _timestamp - ((_dayOfMonth - 1) * 1 days) - (_timestamp % 1 days);
  }

  function claimReward(address _wallet) external override {
    _distributeReward(_wallet);
    emit ClaimReward(_wallet);
  }

  function getUnpaid(
    address _token,
    address _wallet
  ) public view returns (uint256) {
    if (shares[_wallet] == 0) {
      return 0;
    }
    uint256 earnedRewards = _cumulativeRewards(_token, shares[_wallet]);
    uint256 rewardsExcluded = rewards[_token][_wallet].excluded;
    if (earnedRewards <= rewardsExcluded) {
      return 0;
    }
    return earnedRewards - rewardsExcluded;
  }

  function _cumulativeRewards(
    address _token,
    uint256 _share
  ) internal view returns (uint256) {
    return (_share * _rewardsPerShare[_token]) / PRECISION;
  }
}
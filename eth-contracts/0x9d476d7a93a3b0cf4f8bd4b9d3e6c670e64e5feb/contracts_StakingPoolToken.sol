// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './openzeppelin_contracts_access_Ownable.sol';
import './openzeppelin_contracts_token_ERC20_ERC20.sol';
import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './contracts_interfaces_IDexAdapter.sol';
import './contracts_interfaces_IRewardsWhitelister.sol';
import './contracts_interfaces_IProtocolFeeRouter.sol';
import './contracts_interfaces_IStakingPoolToken.sol';
import './contracts_TokenRewards.sol';

contract StakingPoolToken is IStakingPoolToken, ERC20, Ownable {
  using SafeERC20 for IERC20;

  address public immutable override indexFund;
  address public immutable override poolRewards;
  address public override stakeUserRestriction;
  address public override stakingToken;

  modifier onlyRestricted() {
    require(_msgSender() == stakeUserRestriction, 'R');
    _;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    address _pairedLpToken,
    address _rewardsToken,
    address _stakeUserRestriction,
    IProtocolFeeRouter _feeRouter,
    IRewardsWhitelister _rewardsWhitelist,
    IDexAdapter _dexHandler,
    IV3TwapUtilities _v3TwapUtilities
  ) ERC20(_name, _symbol) {
    indexFund = _msgSender();
    stakeUserRestriction = _stakeUserRestriction;
    poolRewards = address(
      new TokenRewards(
        _feeRouter,
        _rewardsWhitelist,
        _dexHandler,
        _v3TwapUtilities,
        indexFund,
        _pairedLpToken,
        address(this),
        _rewardsToken
      )
    );
  }

  function stake(address _user, uint256 _amount) external override {
    require(stakingToken != address(0), 'I');
    if (stakeUserRestriction != address(0)) {
      require(_user == stakeUserRestriction, 'U');
    }
    _mint(_user, _amount);
    IERC20(stakingToken).safeTransferFrom(_msgSender(), address(this), _amount);
    emit Stake(_msgSender(), _user, _amount);
  }

  function unstake(uint256 _amount) external override {
    _burn(_msgSender(), _amount);
    IERC20(stakingToken).safeTransfer(_msgSender(), _amount);
    emit Unstake(_msgSender(), _amount);
  }

  function setStakingToken(address _stakingToken) external onlyOwner {
    require(stakingToken == address(0), 'S');
    stakingToken = _stakingToken;
  }

  function removeStakeUserRestriction() external onlyRestricted {
    stakeUserRestriction = address(0);
  }

  function setStakeUserRestriction(address _user) external onlyRestricted {
    stakeUserRestriction = _user;
  }

  function _afterTokenTransfer(
    address _from,
    address _to,
    uint256 _amount
  ) internal override {
    if (_from != address(0) && _from != address(0xdead)) {
      TokenRewards(poolRewards).setShares(_from, _amount, true);
    }
    if (_to != address(0) && _to != address(0xdead)) {
      TokenRewards(poolRewards).setShares(_to, _amount, false);
    }
  }
}
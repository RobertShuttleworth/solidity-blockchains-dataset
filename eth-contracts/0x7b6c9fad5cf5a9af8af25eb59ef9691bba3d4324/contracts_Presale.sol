// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import './openzeppelin_contracts_access_Ownable.sol';
import './openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol';
import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_utils_ReentrancyGuard.sol';
import './openzeppelin_contracts_utils_Pausable.sol';
import './contracts_interfaces_IAggregator.sol';
import './contracts_interfaces_IStaking.sol';

contract Presale is Ownable, ReentrancyGuard, Pausable {
  using SafeERC20 for IERC20;

  IERC20 public tokenAddress;
  IERC20 public usdtAddress;
  IAggregator public aggregatorContract;
  IStaking public stakingContract;
  address public paymentWallet;
  uint256 public startTime;
  uint256 public endTime;
  uint256 public maxTokensToBuy;
  uint256 public totalTokensSold;
  uint256 public totalBoughtAndStaked;

  uint256 public currentPhase;
  uint256[][3] public phases;
  uint256 public usdRaised;

  mapping(address => uint256) public userDeposits;
  mapping(address => bool) public hasClaimed;

  struct PhaseData {
    uint256 currentPhase;
    uint256 phaseMaxTokens;
    uint256 phasePrice;
    uint256 phaseEndTime;
  }

  event SaleTimeUpdated(bytes32 indexed key, uint256 prevValue, uint256 newValue, uint256 timestamp);
  event TokensBought(address indexed user, uint256 indexed tokensBought, address indexed purchaseToken, uint256 usdPrice, uint256 timestamp);
  event TokensBoughtAndStaked(address indexed user, uint256 indexed tokensBought, address indexed purchaseToken, uint256 usdPrice, uint256 timestamp);
  event TokensClaimed(address indexed user, uint256 amount, uint256 timestamp);
  event TokensClaimedAndStaked(address indexed user, uint256 amount, uint256 timestamp);

  modifier checkSaleState() {
    require(block.timestamp >= startTime && block.timestamp <= endTime, 'Invalid time for buying');
    _;
  }

  constructor() Ownable(msg.sender) {}

  /**
   * @dev To start the presale
   * @param tokenAddress_ Token address
   * @param stakingContract_ Staking contract address
   * @param paymentWallet_ Payment wallet address
   * @param startTime_ Start time
   * @param endTime_ End time
   * @param maxTokensToBuy_ Max tokens to buy
   */
  function initializePresale(
    address tokenAddress_,
    address usdtAddress_,
    address aggregatorContract_,
    address stakingContract_,
    address paymentWallet_,
    uint256 startTime_,
    uint256 endTime_,
    uint256[][3] memory phases_,
    uint256 maxTokensToBuy_
  ) external onlyOwner {
    tokenAddress = IERC20(tokenAddress_);
    usdtAddress = IERC20(usdtAddress_);
    aggregatorContract = IAggregator(aggregatorContract_);
    stakingContract = IStaking(stakingContract_);
    paymentWallet = paymentWallet_;
    startTime = startTime_;
    endTime = endTime_;
    phases = phases_;
    maxTokensToBuy = maxTokensToBuy_;
  }

  /**
   * @dev To calculate the current phase.
   * @param amount_ Number of tokens
   */
  function _checkCurrentPhase(uint256 amount_) private view returns (uint256 phase) {
    if ((totalTokensSold + amount_ >= phases[currentPhase][0] || (block.timestamp >= phases[currentPhase][2])) && currentPhase < 3) {
      phase = currentPhase + 1;
    } else {
      phase = currentPhase;
    }
  }

  /**
   * @dev To calculate and update the current phase.
   * @param amount_ Number of tokens
   */
  function _checkAndUpdateCurrentPhase(uint256 amount_) private returns (uint256 phase) {
    if ((totalTokensSold + amount_ >= phases[currentPhase][0] || (block.timestamp >= phases[currentPhase][2])) && currentPhase < 3) {
      currentPhase++;
      phase = currentPhase;
    } else {
      phase = currentPhase;
    }
  }

  /**
   * @dev To get latest ETH price in 10**18 format
   */
  function getLatestPrice() public view returns (uint256) {
    (, int256 price, , , ) = aggregatorContract.latestRoundData();
    price = (price * (10 ** 10));
    return uint256(price);
  }

  /**
   * @dev To buy into a presale using USDT
   * @param amount_ Number of tokens to buy
   * @param stake_ boolean flag for token staking
   */
  function buyWithUSDT(uint256 amount_, bool stake_) external checkSaleState whenNotPaused nonReentrant {
    require(address(tokenAddress) != address(0), 'Sale token not added');
    require(amount_ > 0, 'Amount can not be zero');
    require(maxTokensToBuy >= amount_, 'Amount exceeds max tokens to buy');

    _checkAndUpdateCurrentPhase(amount_);
    uint256 usdPrice = (amount_ * phases[currentPhase][1]) / 1e18;
    usdRaised += usdPrice;
    totalTokensSold += amount_;

    usdtAddress.safeTransferFrom(msg.sender, paymentWallet, usdPrice);

    if (stake_) {
      tokenAddress.approve(address(stakingContract), amount_);
      IStaking(stakingContract).depositByPresale(msg.sender, amount_);
      emit TokensBoughtAndStaked(msg.sender, amount_, address(usdtAddress), usdPrice, block.timestamp);
    } else {
      userDeposits[msg.sender] += amount_;
      emit TokensBought(msg.sender, amount_, address(usdtAddress), usdPrice, block.timestamp);
    }
  }

  /**
   * @dev To buy into a presale using ETH
   * @param amount_ Number of tokens to buy
   * @param stake_ boolean flag for token staking
   */
  function buyWithETH(uint256 amount_, bool stake_) external payable checkSaleState whenNotPaused nonReentrant {
    require(address(tokenAddress) != address(0), 'Sale token not added');
    require(amount_ > 0, 'Amount can not be zero');
    require(maxTokensToBuy >= amount_, 'Amount exceeds max tokens to buy');

    _checkAndUpdateCurrentPhase(amount_);
    uint256 usdPrice = (amount_ * phases[currentPhase][1]) / 1e18;
    uint256 ethAmount = (usdPrice * 1e18) / getLatestPrice();
    require(msg.value >= ethAmount, 'Insufficient ETH amount');

    usdRaised += usdPrice;
    totalTokensSold += amount_;

    (bool success, ) = paymentWallet.call{value: msg.value}('');
    require(success, 'Transfer fail.');

    if (stake_) {
      tokenAddress.approve(address(stakingContract), amount_);
      IStaking(stakingContract).depositByPresale(msg.sender, amount_);
      emit TokensBoughtAndStaked(msg.sender, amount_, address(usdtAddress), usdPrice, block.timestamp);
    } else {
      userDeposits[msg.sender] += amount_;
      emit TokensBought(msg.sender, amount_, address(usdtAddress), usdPrice, block.timestamp);
    }
  }

  /**
   * @dev To claim tokens after claiming starts
   */
  function claim(bool stake_) external whenNotPaused nonReentrant {
    require(address(tokenAddress) != address(0), 'Sale token not added');
    require(block.timestamp > endTime, 'Claim has not started yet');
    require(!hasClaimed[msg.sender], 'Already claimed');

    hasClaimed[msg.sender] = true;
    uint256 amount_ = userDeposits[msg.sender];
    require(amount_ > 0, 'Nothing to claim');

    delete userDeposits[msg.sender];

    if (stake_) {
      tokenAddress.approve(address(stakingContract), amount_);
      IStaking(stakingContract).depositByPresale(msg.sender, amount_);
      emit TokensClaimedAndStaked(msg.sender, amount_, block.timestamp);
    } else {
      tokenAddress.safeTransfer(msg.sender, amount_);
      emit TokensClaimed(msg.sender, amount_, block.timestamp);
    }
  }

  /**
   * @dev To update the sale times
   * @param startTime_ New start time
   * @param endTime_ New end time
   */
  function changeSaleTimes(uint256 startTime_, uint256 endTime_) external onlyOwner {
    require(startTime_ > 0 || endTime_ > 0, 'Invalid parameters');

    if (startTime_ > 0) {
      require(block.timestamp < startTime, 'Sale already started');
      require(block.timestamp < startTime_, 'Sale time in past');

      uint256 prevValue = startTime;
      startTime = startTime_;
      emit SaleTimeUpdated(bytes32('START'), prevValue, startTime_, block.timestamp);
    }

    if (endTime_ > 0) {
      require(endTime_ > startTime, 'Invalid endTime');

      uint256 prevValue = endTime;
      endTime = endTime_;
      emit SaleTimeUpdated(bytes32('END'), prevValue, endTime_, block.timestamp);
    }
  }

  /**
   * @dev To get the price in USD for given amount of tokens.
   * @param amount_ Number of tokens
   */
  function getCurrentUSDPrice(uint256 amount_) public view returns (uint256 usdtAmount) {
    usdtAmount = (amount_ * phases[_checkCurrentPhase(amount_)][1]) / 1e18;
  }

  /**
   * @dev To get the price in ETH for given amount of tokens.
   * @param amount_ Number of tokens
   */
  function getCurrentETHPrice(uint256 amount_) public view returns (uint256 ethAmount) {
    uint256 usdPrice = (amount_ * phases[_checkCurrentPhase(amount_)][1]) / 1e18;
    ethAmount = (usdPrice * 1e18) / getLatestPrice();
  }

  /**
   * @dev To get the number of tokens for a given amount in USDT.
   * @param usdtAmount_ Amount in USDT
   */
  function getTokensFromUSDT(uint256 usdtAmount_) public view returns (uint256 tokensAmount) {
    tokensAmount = (usdtAmount_ * 1e18) / phases[_checkCurrentPhase(0)][1];
  }

  /**
   * @dev To get the number of tokens for a given amount in ETH.
   * @param ethAmount_ Amount in ETH
   */
  function getTokensFromETH(uint256 ethAmount_) public view returns (uint256 tokensAmount) {
    uint256 usdPricePerToken = phases[_checkCurrentPhase(0)][1];
    uint256 usdValue = (ethAmount_ * getLatestPrice()) / 1e18;
    tokensAmount = (usdValue * 1e18) / (usdPricePerToken * 1e12);
  }

  /**
   * @dev To get the current phase data.
   */
  function getCurrentPhaseData() public view returns (PhaseData memory) {
    PhaseData memory currentPhaseData;
    currentPhaseData.currentPhase = _checkCurrentPhase(0);
    currentPhaseData.phaseMaxTokens = phases[currentPhase][0];
    currentPhaseData.phasePrice = phases[currentPhase][1];
    currentPhaseData.phaseEndTime = phases[currentPhase][2];

    return currentPhaseData;
  }

  /**
   * @dev To update the phases
   */
  function changePhases(uint256[][3] memory phases_) external onlyOwner {
    phases = phases_;
  }

  /**
   * @dev To update a single phase
   */
  function updatePhase(uint256 phaseIndex_, uint256 phaseMaxTokens_, uint256 phasePrice_, uint256 phaseEndTime_) external onlyOwner {
    phases[phaseIndex_][0] = phaseMaxTokens_;
    phases[phaseIndex_][1] = phasePrice_;
    phases[phaseIndex_][2] = phaseEndTime_;
  }

  /**
   * @dev To update the maxTokensToBuy
   */
  function updateMaxTokensToBuy(uint256 maxTokensToBuy_) external onlyOwner {
    maxTokensToBuy = maxTokensToBuy_;
  }

  /**
   * @dev To pause the presale
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @dev To unpause the presale
   */
  function unpause() external onlyOwner {
    _unpause();
  }
}
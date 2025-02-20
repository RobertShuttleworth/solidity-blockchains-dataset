// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import './openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol';
import './openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol';

import './openzeppelin_contracts_interfaces_IERC20Metadata.sol';
import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';

import './contracts_launchpad_multi-platform_public-sale_interface_IMultiPlatformSaleFactory.sol';
import './contracts_launchpad_multi-platform_public-sale_interface_IMultiPlatformPublicSaleInit.sol';
import './contracts_launchpad_multi-platform_public-sale_interface_IMultiPlatformPublicSale.sol';

import './contracts_launchpad_sale-gateway_interface_ISaleGateway.sol';
import './contracts_util_SaleLibrary.sol';

contract MultiPlatformPublicSale is
  Initializable,
  IMultiPlatformPublicSaleInit,
  IMultiPlatformPublicSale,
  PausableUpgradeable,
  ReentrancyGuardUpgradeable
{
  using SafeERC20 for IERC20Metadata;

  uint256 public targetUsdRaised; // How much usd targetted
  uint256 public feeMoved; // Fee amount that already been moved (usd decimal)

  uint256 public whitelistTotalAlloc;
  uint256 public tokenPriceInUsdDecimal; // usd decimal

  uint128 internal minFCFSBuy;
  uint128 internal maxFCFSBuy;

  uint128 internal minComBuy;
  uint128 internal maxComBuy;

  address[] internal whitelists;
  address[] internal voters;

  ISaleGateway public saleGateway;
  IMultiPlatformSaleFactory public factory;
  IERC20Metadata public payment;

  mapping(uint128 => Booster) public booster; // detail each booster
  mapping(uint240 => address[]) public chainBuyers; // buyers each chain
  mapping(uint256 => address[]) internal platformStakers; // staker each platform

  mapping(uint256 => uint256) public platformTargetUsdRaisedPercentage_d2; // usd target percentage each platform

  mapping(address => string) public recipient; // store nonEVM address if needed
  mapping(address => uint256) public whitelist; // whitelist amount
  mapping(uint256 => mapping(address => uint256)) public platformStakerIndex; // staker index

  mapping(uint256 => mapping(uint240 => mapping(address => uint256))) public willBePlatformChainVoterStaked; // will-be-voter staked amount each chain
  mapping(uint256 => uint256) public totalPlatformVoterStaked; // total voter staked amount

  mapping(uint240 => mapping(address => bool)) public isChainBuyer; // check whether user is buyer each chain
  mapping(uint240 => mapping(address => Invoice[])) public chainInvoices; // user invoice detail each chain
  mapping(uint240 => mapping(address => mapping(uint128 => uint256))) public boosterChainBuyerUsdPaid; // user received amount each chain per booster

  mapping(uint240 => uint256) internal chainUsdAchieved; // payment received each chain
  mapping(uint240 => uint256) internal chainFee; // fee received each chain

  mapping(uint240 => uint256[]) internal chainBuyersUsdPaid; // user's price paid each chain
  mapping(uint240 => uint256[]) internal chainBuyersTokenReceived; // user's token received each chain
  mapping(uint240 => uint256[]) internal chainBuyersFee; // user's fee deducted each chain

  mapping(uint240 => mapping(address => uint256)) internal chainBuyersIndex; // user index each chain
  mapping(address => mapping(uint128 => uint256)) internal userAllocation; // user's allocation each booster

  struct Booster {
    uint128 start;
    uint128 end;
    uint256 fee_d2;
    uint256 usdAchieved;
  }

  struct Invoice {
    uint256 userIndex;
    uint128 boosterId;
    uint256 usdPaid;
    uint256 tokenReceived;
    uint256 feeCharged;
  }

  // ========  vote
  bytes32 internal constant FORM_TYPEHASH = keccak256('Form(address from,string content)');

  bytes32 public DOMAIN_SEPARATOR;
  string public name;
  string public version;
  string public message;

  mapping(address => bool) public isVoteValid;

  struct Form {
    address from;
    string content;
  }
  // ========  vote

  event TokenBought(
    uint240 chainID,
    uint128 booster,
    address buyer,
    uint256 usdPaid,
    uint256 tokenReceived,
    uint256 feeCharged
  );

  /**
   * @dev Initialize project for raise fund
   * @param _startInEpoch Epoch date to start booster 1
   * @param _durationPerBoosterInSeconds Duration per booster (in seconds)
   * @param _targetUsdRaised Amount sale to raise (usd decimal)
   * @param _platformPercentage_d2 Sale percentage per platform (2 decimal)
   * @param _tokenPriceInUsdDecimal Token project price (usd decimal)
   * @param _feePercentage_d2 Fee project percentage in each boosters (2 decimal)
   * @param _usdPaymentToken Tokens to raise
   * @param _nameVersionMsg Project EIP712 name, version, message
   */
  function init(
    uint128 _startInEpoch,
    uint128 _durationPerBoosterInSeconds,
    uint256 _targetUsdRaised,
    uint256[] calldata _platformPercentage_d2,
    uint256 _tokenPriceInUsdDecimal,
    uint256[4] calldata _feePercentage_d2,
    address _usdPaymentToken,
    string[3] calldata _nameVersionMsg
  ) external override initializer {
    __Pausable_init();
    __ReentrancyGuard_init();

    uint8 _i = 1;
    do {
      if (_i == 1) {
        booster[_i].start = _startInEpoch;
      } else {
        booster[_i].start = booster[_i - 1].end + 1;
      }
      if (_i < 4) booster[_i].end = booster[_i].start + _durationPerBoosterInSeconds;
      booster[_i].fee_d2 = _feePercentage_d2[_i - 1];

      ++_i;
    } while (_i <= 4);

    targetUsdRaised = _targetUsdRaised;
    for (_i = 0; _i < _platformPercentage_d2.length; ++_i) {
      platformTargetUsdRaisedPercentage_d2[_i] = _platformPercentage_d2[_i];
    }

    payment = IERC20Metadata(_usdPaymentToken);
    factory = IMultiPlatformSaleFactory(_msgSender());
    saleGateway = ISaleGateway(factory.saleGateway());

    tokenPriceInUsdDecimal = _tokenPriceInUsdDecimal;
    message = _nameVersionMsg[2];
    _createDomain(_nameVersionMsg[0], _nameVersionMsg[1]);
  }

  // **** VIEW AREA ****

  function _isEligible() internal view virtual {
    require((_msgSender() == factory.savior() || _msgSender() == owner()), 'restricted');
  }

  function _onlyOwner() internal view virtual {
    require(_msgSender() == owner(), 'unauthorized');
  }

  function _isUsdSufficient(uint256 _amount) internal view virtual {
    require(payment.balanceOf(address(this)) >= _amount, 'insufficient');
  }

  function _isNotStarted() internal view virtual {
    require(uint128(block.timestamp) < booster[1].start, 'started');
  }

  function _isUserStakerInPlatform(uint256 _platformIndex, address _user) internal view returns (bool) {
    if (platformStakers[_platformIndex].length == 0) return false;
    return platformStakers[_platformIndex][platformStakerIndex[_platformIndex][_user]] == _user;
  }

  /**
   * @dev Calculate amount in
   * @param _usdIn USD paid amount
   * @param _buyer User address
   * @param _boosterProgress Booster running
   */
  function _usdInRecalc(
    uint240 _chainID,
    uint256 _alloc,
    uint256 _usdIn,
    address _buyer,
    uint128 _boosterProgress
  ) internal view virtual returns (uint256 usdPaidFinal, uint256 tokenReceivedFinal) {
    usdPaidFinal = _usdIn;

    // adjust to usd left to be raised
    uint256 _targetUsdRaisedLeft = targetUsdRaised - totalUsdAchieved();
    if (usdPaidFinal > _targetUsdRaisedLeft) usdPaidFinal = _targetUsdRaisedLeft;

    // adjust to buyer allocation
    uint256 _usdPaidCurrentBooster = boosterChainBuyerUsdPaid[_chainID][_buyer][_boosterProgress];
    if (_usdPaidCurrentBooster + usdPaidFinal > _alloc) usdPaidFinal = _alloc - _usdPaidCurrentBooster;

    require(usdPaidFinal > 0, 'invalid usdIn');

    // validate limit
    if (_boosterProgress == 3) {
      require(maxFCFSBuy > 0 && usdPaidFinal >= minFCFSBuy, '<min');
    } else if (_boosterProgress == 4) {
      require(maxComBuy > 0 && usdPaidFinal >= minComBuy, '<min');
    }

    tokenReceivedFinal = SaleLibrary.calcTokenReceived(usdPaidFinal, tokenPriceInUsdDecimal);
  }

  function owner() public view virtual returns (address) {
    return factory.owner();
  }

  /**
   * @dev Get booster running now, 0 = no booster running
   */
  function boosterRunning() public view virtual returns (uint128 running) {
    for (uint128 _i = 1; _i <= 4; ++_i) {
      if (
        (uint128(block.timestamp) >= booster[_i].start && uint128(block.timestamp) <= booster[_i].end) ||
        (_i == 4 && uint128(block.timestamp) >= booster[_i].start)
      ) {
        running = _i;
        break;
      }
    }
  }

  function platformNameTargetUsdRaisedPercentage_d2(string calldata _platform) external view virtual returns (uint256) {
    uint256 _platformIndex = factory.getPlatformIndex(_platform);
    return platformTargetUsdRaisedPercentage_d2[_platformIndex];
  }

  function minMaxFcfs() external view returns (uint256 min, uint256 max) {
    min = minFCFSBuy;
    max = maxFCFSBuy;
  }

  function minMaxCom() external view returns (uint256 min, uint256 max) {
    min = minComBuy;
    max = maxComBuy;
  }

  /**
   * @dev Get total usd raised without fee
   */
  function totalUsdAchieved() public view virtual returns (uint256 totalUsdAchievedNumber) {
    for (uint128 i = 1; i <= 4; ++i) {
      totalUsdAchievedNumber += booster[i].usdAchieved;
    }
  }

  /**
   * @dev Get sale report summaries
   */
  function saleSummaries() external view virtual returns (uint256 totalBuyers, uint256 totalFee) {
    uint256 _chainStakedLength = factory.allChainsStakedLength();
    for (uint256 i = 0; i < _chainStakedLength; ++i) {
      uint240 _chainID = uint240(factory.allChainsStaked(i));

      totalBuyers += chainBuyers[_chainID].length;
      totalFee += chainFee[_chainID];
    }
  }

  /**
   * @dev Get all detail length number
   */
  function saleDetailLength() external view virtual returns (uint256 whitelistLength, uint256 voterLength) {
    whitelistLength = whitelists.length;
    voterLength = voters.length;
  }

  function buyerData(
    address _buyer
  ) external view virtual returns (uint256 invoiceLength, uint256 usdPaid, uint256 tokenReceived, uint256 feePaid) {
    uint256 _chainStakedLength = factory.allChainsStakedLength();
    for (uint256 i = 0; i < _chainStakedLength; ++i) {
      uint240 _chainID = uint240(factory.allChainsStaked(i));

      invoiceLength += chainInvoices[_chainID][_buyer].length;
      uint256 buyerIndex = chainBuyersIndex[_chainID][_buyer];
      usdPaid = chainBuyersUsdPaid[_chainID][buyerIndex];
      tokenReceived = chainBuyersTokenReceived[_chainID][buyerIndex];
      feePaid = chainBuyersFee[_chainID][buyerIndex];
    }
  }

  /**
   * @dev Get User Total Staked Per Platform
   * @param _platformIndex Platform by index
   * @param _staker User address
   */
  function totalPlatformUserStaked(
    uint256 _platformIndex,
    address _staker
  ) public view virtual returns (uint256 totalPlatformStakedNumber) {
    uint256 _chainStakedLength = factory.allChainsStakedLength();
    for (uint256 i = 0; i < _chainStakedLength; ++i) {
      totalPlatformStakedNumber += willBePlatformChainVoterStaked[_platformIndex][uint240(factory.allChainsStaked(i))][
        _staker
      ];
    }
  }

  function platformStakerLength(uint256 _platformIndex) external view virtual returns (uint256) {
    return platformStakers[_platformIndex].length;
  }

  function chainBuyersLength(uint240 _chainID) external view virtual returns (uint256) {
    return chainBuyers[_chainID].length;
  }

  /**
   * @dev Get total number invoices of chainID of buyer
   */
  function chainBuyerInvoicesLength(uint240 _chainID, address _buyer) external view virtual returns (uint256) {
    return chainInvoices[_chainID][_buyer].length;
  }

  function payload(uint240 _chainID) external view virtual returns (bytes memory payloadValue) {
    payloadValue = abi.encode(
      _chainID,
      chainUsdAchieved[_chainID],
      chainFee[_chainID],
      chainBuyers[_chainID],
      chainBuyersUsdPaid[_chainID],
      chainBuyersTokenReceived[_chainID],
      chainBuyersFee[_chainID]
    );
  }

  /**
   * @dev Get User Total Staked Allocation
   * @param _buyer User address
   * @param _boosterProgress Booster progress
   */
  function calcBuyerAllocationInUsd(
    address _buyer,
    uint128 _boosterProgress
  ) public view virtual returns (uint256 userAlloc) {
    if (_boosterProgress == 0 || _boosterProgress > 4) return 0;
    if (_boosterProgress == 4) return maxComBuy;

    uint256 _platformLength = factory.allPlatformsLength();
    bool _isVoteValid = isVoteValid[_buyer];
    uint256 _targetUsdRaised = targetUsdRaised;

    for (uint256 _i = 0; _i < _platformLength; ++_i) {
      if (_boosterProgress == 3) {
        if (_isUserStakerInPlatform(_i, _buyer) || whitelist[_buyer] > 0) {
          userAlloc = maxFCFSBuy;
        }
        break;
      }

      uint256 _buyerStaked = totalPlatformUserStaked(_i, _buyer);
      uint256 _totalStaked = totalPlatformVoterStaked[_i];

      uint256 _platformPercentage_d2 = platformTargetUsdRaisedPercentage_d2[_i];
      uint256 _platformTargetUsdRaised = SaleLibrary.calcAmountPercentageAnyDecimal(
        _targetUsdRaised,
        _platformPercentage_d2,
        2
      );

      if (_buyerStaked > 0 && _totalStaked > 0 && _isVoteValid) {
        if (_boosterProgress == 2) {
          userAlloc += SaleLibrary.calcAllocInUsd(
            _buyerStaked,
            _totalStaked,
            _platformTargetUsdRaised -
              SaleLibrary.calcAmountPercentageAnyDecimal(booster[1].usdAchieved, _platformPercentage_d2, 2)
          );
          continue;
        }

        // booster 1
        userAlloc += SaleLibrary.calcAllocInUsd(
          _buyerStaked,
          _totalStaked,
          _platformTargetUsdRaised -
            SaleLibrary.calcAmountPercentageAnyDecimal(whitelistTotalAlloc, _platformPercentage_d2, 2)
        );
      }

      if (_i == _platformLength - 1) {
        uint256 whitelistAmount = whitelist[_buyer];
        if (whitelistAmount > 0) userAlloc += whitelistAmount;
      }
    }
  }

  // **** MAIN AREA ****

  function _releaseToken(address _target, uint256 _amount) internal virtual {
    payment.safeTransfer(_target, _amount);
  }

  /**
   * @dev Set buyer id
   * @param _buyer User address
   */
  function _setUser(uint240 _chainID, address _buyer) internal virtual returns (uint256) {
    if (!isChainBuyer[_chainID][_buyer]) {
      isChainBuyer[_chainID][_buyer] = true;

      chainBuyersIndex[_chainID][_buyer] = chainBuyers[_chainID].length;
      chainBuyers[_chainID].push(_buyer);
      chainBuyersUsdPaid[_chainID].push(0);
      chainBuyersTokenReceived[_chainID].push(0);
      chainBuyersFee[_chainID].push(0);
    }

    return chainBuyersIndex[_chainID][_buyer];
  }

  /**
   * @dev Move raised fund to devAddr/project owner
   */
  function moveFund(uint256 _percent_d2, bool _devAddr, address _target) external virtual whenPaused {
    _isEligible();

    uint256 _amount = SaleLibrary.calcAmountPercentageAnyDecimal(
      chainUsdAchieved[uint240(block.chainid)],
      _percent_d2,
      2
    );

    _isUsdSufficient(_amount);

    if (_devAddr) {
      _releaseToken(factory.operational(), _amount);
    } else {
      _releaseToken(_target, _amount);
    }
  }

  function forceMoveFund() external virtual {
    _isEligible();

    _releaseToken(factory.operational(), payment.balanceOf(address(this)));
  }

  /**
   * @dev Move fee to devAddr
   */
  function moveFee() external virtual {
    _isEligible();

    uint256 _amount = chainFee[uint240(block.chainid)];
    uint256 _left = _amount - feeMoved;

    _isUsdSufficient(_left);
    require(_left > 0, 'bad');

    feeMoved = _amount;

    _releaseToken(
      factory.operational(),
      SaleLibrary.calcAmountPercentageAnyDecimal(_left, factory.operationalPercentage_d2(), 2)
    );
    _releaseToken(
      factory.marketing(),
      SaleLibrary.calcAmountPercentageAnyDecimal(_left, factory.marketingPercentage_d2(), 2)
    );
    _releaseToken(
      factory.treasury(),
      SaleLibrary.calcAmountPercentageAnyDecimal(_left, factory.treasuryPercentage_d2(), 2)
    );
  }

  /**
   * @dev Buy token project using token raise
   * @param _chainID ChainID when buy token
   * @param _usdIn Buy amount
   * @param _buyer Buyer address
   */
  function buyToken(uint240 _chainID, uint256 _usdIn, address _buyer) external virtual override nonReentrant {
    uint128 _running = boosterRunning();
    require(_running > 0, '!booster');

    address _sender = _msgSender();
    if (_sender != address(saleGateway)) {
      _chainID = uint240(block.chainid);
      _buyer = _sender;
    }

    uint256 _buyerIndex = _setUser(_chainID, _buyer);
    if (_sender == address(saleGateway) && paused()) {
      return;
    }

    _requireNotPaused();

    uint256 _buyerAllocation = calcBuyerAllocationInUsd(_buyer, _running);
    require(_buyerAllocation > 0, '!alloc');

    (uint256 _usdInFinal, uint256 _tokenReceivedFinal) = _usdInRecalc(
      _chainID,
      _buyerAllocation,
      _usdIn,
      _buyer,
      _running
    );

    uint256 _feeCharged;
    if (whitelist[_buyer] == 0)
      _feeCharged = SaleLibrary.calcAmountPercentageAnyDecimal(_usdInFinal, booster[_running].fee_d2, 2);

    chainInvoices[_chainID][_buyer].push(Invoice(_buyerIndex, _running, _usdInFinal, _tokenReceivedFinal, _feeCharged));

    booster[_running].usdAchieved += _usdInFinal;

    // chain
    chainUsdAchieved[_chainID] += _usdInFinal;
    chainFee[_chainID] += _feeCharged;

    // user
    chainBuyersUsdPaid[_chainID][_buyerIndex] += _usdInFinal;
    chainBuyersTokenReceived[_chainID][_buyerIndex] += _tokenReceivedFinal;
    chainBuyersFee[_chainID][_buyerIndex] += _feeCharged;
    boosterChainBuyerUsdPaid[_chainID][_buyer][_running] += _usdInFinal;

    if (_sender != address(saleGateway)) payment.safeTransferFrom(_buyer, address(this), _usdInFinal + _feeCharged);

    emit TokenBought(_chainID, _running, _buyer, _usdInFinal, _tokenReceivedFinal, _feeCharged);
  }

  /**
   * @dev Internal team buy
   * @param _usdIn Usd amount to buy
   */
  function teamBuy(uint256 _usdIn) external virtual whenNotPaused {
    _isEligible();

    uint128 _running = boosterRunning();
    require(_running > 2, 'bad');

    address _buyer = _msgSender();
    uint240 _chainID = uint240(block.chainid);
    uint256 _buyerIndex = _setUser(_chainID, _buyer);

    uint256 _usdLeft = targetUsdRaised - totalUsdAchieved();
    if (_usdIn > _usdLeft) _usdIn = _usdLeft;

    uint256 _tokenReceivedFinal = SaleLibrary.calcTokenReceived(_usdIn, tokenPriceInUsdDecimal);

    chainInvoices[uint240(block.chainid)][_buyer].push(Invoice(_buyerIndex, _running, _usdIn, _tokenReceivedFinal, 0));

    booster[_running].usdAchieved += _usdIn;

    // chain
    chainUsdAchieved[_chainID] += _usdIn;

    // user
    chainBuyersUsdPaid[_chainID][_buyerIndex] += _usdIn;
    chainBuyersTokenReceived[_chainID][_buyerIndex] += _tokenReceivedFinal;
    boosterChainBuyerUsdPaid[_chainID][_buyer][_running] += _usdIn;

    emit TokenBought(_chainID, _running, _buyer, _usdIn, _tokenReceivedFinal, 0);
  }

  /**
   * @dev Set recipient address
   * @param _recipient Recipient address
   */
  function setRecipient(string memory _recipient) external virtual whenNotPaused {
    require((targetUsdRaised - totalUsdAchieved() > 0) && bytes(_recipient).length > 0, 'bad');

    recipient[_msgSender()] = _recipient;
  }

  // **** ADMIN AREA ****

  function setPlatformStakers(uint256 _platformIndex, address[] calldata _staker) external virtual {
    _onlyOwner();
    _isNotStarted();

    for (uint256 _i = 0; _i < _staker.length; ++_i) {
      if (platformStakers[_platformIndex].length > 0 && _isUserStakerInPlatform(_platformIndex, _staker[_i])) continue;

      platformStakerIndex[_platformIndex][_staker[_i]] = platformStakers[_platformIndex].length;
      platformStakers[_platformIndex].push(_staker[_i]);
    }
  }

  /**
   * @dev Set user total staked
   * @param _buyers User address
   */
  function setWillBePlatformChainVoterStaked(
    uint256 _platformIndex,
    uint240 _chainID,
    address[] calldata _buyers,
    uint256[] calldata _stakedAmount
  ) external virtual {
    _onlyOwner();
    _isNotStarted();

    uint240 _currentChainID = uint240(factory.allChainsStaked(factory.getChainStakedIndex(_chainID)));
    require(_chainID == _currentChainID && _buyers.length == _stakedAmount.length, 'bad');

    for (uint256 i = 0; i < _buyers.length; ++i) {
      if (
        !_isUserStakerInPlatform(_platformIndex, _buyers[i]) ||
        willBePlatformChainVoterStaked[_platformIndex][_chainID][_buyers[i]] > 0
      ) continue;

      willBePlatformChainVoterStaked[_platformIndex][_chainID][_buyers[i]] = _stakedAmount[i];
    }
  }

  function removeWillBePlatformChainVoterStaked(
    uint256 _platformIndex,
    uint240 _chainID,
    address[] calldata _buyers
  ) external virtual {
    _onlyOwner();
    _isNotStarted();

    uint240 _currentChainID = uint240(factory.allChainsStaked(factory.getChainStakedIndex(_chainID)));
    require(_chainID == _currentChainID, '!chainID');

    for (uint256 i = 0; i < _buyers.length; ++i) {
      if (
        !_isUserStakerInPlatform(_platformIndex, _buyers[i]) ||
        willBePlatformChainVoterStaked[_platformIndex][_chainID][_buyers[i]] == 0
      ) continue;

      delete willBePlatformChainVoterStaked[_platformIndex][_chainID][_buyers[i]];
    }
  }

  /**
   * @dev Set whitelist allocation token in 6 decimal
   * @param _whitelist User address
   * @param _allocationInUsd_d6 Usd allocation in 6 decimal
   */
  function setWhitelist(address[] calldata _whitelist, uint256[] calldata _allocationInUsd_d6) external virtual {
    _onlyOwner();
    _isNotStarted();

    require(_whitelist.length == _allocationInUsd_d6.length, 'bad');

    uint256 _whitelistTotal = whitelistTotalAlloc;
    for (uint256 i = 0; i < _whitelist.length; ++i) {
      if (whitelist[_whitelist[i]] > 0) continue;

      whitelists.push(_whitelist[i]);
      whitelist[_whitelist[i]] = SaleLibrary.calcAmountAnyDecimal(_allocationInUsd_d6[i], 6, payment.decimals());
      _whitelistTotal += whitelist[_whitelist[i]];
    }

    whitelistTotalAlloc = _whitelistTotal;
  }

  /**
   * @dev Update whitelist allocation token in 6 decimal
   * @param _whitelist User address
   * @param _allocationInUsd_d6 Usd allocation in 6 decimal
   */
  function updateWhitelist(address[] calldata _whitelist, uint256[] calldata _allocationInUsd_d6) external virtual {
    _onlyOwner();
    _isNotStarted();

    require(_whitelist.length == _allocationInUsd_d6.length, 'bad');

    uint256 _whitelistTotal = whitelistTotalAlloc;
    for (uint256 i = 0; i < _whitelist.length; ++i) {
      if (whitelist[_whitelist[i]] == 0) continue;

      uint256 oldAlloc = whitelist[_whitelist[i]];
      whitelist[_whitelist[i]] = SaleLibrary.calcAmountAnyDecimal(_allocationInUsd_d6[i], 6, payment.decimals());
      _whitelistTotal = _whitelistTotal - oldAlloc + whitelist[_whitelist[i]];
    }

    whitelistTotalAlloc = _whitelistTotal;
  }

  /**
   * @dev Set Min & Max in FCFS
   * @param _minMaxFCFSBuy Min and max usd to paid
   */
  function setMinMaxFCFS(uint128[2] calldata _minMaxFCFSBuy) external virtual {
    _onlyOwner();
    if (boosterRunning() < 3) minFCFSBuy = _minMaxFCFSBuy[0];
    maxFCFSBuy = _minMaxFCFSBuy[1];
  }

  /**
   * @dev Set Min & Max in Community Booster
   * @param _minMaxComBuy Min and max usd to paid
   */
  function setMinMaxCom(uint128[2] calldata _minMaxComBuy) external virtual {
    _onlyOwner();
    if (boosterRunning() < 4) minComBuy = _minMaxComBuy[0];
    maxComBuy = _minMaxComBuy[1];
  }

  /**
   * @dev Config sale data
   * @param _targetUsdRaised Amount token project to sell (based on token decimals of project)
   * @param _platformPercentage_d2 Sale percentage per platform (2 decimal)
   * @param _tokenPriceInUsdDecimal Token project price in payment decimal
   * @param _feePercentage_d2 Fee project percent in each boosters in 2 decimal
   * @param _usdPaymentToken _payment Tokens to raise
   */
  function config(
    uint256 _targetUsdRaised,
    uint256[] calldata _platformPercentage_d2,
    uint256 _tokenPriceInUsdDecimal,
    uint256[4] memory _feePercentage_d2,
    address _usdPaymentToken
  ) external virtual {
    _onlyOwner();
    _isNotStarted();

    uint8 _i = 1;
    do {
      booster[_i].fee_d2 = _feePercentage_d2[_i - 1];

      ++_i;
    } while (_i <= 4);

    targetUsdRaised = _targetUsdRaised;
    for (_i = 0; _i < _platformPercentage_d2.length; ++_i) {
      platformTargetUsdRaisedPercentage_d2[_i] = _platformPercentage_d2[_i];
    }

    tokenPriceInUsdDecimal = _tokenPriceInUsdDecimal;
    payment = IERC20Metadata(_usdPaymentToken);
  }

  function updateStart(uint128 _startInEpoch, uint128 _durationPerBoosterInSeconds) external virtual {
    _onlyOwner();
    _isNotStarted();

    uint128 _i = 1;
    do {
      if (_i == 1) {
        booster[_i].start = _startInEpoch;
      } else {
        booster[_i].start = booster[_i - 1].end + 1;
      }
      if (_i < 4) booster[_i].end = booster[_i].start + _durationPerBoosterInSeconds;

      ++_i;
    } while (_i <= 4);
  }

  /**
   * @dev Toggle buyToken pause
   */
  function togglePause() external virtual {
    _onlyOwner();
    if (paused()) {
      _unpause();
    } else {
      _pause();
    }
  }

  // ======= vote

  function _createDomain(string calldata _name, string calldata _version) internal virtual {
    require(bytes(_name).length > 0 && bytes(_version).length > 0, 'bad');

    name = _name;
    version = _version;

    DOMAIN_SEPARATOR = keccak256(
      abi.encode(
        // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
        keccak256(bytes(_name)),
        keccak256(bytes(_version)),
        block.chainid,
        address(this)
      )
    );
  }

  function _hash(Form memory form) internal pure virtual returns (bytes32) {
    return keccak256(abi.encode(FORM_TYPEHASH, form.from, keccak256(bytes(form.content))));
  }

  function verify(address _from, bytes memory _signature) public view virtual returns (bool) {
    if (_signature.length != 65) return false;

    bytes32 r;
    bytes32 s;
    uint8 v;

    assembly {
      r := mload(add(_signature, 0x20))
      s := mload(add(_signature, 0x40))
      v := byte(0, mload(add(_signature, 0x60)))
    }

    Form memory form = Form({from: _from, content: message});

    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', DOMAIN_SEPARATOR, _hash(form)));

    if (v != 27 && v != 28) v += 27;

    return ecrecover(digest, v, r, s) == _from;
  }

  /**
   * @dev Migrate voters from gov contract
   * @param _voters Voter's address
   * @param _signatures Voter's signature
   */
  function migrateVoters(address[] calldata _voters, bytes[] calldata _signatures) external virtual {
    _onlyOwner();
    _isNotStarted();

    require(_voters.length == _signatures.length, 'misslength');

    uint256 _platformLength = factory.allPlatformsLength();
    uint256[] memory _platformVoterStaked = new uint256[](_platformLength);
    bool _isStakerExists;

    for (uint256 _i = 0; _i < _platformLength; ++_i) {
      if (platformStakers[_i].length > 0 && !_isStakerExists) {
        _isStakerExists = true;
      }

      _platformVoterStaked[_i] = totalPlatformVoterStaked[_i];
    }

    if (!_isStakerExists) {
      revert('!stakers');
    }

    for (uint256 _i = 0; _i < _voters.length; ++_i) {
      address _voter = _voters[_i];
      bytes calldata _signature = _signatures[_i];

      if (isVoteValid[_voter] || !verify(_voter, _signature)) continue;

      for (uint256 _j = 0; _j < _platformLength; ++_j) {
        if (!_isUserStakerInPlatform(_j, _voter)) continue;

        uint256 staked = totalPlatformUserStaked(_j, _voter);
        _platformVoterStaked[_j] += staked;

        if (!isVoteValid[_voter]) {
          isVoteValid[_voter] = true;
          voters.push(_voter);
        }
      }
    }

    // assign the new value
    for (uint256 _i = 0; _i < _platformLength; ++_i) {
      totalPlatformVoterStaked[_i] = _platformVoterStaked[_i];
    }
  }

  /**
   * @dev Migrate voters from gov contract without signature. TEST ONLY!!!
   * @param _voters Voter's address
   */
  function migrateVoters2(address[] calldata _voters) external virtual {
    _onlyOwner();
    _isNotStarted();

    uint256 _platformLength = factory.allPlatformsLength();
    uint256[] memory _platformVoterStaked = new uint256[](_platformLength);
    bool _isStakerExists;

    for (uint256 _i = 0; _i < _platformLength; ++_i) {
      if (platformStakers[_i].length > 0 && !_isStakerExists) {
        _isStakerExists = true;
      }

      _platformVoterStaked[_i] = totalPlatformVoterStaked[_i];
    }

    if (!_isStakerExists) {
      revert('!stakers');
    }

    for (uint256 _i = 0; _i < _voters.length; ++_i) {
      address _voter = _voters[_i];

      if (isVoteValid[_voter]) continue;

      for (uint256 _j = 0; _j < _platformLength; ++_j) {
        if (!_isUserStakerInPlatform(_j, _voter)) continue;

        uint256 staked = totalPlatformUserStaked(_j, _voter);
        _platformVoterStaked[_j] += staked;

        if (!isVoteValid[_voter]) {
          isVoteValid[_voter] = true;
          voters.push(_voter);
        }
      }
    }

    // assign the new value
    for (uint256 _i = 0; _i < _platformLength; ++_i) {
      totalPlatformVoterStaked[_i] = _platformVoterStaked[_i];
    }
  }
  // ======= vote
}
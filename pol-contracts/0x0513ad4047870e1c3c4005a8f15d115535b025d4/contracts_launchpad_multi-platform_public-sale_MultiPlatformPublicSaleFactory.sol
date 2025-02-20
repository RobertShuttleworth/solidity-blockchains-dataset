// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import './openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol';
import './openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol';

import './openzeppelin_contracts_proxy_beacon_UpgradeableBeacon.sol';
import './openzeppelin_contracts_proxy_beacon_BeaconProxy.sol';
import './openzeppelin_contracts_utils_Strings.sol';

import './contracts_launchpad_multi-platform_public-sale_interface_IMultiPlatformSaleFactory.sol';
import './contracts_launchpad_multi-platform_public-sale_interface_IMultiPlatformPublicSaleInit.sol';

import './contracts_util_ProxyAdminManagerUpgradeable.sol';

contract MultiPlatformPublicSaleFactory is
  Initializable,
  UUPSUpgradeable,
  OwnableUpgradeable,
  PausableUpgradeable,
  ProxyAdminManagerUpgradeable,
  IMultiPlatformSaleFactory
{
  using Strings for string;

  // d2 = 2 decimal
  uint256 public override operationalPercentage_d2;
  uint256 public override marketingPercentage_d2;
  uint256 public override treasuryPercentage_d2;

  string[] public override allPlatforms; // all platforms supported
  address[] public override allProjects; // all projects created
  address[] public override allUsdPaymentTokens; // all accepted usd payment tokens
  uint256[] public override allChainsStaked;

  address public override beacon;
  address public override savior; // able to spend left tokens
  address public override saleGateway; // destination sale gateway

  address public override operational; // operational address
  address public override marketing; // marketing address
  address public override treasury; // treasury address

  mapping(string => uint256) public override getPlatformIndex;
  mapping(address => uint256) public override getUsdPaymentTokenIndex;
  mapping(uint256 => uint256) public override getChainStakedIndex;
  mapping(address => bool) public override isKnown;

  function init(
    string[] calldata _platforms,
    address _beacon,
    address _savior,
    address _saleGateway
  ) external proxied initializer {
    __UUPSUpgradeable_init();
    __Ownable_init(_msgSender());
    __Pausable_init();
    __ProxyAdminManager_init(_msgSender());

    require(
      _platforms.length > 0 && _beacon != address(0) && _saleGateway != address(0) && _savior != address(0),
      'bad'
    );

    for (uint8 i = 0; i < _platforms.length; ++i) {
      getPlatformIndex[_platforms[i]] = allPlatforms.length;
      allPlatforms.push(_platforms[i]);
    }

    beacon = _beacon;
    savior = _savior;
    saleGateway = _saleGateway;
  }

  function _authorizeUpgrade(address newImplementation) internal virtual override proxied {}

  /**
   * @dev Get total number of chain staked supported
   */
  function allChainsStakedLength() external view virtual override returns (uint256) {
    return allChainsStaked.length;
  }

  /**
   * @dev Get total number of projects created
   */
  function allProjectsLength() external view virtual override returns (uint256) {
    return allProjects.length;
  }

  /**
   * @dev Get total number of accepted usd payment token
   */
  function allUsdPaymentTokensLength() external view virtual override returns (uint256) {
    return allUsdPaymentTokens.length;
  }

  /**
   * @dev Get total number of supported platform
   */
  function allPlatformsLength() public view virtual override returns (uint256) {
    return allPlatforms.length;
  }

  /**
   * @dev Check if platform is supported
   */
  function isPlatformSupported(string calldata _platform) public view virtual override returns (bool) {
    return _platform.equal(allPlatforms[getPlatformIndex[_platform]]);
  }

  /**
   * @dev Create new project for raise fund
   * @param _startInEpoch Epoch date to start booster 1
   * @param _durationPerBoosterInSeconds Duration per booster (in seconds)
   * @param _targetUsdRaised Amount usd to raised
   * @param _platformPercentage_d2 Sale percentage per platform (2 decimal)
   * @param _tokenPriceInUsdDecimal Token project price (usd decimal)
   * @param _feePercentage_d2 Fee project percentage in each rounds (2 decimal)
   * @param _usdPaymentToken Tokens to raise
   * @param _nameVersionMsg Project EIP712 name, version, message
   */
  function createProject(
    uint128 _startInEpoch,
    uint128 _durationPerBoosterInSeconds,
    uint256 _targetUsdRaised,
    uint256[] calldata _platformPercentage_d2,
    uint256 _tokenPriceInUsdDecimal,
    uint256[4] calldata _feePercentage_d2,
    address _usdPaymentToken,
    string[3] calldata _nameVersionMsg
  ) external virtual override whenNotPaused onlyOwner returns (address project) {
    uint256 platformLength = allPlatformsLength();

    require(
      _usdPaymentToken != address(0) &&
        _usdPaymentToken == allUsdPaymentTokens[getUsdPaymentTokenIndex[_usdPaymentToken]] &&
        _platformPercentage_d2.length == platformLength &&
        block.timestamp < _startInEpoch &&
        allUsdPaymentTokens.length > 0 &&
        operational != address(0),
      'bad'
    );

    uint256 totalPercentage_d2;
    for (uint8 i = 0; i < platformLength; ++i) {
      totalPercentage_d2 += _platformPercentage_d2[i];
    }
    require(totalPercentage_d2 == 10000, 'invalid _platformPercentage_d2');

    bytes memory data = abi.encodeWithSelector(
      IMultiPlatformPublicSaleInit.init.selector,
      _startInEpoch,
      _durationPerBoosterInSeconds,
      _targetUsdRaised,
      _platformPercentage_d2,
      _tokenPriceInUsdDecimal,
      _feePercentage_d2,
      _usdPaymentToken,
      _nameVersionMsg
    );

    project = address(new BeaconProxy(beacon, data));

    allProjects.push(project);
    isKnown[project] = true;

    emit ProjectCreated(project, allProjects.length - 1);
  }

  /**
   * @dev Add new platform to supports
   * @param _platform Platform name
   */
  function addPlatform(string calldata _platform) external virtual override onlyOwner {
    if (allPlatforms.length > 0) require(!isPlatformSupported(_platform), 'existed');

    getPlatformIndex[_platform] = allPlatforms.length;
    allPlatforms.push(_platform);
  }

  /**
   * @dev Remove supported platform
   * @param _platform Platform name
   */
  function removePlatform(string calldata _platform) external virtual override onlyOwner {
    require(allPlatforms.length > 0 && isPlatformSupported(_platform), '!found');

    uint256 indexToDelete = getPlatformIndex[_platform];
    string memory platformToMove = allPlatforms[allPlatforms.length - 1];

    allPlatforms[indexToDelete] = platformToMove;
    getPlatformIndex[platformToMove] = indexToDelete;

    allPlatforms.pop();
    delete getPlatformIndex[_platform];
  }

  /**
   * @dev Add new usd token to be accepted as payment
   * @param _token New token address
   */
  function addUsdPaymentToken(address _token) external virtual override onlyOwner {
    require(_token != address(0), 'bad');
    if (allUsdPaymentTokens.length > 0)
      require(_token != allUsdPaymentTokens[getUsdPaymentTokenIndex[_token]], 'existed');

    getUsdPaymentTokenIndex[_token] = allUsdPaymentTokens.length;
    allUsdPaymentTokens.push(_token);
  }

  /**
   * @dev Remove usd token as payment
   * @param _token Token address
   */
  function removeUsdPaymentToken(address _token) external virtual override onlyOwner {
    require(_token != address(0), 'bad');
    require(allUsdPaymentTokens.length > 0 && _token == allUsdPaymentTokens[getUsdPaymentTokenIndex[_token]], '!found');

    uint256 indexToDelete = getUsdPaymentTokenIndex[_token];
    address addressToMove = allUsdPaymentTokens[allUsdPaymentTokens.length - 1];

    allUsdPaymentTokens[indexToDelete] = addressToMove;
    getUsdPaymentTokenIndex[addressToMove] = indexToDelete;

    allUsdPaymentTokens.pop();
    delete getUsdPaymentTokenIndex[_token];
  }

  function addChainStaked(uint256[] calldata _chainID) external virtual override onlyOwner {
    for (uint256 i = 0; i < _chainID.length; ++i) {
      if (allChainsStaked.length > 0 && allChainsStaked[getChainStakedIndex[_chainID[i]]] == _chainID[i]) continue;

      getChainStakedIndex[_chainID[i]] = allChainsStaked.length;
      allChainsStaked.push(_chainID[i]);
    }
  }

  function removeChainStaked(uint256[] calldata _chainID) external virtual override onlyOwner {
    require(allChainsStaked.length > 0, 'bad');

    for (uint256 i = 0; i < _chainID.length; ++i) {
      if (allChainsStaked[getChainStakedIndex[_chainID[i]]] != _chainID[i]) continue;

      uint256 indexToDelete = getChainStakedIndex[_chainID[i]];
      uint256 chainToMove = allChainsStaked[allChainsStaked.length - 1];

      allChainsStaked[indexToDelete] = chainToMove;
      getChainStakedIndex[chainToMove] = indexToDelete;

      allChainsStaked.pop();
      delete getChainStakedIndex[_chainID[i]];
    }
  }

  function config(address _beacon, address _saleGateway, address _savior) external virtual override onlyOwner {
    require(_beacon != address(0) && _saleGateway != address(0) && _savior != address(0), 'bad');

    beacon = _beacon;
    saleGateway = _saleGateway;
    savior = _savior;
  }

  function setVault(address _operational, address _marketing, address _treasury) external virtual override onlyOwner {
    require(_operational != address(0) && _marketing != address(0) && _treasury != address(0), 'bad');

    operational = _operational;
    marketing = _marketing;
    treasury = _treasury;

    if (operationalPercentage_d2 + marketingPercentage_d2 + treasuryPercentage_d2 != 10000)
      setVaultPercentage_d2(4000, 3000, 3000);
  }

  /**
   * @dev Config Factory percentage
   * @param _operationalPercentage Operational percentage in 2 decimal
   * @param _marketingPercentage Marketing percentage in 2 decimal
   * @param _treasuryPercentage Treasury percentage in 2 decimal
   */
  function setVaultPercentage_d2(
    uint256 _operationalPercentage,
    uint256 _marketingPercentage,
    uint256 _treasuryPercentage
  ) public virtual override onlyOwner {
    require(_operationalPercentage + _marketingPercentage + _treasuryPercentage == 10000, 'bad');
    operationalPercentage_d2 = _operationalPercentage;
    marketingPercentage_d2 = _marketingPercentage;
    treasuryPercentage_d2 = _treasuryPercentage;
  }

  function togglePause() external virtual onlyOwner {
    if (paused()) {
      _unpause();
    } else {
      _pause();
    }
  }

  function owner() public view virtual override(IMultiPlatformSaleFactory, OwnableUpgradeable) returns (address) {
    return super.owner();
  }
}
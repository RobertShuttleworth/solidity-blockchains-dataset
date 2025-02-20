// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import './openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol';
import './openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol';
import './openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PermitUpgradeable.sol';
import './openzeppelin_contracts_utils_math_Math.sol';
import './openzeppelin_contracts_utils_Address.sol';

import './contracts_eigen-layer_interfaces_IELAirdrop.sol';
import './contracts_eigen-layer_interfaces_IELBridge.sol';
import './contracts_eigen-layer_interfaces_IELRouter.sol';
import './contracts_eigen-layer_interfaces_IUSDC.sol';
import './contracts_eigen-layer_interfaces_IELWithdrawals.sol';

contract USDC is
  Initializable,
  ERC20Upgradeable,
  ERC20BurnableUpgradeable,
  PausableUpgradeable,
  AccessControlUpgradeable,
  ERC20PermitUpgradeable,
  UUPSUpgradeable,
  ReentrancyGuardUpgradeable,
  IUSDC
{
  bytes32 public constant UPGRADER_ROLE = keccak256('UPGRADER_ROLE');
  bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');
  bytes32 public constant POOL_MANAGER_ROLE = keccak256('POOL_MANAGER_ROLE');
  bytes32 public constant VALIDATOR_ORACLE_ROLE = keccak256('VALIDATOR_ORACLE_ROLE');
  bytes32 public constant VALIDATOR_ORACLE_MANAGER_ROLE = keccak256('VALIDATOR_ORACLE_MANAGER_ROLE');
  bytes32 public constant VALIDATOR_ORACLE_SENTINEL_ROLE = keccak256('VALIDATOR_ORACLE_SENTINEL_ROLE');
  bytes32 public constant ANTI_FRAUD_MANAGER_ROLE = keccak256('ANTI_FRAUD_MANAGER_ROLE');
  bytes32 public constant ANTI_FRAUD_SENTINEL_ROLE = keccak256('ANTI_FRAUD_SENTINEL_ROLE');

  uint256 public version;

  IELAirdrop public airdrop;
  IELRouter public router;
  IELWithdrawals public withdrawals;
  IELBridge public bridge;
  address public l1Adapter;

  uint256 public beaconBalance;
  uint256 public withdrawBalance;

  Config public config;

  mapping(address => uint256) public shares;
  uint256 public totalShares;
  mapping(address => mapping(address => uint256)) private allowances;

  mapping(address => uint256) private lastOperationBlock;
  mapping(address => uint256) private nextWithdrawBlock;
  mapping(address => uint256) private nextWithdrawBeaconBlock;
  uint256 public lastResetBlock;
  uint256 public totalDeposited;
  uint256 public totalWithdrawnPool;
  uint256 public totalWithdrawnValidator;

  mapping(address => bool) public pools;

  address[] private validatorsOracle;
  mapping(address => uint256) private validatorsOracleIndices;
  uint256 public currentOracleIndex;

  mapping(bytes => bool) public validators;

  mapping(FeeRole => address payable) private feesRole;
  mapping(FeeType => Fee) private fees;

  mapping(address => bool) private antiFraudList;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function name() public view override returns (string memory) {
    return 'USDC';
  }

  function symbol() public view override returns (string memory) {
    return 'USDC';
  }

  function pause() external onlyRole(ADMIN_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(ADMIN_ROLE) {
    _unpause();
  }

  function _authorizeUpgrade(address _newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

  receive() external payable {
    revert();
  }

  function totalSupply() public view override returns (uint256) {
    return 0;
  }

  function balanceOf(address _account) public view override returns (uint256) {
    return 0;
  }

  function transfer(address _to, uint256 _amount) public override returns (bool) {
    revert();
  }

  function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
    revert();
  }

  function allowance(address _account, address _spender) public view override returns (uint256) {
    return 0;
  }

  function approve(address _spender, uint256 _amount) public override returns (bool) {
    revert();
  }
}
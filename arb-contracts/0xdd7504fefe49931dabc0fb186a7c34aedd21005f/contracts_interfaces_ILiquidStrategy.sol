pragma solidity 0.8.25;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC20.sol";

interface ILiquidStrategy {
    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function asset() external view returns (IERC20);
    function totalAssets() external view returns (uint256);
    function deposit(uint256 _amount) external;
    function withdraw(uint256 _amount) external;
    function migrateFrom4626(address _currentVault, address _newVault, uint256 _minSharesOut) external;
    function reallocateFunds(address[] memory targets, uint256[] memory amounts, bool[] memory isDeposit, uint256[] memory minAmountOuts) external;

    function setLendingVault(address) external;
    function setOracle(address) external;

    // Ethena
    function setEthenaTokens(address _sUSDe, address _USDe) external;
    function enableEthena(bool _enabled) external;

    // CoWSwap
    function approveTokenToCowSwap(address token, uint256 amount) external;
    function signCowSwapOrder(bytes calldata orderUid) external;
    function cancelCowSwapOrder(bytes calldata orderUid) external;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event LendingVaultSet(address indexed sender, address indexed lendingVault);
    event OracleSet(address indexed sender, address indexed oracle);

    event VaultDeposit(address indexed vault, address indexed token, uint256 assets, uint256 shares);
    event VaultWithdraw(address indexed vault, address indexed token, uint256 assets, uint256 shares);
    event StrategyExchange(address indexed from, address indexed to, uint256 amountFrom, uint256 amountOut);

    event VaultAdded(address indexed vault, address indexed asset);
    event VaultRemoved(address indexed vault, address indexed asset);

    event StrategyDeposit(address indexed sender, address token, uint256 indexed amount);
    event StrategyWithdraw(address indexed sender, address token, uint256 indexed amount);

    event TokensRecovered(address indexed sender, address indexed receiver, address indexed token, uint256 amount);

    // CowSwap events
    event OrderPlaced(bytes orderUid);
    event OrderCancelled(bytes orderUid);
    event TokensApproved(address token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyLendingVault();
    error ArrayLengthsMustMatch();
    error LendingVaultAlreadySet();
    error VaultNotSupported();
    error VaultNotApproved();
    error InvalidVaultAddress();
    error CannotBeZeroAddress();
    error SlippageThresholdExceeded(address target, bool isDeposit, uint256 amount, uint256 minAmount);
}
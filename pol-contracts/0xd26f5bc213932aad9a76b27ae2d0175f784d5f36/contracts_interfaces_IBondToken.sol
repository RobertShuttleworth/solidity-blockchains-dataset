// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IBondToken {

    /* ========== Functions ========== */

    function deposit(uint256 amount) external;

    function depositFor(address user, uint256 amount) external;

    function depositSLP(uint256 amount) external;

    function depositSLPFor(address user, uint256 amount) external;

    function requestToWithdraw(uint256 amount, uint256 minAmountOut) external returns (uint256 requestId);

    function cancelWithdrawRequest(uint256 requestId) external;

    function rebase(uint256 indexDelta, bool positive) external;

    function continuousRebase() external;

    function emergencyWithdraw(address token, uint256 amount) external;

    function toBaseAmount(uint256 currentAmount) external view returns (uint256);

    function toRebasedAmount(uint256 baseAmount) external view returns (uint256);

    function realTimeRebaseAmount(uint256 amount) external view returns (uint256);

    function rebaseIndex() external view returns (uint256);

    function runawayEndTime() external view returns (uint256);

    function continuousRebaseIndexDeltaPerSecond() external view returns (uint256);

    function pause() external;

    function unpause() external;

    /* ========== STRUCTS ========== */

    struct VipDepositCap {
        uint256 amount;
        uint256 deadline;
    }

    /* ========== EVENTS ========== */

    event Deposit(
        address indexed user,
        address indexed sender,
        uint256 amount,
        uint256 continuousRebaseIndexDeltaPerSecond
    );
    event DepositSLP(
        address indexed user,
        address indexed sender,
        uint256 amount,
        uint256 continuousRebaseIndexDeltaPerSecond
    );
    event RequestToWithdraw(
        address indexed user,
        uint256 amount,
        uint256 vaultTokenAmount,
        uint256 continuousRebaseIndexDeltaPerSecond,
        uint256 requestId
    );
    event CancelWithdrawRequest(
        uint256 indexed requestId,
        address indexed receiver,
        uint256 continuousRebaseIndexDeltaPerSecond
    );
    event BaseTransfer(address indexed from, address indexed to, uint256 baseAmount, uint256 amount);
    event Rebase(uint256 previousRebaseIndex, uint256 newRebaseIndex, bool positive);
    event ContinuousRebase(uint256 duration, uint256 delta);
    event SetBlacklist(address indexed user, bool isBlacklisted);
    event SetWalletDepositCapOf(address[] wallets, uint256 amount);
    event SetRunawayWindow(uint256 oldRunawayWindow, uint256 newRunawayWindow);
    event EmergencyWithdraw(address indexed token, uint256 amount);
    event TreasuryBalanceChanged(uint256 ratio, uint256 continuousRebaseIndexDeltaPerSecond, uint256 runawayEndTime);
    event TotalDepositCapUpdated(uint256 oldTotalDepositCap, uint256 newTotalDepositCap);
    event WalletDepositCapUpdated(uint256 oldWalletDepositCap, uint256 newWalletDepositCap);
    event RunawayWindowUpdated(uint256 oldRunawayWindow, uint256 newRunawayWindow);
    event MaxDeltaPerSecondUpdated(uint256 oldMaxDeltaPerSecond, uint256 newMaxDeltaPerSecond);

    /* ========== ERRORS ========== */
    
    error ZeroAmount();
    error EmptyArray();
    error Forbidden();
    error InsufficientBalance();
    error InsufficientAllowance();
    error DepositCapReached();
    error WalletDepositCapReached();
    error VipWalletDepositCapReached();
    error InsufficientVaultTokenBalance();
    error Blacklisted();
    error InvalidIndexDelta();
    error RebaseIndexZero();
    error TransferToZeroAddress();
    error TransferFromZeroAddress();
    error InvalidAddress();
    error ZeroRunawayWindow();
    error InvalidPercentage();
}

interface IBondTokenExternal is IBondToken {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address user) external returns (uint256);
}
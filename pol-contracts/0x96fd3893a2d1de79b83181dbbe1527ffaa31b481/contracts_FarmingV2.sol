// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";

error PoolAlreadyExists();
error PoolDoesNotExist();
error AmountMustBeGreaterThanZero();
error AlreadyWithdrawn();
error TokensAreLocked();
error InvalidLockPeriod();
contract FarmingV2 is Initializable, OwnableUpgradeable {
    struct DepositInfo {
        uint256 amount; // Amount of LP tokens deposited
        uint256 depositTime; // Time of deposit
        uint256 unlockTime; // Lock period for this deposit in seconds
        uint256 removalTime; // Time of removal
        bool withdrawn; // Indicates if this deposit has been withdrawn
    }

    struct PoolInfo {
        IERC20 lpToken; // LP token for this pool
        bool exists; // Tracks if the pool has been added
    }

    // Also need to put removal time into history struct
    // need to put removal time in Deposit & Withdraw events

    mapping(address => mapping(IERC20 => DepositInfo[])) public userDeposits; // Track all deposits per user per pool
    mapping(IERC20 => PoolInfo) public pools; // Pool information by LP token
    uint256 public constant ONE_DAY = 1 days; // 1 month in seconds

    event PoolAdded(IERC20 lpToken);
    event PoolRemoved(IERC20 lpToken);
    event Deposit(
        address indexed user,
        IERC20 indexed lpToken,
        uint256 amount,
        uint256 depositId,
        uint256 depositTime,
        uint256 unlockTime
    );
    event Withdraw(
        address indexed user,
        IERC20 indexed lpToken,
        uint256 amount,
        uint256 depositId,
        uint256 depositTime,
        uint256 withdrawalTime
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    // Initialize function to replace constructor
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
    }

    function getUserDeposits(
        address _user,
        IERC20 _lpToken
    ) external view returns (DepositInfo[] memory) {
        return userDeposits[_user][_lpToken];
    }

    function getTotalStaked(IERC20 _lpToken) external view returns (uint256) {
        return _lpToken.balanceOf(address(this));
    }

    function checkPoolExists(IERC20 _lpToken) public view returns (bool) {
        return pools[_lpToken].exists;
    }

    function isLockExpired(
        address _user,
        IERC20 _lpToken,
        uint256 _depositId
    ) external view returns (bool) {
        DepositInfo storage depositView = userDeposits[_user][_lpToken][
            _depositId
        ];
        return block.timestamp > depositView.unlockTime;
    }

    function addPool(IERC20 _lpToken) external onlyOwner {
        if (checkPoolExists(_lpToken)) revert PoolAlreadyExists();
        pools[_lpToken] = PoolInfo({lpToken: _lpToken, exists: true});
        emit PoolAdded(_lpToken);
    }

    function removePool(IERC20 _lpToken) external onlyOwner {
        if (!checkPoolExists(_lpToken)) revert PoolDoesNotExist();
        delete pools[_lpToken];
        emit PoolRemoved(_lpToken);
    }

    function deposit(
        IERC20 _lpToken,
        uint256 _amount,
        uint8 _lockPeriodMonths
    ) external {
        if (!pools[_lpToken].exists) revert PoolDoesNotExist();
        if (_amount == 0) revert AmountMustBeGreaterThanZero();
        if (
            _lockPeriodMonths != 1 &&
            _lockPeriodMonths != 3 &&
            _lockPeriodMonths != 6 &&
            _lockPeriodMonths != 12
        ) revert InvalidLockPeriod();

        uint256 currentTime = block.timestamp;
        uint256 unlockTime = currentTime + _lockPeriodMonths * ONE_DAY;
        _lpToken.transferFrom(msg.sender, address(this), _amount);

        userDeposits[msg.sender][_lpToken].push(
            DepositInfo({
                amount: _amount,
                depositTime: currentTime,
                unlockTime: unlockTime,
                removalTime: 0,
                withdrawn: false
            })
        );

        uint256 depositId = userDeposits[msg.sender][_lpToken].length - 1;
        emit Deposit(
            msg.sender,
            _lpToken,
            _amount,
            depositId,
            currentTime,
            unlockTime
        );
    }

    function withdraw(IERC20 _lpToken, uint256 _depositId) external {
        DepositInfo storage depositInfo = userDeposits[msg.sender][_lpToken][
            _depositId
        ];
        uint256 currentTime = block.timestamp;
        if (depositInfo.withdrawn) revert AlreadyWithdrawn();
        if (currentTime < depositInfo.unlockTime) revert TokensAreLocked();
        if (depositInfo.amount == 0) revert AmountMustBeGreaterThanZero();

        uint256 amountToWithdraw = depositInfo.amount;
        depositInfo.withdrawn = true;
        depositInfo.amount = 0;
        depositInfo.removalTime = currentTime;

        _lpToken.transfer(msg.sender, amountToWithdraw);
        emit Withdraw(
            msg.sender,
            _lpToken,
            amountToWithdraw,
            _depositId,
            depositInfo.depositTime,
            currentTime
        );
    }
}
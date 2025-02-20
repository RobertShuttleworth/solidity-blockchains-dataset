// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_math_SafeCastUpgradeable.sol";

/**
 * @title KagePool
 * @notice A staking pool contract that allows users to stake tokens and earn rewards over time.
 *         Supports multiple pools with different parameters, early withdrawals with penalties,
 *         whitelisting, and emergency withdrawals.
 * @dev Optimized for gas efficiency by rearranging struct members for tight packing,
 *      minimizing storage reads/writes, and simplifying logic without compromising security.
 */
contract KagePool is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeCastUpgradeable for uint256;

    /// @dev Represents one year in seconds (365 days).
    uint256 private constant ONE_YEAR_IN_SECONDS = 365 days;
    /// @dev Represents 100% in basis points.
    uint16 private constant HUNDRED_PERCENT = 10000; // Using basis points for precision
    uint256 private constant PRECISION_FACTOR = 1e18;
    /// @notice The ERC20 token accepted by the staking pools for staking and rewards.
    IERC20Upgradeable public kageAcceptedToken;
    /// @notice The address responsible for distributing rewards.
    address public kageRewardDistributor;
    /// @notice An array containing information about each staking pool.
    KagePoolInfo[] public kagePoolInfo;
    /// @notice Mapping from pool ID and user address to the user's staking data in that pool.
    mapping(uint256 => mapping(address => KageStakingData))
        private kageStakingData;

    /// @notice Mapping from pool ID and user address to the user's revenue data in that pool.
    mapping(uint256 => mapping(address => KageRevenueData))
        private kageRevenueData;

    /// @notice Flag indicating whether emergency withdrawals are allowed.
    bool public kageAllowEmergencyWithdraw;
    /// @notice The address of the treasury where penalty fees are sent.
    address public treasury;

    /// @notice Contains information about a staking pool.
    /// @dev Struct members are tightly packed to reduce storage costs.
    struct KagePoolInfo {
        uint128 cap; // Maximum tokens that can be staked
        uint128 minStaked; // Minimum tokens that can be staked
        uint128 totalStaked; // Total tokens staked in the pool
        uint128 lockDuration; // Lock duration for staked tokens
        uint128 startJoinTime; // Start time for staking
        uint128 endJoinTime; // End time` for staking
        uint64 APY; // APY for staking
    }
    /// @notice Contains staking data for a user in a specific pool.
    /// @dev Struct members are tightly packed to reduce storage costs.
    struct KageStakingData {
        uint128 balance; // User's staked balance
        uint128 joinTime; // Timestamp when user started staking
        uint128 updatedTime; // Timestamp when user's data was last updated
    }
    /// @notice Contains additional information for each pool, including early withdrawal penalties.
    mapping(uint256 => AdditionalPoolInfo) private additionalPoolInfo;
    /// @notice Contains pending early withdrawal data for users.
    mapping(uint256 => mapping(address => KagePendingEarlyWithdrawal))
        private kagePendingEarlyWithdrawals;

    /// @notice Contains information about a user's pending early withdrawal.
    struct KagePendingEarlyWithdrawal {
        uint128 amount; // Amount pending withdrawal
        uint128 applicableAt; // Timestamp when withdrawal becomes claimable
    }
    /// @notice Contains revenue data for a user in a specific pool.
    /// @dev Struct members are tightly packed to reduce storage costs.
    struct KageRevenueData {
        uint128 amount; // Amount of revenue
        uint128 snapshotTime; // Timestamp when revenue was last updated
    }
    /// @notice Contains additional information for a pool.
    struct AdditionalPoolInfo {
        uint128 delayDuration; // Delay for early withdrawal
        uint64 fee; // Early withdrawal fee
    }

    /// @notice Mapping from pool ID to an array of staker addresses.
    mapping(uint256 => address[]) private kagePoolStakers;
    /// @notice Emitted when a new staking pool is created.
    event KagePoolCreated(
        uint256 indexed poolId,
        uint128 capacity,
        uint128 minStaked,
        uint128 lockDuration,
        uint128 startJoinTime,
        uint128 endJoinTime,
        uint128 APY
    );

    /// @notice Emitted when a user deposits tokens into a pool.
    event KageDeposit(
        uint256 indexed poolId,
        address indexed account,
        uint256 amount
    );

    /// @notice Emitted when a user withdraws tokens from a pool.
    event KageWithdraw(
        uint256 indexed poolId,
        address indexed account,
        uint256 amount
    );

    /// @notice Emitted when a user claims their pending withdrawal.
    event KageClaimPendingWithdraw(
        uint256 poolId,
        address account,
        uint128 amount
    );

    /// @notice Emitted when a user performs an early withdrawal with penalty.
    event KageEarlyWithdraw(
        uint256 poolId,
        address account,
        uint128 amount,
        uint128 charge
    );

    /// @notice Emitted when a pool's parameters are updated.
    event KageUpdatePool(
        uint256 poolId,
        uint128 capacity,
        uint128 minStaked,
        uint128 endJoinTime
    );

    /// @notice Emitted when the delay duration for a pool is set.
    event KageSetDelayDuration(uint256 poolId, uint128 duration);

    /// @notice Emitted when staking data is reassigned from one user to another.
    event KageAssignStakingData(uint256 poolId, address from, address to);

    /// @notice Emitted when the admin recovers tokens from the contract.
    event KageAdminRecoverFund(address token, address to, uint256 amount);

    /// @notice Emitted when the reward distributor address is changed.
    event KageChangeRewardDistributor(
        address oldDistributor,
        address newDistributor
    );

    /// @notice Emitted when the treasury address is changed.
    event KageChangeTreasury(address oldTreasury, address newTreasury);

    /// @notice Emitted when revenue claim records are created for a pool
    event KageRevenueAllocated(uint256 indexed poolId, uint128 amount);

    /// @notice Emitted when rewards are paid out to a user
    event KageRewardPaid(
        uint256 indexed poolId,
        address indexed account,
        uint128 amount
    );

    /// @notice Mapping from pool ID and address to staker index in kagePoolStakers array
    /// @dev Used for O(1) removal of stakers from the pool
    mapping(uint256 => mapping(address => uint256)) private kageStakerIndices;

    /// @notice Mapping from pool ID to whether an address is currently staking
    /// @dev Used to track active stakers in each pool
    mapping(uint256 => mapping(address => bool)) private kageIsStaking;

    /// @notice Mapping to track transaction nonces for each user
    /// @dev Used to prevent transaction replay attacks
    mapping(address => uint256) private kageUserNonces;

    /**
     * @notice Initializes the KagePool contract with the accepted token and treasury address.
     * @dev This function should be called only once upon contract deployment.
     * @param _acceptedToken The ERC20 token that the pools will accept for staking and rewards.
     * @param _treasury The address of the treasury where penalty fees will be sent.
     */
    function __KagePool_init(
        IERC20Upgradeable _acceptedToken,
        address _treasury
    ) public initializer {
        require(
            _treasury != address(0) && address(_acceptedToken) != address(0),
            "KageStakingPool: zero address"
        );

        __Ownable_init();
        __Pausable_init();
        _pause();

        kageAcceptedToken = _acceptedToken;
        treasury = _treasury;
    }

    /**
     * @dev Validates that a pool with the given ID exists.
     * @param _poolId ID of the pool to validate.
     */
    modifier kageValidatePoolById(uint256 _poolId) {
        require(
            _poolId < kagePoolInfo.length,
            "KageStakingPool: pool does not exist"
        );
        _;
    }

    /**
     * @notice Pauses the contract, disabling deposits and withdrawals.
     * @dev Only callable by the owner.
     */
    function pauseContract() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract, enabling deposits and withdrawals.
     * @dev Only callable by the owner.
     */
    function unpauseContract() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Sets the treasury address where penalty fees are sent.
     * @dev Only callable by the owner.
     * @param _treasury The new treasury address.
     */
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "KageStakingPool: zero address");

        emit KageChangeTreasury(treasury, _treasury);
        treasury = _treasury;
    }

    /**
     * @notice Allows the admin to recover tokens mistakenly sent to the contract.
     * @dev Only callable by the owner.
     * @param _token The address of the token to recover.
     * @param _to The address to send the recovered tokens to.
     * @param _amount The amount of tokens to recover.
     */
    function kageAdminRecoverFund(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyOwner {
        require(
            IERC20Upgradeable(_token).balanceOf(address(this)) >= _amount,
            "KageStakingPool: insufficient balance"
        );
        require(
            _token != address(kageAcceptedToken),
            "KageStakingPool: cannot recover accepted token"
        );
        IERC20Upgradeable(_token).safeTransfer(_to, _amount);
        emit KageAdminRecoverFund(_token, _to, _amount);
    }

    /**
     * @notice Reassigns staking data from one user to another.
     * @dev Only callable by the owner.
     * @param _poolId The ID of the pool.
     * @param _from The address of the user to reassign data from.
     * @param _to The address of the user to reassign data to.
     */
    function kageAssignStakedData(
        uint256 _poolId,
        address _from,
        address _to
    ) external onlyOwner kageValidatePoolById(_poolId) {
        require(_from != address(0), "KageStakingPool: invalid from address");
        require(_to != address(0), "KageStakingPool: invalid to address");
        require(_from != _to, "KageStakingPool: from and to address same");

        KageStakingData storage stakingDataFrom = kageStakingData[_poolId][
            _from
        ];
        KageStakingData storage stakingDataTo = kageStakingData[_poolId][_to];

        require(
            stakingDataTo.balance == 0 &&
                stakingDataTo.joinTime == 0 &&
                stakingDataTo.updatedTime == 0,
            "KageStakingPool: target already has staking data"
        );

        // Update staker tracking with O(1) operations
        if (kageIsStaking[_poolId][_from]) {
            uint256 fromIndex = kageStakerIndices[_poolId][_from];
            kagePoolStakers[_poolId][fromIndex] = _to;
            kageStakerIndices[_poolId][_to] = fromIndex;
            kageIsStaking[_poolId][_to] = true;
            delete kageStakerIndices[_poolId][_from];
            kageIsStaking[_poolId][_from] = false;
        }

        kageStakingData[_poolId][_to] = stakingDataFrom;
        delete kageStakingData[_poolId][_from];

        KagePendingEarlyWithdrawal
            storage pendingFrom = kagePendingEarlyWithdrawals[_poolId][_from];
        KagePendingEarlyWithdrawal
            storage pendingTo = kagePendingEarlyWithdrawals[_poolId][_to];

        pendingTo.amount = pendingFrom.amount;
        pendingTo.applicableAt = pendingFrom.applicableAt;
        delete kagePendingEarlyWithdrawals[_poolId][_from];

        emit KageAssignStakingData(_poolId, _from, _to);
    }

    /**
     * @notice Returns the total number of staking pools.
     * @return The total number of pools.
     */
    function kagePoolLength() external view returns (uint256) {
        return kagePoolInfo.length;
    }

    /**
     * @notice Returns the total amount of tokens staked in a specific pool.
     * @param _poolId The ID of the pool.
     * @return The total amount of tokens staked in the pool.
     */
    function kageTotalStaked(uint256 _poolId)
        external
        view
        kageValidatePoolById(_poolId)
        returns (uint256)
    {
        return kagePoolInfo[_poolId].totalStaked;
    }

    /**
     * @notice Adds a new staking pool with specified parameters.
     * @dev Only callable by the owner.
     * @param _cap The maximum amount of tokens that can be staked in the pool.
     * @param _minStaked The minimum amount of tokens that can be staked in the pool.
     * @param _lockDuration The duration (in seconds) that tokens are locked after staking.
     * @param _startJoinTime The timestamp when users can start staking in the pool.
     * @param _endJoinTime The timestamp when users can no longer stake in the pool.
     */
    function kageAddPool(
        uint128 _cap,
        uint128 _minStaked,
        uint128 _lockDuration,
        uint128 _startJoinTime,
        uint128 _endJoinTime,
        uint64 _APY
    ) external onlyOwner {
        require(
            _endJoinTime >= block.timestamp && _endJoinTime > _startJoinTime,
            "KageStakingPool: invalid end join time"
        );
        require(_APY > 0, "KageStakingPool: invalid APY");

        kagePoolInfo.push(
            KagePoolInfo({
                cap: _cap,
                minStaked: _minStaked,
                totalStaked: 0,
                lockDuration: _lockDuration,
                startJoinTime: _startJoinTime,
                endJoinTime: _endJoinTime,
                APY: _APY
            })
        );
        emit KagePoolCreated(
            kagePoolInfo.length - 1,
            _cap,
            _minStaked,
            _lockDuration,
            _startJoinTime,
            _endJoinTime,
            _APY
        );
    }

    /**
     * @notice Updates parameters of an existing staking pool.
     * @dev Only callable by the owner.
     * @param _poolId The ID of the pool to update.
     * @param _cap The new maximum amount of tokens that can be staked in the pool.
     * @param _minStaked The new minimum amount of tokens that can be staked in the pool.
     * @param _endJoinTime The new timestamp when users can no longer stake in the pool.
     */
    function kageSetPool(
        uint128 _poolId,
        uint128 _cap,
        uint128 _minStaked,
        uint128 _endJoinTime,
        uint64 _APY
    ) external onlyOwner kageValidatePoolById(_poolId) {
        KagePoolInfo storage pool = kagePoolInfo[_poolId];

        require(
            _endJoinTime >= block.timestamp &&
                _endJoinTime > pool.startJoinTime,
            "KageStakingPool: invalid end join time"
        );
        require(_APY > 0, "KageStakingPool: invalid APY");

        pool.cap = _cap;
        pool.minStaked = _minStaked;
        pool.endJoinTime = _endJoinTime;
        if (
            _APY > 0 &&
            _APY <= 10000 &&
            block.timestamp < pool.endJoinTime &&
            pool.totalStaked == 0
        ) {
            pool.APY = _APY;
        }
        emit KageUpdatePool(_poolId, _cap, _minStaked, _endJoinTime);
    }

    /**
     * @notice Sets the reward distributor address.
     * @dev Only callable by the owner.
     * @param _kageRewardDistributor The new reward distributor address.
     */
    function kageSetRewardDistributor(address _kageRewardDistributor)
        external
        onlyOwner
    {
        require(
            _kageRewardDistributor != address(0),
            "KageStakingPool: zero address"
        );

        emit KageChangeRewardDistributor(
            kageRewardDistributor,
            _kageRewardDistributor
        );
        kageRewardDistributor = _kageRewardDistributor;
    }

    /**
     * @notice Deposits tokens into a staking pool to earn rewards.
     * @param _poolId The ID of the pool to deposit into.
     * @param _amount The amount of tokens to deposit.
     */
    function kageDeposit(uint256 _poolId, uint128 _amount)
        external
        nonReentrant
        whenNotPaused
        kageValidatePoolById(_poolId)
    {
        // Increment nonce to prevent transaction replay
        kageUserNonces[msg.sender]++;

        // Add check for token allowance and balance
        require(
            kageAcceptedToken.allowance(msg.sender, address(this)) >= _amount,
            "KageStakingPool: insufficient allowance"
        );
        require(
            kageAcceptedToken.balanceOf(msg.sender) >= _amount,
            "KageStakingPool: insufficient balance"
        );

        address account = msg.sender;
        _kageDeposit(_poolId, _amount, account);
        kageAcceptedToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit KageDeposit(_poolId, account, _amount);
    }

    /**
     * @dev Internal function to handle depositing tokens into a pool.
     * @param _poolId The ID of the pool.
     * @param _amount The amount of tokens to deposit.
     * @param account The address of the user.
     */
    function _kageDeposit(
        uint256 _poolId,
        uint128 _amount,
        address account
    ) internal {
        KagePoolInfo storage pool = kagePoolInfo[_poolId];
        KageStakingData storage stakingData = kageStakingData[_poolId][account];

        uint128 currentTime = block.timestamp.toUint128();
        require(
            currentTime >= pool.startJoinTime,
            "KageStakingPool: pool not started"
        );
        require(
            currentTime <= pool.endJoinTime,
            "KageStakingPool: pool closed"
        );
        require(
            _amount >= pool.minStaked,
            "KageStakingPool: amount below minimum"
        );

        uint128 totalStakedAfter = pool.totalStaked + _amount;
        if (pool.cap > 0) {
            require(
                totalStakedAfter <= pool.cap,
                "KageStakingPool: pool cap reached"
            );
        }

        // If this is the user's first deposit, add them to pool stakers
        if (stakingData.balance == 0) {
            stakingData.balance = _amount;
            if (!kageIsStaking[_poolId][account]) {
                kagePoolStakers[_poolId].push(account);
                kageStakerIndices[_poolId][account] =
                    kagePoolStakers[_poolId].length -
                    1;
                kageIsStaking[_poolId][account] = true;
            }
            stakingData.joinTime = currentTime;
            stakingData.updatedTime = currentTime;
        } else {
            stakingData.balance += _amount;
            stakingData.updatedTime = currentTime;
        }
        pool.totalStaked = totalStakedAfter;
    }

    /**
     * @notice Withdraws a specified amount of staked tokens from a pool after the lock duration has passed.
     * @param _poolId The ID of the pool to withdraw from.
     * @param _amount The amount of tokens to withdraw.
     */
    function kageWithdraw(uint256 _poolId, uint128 _amount)
        external
        nonReentrant
        whenNotPaused
        kageValidatePoolById(_poolId)
    {
        address account = msg.sender;
        KagePoolInfo storage pool = kagePoolInfo[_poolId];
        KageStakingData storage stakingData = kageStakingData[_poolId][account];

        uint128 lockEndTime = stakingData.updatedTime + pool.lockDuration;
        require(
            block.timestamp >= lockEndTime,
            "KageStakingPool: tokens locked"
        );

        uint128 userBalance = stakingData.balance;
        require(
            userBalance >= _amount,
            "KageStakingPool: insufficient balance"
        );

        // Calculate rewards based on APY
        uint128 rewards = _calculateRewards(
            _amount,
            stakingData.updatedTime,
            uint128(block.timestamp),
            pool.APY,
            pool.lockDuration
        );

        stakingData.balance = userBalance - _amount;
        pool.totalStaked -= _amount;

        // If user has withdrawn all their tokens, remove them from pool stakers
        if (stakingData.balance == 0 && kageIsStaking[_poolId][account]) {
            uint256 indexToRemove = kageStakerIndices[_poolId][account];
            uint256 lastIndex = kagePoolStakers[_poolId].length - 1;
            address lastStaker = kagePoolStakers[_poolId][lastIndex];

            // Move the last staker to the removed position
            if (indexToRemove != lastIndex) {
                kagePoolStakers[_poolId][indexToRemove] = lastStaker;
                kageStakerIndices[_poolId][lastStaker] = indexToRemove;
            }

            kagePoolStakers[_poolId].pop();
            delete kageStakerIndices[_poolId][account];
            kageIsStaking[_poolId][account] = false;
        }

        // Transfer principal amount
        kageAcceptedToken.safeTransfer(account, _amount);

        // Transfer rewards if there are any and if reward distributor is set
        if (rewards > 0 && kageRewardDistributor != address(0)) {
            require(
                IERC20Upgradeable(kageAcceptedToken).balanceOf(
                    kageRewardDistributor
                ) >= rewards,
                "KageStakingPool: insufficient rewards balance"
            );

            // Transfer rewards from reward distributor to user
            IERC20Upgradeable(kageAcceptedToken).safeTransferFrom(
                kageRewardDistributor,
                account,
                rewards
            );
        }

        stakingData.updatedTime = block.timestamp.toUint128();
        emit KageWithdraw(_poolId, account, _amount);

        if (rewards > 0) {
            emit KageRewardPaid(_poolId, account, rewards);
        }
    }

    /**
     * @notice Initiates an early withdrawal of all staked tokens before the lock duration has passed, applying the corresponding penalty.
     * @param _poolId The ID of the pool.
     */
    function kageEarlyWithdrawAll(uint256 _poolId)
        external
        nonReentrant
        whenNotPaused
        kageValidatePoolById(_poolId)
    {
        require(
            additionalPoolInfo[_poolId].fee > 0,
            "KageStakingPool: penalty fee not set"
        );
        address account = msg.sender;
        KageStakingData storage stakingData = kageStakingData[_poolId][account];
        uint128 withdrawAmount = stakingData.balance;
        require(withdrawAmount > 0, "KageStakingPool: nothing to withdraw");

        // Handle pool updates
        KagePoolInfo storage pool = kagePoolInfo[_poolId];
        pool.totalStaked -= withdrawAmount;

        // Calculate penalty
        uint128 penaltyAmount = (withdrawAmount *
            additionalPoolInfo[_poolId].fee) / HUNDRED_PERCENT;
        uint128 amountAfterPenalty = withdrawAmount - penaltyAmount;

        // Calculate rewards
        uint128 rewards = _calculateRewards(
            withdrawAmount,
            stakingData.updatedTime,
            uint128(block.timestamp),
            pool.APY,
            pool.lockDuration
        );

        // Update staking data
        stakingData.balance = 0;
        stakingData.updatedTime = block.timestamp.toUint128();

        // Remove user from pool stakers with O(1) operation
        _removeStakerFromPool(_poolId, account);

        // Update pending withdrawal
        KagePendingEarlyWithdrawal
            storage pendingWithdrawal = kagePendingEarlyWithdrawals[_poolId][
                account
            ];
        pendingWithdrawal.amount += amountAfterPenalty;
        pendingWithdrawal.applicableAt =
            block.timestamp.toUint128() +
            additionalPoolInfo[_poolId].delayDuration;

        // Handle transfers
        kageAcceptedToken.safeTransfer(treasury, penaltyAmount);

        if (rewards > 0 && kageRewardDistributor != address(0)) {
            require(
                IERC20Upgradeable(kageAcceptedToken).balanceOf(
                    kageRewardDistributor
                ) >= rewards,
                "KageStakingPool: insufficient rewards balance"
            );
            IERC20Upgradeable(kageAcceptedToken).safeTransferFrom(
                kageRewardDistributor,
                account,
                rewards
            );
            emit KageRewardPaid(_poolId, account, rewards);
        }

        emit KageEarlyWithdraw(_poolId, account, withdrawAmount, penaltyAmount);
    }

    /**
     * @dev Internal function to remove a staker from a pool.
     * @param _poolId The ID of the pool.
     * @param account The address of the staker to remove.
     */
    function _removeStakerFromPool(uint256 _poolId, address account) internal {
        if (kageIsStaking[_poolId][account]) {
            uint256 indexToRemove = kageStakerIndices[_poolId][account];
            uint256 lastIndex = kagePoolStakers[_poolId].length - 1;

            if (indexToRemove != lastIndex) {
                address lastStaker = kagePoolStakers[_poolId][lastIndex];
                kagePoolStakers[_poolId][indexToRemove] = lastStaker;
                kageStakerIndices[_poolId][lastStaker] = indexToRemove;
            }

            kagePoolStakers[_poolId].pop();
            delete kageStakerIndices[_poolId][account];
            kageIsStaking[_poolId][account] = false;
        }
    }

    /**
     * @notice Returns the amount of tokens a user has staked in a pool.
     * @param _poolId The ID of the pool.
     * @param _account The address of the user.
     * @return The amount of tokens the user has staked.
     */
    function kageBalanceOf(uint256 _poolId, address _account)
        external
        view
        kageValidatePoolById(_poolId)
        returns (uint128)
    {
        return kageStakingData[_poolId][_account].balance;
    }

    /**
     * @notice Returns the staking data for a user in a pool.
     * @param _poolId The ID of the pool.
     * @param _account The address of the user.
     * @return The user's staking data.
     */
    function kageUserStakingData(uint256 _poolId, address _account)
        external
        view
        kageValidatePoolById(_poolId)
        returns (KageStakingData memory)
    {
        return kageStakingData[_poolId][_account];
    }

    /**
     * @notice Sets whether emergency withdrawals are allowed.
     * @dev Only callable by the owner.
     * @param _shouldAllow True to allow emergency withdrawals, false to disallow.
     */
    function kageSetAllowEmergencyWithdraw(bool _shouldAllow)
        external
        onlyOwner
    {
        kageAllowEmergencyWithdraw = _shouldAllow;
    }

    /**
     * @notice Sets the early withdrawal fee for a pool.
     * @dev Only callable by the owner.
     * @param _poolId The ID of the pool.
     * @param _feeInBasisPoints The fee in basis points (1/10000th of a percent).
     */
    function kageSetEarlyWithdrawalFee(
        uint256 _poolId,
        uint64 _feeInBasisPoints
    ) external onlyOwner kageValidatePoolById(_poolId) {
        require(
            _feeInBasisPoints <= HUNDRED_PERCENT,
            "KageStakingPool: fee must be less than or equal to 100%"
        );

        additionalPoolInfo[_poolId].fee = _feeInBasisPoints;
    }

    /**
     * @notice Sets the delay duration for a pool.
     * @dev Only callable by the owner.
     * @param _poolId The ID of the pool.
     * @param _delayDuration The delay duration in seconds.
     */
    function kageSetDelayDuration(uint256 _poolId, uint128 _delayDuration)
        external
        onlyOwner
        kageValidatePoolById(_poolId)
    {
        additionalPoolInfo[_poolId].delayDuration = _delayDuration;
        emit KageSetDelayDuration(_poolId, _delayDuration);
    }

    /**
     * @notice Returns the early withdrawal penalty for a pool.
     * @param _poolId The ID of the pool.
     */
    function getPoolEarlyWithdrawalPenalty(uint256 _poolId)
        external
        view
        kageValidatePoolById(_poolId)
        returns (uint64)
    {
        return additionalPoolInfo[_poolId].fee;
    }

    /**
     * @notice Returns the delay duration for a pool.
     * @param _poolId The ID of the pool.
     */
    function getPoolDelayDuration(uint256 _poolId)
        external
        view
        kageValidatePoolById(_poolId)
        returns (uint128)
    {
        return additionalPoolInfo[_poolId].delayDuration;
    }

    /**
     * @notice Allows a user to withdraw their staked tokens without rewards in case of an emergency.
     * @param _poolId The ID of the pool.
     */
    function kageEmergencyWithdraw(uint256 _poolId)
        external
        nonReentrant
        whenPaused
        kageValidatePoolById(_poolId)
    {
        require(
            kageAllowEmergencyWithdraw,
            "KageStakingPool: emergency withdrawal not allowed"
        );

        address account = msg.sender;
        KageStakingData storage stakingData = kageStakingData[_poolId][account];

        uint128 amount = stakingData.balance;
        require(amount > 0, "KageStakingPool: nothing to withdraw");

        stakingData.balance = 0;
        stakingData.updatedTime = block.timestamp.toUint128();
        kagePoolInfo[_poolId].totalStaked -= amount;

        // Remove user from pool stakers with O(1) operation
        if (kageIsStaking[_poolId][account]) {
            uint256 indexToRemove = kageStakerIndices[_poolId][account];
            uint256 lastIndex = kagePoolStakers[_poolId].length - 1;
            address lastStaker = kagePoolStakers[_poolId][lastIndex];

            if (indexToRemove != lastIndex) {
                kagePoolStakers[_poolId][indexToRemove] = lastStaker;
                kageStakerIndices[_poolId][lastStaker] = indexToRemove;
            }

            kagePoolStakers[_poolId].pop();
            delete kageStakerIndices[_poolId][account];
            kageIsStaking[_poolId][account] = false;
        }

        kageAcceptedToken.safeTransfer(account, amount);
        emit KageWithdraw(_poolId, account, amount);
    }

    /**
     * @notice Allows a user to claim their tokens after the cooldown period has elapsed.
     * @param _poolId The ID of the pool.
     */
    function kageClaimPendingWithdraw(uint256 _poolId)
        external
        nonReentrant
        kageValidatePoolById(_poolId)
    {
        address account = msg.sender;
        KagePendingEarlyWithdrawal
            storage pendingWithdrawal = kagePendingEarlyWithdrawals[_poolId][
                account
            ];

        require(
            pendingWithdrawal.amount > 0,
            "KageStakingPool: no pending withdrawal"
        );
        require(
            block.timestamp >= pendingWithdrawal.applicableAt,
            "KageStakingPool: withdrawal not ready"
        );

        uint128 amountToWithdraw = pendingWithdrawal.amount;

        // Reset the pending withdrawal data
        delete kagePendingEarlyWithdrawals[_poolId][account];

        // Transfer tokens to user
        kageAcceptedToken.safeTransfer(account, amountToWithdraw);

        emit KageClaimPendingWithdraw(_poolId, account, amountToWithdraw);
    }

    /**
     * @notice Returns the pending early withdrawal information for a user in a specific pool.
     * @param _poolId The ID of the pool.
     * @param _account The address of the user.
     * @return amount The amount of tokens pending withdrawal.
     * @return applicableAt The timestamp when the withdrawal becomes claimable.
     */
    function kageGetPendingWithdrawal(uint256 _poolId, address _account)
        external
        view
        kageValidatePoolById(_poolId)
        returns (uint128 amount, uint128 applicableAt)
    {
        KagePendingEarlyWithdrawal
            storage pendingWithdrawal = kagePendingEarlyWithdrawals[_poolId][
                _account
            ];
        return (pendingWithdrawal.amount, pendingWithdrawal.applicableAt);
    }

    /**
     * @notice Returns an array of staker addresses, their staked amounts, and withdrawal times for a given pool
     * @param _poolId The ID of the pool
     * @return poolStakers Array of tuples containing (address staker, uint128 stakedAmount, uint128 withdrawalTime)
     * @dev This function returns all stakers in the pool. For large pools, consider implementing pagination
     */
    function _kageGetPoolStakers(uint256 _poolId)
        internal
        view
        kageValidatePoolById(_poolId)
        returns (KageStakingData[] memory poolStakers)
    {
        // Get total number of stakers in this pool
        uint256 stakerCount = kagePoolStakers[_poolId].length;

        // Initialize return array
        poolStakers = new KageStakingData[](stakerCount);
        // Populate staker info array
        for (uint256 i = 0; i < stakerCount; i++) {
            address stakerAddress = kagePoolStakers[_poolId][i];
            KageStakingData memory stakingData = kageStakingData[_poolId][
                stakerAddress
            ];
            poolStakers[i] = stakingData;
        }

        return poolStakers;
    }

    /**
     * @notice Returns an array of staker addresses, their staked amounts, and withdrawal times for a given pool
     * @param _poolIds Array of pool IDs to allocate revenue to
     * @param _amounts Array of revenue amounts corresponding to each pool ID
     * @dev Only callable by the admin. Creates claim records rather than direct transfers.
     */
    function kageAllocateRevenue(
        uint256[] calldata _poolIds,
        uint128[] calldata _amounts,
        bool _accumulative
    ) external onlyOwner nonReentrant {
        require(msg.sender == owner(), "KageStakingPool: caller is not owner");
        require(
            _poolIds.length == _amounts.length,
            "KageStakingPool: array lengths must match"
        );
        require(_poolIds.length > 0, "KageStakingPool: empty arrays");

        // Check total required balance once
        uint256 totalRequired = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalRequired += _amounts[i];
        }
        require(
            kageAcceptedToken.balanceOf(address(this)) >= totalRequired,
            "KageStakingPool: insufficient contract balance"
        );

        // Process each pool separately to reduce stack depth
        for (uint256 i = 0; i < _poolIds.length; i++) {
            _allocateRevenueForPool(_poolIds[i], _amounts[i], _accumulative);
        }
    }

    // Split the allocation logic into a separate function to reduce stack depth
    function _allocateRevenueForPool(
        uint256 _poolId,
        uint128 _amount,
        bool _accumulative
    ) private {
        require(_amount > 0, "KageStakingPool: amount must be greater than 0");
        require(
            _poolId < kagePoolInfo.length,
            "KageStakingPool: invalid pool id"
        );

        KagePoolInfo storage pool = kagePoolInfo[_poolId];
        require(pool.totalStaked > 0, "KageStakingPool: no stakers in pool");

        // Get all stakers and their data
        KageStakingData[] memory poolStakers = _kageGetPoolStakers(_poolId);
        uint128 revenuePerToken = uint128(
            (_amount * HUNDRED_PERCENT) / pool.totalStaked
        );
        uint128 currentTime = uint128(block.timestamp);

        // Process each staker
        for (uint256 i = 0; i < poolStakers.length; i++) {
            if (poolStakers[i].balance == 0) continue;

            address stakerAddress = kagePoolStakers[_poolId][i];
            uint128 stakerRevenue = uint128(
                (uint256(poolStakers[i].balance) * revenuePerToken) /
                    HUNDRED_PERCENT
            );

            KageRevenueData storage revenueData = kageRevenueData[_poolId][
                stakerAddress
            ];

            if (_accumulative) {
                revenueData.amount += stakerRevenue;
                revenueData.snapshotTime = currentTime;
            } else if (revenueData.snapshotTime != currentTime) {
                revenueData.amount = stakerRevenue;
                revenueData.snapshotTime = currentTime;
            } else {
                revenueData.amount += stakerRevenue;
            }
        }

        emit KageRevenueAllocated(_poolId, _amount);
    }

    /**
     * @notice Get the pending revenue amount for a specific pool and staker
     * @param _poolId The ID of the pool to check
     * @param _staker The address of the staker to check
     * @return amount The pending revenue amount for the staker
     */
    function kageGetPendingRevenue(uint256 _poolId, address _staker)
        external
        view
        returns (uint128 amount)
    {
        KageRevenueData storage revenueData = kageRevenueData[_poolId][_staker];
        return revenueData.amount;
    }

    /**
     * @notice Get all stakers and their revenue data for a specific pool
     * @param _poolId The ID of the pool to check
     * @return stakers Array of staker addresses
     * @return revenues Array of revenue data corresponding to each staker
     */
    function kageGetPoolRevenueData(uint256 _poolId)
        external
        view
        returns (address[] memory stakers, KageRevenueData[] memory revenues)
    {
        // Get array of stakers for this pool
        stakers = kagePoolStakers[_poolId];

        // Initialize revenues array with same length as stakers
        revenues = new KageRevenueData[](stakers.length);

        // Populate revenue data for each staker
        for (uint256 i = 0; i < stakers.length; i++) {
            revenues[i] = kageRevenueData[_poolId][stakers[i]];
        }

        return (stakers, revenues);
    }

    /**
     * @notice Returns a paginated array of staking data for stakers in a given pool
     * @param _poolId The ID of the pool
     * @param _offset Starting index for pagination
     * @param _limit Maximum number of addresses to return
     * @return poolStakers Array of staker addresses for the requested page
     * @return total Total number of stakers in the pool
     */
    function kageGetPoolStakersPaginated(
        uint256 _poolId,
        uint256 _offset,
        uint256 _limit
    )
        external
        view
        kageValidatePoolById(_poolId)
        returns (address[] memory poolStakers, uint256 total)
    {
        address[] memory allStakers = kagePoolStakers[_poolId];
        total = allStakers.length;

        // Calculate actual limit considering array bounds
        uint256 end = _offset + _limit;
        if (end > total) {
            end = total;
        }
        if (_offset >= total) {
            return (new address[](0), total);
        }

        // Create result array of appropriate size
        uint256 resultLength = end - _offset;
        poolStakers = new address[](resultLength);

        // Fill result array
        for (uint256 i = 0; i < resultLength; i++) {
            poolStakers[i] = allStakers[_offset + i];
        }

        return (poolStakers, total);
    }

    /// @dev Gap for future storage variables
    /// @dev This gap allows us to add new storage variables in upgrades
    uint256[47] private __gap;

    /**
     * @notice Calculates the current rewards for a given pool and wallet address
     * @param _poolId The ID of the pool
     * @param _wallet The wallet address to check rewards for
     * @return The current reward amount
     */
    function kageCalculateCurrentRewards(uint256 _poolId, address _wallet)
        external
        view
        kageValidatePoolById(_poolId)
        returns (uint128)
    {
        KageStakingData storage stakingData = kageStakingData[_poolId][_wallet];

        // If no balance or not staking, return 0
        if (stakingData.balance == 0) {
            return 0;
        }
        // Get the lock period for this wallet
        uint128 walletLockPeriod = uint128(block.timestamp) -
            stakingData.updatedTime;

        // If wallet's staking period exceeds pool's lock duration, use pool's lock duration
        if (walletLockPeriod > kagePoolInfo[_poolId].lockDuration) {
            walletLockPeriod = kagePoolInfo[_poolId].lockDuration;
        }

        KagePoolInfo storage pool = kagePoolInfo[_poolId];

        return
            _calculateRewards(
                stakingData.balance,
                stakingData.updatedTime,
                uint128(block.timestamp),
                pool.APY,
                walletLockPeriod
            );
    }

    /**
     * @notice Calculates rewards based on staking parameters
     * @dev Uses APY and staking duration to compute rewards with precision
     * @param stakedAmount The amount of tokens staked
     * @param stakingStartTime The timestamp when staking started
     * @param stakingEndTime The timestamp when staking ended
     * @param APY The annual percentage yield in basis points
     * @param lockDuration The duration for which tokens are locked
     * @return The calculated reward amount
     */
    function _calculateRewards(
        uint128 stakedAmount,
        uint128 stakingStartTime,
        uint128 stakingEndTime,
        uint64 APY,
        uint128 lockDuration
    ) internal pure returns (uint128) {
        if (stakingEndTime <= stakingStartTime || APY == 0) {
            return 0;
        }

        uint128 stakingDuration = stakingEndTime - stakingStartTime;
        if (stakingDuration > lockDuration) {
            stakingDuration = lockDuration;
        }
        // Use standard multiplication for calculations
        uint256 numerator = uint256(stakedAmount) *
            uint64(APY) *
            uint256(stakingDuration) *
            PRECISION_FACTOR;
        uint256 denominator = uint256(HUNDRED_PERCENT) *
            ONE_YEAR_IN_SECONDS *
            PRECISION_FACTOR;
        uint256 rewards = numerator / denominator;

        // Ensure no overflow when casting back to uint128
        require(
            rewards <= type(uint128).max,
            "KageStakingPool: reward overflow"
        );
        return uint128(rewards);
    }

    /**
     * @notice Gets the next nonce for a user
     * @dev Used to prevent transaction replay attacks
     * @param user The address of the user
     * @return The next nonce value for the user
     */
    function kageGetNextNonce(address user) external view returns (uint256) {
        return kageUserNonces[user];
    }

    function kageGetProxyAdmin() external view returns (address) {
        return address(treasury);
    }
}
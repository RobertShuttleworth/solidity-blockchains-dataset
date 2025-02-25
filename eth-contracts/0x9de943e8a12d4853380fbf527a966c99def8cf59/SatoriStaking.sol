// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}


/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}


contract SatoriStaking is Ownable, ReentrancyGuard , Pausable{

    IERC20 public immutable satoriToken;
    uint256 public constant MAX_REWARDS_ALLOCATION = 15_000_000 * 10**18;  // Total allocated $SATORI tokens for rewards
    uint256 public totalAllocatedRewards;                                  // Track the total allocated rewards
    address public dead = 0x000000000000000000000000000000000000dEaD;

    struct StakingProgram {
        uint64 duration;                 // Duration in days
        uint64 apy;                      // Annual Percentage Yield in basis points (10000 = 100%)
        uint64 earlyWithdrawalPeriod;    // Early withdrawal period in days
        uint64 earlyWithdrawalFee;       // Early withdrawal fee percentage in basis points (10000 = 100%)
    }

    struct Stake {
        uint256 amount;
        uint256 accumulatedRewards;
        uint64 startTime;
        uint64 programIndex;
        bool restaked;
        bool unstaked;
        bool claimed;
    }

    StakingProgram[] public stakingPrograms;
    mapping(address => mapping(uint256 => Stake)) public stakes;
    mapping(address => uint256) public stakeCounts;

    event Staked(address indexed user, uint256 amount, uint256 programIndex);
    event Unstaked(address indexed user, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 amount);
    event Burned(uint256 amount);

    /**
     * @dev Initializes the contract with the given $SATORI token address and defines staking programs.
     * @param _satoriToken Address of the $SATORI token contract.
     */
    constructor(address _satoriToken) Ownable(msg.sender){
        satoriToken = IERC20(_satoriToken);

        // Initialize staking programs
        stakingPrograms.push(StakingProgram(14, 1500, 3, 300));
        stakingPrograms.push(StakingProgram(30, 3600, 7, 600));
        stakingPrograms.push(StakingProgram(45, 4800, 10, 1200));
        stakingPrograms.push(StakingProgram(60, 7200, 14, 1500));
    }


    /**
     * @notice Allows users to stake $SATORI tokens in a specified staking program.
     * @param amount The amount of $SATORI tokens to stake.
     * @param programIndex The ID of the staking program (0-3).
     */
    function stake(uint256 amount, uint256 programIndex) external nonReentrant whenNotPaused {
        require(satoriToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(satoriToken.allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");

        require(amount > 0, "Staking amount must be greater than 0");
        require(programIndex < stakingPrograms.length, "Invalid staking program index");

        uint256 stakeIndex = stakeCounts[msg.sender];
        stakes[msg.sender][stakeIndex] = Stake(amount, 0, uint64(block.timestamp), uint64(programIndex), false, false, false);
        stakeCounts[msg.sender] = stakeIndex + 1;

        satoriToken.transferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, amount, programIndex);
    }


    /**
     * @notice Allows users to unstake their tokens from a specified staking program.
     * @param stakeIndex The index of the user's stake to unstake.
     */
    function unstake(uint256 stakeIndex) external nonReentrant {
        Stake storage userStake = stakes[msg.sender][stakeIndex];
        require(!userStake.unstaked, "Already unstaked");
        require(userStake.amount > 0, "Invalid stake");

        StakingProgram memory program = stakingPrograms[userStake.programIndex];
        uint256 duration = (block.timestamp - userStake.startTime) / 1 days;
        uint256 amount = userStake.amount;
        uint256 reward;

        if (duration < program.earlyWithdrawalPeriod) {
            // Early withdrawal period
            uint256 fee = (amount * program.earlyWithdrawalFee) / 10000;
            amount -= fee;
            satoriToken.transfer(dead, fee);
            satoriToken.transfer(_msgSender(), amount);
            emit Burned(fee);
        } else if (duration < program.duration) {
            revert("Cannot unstake during the lockup period");
        } else {
            // After staking period is complete
            satoriToken.transfer(_msgSender(), amount);
        }

        userStake.unstaked = true;
        emit Unstaked(msg.sender, amount, reward);
    }


    function restake(uint256 stakeIndex) external {
        Stake storage userStake = stakes[msg.sender][stakeIndex];
        require(userStake.amount > 0 && !userStake.unstaked, "Invalid stake");

        StakingProgram memory program = stakingPrograms[userStake.programIndex];
        uint256 duration = (block.timestamp - userStake.startTime) / 1 days;
        require(duration >= program.duration, "Cannot restake yet");

        uint256 reward = _calculateReward(userStake);

        userStake.startTime = uint64(block.timestamp);
        userStake.accumulatedRewards += reward;
        userStake.restaked = true;

        emit Staked(msg.sender, userStake.amount, userStake.programIndex);
    }


    function claimRewards(uint256 stakeIndex) external nonReentrant{
        Stake storage userStake = stakes[msg.sender][stakeIndex];
        require(userStake.unstaked, "Claim available only after unstake");
        require(!userStake.claimed, "Already claimed");

        uint256 reward = _calculateReward(userStake) + userStake.accumulatedRewards;
        require(totalAllocatedRewards + reward <= MAX_REWARDS_ALLOCATION, "Max rewards allocation exceeded");
        totalAllocatedRewards += reward;
        userStake.claimed = true;
        userStake.accumulatedRewards = reward;

        satoriToken.transfer(_msgSender(), reward);

        emit RewardsClaimed(msg.sender, reward);

    }


    function _calculateReward(Stake memory userStake) internal view returns (uint256) {
        StakingProgram memory program = stakingPrograms[userStake.programIndex];
        uint256 duration = (block.timestamp - userStake.startTime) / 1 days;

        if(duration > program.duration){
            duration = program.duration;
        }

        uint256 apy = program.apy;

        if (userStake.restaked && (userStake.programIndex == 2 || userStake.programIndex == 3)) {
            return ((userStake.amount * (apy + 1200)) * duration) / 3650000;
        } else {
            return ((userStake.amount * apy) * duration) / 3650000;
        }
    }


    /**
     * @notice Gets all stakes for a user.
     * @param user The address of the user.
     * @return An array of stakes.
     */
    function getUserStakes(address user) external view returns (Stake[] memory) {
        uint256 count = stakeCounts[user];
        Stake[] memory userStakes = new Stake[](count);

        for (uint256 i = 0; i < count; i++) {
            userStakes[i] = stakes[user][i];
        }

        return userStakes;
    }


    function getEarnedReward(address user, uint256 stakeIndex) external view returns (uint256 reward){
       Stake storage userStake = stakes[user][stakeIndex];
       reward = userStake.accumulatedRewards + _calculateReward(userStake);
    }


    function getProgram(uint64 programIndex) external view returns(StakingProgram memory){
        return stakingPrograms[programIndex];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
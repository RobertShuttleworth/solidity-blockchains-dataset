// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
pragma experimental ABIEncoderV2;

import "./contracts_libraries_MathUtil.sol";
import "./contracts_interfaces_IStakingProxy.sol";
import "./contracts_interfaces_IRewardStaking.sol";
import "./contracts_libraries_BoringMath.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_utils_math_Math.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./contracts_QLqdrGateway.sol";
import "./contracts_interfaces_ISmartWalletWhitelist.sol";

/*
LQDR Locking contract
*/
contract QLqdr is ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using BoringMath for uint256;
    using BoringMath224 for uint224;
    using BoringMath112 for uint112;
    using BoringMath32 for uint32;
    using SafeERC20 for IERC20;

    /* ========== AXELAR VARIABLES ========== */
    QLqdrGateway public qLqdrGateway;
    uint256 public minValue;

    /* ========== STATE VARIABLES ========== */

    struct Reward {
        uint40 periodFinish;
        uint208 rewardRate;
        uint40 lastUpdateTime;
        uint208 rewardPerTokenStored;
    }
    struct Balances {
        uint112 locked;
        uint32 nextUnlockId;
    }
    struct LockedBalance {
        uint112 amount;
        uint32 unlockTime;
    }
    struct EarnedData {
        address token;
        uint256 amount;
    }
    struct Epoch {
        uint224 supply; //epoch supply
        uint32 date; //epoch start date
    }

    //token
    IERC20 public stakingToken;

    //rewards
    address[] public rewardTokens;
    mapping(address => Reward) public rewardData;

    // Duration that rewards are streamed over
    uint256 public rewardsDuration;

    // Duration of lock/earned penalty period
    uint256 public lockDuration;

    // reward token -> distributor -> is approved to add rewards
    mapping(address => mapping(address => bool)) public rewardDistributors;

    // user -> reward token -> amount
    mapping(address => mapping(address => uint256))
        public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    //supplies and epochs
    uint256 public lockedSupply;
    Epoch[] public epochs;

    //mappings for balance data
    mapping(address => Balances) public balances;
    mapping(address => LockedBalance[]) public userLocks;

    uint256 public denominator;

    //management
    uint256 public kickRewardPerEpoch;
    uint256 public kickRewardEpochDelay;

    //shutdown
    bool public isShutdown;

    //erc20-like interface
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    //instant unlock variables
    uint256 public penalty;
    bool public instantUnlockEnabled;

    address public smartWalletChecker;

    bool public kickEnabled;

    mapping(address => uint256) public instantWithdrawTime;
    mapping(uint256 => uint256) public instantWithdrawnByEpoch;

    bool public paused;

    /* ========== CONSTRUCTOR ========== */

    constructor() {}

    function initialize(
        IERC20 _stakingToken,
        uint256 _rewardsDuration,
        uint256 _minValue,
        uint256 _penalty,
        bool _instantUnlockEnabled,
        address _smartWalletChecker
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        denominator = 10000;
        kickRewardPerEpoch = 100;
        kickRewardEpochDelay = 4;

        require(_penalty > 0 && _penalty <= 10000, "Invalid penalty fee");
        penalty = _penalty;
        instantUnlockEnabled = _instantUnlockEnabled;

        minValue = _minValue;

        _name = "Vote Locked LQDR Token";
        _symbol = "QLQDR";
        _decimals = 18;
        stakingToken = _stakingToken;

        rewardsDuration = _rewardsDuration;
        lockDuration = rewardsDuration * 12;
        uint256 currentEpoch = block.timestamp.div(rewardsDuration).mul(
            rewardsDuration
        );
        epochs.push(Epoch({supply: 0, date: uint32(currentEpoch)}));

        isShutdown = false;

        smartWalletChecker = _smartWalletChecker;
    }

    modifier onlyWhitelisted() {
        if (tx.origin != msg.sender) {
            require(
                address(smartWalletChecker) != address(0),
                "Not whitelisted"
            );
            require(
                ISmartWalletWhitelist(smartWalletChecker).check(msg.sender),
                "Not whitelisted"
            );
        }
        _;
    }

    modifier onlyGateway() {
        require(msg.sender == address(qLqdrGateway), "!Gateway");
        _;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function version() public pure returns (uint256) {
        return 1;
    }

    /* ========== ADMIN CONFIGURATION ========== */
    function setQLqdrGateway(address payable _qLqdrGateway) public onlyOwner {
        qLqdrGateway = QLqdrGateway(_qLqdrGateway);
    }

    function setMinValue(uint256 _minValue) external onlyOwner {
        minValue = _minValue;
    }

    function setPenaltyFee(uint256 _penalty) external onlyOwner {
        require(_penalty > 0 && _penalty <= 10000, "Invalid penalty fee");
        penalty = _penalty;
    }

    function enableInstantUnlock(bool _enabled) external onlyOwner {
        require(instantUnlockEnabled != _enabled, "Already set");
        instantUnlockEnabled = _enabled;
    }

    function enableKick(bool _enabled) external onlyOwner {
        require(kickEnabled != _enabled, "Already set");
        kickEnabled = _enabled;
    }

    function pause(bool _paused) external onlyOwner {
        require(paused != _paused, "Already set");
        paused = _paused;
    }

    // Add a new reward token to be distributed to stakers
    function addReward(
        address _rewardsToken,
        address _distributor
    ) public onlyOwner {
        require(rewardData[_rewardsToken].lastUpdateTime == 0);
        require(_rewardsToken != address(stakingToken));
        rewardTokens.push(_rewardsToken);
        rewardData[_rewardsToken].lastUpdateTime = uint40(block.timestamp);
        rewardData[_rewardsToken].periodFinish = uint40(block.timestamp);
        rewardDistributors[_rewardsToken][_distributor] = true;
    }

    // Modify approval for an address to call notifyRewardAmount
    function approveRewardDistributor(
        address _rewardsToken,
        address _distributor,
        bool _approved
    ) external onlyOwner {
        require(rewardData[_rewardsToken].lastUpdateTime > 0);
        rewardDistributors[_rewardsToken][_distributor] = _approved;
    }

    //set kick incentive
    function setKickIncentive(
        uint256 _rate,
        uint256 _delay
    ) external onlyOwner {
        require(_rate <= 500, "over max rate"); //max 5% per epoch
        require(_delay >= 2, "min delay"); //minimum 2 epochs of grace
        kickRewardPerEpoch = _rate;
        kickRewardEpochDelay = _delay;
    }

    //shutdown the contract. unstake all tokens. release all locks
    function shutdown() external onlyOwner {
        isShutdown = true;
    }

    /* ========== VIEWS ========== */

    function _rewardPerToken(
        address _rewardsToken,
        uint256 _totalSupply
    ) internal view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardData[_rewardsToken].rewardPerTokenStored;
        }
        return
            uint256(rewardData[_rewardsToken].rewardPerTokenStored).add(
                _lastTimeRewardApplicable(
                    rewardData[_rewardsToken].periodFinish
                )
                    .sub(rewardData[_rewardsToken].lastUpdateTime)
                    .mul(rewardData[_rewardsToken].rewardRate)
                    .mul(1e18)
                    .div(_totalSupply)
            );
    }

    function _earned(
        address _user,
        address _rewardsToken,
        uint256 _balance,
        uint256 _totalSupply
    ) internal view returns (uint256) {
        return
            _balance
                .mul(
                    _rewardPerToken(_rewardsToken, _totalSupply).sub(
                        userRewardPerTokenPaid[_user][_rewardsToken]
                    )
                )
                .div(1e18)
                .add(rewards[_user][_rewardsToken]);
    }

    function _lastTimeRewardApplicable(
        uint256 _finishTime
    ) internal view returns (uint256) {
        return Math.min(block.timestamp, _finishTime);
    }

    function lastTimeRewardApplicable(
        address _rewardsToken
    ) public view returns (uint256) {
        return
            _lastTimeRewardApplicable(rewardData[_rewardsToken].periodFinish);
    }

    function rewardPerToken(
        address _rewardsToken
    ) external view returns (uint256) {
        uint256 _totalSupply = qLqdrGateway.totalSupply();
        return _rewardPerToken(_rewardsToken, _totalSupply);
    }

    function getRewardForDuration(
        address _rewardsToken
    ) external view returns (uint256) {
        return
            uint256(rewardData[_rewardsToken].rewardRate).mul(rewardsDuration);
    }

    // Address and claimable amount of all reward tokens for the given account
    function claimableRewards(
        address _account
    ) external view returns (EarnedData[] memory userRewards) {
        userRewards = new EarnedData[](rewardTokens.length);
        // Balances storage userBalance = balances[_account];
        uint256 _balance = qLqdrGateway.lockedBalanceOf(_account);
        uint256 _totalSupply = qLqdrGateway.totalLockedSupply();
        for (uint256 i = 0; i < userRewards.length; i++) {
            address token = rewardTokens[i];
            userRewards[i].token = token;
            userRewards[i].amount = _earned(
                _account,
                token,
                _balance,
                _totalSupply
            );
        }
        return userRewards;
    }

    // total token balance of an account, including unlocked but not withdrawn tokens
    function lockedBalanceOf(
        address _user
    ) external view returns (uint256 amount) {
        return balances[_user].locked;
    }

    //balance of an account which only includes properly locked tokens as of the most recent eligible epoch
    function balanceOf(address _user) external view returns (uint256 amount) {
        LockedBalance[] storage locks = userLocks[_user];
        Balances storage userBalance = balances[_user];
        uint256 nextUnlockId = userBalance.nextUnlockId;

        //start with current locked amount
        amount = balances[_user].locked;

        if (balances[_user].locked > 0) {
            uint256 locksLength = locks.length;
            //remove old records only (will be better gas-wise than adding up)
            for (uint i = nextUnlockId; i < locksLength; i++) {
                if (locks[i].unlockTime <= block.timestamp) {
                    amount = amount.sub(locks[i].amount);
                } else {
                    //stop now as no futher checks are needed
                    break;
                }
            }

            //also remove amount locked in the next epoch
            uint256 currentEpoch = block.timestamp.div(rewardsDuration).mul(
                rewardsDuration
            );
            if (
                locksLength > 0 &&
                uint256(locks[locksLength - 1].unlockTime).sub(lockDuration) >
                currentEpoch
            ) {
                amount = amount.sub(locks[locksLength - 1].amount);
            }
        }

        return amount;
    }

    //balance of an account which only includes properly locked tokens at the given epoch
    function balanceAtEpochOf(
        uint256 _epoch,
        address _user
    ) external view returns (uint256 amount) {
        LockedBalance[] storage locks = userLocks[_user];

        //get timestamp of given epoch index
        uint256 epochTime = epochs[_epoch].date;
        //get timestamp of first non-inclusive epoch
        uint256 cutoffEpoch = epochTime.sub(lockDuration);

        //need to add up since the range could be in the middle somewhere
        //traverse inversely to make more current queries more gas efficient
        for (uint i = locks.length - 1; i + 1 != 0; i--) {
            uint256 lockEpoch = uint256(locks[i].unlockTime).sub(lockDuration);
            //lock epoch must be less or equal to the epoch we're basing from.
            if (lockEpoch <= epochTime) {
                if (lockEpoch > cutoffEpoch) {
                    amount = amount.add(locks[i].amount);
                } else {
                    //stop now as no futher checks matter
                    break;
                }
            }

            if (i == 0) {
                break;
            }
        }

        return amount;
    }

    //return currently locked but not active balance
    function pendingLockOf(
        address _user
    ) external view returns (uint256 amount) {
        LockedBalance[] storage locks = userLocks[_user];

        uint256 locksLength = locks.length;

        //return amount if latest lock is in the future
        uint256 currentEpoch = block.timestamp.div(rewardsDuration).mul(
            rewardsDuration
        );
        if (
            locksLength > 0 &&
            uint256(locks[locksLength - 1].unlockTime).sub(lockDuration) >
            currentEpoch
        ) {
            return locks[locksLength - 1].amount;
        }

        return 0;
    }

    function pendingLockAtEpochOf(
        uint256 _epoch,
        address _user
    ) external view returns (uint256 amount) {
        LockedBalance[] storage locks = userLocks[_user];

        //get next epoch from the given epoch index
        uint256 nextEpoch = uint256(epochs[_epoch].date).add(rewardsDuration);

        if (locks.length == 0) {
            return 0;
        }
        //traverse inversely to make more current queries more gas efficient
        for (uint i = locks.length - 1; i + 1 != 0; i--) {
            uint256 lockEpoch = uint256(locks[i].unlockTime).sub(lockDuration);

            //return the next epoch balance
            if (lockEpoch == nextEpoch) {
                return locks[i].amount;
            } else if (lockEpoch < nextEpoch) {
                //no need to check anymore
                break;
            }

            if (i == 0) {
                break;
            }
        }

        return 0;
    }

    //supply of all properly locked balances at most recent eligible epoch
    function totalSupply() external view returns (uint256 supply) {
        uint256 currentEpoch = block.timestamp.div(rewardsDuration).mul(
            rewardsDuration
        );
        uint256 cutoffEpoch = currentEpoch.sub(lockDuration);
        uint256 epochindex = epochs.length;

        //do not include next epoch's supply
        if (uint256(epochs[epochindex - 1].date) > currentEpoch) {
            epochindex--;
        }

        //traverse inversely to make more current queries more gas efficient
        for (uint i = epochindex - 1; i + 1 != 0; i--) {
            Epoch storage e = epochs[i];
            if (uint256(e.date) <= cutoffEpoch) {
                break;
            }
            supply = supply.add(e.supply);

            if (instantWithdrawnByEpoch[i] > 0) {
                supply -= instantWithdrawnByEpoch[i];
            }

            if (i == 0) {
                break;
            }
        }

        return supply;
    }

    //supply of all properly locked balances at the given epoch
    function totalSupplyAtEpoch(
        uint256 _epoch
    ) external view returns (uint256 supply) {
        uint256 epochStart = uint256(epochs[_epoch].date)
            .div(rewardsDuration)
            .mul(rewardsDuration);
        uint256 cutoffEpoch = epochStart.sub(lockDuration);

        //traverse inversely to make more current queries more gas efficient
        for (uint i = _epoch; i + 1 != 0; i--) {
            Epoch storage e = epochs[i];
            if (uint256(e.date) <= cutoffEpoch) {
                break;
            }
            supply = supply.add(epochs[i].supply);

            if (instantWithdrawnByEpoch[i] > 0) {
                supply -= instantWithdrawnByEpoch[i];
            }

            if (i == 0) {
                break;
            }
        }

        return supply;
    }

    //find an epoch index based on timestamp
    function findEpochId(uint256 _time) public view returns (uint256 epoch) {
        uint256 max = epochs.length - 1;
        uint256 min = 0;

        //convert to start point
        _time = _time.div(rewardsDuration).mul(rewardsDuration);

        for (uint256 i = 0; i < 128; i++) {
            if (min >= max) break;

            uint256 mid = (min + max + 1) / 2;
            uint256 midEpochBlock = epochs[mid].date;
            if (midEpochBlock == _time) {
                //found
                return mid;
            } else if (midEpochBlock < _time) {
                min = mid;
            } else {
                max = mid - 1;
            }
        }
        return min;
    }

    // Information on a user's locked balances
    function lockedBalances(
        address _user
    )
        external
        view
        returns (
            uint256 total,
            uint256 unlockable,
            uint256 locked,
            LockedBalance[] memory lockData
        )
    {
        LockedBalance[] storage locks = userLocks[_user];
        Balances storage userBalance = balances[_user];
        uint256 nextUnlockId = userBalance.nextUnlockId;
        uint256 idx;
        for (uint i = nextUnlockId; i < locks.length; i++) {
            if (locks[i].unlockTime > block.timestamp) {
                if (idx == 0) {
                    lockData = new LockedBalance[](locks.length - i);
                }
                lockData[idx] = locks[i];
                idx++;
                locked = locked.add(locks[i].amount);
            } else {
                unlockable = unlockable.add(locks[i].amount);
            }
        }
        return (userBalance.locked, unlockable, locked, lockData);
    }

    function userLocksData(
        address _user
    ) external view returns (LockedBalance[] memory lockData) {
        lockData = userLocks[_user];
    }

    //number of epochs
    function epochCount() external view returns (uint256) {
        return epochs.length;
    }

    //number of rewards
    function rewardCount() external view returns (uint256) {
        return rewardTokens.length;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function checkpointEpoch() external nonReentrant onlyWhitelisted {
        _checkpointEpoch();
    }

    //insert a new epoch if needed. fill in any gaps
    function _checkpointEpoch() internal {
        //create new epoch in the future where new non-active locks will lock to
        uint256 nextEpoch = block
            .timestamp
            .div(rewardsDuration)
            .mul(rewardsDuration)
            .add(rewardsDuration);
        uint256 epochindex = epochs.length;

        //first epoch add in constructor, no need to check 0 length

        //check to add
        if (epochs[epochindex - 1].date < nextEpoch) {
            //fill any epoch gaps
            while (epochs[epochs.length - 1].date != nextEpoch) {
                uint256 nextEpochDate = uint256(epochs[epochs.length - 1].date)
                    .add(rewardsDuration);
                epochs.push(Epoch({supply: 0, date: uint32(nextEpochDate)}));
            }
        }
    }

    // Locked tokens cannot be withdrawn for lockDuration and are eligible to receive stakingReward rewards
    function lock(
        address _account,
        uint256 _amount
    ) external payable nonReentrant onlyWhitelisted updateReward(_account) {
        //pull tokens
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        //lock
        _lock(_account, _amount, false);

        require(msg.value >= minValue, "Wrong value");
        qLqdrGateway.lockOnThisChain{value: msg.value}(_account, _amount);
    }

    //lock tokens
    function _lock(address _account, uint256 _amount, bool _isRelock) internal {
        require(!paused, "Paused");
        require(_amount > 0, "Cannot stake 0");
        require(!isShutdown, "shutdown");

        require(
            instantWithdrawTime[_account] + rewardsDuration < block.timestamp,
            "1 epoch should be passed from the instant withdraw"
        );

        Balances storage bal = balances[_account];

        //must try check pointing epoch first
        _checkpointEpoch();

        uint112 lockAmount = _amount.to112();

        //add user balances
        bal.locked = bal.locked.add(lockAmount);

        //add to total supplies
        lockedSupply = lockedSupply.add(lockAmount);

        //add user lock records or add to current
        uint256 lockEpoch = block.timestamp.div(rewardsDuration).mul(
            rewardsDuration
        );
        //if a fresh lock, add on an extra duration period
        if (!_isRelock) {
            lockEpoch = lockEpoch.add(rewardsDuration);
        }
        uint256 unlockTime = lockEpoch.add(lockDuration);
        uint256 idx = userLocks[_account].length;

        //if the latest user lock is smaller than this lock, always just add new entry to the end of the list
        if (idx == 0 || userLocks[_account][idx - 1].unlockTime < unlockTime) {
            userLocks[_account].push(
                LockedBalance({
                    amount: lockAmount,
                    unlockTime: uint32(unlockTime)
                })
            );
        } else {
            //else add to a current lock

            //if latest lock is further in the future, lower index
            //this can only happen if relocking an expired lock after creating a new lock
            if (userLocks[_account][idx - 1].unlockTime > unlockTime) {
                idx--;
            }

            //if idx points to the epoch when same unlock time, update
            //(this is always true with a normal lock but maybe not with relock)
            if (userLocks[_account][idx - 1].unlockTime == unlockTime) {
                LockedBalance storage userL = userLocks[_account][idx - 1];
                userL.amount = userL.amount.add(lockAmount);
            } else {
                //can only enter here if a relock is made after a lock and there's no lock entry
                //for the current epoch.
                //ex a list of locks such as "[...][older][current*][next]" but without a "current" lock
                //length - 1 is the next epoch
                //length - 2 is a past epoch
                //thus need to insert an entry for current epoch at the 2nd to last entry
                //we will copy and insert the tail entry(next) and then overwrite length-2 entry

                //reset idx
                idx = userLocks[_account].length;

                //get current last item
                LockedBalance storage userL = userLocks[_account][idx - 1];

                //add a copy to end of list
                userLocks[_account].push(
                    LockedBalance({
                        amount: userL.amount,
                        unlockTime: userL.unlockTime
                    })
                );

                //insert current epoch lock entry by overwriting the entry at length-2
                userL.amount = lockAmount;
                userL.unlockTime = uint32(unlockTime);
            }
        }

        //update epoch supply, epoch checkpointed above so safe to add to latest
        uint256 eId = epochs.length - 1;
        //if relock, epoch should be current and not next, thus need to decrease index to length-2
        if (_isRelock) {
            eId--;
        }
        Epoch storage e = epochs[eId];
        e.supply = e.supply.add(uint224(lockAmount));

        emit Staked(_account, lockEpoch, _amount, lockAmount);
    }

    // Withdraw all currently locked tokens where the unlock time has passed
    function _processExpiredLocks(
        address _account,
        bool _relock,
        address _withdrawTo,
        address _rewardAddress,
        uint256 _checkDelay,
        bool revertNoExp
    ) internal updateReward(_account) {
        require(!paused, "Paused");
        LockedBalance[] storage locks = userLocks[_account];
        Balances storage userBalance = balances[_account];
        uint112 locked;
        uint256 length = locks.length;
        uint256 reward = 0;

        if (
            isShutdown ||
            locks[length - 1].unlockTime <= block.timestamp.sub(_checkDelay)
        ) {
            //if time is beyond last lock, can just bundle everything together
            locked = userBalance.locked;

            //dont delete, just set next index
            userBalance.nextUnlockId = length.to32();

            //check for kick reward
            //this wont have the exact reward rate that you would get if looped through
            //but this section is supposed to be for quick and easy low gas processing of all locks
            //we'll assume that if the reward was good enough someone would have processed at an earlier epoch
            if (_checkDelay > 0) {
                uint256 currentEpoch = block
                    .timestamp
                    .sub(_checkDelay)
                    .div(rewardsDuration)
                    .mul(rewardsDuration);
                uint256 epochsover = currentEpoch
                    .sub(uint256(locks[length - 1].unlockTime))
                    .div(rewardsDuration);
                uint256 rRate = MathUtil.min(
                    kickRewardPerEpoch.mul(epochsover + 1),
                    denominator
                );
                reward = uint256(locks[length - 1].amount).mul(rRate).div(
                    denominator
                );
            }
        } else {
            //use a processed index(nextUnlockId) to not loop as much
            //deleting does not change array length
            uint32 nextUnlockId = userBalance.nextUnlockId;
            for (uint i = nextUnlockId; i < length; i++) {
                //unlock time must be less or equal to time
                if (locks[i].unlockTime > block.timestamp.sub(_checkDelay))
                    break;

                //add to cumulative amounts
                locked = locked.add(locks[i].amount);

                //check for kick reward
                //each epoch over due increases reward
                if (_checkDelay > 0) {
                    uint256 currentEpoch = block
                        .timestamp
                        .sub(_checkDelay)
                        .div(rewardsDuration)
                        .mul(rewardsDuration);
                    uint256 epochsover = currentEpoch
                        .sub(uint256(locks[i].unlockTime))
                        .div(rewardsDuration);
                    uint256 rRate = MathUtil.min(
                        kickRewardPerEpoch.mul(epochsover + 1),
                        denominator
                    );
                    reward = reward.add(
                        uint256(locks[i].amount).mul(rRate).div(denominator)
                    );
                }
                //set next unlock index
                nextUnlockId++;
            }
            //update next unlock index
            userBalance.nextUnlockId = nextUnlockId;
        }

        if (revertNoExp) {
            require(locked > 0, "no exp locks");
        }
        if (locked == 0) {
            return;
        }

        //update user balances and total supplies
        userBalance.locked = userBalance.locked.sub(locked);
        lockedSupply = lockedSupply.sub(locked);

        emit Withdrawn(_account, locked, _relock);

        //send process incentive
        if (reward > 0) {
            //reduce return amount by the kick reward
            locked = locked.sub(reward.to112());

            //transfer reward
            transferStakingToken(_rewardAddress, reward);

            emit KickReward(_rewardAddress, _account, reward);
        }

        //relock or return to user
        if (_relock) {
            _lock(_withdrawTo, locked, true);
        } else {
            transferStakingToken(_withdrawTo, locked);
        }
    }

    function _increaseInstantWithdrawnByEpoch(
        uint256 _epoch,
        uint256 _amount
    ) internal {
        instantWithdrawnByEpoch[_epoch] += _amount;
    }

    function increaseInstantWithdrawnByEpoch(
        uint256 _epoch,
        uint256 _amount
    ) external onlyOwner {
        _increaseInstantWithdrawnByEpoch(_epoch, _amount);
    }

    // Withdraw all currently locked tokens where the unlock time has passed
    function _processInstantUnlock(
        address _account,
        address _withdrawTo
    ) internal updateReward(_account) {
        require(instantUnlockEnabled && penalty > 0, "Instant unlock disabled");

        LockedBalance[] storage locks = userLocks[_account];
        Balances storage userBalance = balances[_account];
        uint112 locked;
        uint256 length = locks.length;

        //if time is beyond last lock, can just bundle everything together
        locked = userBalance.locked;

        for (uint i = userBalance.nextUnlockId; i < length; i++) {
            uint256 _lockTime = locks[i].unlockTime - lockDuration;
            uint256 _lockEpoch = findEpochId(_lockTime);
            _increaseInstantWithdrawnByEpoch(_lockEpoch, locks[i].amount);
        }

        //dont delete, just set next index
        userBalance.nextUnlockId = length.to32();
        require(locked > 0, "no exp locks");

        //update user balances and total supplies
        userBalance.locked = userBalance.locked.sub(locked);
        lockedSupply = lockedSupply.sub(locked);

        emit Withdrawn(_account, locked, false);

        uint256 _toBurn = (locked * penalty) / denominator;
        uint256 _toSend = uint256(locked) - _toBurn;

        if (_toBurn > 0) {
            transferStakingToken(address(0xdead), _toBurn);
        }
        if (locked > 0) {
            transferStakingToken(_withdrawTo, _toSend);
        }
    }

    // withdraw expired locks to a different address
    function withdrawExpiredLocksTo(
        address _withdrawTo
    ) external payable nonReentrant onlyWhitelisted {
        require(msg.value >= minValue, "Wrong values");
        _processExpiredLocks(
            msg.sender,
            false,
            _withdrawTo,
            msg.sender,
            0,
            true
        );

        qLqdrGateway.withdrawExpiredLocksToOnThisChain{value: msg.value}(
            msg.sender
        );
    }

    function instantWithdrawTo(
        address _withdrawTo
    ) external payable nonReentrant onlyWhitelisted {
        require(!paused, "Paused");
        require(msg.value >= minValue, "Wrong values");
        _processExpiredLocks(
            msg.sender,
            false,
            _withdrawTo,
            msg.sender,
            0,
            false
        );
        _processInstantUnlock(msg.sender, _withdrawTo);

        instantWithdrawTime[msg.sender] = block.timestamp;

        qLqdrGateway.instantWithdrawToOnThisChain{value: msg.value}(msg.sender);
    }

    // Withdraw/relock all currently locked tokens where the unlock time has passed
    function processExpiredLocks(
        bool _relock
    ) external payable nonReentrant onlyWhitelisted {
        _processExpiredLocks(
            msg.sender,
            _relock,
            msg.sender,
            msg.sender,
            0,
            true
        );

        require(msg.value >= minValue, "Wrong values");
        qLqdrGateway.processExpiredLocksOnThisChain{value: msg.value}(
            msg.sender,
            _relock
        );
    }

    function kickExpiredLocks(
        address _account
    ) external payable nonReentrant onlyWhitelisted {
        require(kickEnabled, "Kick feature disabled");
        //allow kick after grace period of 'kickRewardEpochDelay'
        _processExpiredLocks(
            _account,
            false,
            _account,
            msg.sender,
            rewardsDuration.mul(kickRewardEpochDelay),
            true
        );

        require(msg.value == minValue, "Wrong values");
        qLqdrGateway.kickExpiredLocksOnThisChain{value: msg.value}(_account);
    }

    //transfer helper: pull enough from staking, transfer, updating staking ratio
    function transferStakingToken(address _account, uint256 _amount) internal {
        //transfer
        stakingToken.safeTransfer(_account, _amount);
    }

    // Claim all pending rewards
    function getReward(
        address _account
    ) public nonReentrant onlyWhitelisted updateReward(_account) {
        for (uint i; i < rewardTokens.length; i++) {
            address _rewardsToken = rewardTokens[i];
            uint256 reward = rewards[_account][_rewardsToken];
            if (reward > 0) {
                rewards[_account][_rewardsToken] = 0;
                IERC20(_rewardsToken).safeTransfer(_account, reward);
                emit RewardPaid(_account, _rewardsToken, reward);
            }
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function _notifyReward(address _rewardsToken, uint256 _reward) internal {
        Reward storage rdata = rewardData[_rewardsToken];

        if (block.timestamp >= rdata.periodFinish) {
            rdata.rewardRate = _reward.div(rewardsDuration).to208();
        } else {
            uint256 remaining = uint256(rdata.periodFinish).sub(
                block.timestamp
            );
            uint256 leftover = remaining.mul(rdata.rewardRate);
            rdata.rewardRate = _reward
                .add(leftover)
                .div(rewardsDuration)
                .to208();
        }

        rdata.lastUpdateTime = block.timestamp.to40();
        rdata.periodFinish = block.timestamp.add(rewardsDuration).to40();
    }

    function notifyRewardAmount(
        address _rewardsToken,
        uint256 _reward
    ) external updateReward(address(0)) {
        require(rewardDistributors[_rewardsToken][msg.sender]);
        require(_reward > 0, "No reward");

        _notifyReward(_rewardsToken, _reward);

        // handle the transfer of reward tokens via `transferFrom` to reduce the number
        // of transactions required and ensure correctness of the _reward amount
        IERC20(_rewardsToken).safeTransferFrom(
            msg.sender,
            address(this),
            _reward
        );

        emit RewardAdded(_rewardsToken, _reward);
    }

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external onlyOwner {
        require(
            _tokenAddress != address(stakingToken),
            "Cannot withdraw staking token"
        );
        require(
            rewardData[_tokenAddress].lastUpdateTime == 0,
            "Cannot withdraw reward token"
        );
        IERC20(_tokenAddress).safeTransfer(owner(), _tokenAmount);
        emit Recovered(_tokenAddress, _tokenAmount);
    }

    function forceUpdateReward(address _account) external onlyGateway {
        //stack too deep
        // Balances storage userBalance = balances[_account];
        uint256 _balance = qLqdrGateway.lockedBalanceOf(_account);
        uint256 _totalSupply = qLqdrGateway.totalLockedSupply();
        for (uint i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            rewardData[token].rewardPerTokenStored = _rewardPerToken(
                token,
                _totalSupply
            ).to208();
            rewardData[token].lastUpdateTime = _lastTimeRewardApplicable(
                rewardData[token].periodFinish
            ).to40();
            if (_account != address(0)) {
                rewards[_account][token] = _earned(
                    _account,
                    token,
                    _balance,
                    _totalSupply
                );
                userRewardPerTokenPaid[_account][token] = rewardData[token]
                    .rewardPerTokenStored;
            }
        }
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address _account) {
        {
            //stack too deep
            // Balances storage userBalance = balances[_account];
            uint256 _balance = qLqdrGateway.lockedBalanceOf(_account);
            uint256 _totalSupply = qLqdrGateway.totalLockedSupply();
            for (uint i = 0; i < rewardTokens.length; i++) {
                address token = rewardTokens[i];
                rewardData[token].rewardPerTokenStored = _rewardPerToken(
                    token,
                    _totalSupply
                ).to208();
                rewardData[token].lastUpdateTime = _lastTimeRewardApplicable(
                    rewardData[token].periodFinish
                ).to40();
                if (_account != address(0)) {
                    rewards[_account][token] = _earned(
                        _account,
                        token,
                        _balance,
                        _totalSupply
                    );
                    userRewardPerTokenPaid[_account][token] = rewardData[token]
                        .rewardPerTokenStored;
                }
            }
        }
        _;
    }

    /* ========== EVENTS ========== */
    event RewardAdded(address indexed _token, uint256 _reward);
    event Staked(
        address indexed _user,
        uint256 indexed _epoch,
        uint256 _paidAmount,
        uint256 _lockedAmount
    );
    event Withdrawn(address indexed _user, uint256 _amount, bool _relocked);
    event KickReward(
        address indexed _user,
        address indexed _kicked,
        uint256 _reward
    );
    event RewardPaid(
        address indexed _user,
        address indexed _rewardsToken,
        uint256 _reward
    );
    event Recovered(address _token, uint256 _amount);

    receive() external payable {}

    fallback() external {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {Ownable} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import {ReentrancyGuard} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_ReentrancyGuard.sol";

import {currentEpoch, nextEpoch, WEEK} from "./src_libraries_EpochMath.sol";
import {AbraStaking} from "./src_token_AbraStaking.sol";
import {VoterV4} from "./src_VoterV4.sol";

enum Mode {
    Internal,
    External
}

struct Reward {
    uint256 rewardsPerEpoch;
    uint256 lastUpdateTime;
}

error Bribe_NoVotes(uint32 epoch);

contract Bribe is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    address immutable VE;
    address immutable FACTORY;
    Mode    immutable MODE;
    uint    immutable KIND;

    address public voter;
    uint32  public firstBribeTimestamp;

    address[] public rewardTokens;
    mapping(address => mapping(uint256 => Reward)) public rewardData;  // token -> startTimestamp -> Reward
    mapping(address => bool) public isRewardToken;

    // owner -> reward token -> lastTime
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public userTimestamp;

    //uint256 private _totalSupply;
    mapping(uint256 => uint256) private _totalSupply;
    mapping(address => mapping(uint256 => uint256)) private _balances; //owner -> timestamp -> amount

    event RewardAdded(address indexed rewardToken, uint256 reward, uint256 startTimestamp);
    event Staked(uint256 indexed lockupId, uint256 amount);
    event Withdrawn(uint256 indexed lockupId, uint256 amount);
    event RewardPaid(address indexed user,address indexed rewardsToken,uint256 reward);
    event Recovered(address indexed token, uint256 amount);

    /* ========== CONSTRUCTOR ========== */

    constructor(address _voter, address _owner, Mode _mode, uint _kind) Ownable(_owner) {
        require(_voter != address(0));
        voter = _voter;
        firstBribeTimestamp = 0;
        VE = VoterV4(_voter).ve();
        FACTORY = msg.sender;
        MODE = _mode;
        KIND = _kind;
    }

    /* ========== VIEWS ========== */

    /// @notice get the length of the reward tokens
    function rewardsListLength() external view returns(uint256) {
        return rewardTokens.length;
    }

    /// @notice get the last totalSupply (total votes for a pool)
    function totalSupply() external view returns (uint256) {
        uint256 _currentEpochStart = currentEpoch(); // claim until current epoch
        return _totalSupply[_currentEpochStart];
    }

    /// @notice get a totalSupply given a timestamp
    function totalSupplyAt(uint256 _timestamp) external view returns (uint256) {
        return _totalSupply[_timestamp];
    }

    /// @notice read the balanceOf the tokenId at a given timestamp
    function balanceOfAt(uint256 lockupId, uint256 _timestamp) public view returns (uint256) {
        address _owner = AbraStaking(VE).lockupRefs(lockupId).owner;
        return _balances[_owner][_timestamp];
    }


    /// @notice get last deposit available given a tokenID
    function balanceOf(uint256 lockupId) public view returns (uint256) {
        uint256 _timestamp = nextEpoch();
        address _owner = AbraStaking(VE).lockupRefs(lockupId).owner;
        return _balances[_owner][_timestamp];
    }

    /// @notice get the balance of an owner in the current epoch
    function balanceOfOwner(address _owner) public view returns (uint256) {
        uint256 _timestamp = nextEpoch();
        return _balances[_owner][_timestamp];
    }

    /// @notice get the balance of an owner given a timestamp
    function balanceOfOwnerAt(address _owner, uint256 _timestamp) public view returns (uint256) {
        return _balances[_owner][_timestamp];
    }

    /// @notice Read earned amount given address and reward token, returns the rewards
    function earned(address _owner, address _rewardToken) public view returns(uint256 reward) {
        (reward,) = earned(_owner, _rewardToken, 52);
    }

    /// @notice Read earned amount given address and reward token, returns the rewards and the last user timestamp (used in case user do not claim since 52+epochs)
    function earned(address _owner, address _rewardToken, uint epochs) public view returns(uint256, uint256) {
        uint256 k = 0;
        uint256 reward = 0;
        uint256 _endTimestamp = currentEpoch(); // claim until current epoch
        uint256 _userLastTime = userTimestamp[_owner][_rewardToken];

        // if user first time then set it to first bribe - week to avoid any timestamp problem
        if(_userLastTime < firstBribeTimestamp){
            _userLastTime = firstBribeTimestamp;
        }

        for(k; k < epochs; k++){
            if(_userLastTime == _endTimestamp){
                // if we reach the current epoch, exit
                break;
            }
            reward += _earned(_owner, _rewardToken, _userLastTime);
            _userLastTime += WEEK;
        }

        return (reward, _userLastTime);
    }

    /// @notice get the earned rewards
    function _earned(address _owner, address _rewardToken, uint256 _timestamp) internal view returns (uint256) {
        uint256 _balance = balanceOfOwnerAt(_owner, _timestamp);
        if(_balance == 0){
            return 0;
        } else {
            uint256 _rewardPerToken = rewardPerToken(_rewardToken, _timestamp);
            uint256 _rewards = _rewardPerToken * _balance / 1e18;
            return _rewards;
        }
    }

    /// @notice get the rewards for token
    function rewardPerToken(address _rewardsToken, uint256 _timestamp) public view returns (uint256) {
        if (_totalSupply[_timestamp] == 0) {
            return rewardData[_rewardsToken][_timestamp].rewardsPerEpoch;
        }
        return rewardData[_rewardsToken][_timestamp].rewardsPerEpoch * 1e18 / _totalSupply[_timestamp];
    }


    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice User votes deposit
    /// @dev    called on voter.vote() or voter.poke()
    ///         we save into owner "address" and not "tokenID".
    ///         Owner must reset before transferring token
    function deposit(uint256 amount, uint256 lockupId) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        require(msg.sender == voter);

        address participant = AbraStaking(VE).lockupRefs(lockupId).owner;
        uint256 _startTimestamp = currentEpoch() + WEEK;
        uint256 _oldSupply = _totalSupply[_startTimestamp];
        uint256 _lastBalance = _balances[participant][_startTimestamp];

        _totalSupply[_startTimestamp] =  _oldSupply + amount;
        _balances[participant][_startTimestamp] = _lastBalance + amount;

        emit Staked(lockupId, amount);
    }

    /// @notice User votes withdrawal
    /// @dev    called on voter.reset()
    function withdraw(uint256 amount, uint256 lockupId) external nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        require(msg.sender == voter);
        uint256 _startTimestamp = currentEpoch() + WEEK;
        address participant = AbraStaking(VE).lockupRefs(lockupId).owner;
        //
        // incase of bribe contract reset in gauge proxy
        if (amount <= _balances[participant][_startTimestamp]) {
            uint256 _oldSupply = _totalSupply[_startTimestamp];
            uint256 _oldBalance = _balances[participant][_startTimestamp];
            _totalSupply[_startTimestamp] =  _oldSupply - amount;
            _balances[participant][_startTimestamp] =  _oldBalance - amount;
            emit Withdrawn(lockupId, amount);
        }
    }

    /// @notice Claim the rewards given msg.sender
    function getReward(address[] calldata tokens) external {
        getReward(msg.sender, tokens);
    }

    /// @notice Claim the rewards given msg.sender
    function getReward(address[] calldata tokens, uint epochs) external {
        getReward(msg.sender, tokens, epochs);
    }

    function getReward(address _owner, address[] calldata tokens) public {
        getReward(_owner, tokens, 52);
    }

    /// @notice Claim rewards
    function getReward(address _owner, address[] calldata tokens, uint epochs) public nonReentrant  {
        require(msg.sender == voter || msg.sender == _owner, "nao");
        uint256 _userLastTime;
        uint256 reward = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            address _rewardToken = tokens[i];
            (reward, _userLastTime) = earned(_owner, _rewardToken, epochs);
            userTimestamp[_owner][_rewardToken] = _userLastTime;

            if (reward > 0) {
                IERC20(_rewardToken).safeTransfer(_owner, reward);
                emit RewardPaid(_owner, _rewardToken, reward);
            }
        }
    }

    function canNotifyReward() public view returns (bool) {
        // If no-one voted for this INTERNAL bribe in the previous epoch, then we can't distribute voter's rewards
        // becase they will be lost permanently.
        // Instead, we should carry over these rewards to the next epoch that has votes.
        if (MODE == Mode.Internal && _totalSupply[currentEpoch()] == 0) {
            return false;
        }
        return true;
    }

    /// @notice Notify a bribe amount
    function notifyRewardAmount(address _rewardsToken, uint256 reward) external nonReentrant {
        require(isRewardToken[_rewardsToken], "reward token not verified");
        uint32 _startTimestamp = currentEpoch();
        if (!canNotifyReward()) {
            revert Bribe_NoVotes(_startTimestamp);
        }
        // In the internal bribes mode, all rewards are distributed for the current epoch, while votes are cast for the
        // upcoming epoch. This means that in the internal mode, you won't know the amount of future bribes until the
        // upcoming epoch becomes the current one. In the external mode, bribes are designated for the future epoch, so
        // everyone can see the amount of bribes before voting.
        if (MODE == Mode.External) {
            _startTimestamp += WEEK;
        }

        IERC20(_rewardsToken).safeTransferFrom(msg.sender, address(this), reward);

        if(firstBribeTimestamp == 0){
            firstBribeTimestamp = _startTimestamp;
        }

        uint256 _lastReward = rewardData[_rewardsToken][_startTimestamp].rewardsPerEpoch;

        rewardData[_rewardsToken][_startTimestamp].rewardsPerEpoch = _lastReward + reward;
        rewardData[_rewardsToken][_startTimestamp].lastUpdateTime = block.timestamp;

        emit RewardAdded(_rewardsToken, reward, _startTimestamp);
    }



    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice add rewards tokens
    function addRewardTokens(address[] calldata _rewardsTokens) public onlyAllowed {
        uint256 i = 0;
        for(i; i < _rewardsTokens.length; i++){
           _addRewardToken(_rewardsTokens[i]);
        }
    }

    /// @notice add a single reward token
    function addRewardToken(address _rewardToken) public onlyAllowed {
        _addRewardToken(_rewardToken);
    }

    function _addRewardToken(address _rewardToken) internal {
        if(!isRewardToken[_rewardToken]){
            isRewardToken[_rewardToken] = true;
            rewardTokens.push(_rewardToken);
        }
    }

    /// @notice Recover some ERC20 from the contract and updated given bribe
    function recoverERC20AndUpdateData(address tokenAddress, uint256 tokenAmount) external onlyAllowed {
        require(tokenAmount <= IERC20(tokenAddress).balanceOf(address(this)));
        require(owner() != address(0));

        uint256 _startTimestamp = currentEpoch();
        if (MODE == Mode.External) {
            _startTimestamp += WEEK;
        }
        uint256 _lastReward = rewardData[tokenAddress][_startTimestamp].rewardsPerEpoch;
        rewardData[tokenAddress][_startTimestamp].rewardsPerEpoch = _lastReward - tokenAmount;
        rewardData[tokenAddress][_startTimestamp].lastUpdateTime = block.timestamp;


        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /// @notice Recover some ERC20 from the contract.
    /// @dev    Be careful --> if called then getReward() at last epoch will fail because some reward are missing!
    ///         Think about calling recoverERC20AndUpdateData()
    function emergencyRecoverERC20(address tokenAddress, uint256 tokenAmount) external onlyAllowed {
        require(tokenAmount <= IERC20(tokenAddress).balanceOf(address(this)));
        require(owner() != address(0));

        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    /// @notice Set a new voter
    function setVoter(address _Voter) external onlyAllowed {
        require(_Voter != address(0));
        voter = _Voter;
    }

    /* ========== MODIFIERS ========== */

    modifier onlyAllowed() {
        require(msg.sender == owner() || msg.sender == FACTORY, "permission is denied!");
        _;
    }

    /* ========== VIEW FUNCTIONS FOR CONSTANTS  ========== */

    function ve() external view returns(address) {
        return VE;
    }
    function factory() external view returns(address) {
        return FACTORY;
    }
    function mode() external view returns(Mode) {
        return MODE;
    }
    function kind() external view returns(uint) {
        return KIND;
    }
}
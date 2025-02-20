// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {ERC20Upgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import {AccessManagedUpgradeable} from "./openzeppelin_contracts-upgradeable_access_manager_AccessManagedUpgradeable.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {UUPSUpgradeable} from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";

import {IGauge} from "./src_interfaces_IGauge.sol";
import {IWrapper} from "./src_interfaces_IWrapper.sol";
import {ISwapProvider} from "./src_interfaces_ISwapProvider.sol";
import {nextEpoch} from "./src_libraries_EpochMath.sol";

abstract contract BaseGauge is
    IGauge,
    ERC20Upgradeable,
    AccessManagedUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /// @dev A time period for continuity of rewards between epoch changes.
    /// Since distribution for each epoch can happen with a delay, we distribute rewards for
    /// EPOCH + REWARD_OVERLAP_WINDOW duration
    uint256 internal immutable REWARD_OVERLAP_WINDOW;
    address internal immutable UNDERLYING;
    address internal immutable ABRA;

    /// @custom:storage-location erc7201:io.cadabra.storage.BaseGauge
    struct BaseGaugeStorage {
        uint32  rewardPeriodFinish;
        uint32  rewardLastUpdateTime;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
        mapping(address => uint256) userRewardPerTokenPaid;
        mapping(address => uint256) rewards;
    }

    // keccak256(abi.encode(uint256(keccak256("io.cadabra.storage.BaseGauge")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant BASE_GAUGE_STORAGE_LOCATION =
        0x40eb12872a2a3a645111a5e6ff241bef90ea514a0416c22055742263afd4ed00;

    function _getBaseGaugeStorage() private pure returns (BaseGaugeStorage storage $) {
        assembly {
            $.slot := BASE_GAUGE_STORAGE_LOCATION
        }
    }

    constructor(address _abra, address _underlying, uint _rewardOverlapWindow) {
        ABRA = _abra;
        UNDERLYING = _underlying;
        REWARD_OVERLAP_WINDOW = _rewardOverlapWindow;
        _disableInitializers();
    }

    function __BaseGauge_init(string memory name_, string memory symbol_, address authority_)
        internal
        onlyInitializing
    {
        __ERC20_init(name_, symbol_);
        __AccessManaged_init(authority_);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    // @dev intentionally using `restricted` for internal function
    function _authorizeUpgrade(address) internal override restricted {
    }

    function underlying() external view returns (address) {
        return UNDERLYING;
    }

    function abra() external view returns (address) {
        return ABRA;
    }

    function rewardOverlapWindow() external view returns (uint256) {
        return REWARD_OVERLAP_WINDOW;
    }

    function yieldSources() external view virtual returns (address[] memory sources);

    //╔═══════════════════════════════════════════ GAUGE FUNCTIONS ═══════════════════════════════════════════╗

    ///@notice last time reward
    function lastTimeRewardApplicable() public view returns (uint256) {
        BaseGaugeStorage storage $ = _getBaseGaugeStorage();
        return block.timestamp < $.rewardPeriodFinish ? block.timestamp : $.rewardPeriodFinish;
    }

    ///@notice  reward for a single token
    function rewardPerToken() public view returns (uint256 _rewardPerToken) {
        BaseGaugeStorage storage $ = _getBaseGaugeStorage();
        _rewardPerToken = $.rewardPerTokenStored;
        uint256 _lastTimeRewardApplicable = lastTimeRewardApplicable();
        uint256 _totalSupply = totalSupply();
        if (_totalSupply != 0) {
            _rewardPerToken += (_lastTimeRewardApplicable - $.rewardLastUpdateTime) * $.rewardRate * 1e18 / _totalSupply;
        }
    }

    ///@notice see earned rewards for user
    function earned(address account) public view returns (uint256) {
        BaseGaugeStorage storage $ = _getBaseGaugeStorage();
        return $.rewards[account] + balanceOf(account) * (rewardPerToken() - $.userRewardPerTokenPaid[account]) / 1e18;
    }


    ///@notice deposit amount TOKEN
    function deposit(uint256 amount) external {
        _deposit(amount, msg.sender);
    }

    ///@notice deposit internal
    function _deposit(uint256 amount, address account) internal nonReentrant {
        require(amount > 0, "deposit(Gauge): cannot stake 0");

        _mint(account, amount); // todo transfer underlying first

        IERC20(UNDERLYING).safeTransferFrom(account, address(this), amount);

        emit Deposit(account, amount);
    }

    ///@notice withdraw a certain amount of TOKEN
    function withdraw(uint256 amount) override external {
        _withdraw(amount);
    }

    ///@notice withdraw internal
    function _withdraw(uint256 amount) internal nonReentrant {
        require(amount > 0, "Cannot withdraw 0");

        _burn(msg.sender, amount);

        IERC20(UNDERLYING).safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    ///@notice User harvest function
    function getReward() external returns (uint reward) {
        reward = _getReward(msg.sender);
        if (reward > 0) {
            IERC20(ABRA).safeTransfer(msg.sender, reward);
        }
    }

    function _getReward(address account) internal returns (uint reward){
        BaseGaugeStorage storage $ = _getBaseGaugeStorage();
        reward = earned(account);
        if (reward > 0) {
            updateRewardPerTokenStored();
            $.userRewardPerTokenPaid[account] = $.rewardPerTokenStored;
            $.rewards[account] = 0;
            emit Harvest(account, reward);
        }
    }


    function updateRewardPerTokenStored() private {
        BaseGaugeStorage storage $ = _getBaseGaugeStorage();
        uint256 _lastTimeRewardApplicable = lastTimeRewardApplicable();
        $.rewardPerTokenStored = rewardPerToken();
        $.rewardLastUpdateTime = uint32(_lastTimeRewardApplicable);
    }

    function updateReward(address account) private {
        BaseGaugeStorage storage $ = _getBaseGaugeStorage();
        // always must be called only after updateRewardPerTokenStored
        if (account != address(0)) {
            uint256 _earned = earned(account);
            $.rewards[account] = _earned;
            $.userRewardPerTokenPaid[account] = $.rewardPerTokenStored;
        }
    }

    function _update(address from, address to, uint256 value) internal virtual override {
        updateRewardPerTokenStored();
        updateReward(from);
        updateReward(to);
        super._update(from, to, value);
    }

    function notifyRewardAmount(uint amount) override external restricted {
        IERC20(ABRA).safeTransferFrom(msg.sender, address(this), amount);
        _allocateReward(amount);
    }

    function _allocateReward(uint reward) private {
        BaseGaugeStorage storage $ = _getBaseGaugeStorage();
        uint DISTRIBUTION_DURATION = nextEpoch() - block.timestamp + REWARD_OVERLAP_WINDOW;
        updateRewardPerTokenStored();
        uint256 _rewardPeriodFinish = $.rewardPeriodFinish;
        if (block.timestamp >= _rewardPeriodFinish) {
            $.rewardRate = reward / DISTRIBUTION_DURATION;
        } else {
            uint256 remaining = _rewardPeriodFinish - block.timestamp;
            uint256 leftover = remaining * $.rewardRate;
            $.rewardRate = (reward + leftover) / DISTRIBUTION_DURATION;
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IERC20(ABRA).balanceOf(address(this));
        require($.rewardRate <= balance / DISTRIBUTION_DURATION, "Provided reward too high");

        $.rewardLastUpdateTime = uint32(block.timestamp);
        $.rewardPeriodFinish = uint32(block.timestamp + DISTRIBUTION_DURATION);
        emit RewardsAllocated(reward, block.timestamp + DISTRIBUTION_DURATION);
    }

}
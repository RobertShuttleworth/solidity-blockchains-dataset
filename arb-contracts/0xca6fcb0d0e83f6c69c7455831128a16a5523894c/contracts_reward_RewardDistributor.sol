// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";

import "./contracts_interfaces_IRewardController.sol";

contract RewardDistributor is ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 constant ONE = 1e18;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    address public referenceToken;
    address rewardToken;
    uint256 lastRewardBalance;
    uint256 cumulativeRewardPerToken;
    mapping(address => uint256) claimableReward;
    mapping(address => uint256) previousCumulatedRewardPerToken;
    mapping(address => bool) public isHandler;
    mapping(address => uint256) lastClaimTime;

    event Claim(address receiver, uint256 amount);
    event Migrate(
        address from,
        address to,
        uint256 claimableReward,
        uint256 previousCumulatedRewardPerToken,
        uint256 lastClaimTime
    );

    modifier onlyHandler() {
        require(isHandler[msg.sender], "RewardDistributor::HANDLER");
        _;
    }

    // deposit mlp
    function initialize(
        string memory name_,
        string memory symbol_,
        address rewardToken_,
        address referenceToken_
    ) external initializer {
        __Ownable_init();

        name = name_;
        symbol = symbol_;
        rewardToken = rewardToken_;
        referenceToken = referenceToken_;
    }

    function setHandler(address handler_, bool enable_) external onlyOwner {
        isHandler[handler_] = enable_;
    }

    function balanceOf(address account) public view returns (uint256) {
        return IERC20Upgradeable(referenceToken).balanceOf(account);
    }

    function totalSupply() public view returns (uint256) {
        return IERC20Upgradeable(referenceToken).totalSupply();
    }

    function updateRewards(address account) external nonReentrant {
        _updateRewards(account);
    }

    // Claim rewards for senior/junior. Should call RouterV1.updateRewards() first to collected all rewards.
    function claim(address _receiver) external nonReentrant returns (uint256) {
        require(lastClaimTime[_receiver] != block.timestamp, "RewardDistributor::ALREADY_CLAIMED");
        return _claim(msg.sender, _receiver);
    }

    function claimFor(
        address account,
        address _receiver
    ) external onlyHandler nonReentrant returns (uint256) {
        return _claim(account, _receiver);
    }

    function _claim(address account, address receiver) private returns (uint256) {
        _updateRewards(account);
        uint256 tokenAmount = claimableReward[account];
        claimableReward[account] = 0;
        if (tokenAmount > 0) {
            lastClaimTime[account] = block.timestamp;
            lastRewardBalance -= tokenAmount;
            IERC20Upgradeable(rewardToken).safeTransfer(receiver, tokenAmount);
            emit Claim(account, tokenAmount);
        }
        return tokenAmount;
    }

    // Get claimable rewards for senior/junior. Should call RouterV1.updateRewards() first to collected all rewards.
    function claimable(address account) public returns (uint256) {
        _updateRewards(account);
        uint256 balance = balanceOf(account);
        if (balance == 0) {
            return claimableReward[account];
        }
        return
            claimableReward[account] +
            ((balance * (cumulativeRewardPerToken - previousCumulatedRewardPerToken[account])) /
                ONE);
    }

    function migrate(address from, address to) external onlyHandler nonReentrant {
        require(to != address(0), "RewardDistributor::INVALID_ACCOUNT");
        require(from != to, "RewardDistributor::SAME_ACCOUNT");

        _updateRewards(to);
        require(
            claimableReward[to] == 0 && balanceOf(to) == 0,
            "RewardDistributor::RECEIVER_NOT_EMPTY"
        );

        claimableReward[to] = claimableReward[from];
        previousCumulatedRewardPerToken[to] = previousCumulatedRewardPerToken[from];
        lastClaimTime[to] = lastClaimTime[from];

        emit Migrate(
            from,
            to,
            claimableReward[from],
            previousCumulatedRewardPerToken[from],
            lastClaimTime[from]
        );

        claimableReward[from] = 0;
        previousCumulatedRewardPerToken[from] = 0;
        lastClaimTime[from] = 0;
    }

    // account can be 0
    function _updateRewards(address account) private {
        // update new rewards
        uint256 balance = IERC20Upgradeable(rewardToken).balanceOf(address(this));
        uint256 reward = balance - lastRewardBalance;
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        lastRewardBalance = balance;

        uint256 supply = totalSupply();
        if (supply > 0 && reward > 0) {
            _cumulativeRewardPerToken = _cumulativeRewardPerToken + ((reward * ONE) / supply);
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }
        if (_cumulativeRewardPerToken == 0) {
            return;
        }
        if (account != address(0)) {
            uint256 accountReward = (balanceOf(account) *
                (_cumulativeRewardPerToken - previousCumulatedRewardPerToken[account])) / ONE;
            uint256 rewards = claimableReward[account] + accountReward;
            claimableReward[account] = rewards;
            previousCumulatedRewardPerToken[account] = _cumulativeRewardPerToken;
        }
    }

    function allowance(address, address) external pure returns (uint256) {
        return 0;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./openzeppelin_contracts-upgradeable_access_AccessControlEnumerableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";

import "./contracts_staking_CAVStakingSignature.sol";

import "./contracts_interfaces_ICoinAvatarCore.sol";
import "./contracts_interfaces_IERC721.sol";

import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";

contract CAVStaking is
    AccessControlEnumerableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    CAVStakingSignature,
    UUPSUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public rewardBalance; // Balance for rewards
    uint256 public rewardRate; // Reward to be paid out per second
    uint256 public totalCoins; // Total coins amount
    uint256 public totalTokenQuantity; // Total staking token quantity
    uint32 public duration; // Duration of rewards to be paid out (in seconds)
    uint32 public finishAt; // Timestamp of when the rewards finish
    IERC20Upgradeable public rewardToken; // Reward token address
    IERC20Upgradeable public stakingToken; // Staking token address
    IERC721 public coinToken721; // Coin ERC721 token address
    ICoinAvatarCore public launchpad; // CoinAvatarCore address

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    struct TokenInfo {
        uint256 quantity;
        uint32 term;
        uint8 termLvl;
        uint8 fusionLvl;
        uint32 lastRewardTime;
    }

    mapping(uint256 => TokenInfo) public tokenInfo; // tokenId => TokenInfo
    EnumerableSet.UintSet private stakedTokenIds;

    mapping(address => uint256) public userNonce;

    modifier onlyOwner() {
        require(hasRole(OWNER_ROLE, msg.sender), "Caller is not an owner.");
        _;
    }

    event Deposited(
        address user,
        uint256 tokenId,
        uint256 amount,
        uint256 term
    );
    event Withdrawn(address user, uint256 tokenId, uint256 amount);
    event AddedBalance(address ownerAddress, uint256 amount, uint32 time);
    event GetReward(address user, uint256 tokenId, uint256 rewardAmount);

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(OWNER_ROLE) {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address rewardTokenAddress,
        address stakingTokenAddress,
        address coinAddress,
        address launchpadAddress,
        uint32 durationInSec,
        string memory _name,
        string memory _version
    ) public initializer {
        __Signature_init(_name, _version);
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        coinToken721 = IERC721(coinAddress);
        rewardToken = IERC20Upgradeable(rewardTokenAddress);
        stakingToken = IERC20Upgradeable(stakingTokenAddress);
        launchpad = ICoinAvatarCore(launchpadAddress);
        duration = durationInSec;
        _setupRole(OWNER_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(OWNER_ROLE, OWNER_ROLE);
        _setRoleAdmin(DEFAULT_ADMIN_ROLE, OWNER_ROLE);
        _setupRole(OWNER_ROLE, launchpadAddress);
        _setupRole(SIGNER_ROLE, msg.sender);
    }

    function withdrawReward(uint256 tokenId) public nonReentrant {
        require(
            msg.sender == coinToken721.ownerOf(tokenId),
            "msg.sender != owner of token"
        );

        uint256 reward = pendingReward(tokenId);
        if (reward > 0) {
            require(
                rewardBalance >= reward,
                "Not enough balance on the contract."
            );
            uint32 term = tokenInfo[tokenId].term;

            tokenInfo[tokenId].lastRewardTime = term < uint32(block.timestamp)
                ? term
                : uint32(block.timestamp);

            rewardBalance -= reward;

            rewardToken.safeTransfer(msg.sender, reward);
            emit GetReward(msg.sender, tokenId, reward);
        }
    }

    function deposit(
        uint256 tokenId,
        uint32 term,
        address tokenFee,
        uint256 feeAmount,
        uint256 nonce,
        Signature calldata signature
    ) external nonReentrant whenNotPaused {
        require(
            hasRole(
                SIGNER_ROLE,
                _getDepositHash(
                    msg.sender,
                    tokenFee,
                    term,
                    nonce,
                    tokenId,
                    feeAmount,
                    signature.v,
                    signature.r,
                    signature.s
                )
            ),
            "Action is inconsistent."
        );
        require(userNonce[msg.sender] < nonce, "Wrong nonce.");
        userNonce[msg.sender] = nonce;

        require(
            msg.sender == coinToken721.ownerOf(tokenId),
            "Sender != owner of coin."
        );
        require(tokenInfo[tokenId].quantity == 0, "This token already staked.");

        ICoinAvatarCore.TokenData memory token = launchpad.getFreezingBalance(
            tokenId
        );
        require(
            token.tokenAddress == address(stakingToken),
            "Token != staking token."
        );

        if (token.notFrstTimeStaked) {
            launchpad.receiveFeeFromStakingContract(
                msg.sender,
                tokenFee,
                feeAmount
            );
        }

        (uint8 fusionLvl, uint8 termLvl) = parseLvl(
            term,
            token.fusion,
            uint32(block.timestamp)
        );

        tokenInfo[tokenId] = TokenInfo(
            token.balance,
            term,
            termLvl,
            fusionLvl,
            uint32(block.timestamp)
        );

        totalCoins += 1;
        totalTokenQuantity += token.balance;
        stakedTokenIds.add(tokenId);

        launchpad.setSingleStakingAction(tokenId, true);
        emit Deposited(msg.sender, tokenId, token.balance, term);
    }

    function withdraw(uint256 tokenId) external whenNotPaused {
        TokenInfo memory stakedToken = tokenInfo[tokenId];
        ICoinAvatarCore.TokenData memory token = launchpad.getFreezingBalance(
            tokenId
        );
        require(
            stakedToken.term < uint32(block.timestamp),
            "Your term > then time now"
        );
        withdrawReward(tokenId);
        delete tokenInfo[tokenId];
        stakedTokenIds.remove(tokenId);

        totalCoins -= 1;
        totalTokenQuantity -= token.balance;

        launchpad.setSingleStakingAction(tokenId, false);

        emit Withdrawn(msg.sender, tokenId, token.balance);
    }

    function addBalance(uint256 amount) external onlyOwner nonReentrant {
        if (uint32(block.timestamp) >= finishAt) {
            rewardRate = amount / duration;
            finishAt = uint32(block.timestamp + duration);
        } else {
            uint256 remainingRewards = (finishAt - uint32(block.timestamp)) *
                rewardRate;
            rewardRate = (amount + remainingRewards) / duration;
        }
        require(rewardRate > 0, "reward rate = 0");

        rewardBalance += amount;

        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        require(
            rewardRate * duration <= rewardToken.balanceOf(address(this)),
            "reward amount > balance"
        );
        emit AddedBalance(msg.sender, amount, uint32(block.timestamp));
    }

    function setPause(bool pause) external onlyOwner {
        if (pause) {
            _pause();
        } else {
            _unpause();
        }
    }

    function setRewardsDuration(uint32 newDuration) external onlyOwner {
        require(
            finishAt < uint32(block.timestamp),
            "Reward duration not finished."
        );
        duration = newDuration;
    }

    function setNewCoinAvatarCore(
        address newCoinAvatarCore
    ) external onlyOwner {
        launchpad = ICoinAvatarCore(newCoinAvatarCore);
    }

    function setNewCoin(address newCoin) external onlyOwner {
        coinToken721 = IERC721(newCoin);
    }

    function setNewRewardToken(address newRewardToken) external onlyOwner {
        rewardToken = IERC20Upgradeable(newRewardToken);
    }

    function setNewStakingToken(address newStakingToken) external onlyOwner {
        stakingToken = IERC20Upgradeable(newStakingToken);
    }

    function _calculatePercentage(
        uint16 percentage
    ) internal view returns (uint256) {
        return (rewardRate * percentage) / 100000;
    }

    function calcRewardWithDistr(
        uint256 distributionLvl
    ) internal view returns (uint256) {
        if (distributionLvl == 0) return 0;
        uint256 timeRewardPercentage = _calculatePercentage(uint16(25000));
        uint256 accPerCoin = uint256((1 * uint256(10 ** 18)) / totalCoins);
        uint256 rewardPercentage = (accPerCoin *
            (distributionLvl * uint256(10 ** 17))) / (51 * uint256(10 ** 17));
        return
            uint256(
                (timeRewardPercentage * rewardPercentage) / uint256(10 ** 18)
            );
    }

    function pendingReward(uint256 tokenId) public view returns (uint256) {
        TokenInfo memory token = tokenInfo[tokenId];
        if (token.quantity == 0) return 0;
        uint256 fusionReward = calcRewardWithDistr(token.fusionLvl);
        uint256 termReward = calcRewardWithDistr(token.termLvl);
        uint256 blockRewardPercentage = _calculatePercentage(uint16(50000));
        uint256 quantityRewardPercentage = (token.quantity *
            uint256(10 ** 18)) / totalTokenQuantity;
        uint256 quantityReward = uint256(
            (blockRewardPercentage * quantityRewardPercentage) /
                uint256(10 ** 18)
        );

        uint256 multiplier;

        if (token.term < uint32(block.timestamp)) {
            multiplier = uint32(token.term - token.lastRewardTime);
        } else {
            multiplier = uint32(block.timestamp - token.lastRewardTime);
        }

        return multiplier * (fusionReward + termReward + quantityReward);
    }

    function getRewardBalance() external view returns (uint256) {
        return rewardBalance;
    }

    function parseLvl(
        uint256 term,
        uint256 fusion,
        uint32 blockTime
    ) internal pure returns (uint8, uint8) {
        uint8 fusionLvl;
        uint8 termLvl;

        if (fusion <= 4) fusionLvl = 0;
        else if (fusion >= 5 && fusion <= 9) fusionLvl = 5;
        else if (fusion >= 10 && fusion <= 14) fusionLvl = 10;
        else if (fusion >= 15 && fusion <= 19) fusionLvl = 15;
        else if (fusion >= 20 && fusion <= 24) fusionLvl = 20;
        else if (fusion >= 25 && fusion <= 29) fusionLvl = 25;
        else if (fusion >= 30) fusionLvl = 30;

        if (term <= blockTime + 31 days) termLvl = 1;
        else if (term > blockTime + 31 days && term <= blockTime + 93 days)
            termLvl = 3;
        else if (term > blockTime + 93 days && term <= blockTime + 186 days)
            termLvl = 6;
        else if (term > blockTime + 186 days && term <= blockTime + 279 days)
            termLvl = 9;
        else if (term > blockTime + 279 days && term <= blockTime + 372 days)
            termLvl = 12;
        else if (term > blockTime + 279 days && term <= blockTime + 744 days)
            termLvl = 24;
        else revert("Wrong term.");

        return (fusionLvl, termLvl);
    }

    function getStakedTokens() external view returns (uint256[] memory) {
        return stakedTokenIds.values();
    }

    uint256[99] __gap;
}
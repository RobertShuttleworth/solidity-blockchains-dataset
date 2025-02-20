// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_TaskMarketplace.sol";

contract TaskBot is 
    Initializable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable 
{
    TaskMarketplace public marketplace;
    uint256 public minReward;
    uint256 public maxConcurrentTasks;
    uint256 public currentTasks;
    uint256 public constant MAX_GAS_PRICE = 500 gwei;
    uint256 public constant MIN_EXECUTION_TIME = 30 seconds;
    
    mapping(uint256 => bool) public activeTasks;
    mapping(uint256 => uint256) public taskStartTimes;
    mapping(address => bool) public authorizedOperators;
    
    uint256 public constant MAX_BATCH_SIZE = 50;
    mapping(uint256 => uint256[]) public taskBatches;
    uint256 public currentBatchId;
    
    event TaskAccepted(uint256 indexed taskId);
    event TaskProcessed(uint256 indexed taskId, bool success);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event EmergencyWithdrawal(address indexed token, uint256 amount);
    
    modifier onlyOperator() {
        require(authorizedOperators[msg.sender] || owner() == msg.sender, "Not authorized");
        _;
    }
    
    modifier withinGasLimit() {
        require(tx.gasprice <= MAX_GAS_PRICE, "Gas price too high");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        address _marketplace,
        uint256 _minReward,
        uint256 _maxConcurrentTasks,
        address initialOwner
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        
        _transferOwnership(initialOwner);
        marketplace = TaskMarketplace(_marketplace);
        minReward = _minReward;
        maxConcurrentTasks = _maxConcurrentTasks;
        authorizedOperators[initialOwner] = true;
    }
    
    function addOperator(address operator) external onlyOwner {
        require(operator != address(0), "Invalid operator");
        authorizedOperators[operator] = true;
        emit OperatorAdded(operator);
    }
    
    function removeOperator(address operator) external onlyOwner {
        require(operator != owner(), "Cannot remove owner");
        authorizedOperators[operator] = false;
        emit OperatorRemoved(operator);
    }
    
    function registerWithMarketplace() external onlyOwner {
        marketplace.registerBot();
    }
    
    function evaluateAndClaimTask(
        uint256 taskId
    ) external onlyOperator whenNotPaused nonReentrant withinGasLimit {
        require(currentTasks < maxConcurrentTasks, "Max tasks reached");
        
        TaskMarketplace.Task memory task = marketplace.getTask(taskId);
        require(task.exists, "Task does not exist");
        require(task.reward >= minReward, "Reward too low");
        
        marketplace.claimTask(taskId);
        activeTasks[taskId] = true;
        taskStartTimes[taskId] = block.timestamp;
        currentTasks++;
        
        emit TaskAccepted(taskId);
    }
    
    function completeTask(
        uint256 taskId
    ) external onlyOperator whenNotPaused nonReentrant withinGasLimit {
        require(activeTasks[taskId], "Task not active");
        require(
            block.timestamp >= taskStartTimes[taskId] + MIN_EXECUTION_TIME,
            "Minimum execution time not met"
        );
        
        marketplace.completeTask(taskId);
        activeTasks[taskId] = false;
        currentTasks--;
        
        emit TaskProcessed(taskId, true);
    }
    
    function evaluateAndClaimBatch(
        uint256[] calldata taskIds
    ) external onlyOperator whenNotPaused nonReentrant withinGasLimit {
        require(taskIds.length <= MAX_BATCH_SIZE, "Batch too large");
        require(currentTasks + taskIds.length <= maxConcurrentTasks, "Would exceed max tasks");
        
        uint256[] memory acceptedTasks = new uint256[](taskIds.length);
        uint256 acceptedCount = 0;
        
        for (uint256 i = 0; i < taskIds.length; i++) {
            TaskMarketplace.Task memory task = marketplace.getTask(taskIds[i]);
            if (task.exists && task.reward >= minReward) {
                try marketplace.claimTask(taskIds[i]) {
                    activeTasks[taskIds[i]] = true;
                    taskStartTimes[taskIds[i]] = block.timestamp;
                    acceptedTasks[acceptedCount] = taskIds[i];
                    acceptedCount++;
                    emit TaskAccepted(taskIds[i]);
                } catch {
                    continue;
                }
            }
        }
        
        if (acceptedCount > 0) {
            currentBatchId++;
            taskBatches[currentBatchId] = new uint256[](acceptedCount);
            for (uint256 i = 0; i < acceptedCount; i++) {
                taskBatches[currentBatchId][i] = acceptedTasks[i];
            }
            currentTasks += acceptedCount;
        }
    }

    function completeBatch(
        uint256 batchId
    ) external onlyOperator whenNotPaused nonReentrant withinGasLimit {
        uint256[] memory tasks = taskBatches[batchId];
        require(tasks.length > 0, "Invalid batch");
        
        for (uint256 i = 0; i < tasks.length; i++) {
            uint256 taskId = tasks[i];
            if (activeTasks[taskId] && 
                block.timestamp >= taskStartTimes[taskId] + MIN_EXECUTION_TIME) {
                try marketplace.completeTask(taskId) {
                    activeTasks[taskId] = false;
                    currentTasks--;
                    emit TaskProcessed(taskId, true);
                } catch {
                    continue;
                }
            }
        }
        
        delete taskBatches[batchId];
    }
    
    function emergencyPause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function updateSettings(
        uint256 _minReward,
        uint256 _maxConcurrentTasks
    ) external onlyOwner {
        require(_maxConcurrentTasks > 0, "Invalid max tasks");
        minReward = _minReward;
        maxConcurrentTasks = _maxConcurrentTasks;
    }
    
    function emergencyWithdraw(
        address token,
        uint256 amount
    ) external onlyOwner whenPaused nonReentrant {
        require(token != address(0), "Invalid token");
        require(IERC20(token).transfer(owner(), amount), "Transfer failed");
        emit EmergencyWithdrawal(token, amount);
    }
}
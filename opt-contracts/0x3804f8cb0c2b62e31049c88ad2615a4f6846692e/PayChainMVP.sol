/**
 *Submitted for verification at optimistic.etherscan.io on 2024-12-16
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title PayChainMVP
 * @notice Manages employee salaries and expenses using stablecoins
 * @dev Implementation handles both salary disbursement and expense management
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract PayChainMVP {
    // State Variables
    IERC20 public immutable stablecoin;
    address public cfo;
    uint8 private immutable tokenDecimals;
    
    // Constants
    uint256 public constant MAX_CLAIMABLE_MONTHS = 3;
    uint256 public constant EXPENSE_VALIDITY_PERIOD = 90 days;
    uint256 public constant MAX_DESCRIPTION_LENGTH = 200;
    uint256 public constant MINIMUM_AMOUNT = 1e6; // $1 with 6 decimals
    
    struct Employee {
        bool isActive;
        uint256 monthlySalary;
        uint256 lastClaimDate;
        uint256 startDate;
        uint256 terminationDate;
        string name;        // Changed from hash to direct storage for MVP simplicity
        string department;  // Changed from hash to direct storage for MVP simplicity
    }
    
    struct Expense {
        uint256 amount;
        string description;
        ExpenseStatus status;
        uint256 submissionDate;
        string rejectionReason;
        uint256 processedDate;
        bool isRevoked;
    }
    
    enum ExpenseStatus { PENDING, APPROVED, REJECTED, CLAIMED }
    enum PauseType { NONE, PARTIAL, FULL }
    
    // Storage
    mapping(address => Employee) public employees;
    mapping(address => mapping(uint256 => Expense)) public expenses;
    mapping(address => uint256) public expenseCount;
    mapping(address => uint256) public lastActionBlock;
    
    // Emergency controls
    PauseType public currentPauseType;
    address public pendingCfo;
    uint256 public cfoTransferTime;
    
    // Events
    event EmployeeAdded(
        address indexed employee, 
        string name, 
        uint256 salary, 
        uint256 startDate
    );
    
    event EmployeeTerminated(
        address indexed employee, 
        uint256 terminationDate, 
        uint256 finalPayout
    );
    
    event SalaryClaimed(
        address indexed employee, 
        uint256 amount, 
        uint256 periodStart, 
        uint256 periodEnd
    );
    
    event ExpenseSubmitted(
        address indexed employee, 
        uint256 indexed expenseId, 
        uint256 amount,
        string description
    );
    
    event ExpenseStatusUpdated(
        address indexed employee,
        uint256 indexed expenseId,
        ExpenseStatus status,
        string reason
    );
    
    event ExpenseRevoked(
        address indexed employee,
        uint256 indexed expenseId,
        uint256 timestamp
    );
    
    event CFOTransferInitiated(
        address indexed currentCfo,
        address indexed pendingCfo,
        uint256 effectiveTime
    );
    
    // Modifiers
    modifier onlyCFO() {
        require(msg.sender == cfo, "Not CFO");
        _;
    }
    
    modifier onlyEmployee() {
        require(employees[msg.sender].isActive, "Not active employee");
        _;
    }
    
    modifier notInSameBlock(address account) {
        require(lastActionBlock[account] < block.number, "Action in same block");
        _;
        lastActionBlock[account] = block.number;
    }
    
    modifier whenNotPaused(PauseType requiredType) {
        require(
            currentPauseType == PauseType.NONE || 
            (currentPauseType == PauseType.PARTIAL && requiredType == PauseType.PARTIAL),
            "Operation paused"
        );
        _;
    }
    
    /**
     * @notice Contract constructor
     * @param _stablecoin Address of the stablecoin contract
     */
    constructor(address _stablecoin) {
        require(_stablecoin != address(0), "Invalid token");
        stablecoin = IERC20(_stablecoin);
        tokenDecimals = IERC20(_stablecoin).decimals();
        cfo = msg.sender;
    }
    
    /**
     * @notice Initiates CFO role transfer
     * @param _newCfo Address of the new CFO
     */
    function initiateCFOTransfer(address _newCfo) external onlyCFO {
        require(_newCfo != address(0), "Invalid address");
        pendingCfo = _newCfo;
        cfoTransferTime = block.timestamp + 2 days;
        emit CFOTransferInitiated(cfo, _newCfo, cfoTransferTime);
    }
    
    /**
     * @notice Completes CFO role transfer
     */
    function completeCFOTransfer() external {
        require(msg.sender == pendingCfo, "Not pending CFO");
        require(block.timestamp >= cfoTransferTime, "Transfer not ready");
        cfo = pendingCfo;
        pendingCfo = address(0);
        cfoTransferTime = 0;
    }
    
    /**
     * @notice Adds a new employee
     * @param _employee Employee wallet address
     * @param _name Employee name
     * @param _department Employee department
     * @param _monthlySalary Monthly salary amount
     * @param _startDate Employment start date
     */
    function addEmployee(
        address _employee,
        string calldata _name,
        string calldata _department,
        uint256 _monthlySalary,
        uint256 _startDate
    ) external onlyCFO whenNotPaused(PauseType.FULL) {
        require(!employees[_employee].isActive, "Employee exists");
        require(_monthlySalary >= MINIMUM_AMOUNT, "Salary too low");
        require(_startDate <= block.timestamp, "Invalid start date");
        require(bytes(_name).length > 0, "Empty name");
        require(bytes(_department).length > 0, "Empty department");
        
        employees[_employee] = Employee({
            isActive: true,
            monthlySalary: _monthlySalary,
            lastClaimDate: _startDate,
            startDate: _startDate,
            terminationDate: 0,
            name: _name,
            department: _department
        });
        
        emit EmployeeAdded(_employee, _name, _monthlySalary, _startDate);
    }
    
    /**
     * @notice Terminates an employee
     * @param _employee Employee address
     * @param _terminationDate Date of termination
     */
    function terminateEmployee(
        address _employee,
        uint256 _terminationDate
    ) external onlyCFO whenNotPaused(PauseType.FULL) {
        Employee storage emp = employees[_employee];
        require(emp.isActive, "Not active employee");
        require(_terminationDate >= emp.startDate && _terminationDate <= block.timestamp, "Invalid date");
        
        // Calculate final payout
        uint256 finalPayout = calculateFinalPayout(_employee, _terminationDate);
        emp.isActive = false;
        emp.terminationDate = _terminationDate;
        
        if (finalPayout > 0) {
            require(stablecoin.transfer(_employee, finalPayout), "Transfer failed");
        }
        
        emit EmployeeTerminated(_employee, _terminationDate, finalPayout);
    }
    
    /**
     * @notice Submits an expense for approval
     * @param _amount Expense amount
     * @param _description Expense description
     */
    function submitExpense(
        uint256 _amount,
        string calldata _description
    ) external onlyEmployee whenNotPaused(PauseType.PARTIAL) notInSameBlock(msg.sender) {
        require(_amount >= MINIMUM_AMOUNT, "Amount too small");
        require(bytes(_description).length <= MAX_DESCRIPTION_LENGTH, "Description too long");
        require(bytes(_description).length > 0, "Empty description");
        
        uint256 expenseId = expenseCount[msg.sender]++;
        
        expenses[msg.sender][expenseId] = Expense({
            amount: _amount,
            description: _description,
            status: ExpenseStatus.PENDING,
            submissionDate: block.timestamp,
            rejectionReason: "",
            processedDate: 0,
            isRevoked: false
        });
        
        emit ExpenseSubmitted(msg.sender, expenseId, _amount, _description);
    }
    
    /**
     * @notice Revokes a pending expense
     * @param _expenseId ID of the expense to revoke
     */
    function revokeExpense(
        uint256 _expenseId
    ) external onlyEmployee whenNotPaused(PauseType.PARTIAL) {
        Expense storage expense = expenses[msg.sender][_expenseId];
        require(expense.status == ExpenseStatus.PENDING, "Not pending");
        require(!expense.isRevoked, "Already revoked");
        
        expense.isRevoked = true;
        emit ExpenseRevoked(msg.sender, _expenseId, block.timestamp);
    }
    
    /**
     * @notice Processes an expense (approve or reject)
     * @param _employee Employee address
     * @param _expenseId Expense ID
     * @param _approve Whether to approve or reject
     * @param _reason Reason for rejection (if applicable)
     */
    function processExpense(
        address _employee,
        uint256 _expenseId,
        bool _approve,
        string calldata _reason
    ) external onlyCFO whenNotPaused(PauseType.PARTIAL) {
        require(_expenseId < expenseCount[_employee], "Invalid expense");
        Expense storage expense = expenses[_employee][_expenseId];
        require(expense.status == ExpenseStatus.PENDING, "Not pending");
        require(!expense.isRevoked, "Expense revoked");
        
        if (!_approve) {
            require(bytes(_reason).length > 0, "Reason required");
            expense.status = ExpenseStatus.REJECTED;
            expense.rejectionReason = _reason;
        } else {
            expense.status = ExpenseStatus.APPROVED;
        }
        
        expense.processedDate = block.timestamp;
        emit ExpenseStatusUpdated(_employee, _expenseId, expense.status, _reason);
    }
    
    /**
     * @notice Claims an approved expense
     * @param _expenseId ID of the expense to claim
     */
    function claimExpense(
        uint256 _expenseId
    ) external onlyEmployee whenNotPaused(PauseType.PARTIAL) notInSameBlock(msg.sender) {
        Expense storage expense = expenses[msg.sender][_expenseId];
        require(expense.status == ExpenseStatus.APPROVED, "Not approved");
        require(block.timestamp - expense.submissionDate <= EXPENSE_VALIDITY_PERIOD, "Expired");
        
        expense.status = ExpenseStatus.CLAIMED;
        require(stablecoin.transfer(msg.sender, expense.amount), "Transfer failed");
        
        emit ExpenseStatusUpdated(msg.sender, _expenseId, ExpenseStatus.CLAIMED, "");
    }
    
    /**
     * @notice Calculates final payout for terminated employee
     * @param _employee Employee address
     * @param _terminationDate Date of termination
     * @return Final payout amount
     */
    function calculateFinalPayout(
        address _employee,
        uint256 _terminationDate
    ) public view returns (uint256) {
        Employee memory emp = employees[_employee];
        if (!emp.isActive || _terminationDate <= emp.lastClaimDate) return 0;
        
        uint256 daysWorked = (_terminationDate - emp.lastClaimDate) / 1 days;
        return (daysWorked * emp.monthlySalary) / 30;
    }
}
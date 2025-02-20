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
        string name;
        string department;
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
    address[] private employeeAddresses; // New array to track all employee addresses
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
    
    event PauseStatusChanged(PauseType pauseType);
    
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
     * @notice Sets the pause status of the contract
     * @param _pauseType New pause type to set
     */
    function setPauseStatus(PauseType _pauseType) external onlyCFO {
        currentPauseType = _pauseType;
        emit PauseStatusChanged(_pauseType);
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
     * @notice Gets total number of employees (both active and terminated)
     * @return Total number of employees
     */
    function getTotalEmployees() external view returns (uint256) {
        return employeeAddresses.length;
    }
    
    /**
     * @notice Gets all employees with pagination
     * @param _offset Starting index
     * @param _limit Maximum number of employees to return
     * @return addresses Array of employee addresses
     * @return names Array of employee names
     * @return departments Array of employee departments
     * @return isActive Array indicating if each employee is active
     */
    function getAllEmployees(uint256 _offset, uint256 _limit) 
        external 
        view 
        returns (
            address[] memory addresses,
            string[] memory names,
            string[] memory departments,
            bool[] memory isActive
        ) 
    {
        require(_offset < employeeAddresses.length, "Invalid offset");
        
        uint256 remaining = employeeAddresses.length - _offset;
        uint256 count = remaining < _limit ? remaining : _limit;
        
        addresses = new address[](count);
        names = new string[](count);
        departments = new string[](count);
        isActive = new bool[](count);
        
        for (uint256 i = 0; i < count; i++) {
            address empAddress = employeeAddresses[_offset + i];
            Employee memory emp = employees[empAddress];
            
            addresses[i] = empAddress;
            names[i] = emp.name;
            departments[i] = emp.department;
            isActive[i] = emp.isActive;
        }
        
        return (addresses, names, departments, isActive);
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
        require(_employee != address(0), "Invalid address");
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
        
        employeeAddresses.push(_employee);
        emit EmployeeAdded(_employee, _name, _monthlySalary, _startDate);
    }
    
    // ... [rest of the contract remains unchanged]
    
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
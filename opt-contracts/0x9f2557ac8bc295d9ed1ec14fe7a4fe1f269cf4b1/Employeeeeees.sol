/**
 *Submitted for verification at optimistic.etherscan.io on 2024-12-20
*/

/**
 *Submitted for verification at optimistic.etherscan.io on 2024-12-20
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Employeeeeees
 * @notice Manages employee salaries and expenses using stablecoins
 * @dev Implementation handles both salary disbursement and expense management
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function decimals() external view returns (uint8);
}

contract Employeeeeees {
    // State Variables
    IERC20 public immutable stablecoin;
    address public cfo;
    uint8 private immutable tokenDecimals;
    
    // Constants - made private and exposed through getters if needed
    uint256 private constant MAX_CLAIMABLE_MONTHS = 3;
    uint256 private constant EXPENSE_VALIDITY_PERIOD = 90 days;
    uint256 private constant MAX_DESCRIPTION_LENGTH = 200;
    uint256 private constant MINIMUM_AMOUNT = 1e6; // $1 with 6 decimals
    uint256 private constant CFO_TRANSFER_DELAY = 2 days;
    
    // Added reentrancy guard
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _reentrancyStatus;
    
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
    mapping(address => Employee) private employees; // Made private with getter
    address[] private employeeAddresses;
    mapping(address => mapping(uint256 => Expense)) private expenses; // Made private with getter
    mapping(address => uint256) private expenseCount;
    mapping(address => uint256) private lastActionBlock;
    
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
    
    // Custom errors for gas optimization
    error NotCFO();
    error NotActiveEmployee();
    error ActionInSameBlock();
    error OperationPaused();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidDate();
    error InvalidRange();
    error TransferFailed();
    error ExpenseNotPending();
    error ExpenseAlreadyRevoked();
    error ExpenseExpired();
    error ExpenseNotApproved();
    error EmptyInput();
    error InputTooLong();
    error TransferNotReady();
    error InvalidPagination();
    error ReentrancyGuardError();
    
    // Modifiers
    modifier onlyCFO() {
        if (msg.sender != cfo) revert NotCFO();
        _;
    }
    
    modifier onlyEmployee() {
        if (!employees[msg.sender].isActive) revert NotActiveEmployee();
        _;
    }
    
    modifier notInSameBlock(address account) {
        if (lastActionBlock[account] == block.number) revert ActionInSameBlock();
        _;
        lastActionBlock[account] = block.number;
    }
    
    modifier whenNotPaused(PauseType requiredType) {
        if (!(currentPauseType == PauseType.NONE || 
            (currentPauseType == PauseType.PARTIAL && requiredType == PauseType.PARTIAL))) {
            revert OperationPaused();
        }
        _;
    }

    // Added reentrancy guard modifier
    modifier nonReentrant() {
        if (_reentrancyStatus == ENTERED) revert ReentrancyGuardError();
        _reentrancyStatus = ENTERED;
        _;
        _reentrancyStatus = NOT_ENTERED;
    }

    constructor(address _stablecoin) {
        if (_stablecoin == address(0)) revert InvalidAddress();
        stablecoin = IERC20(_stablecoin);
        tokenDecimals = IERC20(_stablecoin).decimals();
        cfo = msg.sender;
        _reentrancyStatus = NOT_ENTERED;
    }

    // Added check for contract balance
    function getContractBalance() public view returns (uint256) {
        return stablecoin.balanceOf(address(this));
    }

    // Added function to check if amount is claimable based on contract balance
    function isAmountClaimable(uint256 amount) private view returns (bool) {
        return amount <= getContractBalance();
    }

    function getClaimableSalary(
        address _employee
    ) public view returns (uint256) {
        Employee memory emp = employees[_employee];
        if (!emp.isActive) return 0;
        
        uint256 currentTime = block.timestamp;
        uint256 monthsPassed = (currentTime - emp.lastClaimDate) / 30 days;
        if (monthsPassed > MAX_CLAIMABLE_MONTHS) {
            monthsPassed = MAX_CLAIMABLE_MONTHS;
        }
        
        return monthsPassed * emp.monthlySalary;
    }

    function claimSalary() external 
        onlyEmployee 
        whenNotPaused(PauseType.PARTIAL) 
        notInSameBlock(msg.sender) 
        nonReentrant 
        returns (uint256 amount) 
    {
        amount = getClaimableSalary(msg.sender);
        if (amount == 0) revert InvalidAmount();
        if (!isAmountClaimable(amount)) revert TransferFailed();
        
        uint256 currentTime = block.timestamp;
        uint256 monthsPassed = (currentTime - employees[msg.sender].lastClaimDate) / 30 days;
        if (monthsPassed > MAX_CLAIMABLE_MONTHS) {
            monthsPassed = MAX_CLAIMABLE_MONTHS;
        }
        
        uint256 periodStart = employees[msg.sender].lastClaimDate;
        uint256 periodEnd = periodStart + (monthsPassed * 30 days);
        
        // Update state before transfer
        employees[msg.sender].lastClaimDate = periodEnd;
        
        if (!stablecoin.transfer(msg.sender, amount)) revert TransferFailed();
        emit SalaryClaimed(msg.sender, amount, periodStart, periodEnd);
        
        return amount;
    }

    // Added explicit getters for private mappings
    function getEmployee(address _employee) external view returns (
        bool isActive,
        uint256 monthlySalary,
        uint256 lastClaimDate,
        uint256 startDate,
        uint256 terminationDate,
        string memory name,
        string memory department
    ) {
        Employee memory emp = employees[_employee];
        return (
            emp.isActive,
            emp.monthlySalary,
            emp.lastClaimDate,
            emp.startDate,
            emp.terminationDate,
            emp.name,
            emp.department
        );
    }

    function getExpense(address _employee, uint256 _expenseId) external view returns (
        uint256 amount,
        string memory description,
        ExpenseStatus status,
        uint256 submissionDate,
        string memory rejectionReason,
        uint256 processedDate,
        bool isRevoked
    ) {
        Expense memory exp = expenses[_employee][_expenseId];
        return (
            exp.amount,
            exp.description,
            exp.status,
            exp.submissionDate,
            exp.rejectionReason,
            exp.processedDate,
            exp.isRevoked
        );
    }

    function submitExpense(
        uint256 _amount,
        string calldata _description
    ) external 
        onlyEmployee 
        whenNotPaused(PauseType.PARTIAL) 
        notInSameBlock(msg.sender) 
    {
        if (_amount < MINIMUM_AMOUNT) revert InvalidAmount();
        if (bytes(_description).length > MAX_DESCRIPTION_LENGTH) revert InputTooLong();
        if (bytes(_description).length == 0) revert EmptyInput();
        
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

    function revokeExpense(
        uint256 _expenseId
    ) external onlyEmployee whenNotPaused(PauseType.PARTIAL) {
        Expense storage expense = expenses[msg.sender][_expenseId];
        if (expense.status != ExpenseStatus.PENDING) revert ExpenseNotPending();
        if (expense.isRevoked) revert ExpenseAlreadyRevoked();
        
        expense.isRevoked = true;
        emit ExpenseRevoked(msg.sender, _expenseId, block.timestamp);
    }

    function claimExpense(
        uint256 _expenseId
    ) external 
        onlyEmployee 
        whenNotPaused(PauseType.PARTIAL) 
        notInSameBlock(msg.sender) 
        nonReentrant 
    {
        Expense storage expense = expenses[msg.sender][_expenseId];
        if (expense.status != ExpenseStatus.APPROVED) revert ExpenseNotApproved();
        if (block.timestamp - expense.submissionDate > EXPENSE_VALIDITY_PERIOD) revert ExpenseExpired();
        if (!isAmountClaimable(expense.amount)) revert TransferFailed();
        
        // Update state before transfer
        expense.status = ExpenseStatus.CLAIMED;
        
        if (!stablecoin.transfer(msg.sender, expense.amount)) revert TransferFailed();
        emit ExpenseStatusUpdated(msg.sender, _expenseId, ExpenseStatus.CLAIMED, "");
    }

    function terminateEmployee(
        address _employee,
        uint256 _terminationDate
    ) external onlyCFO whenNotPaused(PauseType.FULL) nonReentrant {
        Employee storage emp = employees[_employee];
        if (!emp.isActive) revert NotActiveEmployee();
        if (_terminationDate < emp.startDate || _terminationDate > block.timestamp) revert InvalidDate();
        
        uint256 finalPayout = calculateFinalPayout(_employee, _terminationDate);
        
        // Update state before transfer
        emp.isActive = false;
        emp.terminationDate = _terminationDate;
        
        if (finalPayout > 0) {
            if (!isAmountClaimable(finalPayout)) revert TransferFailed();
            if (!stablecoin.transfer(_employee, finalPayout)) revert TransferFailed();
        }
        
        emit EmployeeTerminated(_employee, _terminationDate, finalPayout);
    }

    // Constants getters
    function getMaxClaimableMonths() external pure returns (uint256) {
        return MAX_CLAIMABLE_MONTHS;
    }

    function getExpenseValidityPeriod() external pure returns (uint256) {
        return EXPENSE_VALIDITY_PERIOD;
    }

    function getMaxDescriptionLength() external pure returns (uint256) {
        return MAX_DESCRIPTION_LENGTH;
    }

    function getMinimumAmount() external pure returns (uint256) {
        return MINIMUM_AMOUNT;
    }

    function getCfoTransferDelay() external pure returns (uint256) {
        return CFO_TRANSFER_DELAY;
    }

    function getEmployeeExpenses(
        address _employee,
        uint256 _startId,
        uint256 _endId
    ) external view returns (
        uint256[] memory amounts,
        string[] memory descriptions,
        ExpenseStatus[] memory statuses,
        uint256[] memory submissionDates,
        bool[] memory isRevoked
    ) {
        if (_endId <= _startId || _endId > expenseCount[_employee]) revert InvalidRange();
        
        uint256 size = _endId - _startId;
        amounts = new uint256[](size);
        descriptions = new string[](size);
        statuses = new ExpenseStatus[](size);
        submissionDates = new uint256[](size);
        isRevoked = new bool[](size);
        
        for (uint256 i = 0; i < size; i++) {
            Expense memory exp = expenses[_employee][_startId + i];
            amounts[i] = exp.amount;
            descriptions[i] = exp.description;
            statuses[i] = exp.status;
            submissionDates[i] = exp.submissionDate;
            isRevoked[i] = exp.isRevoked;
        }
        
        return (amounts, descriptions, statuses, submissionDates, isRevoked);
    }

    function getPendingExpensesCount(
        address _employee
    ) external view returns (uint256 count) {
        uint256 total = expenseCount[_employee];
        for (uint256 i = 0; i < total; i++) {
            if (expenses[_employee][i].status == ExpenseStatus.PENDING && !expenses[_employee][i].isRevoked) {
                count++;
            }
        }
        return count;
    }

    function setPauseStatus(PauseType _pauseType) external onlyCFO {
        currentPauseType = _pauseType;
        emit PauseStatusChanged(_pauseType);
    }
    
    function initiateCFOTransfer(address _newCfo) external onlyCFO {
        if (_newCfo == address(0)) revert InvalidAddress();
        pendingCfo = _newCfo;
        cfoTransferTime = block.timestamp + CFO_TRANSFER_DELAY;
        emit CFOTransferInitiated(cfo, _newCfo, cfoTransferTime);
    }
    
    function completeCFOTransfer() external {
        if (msg.sender != pendingCfo) revert NotCFO();
        if (block.timestamp < cfoTransferTime) revert TransferNotReady();
        
        address oldCfo = cfo;
        cfo = pendingCfo;
        pendingCfo = address(0);
        cfoTransferTime = 0;
        
        emit CFOTransferInitiated(oldCfo, cfo, 0);
    }
    
    function getTotalEmployees() external view returns (uint256) {
        return employeeAddresses.length;
    }
    
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
        if (_offset >= employeeAddresses.length) revert InvalidPagination();
        
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
    
    function addEmployee(
        address _employee,
        string calldata _name,
        string calldata _department,
        uint256 _monthlySalary,
        uint256 _startDate
    ) external onlyCFO whenNotPaused(PauseType.FULL) {
        if (_employee == address(0)) revert InvalidAddress();
        if (employees[_employee].isActive) revert NotActiveEmployee();
        if (_monthlySalary < MINIMUM_AMOUNT) revert InvalidAmount();
        if (_startDate > block.timestamp) revert InvalidDate();
        if (bytes(_name).length == 0) revert EmptyInput();
        if (bytes(_department).length == 0) revert EmptyInput();
        
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

    /**
     * @notice Approves a pending expense
     * @param _employee Employee address
     * @param _expenseId Expense ID to approve
     */
    function approveExpense(
        address _employee,
        uint256 _expenseId
    ) external onlyCFO whenNotPaused(PauseType.PARTIAL) {
        Expense storage expense = expenses[_employee][_expenseId];
        if (expense.status != ExpenseStatus.PENDING) revert ExpenseNotPending();
        if (expense.isRevoked) revert ExpenseAlreadyRevoked();
        if (!employees[_employee].isActive) revert NotActiveEmployee();
        
        expense.status = ExpenseStatus.APPROVED;
        expense.processedDate = block.timestamp;
        
        emit ExpenseStatusUpdated(_employee, _expenseId, ExpenseStatus.APPROVED, "");
    }

    /**
     * @notice Rejects a pending expense
     * @param _employee Employee address
     * @param _expenseId Expense ID to reject
     * @param _reason Reason for rejection
     */
    function rejectExpense(
        address _employee,
        uint256 _expenseId,
        string calldata _reason
    ) external onlyCFO whenNotPaused(PauseType.PARTIAL) {
        if (bytes(_reason).length == 0) revert EmptyInput();
        if (bytes(_reason).length > MAX_DESCRIPTION_LENGTH) revert InputTooLong();
        
        Expense storage expense = expenses[_employee][_expenseId];
        if (expense.status != ExpenseStatus.PENDING) revert ExpenseNotPending();
        if (expense.isRevoked) revert ExpenseAlreadyRevoked();
        if (!employees[_employee].isActive) revert NotActiveEmployee();
        
        expense.status = ExpenseStatus.REJECTED;
        expense.rejectionReason = _reason;
        expense.processedDate = block.timestamp;
        
        emit ExpenseStatusUpdated(_employee, _expenseId, ExpenseStatus.REJECTED, _reason);
    }

    function calculateFinalPayout(
        address _employee,
        uint256 _terminationDate
    ) public view returns (uint256) {
        Employee memory emp = employees[_employee];
        if (!emp.isActive || _terminationDate <= emp.lastClaimDate) return 0;
        
        uint256 daysWorked = (_terminationDate - emp.lastClaimDate) / 1 days;
        return (daysWorked * emp.monthlySalary) / 30;
    }

    function getTotalExpensesCount(
    address _employee
) external view returns (uint256) {
    return expenseCount[_employee];
}

function getAllPendingExpenses(
    uint256 _offset,
    uint256 _limit
) external view returns (
    address[] memory expenseOwners,
    uint256[] memory expenseIds,
    uint256[] memory amounts,
    string[] memory descriptions,
    uint256[] memory submissionDates
) {
    // First count total pending expenses to allocate arrays
    uint256 totalPending = 0;
    uint256 currentOffset = 0;
    
    // Count pending expenses and find the starting point
    for (uint256 empIdx = 0; empIdx < employeeAddresses.length; empIdx++) {
        address empAddress = employeeAddresses[empIdx];
        for (uint256 expId = 0; expId < expenseCount[empAddress]; expId++) {
            Expense memory exp = expenses[empAddress][expId];
            if (exp.status == ExpenseStatus.PENDING && !exp.isRevoked) {
                if (currentOffset >= _offset) {
                    totalPending++;
                    if (totalPending > _limit) break;
                }
                currentOffset++;
            }
        }
        if (totalPending >= _limit) break;
    }
    
    // Initialize arrays with the correct size
    uint256 size = totalPending;
    expenseOwners = new address[](size);
    expenseIds = new uint256[](size);
    amounts = new uint256[](size);
    descriptions = new string[](size);
    submissionDates = new uint256[](size);
    
    // Reset counters for populating arrays
    uint256 resultIdx = 0;
    currentOffset = 0;
    
    // Populate arrays with pending expense data
    for (uint256 empIdx = 0; empIdx < employeeAddresses.length && resultIdx < size; empIdx++) {
        address empAddress = employeeAddresses[empIdx];
        for (uint256 expId = 0; expId < expenseCount[empAddress] && resultIdx < size; expId++) {
            Expense memory exp = expenses[empAddress][expId];
            if (exp.status == ExpenseStatus.PENDING && !exp.isRevoked) {
                if (currentOffset >= _offset) {
                    expenseOwners[resultIdx] = empAddress;
                    expenseIds[resultIdx] = expId;
                    amounts[resultIdx] = exp.amount;
                    descriptions[resultIdx] = exp.description;
                    submissionDates[resultIdx] = exp.submissionDate;
                    resultIdx++;
                }
                currentOffset++;
            }
        }
    }
    
    return (expenseOwners, expenseIds, amounts, descriptions, submissionDates);
}
}
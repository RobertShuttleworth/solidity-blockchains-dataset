// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./lib_OpenZeppelin_access_Ownable.sol";
import "./contracts_SharedTypes.sol";

/**
 * @dev GigabitEscrowStatistics contract
 *
 * This contract manages the statistics and fault counting for the escrow contracts.
 * It handles counting the status of each order and tracks faults for workers and customers.
 */
contract GigabitEscrowStatistics is Ownable {

    // Struct to hold the user statistics
    // note: uint16 (2 bytes) x 12 = 24 bytes, and uint32 (4 bytes) x 2 = 8 bytes, for a total of 32 bytes
    //       which fits perfectly into one storage slot
    struct UserStatistics {
        uint16 totalOrdersInitiated;           // Total orders initiated as a customer
        uint16 totalOrdersReceived;            // Total orders received as a worker
        uint16 totalOrdersInitiatedSuccessful; // Total successful orders initiated as a customer
        uint16 totalOrdersReceivedSuccessful;  // Total successful orders received as a worker
        uint16 timesAsReferrer;                // Times this user has been a referrer
        uint16 timesAsAffiliate;               // Times this user has been an affiliate
        uint16 faultsReceivedAsCustomer;       // Faults recorded against this user as a customer
        uint16 faultsReceivedAsWorker;         // Faults recorded against this user as a worker
        uint16 disputesInitiated;              // Disputes initiated by this user
        uint16 disputesReceived;               // Disputes received by this user
        uint16 reportsInitiated;               // Reports initiated by this user
        uint16 reportsReceived;                // Reports received by this user
        uint32 totalAmountEarned;              // Total amount earned by this user (as worker, affiliate, or referrer)
        uint32 totalAmountSpent;               // Total amount spent by this user (as customer), less any refunds
    }

    // Struct to hold the financial statistics
    // note: Each uint32 (4 bytes) x 8 = 32 bytes, which fits perfectly into one storage slot
    struct FinancialStatistics {
        uint32 spentByCustomers;        // amount spent by customers, less any refunds
        uint32 collectedByWorkers;      // amount earned by workers
        uint32 collectedByAffiliates;   // amount earned by affiliates
        uint32 collectedByReferrers;    // amount earned by referrals
        uint32 collectedByArbiters;     // amount earned by arbiters
        uint32 collectedByCompanyTotal; // amount earned by the company
        uint32 collectedServiceFees;    // service fees collected
        uint32 collectedPlatformFees;   // platform fees collected
    }

    // Struct to hold the statistics for each work status
    // note: uint32 (4 bytes) x 8 = 32 bytes, which fits perfectly into one storage slot
    struct StatusStatistics {
        uint32 inQueue;      // Orders currently in the 'IN_QUEUE' status
        uint32 inProgress;   // Orders currently in the 'IN_PROGRESS' status
        uint32 inReview;     // Orders currently in the 'IN_REVIEW' status
        uint32 inDispute;    // Orders currently in the 'IN_DISPUTE' status
        uint32 completed;    // Orders currently in the 'COMPLETED' status
        uint32 settled;      // Orders currently in the 'SETTLED' status
        uint32 canceled;     // Orders currently in the 'CANCELED' status
        uint32 terminated;   // Orders currently in the 'TERMINATED' status
    }

    uint256 public packedFinancialStatistics;
    uint256 public packedStatusStatistics;
    mapping(address reporter => uint256 lastReportedTimestamp) private reporterLastReportedMap;
    mapping(address reporter => address reported) private reporterReportedMap;
    mapping(address blacklisted => bool) public blacklistedMap;
    mapping(address => uint256) public packedUserStatistics;
    mapping(address => bool) public managerWhitelist;

    event StatsUnderflowWarning();

    error UserBlacklisted();
    error ReporterCooldown();
    error ReporterNotFound();
    error ReportedNotFound();
    error DuplicateReport();
    error NoChange();
    error OwnerAddress();
    error ThisAddress();
    error ZeroAddress();

    modifier onlyManager() {
        if (managerWhitelist[_msgSender()] == false) {
            revert("Only manager can call this function");
        }
        _;
    }

    modifier onlyAuthorized() {
        if (tx.origin != owner() // We have custom logic here to allow for tx.origin to be used, as we instantiate from another contract
            && _msgSender() != owner()
        ) {
            revert("Only authorized address can call this function");
        }
        _;
    }

    modifier notBlacklisted() {
        if (blacklistedMap[_msgSender()] == true) {
            revert UserBlacklisted();
        }
        _;
    }

    function addManagerToWhitelist(address _manager) external onlyAuthorized {
        if (_manager == address(0)) {
            revert("Manager is not a valid address");
        }
        if (managerWhitelist[_manager] == true) {
            revert("Manager already whitelisted");
        }
        managerWhitelist[_manager] = true;
    }

    function removeManagerFromWhitelist(address _manager) external onlyOwner {
        if (_manager == address(0)) {
            revert("Manager is not a valid address");
        }
        if (managerWhitelist[_manager] == false) {
            revert("Manager not whitelisted");
        }
        managerWhitelist[_manager] = false;
    }

    function isManager(address _address) external view returns (bool) {
        return managerWhitelist[_address];
    }

    function overwriteFinancialStatistics(FinancialStatistics memory _stats) external onlyOwner {
        packedFinancialStatistics = packFinancialStatistics(_stats);
    }

    function resetFinancialStatistics() external onlyOwner {
        packedFinancialStatistics = 0;
    }

    function overwriteStatusStatistics(StatusStatistics memory _stats) external onlyOwner {
        packedStatusStatistics = packStatusStatistics(_stats);
    }

    function resetStatusStatistics() external onlyOwner {
        packedStatusStatistics = 0;
    }

    function overwriteUserStatistics(address _user, UserStatistics memory _stats) external onlyOwner {
        packedUserStatistics[_user] = packUserStatistics(_stats);
    }

    function resetUserStatistics(address _user) external onlyOwner {
        packedUserStatistics[_user] = 0;
    }

    function orderInitiated(address _customer, address _worker) external onlyManager {
        // Get the current statistics
        UserStatistics memory _customerStats = unpackUserStatistics(packedUserStatistics[_customer]);
        UserStatistics memory _workerStats = unpackUserStatistics(packedUserStatistics[_worker]);
        StatusStatistics memory _statusStats = unpackStatusStatistics(packedStatusStatistics);

        // Update the current statistics values with the new values in memory
        unchecked {
            _customerStats.totalOrdersInitiated++;
            _workerStats.totalOrdersReceived++;
            _statusStats.inQueue++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_customer] = packUserStatistics(_customerStats);
        packedUserStatistics[_worker] = packUserStatistics(_workerStats);
        packedStatusStatistics = packStatusStatistics(_statusStats);
    }

    function report(address _reporter, address _reported) public onlyManager {
        // Get the current statistics
        UserStatistics memory _reporterStats = unpackUserStatistics(packedUserStatistics[_reporter]);
        UserStatistics memory _reportedStats = unpackUserStatistics(packedUserStatistics[_reported]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _reporterStats.reportsInitiated++;
            _reportedStats.reportsReceived++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_reporter] = packUserStatistics(_reporterStats);
        packedUserStatistics[_reported] = packUserStatistics(_reportedStats);
    }

    function updateStatus(SharedTypes.WorkStatus _oldStatus, SharedTypes.WorkStatus _newStatus) external onlyManager {
        // Load the current statistics from storage
        uint256 _packedStatusStatistics = packedStatusStatistics;

        // Unpack the current statistics from storage into a memory struct
        StatusStatistics memory _currentStats = unpackStatusStatistics(_packedStatusStatistics);

        // Decrease the counter for the old status
        bool _underflowWarn = false;
        if (_oldStatus == SharedTypes.WorkStatus.IN_QUEUE) {
            if (_currentStats.inQueue > 0) {
                unchecked {
                    _currentStats.inQueue--;
                }
            } else {
                _underflowWarn = true;
            }
        } else if (_oldStatus == SharedTypes.WorkStatus.IN_PROGRESS) {
            if (_currentStats.inProgress > 0) {
                unchecked {
                    _currentStats.inProgress--;
                }
            } else {
                _underflowWarn = true;
            }
        } else if (_oldStatus == SharedTypes.WorkStatus.IN_REVIEW) {
            if (_currentStats.inReview > 0) {
                unchecked {
                    _currentStats.inReview--;
                }
            } else {
                _underflowWarn = true;
            }
        } else if (_oldStatus == SharedTypes.WorkStatus.IN_DISPUTE) {
            if (_currentStats.inDispute > 0) {
                unchecked {
                    _currentStats.inDispute--;
                }
            } else {
                _underflowWarn = true;
            }
        } else if (_oldStatus == SharedTypes.WorkStatus.COMPLETED) {
            if (_currentStats.completed > 0) {
                unchecked {
                    _currentStats.completed--;
                }
            } else {
                _underflowWarn = true;
            }
        } else if (_oldStatus == SharedTypes.WorkStatus.SETTLED) {
            if (_currentStats.settled > 0) {
                unchecked {
                    _currentStats.settled--;
                }
            } else {
                _underflowWarn = true;
            }
        } else if (_oldStatus == SharedTypes.WorkStatus.CANCELED) {
            if (_currentStats.canceled > 0) {
                unchecked {
                    _currentStats.canceled--;
                }
            } else {
                _underflowWarn = true;
            }
        } else if (_oldStatus == SharedTypes.WorkStatus.TERMINATED) {
            if (_currentStats.terminated > 0) {
                unchecked {
                    _currentStats.terminated--;
                }
            } else {
                _underflowWarn = true;
            }
        }

        // Note: We don't want to revert a valid transaction just because of an underflow warning in the 
        // statistics. However, we do want to know about it, so we emit an event here.
        if (_underflowWarn == true) {
            emit StatsUnderflowWarning();
        }

        // Increase the counter for the new status, unchecked as we're unlikely to increment beyond 
        // the uint32 maximum of 4,294,967,295 (and if we did, that would be a very good problem to have)
        if (_newStatus == SharedTypes.WorkStatus.IN_QUEUE) {
            unchecked {
                _currentStats.inQueue++;
            }
        } else if (_newStatus == SharedTypes.WorkStatus.IN_PROGRESS) {
            unchecked {
                _currentStats.inProgress++;
            }
        } else if (_newStatus == SharedTypes.WorkStatus.IN_REVIEW) {
            unchecked {
                _currentStats.inReview++;
            }
        } else if (_newStatus == SharedTypes.WorkStatus.IN_DISPUTE) {
            unchecked {
                _currentStats.inDispute++;
            }
        } else if (_newStatus == SharedTypes.WorkStatus.COMPLETED) {
            unchecked {
                _currentStats.completed++;
            }
        } else if (_newStatus == SharedTypes.WorkStatus.SETTLED) {
            unchecked {
                _currentStats.settled++;
            }
        } else if (_newStatus == SharedTypes.WorkStatus.CANCELED) {
            unchecked {
                _currentStats.canceled++;
            }
        } else if (_newStatus == SharedTypes.WorkStatus.TERMINATED) {
            unchecked {
                _currentStats.terminated++;
            }
        }

        // Pack the updated statistics back into the storage variable
        packedStatusStatistics = packStatusStatistics(_currentStats);
    }

    function updateFinancialStatistics(uint256 _packedFinancialStatsToAdd) external onlyManager {
        // Get the current statistics
        FinancialStatistics memory _currentStats = unpackFinancialStatistics(packedFinancialStatistics);

        // Get the new statistics to add
        FinancialStatistics memory _statsToAdd = unpackFinancialStatistics(_packedFinancialStatsToAdd);

        // Update the current statistics values with the new values in memory
        _currentStats.spentByCustomers += _statsToAdd.spentByCustomers;
        _currentStats.collectedByWorkers += _statsToAdd.collectedByWorkers;
        _currentStats.collectedByAffiliates += _statsToAdd.collectedByAffiliates;
        _currentStats.collectedByReferrers += _statsToAdd.collectedByReferrers;
        _currentStats.collectedByArbiters += _statsToAdd.collectedByArbiters;
        _currentStats.collectedByCompanyTotal += _statsToAdd.collectedByCompanyTotal;
        _currentStats.collectedServiceFees += _statsToAdd.collectedServiceFees;
        _currentStats.collectedPlatformFees += _statsToAdd.collectedPlatformFees;

        // Update the statistics with the updated values
        packedFinancialStatistics = packFinancialStatistics(_currentStats);
    }

    function increaseWorkerFields(
        address _user,
        bool _orderReceived,
        bool _orderReceivedSuccessful,
        bool _faultReceived,
        bool _disputeReceived,
        bool _reportReceived,
        uint16 _amountEarned
    ) external onlyManager {
        // Check if the order has been received
        if (_orderReceived == false) {
            revert("Order must be received to increase worker fields");
        }

        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        if (_orderReceived == true) {
            unchecked {
                _currentStats.totalOrdersReceived++;
            }
        }
        if (_orderReceivedSuccessful == true) {
            unchecked {
                _currentStats.totalOrdersReceivedSuccessful++;
            }
        }
        if (_faultReceived == true) {
            unchecked {
                _currentStats.faultsReceivedAsWorker++;
            }
        }
        if (_disputeReceived == true) {
            unchecked {
                _currentStats.disputesReceived++;
            }
        }
        if (_reportReceived == true) {
            unchecked {
                _currentStats.reportsReceived++;
            }
        }
        if (_amountEarned > 0) {
            unchecked {
                _currentStats.totalAmountEarned += _amountEarned;
            }
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function increaseCustomerFields(
        address _user,
        bool _orderInitiated,
        bool _orderInitiatedSuccessful,
        bool _faultReceived,
        bool _disputeInitiated,
        bool _reportInitiated,
        uint16 _amountSpent
    ) external onlyManager {
        // Check if the order has been initiated
        if (_orderInitiated == false) {
            revert("Order must be initiated to increase customer fields");
        }

        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        if (_orderInitiated == true) {
            unchecked {
                _currentStats.totalOrdersInitiated++;
            }
        }
        if (_orderInitiatedSuccessful == true) {
            unchecked {
                _currentStats.totalOrdersInitiatedSuccessful++;
            }
        }
        if (_faultReceived == true) {
            unchecked {
                _currentStats.faultsReceivedAsCustomer++;
            }
        }
        if (_disputeInitiated == true) {
            unchecked {
                _currentStats.disputesInitiated++;
            }
        }
        if (_reportInitiated == true) {
            unchecked {
                _currentStats.reportsInitiated++;
            }
        }
        if (_amountSpent > 0) {
            unchecked {
                _currentStats.totalAmountSpent += _amountSpent;
            }
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementTotalOrdersInitiated(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.totalOrdersInitiated++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementTotalOrdersReceived(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.totalOrdersReceived++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementTotalOrdersInitiatedSuccessful(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.totalOrdersInitiatedSuccessful++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementTotalOrdersReceivedSuccessful(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.totalOrdersReceivedSuccessful++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementTimesAsReferrer(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.timesAsReferrer++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementTimesAsAffiliate(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.timesAsAffiliate++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementFaultsReceivedAsCustomer(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.faultsReceivedAsCustomer++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementFaultsReceivedAsWorker(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.faultsReceivedAsWorker++;
        }
        
        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementDisputesInitiated(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.disputesInitiated++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementDisputesReceived(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.disputesReceived++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementReportsInitiated(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.reportsInitiated++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function incrementReportsReceived(address _user) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.reportsReceived++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function increaseTotalAmountEarned(address _user, uint32 _amountEarned) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.totalAmountEarned += _amountEarned;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function increaseTotalAmountSpent(address _user, uint32 _amountSpent) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        unchecked {
            _currentStats.totalAmountSpent += _amountSpent;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    function decreaseTotalAmountSpent(address _user, uint32 _amountRefunded) external onlyManager {
        // Get the current statistics
        UserStatistics memory _currentStats = unpackUserStatistics(packedUserStatistics[_user]);

        // Update the current statistics values with the new values in memory
        if (_currentStats.totalAmountSpent < _amountRefunded) {
            _currentStats.totalAmountSpent = 0;
        } else {
            unchecked {
                _currentStats.totalAmountSpent -= _amountRefunded;
            }
        }

        // Update the statistics with the updated values
        packedUserStatistics[_user] = packUserStatistics(_currentStats);
    }

    // Function to pack 8 uint32 values into a single uint256
    function packFinancialStatistics(FinancialStatistics memory _stats) internal pure returns (uint256) {
        uint256 packedData = 0;
        
        packedData |= uint256(_stats.spentByCustomers) << 224;
        packedData |= uint256(_stats.collectedByWorkers) << 192;
        packedData |= uint256(_stats.collectedByAffiliates) << 160;
        packedData |= uint256(_stats.collectedByReferrers) << 128;
        packedData |= uint256(_stats.collectedByArbiters) << 96;
        packedData |= uint256(_stats.collectedByCompanyTotal) << 64;
        packedData |= uint256(_stats.collectedServiceFees) << 32;
        packedData |= uint256(_stats.collectedPlatformFees);

        return packedData;
    }

    // Function to unpack a uint256 into 8 uint32 variables
    function unpackFinancialStatistics(uint256 packedData) internal pure returns (FinancialStatistics memory) {
        FinancialStatistics memory _stats;

        _stats.spentByCustomers = uint32(packedData >> 224);
        _stats.collectedByWorkers = uint32(packedData >> 192);
        _stats.collectedByAffiliates = uint32(packedData >> 160);
        _stats.collectedByReferrers = uint32(packedData >> 128);
        _stats.collectedByArbiters = uint32(packedData >> 96);
        _stats.collectedByCompanyTotal = uint32(packedData >> 64);
        _stats.collectedServiceFees = uint32(packedData >> 32);
        _stats.collectedPlatformFees = uint32(packedData);

        return _stats;
    }

    function packStatusStatistics(StatusStatistics memory _stats) internal pure returns (uint256) {
        uint256 packedData = 0;
        
        packedData |= uint256(_stats.inQueue) << 224;
        packedData |= uint256(_stats.inProgress) << 192;
        packedData |= uint256(_stats.inReview) << 160;
        packedData |= uint256(_stats.inDispute) << 128;
        packedData |= uint256(_stats.completed) << 96;
        packedData |= uint256(_stats.settled) << 64;
        packedData |= uint256(_stats.canceled) << 32;
        packedData |= uint256(_stats.terminated);

        return packedData;
    }

    function unpackStatusStatistics(uint256 packedData) internal pure returns (StatusStatistics memory) {
        StatusStatistics memory _stats;

        _stats.inQueue = uint32(packedData >> 224);
        _stats.inProgress = uint32(packedData >> 192);
        _stats.inReview = uint32(packedData >> 160);
        _stats.inDispute = uint32(packedData >> 128);
        _stats.completed = uint32(packedData >> 96);
        _stats.settled = uint32(packedData >> 64);
        _stats.canceled = uint32(packedData >> 32);
        _stats.terminated = uint32(packedData);

        return _stats;
    }

    function packUserStatistics (UserStatistics memory _stats) internal pure returns (uint256) {
        uint256 packedData = 0;
        
        packedData |= uint256(_stats.totalOrdersInitiated) << 240;
        packedData |= uint256(_stats.totalOrdersReceived) << 224;
        packedData |= uint256(_stats.totalOrdersInitiatedSuccessful) << 208;
        packedData |= uint256(_stats.totalOrdersReceivedSuccessful) << 192;
        packedData |= uint256(_stats.timesAsReferrer) << 176;
        packedData |= uint256(_stats.timesAsAffiliate) << 160;
        packedData |= uint256(_stats.faultsReceivedAsCustomer) << 144;
        packedData |= uint256(_stats.faultsReceivedAsWorker) << 128;
        packedData |= uint256(_stats.disputesInitiated) << 112;
        packedData |= uint256(_stats.disputesReceived) << 96;
        packedData |= uint256(_stats.reportsInitiated) << 80;
        packedData |= uint256(_stats.reportsReceived) << 64;
        packedData |= uint256(_stats.totalAmountEarned) << 32;
        packedData |= uint256(_stats.totalAmountSpent);

        return packedData;
    }

    function unpackUserStatistics (uint256 packedData) internal pure returns (UserStatistics memory) {
        UserStatistics memory _stats;

        _stats.totalOrdersInitiated = uint16(packedData >> 240);
        _stats.totalOrdersReceived = uint16(packedData >> 224);
        _stats.totalOrdersInitiatedSuccessful = uint16(packedData >> 208);
        _stats.totalOrdersReceivedSuccessful = uint16(packedData >> 192);
        _stats.timesAsReferrer = uint16(packedData >> 176);
        _stats.timesAsAffiliate = uint16(packedData >> 160);
        _stats.faultsReceivedAsCustomer = uint16(packedData >> 144);
        _stats.faultsReceivedAsWorker = uint16(packedData >> 128);
        _stats.disputesInitiated = uint16(packedData >> 112);
        _stats.disputesReceived = uint16(packedData >> 96);
        _stats.reportsInitiated = uint16(packedData >> 80);
        _stats.reportsReceived = uint16(packedData >> 64);
        _stats.totalAmountEarned = uint32(packedData >> 32);
        _stats.totalAmountSpent = uint32(packedData);

        return _stats;
    }

    function getUserStatistics(address _user) external view returns (UserStatistics memory) {
        return unpackUserStatistics(packedUserStatistics[_user]);
    }

    function reportGlobal(address _reported) external notBlacklisted {
        address _reporter = _msgSender();

        // Unpack information about the reporter and reported addresses
        UserStatistics memory _reporterStats = unpackUserStatistics(packedUserStatistics[_reporter]);
        UserStatistics memory _reportedStats = unpackUserStatistics(packedUserStatistics[_reported]);

        //////////////
        /// CHECKS ///
        //////////////

        // If the reporter hasn't successfully initiated or received any orders, revert
        // We want to prevent users who haven't contributed to the platform from reporting others
        if (_reporterStats.totalOrdersInitiatedSuccessful == 0 
            && _reporterStats.totalOrdersReceivedSuccessful == 0
        ) {
            revert ReporterNotFound();
        }

        // If the reported address hasn't initiated or received any orders, revert
        // We want to prevent reporting users who haven't used the platform
        if (_reportedStats.totalOrdersInitiated == 0 
            && _reportedStats.totalOrdersReceived == 0
        ) {
            revert ReportedNotFound();
        }

        // Verify that the reporter last reported timestamp is more than 1 hour ago
        // This is to prevent spamming reports
        uint256 timeSinceLastReport = block.timestamp - reporterLastReportedMap[_reporter];

        // Calculate dynamic cooldown based on the report count for cooldown purposes
        // The cooldown period is 1 hour for the first report, and increases by 1 hour for each subsequent report
        // The maximum cooldown period is 24 hours
        uint256 dynamicCooldown = _reporterStats.reportsInitiated > 24 
            ? 24 hours
            : 1 hours * _reporterStats.reportsInitiated;

        // Ensure the reporter respects the cooldown period
        if (timeSinceLastReport < dynamicCooldown) {
            revert ReporterCooldown();
        }

        // Verify that the reporter hasn't already reported the reported address
        // This is to prevent duplicate reports
        if (reporterReportedMap[_reporter] == _reported) {
            revert DuplicateReport();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Set the reported address in the reporter's map so we can enforce the duplicate report check
        reporterReportedMap[_reporter] = _reported;

        // Set the last reported timestamp for the reporter so we can enforce the cooldown
        reporterLastReportedMap[_reporter] = block.timestamp;


        // Update the current statistics values with the new values in memory
        unchecked {
            _reporterStats.reportsInitiated++;
            _reportedStats.reportsReceived++;
        }

        // Update the statistics with the updated values
        packedUserStatistics[_reporter] = packUserStatistics(_reporterStats);
        packedUserStatistics[_reported] = packUserStatistics(_reportedStats);
    }

    function manageBlacklist(address _user, bool _status) external onlyOwner {
        //////////////
        /// CHECKS ///
        //////////////

        // Ensure the owner address isn't blacklisted
        if (_user == owner()) {
            revert OwnerAddress();
        }

        // Ensure the contract address isn't blacklisted
        if (_user == address(this)) {
            revert ThisAddress();
        }
        
        // Ensure the user address isn't the zero address
        if (_user == address(0)) {
            revert ZeroAddress();
        }

        // Ensure the user address isn't already blacklisted
        if (blacklistedMap[_user] == _status) {
            revert NoChange();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Update the blacklist status for the user
        blacklistedMap[_user] = _status;
    }
}
// contracts/TokenEscrow.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";

contract TokenEscrow is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct VestingSchedule {
        uint256 totalAmount;
        uint256 releasedAmount;
        uint256 startTime;
        uint256 duration;
        uint256 cliffDuration;
        uint256 releaseInterval;
        bool revoked;
        uint256 lastReleaseTime;
        uint256 tierId;
    }

    IERC20Upgradeable public token;
    mapping(address => VestingSchedule[]) public vestingSchedules;
    mapping(address => uint256) public totalVestedAmount;
    mapping(address => bool) public presaleContracts;
    mapping(address => uint256) public publicSaleDeposits;

    uint256 public constant MINIMUM_VESTING_DURATION = 1 days;
    uint256 public constant MAXIMUM_VESTING_DURATION = 730 days;
    bool public publicSaleWithdrawalsEnabled;

    // Add events
    event PublicSaleDeposit(address indexed beneficiary, uint256 amount);
    event PublicSaleWithdrawal(address indexed beneficiary, uint256 amount);
    event PublicSaleWithdrawalsStatusUpdated(bool enabled);
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 duration,
        uint256 cliffDuration,
        uint256 tierId
    );
    event TokensReleased(
        address indexed beneficiary,
        uint256 amount,
        uint256 scheduleIndex,
        uint256 timestamp
    );
    event VestingRevoked(
        address indexed beneficiary,
        uint256 scheduleIndex,
        uint256 unreleasedAmount,
        uint256 timestamp
    );
    event PresaleContractUpdated(
        address indexed presaleContract,
        bool authorized
    );

    modifier onlyPreSaleManager() {
        require(presaleContracts[msg.sender], "Not authorized");
        _;
    }

    function initialize(address _token) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        require(_token != address(0), "Invalid token address");
        token = IERC20Upgradeable(_token);
    }

    function setPresaleContract(
        address _presaleContract,
        bool _authorized
    ) external onlyOwner {
        require(_presaleContract != address(0), "Invalid presale contract");
        presaleContracts[_presaleContract] = _authorized;
        emit PresaleContractUpdated(_presaleContract, _authorized);
    }

    // Function for public sale deposits (no vesting)
    function depositPublicSale(
        address _beneficiary,
        uint256 _amount
    ) external whenNotPaused {
        require(presaleContracts[msg.sender], "Not authorized presale");
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_amount > 0, "Amount must be > 0");

        token.safeTransferFrom(msg.sender, address(this), _amount);
        publicSaleDeposits[_beneficiary] += _amount;

        emit PublicSaleDeposit(_beneficiary, _amount);
    }

    // Function to enable/disable public sale withdrawals (only presale can call)
    function setPublicSaleWithdrawalsEnabled(bool _enabled) external onlyPreSaleManager {
        require(presaleContracts[msg.sender], "Not authorized presale");
        publicSaleWithdrawalsEnabled = _enabled;
        emit PublicSaleWithdrawalsStatusUpdated(_enabled);
    }

    // Function for public sale withdrawals
    function withdrawPublicSale(
        address _beneficiary
    ) external nonReentrant whenNotPaused {
        require(presaleContracts[msg.sender], "Not authorized");
        require(publicSaleWithdrawalsEnabled, "Withdrawals not enabled");
        require(publicSaleDeposits[_beneficiary] > 0, "No tokens to withdraw");

        uint256 amount = publicSaleDeposits[_beneficiary];
        publicSaleDeposits[_beneficiary] = 0;

        token.safeTransfer(_beneficiary, amount);
        emit PublicSaleWithdrawal(_beneficiary, amount);
    }

    // Add view function for public sale balances
    function getPublicSaleBalance(
        address _beneficiary
    ) external view returns (uint256) {
        return publicSaleDeposits[_beneficiary];
    }

    function deposit(
        address _beneficiary,
        uint256 _amount,
        uint256 _vestingPeriod,
        uint256 _tierId
    ) external whenNotPaused {
        require(presaleContracts[msg.sender], "Not authorized presale");
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(_amount > 0, "Amount must be > 0");
        require(
            _vestingPeriod >= MINIMUM_VESTING_DURATION,
            "Vesting period too short"
        );
        require(
            _vestingPeriod <= MAXIMUM_VESTING_DURATION,
            "Vesting period too long"
        );

        token.safeTransferFrom(msg.sender, address(this), _amount);

        VestingSchedule memory schedule = VestingSchedule({
            totalAmount: _amount,
            releasedAmount: 0,
            startTime: block.timestamp,
            duration: _vestingPeriod,
            cliffDuration: _vestingPeriod / 4, // 25% cliff period
            releaseInterval: 1 days,
            revoked: false,
            lastReleaseTime: 0,
            tierId: _tierId
        });

        vestingSchedules[_beneficiary].push(schedule);
        totalVestedAmount[_beneficiary] += _amount;

        emit VestingScheduleCreated(
            _beneficiary,
            _amount,
            block.timestamp,
            _vestingPeriod,
            schedule.cliffDuration,
            _tierId
        );
    }

    // Additional functions will continue in the next section...
    // Continuing TokenEscrow.sol...

    function release(
        uint256 _scheduleIndex
    ) external nonReentrant whenNotPaused returns (uint256) {
        VestingSchedule storage schedule = vestingSchedules[msg.sender][
            _scheduleIndex
        ];
        require(!schedule.revoked, "Schedule revoked");

        uint256 releasable = _computeReleasableAmount(schedule);
        require(releasable > 0, "No tokens to release");

        schedule.releasedAmount += releasable;
        schedule.lastReleaseTime = block.timestamp;
        totalVestedAmount[msg.sender] -= releasable;

        token.safeTransfer(msg.sender, releasable);
        emit TokensReleased(
            msg.sender,
            releasable,
            _scheduleIndex,
            block.timestamp
        );

        return releasable;
    }

    function _computeReleasableAmount(
        VestingSchedule memory _schedule
    ) internal view returns (uint256) {
        if (block.timestamp < _schedule.startTime + _schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= _schedule.startTime + _schedule.duration) {
            return _schedule.totalAmount - _schedule.releasedAmount;
        }

        uint256 timeFromStart = block.timestamp - _schedule.startTime;
        uint256 vestedAmount = (_schedule.totalAmount * timeFromStart) /
            _schedule.duration;
        return vestedAmount - _schedule.releasedAmount;
    }

    function revokeVesting(
        address _beneficiary,
        uint256 _scheduleIndex
    ) external onlyOwner {
        VestingSchedule storage schedule = vestingSchedules[_beneficiary][
            _scheduleIndex
        ];
        require(!schedule.revoked, "Already revoked");

        uint256 releasable = _computeReleasableAmount(schedule);
        if (releasable > 0) {
            schedule.releasedAmount += releasable;
            totalVestedAmount[_beneficiary] -= releasable;
            token.safeTransfer(_beneficiary, releasable);
        }

        uint256 remaining = schedule.totalAmount - schedule.releasedAmount;
        if (remaining > 0) {
            token.safeTransfer(owner(), remaining);
        }

        schedule.revoked = true;
        emit VestingRevoked(
            _beneficiary,
            _scheduleIndex,
            remaining,
            block.timestamp
        );
    }

    function getVestingInfo(
        address _beneficiary
    )
        external
        view
        returns (
            uint256[] memory totalAmounts,
            uint256[] memory releasedAmounts,
            uint256[] memory startTimes,
            uint256[] memory durations,
            bool[] memory revoked
        )
    {
        VestingSchedule[] storage schedules = vestingSchedules[_beneficiary];
        uint256 length = schedules.length;

        totalAmounts = new uint256[](length);
        releasedAmounts = new uint256[](length);
        startTimes = new uint256[](length);
        durations = new uint256[](length);
        revoked = new bool[](length);

        for (uint256 i = 0; i < length; i++) {
            totalAmounts[i] = schedules[i].totalAmount;
            releasedAmounts[i] = schedules[i].releasedAmount;
            startTimes[i] = schedules[i].startTime;
            durations[i] = schedules[i].duration;
            revoked[i] = schedules[i].revoked;
        }
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

contract TokenVesting is Ownable, ReentrancyGuard  {
    using SafeERC20 for IERC20;

    /// @notice The ERC20 token being vested
    IERC20 public token;
    
    struct VestingSchedule {
        uint256 cliff; // cliff time of the vesting start in seconds since the UNIX epoch
        uint256 duration; // duration of the vesting period in seconds
        uint256 start; // start time of the vesting period in seconds since the UNIX epoch
        uint256 totalAmount; // total amount of tokens to be released at the end of the vesting
        uint256 released;  // amount of tokens released
        uint8 tgePercentage; // percentage of tokens to be released at TGE (0-100)
    }

    /// @notice The timestamp when the token generation event (TGE) occurs
    uint256 public tgetime;

    /// @notice Total value of tokens locked in the contract
    uint256 public tvl; // total value locked

    /// @notice Mapping of beneficiary addresses to their vesting schedule
    mapping(address => VestingSchedule) public vestingSchedules;

    event TokensReleased(address indexed beneficiary, uint256 amount, uint256 indexed timestamp);
    event TGEtime(uint256 new_tge_time);
    event AddedVestingSchedule(
        address indexed beneficiary, 
        uint256 cliff, 
        uint256 duration, 
        uint256 start, 
        uint256 totalAmount, 
        uint8 tgePercentage
    );
    event ChangedBeneficiaryAddress(address indexed lost_address, address indexed new_address);

    // Add constant for seconds in a month (30 days)
    uint256 private constant SECONDS_PER_MONTH = 30 days;

    constructor(address token_address) Ownable(msg.sender) {

        require(token_address != address(0), "Token address can not be zero");

        token = IERC20(token_address);
    }

    /// @notice Sets the TGE (Token Generation Event) time
    /// @param new_tge_time The timestamp for the TGE
    /// @dev Can only be set once by the contract owner
    function setTGEtime(uint256 new_tge_time) external onlyOwner{
        require(tgetime == 0, "TGE has already set");
        tgetime = new_tge_time;
        emit TGEtime(new_tge_time);
    }

    /// @notice Creates a new vesting schedule for a beneficiary
    /// @param beneficiary The address that will receive the tokens
    /// @param cliffMonths The duration in months before tokens begin vesting
    /// @param durationMonths The total duration of the vesting period in months
    /// @param start The start time of the vesting period
    /// @param totalAmount The total amount of tokens to be vested
    /// @param tgePercentage Percentage of tokens to be released at TGE (0-100)
    function addVestingSchedule(
        address beneficiary,
        uint256 cliffMonths,
        uint256 durationMonths,
        uint256 start,
        uint256 totalAmount,
        uint8 tgePercentage
    ) external onlyOwner {
        require(tgetime > 0, "TGE time is not set");
        require(start >= tgetime, "Start time should be greater or equal than TGE time");
        require(durationMonths > 0, "Duration should be positive");
        require(cliffMonths <= durationMonths, "Cliff should not exceed duration");
        require(totalAmount > 0, "Total amount must be greater than 0");
        require(beneficiary != address(0), "Beneficiary address can not be zero");
        require(tgePercentage <= 100, "TGE percentage must be between 0 and 100");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Vesting schedule already exists for beneficiary");

        // Convert months to seconds
        uint256 cliffSeconds = cliffMonths * SECONDS_PER_MONTH;
        uint256 durationSeconds = durationMonths * SECONDS_PER_MONTH;

        uint totalTokensOfSmartContract = token.balanceOf(address(this));
        uint availableTokensOfSmartContract = totalTokensOfSmartContract - tvl;

        require(totalAmount <= availableTokensOfSmartContract, "The smart contract does not have enough tokens");

        vestingSchedules[beneficiary] = VestingSchedule({
            cliff: cliffSeconds,
            duration: durationSeconds,
            start: start,
            totalAmount: totalAmount,
            released: 0,
            tgePercentage: tgePercentage
        });

        tvl += totalAmount;

        emit AddedVestingSchedule(beneficiary, cliffSeconds, durationSeconds, start, totalAmount, tgePercentage);
    }

    /// @notice Allows beneficiary to claim their vested tokens
    /// @dev Transfers all available tokens that have vested to the caller
    function claim() external nonReentrant {
        
        uint256 unreleased = prepareAvailableTokensForRelease(msg.sender);

        require(unreleased > 0, "No tokens are due for release");

        token.safeTransfer(msg.sender, unreleased);

        tvl -= unreleased;
    }

    /// @notice Returns the total amount of tokens already released for a beneficiary
    /// @param beneficiary The address to check
    /// @return The amount of tokens already released
    function getReleasedTokens(address beneficiary) external view returns(uint256) {
        return vestingSchedules[beneficiary].released;
    }

    /// @notice Returns the amount of tokens that are currently available to claim
    /// @param beneficiary The address to check
    /// @return The amount of tokens available to claim
    function getAvailableTokens(address beneficiary) external view returns(uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];
        
        if (schedule.totalAmount == 0) {
            return 0;
        }

        uint256 vestedAmount = calculateVestedAmount(schedule);
        return vestedAmount - schedule.released;
    }

    /// @notice Internal function to prepare tokens for release
    /// @param beneficiary The address for which to prepare tokens
    /// @return The amount of tokens prepared for release
    function prepareAvailableTokensForRelease(address beneficiary) internal returns(uint256) {
        VestingSchedule storage schedule = vestingSchedules[beneficiary];

        if (schedule.totalAmount == 0) {
            return 0;
        }

        uint256 vestedAmount = calculateVestedAmount(schedule);
        uint256 releaseable = vestedAmount - schedule.released;
        
        if (releaseable > 0) {
            schedule.released = schedule.released + releaseable;
            emit TokensReleased(msg.sender, releaseable, block.timestamp);
        }

        return releaseable;
    }

    /// @notice Calculates the amount of tokens that have vested for a schedule
    /// @param schedule The vesting schedule to calculate for
    /// @return The amount of tokens that have vested
    function calculateVestedAmount(VestingSchedule storage schedule) internal view returns (uint256) {
        uint256 currentTimestamp = block.timestamp;
        
        // Calculate TGE amount
        uint256 tgeAmount = (schedule.totalAmount * schedule.tgePercentage) / 100;
        
        // If before TGE, nothing is vested
        if (currentTimestamp < tgetime) {
            return 0;
        }
        
        // After TGE, TGE amount is immediately available
        if (currentTimestamp < schedule.start + schedule.cliff) {
            return tgeAmount;
        }
        
        // If after vesting period, everything is vested
        if (currentTimestamp >= schedule.start + schedule.duration) {
            return schedule.totalAmount;
        }
        
        // Calculate completed months since start
        uint256 monthsSinceStart = (currentTimestamp - schedule.start) / SECONDS_PER_MONTH;
        uint256 totalMonths = schedule.duration / SECONDS_PER_MONTH;
        
        // Calculate the linearly vested amount based on completed months
        uint256 remainingAmount = schedule.totalAmount - tgeAmount;
        uint256 monthlyVestingAmount = remainingAmount * monthsSinceStart / totalMonths;
        
        return tgeAmount + monthlyVestingAmount;
    }

    /// @notice This function is intended in case the beneficiary loses his wallet
    /// @dev No minting of additional tokens or premature unlocking of existing ones. Only the beneficiary's address can be replaced while maintaining the current state of token locking
    /// @param lost_address - an old address, which will be replaced
    /// @param new_address - a new address, which will be set 
    function changeBeneficiaryAddress(address lost_address, address new_address) external onlyOwner {
        require(new_address != address(0), "New address cannot be zero");
        require(vestingSchedules[new_address].totalAmount == 0, "New address already has a vesting schedule");
        
        vestingSchedules[new_address] = vestingSchedules[lost_address];
        delete vestingSchedules[lost_address];

        emit ChangedBeneficiaryAddress(lost_address, new_address);
    }

    /// @notice Allows owner to withdraw any accidentally sent tokens (except vesting token)
    /// @param _token The token contract to withdraw
    /// @param _amount The amount of tokens to withdraw
    /// @dev Cannot withdraw the vesting token to protect beneficiaries
    function emergencyWithdraw(IERC20 _token, uint256 _amount) external onlyOwner {
        require(_amount > 0, "Amount must be greater than 0");
        
        uint256 balance = _token.balanceOf(address(this));
        require(balance >= _amount, "Insufficient balance");
        
        _token.safeTransfer(owner(), _amount);
    }
}
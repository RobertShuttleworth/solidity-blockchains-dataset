// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Ownable2Step, Ownable} from "./lib_openzeppelin-contracts_contracts_access_Ownable2Step.sol";
import {SafeTransferLib} from "./lib_solbase_src_utils_SafeTransferLib.sol";
import {Errors} from "./src_libs_Errors.sol";
import {Philcoin} from "./src_token_Philcoin.sol";

/// @title FoundationVesting
/// @notice This contract handles the vesting of Philcoin tokens for the Foundation allocation.
/// @dev The contract includes a 12-month cliff period followed by 24 months of linear vesting and 50% release at TGE.
/// The contract ensures that tokens are only released to the beneficiary according to the vesting schedule.
contract FoundationVesting is Ownable2Step {
    /// @notice The Philcoin token contract.
    Philcoin public immutable philcoin;

    /// @notice The address of the beneficiary.
    address public beneficiary;

    /// @notice The total amount of tokens released so far.
    uint256 public released;

    /// @notice The amount of tokens initially released at TGE.
    uint256 public initialReleaseAmount;

    /// @notice The start time of the vesting period.
    uint64 public immutable start;

    /// @notice The end of the cliff period.
    uint64 public immutable cliff;

    /// @notice The duration of the vesting period in seconds.
    uint64 public immutable duration;

    /// @notice Emitted when tokens are released.
    /// @param sender The address of the sender.
    /// @param beneficiary The address of the beneficiary.
    /// @param releasedAmount The amount of tokens released.
    event TokensReleased(address indexed sender, address indexed beneficiary, uint256 releasedAmount);

    /// @notice Emitted when the initial tokens are released at TGE.
    /// @param beneficiary The address of the beneficiary.
    /// @param initialReleaseAmount The amount of tokens released.
    event InitialTokensReleased(address indexed beneficiary, uint256 initialReleaseAmount);

    /// @notice Emitted when the beneficiary address is updated.
    /// @param beneficiary The new beneficiary address.
    event BeneficiaryUpdated(address beneficiary);

    /// @notice Initializes the vesting contract with the given parameters.
    /// @param _philcoin The address of the Philcoin token contract.
    /// @param _owner The address of the owner account.
    /// @param _beneficiary The address of the beneficiary.
    /// @param _start The time when the initial release happens (TGE) and the beginning of the vesting period that follows.
    /// @param _cliff The duration of the cliff period in seconds.
    /// @param _duration The duration of the entire vesting period in seconds, including the cliff.
    /// @param _initialReleaseAmount The amount of tokens to be released at TGE.
    constructor(
        address _philcoin,
        address _owner,
        address _beneficiary,
        uint64 _start,
        uint64 _cliff,
        uint64 _duration,
        uint256 _initialReleaseAmount
    ) Ownable2Step() Ownable(_owner) {
        if (_philcoin == address(0) || _beneficiary == address(0)) revert Errors.ZeroAddressProvided();
        if (_start == 0 || _start < block.timestamp || _duration < 365 days || _cliff > _duration) {
            revert Errors.InvalidVestingTimestamp();
        }

        philcoin = Philcoin(_philcoin);
        beneficiary = _beneficiary;
        start = _start;
        cliff = _start + _cliff;
        duration = _duration;
        released = 0;
        initialReleaseAmount = _initialReleaseAmount;
    }

    /// @notice Releases the vested tokens to the beneficiary.
    /// @dev Reverts if the current time is before the cliff period has ended or if there are no tokens to release.
    function release() external {
        if (uint64(block.timestamp) < cliff) revert Errors.CliffPeriodNotReached();

        uint256 unreleased = releasableAmount();
        if (unreleased == 0) revert Errors.NoTokensToRelease();

        if (uint64(block.timestamp) >= end()) {
            unreleased = philcoin.balanceOf(address(this)); // Force release of all remaining tokens.
        }

        released += unreleased;
        SafeTransferLib.safeTransfer(address(philcoin), beneficiary, unreleased);

        emit TokensReleased(msg.sender, beneficiary, unreleased);
    }

    /// @notice Calculates the amount of tokens that can be released at the current time.
    /// @return The amount of tokens that can be released.
    function releasableAmount() public view returns (uint256) {
        return vestedAmount() - released;
    }

    /// @notice Calculates the total amount of tokens that have vested up to the current time.
    /// @return The amount of tokens that have vested.
    function vestedAmount() public view returns (uint256) {
        uint256 totalAllocation = philcoin.balanceOf(address(this)) + released;

        if (uint64(block.timestamp) < start) {
            // No tokens are vested before the start time
            return 0;
        } else if (uint64(block.timestamp) >= start && uint64(block.timestamp) < cliff) {
            // During the period between start and cliff, only the initial release amount is vested
            return initialReleaseAmount;
        } else if (uint64(block.timestamp) >= end()) {
            // After the vesting period ends, all tokens are vested
            return totalAllocation;
        } else {
            // During the vesting period, calculate the vested amount linearly
            uint256 vested = initialReleaseAmount
                + (totalAllocation - initialReleaseAmount) * (uint64(block.timestamp) - cliff)
                    / (duration - (cliff - start));
            return vested;
        }
    }

    /// @notice Returns the end time of the vesting period.
    /// @return The end time of the vesting period.
    function end() public view returns (uint256) {
        return start + duration;
    }

    /// @notice Releases the initial tokens at TGE.
    /// @dev Reverts if the current time is before the start time or if the initial release has already been done.
    function initialReleaseTokens() public onlyOwner {
        if (uint64(block.timestamp) < start) revert Errors.InitialReleaseNotStartedYet();
        if (released != 0) revert Errors.InitialReleaseAlreadyDone();

        released += initialReleaseAmount;
        SafeTransferLib.safeTransfer(address(philcoin), beneficiary, initialReleaseAmount);
        emit InitialTokensReleased(beneficiary, initialReleaseAmount);
    }

    /// @notice Updates the beneficiary address.
    /// @param _beneficiary The new beneficiary address.
    function updateBeneficiary(address _beneficiary) external onlyOwner {
        if (_beneficiary == address(0)) revert Errors.ZeroAddressProvided();
        beneficiary = _beneficiary;
        emit BeneficiaryUpdated(_beneficiary);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OwnableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_utils_SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_security_ReentrancyGuardUpgradeable.sol";

import { IHMXStaking } from "./src_staking_interfaces_IHMXStaking.sol";
import { ILHMXVester } from "./src_vesting_interfaces_ILHMXVester.sol";

/// @title LFDXVester - Vesting contract for LFDX tokens.
contract LFDXVester is OwnableUpgradeable, ReentrancyGuardUpgradeable, ILHMXVester {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /**
   * Events
   */
  event LogSetEndCliffTimestamp(uint256 oldValue, uint256 newValue);
  event LogSetHmxStaking(address oldValue, address newValue);
  event LogClaim(address indexed account, uint256 claimableAmount, uint256 claimAmount);

  /**
   * Errors
   */
  error LFDXVester_InsufficientClaimableAmount();
  error LFDXVester_NotEnoughAvailableLFDX();

  /**
   * States
   */
  IERC20Upgradeable public fdx;
  IERC20Upgradeable public lfdx;
  IHMXStaking public fdxStaking;

  mapping(address => uint256) public userClaimedAmount;
  uint256 public endCliffTimestamp;
  uint256 public vestingPeriodSec;
  uint256 public vestingPeriodAmount;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Constructor.
  /// @param _fdxAddress The address of the FDX token contract.
  /// @param _lfdxAddress The address of the LFDX token contract.
  /// @param _endCliffTimestamp The timestamp when the lock period ends.
  function initialize(
    address _fdxAddress,
    address _lfdxAddress,
    uint256 _endCliffTimestamp,
    uint256 _vestingPeriodSec,
    uint256 _vestingPeriodAmount
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    require(_endCliffTimestamp > block.timestamp, "bad timestamp");
    require(_vestingPeriodSec > 0 && _vestingPeriodAmount > 0, "bad vest period");

    fdx = IERC20Upgradeable(_fdxAddress);
    lfdx = IERC20Upgradeable(_lfdxAddress);

    endCliffTimestamp = _endCliffTimestamp;
    vestingPeriodSec = _vestingPeriodSec;
    vestingPeriodAmount = _vestingPeriodAmount;

    // Santy checks
    fdx.totalSupply();
    lfdx.totalSupply();
  }

  /// @dev Claims LFDX tokens for the sender.
  /// @param amount The amount of LFDX tokens to claim.
  function claimFor(uint256 amount) external nonReentrant {
    address account = msg.sender;

    // Check
    if (amount > lfdx.balanceOf(account)) revert LFDXVester_NotEnoughAvailableLFDX();
    uint256 claimable = _getUnlockAmount(account) - userClaimedAmount[account];
    if (amount > claimable) revert LFDXVester_InsufficientClaimableAmount();

    // Effect
    // Update the claimed amount for the user
    userClaimedAmount[account] += amount;

    // Interaction
    // Transfer LFDX tokens from the user to address(0xdead)
    lfdx.safeTransferFrom(account, address(0xdead), amount);
    // Transfer FDX tokens from this contract to the user with the same amount
    fdx.safeTransfer(account, amount);

    emit LogClaim(account, claimable, amount);
  }

  /**
   * Setter
   */

  /// @notice Sets the end cliff timestamp.
  /// @param _endCliffTimestamp The timestamp when the lock period ends.
  function setEndCliffTimestamp(uint256 _endCliffTimestamp) external onlyOwner {
    require(block.timestamp < endCliffTimestamp, "passed");
    emit LogSetEndCliffTimestamp(endCliffTimestamp, _endCliffTimestamp);
    endCliffTimestamp = _endCliffTimestamp;
  }

  /// @notice Sets the FDX staking contract address.
  /// @dev Allow to set FDX staking after deployment because LFDXVester is deployed before FDXStaking.
  /// @param _fdxStaking The address of the FDX staking contract.
  function setHmxStaking(address _fdxStaking) external onlyOwner {
    emit LogSetHmxStaking(address(fdxStaking), _fdxStaking);
    fdxStaking = IHMXStaking(_fdxStaking);
  }

  /**
   * Getters
   */

  function getClaimableHmx(address account) external view returns (uint256) {
    return _getUnlockAmount(account) - userClaimedAmount[account];
  }

  function getUserClaimedAmount(address account) external view returns (uint256) {
    return userClaimedAmount[account];
  }

  function getTotalLFDXAmount(address account) external view returns (uint256 amount) {
    return _getTotalLFDXAmount(account);
  }

  function getTotalLHMXAmount(address account) external view returns (uint256 amount) {
    return _getTotalLFDXAmount(account);
  }

  function _getTotalLFDXAmount(address account) internal view returns (uint256 amount) {
    return
      lfdx.balanceOf(account) +
      fdxStaking.getUserTokenAmount(address(lfdx), account) +
      userClaimedAmount[account];
  }

  function getUnlockAmount(address account) external view returns (uint256) {
    return _getUnlockAmount(account);
  }

  /// @dev Retrieves the unlock amount for a given account.
  /// @param account The address of the account.
  /// @return The unlock amount for the account.
  function _getUnlockAmount(address account) internal view returns (uint256) {
    // The total unlock amount is calculated based on the elapsed time since LFDX deployment,
    // starting from 6 months after deployment and divided into 18 equal monthly unlock periods.
    // The unlock amount is determined by multiplying the total LFDX amount by the elapsed months
    // and dividing it by 18.

    // If the current timestamp is before the end of the lock period, the unlock amount is 0.
    if (block.timestamp < endCliffTimestamp) {
      return 0;
    }

    uint256 totalAmount = _getTotalLFDXAmount(account);

    // Calculate the elapsed months since the end of the lock period.
    uint256 elapsedPeriods = (block.timestamp - endCliffTimestamp) / vestingPeriodSec;

    // Calculate the unlock amount by dividing the total LFDX amount by 18 and multiplying
    // it by the elapsed months.
    return elapsedPeriods >= vestingPeriodAmount ? totalAmount : (totalAmount * elapsedPeriods) / vestingPeriodAmount;
  }

}
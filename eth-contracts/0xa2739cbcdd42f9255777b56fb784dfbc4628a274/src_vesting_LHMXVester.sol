// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OwnableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_utils_SafeERC20Upgradeable.sol";
import { ReentrancyGuardUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_security_ReentrancyGuardUpgradeable.sol";

import { IHMXStaking } from "./src_staking_interfaces_IHMXStaking.sol";
import { ILHMXVester } from "./src_vesting_interfaces_ILHMXVester.sol";

/// @title LHMXVester - Vesting contract for LHMX tokens.
contract LHMXVester is OwnableUpgradeable, ReentrancyGuardUpgradeable, ILHMXVester {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  uint256 private constant ONE_MONTH_TIMESTAMP = 30 days;

  /**
   * Events
   */
  event LogSetEndCliffTimestamp(uint256 oldValue, uint256 newValue);
  event LogSetHmxStaking(address oldValue, address newValue);
  event LogClaim(address indexed account, uint256 claimableAmount, uint256 claimAmount);

  /**
   * Errors
   */
  error LHMXVester_InsufficientClaimableAmount();
  error LHMXVester_NotEnoughAvailableLHMX();

  /**
   * States
   */
  IERC20Upgradeable public hmx;
  IERC20Upgradeable public lhmx;
  IHMXStaking public hmxStaking;

  mapping(address => uint256) public userClaimedAmount;
  uint256 public endCliffTimestamp;

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Constructor.
  /// @param _hmxAddress The address of the HMX token contract.
  /// @param _lhmxAddress The address of the LHMX token contract.
  /// @param _endCliffTimestamp The timestamp when the lock period ends.
  function initialize(
    address _hmxAddress,
    address _lhmxAddress,
    uint256 _endCliffTimestamp
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    require(_endCliffTimestamp > block.timestamp, "bad timestamp");

    hmx = IERC20Upgradeable(_hmxAddress);
    lhmx = IERC20Upgradeable(_lhmxAddress);

    endCliffTimestamp = _endCliffTimestamp;

    // Santy checks
    hmx.totalSupply();
    lhmx.totalSupply();
  }

  /// @dev Claims LHMX tokens for the sender.
  /// @param amount The amount of LHMX tokens to claim.
  function claimFor(uint256 amount) external nonReentrant {
    address account = msg.sender;

    // Check
    if (amount > lhmx.balanceOf(account)) revert LHMXVester_NotEnoughAvailableLHMX();
    uint256 claimable = _getUnlockAmount(account) - userClaimedAmount[account];
    if (amount > claimable) revert LHMXVester_InsufficientClaimableAmount();

    // Effect
    // Update the claimed amount for the user
    userClaimedAmount[account] += amount;

    // Interaction
    // Transfer LHMX tokens from the user to address(0xdead)
    lhmx.safeTransferFrom(account, address(0xdead), amount);
    // Transfer HMX tokens from this contract to the user with the same amount
    hmx.safeTransfer(account, amount);

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

  /// @notice Sets the HMX staking contract address.
  /// @dev Allow to set HMX staking after deployment because LHMXVester is deployed before HMXStaking.
  /// @param _hmxStaking The address of the HMX staking contract.
  function setHmxStaking(address _hmxStaking) external onlyOwner {
    emit LogSetHmxStaking(address(hmxStaking), _hmxStaking);
    hmxStaking = IHMXStaking(_hmxStaking);
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

  function getTotalLHMXAmount(address account) external view returns (uint256 amount) {
    return _getTotalLHMXAmount(account);
  }

  function _getTotalLHMXAmount(address account) internal view returns (uint256 amount) {
    return
      lhmx.balanceOf(account) +
      hmxStaking.getUserTokenAmount(address(lhmx), account) +
      userClaimedAmount[account];
  }

  function getUnlockAmount(address account) external view returns (uint256) {
    return _getUnlockAmount(account);
  }

  /// @dev Retrieves the unlock amount for a given account.
  /// @param account The address of the account.
  /// @return The unlock amount for the account.
  function _getUnlockAmount(address account) internal view returns (uint256) {
    // The total unlock amount is calculated based on the elapsed time since LHMX deployment,
    // starting from 6 months after deployment and divided into 18 equal monthly unlock periods.
    // The unlock amount is determined by multiplying the total LHMX amount by the elapsed months
    // and dividing it by 18.

    // If the current timestamp is before the end of the lock period, the unlock amount is 0.
    if (block.timestamp < endCliffTimestamp) {
      return 0;
    }

    uint256 totalAmount = _getTotalLHMXAmount(account);

    // Calculate the elapsed months since the end of the lock period.
    uint256 elapsedMonths = (block.timestamp - endCliffTimestamp) / ONE_MONTH_TIMESTAMP;

    // Calculate the unlock amount by dividing the total LHMX amount by 18 and multiplying
    // it by the elapsed months.
    return elapsedMonths >= 18 ? totalAmount : (totalAmount * elapsedMonths) / 18;
  }
}
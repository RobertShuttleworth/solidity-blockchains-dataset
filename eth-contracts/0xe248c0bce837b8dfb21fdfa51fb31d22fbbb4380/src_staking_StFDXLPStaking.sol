// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import { IERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_utils_SafeERC20Upgradeable.sol";

import { IRewarder } from "./src_staking_interfaces_IRewarder.sol";
import { MintableTokenInterface } from "./src_staking_interfaces_MintableTokenInterface.sol";
import { IStaking } from "./src_staking_interfaces_IStaking.sol";

interface IStakingExtended is IStaking {
  function processDragonPointBeforeWithdraw(address user) external;

  function processDragonPointAfterWithdraw(
    address user,
    uint256 shareBefore,
    uint256 shareAfter
  ) external;

  function getTotalShareInFdxFromAllStakings(address) external view returns (uint256);
}

/// @title LP Staking Contract for multiple reward distributions
/// @author Flex Trade Dev team
/// @notice Stake LP token to get Protocol Revenues, esFDX and Flex Points
/// @dev Explain to a developer any extra details
contract StFDXLPStaking is OwnableUpgradeable, IStaking {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  // Events
  event LogAddRewarder(address newRewarder);
  event LogDeposit(address indexed caller, address indexed user, address token, uint256 amount);
  event LogWithdraw(address indexed caller, address token, uint256 amount);
  event LogSetIsCompounder(address compounder, bool isCompounder);

  // Errors
  error StFDXLPStaking_InvalidTokenAmount();
  error StFDXLPStaking_InsufficientTokenAmount();
  error StFDXLPStaking_NotRewarder();
  error StFDXLPStaking_NotCompounder();
  error StFDXLPStaking_InconsistentLength();
  error StFDXLPStaking_InvalidAddress();

  /**
   * @dev State variables
   */

  /// @notice The LP token (FDX/ETH LP) used for staking
  address public stakingToken;

  /// @notice The address of FDXStaking Smart Contract
  address public fdxStaking;

  /// @notice Contract that handles minting of stFDXLP tokens
  MintableTokenInterface public stFDXLP;

  /// @notice Mapping to track user's staking amount
  mapping(address => uint256) public userTokenAmount;

  /// @notice List of rewarder addresses
  address[] public rewarders;

  /// @notice Mapping to track if an address is a registered rewader
  mapping(address => bool) public isRewarder;

  /// @notice Mapping to track if an address is an approved compounder.
  mapping(address compounder => bool isAllowed) public isCompounder;

  /**
   * @dev Initializes the contract.
   * @param stakingToken_ The address of the staking token (FDX/ETH LP).
   * @param stFDXLP_ The address of the stFDXLP mintable token contract.
   */
  function initialize(
    address stakingToken_,
    address stFDXLP_,
    address fdxStaking_
  ) external initializer {
    OwnableUpgradeable.__Ownable_init();
    stakingToken = stakingToken_;
    stFDXLP = MintableTokenInterface(stFDXLP_);
    fdxStaking = fdxStaking_;

    // Sanity check
    ERC20Upgradeable(stakingToken).decimals();
    ERC20Upgradeable(stFDXLP_).decimals();
  }

  /**
   * @dev Admin Functions
   */

  /// @notice Adds a new rewarder contract to the list of rewarders.
  /// @param newRewarder The address of the new rewarder to add.
  /// @dev This function ensures that the rewarder is not already added before appending it.
  function addRewarder(address newRewarder) external onlyOwner {
    if (!_isDuplicatedRewarder(newRewarder)) {
      rewarders.push(newRewarder);
    }

    if (!isRewarder[newRewarder]) {
      isRewarder[newRewarder] = true;
    }

    emit LogAddRewarder(newRewarder);
  }

  /// @notice Removes a rewarder from the rewarder list by its index.
  /// @param removeRewarderIndex The index of the rewarder to remove from the list.
  function removeRewarderByIndex(uint256 removeRewarderIndex) external onlyOwner {
    address rewarderToRemove = rewarders[removeRewarderIndex];

    rewarders[removeRewarderIndex] = rewarders[rewarders.length - 1];
    rewarders.pop();

    isRewarder[rewarderToRemove] = false;
  }

  /// @notice Updates the compounder status for a list of compounders.
  /// @param compounders The list of addresses to update the compounder status for.
  /// @param isAllowed The list of corresponding statuses (true or false) for each address.
  /// @dev Allows the owner to approve or disapprove compounders.
  function setIsCompounders(
    address[] memory compounders,
    bool[] memory isAllowed
  ) external onlyOwner {
    uint256 length = compounders.length;
    if (length != isAllowed.length) revert StFDXLPStaking_InconsistentLength();

    for (uint256 i; i < length; ) {
      if (compounders[i] == address(0)) revert StFDXLPStaking_InvalidAddress();

      isCompounder[compounders[i]] = isAllowed[i];
      emit LogSetIsCompounder(compounders[i], isAllowed[i]);
      unchecked {
        ++i;
      }
    }
  }

  /**
   * @dev User Functions
   */

  /// @notice Deposits staking tokens for a specified user and triggers rewarder's `onDeposit` function.
  /// @param account The address of the user depositing tokens.
  /// @param token The address of the token being deposited.
  /// @param amount The amount of tokens being deposited.
  /// @dev Calls `onDeposit` for each associated rewarder and mints stFDXLP tokens to the user.
  function deposit(address account, address token, uint256 amount) external {
    _deposit(account, amount);
  }

  /// @notice Internal function to handle the deposit logic.
  /// @param account The address of the user depositing tokens.
  /// @param amount The amount of tokens being deposited.
  function _deposit(address account, uint256 amount) internal {
    if (amount == 0) revert StFDXLPStaking_InvalidTokenAmount();

    // Call each associated rewarder's `onDeposit` function.
    for (uint256 i = 0; i < rewarders.length; ) {
      IRewarder(rewarders[i]).onDeposit(account, amount);
      unchecked {
        ++i;
      }
    }

    IERC20Upgradeable(stakingToken).safeTransferFrom(msg.sender, address(this), amount);

    // Increase user balance
    userTokenAmount[account] += amount;

    // Mint stFDXLP token to user
    stFDXLP.mint(account, amount);

    emit LogDeposit(msg.sender, account, stakingToken, amount);
  }

  /// @notice Withdraws an amount of staking tokens for the caller.
  /// @param amount The amount of tokens to withdraw.
  function withdraw(uint256 amount) public {
    IStakingExtended(fdxStaking).processDragonPointBeforeWithdraw(msg.sender);
    uint256 shareBefore = IStakingExtended(fdxStaking).getTotalShareInFdxFromAllStakings(msg.sender);
    _withdraw(msg.sender, amount);
    uint256 shareAfter = IStakingExtended(fdxStaking).getTotalShareInFdxFromAllStakings(msg.sender);
    IStakingExtended(fdxStaking).processDragonPointAfterWithdraw(
      msg.sender,
      shareBefore,
      shareAfter
    );
  }

  /// @notice Internal function to handle the withdrawal logic.
  /// @param user The address of the user withdrawing tokens.
  /// @param amount The amount of tokens being withdrawn.
  function _withdraw(address user, uint256 amount) internal {
    if (amount == 0) revert StFDXLPStaking_InvalidTokenAmount();

    // Ensure the user has enough tokens to withdraw
    if (userTokenAmount[user] < amount) revert StFDXLPStaking_InsufficientTokenAmount();

    // Call each associated rewarder's `onWithdraw` function.
    uint256 length = rewarders.length;
    for (uint256 i = 0; i < length; ) {
      address rewarder = rewarders[i];
      IRewarder(rewarder).onWithdraw(user, amount);
      unchecked {
        ++i;
      }
    }

    // Subtract the withdrawn amount and transfer the staking token
    userTokenAmount[user] -= amount;

    // Burn stFDXLP tokens
    stFDXLP.burn(user, amount);

    IERC20Upgradeable(stakingToken).safeTransfer(user, amount);

    emit LogWithdraw(user, stakingToken, amount);
  }

  /// @notice Harvests rewards for the calling user and transfers them to the caller.
  /// @param rewarders The array of rewarder addresses whose rewards are being harvested.
  /// @dev Calls `onHarvest` for each rewarder for the user and transfers rewards.
  function harvest(address[] memory rewarders) external {
    // Call the internal _harvestFor function with the same user as the receiver.
    _harvestFor(msg.sender, msg.sender, rewarders);
  }

  /// @notice Harvests rewards for a user and sends them to a compounder. Only compounder can call this function.
  /// @param user The address of the user whose rewards are being harvested.
  /// @param _rewarders The list of rewarder addresses to harvest from.
  function harvestToCompounder(address user, address[] memory _rewarders) external {
    if (!isCompounder[msg.sender]) revert StFDXLPStaking_NotCompounder();
    _harvestFor(user, msg.sender, _rewarders);
  }

  /// @notice Internal function to handle reward harvesting for a specific user and send the rewards to the receiver.
  /// @param user The address of the user whose rewards are being harvested.
  /// @param receiver The address to which the rewards will be sent.
  /// @param rewarders The list of rewarders to harvest rewards from.
  function _harvestFor(address user, address receiver, address[] memory rewarders) internal {
    uint256 length = rewarders.length;
    for (uint256 i = 0; i < length; ) {
      if (!isRewarder[rewarders[i]]) revert StFDXLPStaking_NotRewarder();

      IRewarder(rewarders[i]).onHarvest(user, receiver);
      unchecked {
        ++i;
      }
    }
  }

  /// @notice Calculates the share of the specified user in a given rewarder.
  /// @param rewarder The address of the rewarder contract.
  /// @param user The address of the user.
  /// @return share The share of the user in the rewarder, typically based on the user's stake.
  function calculateShare(address rewarder, address user) external view returns (uint256 share) {
    share = userTokenAmount[user];
  }

  /// @notice Calculates the total share of all users in a given rewarder.
  /// @param rewarder The address of the rewarder contract.
  /// @return totalShare The total share of all users in the rewarder.
  function calculateTotalShare(address rewarder) external view returns (uint256 totalShare) {
    totalShare = IERC20Upgradeable(stakingToken).balanceOf(address(this));
  }

  /**
   * @dev Getters
   */

  /// @notice Returns the list of rewarders for the staking token.
  /// @return rewarders The list of rewarder addresses.
  function getStakingTokenRewarders() external view returns (address[] memory) {
    return rewarders;
  }

  /**
   * @dev Private Functions
   */

  /// @notice Checks whether a given rewarder is already in the rewarder list.
  /// @param rewarder The address of the rewarder to check.
  /// @return bool True if the rewarder is already in the list, false otherwise.
  function _isDuplicatedRewarder(address rewarder) internal view returns (bool) {
    uint256 length = rewarders.length;
    for (uint256 i = 0; i < length; ) {
      if (rewarders[i] == rewarder) return true;
      unchecked {
        ++i;
      }
    }
    return false;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }
}
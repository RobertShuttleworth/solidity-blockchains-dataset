// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Initializable} from "./foundry-lib_solidity-utils_src_contracts_transparent-proxy_Initializable.sol";
import {ITypeAndVersion} from "./src_v0.8_shared_interfaces_ITypeAndVersion.sol";
import {IBurnMintERC20} from "./src_v0.8_shared_token_ERC20_IBurnMintERC20.sol";

import {UpgradeableTokenPool} from "./src_v0.8_ccip_pools_GHO_UpgradeableTokenPool.sol";
import {UpgradeableBurnMintTokenPoolAbstract} from "./src_v0.8_ccip_pools_GHO_UpgradeableBurnMintTokenPoolAbstract.sol";
import {RateLimiter} from "./src_v0.8_ccip_libraries_RateLimiter.sol";
import {IRouter} from "./src_v0.8_ccip_interfaces_IRouter.sol";

/// @title UpgradeableBurnMintTokenPool
/// @author Aave Labs
/// @notice Upgradeable version of Chainlink's CCIP BurnMintTokenPool
/// @dev Contract adaptations:
/// - Implementation of Initializable to allow upgrades
/// - Move of allowlist and router definition to initialization stage
/// - Inclusion of rate limit admin who may configure rate limits in addition to owner
/// - Addition of authorized function to to directly burn liquidity, thereby reducing the facilitator's bucket level.
/// - Modifications from inherited contract (see contract for more details):
///   - UpgradeableTokenPool: Modify `onlyOnRamp` & `onlyOffRamp` modifier to accept transactions from ProxyPool
contract UpgradeableBurnMintTokenPool is Initializable, UpgradeableBurnMintTokenPoolAbstract, ITypeAndVersion {
  error Unauthorized(address caller);

  string public constant override typeAndVersion = "BurnMintTokenPool 1.4.0";

  /// @notice The address of the rate limiter admin.
  /// @dev Can be address(0) if none is configured.
  address internal s_rateLimitAdmin;

  /// @dev Constructor
  /// @param token The bridgeable token that is managed by this pool.
  /// @param armProxy The address of the arm proxy
  /// @param allowlistEnabled True if pool is set to access-controlled mode, false otherwise
  constructor(
    address token,
    address armProxy,
    bool allowlistEnabled
  ) UpgradeableTokenPool(IBurnMintERC20(token), armProxy, allowlistEnabled) {}

  /// @dev Initializer
  /// @dev The address passed as `owner` must accept ownership after initialization.
  /// @dev The `allowlist` is only effective if pool is set to access-controlled mode
  /// @param owner The address of the owner
  /// @param allowlist A set of addresses allowed to trigger lockOrBurn as original senders
  /// @param router The address of the router
  function initialize(address owner, address[] memory allowlist, address router) public virtual initializer {
    if (owner == address(0) || router == address(0)) revert ZeroAddressNotAllowed();
    _transferOwnership(owner);

    s_router = IRouter(router);

    // Pool can be set as permissioned or permissionless at deployment time only to save hot-path gas.
    if (i_allowlistEnabled) {
      _applyAllowListUpdates(new address[](0), allowlist);
    }
  }

  /// @notice Sets the rate limiter admin address.
  /// @dev Only callable by the owner.
  /// @param rateLimitAdmin The new rate limiter admin address.
  function setRateLimitAdmin(address rateLimitAdmin) external onlyOwner {
    s_rateLimitAdmin = rateLimitAdmin;
  }

  /// @notice Gets the rate limiter admin address.
  function getRateLimitAdmin() external view returns (address) {
    return s_rateLimitAdmin;
  }

  /// @notice Sets the chain rate limiter config.
  /// @dev Only callable by the owner or the rate limiter admin. NOTE: overwrites the normal
  /// onlyAdmin check in the base implementation to also allow the rate limiter admin.
  /// @param remoteChainSelector The remote chain selector for which the rate limits apply.
  /// @param outboundConfig The new outbound rate limiter config.
  /// @param inboundConfig The new inbound rate limiter config.
  function setChainRateLimiterConfig(
    uint64 remoteChainSelector,
    RateLimiter.Config memory outboundConfig,
    RateLimiter.Config memory inboundConfig
  ) external override {
    if (msg.sender != s_rateLimitAdmin && msg.sender != owner()) revert Unauthorized(msg.sender);

    _setRateLimitConfig(remoteChainSelector, outboundConfig, inboundConfig);
  }

  /// @notice Burn an amount of tokens with no additional logic.
  /// @dev This GHO-specific functionality is designed for migrating bucket levels between
  /// facilitators. The new pool is expected to mint amount of tokens, while the old pool
  /// burns an equivalent amount. This ensures the facilitator can be offboarded, as all
  /// liquidity minted by it must be fully burned
  /// @param amount The amount of tokens to burn.
  function directBurn(uint256 amount) external onlyOwner {
    _burn(amount);
  }

  /// @inheritdoc UpgradeableBurnMintTokenPoolAbstract
  function _burn(uint256 amount) internal virtual override {
    IBurnMintERC20(address(i_token)).burn(amount);
  }
}
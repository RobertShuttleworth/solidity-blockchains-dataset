// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPool} from "./src_v0.8_ccip_interfaces_pools_IPool.sol";
import {IARM} from "./src_v0.8_ccip_interfaces_IARM.sol";
import {IRouter} from "./src_v0.8_ccip_interfaces_IRouter.sol";

import {OwnerIsCreator} from "./src_v0.8_shared_access_OwnerIsCreator.sol";
import {RateLimiter} from "./src_v0.8_ccip_libraries_RateLimiter.sol";

import {IERC20} from "./src_v0.8_vendor_openzeppelin-solidity_v4.8.3_contracts_token_ERC20_IERC20.sol";
import {IERC165} from "./src_v0.8_vendor_openzeppelin-solidity_v4.8.3_contracts_utils_introspection_IERC165.sol";
import {EnumerableSet} from "./src_v0.8_vendor_openzeppelin-solidity_v4.8.3_contracts_utils_structs_EnumerableSet.sol";

/// @title UpgradeableTokenPool
/// @author Aave Labs
/// @notice Upgradeable version of Chainlink's CCIP TokenPool
/// @dev Contract adaptations:
///   - Setters & Getters for new ProxyPool (to support 1.5 CCIP migration on the existing 1.4 Pool)
///   - Modify `onlyOnRamp` & `onlyOffRamp` modifier to accept transactions from ProxyPool
abstract contract UpgradeableTokenPool is IPool, OwnerIsCreator, IERC165 {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.UintSet;
  using RateLimiter for RateLimiter.TokenBucket;

  error CallerIsNotARampOnRouter(address caller);
  error ZeroAddressNotAllowed();
  error SenderNotAllowed(address sender);
  error AllowListNotEnabled();
  error NonExistentChain(uint64 remoteChainSelector);
  error ChainNotAllowed(uint64 remoteChainSelector);
  error BadARMSignal();
  error ChainAlreadyExists(uint64 chainSelector);

  event Locked(address indexed sender, uint256 amount);
  event Burned(address indexed sender, uint256 amount);
  event Released(address indexed sender, address indexed recipient, uint256 amount);
  event Minted(address indexed sender, address indexed recipient, uint256 amount);
  event ChainAdded(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );
  event ChainConfigured(
    uint64 remoteChainSelector,
    RateLimiter.Config outboundRateLimiterConfig,
    RateLimiter.Config inboundRateLimiterConfig
  );
  event ChainRemoved(uint64 remoteChainSelector);
  event AllowListAdd(address sender);
  event AllowListRemove(address sender);
  event RouterUpdated(address oldRouter, address newRouter);

  struct ChainUpdate {
    uint64 remoteChainSelector; // ──╮ Remote chain selector
    bool allowed; // ────────────────╯ Whether the chain is allowed
    RateLimiter.Config outboundRateLimiterConfig; // Outbound rate limited config, meaning the rate limits for all of the onRamps for the given chain
    RateLimiter.Config inboundRateLimiterConfig; // Inbound rate limited config, meaning the rate limits for all of the offRamps for the given chain
  }

  /// @dev The storage slot for Proxy Pool address, act as an on ramp "wrapper" post ccip 1.5 migration.
  /// @dev This was added to continue support for 1.2 onRamp during 1.5 migration, and is stored
  /// this way to avoid storage collision.
  // bytes32(uint256(keccak256("ccip.pools.GHO.UpgradeableTokenPool.proxyPool")) - 1)
  bytes32 internal constant PROXY_POOL_SLOT = 0x75bb68f1b335d4dab6963140ecff58281174ef4362bb85a8593ab9379f24fae2;

  /// @dev The bridgeable token that is managed by this pool.
  IERC20 internal immutable i_token;
  /// @dev The address of the arm proxy
  address internal immutable i_armProxy;
  /// @dev The immutable flag that indicates if the pool is access-controlled.
  bool internal immutable i_allowlistEnabled;
  /// @dev A set of addresses allowed to trigger lockOrBurn as original senders.
  /// Only takes effect if i_allowlistEnabled is true.
  /// This can be used to ensure only token-issuer specified addresses can
  /// move tokens.
  EnumerableSet.AddressSet internal s_allowList;
  /// @dev The address of the router
  IRouter internal s_router;
  /// @dev A set of allowed chain selectors. We want the allowlist to be enumerable to
  /// be able to quickly determine (without parsing logs) who can access the pool.
  /// @dev The chain selectors are in uin256 format because of the EnumerableSet implementation.
  EnumerableSet.UintSet internal s_remoteChainSelectors;
  /// @dev Outbound rate limits. Corresponds to the inbound rate limit for the pool
  /// on the remote chain.
  mapping(uint64 => RateLimiter.TokenBucket) internal s_outboundRateLimits;
  /// @dev Inbound rate limits. This allows per destination chain
  /// token issuer specified rate limiting (e.g. issuers may trust chains to varying
  /// degrees and prefer different limits)
  mapping(uint64 => RateLimiter.TokenBucket) internal s_inboundRateLimits;

  constructor(IERC20 token, address armProxy, bool allowlistEnabled) {
    if (address(token) == address(0)) revert ZeroAddressNotAllowed();
    i_token = token;
    i_armProxy = armProxy;
    i_allowlistEnabled = allowlistEnabled;
  }

  /// @notice Get ARM proxy address
  /// @return armProxy Address of arm proxy
  function getArmProxy() public view returns (address armProxy) {
    return i_armProxy;
  }

  /// @inheritdoc IPool
  function getToken() public view override returns (IERC20 token) {
    return i_token;
  }

  /// @notice Gets the pool's Router
  /// @return router The pool's Router
  function getRouter() public view returns (address router) {
    return address(s_router);
  }

  /// @notice Sets the pool's Router
  /// @param newRouter The new Router
  function setRouter(address newRouter) public onlyOwner {
    if (newRouter == address(0)) revert ZeroAddressNotAllowed();
    address oldRouter = address(s_router);
    s_router = IRouter(newRouter);

    emit RouterUpdated(oldRouter, newRouter);
  }

  /// @inheritdoc IERC165
  function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
    return interfaceId == type(IPool).interfaceId || interfaceId == type(IERC165).interfaceId;
  }

  // ================================================================
  // │                     Chain permissions                        │
  // ================================================================

  /// @notice Checks whether a chain selector is permissioned on this contract.
  /// @return true if the given chain selector is a permissioned remote chain.
  function isSupportedChain(uint64 remoteChainSelector) public view returns (bool) {
    return s_remoteChainSelectors.contains(remoteChainSelector);
  }

  /// @notice Get list of allowed chains
  /// @return list of chains.
  function getSupportedChains() public view returns (uint64[] memory) {
    uint256[] memory uint256ChainSelectors = s_remoteChainSelectors.values();
    uint64[] memory chainSelectors = new uint64[](uint256ChainSelectors.length);
    for (uint256 i = 0; i < uint256ChainSelectors.length; ++i) {
      chainSelectors[i] = uint64(uint256ChainSelectors[i]);
    }

    return chainSelectors;
  }

  /// @notice Sets the permissions for a list of chains selectors. Actual senders for these chains
  /// need to be allowed on the Router to interact with this pool.
  /// @dev Only callable by the owner
  /// @param chains A list of chains and their new permission status & rate limits. Rate limits
  /// are only used when the chain is being added through `allowed` being true.
  function applyChainUpdates(ChainUpdate[] calldata chains) external virtual onlyOwner {
    for (uint256 i = 0; i < chains.length; ++i) {
      ChainUpdate memory update = chains[i];
      RateLimiter._validateTokenBucketConfig(update.outboundRateLimiterConfig, !update.allowed);
      RateLimiter._validateTokenBucketConfig(update.inboundRateLimiterConfig, !update.allowed);

      if (update.allowed) {
        // If the chain already exists, revert
        if (!s_remoteChainSelectors.add(update.remoteChainSelector)) {
          revert ChainAlreadyExists(update.remoteChainSelector);
        }

        s_outboundRateLimits[update.remoteChainSelector] = RateLimiter.TokenBucket({
          rate: update.outboundRateLimiterConfig.rate,
          capacity: update.outboundRateLimiterConfig.capacity,
          tokens: update.outboundRateLimiterConfig.capacity,
          lastUpdated: uint32(block.timestamp),
          isEnabled: update.outboundRateLimiterConfig.isEnabled
        });

        s_inboundRateLimits[update.remoteChainSelector] = RateLimiter.TokenBucket({
          rate: update.inboundRateLimiterConfig.rate,
          capacity: update.inboundRateLimiterConfig.capacity,
          tokens: update.inboundRateLimiterConfig.capacity,
          lastUpdated: uint32(block.timestamp),
          isEnabled: update.inboundRateLimiterConfig.isEnabled
        });
        emit ChainAdded(update.remoteChainSelector, update.outboundRateLimiterConfig, update.inboundRateLimiterConfig);
      } else {
        // If the chain doesn't exist, revert
        if (!s_remoteChainSelectors.remove(update.remoteChainSelector)) {
          revert NonExistentChain(update.remoteChainSelector);
        }

        delete s_inboundRateLimits[update.remoteChainSelector];
        delete s_outboundRateLimits[update.remoteChainSelector];
        emit ChainRemoved(update.remoteChainSelector);
      }
    }
  }

  // ================================================================
  // │                        Rate limiting                         │
  // ================================================================

  /// @notice Consumes outbound rate limiting capacity in this pool
  function _consumeOutboundRateLimit(uint64 remoteChainSelector, uint256 amount) internal {
    s_outboundRateLimits[remoteChainSelector]._consume(amount, address(i_token));
  }

  /// @notice Consumes inbound rate limiting capacity in this pool
  function _consumeInboundRateLimit(uint64 remoteChainSelector, uint256 amount) internal {
    s_inboundRateLimits[remoteChainSelector]._consume(amount, address(i_token));
  }

  /// @notice Gets the token bucket with its values for the block it was requested at.
  /// @return The token bucket.
  function getCurrentOutboundRateLimiterState(
    uint64 remoteChainSelector
  ) external view returns (RateLimiter.TokenBucket memory) {
    return s_outboundRateLimits[remoteChainSelector]._currentTokenBucketState();
  }

  /// @notice Gets the token bucket with its values for the block it was requested at.
  /// @return The token bucket.
  function getCurrentInboundRateLimiterState(
    uint64 remoteChainSelector
  ) external view returns (RateLimiter.TokenBucket memory) {
    return s_inboundRateLimits[remoteChainSelector]._currentTokenBucketState();
  }

  /// @notice Sets the chain rate limiter config.
  /// @param remoteChainSelector The remote chain selector for which the rate limits apply.
  /// @param outboundConfig The new outbound rate limiter config, meaning the onRamp rate limits for the given chain.
  /// @param inboundConfig The new inbound rate limiter config, meaning the offRamp rate limits for the given chain.
  function setChainRateLimiterConfig(
    uint64 remoteChainSelector,
    RateLimiter.Config memory outboundConfig,
    RateLimiter.Config memory inboundConfig
  ) external virtual onlyOwner {
    _setRateLimitConfig(remoteChainSelector, outboundConfig, inboundConfig);
  }

  function _setRateLimitConfig(
    uint64 remoteChainSelector,
    RateLimiter.Config memory outboundConfig,
    RateLimiter.Config memory inboundConfig
  ) internal {
    if (!isSupportedChain(remoteChainSelector)) revert NonExistentChain(remoteChainSelector);
    RateLimiter._validateTokenBucketConfig(outboundConfig, false);
    s_outboundRateLimits[remoteChainSelector]._setTokenBucketConfig(outboundConfig);
    RateLimiter._validateTokenBucketConfig(inboundConfig, false);
    s_inboundRateLimits[remoteChainSelector]._setTokenBucketConfig(inboundConfig);
    emit ChainConfigured(remoteChainSelector, outboundConfig, inboundConfig);
  }

  // ================================================================
  // │                           Access                             │
  // ================================================================

  /// @notice Checks whether remote chain selector is configured on this contract, and if the msg.sender
  /// is a permissioned onRamp for the given chain on the Router.
  modifier onlyOnRamp(uint64 remoteChainSelector) {
    if (!isSupportedChain(remoteChainSelector)) revert ChainNotAllowed(remoteChainSelector);
    if (!(msg.sender == getProxyPool() || msg.sender == s_router.getOnRamp(remoteChainSelector))) {
      revert CallerIsNotARampOnRouter(msg.sender);
    }
    _;
  }

  /// @notice Checks whether remote chain selector is configured on this contract, and if the msg.sender
  /// is a permissioned offRamp for the given chain on the Router.
  modifier onlyOffRamp(uint64 remoteChainSelector) {
    if (!isSupportedChain(remoteChainSelector)) revert ChainNotAllowed(remoteChainSelector);
    if (!(msg.sender == getProxyPool() || s_router.isOffRamp(remoteChainSelector, msg.sender))) {
      revert CallerIsNotARampOnRouter(msg.sender);
    }
    _;
  }

  // ================================================================
  // │                          Allowlist                           │
  // ================================================================

  modifier checkAllowList(address sender) {
    if (i_allowlistEnabled && !s_allowList.contains(sender)) revert SenderNotAllowed(sender);
    _;
  }

  /// @notice Gets whether the allowList functionality is enabled.
  /// @return true is enabled, false if not.
  function getAllowListEnabled() external view returns (bool) {
    return i_allowlistEnabled;
  }

  /// @notice Gets the allowed addresses.
  /// @return The allowed addresses.
  function getAllowList() external view returns (address[] memory) {
    return s_allowList.values();
  }

  /// @notice Apply updates to the allow list.
  /// @param removes The addresses to be removed.
  /// @param adds The addresses to be added.
  /// @dev allowListing will be removed before public launch
  function applyAllowListUpdates(address[] calldata removes, address[] calldata adds) external onlyOwner {
    _applyAllowListUpdates(removes, adds);
  }

  /// @notice Internal version of applyAllowListUpdates to allow for reuse in the constructor.
  function _applyAllowListUpdates(address[] memory removes, address[] memory adds) internal {
    if (!i_allowlistEnabled) revert AllowListNotEnabled();

    for (uint256 i = 0; i < removes.length; ++i) {
      address toRemove = removes[i];
      if (s_allowList.remove(toRemove)) {
        emit AllowListRemove(toRemove);
      }
    }
    for (uint256 i = 0; i < adds.length; ++i) {
      address toAdd = adds[i];
      if (toAdd == address(0)) {
        continue;
      }
      if (s_allowList.add(toAdd)) {
        emit AllowListAdd(toAdd);
      }
    }
  }

  /// @notice Ensure that there is no active curse.
  modifier whenHealthy() {
    if (IARM(i_armProxy).isCursed()) revert BadARMSignal();
    _;
  }

  /// @notice Getter for proxy pool address.
  /// @return proxyPool The proxy pool address.
  function getProxyPool() public view returns (address proxyPool) {
    assembly ("memory-safe") {
      proxyPool := shr(96, shl(96, sload(PROXY_POOL_SLOT)))
    }
  }

  /// @notice Setter for proxy pool address, only callable by the DAO.
  /// @param proxyPool The address of the proxy pool.
  function setProxyPool(address proxyPool) external onlyOwner {
    if (proxyPool == address(0)) revert ZeroAddressNotAllowed();
    assembly ("memory-safe") {
      sstore(PROXY_POOL_SLOT, proxyPool)
    }
  }
}
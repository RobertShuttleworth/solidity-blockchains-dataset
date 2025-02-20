// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { Initializable } from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import { AccessControlUpgradeable } from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import { PausableUpgradeable } from "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";

import { IRemoteHub, IXusdToken, IPayoutManager, IRoleManager } from "./contracts_interfaces_IRemoteHub.sol";
import { NonRebaseInfo } from "./contracts_interfaces_IPayoutManager.sol";

/**
 * @title ExchangeChild
 * @notice Manages the exchange and payout process for XUSD tokens
 * @dev Inherits from Initializable, AccessControlUpgradeable, UUPSUpgradeable, and PausableUpgradeable
 */
contract ExchangeChild is Initializable, AccessControlUpgradeable, UUPSUpgradeable, PausableUpgradeable {
    uint256 public constant LIQ_DELTA_DM = 1e6;

    /** @notice New delta value for payout calculations */
    uint256 public newDelta;
    /** @notice Deadline for payout execution */
    uint256 public payoutDeadline;
    /** @notice Time delta for payout deadline */
    uint256 public payoutDelta;
    /** @notice Interface for the RemoteHub contract */
    IRemoteHub public remoteHub;

    // --- events

    event RemoteHubUpdated(address remoteHub);
    event PayoutDeltaUpdated(uint256 payoutDelta);
    event PayoutShortEvent(uint256 newDelta, uint256 nonRebaseDelta);
    event PayoutInfoStored(uint256 newDelta, uint256 payoutDeadline);

    // ---  initializer

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function UPGRADER_ROLE() public pure returns (bytes32) {
        return keccak256("UPGRADER_ROLE");
    }

    function PAYOUT_EXECUTOR_ROLE() public pure returns (bytes32) {
        return keccak256("PAYOUT_EXECUTOR_ROLE");
    }

    /**
     * @notice Initializes the contract
     * @param _remoteHub Address of the RemoteHub contract
     */
    function initialize(address _remoteHub) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE(), msg.sender);

        remoteHub = IRemoteHub(_remoteHub);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

    // ---  remoteHub getters

    function xusd() internal view returns (IXusdToken) {
        return remoteHub.xusd();
    }

    function roleManager() internal view returns (IRoleManager) {
        return remoteHub.roleManager();
    }

    function payoutManager() internal view returns (IPayoutManager) {
        return remoteHub.payoutManager();
    }

    // ---  modifiers

    modifier onlyUpgrader() {
        require(hasRole(UPGRADER_ROLE(), msg.sender), "Caller doesn't have UPGRADER_ROLE role");
        _;
    }

    modifier onlyPayoutExecutor() {
        require(hasRole(PAYOUT_EXECUTOR_ROLE(), msg.sender), "Caller is not the payout executor");
        _;
    }

    // --- setters

    function setRemoteHub(address _remoteHub) external onlyUpgrader {
        require(_remoteHub != address(0), "Zero address not allowed");
        remoteHub = IRemoteHub(_remoteHub);
        emit RemoteHubUpdated(_remoteHub);
    }

    function setPayoutDelta(uint256 _payoutDelta) external onlyUpgrader {
        payoutDelta = _payoutDelta;
        emit PayoutDeltaUpdated(payoutDelta);
    }

    // --- logic

    /**
     * @notice Executes the payout process
     */
    function payout() public {
        require(newDelta > 0, "new delta is not ready");
        require(_isUnit() || payoutDeadline >= block.timestamp, "You are not Unit or timestamp is not ready.");
        require(newDelta > LIQ_DELTA_DM, "Negative rebase");

        IXusdToken _xusd = xusd();
        IPayoutManager _payoutManager = payoutManager();

        uint256 totalNav = (_xusd.totalSupply() * newDelta) / LIQ_DELTA_DM;
        (NonRebaseInfo[] memory nonRebaseInfo, uint256 nonRebaseDelta) = _xusd.changeSupply(totalNav);

        if (nonRebaseDelta > 0) {
            _xusd.mint(address(_payoutManager), nonRebaseDelta);
            _payoutManager.payoutDone(address(_xusd), nonRebaseInfo);
        }

        require(_xusd.totalSupply() == totalNav, "total != nav");

        newDelta = 0;

        emit PayoutShortEvent(newDelta, nonRebaseDelta);
    }

    /**
     * @notice Initiates a payout with a new delta value
     * @param _newDelta New delta value for the payout
     */
    function payout(uint256 _newDelta) external onlyPayoutExecutor {
        require(_newDelta > LIQ_DELTA_DM, "Negative rebase");

        newDelta = _newDelta;
        payoutDeadline = block.timestamp + payoutDelta;

        emit PayoutInfoStored(newDelta, payoutDeadline);

        if (payoutDelta == 0) {
            payout();
        }
    }

    /**
     * @notice Checks if the caller has the UNIT_ROLE
     * @return bool True if the caller has the UNIT_ROLE, false otherwise
     */
    function _isUnit() internal view returns (bool) {
        return roleManager().hasRole(roleManager().UNIT_ROLE(), msg.sender);
    }
}
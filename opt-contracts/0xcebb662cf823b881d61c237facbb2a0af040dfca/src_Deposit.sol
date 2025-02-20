// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { UUPSUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import { IERC20, SafeERC20 } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";

contract Deposit is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint16 public constant BASIS_POINTS = 10_000;

    IERC20 public jpyt;
    address[] public recipientAddrs;
    uint16[] public recipientPercentBPs;

    event PercentBPsSet(address[] _recipientAddrs, uint16[] recipientPercentBPs);
    event JPYTDistributed(address[] _recipientAddrs, uint256[] recipientAmounts);

    error MismatchedLengths();
    error InvalidPercentBPs();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _defaultAdmin,
        address _operator,
        address _upgrader,
        address _jpyt,
        address[] calldata _recipientAddrs,
        uint16[] calldata _recipientPercentBPs
    )
        public
        initializer
    {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(OPERATOR_ROLE, _operator);
        _grantRole(UPGRADER_ROLE, _upgrader);

        jpyt = IERC20(_jpyt);
        recipientAddrs = _recipientAddrs;
        recipientPercentBPs = _recipientPercentBPs;
    }

    function setPercentBPs(
        address[] calldata _recipientAddrs,
        uint16[] calldata _recipientPercentBPs
    )
        external
        onlyRole(OPERATOR_ROLE)
    {
        if (_recipientAddrs.length != _recipientPercentBPs.length) {
            revert MismatchedLengths();
        }

        uint16 sumPercentBPs;
        uint256 recipientAddrsLength = _recipientAddrs.length;
        for (uint256 i; i < recipientAddrsLength;) {
            sumPercentBPs += _recipientPercentBPs[i];

            unchecked {
                ++i;
            }
        }
        if (sumPercentBPs != BASIS_POINTS) {
            revert InvalidPercentBPs();
        }

        recipientAddrs = _recipientAddrs;
        recipientPercentBPs = _recipientPercentBPs;

        emit PercentBPsSet(_recipientAddrs, _recipientPercentBPs);
    }

    function distribute() external onlyRole(OPERATOR_ROLE) {
        uint256 jpytBalance = IERC20(jpyt).balanceOf(address(this));

        uint256 recipientAddrsLength = recipientAddrs.length;
        uint256[] memory recipientAmounts = new uint256[](recipientAddrsLength);

        for (uint256 i; i < recipientAddrsLength;) {
            uint256 recipientAmount = jpytBalance * recipientPercentBPs[i] / BASIS_POINTS;
            recipientAmounts[i] = recipientAmount;

            IERC20(jpyt).safeTransfer(recipientAddrs[i], recipientAmount);

            unchecked {
                ++i;
            }
        }

        emit JPYTDistributed(recipientAddrs, recipientAmounts);
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
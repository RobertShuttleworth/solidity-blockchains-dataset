// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_utils_ReentrancyGuardUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import "./src_interfaces_IVault.sol";
import "./src_interfaces_ISpokeController.sol";
import {DataTypes} from "./src_libraries_types_DataTypes.sol";

contract CrossChainVault is
    IVault,
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    ISpokeController public spokeController;

    event Supply(address indexed asset, address indexed onBehalfOf, uint256 amount, uint16 referralCode);
    event Withdraw(address indexed asset, address indexed to, uint256 amount);
    event Borrow(address indexed asset, address indexed onBehalfOf, uint256 amount, uint16 referralCode);
    event Repay(address indexed asset, address indexed onBehalfOf, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _spokeController) public initializer {
        __ReentrancyGuard_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, _spokeController);

        spokeController = ISpokeController(_spokeController);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
        external
        payable
        nonReentrant
    {
        require(amount > 0, "Invalid amount");
        address finalUser = onBehalfOf == address(0) ? msg.sender : onBehalfOf;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        DataTypes.SupplyParams memory params = DataTypes.SupplyParams({
            sender: msg.sender,
            asset: asset,
            amount: amount,
            onBehalfOf: finalUser,
            referralCode: referralCode
        });

        spokeController.sendSupplyIntent(params);

        emit Supply(asset, finalUser, amount, referralCode);
    }

    function withdraw(address asset, uint256 amount, address to) external payable nonReentrant {
        require(amount > 0, "Invalid amount");
        address receiver = to == address(0) ? msg.sender : to;

        DataTypes.WithdrawParams memory params =
            DataTypes.WithdrawParams({sender: msg.sender, asset: asset, amount: amount, to: receiver});

        spokeController.sendWithdrawIntent(params);

        emit Withdraw(asset, receiver, amount);
    }

    function borrow(address asset, uint256 amount, address onBehalfOf, uint256 interestRateMode, uint16 referralCode)
        external
        payable
        nonReentrant
    {
        require(amount > 0, "Invalid amount");
        address finalUser = onBehalfOf == address(0) ? msg.sender : onBehalfOf;

        DataTypes.BorrowParams memory params = DataTypes.BorrowParams({
            sender: msg.sender,
            asset: asset,
            amount: amount,
            interestRateMode: interestRateMode,
            referralCode: referralCode,
            onBehalfOf: finalUser
        });

        spokeController.sendBorrowIntent(params);

        emit Borrow(asset, finalUser, amount, referralCode);
    }

    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        payable
        nonReentrant
        returns (uint256)
    {
        require(amount > 0, "Invalid amount");
        address finalUser = onBehalfOf == address(0) ? msg.sender : onBehalfOf;

        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        DataTypes.RepayParams memory params = DataTypes.RepayParams({
            sender: msg.sender,
            asset: asset,
            amount: amount,
            interestRateMode: interestRateMode,
            onBehalfOf: finalUser
        });

        spokeController.sendRepayIntent(params);

        emit Repay(asset, finalUser, amount);
        return amount;
    }

    function executeIntent(address asset, uint256 amount, address to) external nonReentrant onlyRole(EXECUTOR_ROLE) {
        IERC20(asset).safeTransfer(to, amount);
    }

    function setSpokeController(address newSpokeController) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newSpokeController != address(0), "Invalid address");
        spokeController = ISpokeController(newSpokeController);
        _grantRole(EXECUTOR_ROLE, newSpokeController);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_access_extensions_AccessControlEnumerableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IGateway {
    function withdraw(
        uint256 realTokenAmount,
        uint256 bridgedTokenAmount
    ) external;

    function deposit(uint256 realTokenAmount) external;

    function nativeToken() external view returns (address);

    function mbToken() external view returns (address);
}

/// @notice The modified Escrow contract to work with Gateway
contract Escrow is Initializable, AccessControlEnumerableUpgradeable {
    address public gatewayAddress;
    address public nativeTokenAddress;
    address public treasureAddress;
    uint256 public thresholdAmount;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant DEPOSITOR_ROLE = keccak256("DEPOSITOR_ROLE");
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");
    bytes32 public constant ASSET_MANAGER_ROLE =
        keccak256("ASSET_MANAGER_ROLE");

    event DepositToGateway(uint256 amount, uint256 thresholdAmount);
    event WithdrawFromGateway(uint256 amount, uint256 thresholdAmount);
    event SetThresholdAmount(uint256 thresholdAmount);
    event TreasureChanged(address oldTreasure, address newTreasure);
    event WithdrawERC20(address token, address to, uint256 amount);

    function initialize(
        address _gatewayAddress,
        address _treasureAddress,
        uint256 _thresholdAmount
    ) public initializer {
        __AccessControl_init();

        gatewayAddress = _gatewayAddress;
        treasureAddress = _treasureAddress;
        thresholdAmount = _thresholdAmount;

        nativeTokenAddress = IGateway(gatewayAddress).nativeToken();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    function depositToGateway() external onlyRole(DEPOSITOR_ROLE) {
        uint256 gatewayBalance = IERC20(nativeTokenAddress).balanceOf(
            gatewayAddress
        );
        require(
            gatewayBalance < thresholdAmount,
            "Escrow: Gateway balance exceeds the threshold"
        );

        uint256 requiredAmount = thresholdAmount - gatewayBalance;
        uint256 escrowBalance = IERC20(nativeTokenAddress).balanceOf(
            address(this)
        );
        uint256 amount = requiredAmount < escrowBalance
            ? requiredAmount
            : escrowBalance;

        IERC20(nativeTokenAddress).approve(gatewayAddress, amount);
        IGateway(gatewayAddress).deposit(amount);

        emit DepositToGateway(amount, thresholdAmount);
    }

    function withdrawFromGateway() external onlyRole(WITHDRAWER_ROLE) {
        uint256 gatewayBalance = IERC20(nativeTokenAddress).balanceOf(
            gatewayAddress
        );
        require(
            gatewayBalance > thresholdAmount,
            "Escrow: Gateway balance is below the threshold"
        );

        uint256 requiredAmount = gatewayBalance - thresholdAmount;
        IGateway(gatewayAddress).withdraw(requiredAmount, 0);

        emit WithdrawFromGateway(requiredAmount, thresholdAmount);
    }

    function setThresholdAmount(
        uint256 _thresholdAmount
    ) external onlyRole(ADMIN_ROLE) {
        thresholdAmount = _thresholdAmount;

        emit SetThresholdAmount(_thresholdAmount);
    }

    function setTreasureAddress(
        address _treasureAddress
    ) external onlyRole(ADMIN_ROLE) {
        address oldTreasure = treasureAddress;
        treasureAddress = _treasureAddress;

        emit TreasureChanged(oldTreasure, treasureAddress);
    }

    function withdrawERC20(
        address token,
        uint256 amount
    ) external onlyRole(ASSET_MANAGER_ROLE) {
        IERC20(token).transfer(treasureAddress, amount);

        emit WithdrawERC20(token, treasureAddress, amount);
    }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_interfaces_IERC20.sol";
import "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_access_manager_IAccessManaged.sol";

interface IWrapper is IERC20, IAccessManaged {

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    // TODO move to common library
    struct TransferInfo {
        uint256 amount; // amount to transfer
        address token; // token to transfer
    }

    function depositRaw(address dustReceiver) external returns (uint shares);
    function depositRaw(address dustReceiver, address receiver) external returns (uint shares);
    function redeemRaw(uint lpAmount, address receiver)
        external
        returns (
            address[] memory tokens,
            uint[] memory amounts
        );
    function claim(address receiver) external;
    function recoverFunds(TransferInfo calldata transfer, address to) external;

    function depositTokens() external view returns (address[] memory tokens);
    function rewardTokens() external view returns(address[] memory tokens);
    function poolTokens() external view returns(address[] memory tokens);
    function ratios() external returns(address[] memory tokens, uint[] memory ratio);
    function description() external view returns (string memory);

}
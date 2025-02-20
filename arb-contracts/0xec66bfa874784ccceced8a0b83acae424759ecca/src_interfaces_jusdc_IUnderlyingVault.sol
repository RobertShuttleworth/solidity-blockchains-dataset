// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

interface IUnderlyingVault {
    function initialize(address _asset, address _enforceHub, string memory _name, string memory _symbol) external;

    function burn(address account, uint256 shares) external;
    function mint(uint256 shares, address receiver) external returns (uint256);
    function withdraw(uint256 assets, address receiver, address /*owner*/ ) external returns (uint256);

    function receiveRewards(uint256 amount) external;
    function borrow(uint256 amount) external;
    function payBack(uint256 amount, uint256 incentives) external;
    function enforcePayBack(uint256 amount, bytes calldata enforceData) external returns (uint256);
    function addStrategy(address _newOperator, uint256 _cap) external;
    function removeStrategy(address _operator) external;

    function transfer(address user, uint256 amount) external returns (bool);

    function retentionRefund(uint256 amount, bytes memory enforceData) external view returns (uint256);
    function balanceOf(address user) external view returns (uint256);

    function borrowableAmount(address strategy) external view returns (uint256);
    function cap(address strategy) external view returns (uint256);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function totalAssets() external view returns (uint256);

    function loaned(address strategy) external view returns (uint256);

    function underlying() external view returns (IERC20);

    /* -------------------------------------------------------------------------- */
    /*                                   EVENTS                                   */
    /* -------------------------------------------------------------------------- */

    event EmergencyWithdrawal(address indexed caller, address indexed receiver, address[] tokens, uint256 nativeBalanc);
    event ReceiveRewards(address indexed sender, uint256 amount, uint256 totalAssets, uint256 totalSupply);
    event Borrowed(address indexed to, uint256 amount, uint256 totalDebt);
    event PayBack(address indexed from, uint256 amount, uint256 incentives, uint256 totalDebt);
    event EnforcePayback(uint256 amount, uint256 retention, uint256 totalAssets, uint256 totalDebt);

    /* -------------------------------------------------------------------------- */
    /*                                    ERRORS                                   */
    /* -------------------------------------------------------------------------- */

    error NotEnoughFunds();
    error CallerIsNotStrategy();
    error FailSendETH();
    error NotRightCaller();
    error CapReached();
    error SequencerDown();
    error StalePrice();
    error InvalidPrice();
    error StalePriceUpdate();
}
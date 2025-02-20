// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IWormholeTunnel} from "./src_interfaces_IWormholeTunnel.sol";

interface ISpoke {

    error CreditLimitExceeded();
    error CreditNotFound();
    error CustodyLimitExceeded();
    error FundsAlreadyReleased();
    error InsufficientMsgValue();
    error InsufficientFunds();
    error InvalidAction();
    error InvalidAmount();
    error InvalidCostForReturnDeliveryLength();
    error InvalidDeliveryCost();
    error InvalidReleaseFundsPayload();
    error InvalidWethForUnwrap();
    error OnlyHubSender();
    error OnlyWormholeTunnel();
    error TransactionLimitExceeded();
    error TransferFailed();
    error UnusedParameterMustBeZero();

    function unwrapWethToTarget(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external payable;

    function releaseFunds(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external payable;

    function topUp(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external payable;

    function confirmCredit(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external payable;

    function finalizeCredit(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external payable;
}
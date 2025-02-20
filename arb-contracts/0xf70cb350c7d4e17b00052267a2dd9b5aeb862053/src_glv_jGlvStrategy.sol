// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2024 JonesDAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

// Check https://docs.jonesdao.io/jones-dao/other/bounty for details on our bounty program.

pragma solidity ^0.8.26;

import {UpgradeableKeepable} from "./src_governance_UpgradeableKeepable.sol";
import {ReentrancyGuardUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_ReentrancyGuardUpgradeable.sol";

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

import {IGlvRouter} from "./src_interfaces_gmx_IGlvRouter.sol";
import {IGlvHandler} from "./src_interfaces_gmx_IGlvHandler.sol";
import {IGlvDepositCallbackReceiver} from "./src_interfaces_gmx_IGlvDepositCallbackReceiver.sol";
import {IGlvWithdrawalCallbackReceiver} from "./src_interfaces_gmx_IGlvWithdrawalCallbackReceiver.sol";
import {IEventUtils} from "./src_interfaces_gmx_IEventUtils.sol";
import {GlvDeposit} from "./src_interfaces_gmx_GlvDeposit.sol";
import {GlvWithdrawal} from "./src_interfaces_gmx_GlvWithdrawal.sol";

import {IWithdrawalCallback} from "./src_interfaces_glv_IWithdrawalCallback.sol";
import {IjGlvRouter} from "./src_interfaces_glv_IjGlvRouter.sol";
import {IjGlvStrategy} from "./src_interfaces_glv_IjGlvStrategy.sol";

contract jGlvStrategy is
    IjGlvStrategy,
    IGlvDepositCallbackReceiver,
    IGlvWithdrawalCallbackReceiver,
    UpgradeableKeepable,
    ReentrancyGuardUpgradeable
{
    /* -------------------------------------------------------------------------- */
    /*                                  VARIABLES                                 */
    /* -------------------------------------------------------------------------- */

    address public router;

    address private constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address private constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address private constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    bytes32 private constant CONTROLLER = keccak256(abi.encode("CONTROLLER"));

    uint256 public operations;

    mapping(bytes32 => bool) public ongoingOperation;

    IGlvRouter public glvRouter;

    // key => callback contract
    mapping(bytes32 => address) public callBackContract;

    // glv => index
    mapping(address => uint256) public glvIndex;
    address[] private _glvs;

    bool public withdrawalIssue;
    uint256 public totalWithdrawalAmount;

    // key => withdrawal information
    mapping(bytes32 => WithdrawalInfo) public withdrawalInfo;

    // key => deposit amount
    mapping(bytes32 => uint256) public depositAmount;
    uint256 public pendingDepositAmount;

    // glv => pending glv withdrawal amount
    mapping(address => uint256) public pendingWithdrawnAmounts;

    address public bot;

    /* -------------------------------------------------------------------------- */
    /*                                  INITIALIZE                                */
    /* -------------------------------------------------------------------------- */
    function initialize(address _router, address _bot, address[] memory _gvls) external initializer {
        __Governable_init(msg.sender);
        __ReentrancyGuard_init();

        operations = 1;
        _glvs.push(ZERO_ADDRESS);

        router = _router;
        bot = _bot;

        glvRouter = IGlvRouter(0x105b5aFe50FBCe7759051974fB1710ce331C77B3);

        uint256 length = _gvls.length;

        for (uint256 i; i < length;) {
            _addGlv(_gvls[i]);

            unchecked {
                ++i;
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                    VIEW                                    */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Revert if there is an ongoing operation
     */
    function operationCheck() external view {
        _operationCheck();
    }

    function glvs() external view returns (address[] memory) {
        return _glvs;
    }

    function getWithdrawalInfo(bytes32 key) external view returns (WithdrawalInfo memory) {
        return withdrawalInfo[key];
    }

    /* -------------------------------------------------------------------------- */
    /*                                   KEEPER                                   */
    /* -------------------------------------------------------------------------- */

    struct GVLDeposit {
        uint256[] amounts;
        address[] glvs; // WETH/USDC GLV
        address[] markets; // WETH/USDC GM MARKET
        address[] initialLongToken;
        uint256[] minGlvTokens;
        uint256[] executionFee;
        uint256[] callbackGasLimit;
    }

    function gvlDeposits(GVLDeposit memory _deposit) external payable nonReentrant {
        _onlyKeeperOrRouter(msg.sender);
        _operationCheck();

        IGlvHandler.CreateGlvDepositParams memory depositParams;

        address thisAddress = address(this);

        address glvVault = _glvVault();

        uint256 length = _deposit.amounts.length;

        address[] memory emptyPath;

        if (
            length != _deposit.glvs.length || length != _deposit.markets.length
                || length != _deposit.initialLongToken.length || length != _deposit.minGlvTokens.length
                || length != _deposit.executionFee.length || length != _deposit.callbackGasLimit.length
        ) {
            revert lengthMissMatch();
        }

        for (uint256 i; i < length;) {
            if (_deposit.amounts[i] == 0) {
                revert ZeroAmount();
            }

            if (glvIndex[_deposit.glvs[i]] == 0) {
                revert GvlNotFound();
            }

            glvRouter.sendWnt{value: _deposit.executionFee[i]}(glvVault, _deposit.executionFee[i]);

            IERC20(USDC).approve(address(glvRouter.router()), _deposit.amounts[i]);
            glvRouter.sendTokens(USDC, glvVault, _deposit.amounts[i]);

            depositParams = IGlvHandler.CreateGlvDepositParams({
                glv: _deposit.glvs[i],
                market: _deposit.markets[i],
                receiver: thisAddress,
                callbackContract: thisAddress,
                uiFeeReceiver: ZERO_ADDRESS,
                initialLongToken: _deposit.initialLongToken[i], // WETH
                initialShortToken: USDC,
                longTokenSwapPath: emptyPath,
                shortTokenSwapPath: emptyPath,
                minGlvTokens: _deposit.minGlvTokens[i], // 0
                executionFee: _deposit.executionFee[i], // 750.000
                callbackGasLimit: _deposit.callbackGasLimit[i], // 750.000
                shouldUnwrapNativeToken: true,
                isMarketTokenDeposit: false
            });

            bytes32 key = glvRouter.createGlvDeposit(depositParams);

            operations = operations + 1;

            ongoingOperation[key] = true;

            depositAmount[key] = _deposit.amounts[i];
            pendingDepositAmount = pendingDepositAmount + _deposit.amounts[i];

            emit GlvDepositCreated(key, _deposit.executionFee[i], _deposit.callbackGasLimit[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Callback of Executed Deposit.
     * @param key Deposit key or id.
     */
    function afterGlvDepositExecution(
        bytes32 key,
        GlvDeposit.Props memory glvDeposit,
        IEventUtils.EventLogData memory eventData
    ) external nonReentrant {
        _onlyControllerOrKeeper(msg.sender);

        if (!ongoingOperation[key]) {
            revert InvalidOperation();
        }

        if (operations == 1) {
            revert OperationNotStarted();
        }

        operations = operations - 1;
        ongoingOperation[key] = false;

        pendingDepositAmount = pendingDepositAmount - depositAmount[key];
        depositAmount[key] = 0;

        _ethExcess();

        emit GlvDepositExecuted(key, glvDeposit, eventData);
    }

    /**
     * @notice Callback of Cancelled Deposit.
     * @param key Deposit key or id.
     */
    function afterGlvDepositCancellation(
        bytes32 key,
        GlvDeposit.Props memory glvDeposit,
        IEventUtils.EventLogData memory eventData
    ) external nonReentrant {
        _onlyControllerOrKeeper(msg.sender);

        if (!ongoingOperation[key]) {
            revert InvalidOperation();
        }

        if (operations == 1) {
            revert OperationNotStarted();
        }

        operations = operations - 1;
        ongoingOperation[key] = false;

        pendingDepositAmount = pendingDepositAmount - depositAmount[key];
        depositAmount[key] = 0;

        _ethExcess();

        emit GlvDepositCancelled(key, glvDeposit, eventData);
    }

    function gvlWithdrawals(
        bool fix,
        uint256 shares,
        uint256 extraAmount,
        address receiver,
        address callbackContract,
        GVLWithdrawal memory _withdrawal
    ) external payable nonReentrant {
        _onlyKeeperOrRouter(msg.sender);

        if (operations > 1) {
            revert OngoingOperation();
        }

        if (withdrawalIssue && !fix) {
            revert WithdrawalIssue();
        }

        IGlvHandler.CreateGlvWithdrawalParams memory withdrawalParams;

        address thisAddress = address(this);

        address glvVault = _glvVault();

        uint256 length = _withdrawal.amounts.length;

        if (length == 0 && extraAmount > 0) {
            if (shares > 0) {
                IjGlvRouter(router).vault().burn(thisAddress, shares);
            }
            if (receiver != address(0)) {
                IERC20(USDC).transfer(receiver, extraAmount);
            }
            if (callbackContract != address(0)) {
                IWithdrawalCallback(callbackContract).withdrawalCallback(shares, extraAmount);
            }

            return;
        }

        address[] memory emptyPath;

        if (
            length != _withdrawal.glvs.length || length != _withdrawal.markets.length
                || length != _withdrawal.longTokenSwapPath.length || length != _withdrawal.minLongTokenAmount.length
                || length != _withdrawal.minShortTokenAmount.length || length != _withdrawal.executionFee.length
                || length != _withdrawal.callbackGasLimit.length
        ) {
            revert lengthMissMatch();
        }

        for (uint256 i; i < length;) {
            if (_withdrawal.amounts[i] == 0) {
                revert ZeroAmount();
            }

            if (glvIndex[_withdrawal.glvs[i]] == 0) {
                revert GvlNotFound();
            }

            glvRouter.sendWnt{value: _withdrawal.executionFee[i]}(glvVault, _withdrawal.executionFee[i]);

            IERC20(_withdrawal.glvs[i]).approve(address(glvRouter.router()), _withdrawal.amounts[i]);
            glvRouter.sendTokens(_withdrawal.glvs[i], glvVault, _withdrawal.amounts[i]);

            withdrawalParams = IGlvHandler.CreateGlvWithdrawalParams({
                receiver: thisAddress,
                callbackContract: thisAddress,
                uiFeeReceiver: ZERO_ADDRESS,
                market: _withdrawal.markets[i],
                glv: _withdrawal.glvs[i],
                longTokenSwapPath: _withdrawal.longTokenSwapPath[i],
                shortTokenSwapPath: emptyPath,
                minLongTokenAmount: _withdrawal.minLongTokenAmount[i],
                minShortTokenAmount: _withdrawal.minShortTokenAmount[i],
                shouldUnwrapNativeToken: true,
                executionFee: _withdrawal.executionFee[i],
                callbackGasLimit: _withdrawal.callbackGasLimit[i]
            });

            bytes32 key = glvRouter.createGlvWithdrawal(withdrawalParams);

            operations = operations + 1;

            ongoingOperation[key] = true;

            withdrawalInfo[key] = WithdrawalInfo({
                router: msg.sender == router,
                shares: shares,
                extraAmount: extraAmount,
                receiver: receiver,
                callbackContract: callbackContract,
                withdrawalParams: withdrawalParams
            });

            pendingWithdrawnAmounts[_withdrawal.glvs[i]] =
                pendingWithdrawnAmounts[_withdrawal.glvs[i]] + _withdrawal.amounts[i];

            emit GlvWithdrawalCreated(key, _withdrawal.executionFee[i], _withdrawal.callbackGasLimit[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Callback of Executed Withdrawal.
     * @param key Withdrawal key or id.
     */
    function afterGlvWithdrawalExecution(
        bytes32 key,
        GlvWithdrawal.Props memory glvWithdrawal,
        IEventUtils.EventLogData memory eventData
    ) external nonReentrant {
        _onlyControllerOrKeeper(msg.sender);

        if (!ongoingOperation[key]) {
            revert InvalidOperation();
        }

        if (operations == 1) {
            revert OperationNotStarted();
        }

        operations = operations - 1;
        ongoingOperation[key] = false;

        pendingWithdrawnAmounts[glvWithdrawal.addresses.glv] =
            pendingWithdrawnAmounts[glvWithdrawal.addresses.glv] - glvWithdrawal.numbers.glvTokenAmount;

        totalWithdrawalAmount =
            totalWithdrawalAmount + eventData.uintItems.items[0].value + eventData.uintItems.items[1].value;

        WithdrawalInfo memory info = withdrawalInfo[key];

        if (operations == 1 && !withdrawalIssue && info.router) {
            uint256 amount = totalWithdrawalAmount + info.extraAmount;

            totalWithdrawalAmount = 0;

            if (info.shares > 0) {
                IjGlvRouter(router).vault().burn(address(this), info.shares);
            }
            if (info.receiver != address(0)) {
                IERC20(USDC).transfer(info.receiver, amount);
            }
            if (info.callbackContract != address(0)) {
                IWithdrawalCallback(info.callbackContract).withdrawalCallback(info.shares, amount);
            }
        }

        _ethExcess();

        emit GlvWithdrawalExecuted(key, glvWithdrawal, eventData);
    }

    /**
     * @notice Callback of Cancelled Withdrawal.
     * @param key Withdrawal key or id.
     */
    function afterGlvWithdrawalCancellation(
        bytes32 key,
        GlvWithdrawal.Props memory glvWithdrawal,
        IEventUtils.EventLogData memory eventData
    ) external nonReentrant {
        _onlyControllerOrKeeper(msg.sender);

        if (!ongoingOperation[key]) {
            revert InvalidOperation();
        }

        if (operations == 1) {
            revert OperationNotStarted();
        }

        operations = operations - 1;
        ongoingOperation[key] = false;

        pendingWithdrawnAmounts[glvWithdrawal.addresses.glv] =
            pendingWithdrawnAmounts[glvWithdrawal.addresses.glv] - glvWithdrawal.numbers.glvTokenAmount;

        withdrawalIssue = true;

        _ethExcess();

        emit GlvDWithdrawalCancelled(key, glvWithdrawal, eventData);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  ONLY KEEPER                              */
    /* -------------------------------------------------------------------------- */

    function refundGas(address _to) external onlyKeeper {
        IERC20(WETH).transfer(_to, IERC20(WETH).balanceOf(address(this)));
    }

    /* -------------------------------------------------------------------------- */
    /*                                   ONLY GOVERNOR                            */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Update Internal Variables.
     */
    function updateInternalVariables(address _router, address _bot, address _glvRouter) external onlyGovernor {
        _operationCheck();

        router = _router;
        bot = _bot;
        glvRouter = IGlvRouter(_glvRouter);
    }

    /**
     * @notice Add Glv token
     */
    function addGlv(address _newGlv) external onlyGovernor {
        _operationCheck();

        _addGlv(_newGlv);
    }

    /**
     * @notice Remove Glv token
     */
    function removeGlv(address _glv) external onlyGovernor {
        _operationCheck();

        uint256 index = glvIndex[_glv];

        if (index == 0) {
            revert GvlNotFound();
        }

        uint256 length = _glvs.length;

        if (index != length - 1) {
            _glvs[index] = _glvs[length - 1];
        }

        _glvs.pop();

        glvIndex[_glv] = 0;
    }

    /**
     * @notice Moves assets from the strategy to `_to`
     * @param _assets An array of IERC20 compatible tokens to move out from the strategy
     * @param _withdrawNative `true` if we want to move the native asset from the strategy
     */
    function emergencyWithdraw(address _to, address[] memory _assets, bool _withdrawNative) external onlyGovernor {
        uint256 assetsLength = _assets.length;
        for (uint256 i = 0; i < assetsLength;) {
            IERC20 asset_ = IERC20(_assets[i]);
            uint256 assetBalance = asset_.balanceOf(address(this));

            if (assetBalance > 0) {
                // Transfer the ERC20 tokens
                asset_.transfer(_to, assetBalance);
            }

            unchecked {
                ++i;
            }
        }

        uint256 nativeBalance = address(this).balance;

        // Nothing else to do
        if (_withdrawNative && nativeBalance > 0) {
            // Transfer the native currency
            (bool sent,) = payable(_to).call{value: nativeBalance}("");
            if (!sent) {
                revert FailSendETH();
            }
        }

        emit EmergencyWithdrawal(msg.sender, _to, _assets, _withdrawNative ? nativeBalance : 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    PRIVATE                                 */
    /* -------------------------------------------------------------------------- */

    function _onlyControllerOrKeeper(address sender) private view {
        if (!glvRouter.roleStore().hasRole(sender, CONTROLLER) && !hasRole(KEEPER, sender)) {
            revert Unauthorized();
        }
    }

    function _onlyKeeperOrRouter(address sender) private view {
        if (!hasRole(KEEPER, sender) && sender != router) {
            revert Unauthorized();
        }
    }

    function _operationCheck() private view {
        if (operations > 1) {
            revert OngoingOperation();
        }

        if (withdrawalIssue) {
            revert WithdrawalIssue();
        }
    }

    function _glvVault() private view returns (address) {
        return address(glvRouter.glvHandler().glvVault());
    }

    function _addGlv(address _newGlv) private {
        if (glvIndex[_newGlv] > 0) {
            revert GvlAlreadyAdded();
        }

        glvIndex[_newGlv] = _glvs.length;

        _glvs.push(_newGlv);
    }

    function _ethExcess() private {
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool sent,) = bot.call{value: ethBalance}("");
            if (!sent) {
                revert FailSendETH();
            }
        }
    }

    error ZeroAmount();
    error lengthMissMatch();
    error Unauthorized();
    error InvalidOperation();
    error OperationNotStarted();
    error OngoingOperation();
    error WithdrawalIssue();
    error GvlAlreadyAdded();
    error GvlNotFound();
    error FailSendETH();

    event GlvDepositCreated(bytes32 indexed key, uint256 executionFee, uint256 gasLimit);
    event GlvDepositExecuted(bytes32 indexed key, GlvDeposit.Props glvWithdrawal, IEventUtils.EventLogData eventData);
    event GlvDepositCancelled(bytes32 indexed key, GlvDeposit.Props glvWithdrawal, IEventUtils.EventLogData eventData);

    event GlvWithdrawalCreated(bytes32 indexed key, uint256 executionFee, uint256 gasLimit);
    event GlvWithdrawalExecuted(
        bytes32 indexed key, GlvWithdrawal.Props glvWithdrawal, IEventUtils.EventLogData eventData
    );
    event GlvDWithdrawalCancelled(
        bytes32 indexed key, GlvWithdrawal.Props glvWithdrawal, IEventUtils.EventLogData eventData
    );

    event EmergencyWithdrawal(address indexed caller, address indexed to, address[] assets, uint256 nativeBalance);
}
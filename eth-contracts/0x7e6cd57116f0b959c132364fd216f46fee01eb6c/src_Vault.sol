// SPDX-License-Identifier: LicenseRef-CICADA-Proprietary
// SPDX-FileCopyrightText: (c) 2024 Cicada Software, CICADA DMCC. All rights reserved.

pragma solidity ^0.8.28;

import "./dependencies_openzeppelin-contracts-5.0.2_token_ERC20_utils_SafeERC20.sol";
import {Context} from "./dependencies_openzeppelin-contracts-5.0.2_utils_Context.sol";
import "./dependencies_openzeppelin-contracts-5.0.2_utils_Address.sol";
import "./dependencies_uniswap-v2-periphery-1.1.0-beta.0_contracts_interfaces_IUniswapV2Router02.sol";
import "./dependencies_uniswap-v2-core-1.0.1_contracts_interfaces_IUniswapV2Factory.sol";
import "./dependencies_openzeppelin-contracts-5.0.2_access_AccessControl.sol";
import "./dependencies_openzeppelin-contracts-5.0.2_utils_math_Math.sol";

/**
 * @title Vault
 * @notice Manages funds and executes arbitrage operations on behalf of the DeGate arbitrage engine.
 * Handles asset approvals, delegates execution to the strategy, and enforces a USD TVL loss threshold to safeguard funds.
 * @dev The Vault interacts with a strategy contract to perform swaps and can be upgraded to integrate new strategies and DeFi protocols.
 */
contract Vault is AccessControl {
    using SafeERC20 for IERC20;
    using Address for address;

    struct VaultReserves {
        uint256 baseTokenBalance;
        uint256 baseTokenUsdValue;
        uint256 quoteTokenBalance;
        uint256 quoteTokenUsdValue;
        uint256 totalUsdValue;
    }

    // MANAGER_ROLE: Responsible for managing and upgrading the strategy contract.
    // Can grant MANAGER_ROLE and GATEWAY_EXECUTOR_ROLE roles.
    // Typically held by the platform staff via a multisignature wallet. This role allows
    // for the introduction of new methods and integrations with DeFi protocols.
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // GATEWAY_EXECUTOR_ROLE: Held by the arbitrage engine gateway process, this EOA is responsible
    // for triggering arbitrage operations and covering the gas costs associated with these transactions.
    bytes32 public constant GATEWAY_EXECUTOR_ROLE = keccak256("GATEWAY_EXECUTOR_ROLE");

    // FINANCIER_ROLE: Held by the owner of the funds, which could be an externally owned
    // account (EOA) or a multisignature wallet. The holder of this role is responsible for
    // providing the funding for operations and has the exclusive ability to withdraw funds
    // from the vault.
    // Can grant FINANCIER_ROLE to other accounts.
    bytes32 public constant FINANCIER_ROLE = keccak256("FINANCIER_ROLE");

    // MAX_ALLOWED_LOSS_BPS represents the maximum allowed loss in basis points (bps).
    // A value of 1000 bps is equivalent to a 10% maximum loss allowed per single action
    uint256 public constant MAX_ALLOWED_SINGLE_LOSS_BPS = 100;
    uint256 public constant MAX_ALLOWED_CUM_LOSS_BPS = 1000;

    address public strategy;
    IERC20 public baseToken;
    IERC20 public quoteToken;
    IERC20 public usdToken;
    address[] public reservesEvaluationPath;
    IUniswapV2Router02 public router;
    string public constant version = "v0.1.0-flex";
    uint256 public allowedSingleLossBps;
    uint256 public allowedCumLossBps;
    uint256 public currentCumLossBps;

    // These events are emitted during the arbitrage execution process to track the state and results of operations.
    // allowing the arbitrage engine to index, fetch, and analyze the outcomes.
    // `PreExecState` captures the Vault's initial balances and USD TVL before execution.
    // `PostExecState` records the final balances and resulting USD TVL
    // `ExecResult` provides the net changes in balances and USD value.
    event PreExecState(VaultReserves);
    event PostExecState(VaultReserves);
    event ExecResult(int256 baseTokenBalanceChange, int256 quoteTokenBalanceChange, int256 totalUsdValueChange);

    event AllowedLossUpdated(uint256 allowedSingleLossBps, uint256 allowedCumLossBps);
    event StrategyUpdated(address previousStrategy, address newStrategy);

    /**
     * @dev Initializes the Vault with the provided parameters.
     * @param _baseToken Address of the base token (first token in the pair).
     * @param _quoteToken Address of the quote token (second token in the pair).
     * @param _reservesEvaluationPath Route to the USD stablecoin token (for USD valuation).
     * @param _router Address of the Uniswap V2 router (for price impact and USD value calculations).
     * @param _allowedSingleLossBps Allowed single-tx loss in 1/10000 basis points (modifiable by FINANCIER_ROLE).
     * @param _allowedCumLossBps Allowed cumulative loss loss in 1/10000 basis points (modifiable by FINANCIER_ROLE).
     * @param _strategy Address of the strategy contract (modifiable by MANAGER_ROLE).
     * @param _financier Address granted the FINANCIER_ROLE (responsible for funding operations).
     * @param _gatewayExecutor Address granted the GATEWAY_EXECUTOR_ROLE (initiates buy/sell operations).
     * @param _manager Address granted the MANAGER_ROLE (manages strategy upgrades).
     */
    constructor(
        IERC20 _baseToken,
        IERC20 _quoteToken,
        address[] memory _reservesEvaluationPath,
        IUniswapV2Router02 _router,
        uint256 _allowedSingleLossBps,
        uint256 _allowedCumLossBps,
        address _strategy,
        address _financier,
        address _gatewayExecutor,
        address _manager
    ) {
        _validateTokensAndRouter(address(_baseToken), address(_quoteToken), address(_router));
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        router = _router;
        _validateEvaluationPath(_reservesEvaluationPath);
        reservesEvaluationPath = _reservesEvaluationPath;
        require(_allowedSingleLossBps <= MAX_ALLOWED_SINGLE_LOSS_BPS, "ALLOWED_SINGLE_LOSS_OVER_MAX");
        require(_allowedCumLossBps <= MAX_ALLOWED_CUM_LOSS_BPS, "ALLOWED_CUM_LOSS_OVER_MAX");
        allowedSingleLossBps = _allowedSingleLossBps;
        allowedCumLossBps = _allowedCumLossBps;
        strategy = _strategy;
        _setRoleAdmin(GATEWAY_EXECUTOR_ROLE, MANAGER_ROLE);
        _setRoleAdmin(MANAGER_ROLE, MANAGER_ROLE);
        _setRoleAdmin(FINANCIER_ROLE, FINANCIER_ROLE);
        _grantRole(FINANCIER_ROLE, _financier);
        _grantRole(GATEWAY_EXECUTOR_ROLE, _gatewayExecutor);
        _grantRole(MANAGER_ROLE, _manager);
    }

    function updateConfig(
        IERC20 _baseToken,
        IERC20 _quoteToken,
        address[] memory _reservesEvaluationPath,
        IUniswapV2Router02 _router
    ) external onlyRole(MANAGER_ROLE) {
        _validateTokensAndRouter(address(_baseToken), address(_quoteToken), address(_router));
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        router = _router;
        _validateEvaluationPath(_reservesEvaluationPath);
        reservesEvaluationPath = _reservesEvaluationPath;
    }

    /**
     * @notice Updates the allowed USD loss thresholds in basis points (bps).
     * @param _allowedSingleLossBps The new allowed single-operation loss in bps (1 bps = 0.01%).
     * @param _allowedCumLossBps The new allowed cumulative loss in bps (1 bps = 0.01%).
     *
     * Example: `setAllowedLoss(100);` sets the allowed loss to 1%.
     */
    function setAllowedLoss(uint256 _allowedSingleLossBps, uint256 _allowedCumLossBps)
        external
        onlyRole(FINANCIER_ROLE)
    {
        require(_allowedSingleLossBps <= MAX_ALLOWED_SINGLE_LOSS_BPS, "ALLOWED_SINGLE_LOSS_OVER_MAX");
        require(_allowedCumLossBps <= MAX_ALLOWED_CUM_LOSS_BPS, "ALLOWED_CUM_LOSS_OVER_MAX");
        allowedSingleLossBps = _allowedSingleLossBps;
        allowedCumLossBps = _allowedCumLossBps;
        currentCumLossBps = 0;
        emit AllowedLossUpdated(allowedSingleLossBps, allowedCumLossBps);
    }

    /**
     * @notice Updates the strategy contract used by the Vault.
     * @dev This function is used to update the strategy contract that the Vault interacts with for executing arbitrage operations.
     * Can only be called by an account with the MANAGER_ROLE (Typically held by the platform staff via a multisignature wallet)
     * @param _strategy The address of the new strategy contract.
     */
    function setStrategy(address _strategy) external onlyRole(MANAGER_ROLE) {
        require(_strategy != address(0), "STRATEGY_NOTSET");
        require(_strategy != strategy, "SAME_STRATEGY");
        // Revoke approvals from previous strategy for safety
        if (strategy != address(0)) {
            baseToken.forceApprove(strategy, 0);
            quoteToken.forceApprove(strategy, 0);
        }
        strategy = _strategy;
        emit StrategyUpdated(strategy, _strategy);
    }

    /**
     * @dev Executes swap operations initiated by an external DeGate process with GATEWAY_EXECUTOR_ROLE.
     * Approves and flash-loans specified amounts of base and quote tokens from the Vault to the Strategy contract,
     * delegating control for execution. The Strategy completes the operation and returns the funds to the Vault.
     * While temporary USD losses due to slippage and DEX fees are expected, the modifier ensures losses
     * stay within the allowed threshold, mitigating potential mistakes.
     * @param _baseTokenAmount The amount of base tokens to approve and flash-loan to the Strategy.
     * @param _quoteTokenAmount The amount of quote tokens to approve and flash-loan to the Strategy.
     * @param _params Encoded function selector and parameters for the Strategy contract's execution.
     */
    function approveAndExecuteOperation(uint256 _baseTokenAmount, uint256 _quoteTokenAmount, bytes calldata _params)
        external
        onlyRole(GATEWAY_EXECUTOR_ROLE)
    {
        baseToken.forceApprove(strategy, _baseTokenAmount);
        quoteToken.forceApprove(strategy, _quoteTokenAmount);
        VaultReserves memory vaultReservesBefore = getVaultReserves();
        emit PreExecState(vaultReservesBefore);
        strategy.functionCall(_params);
        VaultReserves memory vaultReservesAfter = getVaultReserves();
        _trackAndEnforceLossLimits(vaultReservesBefore, vaultReservesAfter);
        emit PostExecState(vaultReservesAfter);
        emit ExecResult(
            int256(vaultReservesAfter.baseTokenBalance) - int256(vaultReservesBefore.baseTokenBalance),
            int256(vaultReservesAfter.quoteTokenBalance) - int256(vaultReservesBefore.quoteTokenBalance),
            int256(vaultReservesAfter.totalUsdValue) - int256(vaultReservesBefore.totalUsdValue)
        );
    }

    /**
     * @notice Withdraws a specified amount of a given token from the Vault.
     * @dev Allows the funds' owner to withdraw baseToken, quoteToken, or recover any other tokens (e.g., mistakenly sent) from the Vault.
     * This function can only be called by an account with the FINANCIER_ROLE, representing the owner of the funds.
     * @param token The ERC20 token to withdraw.
     * @param amount The amount of the token to withdraw.
     */
    function withdraw(IERC20 token, uint256 amount) external onlyRole(FINANCIER_ROLE) {
        token.safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Calculates and returns the total USD value of the vault's reserves.
     * @dev This function retrieves the balances of two tokens (baseToken and quoteToken),
     *      converts their respective balances into USD value using a Uniswap-like router,
     *      and sums the USD values to return the total value of the reserves.
     *
     * @return usdValue The total USD value of the vault's reserves.
     */
    function getVaultReserves() public view returns (VaultReserves memory) {
        uint256 baseTokenBalance = baseToken.balanceOf(address(this));
        uint256 quoteTokenBalance = quoteToken.balanceOf(address(this));

        uint256 baseTokenUsdValue;
        uint256 quoteTokenUsdValue;

        // If the route is not explicitly specified, evaluate baseToken by the direct route to quoteToken
        // and use theraw quote token balance as USD value
        if (reservesEvaluationPath.length == 0) {
            address[] memory fullEvaluationPath = new address[](2);
            fullEvaluationPath[0] = address(baseToken);
            fullEvaluationPath[1] = address(quoteToken);

            if (baseTokenBalance > 0) {
                fullEvaluationPath[0] = address(baseToken);
                baseTokenUsdValue = router.getAmountsOut(baseTokenBalance, fullEvaluationPath)[1];
            }

            quoteTokenUsdValue = quoteTokenBalance;
        } else {
            address[] memory fullEvaluationPath = new address[](reservesEvaluationPath.length + 1);
            for (uint256 i = 0; i < reservesEvaluationPath.length; i++) {
                fullEvaluationPath[i + 1] = reservesEvaluationPath[i];
            }

            if (baseTokenBalance > 0) {
                fullEvaluationPath[0] = address(baseToken);
                baseTokenUsdValue = router.getAmountsOut(baseTokenBalance, fullEvaluationPath)[1];
            }

            if (quoteTokenBalance > 0) {
                fullEvaluationPath[0] = address(quoteToken);
                quoteTokenUsdValue = router.getAmountsOut(quoteTokenBalance, fullEvaluationPath)[1];
            }
        }

        uint256 totalUsdValue = baseTokenUsdValue + quoteTokenUsdValue;

        VaultReserves memory reserves = VaultReserves({
            baseTokenBalance: baseTokenBalance,
            baseTokenUsdValue: baseTokenUsdValue,
            quoteTokenBalance: quoteTokenBalance,
            quoteTokenUsdValue: quoteTokenUsdValue,
            totalUsdValue: totalUsdValue
        });

        return reserves;
    }

    /**
     * @dev Tracks and enforces loss limits based on the change in reserves.
     * This function calculates the loss in USD value between the reserves before and after an operation.
     * It then converts this loss to basis points (bps) and ensures that the loss does not exceed the allowed single loss
     * and cumulative loss limits. If the loss exceeds these limits, the function reverts.
     *
     * @param reservesBefore The reserves before the operation.
     * @param reservesAfter The reserves after the operation.
     */
    function _trackAndEnforceLossLimits(VaultReserves memory reservesBefore, VaultReserves memory reservesAfter)
        internal
    {
        if (reservesBefore.totalUsdValue > reservesAfter.totalUsdValue) {
            uint256 singleLossUsd = reservesBefore.totalUsdValue - reservesAfter.totalUsdValue;
            // Ensure singleLossBps is at least 1 if a loss occurred to prevent exploiting rounding errors
            uint256 singleLossBps = Math.max((singleLossUsd * 10000) / reservesBefore.totalUsdValue, 1);
            currentCumLossBps += singleLossBps;
            require(singleLossBps <= allowedSingleLossBps, "SINGLE_LOSS_EXCEEDS_ALLOWED");
            require(currentCumLossBps <= allowedCumLossBps, "CUM_LOSS_EXCEEDS_ALLOWED");
        }
    }

    function _validateTokensAndRouter(address _baseToken, address _quoteToken, address _router) internal pure {
        require(_baseToken != address(0), "BASE_TOKEN_NOT_SET");
        require(_quoteToken != address(0), "QUOTE_TOKEN_NOT_SET");
        require(_router != address(0), "ROUTER_NOT_SET");
        require(_baseToken != _quoteToken, "BASE_AND_QUOTE_EQUAL");
    }

    function _validateEvaluationPath(address[] memory _reservesEvaluationPath) internal view {
        for (uint256 i = 0; i < _reservesEvaluationPath.length; i++) {
            require(_reservesEvaluationPath[i] != address(0), "EVALUATION_PATH_CONTAINS_ZERO");
            require(_reservesEvaluationPath[i] != address(baseToken), "EVALUATION_PATH_CONTAINS_BASE");
            require(_reservesEvaluationPath[i] != address(quoteToken), "EVALUATION_PATH_CONTAINS_QUOTE");
        }
    }
}
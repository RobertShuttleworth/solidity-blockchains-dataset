// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import { SafeTransferLib } from "./lib_solmate_src_utils_SafeTransferLib.sol";
import { SafeTransferLib } from "./lib_solmate_src_utils_SafeTransferLib.sol";
import { SafeTransferLib } from "./lib_solmate_src_utils_SafeTransferLib.sol";
import { SwapParams, AddLiquidityParams } from "./contracts_structs_LiquidityStructs.sol";
import { ILiquidityConnector } from "./contracts_interfaces_ILiquidityConnector.sol";
import { ConnectorRegistry } from "./contracts_ConnectorRegistry.sol";
import { DelegateModule } from "./contracts_modules_DelegateModule.sol";
import { ZapIn, ZapOut } from "./contracts_structs_ZapStructs.sol";
import { IZapLib } from "./contracts_interfaces_libraries_IZapLib.sol";
import { ISwapLib } from "./contracts_interfaces_libraries_ISwapLib.sol";

contract ZapLib is DelegateModule, IZapLib {
    error LiquidityAmountError(); // 0x4d0ab6b4

    ISwapLib public immutable swapLib;
    ConnectorRegistry public immutable connectorRegistry;

    constructor(ConnectorRegistry connectorRegistry_, ISwapLib swapLib_) {
        connectorRegistry = connectorRegistry_;
        swapLib = swapLib_;
    }

    function zapIn(
        ZapIn memory zap
    ) external payable {
        uint256 swapDataLength = zap.swaps.length;
        for (uint256 i; i < swapDataLength;) {
            _delegateTo(
                address(swapLib), abi.encodeCall(ISwapLib.swap, (zap.swaps[i]))
            );
            unchecked {
                i++;
            }
        }

        if (zap.addLiquidityParams.lpToken == address(0)) {
            return;
        }

        bool atLeastOneNonZero = false;

        AddLiquidityParams memory addLiquidityParams = zap.addLiquidityParams;
        uint256 addLiquidityParamsTokensLength =
            addLiquidityParams.tokens.length;
        for (uint256 i; i < addLiquidityParamsTokensLength; i++) {
            if (addLiquidityParams.tokens[i] == address(0)) {
                continue;
            }
            if (addLiquidityParams.desiredAmounts[i] == 0) {
                addLiquidityParams.desiredAmounts[i] = IERC20(
                    addLiquidityParams.tokens[i]
                ).balanceOf(address(this));
            }
            if (addLiquidityParams.desiredAmounts[i] > 0) {
                atLeastOneNonZero = true;
                // In case there is USDT or similar dust approval, revoke it
                SafeTransferLib.safeApprove(
                    addLiquidityParams.tokens[i], addLiquidityParams.router, 0
                );
                SafeTransferLib.safeApprove(
                    addLiquidityParams.tokens[i],
                    addLiquidityParams.router,
                    addLiquidityParams.desiredAmounts[i]
                );
            }
        }

        if (!atLeastOneNonZero) {
            revert LiquidityAmountError();
        }

        address routerConnector =
            connectorRegistry.connectorOf(addLiquidityParams.router);

        _delegateTo(
            routerConnector,
            abi.encodeCall(
                ILiquidityConnector.addLiquidity, (addLiquidityParams)
            )
        );

        for (uint256 i; i < addLiquidityParamsTokensLength;) {
            if (addLiquidityParams.tokens[i] != address(0)) {
                // Revoke any dust approval in case the amount was estimated
                SafeTransferLib.safeApprove(
                    addLiquidityParams.tokens[i], addLiquidityParams.router, 0
                );
            }
            unchecked {
                i++;
            }
        }
    }

    function zapOut(
        ZapOut memory zap
    ) external {
        if (zap.removeLiquidityParams.lpToken != address(0)) {
            if (zap.removeLiquidityParams.lpAmountIn > 0) {
                SafeTransferLib.safeApprove(
                    zap.removeLiquidityParams.lpToken,
                    zap.removeLiquidityParams.router,
                    zap.removeLiquidityParams.lpAmountIn
                );
            }
            address routerConnector =
                connectorRegistry.connectorOf(zap.removeLiquidityParams.router);
            _delegateTo(
                address(routerConnector),
                abi.encodeCall(
                    ILiquidityConnector.removeLiquidity,
                    zap.removeLiquidityParams
                )
            );
        }

        uint256 swapDataLength = zap.swaps.length;
        for (uint256 i; i < swapDataLength;) {
            _delegateTo(
                address(swapLib), abi.encodeCall(ISwapLib.swap, (zap.swaps[i]))
            );
            unchecked {
                i++;
            }
        }
    }
}
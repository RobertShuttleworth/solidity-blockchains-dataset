// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

import { BalanceManagement } from './contracts_BalanceManagement.sol';
import { Pausable } from './contracts_Pausable.sol';
import { SystemVersionId } from './contracts_SystemVersionId.sol';
import '../helpers/TransferHelper.sol' as TransferHelper;

/**
 * @title SwapGasEstimateWithUniswapV3Flash
 * @notice Swap gas estimate with Uniswap V3 flash loans
 */
contract SwapGasEstimateWithUniswapV3Flash is SystemVersionId, Pausable, BalanceManagement {
    struct SwapParameters {
        address fromTokenAddress;
        uint256 fromTokenAmount;
        address approvalContract;
        address swapContract;
        bytes swapData;
    }

    struct FlashParameters {
        address flashContract;
        bool isFlashToken1;
    }

    error ResultInfo(bool isSuccess, uint256 gasUsed);

    function estimateSwapGas(
        SwapParameters calldata _swapParameters,
        FlashParameters calldata _flashParameters
    ) external whenNotPaused {
        uint256 amount0;
        uint256 amount1;

        if (_flashParameters.isFlashToken1) {
            amount1 = _swapParameters.fromTokenAmount;
        } else {
            amount0 = _swapParameters.fromTokenAmount;
        }

        IUniswapV3Flash(_flashParameters.flashContract).flash(
            address(this),
            amount0,
            amount1,
            abi.encode(_swapParameters)
        );
    }

    function uniswapV3FlashCallback(
        uint256 /*_fee0*/,
        uint256 /*_fee1*/,
        bytes calldata _data
    ) external whenNotPaused {
        SwapParameters memory swapParameters = abi.decode(_data, (SwapParameters));

        if (swapParameters.approvalContract != address(0)) {
            TransferHelper.safeApprove(
                swapParameters.fromTokenAddress,
                swapParameters.approvalContract,
                swapParameters.fromTokenAmount
            );
        }

        uint256 gasLeftBefore = gasleft();

        (bool swapCallSuccess, ) = swapParameters.swapContract.call(swapParameters.swapData);

        revert ResultInfo(swapCallSuccess, gasLeftBefore - gasleft());
    }
}

interface IUniswapV3Flash {
    function flash(
        address _recipient,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external;
}
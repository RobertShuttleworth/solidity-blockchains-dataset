// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

import { BalanceManagement } from './contracts_BalanceManagement.sol';
import { Pausable } from './contracts_Pausable.sol';
import { SystemVersionId } from './contracts_SystemVersionId.sol';
import '../helpers/TransferHelper.sol' as TransferHelper;

/// @title SwapGasEstimateWithUniswapFlash
/// @notice Swap gas estimate with Uniswap V2/V3 flash loans
contract SwapGasEstimateWithUniswapFlash is SystemVersionId, Pausable, BalanceManagement {
    struct SwapParameters {
        address fromTokenAddress;
        uint256 fromTokenAmount;
        address approvalAddress;
        address swapAddress;
        bytes swapData;
    }

    struct FlashParameters {
        address flashAddress;
        bool isToken1;
        bool isV3;
    }

    error ResultInfo(bool isSuccess, uint256 gasUsed);

    /// @notice The standard "receive" function
    /// @dev Allows native token funds to be received from swap contracts
    receive() external payable {}

    function estimateSwapGas(
        SwapParameters calldata _swapParameters,
        FlashParameters calldata _flashParameters
    ) external whenNotPaused {
        uint256 amount0;
        uint256 amount1;

        if (_flashParameters.isToken1) {
            amount1 = _swapParameters.fromTokenAmount;
        } else {
            amount0 = _swapParameters.fromTokenAmount;
        }

        if (_flashParameters.isV3) {
            IUniswapV3Flash(_flashParameters.flashAddress).flash(
                address(this),
                amount0,
                amount1,
                abi.encode(_swapParameters)
            );
        } else {
            IUniswapV2Flash(_flashParameters.flashAddress).swap(
                amount0,
                amount1,
                address(this),
                abi.encode(_swapParameters)
            );
        }
    }

    function uniswapV3FlashCallback(
        uint256 /*_fee0*/,
        uint256 /*_fee1*/,
        bytes calldata _data
    ) external whenNotPaused {
        _estimateSwapGas(_data);
    }

    function uniswapV2Call(
        address /*_sender*/,
        uint256 /*_amount0*/,
        uint256 /*_amount1*/,
        bytes calldata _data
    ) external whenNotPaused {
        _estimateSwapGas(_data);
    }

    function _estimateSwapGas(bytes calldata _data) private {
        SwapParameters memory swapParameters = abi.decode(_data, (SwapParameters));

        if (swapParameters.approvalAddress != address(0)) {
            TransferHelper.safeApprove(
                swapParameters.fromTokenAddress,
                swapParameters.approvalAddress,
                swapParameters.fromTokenAmount
            );
        }

        uint256 gasLeftBefore = gasleft();

        (bool swapCallSuccess, ) = swapParameters.swapAddress.call(swapParameters.swapData);

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

interface IUniswapV2Flash {
    function swap(uint _amount0Out, uint _amount1Out, address _to, bytes calldata _data) external;
}
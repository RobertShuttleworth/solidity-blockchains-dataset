// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;
import { BalanceManagement } from './contracts_BalanceManagement.sol';
import { Pausable } from './contracts_Pausable.sol';
import { SystemVersionId } from './contracts_SystemVersionId.sol';

/**
 * @title SwapGasEstimate
 * @notice The contract for swap gas estimates
 */
contract SwapGasEstimate is
    SystemVersionId,
    Pausable,
    BalanceManagement
{
    struct SwapData {
        address flashContract;
        bool isAmount1;
        address tokenAddress;
        uint256 tokenAmount;
        address tokenApprovalContract;
        address swapContract;
    }

    SwapData currentSwapData;

    error ResultInfo(bool isSuccess, uint256 gasUsed);

    function estimateSwapGas(SwapData calldata _swapData) external whenNotPaused {
        currentSwapData = _swapData;

        uint256 amount0;
        uint256 amount1;

        if (_swapData.isAmount1) {
            amount1 = _swapData.tokenAmount;
        } else {
            amount0 = _swapData.tokenAmount;
        }

        IFlash(_swapData.flashContract).flash(address(this), amount0, amount1, '');
    }

    function uniswapV3FlashCallback(bytes calldata /*data*/) external {
        revert ResultInfo(true, 42000);
    }
}

interface IFlash {
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}
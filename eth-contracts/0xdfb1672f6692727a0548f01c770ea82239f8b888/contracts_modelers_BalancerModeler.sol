// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./contracts_helpers_ERC20Helper.sol";
import "./contracts_helpers_Constants.sol";

interface BalancerPool {
    function setSwapFeePercentage(uint256 swapFeePercentage) external;
    function getSwapFeePercentage() external view returns (uint256 fee);
}

interface BalancerVault {
    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    enum JoinKind {
        INIT,
        EXACT_TOKENS_IN_FOR_BPT_OUT,
        TOKEN_IN_FOR_EXACT_BPT_OUT,
        ALL_TOKENS_IN_FOR_EXACT_BPT_OUT
    }
    enum ExitKind {
        EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
        EXACT_BPT_IN_FOR_TOKENS_OUT,
        BPT_IN_FOR_EXACT_TOKENS_OUT
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address recipient;
        bool toInternalBalance;
    }

    struct JoinPoolRequest {
        address[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    struct ExitPoolRequest {
        address[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData;
    }

    function joinPool(bytes32 poolId, address sender, address recipient, JoinPoolRequest memory request)
        external
        payable;

    function exitPool(bytes32 poolId, address sender, address payable recipient, ExitPoolRequest memory request)
        external;

    function swap(SingleSwap memory singleSwap, FundManagement memory funds, uint256 minAmount, uint256 deadline)
        external
        returns (uint256 amountCalculated);
}

contract BalancerModeler is ERC20Helper {
    function balancerSwap(
        BalancerVault vault,
        bytes32 poolId,
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 minAmount,
        address recipient
    ) external returns (uint256) {
        BalancerVault.SingleSwap memory singleSwap = BalancerVault.SingleSwap(
            poolId, BalancerVault.SwapKind.GIVEN_IN, sellToken, buyToken, sellAmount, abi.encode(0)
        );
        return vault.swap(
            singleSwap,
            BalancerVault.FundManagement(address(this), false, recipient, false),
            minAmount,
            type(uint256).max // deadline
        );
    }

    function balancerAddLiquidity(
        BalancerVault vault,
        bytes32 poolId,
        uint256 sellTokenIndex,
        address buyToken,
        uint256 sellAmount,
        uint256 minAmount,
        address recipient,
        address[] memory assets
    ) external returns (uint256 buyAmount) {
        uint256 startBalance = getBalance(buyToken, recipient);
        uint256[] memory amounts = new uint256[](assets.length);
        amounts[sellTokenIndex] = sellAmount;
        bytes memory userData = abi.encode(BalancerVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amounts, minAmount);

        BalancerVault.JoinPoolRequest memory request = BalancerVault.JoinPoolRequest(assets, amounts, userData, false);

        vault.joinPool(poolId, address(this), recipient, request);

        uint256 endBalance = getBalance(buyToken, recipient);

        buyAmount = endBalance - startBalance;
    }

    function balancerRemoveLiquidity(
        BalancerVault vault,
        bytes32 poolId,
        uint256 sellAmount,
        address buyToken,
        uint256 buyTokenIndex,
        uint256 minAmount,
        address payable recipient,
        address[] memory assets
    ) external returns (uint256 buyAmount) {
        uint256 startBalance = getBalance(buyToken, recipient);
        uint256[] memory minAmounts = new uint256[](assets.length);
        minAmounts[buyTokenIndex] = minAmount;
        bytes memory userData =
            abi.encode(BalancerVault.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, sellAmount, buyTokenIndex);
        BalancerVault.ExitPoolRequest memory request =
            BalancerVault.ExitPoolRequest(assets, minAmounts, userData, false);
        vault.exitPool(poolId, address(this), recipient, request);
        uint256 endBalance = getBalance(buyToken, recipient);
        buyAmount = endBalance - startBalance;
    }

    function balancerSetSubsidizedFee(address _poolAddress, uint256 _subsidy) external {
        BalancerPool pool = BalancerPool(_poolAddress);
        uint256 fee = pool.getSwapFeePercentage();
        uint256 subsidy = (fee * _subsidy) / ONE;
        uint256 newFee = fee - subsidy;

        pool.setSwapFeePercentage(newFee);
    }
}
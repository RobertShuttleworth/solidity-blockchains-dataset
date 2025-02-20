// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;
import "./contracts_interfaces_IDataHub.sol";

interface IExecutor {
    function TransferBalances(
        bytes32[2] memory pair,
        address[] memory takers,
        address[] memory makers,
        uint256[] memory taker_amounts,
        uint256[] memory maker_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts,
        bool[][2] memory trade_side
    ) external;

    function fetchOrderBookProvider() external view returns (address);

    function fetchDaoWallet() external view returns (address);

    function divideFee(bytes32 token, uint256 amount) external;

    // function aggregated_trade_in_process_success(
    //     address user,
    //     bytes32[2] memory path, // path[0]: tokenOut, path[1]: tokenIn
    //     uint256 amountIn,
    //     string memory chainId, // 1 | 137 | BTC | SOL
    //     string memory tokenInAddress // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
    // ) external returns (bool);

    struct CrossChainAggregatedTrade {
        address user;
        bytes32[2] path; // path[0]: tokenOut, path[1]: tokenIn
        uint256 amountOut; // Vault -> Uniswap
        uint256 amountInMin; // Vault <- Uniswap
        string[2] chainId; // 1 | 137 | BTC | SOL
        string[2] tokenAddress; // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
    }

    function crossChainAggregatedTradeDetail(
        uint256 nonce
    ) external view returns (CrossChainAggregatedTrade memory);

    function aggregatedTrade(
        bytes32[2] memory path, // path[0]: tokenOut, path[1]: tokenIn
        uint256 amountOut, // Vault -> Uniswap
        uint256 amountInMin, // Vault <- Uniswap
        string[2] memory chainId, // 1 | 137 | BTC | SOL
        string[2] memory tokenAddress, // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
        bool crossChain,
        uint256 crossChainAggregatedTrade_nonce // only if crossChain = true - idk how the fuck to include this parameter
    ) external payable;
}
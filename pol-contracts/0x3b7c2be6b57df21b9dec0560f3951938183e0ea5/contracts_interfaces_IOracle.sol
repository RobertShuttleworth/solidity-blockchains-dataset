// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IOracle {
    function ProcessTrade(
        bytes32[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        bool[][2] memory trade_side,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts
    ) external;

    // function revertTrade(
    //     bytes32[2] memory pair,
    //     address[] memory takers,
    //     address[] memory makers,
    //     uint256[] memory taker_amounts,
    //     uint256[] memory maker_amounts
    // ) external;

    function ProcessWithdraw(
        address user,
        bytes32 token,
        string memory chainId,
        string memory tokenAddress,
        uint256 amount
    ) external;

    function checkWithdrawalDetails(
        uint256 nonce,
        address user,
        bytes32 token,
        uint256 amount
    ) external view;

    function setWithdrawalSuccess(uint256 nonce) external;

    function setWithdrawalFail(uint256 nonce) external;

    function ProcessAggregatedTrade(
        address user,
        bytes32[2] memory path, // path[0]: tokenOut, path[1]: tokenIn
        uint256 amountOut, // Vault -> Uniswap
        uint256 amountInMin, // Vault <- Uniswap
        string memory chainId, // 1 | 137 | BTC | SOL
        string[2] memory tokenAddress, // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
        bool crossChain,
        uint256 crossChainAggregatedTradeNonce
    ) external;

    function checkAggregatedTradeDetails(
        uint256 nonce,
        address user,
        bytes32[2] memory path, // path[0]: tokenOut, path[1]: tokenIn
        uint256 amountOut // Vault -> Uniswap
    ) external view;

    function setAggregatedTradeSuccess(uint256 nonce) external;

    function setAggregatedTradeFail(uint256 nonce) external;

    function ProcessCCTPForWithdraw(
        address user,
        bytes32 source_token, // hash(chain.USDC)
        bytes32 target_token, // hash(chain.USDC)
        uint256 amount,
        string memory source_chainId, // 1 | 137 | BTC | SOL
        string memory source_token_address, // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
        string memory target_chainId, // 1 | 137 | BTC | SOL
        string memory target_token_address // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
    ) external;

    function checkWithdrawalCCTPDetails(
        uint256 nonce,
        address user,
        bytes32 source_token,
        bytes32 target_token,
        uint256 amount
    ) external view;

    function setWithdrawalCCTPSuccess(uint256 nonce) external;

    function setWithdrawalCCTPFail(uint256 nonce) external;

    function ProcessCycleCCTPForAggregatedTrade(
        address user,
        uint256 transactionId,
        bytes32 source_token, // chain.USDC
        bytes32 target_token, // chain.USDC
        uint256 amount
    ) external;

    function checkAggregatedTradeCCTPDetails(
        uint256 nonce,
        address user,
        uint256 transactionId,
        bytes32 source_token,
        bytes32 target_token,
        uint256 amount
    ) external view;

    function setAggregatedTradeCCTPSuccess(uint256 nonce) external;

    function setAggregatedTradeCCTPFail(uint256 nonce) external;
}
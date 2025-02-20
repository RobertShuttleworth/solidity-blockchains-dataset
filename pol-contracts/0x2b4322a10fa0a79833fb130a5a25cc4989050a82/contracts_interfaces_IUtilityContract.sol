// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IUtilityContract {
    // struct AggregatedTradeInfo {
    //     address user;
    //     bytes32[2] path;
    //     uint256 amountOut;
    //     uint256 amountInMin;
    //     string chainId;
    //     string[2] tokenAddress;
    //     address[3] airnode_details;
    //     bytes32 endpointId;
    // }

    // function validateMarginStatus(
    //     address user,
    //     bytes32 token
    // ) external view returns (bool);

    function calculateTradeLiabilityAddtions(
        bytes32[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) external returns (uint256[] memory, uint256[] memory);

    // function returnPending(
    //     address user,
    //     bytes32 token
    // ) external view returns (uint256);

    // function calculateAmountToAddToLiabilities(
    //     address user,
    //     bytes32 token,
    //     uint256 amount
    // ) external returns (uint256);

    // function returnAssets(
    //     address user,
    //     bytes32 token
    // ) external view returns (uint256);

    // function returnBulkAssets(
    //     address[] memory users,
    //     bytes32 token
    // ) external view returns (uint256);

    // // function returnliabilities(
    // //     address user,
    // //     bytes32 token
    // // ) external view returns (uint256);

    // function returnMaintenanceRequirementForTrade(
    //     bytes32 token,
    //     uint256 amount
    // ) external view returns (uint256);

    // function processMargin(
    //     bytes32[2] memory pair,
    //     address[][2] memory participants,
    //     uint256[][2] memory trade_amounts
    // ) external returns (bool);

    // function fetchBorrowProportionList(
    //     uint256 dimension,
    //     uint256 startingIndex,
    //     uint256 endingIndex,
    //     bytes32 token
    // ) external view returns (uint256[] memory);

    // function fetchRatesList(
    //     uint256 dimension,
    //     uint256 startingIndex,
    //     uint256 endingIndex,
    //     bytes32 token
    // ) external view returns (uint256[] memory);

    // function chargeStaticLiabilityInterest(
    //     bytes32 token,
    //     uint256 index
    // ) external view returns (uint256);

    function validateTradeAmounts(
        uint256[][2] memory trade_amounts
    ) external view returns (bool);

    // function debitAssetInterest(address user, bytes32 token) external;

    // function returnEarningProfit(
    //     address user,
    //     bytes32 token
    // ) external view returns (uint256);

    // function maxBorrowCheck(
    //     bytes32[2] memory pair,
    //     address[][2] memory participants,
    //     uint256[][2] memory trade_amounts
    // ) external view returns (bool);

    // function averageBorrowProportion(
    //     uint256 dimension,
    //     uint256 startingIndex,
    //     uint256 endingIndex,
    //     bytes32 token
    // ) external view returns (uint256);

    // function averageInterestRate(
    //     uint256 dimension,
    //     uint256 startingIndex,
    //     uint256 endingIndex,
    //     bytes32 token
    // ) external view returns (uint256);

    function getLastCctpCycleTxId(address user) external view returns (uint256);

    function updateLastCctpCycleTxId(address user) external;

    function setCctpCycleTxIdCurrentSuccessAmount(
        address user,
        uint256 txId,
        uint256 value
    ) external;

    function setCctpCycleTxIdCurrentFailedAmount(
        address user,
        uint256 txId,
        uint256 value
    ) external;

    function setCctpCycleTxIdTotalAmount(
        address user,
        uint256 txId,
        uint256 value
    ) external;

    function addCctpCycleTxIdTokens(
        address user,
        uint256 txId,
        bytes32 value
    ) external;

    function addCctpCycleTxIdAmounts(
        address user,
        uint256 txId,
        uint256 value
    ) external;

    function setAggregatedTradeInfo(
        uint256 txId,
        address user,
        bytes32[2] memory path,
        uint256 amountOut,
        uint256 amountInMin,
        string memory chainId,
        string[2] memory tokenAddress
    ) external;
}
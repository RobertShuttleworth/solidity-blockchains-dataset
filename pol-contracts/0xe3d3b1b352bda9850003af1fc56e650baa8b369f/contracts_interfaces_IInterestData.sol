// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;
//import "../interfaces/IDataHub.sol";

interface IInterestData {
    function updateLiabilities(
        address user,
        bytes32 token,
        uint256 liabilitiesAccrued,
        bool minus
    ) external;

    function updateLendingPoolAssets(
        bytes32 token,
        uint256 amount,
        bool direction
    ) external;

    function calculateInitialManipulatedLiabilities(
        bytes32 token,
        uint256 rawLiabilities
    ) external view returns (uint256);

    function calculateActualCurrentLiabilities(
        address user,
        bytes32 token
    ) external view returns (uint256);

    function returnInterestCharge(
        address user,
        bytes32 token
    ) external view returns (uint256);

    function updateCIMandTBA(bytes32 token) external;

    function simulateCIMandTBA(
        bytes32 token
    ) external view returns (uint256, uint256, uint256, uint256);

    function calculateManipulatedTotalBorrowedAmount(
        bytes32 token,
        uint256 rawTotalBorrowedAmount // I'm not sure if we need to pass this in here or if we should just get it from the asset logs.
    ) external view returns (uint256);

    function calculateActualCurrentLendingPoolAssets(
        address user,
        bytes32 token
    ) external view returns (uint256);

    function calculateInitialManipulatedLendingPoolAssets(
        bytes32 token,
        uint256 rawLendingPoolAssets
    ) external view returns (uint256);

    function calculateInitialManipulatedLendingPoolSupply(
        bytes32 token,
        uint256 rawLendingPoolSupply // I'm not sure if we need to pass this in here or if we should just get it from the asset logs.
    ) external view returns (uint256);

    function calculateActualTotalLendingPoolSupply(
        bytes32 token
    ) external view returns (uint256);

    // function calculateActualTotalBorrowedAmount(
    //     bytes32 token
    // ) external view returns (uint256);

    // function updateInterestIndex(
    //     bytes32 token,
    //     uint256 index,
    //     uint256 value
    // ) external;

    // function fetchTimeScaledRateIndex(
    //     uint targetEpoch,
    //     bytes32 token,
    //     uint256 index
    // ) external view returns (interestDetails memory);

    function getStorkOraclePrice(
        bytes32 _token
    ) external view returns (uint256);
}
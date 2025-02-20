// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

interface IFeeManager {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event MintManagementShares(
        address indexed manager, uint256 newManagerShares, address indexed protocolTreasury, uint256 newProtocolShares
    );
    event MintPerformanceShares(
        address indexed manager, uint256 newManagerShares, address indexed protocolTreasury, uint256 newProtocolShares
    );

    event SetHighWaterMarkSharePrice(uint256 indexed sharePrice);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error OnlyLendingVault();
    error OnlyLendingVaultOrOperator();
    error FeeExceedsMaximumAllowed();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    struct Fees {
        uint16 management;
        uint16 performance;
    }

    enum FeeTypes {
        MANAGEMENT,
        PERFORMANCE
    }

    function fees() external returns (uint16, uint16);

    function lastManagementFeeTimestamp() external returns (uint256);

    function highWaterMarkSharePrice() external returns (uint256);

    function lendingVault() external returns (address);

    function setPerformanceFee(uint16 fee) external;

    function performanceFee() external view returns (uint16);

    function setManagementFee(uint16 fee) external;

    function updateProtocolSplit(uint8 newProtocolSplit) external;

    function managementFee() external returns (uint16);

    function accrueFees() external;
}
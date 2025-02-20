// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

interface IVaultAdmin {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event SetManager(address indexed newManager);
    event SetOperator(address indexed operator, bool indexed approved);
    event SetFee(uint16 feeBps, uint256 indexed feeType);
    event SetProtocolTreasury(address indexed newTreasury);
    event SetWhitelistStatus(bool indexed status);
    event UpdateProtocolSplit(uint8 indexed newSplit);
    event UpdateWhitelist(address indexed whitelistedAddress, bool indexed approved);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CannotBeZeroAddress();
    error AddressNotWhitelisted();
    error OnlyVaultManager();
    error OnlyOperator();
    error OnlyProtocolTreasury();
    error WhitelistNotEnabled();
    error ProtocolSplitExceedsMaximumAllowed();

    /*//////////////////////////////////////////////////////////////
                                FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function protocolTreasury() external returns (address);

    function manager() external returns (address);

    function isOperator(address operator) external returns (bool);

    function whitelistedAddresses(address) external returns (bool);

    function whitelistEnabled() external returns (bool);

    function protocolSplit() external returns (uint8);

    function MAX_SPLIT() external returns (uint8);

    function baseUnit() external returns (uint256);

    function updateWhitelistStatus(bool status) external;

    function updateWhitelist(address depositor, bool approved) external;

    function setManager(address newManager) external;

    function setOperator(address operator, bool approved) external;

    function setProtocolTreasury(address newProtocolTreasury) external;

}
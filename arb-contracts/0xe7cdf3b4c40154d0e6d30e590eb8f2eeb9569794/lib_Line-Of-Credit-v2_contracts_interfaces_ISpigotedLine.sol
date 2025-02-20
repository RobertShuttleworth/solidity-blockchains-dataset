// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

import {ISpigot} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigot.sol";

interface ISpigotedLine {
    struct ClaimAndTradeParams {
        address claimToken;
        address targetToken;
        address payable swapTarget;
        address spigot;
        uint256 unused;
        uint128 swapFee;
        address protocolTreasury;
        bytes zeroExTradeData;
    }

    /**
     * @notice - Log how many spigot tokens are used to repay debt after claimAndRepay
     *         - dont need to track value like other events because _repay already emits that
     *         - Mainly used to log debt that is paid via Spigot directly vs other sources. Without this event it's a lot harder to parse that offchain.
     */
    event SpigotPayment(address indexed token, uint256 indexed amount);

    /**
     * @notice - Log how many spigot tokens were traded for credit tokens.
     *         - Differs from SpigotPayment because we trade tokens at different times from repaying with spigot tokens
     * @dev    - Can you use to figure out price of spigot tokens offchain since we only have an oracle for credit tokens
     * @dev    - Spigot tokens may be from reserves or from Spigot tokens.
     */
    event TradeSpigotTokens(
        address indexed spigotToken,
        uint256 spigotTokenAmount,
        address indexed debtToken,
        uint256 indexed debtTokensBought
    );

    // 0 for spigot token, 1 for credit token
    event ReservesChanged(address indexed token, int256 indexed diff, uint256 tokenType);

    error ReservesOverdrawn(address token, uint256 amountAvailable);
    error LineHasActiveCreditPositions(uint256 numActiveCreditPositions);

    // Borrower functions
    function useAndRepay(uint256 amount) external;
    function claimAndRepay(address claimToken, bytes calldata zeroExTradeData) external returns (uint256);
    function claimAndTrade(address claimToken, bytes calldata zeroExTradeData)
        external
        returns (uint256 tokensBought);

    // Spigot management functions
    function sweep(address to, address token, uint256 amount) external;

    // getters
    function unused(address token) external view returns (uint256);
    function tradeable(address token) external view returns (uint256);
    function spigot() external returns (ISpigot);
    function swapTarget() external view returns (address payable);
}
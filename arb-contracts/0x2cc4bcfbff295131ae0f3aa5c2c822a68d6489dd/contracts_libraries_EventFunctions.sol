// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

contract EventFunctions {

    event FundAccept();

    event FundLock();

    event Issuance();

    event Mature();

    event Deposit(
        address indexed user,
        uint256 amount
    );

    event WithdrawPrincipal(
        address indexed user,
        uint256 amount
    );

    event WithdrawCoupon(
        address indexed user,
        uint256 amount
    );

    event WithdrawOption(
        address indexed user,
        uint256 amount
    );

    event RedeemOptionPayout(
        address indexed from,
        uint256 amount
    );

    event DistributeFunds(
        address indexed qredoDeribit,
        uint256 optionRate,
        address indexed pendleRouter,
        uint8 yieldRate
    );
    
    event RedeemYield(
        address pendleRouter,
        uint256 amount
    );

    event EarlyWithdraw(
        address indexed user,
        uint256 noOfBlock, 
        uint256 exactPtIn, 
        uint256 earlyWithdrawUser
    );

    event UserOptionPositionPaid(uint256 totalOptionPosition);

    /// @notice Event emitted when new issuance cycle is updated
    event UpdateParameters(
        string name,
        address router, 
        address market
    );

    event UpdateStructure(
        uint256 strikePrice1,
        uint256 strikePrice2,
        uint256 strikePrice3,
        uint256 strikePrice4,
        uint256 tr1,
        uint256 tr2,
        string apy,
        uint8 underlyingSpotRef
    );
    
    event Coupon(
        address indexed user,
        uint256 amount
    );

    event OptionPayout(
        address indexed user,
        uint256 amount
    );

    event UpdateCoupon(
        uint256 newCoupon
    );

    event AddOptionProfitList(
        address[] userList,
        uint256[] amountList
    );

    event WhiteList(
        address indexed account
    );

    event RemoveFromWhiteList(
        address indexed account
    );

    event AddAdmin(
        address indexed account
    );
}

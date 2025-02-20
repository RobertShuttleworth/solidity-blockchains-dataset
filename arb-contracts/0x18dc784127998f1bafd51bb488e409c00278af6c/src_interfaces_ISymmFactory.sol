// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Vertex Factory Interface
/// @notice Interface for managing platform fees, callbacks, and token
/// withdrawals in a trading environment.
interface ISymmFactory {
    /*//////////////////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event PlatformFeeApplied(
        address indexed referee,
        uint256 grossAmount,
        uint256 feeAmount,
        uint256 feeDiscount
    );
    event BackendWalletChanged(
        address indexed oldBackendWallet, address indexed newBackendWallet
    );

    event SymmPlatformFeeBPSChanged(uint256 newSymmPlatformFeeBPS);

    event EthWithdrawnFromSymmFactory(uint256 amount, address withdrawAddress);

    event ClaimedFeeDiscountInETH(address indexed user, uint256 amount);

    event TokenWithdrawal(
        address indexed token, address indexed to, uint256 indexed amount
    );

    event DepositAndDistributeFeeAmount(
        uint256 totalAmount,
        uint256 claimableFeeDiscount,
        uint256 referralWithdrawal
    );

    event USDCWithdrawalFailed(uint256 amount);

    event StakerDistributionFailed(uint256 amount);
    event ReferralTransferFailed(uint256 amount);

    /*//////////////////////////////////////////////////////////////////////////
                                EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function initialize(
        address _comptroller,
        address _backendWallet,
        uint256 _symmPlatformFeeBPS
    )
        external;

    /// @notice Function to view the base gas fee
    function symmPlatformFeeBPS() external view returns (uint256);

    /// @notice Function to view the callback wallet address
    function backendWallet() external view returns (address);

    function applyPlatformFeeEth(
        address _referee,
        uint256 _grossAmount,
        bytes32 referralCode
    )
        external;

    function claimFeeDiscount() external;

    function setBackendWallet(address _backendWallet) external;

    function setSymmPlatformFeeBPS(uint256 _symmPlatformFeeBPS) external;

    function setSwapData(
        address _uniswapRouter,
        address _usdcToken,
        uint24 _poolFee
    )
        external;

    function setDistributionCaps(
        uint256 _stakersTreasuryCap,
        uint256 _feeDiscountCap,
        uint256 _referralCap
    )
        external;

    /// @notice Function to withdraw eth fees from the vertex factory to
    /// prevent stuck funds
    function withdrawEth(uint256 _amount, address _withdrawAddress) external;

    function withdrawToken(
        address token,
        address to,
        uint256 amount
    )
        external
        returns (bool);

    function distributeFeeAmount(
        uint256 amountForClaimableDiscount,
        uint256 amountForStakerFee,
        uint256 amountForReferralRewards
    )
        external
        payable;
}
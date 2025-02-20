// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import { IComptroller } from "./src_interfaces_IComptroller.sol";
import { IPlatformLogic } from "./src_interfaces_IPlatformLogic.sol";
import { ComptrollerManager } from "./src_helpers_ComptrollerManager.sol";
import { IFeeRebateManager } from "./src_interfaces_IFeeRebateManager.sol";
import { SafeTransferLib } from "./lib_solady_src_utils_SafeTransferLib.sol";
import { ReentrancyGuard } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_ReentrancyGuard.sol";
import { Errors } from "./src_libraries_Errors.sol";
import { ISymmFactory } from "./src_interfaces_ISymmFactory.sol";
import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { ISwapRouter } from "./src_interfaces_ISwapRouter.sol";

contract SymmFactory is
    ComptrollerManager,
    ReentrancyGuard,
    ISymmFactory,
    Initializable
{
    uint256 public totalFeeCollected; // Amount in ETH that user paid to Pear as
        // Platform Fee
    uint256 public totalFeeFilled; // Amount in ETH that admin adds to this
        // contract

    uint256 public symmPlatformFeeBPS;

    address public backendWallet;

    // claimable fee for user
    mapping(address => uint256) public claimableFeeDiscountInETH;

    uint256 public remainingReferralWithdrawal;
    uint256 public remainingClaimableFeeDiscountInEth;
    uint256 public remainingStakersAndTreasuryFee;

    //uniswap V3
    ISwapRouter public uniswapV3Router;
    address public USDC;
    uint24 public pool_fee;

    // Define distribution percentages
    uint256 public STAKERS_TREASURY_CAP = 65; // 65%
    uint256 public FEE_DISCOUNT_CAP = 25; // 25%
    uint256 public REFERRAL_CAP = 10; // 10%

    /// @notice Modifier to restrict access to only the contract owner.
    modifier onlyAdmin() {
        if (comptroller.admin() != msg.sender) {
            revert Errors.SymmFactory_NotComptrollerAdmin();
        }
        _;
    }

    modifier onlyBackendWallet() {
        if (backendWallet != msg.sender) {
            revert Errors.SymmFactory_NotBackendWallet();
        }
        _;
    }

    modifier onlyAdminOrBackend() {
        if (comptroller.admin() != msg.sender && backendWallet != msg.sender) {
            revert Errors.SymmFactory_NotComptrollerAdmin();
        }
        _;
    }

    receive() external payable {
        uint256 amount = msg.value;
        _distributeReceivedFunds(amount);
    }

    constructor() {
        _disableInitializers();
    }

    /**
     * @param _comptroller Address of the Comptroller instance containing the
     * contract's admin
     * @param _backendWallet Address of the wallet that will send fee
     * @param _symmPlatformFeeBPS Platform fee in basis points
     */
    function initialize(
        address _comptroller,
        address _backendWallet,
        uint256 _symmPlatformFeeBPS
    )
        external
        override
        initializer
    {
        comptroller = IComptroller(_comptroller);
        backendWallet = _backendWallet;
        symmPlatformFeeBPS = _symmPlatformFeeBPS;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _distributeReceivedFunds(uint256 _amount) internal {
        if (_amount == 0) {
            revert Errors.SymmFactoryNoAmountToDistribute();
        }
        address platformLogic = comptroller.getPlatformLogic();
        uint256 remainingAmount = _amount;

        totalFeeFilled += _amount;

        // First priority: Send to stakers if there's remaining amount (65%)
        if (remainingAmount > 0 && remainingStakersAndTreasuryFee > 0) {
            uint256 maxStakersAmount = (_amount * STAKERS_TREASURY_CAP) / 100;
            uint256 stakersAmount = min(
                maxStakersAmount,
                min(remainingAmount, remainingStakersAndTreasuryFee)
            );

            try IPlatformLogic(platformLogic)
                .splitBetweenStakersAndTreasuryFromSymm{ value: stakersAmount }() {
                remainingStakersAndTreasuryFee -= stakersAmount;
                remainingAmount -= stakersAmount;
            } catch {
                // If splitting fails, keep the amount in contract
                // Optionally emit an event for monitoring
                emit StakerDistributionFailed(stakersAmount);
            }
        }

        // Second priority: Keep funds for fee discount if needed (25%)
        if (remainingAmount > 0 && remainingClaimableFeeDiscountInEth > 0) {
            uint256 maxFeeDiscountAmount = (_amount * FEE_DISCOUNT_CAP) / 100;
            uint256 feeDiscountAmount = min(
                maxFeeDiscountAmount,
                min(remainingAmount, remainingClaimableFeeDiscountInEth)
            );

            remainingClaimableFeeDiscountInEth -= feeDiscountAmount;
            remainingAmount -= feeDiscountAmount;
        }

        // Third priority: Send referral withdrawal (10%)
        if (remainingAmount > 0 && remainingReferralWithdrawal > 0) {
            uint256 maxReferralAmount = (_amount * REFERRAL_CAP) / 100;
            uint256 referralAmount = min(
                maxReferralAmount,
                min(remainingAmount, remainingReferralWithdrawal)
            );

            SafeTransferLib.safeTransferETH(platformLogic, referralAmount);
            remainingReferralWithdrawal -= referralAmount;
            remainingAmount -= referralAmount;
        }

        emit DepositAndDistributeFeeAmount(
            _amount,
            remainingClaimableFeeDiscountInEth,
            remainingReferralWithdrawal
        );
    }

    function distributeUSDC() external onlyAdminOrBackend {
        uint256 usdcAmount = IERC20(USDC).balanceOf(address(this));
        if (usdcAmount == 0) {
            revert Errors.SymmFactoryNoAmountToDistribute();
        }
        IERC20(USDC).approve(address(uniswapV3Router), usdcAmount);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
            tokenIn: USDC,
            tokenOut: uniswapV3Router.WETH9(),
            fee: pool_fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: usdcAmount,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = uniswapV3Router.exactInputSingle(params);

        // This will make WETH contract send funds to this SymmFactory contract
        // and this will trigger the `receive` function - which calls
        // `_distributeReceivedFunds()`
        (bool success,) = uniswapV3Router.WETH9().call(
            abi.encodeWithSignature("withdraw(uint256)", amountOut)
        );

        if (!success) {
            revert Errors.SymmFactoryFailedToWithdrawUSDC();
        }
    }

    /// @inheritdoc ISymmFactory
    function distributeFeeAmount(
        uint256 amountForClaimableDiscount,
        uint256 amountForStakerFee,
        uint256 amountForReferralRewards
    )
        external
        payable
        override
        onlyAdminOrBackend
    {
        uint256 totalAmount = amountForClaimableDiscount + amountForStakerFee
            + amountForReferralRewards;

        if (totalAmount > msg.value) {
            revert Errors.SymmFactoryIncorrectAmountSent();
        }
        address platformLogic = comptroller.getPlatformLogic();

        // Distribute amountForStakerFee
        if (amountForStakerFee > 0) {
            try IPlatformLogic(platformLogic)
                .splitBetweenStakersAndTreasuryFromSymm{ value: amountForStakerFee }(
            ) {
                remainingStakersAndTreasuryFee -= amountForStakerFee;
            } catch {
                // If splitting fails, keep the amount in contract
                // Optionally emit an event for monitoring
                emit StakerDistributionFailed(amountForStakerFee);
            }
        }

        remainingClaimableFeeDiscountInEth = (
            remainingClaimableFeeDiscountInEth > amountForClaimableDiscount
        ) ? remainingClaimableFeeDiscountInEth - amountForClaimableDiscount : 0;

        if (amountForReferralRewards > 0 && remainingReferralWithdrawal > 0) {
            uint256 minValue = (
                amountForReferralRewards > remainingReferralWithdrawal
            ) ? amountForReferralRewards : remainingReferralWithdrawal;

            SafeTransferLib.safeTransferETH(platformLogic, minValue);
            remainingReferralWithdrawal -= minValue;
        }
    }

    /// @inheritdoc ISymmFactory
    /**
     * @notice Apply the platform fee to the user's trade amount in ETH.
     * @param _referee The address of the user who is paying the fee.
     * @param _grossAmount The gross amount of the trade in USD.
     * @param referralCode The referral code of the user who referred the
     */
    function applyPlatformFeeEth(
        address _referee,
        uint256 _grossAmount,
        bytes32 referralCode
    )
        external
        nonReentrant
        onlyBackendWallet
    {
        uint256 feeAmount = (_grossAmount * symmPlatformFeeBPS) / 10_000;
        address platformLogic = comptroller.getPlatformLogic();
        uint256 feeAmountInEth =
            IPlatformLogic(platformLogic).convertFeeToEth(feeAmount);

        if (referralCode != 0) {
            IPlatformLogic(platformLogic).addRefereeFromFactory(
                referralCode, _referee
            );
        }

        // calculating the fee Amounts needed for later use in PlatformLogic
        // feeAmountAfterDiscount will be in ETH
        (uint256 feeAmountAfterDiscount, uint256 referrerWithdrawal) =
        IPlatformLogic(platformLogic).applyPlatformFeeEthSymm(
            _referee, feeAmountInEth
        );

        IFeeRebateManager(comptroller.getFeeRebateManager()).updateTradeDetails(
            _referee, _grossAmount, feeAmountAfterDiscount
        );

        uint256 discountInEth = feeAmountInEth - feeAmountAfterDiscount;

        totalFeeCollected += feeAmountInEth;
        remainingClaimableFeeDiscountInEth += discountInEth;
        remainingReferralWithdrawal += referrerWithdrawal;
        remainingStakersAndTreasuryFee += feeAmountAfterDiscount;

        claimableFeeDiscountInETH[_referee] += discountInEth;

        emit PlatformFeeApplied(
            _referee, _grossAmount, feeAmountInEth, discountInEth
        );
    }

    // @inheritdoc ISymmFactory
    function claimFeeDiscount() external override {
        uint256 claimableAmount = claimableFeeDiscountInETH[msg.sender];
        if (claimableAmount == 0) {
            revert Errors.SymmFactoryNoClaimableDiscount();
        }
        uint256 balance = address(this).balance;
        uint256 claimAmount =
            claimableAmount > balance ? balance : claimableAmount;
        claimableFeeDiscountInETH[msg.sender] -= claimAmount;
        SafeTransferLib.safeTransferETH(msg.sender, claimAmount);
        emit ClaimedFeeDiscountInETH(msg.sender, claimAmount);
    }

    /// @inheritdoc ISymmFactory
    function setBackendWallet(address _backendWallet)
        external
        override
        onlyAdmin
    {
        emit BackendWalletChanged(backendWallet, _backendWallet);

        backendWallet = _backendWallet;
    }

    /// @inheritdoc ISymmFactory
    function setSymmPlatformFeeBPS(uint256 _symmPlatformFeeBPS)
        external
        onlyAdmin
    {
        symmPlatformFeeBPS = _symmPlatformFeeBPS;
        emit SymmPlatformFeeBPSChanged(_symmPlatformFeeBPS);
    }

    /// @inheritdoc ISymmFactory
    function setSwapData(
        address _uniswapRouter,
        address _usdcToken,
        uint24 _poolFee
    )
        external
        onlyAdmin
    {
        if (_uniswapRouter != address(0)) {
            uniswapV3Router = ISwapRouter(_uniswapRouter);
        }
        if (_usdcToken != address(0)) {
            USDC = _usdcToken;
        }
        if (_poolFee != 0) {
            pool_fee = _poolFee;
        }
    }

    /// @inheritdoc ISymmFactory
    function setDistributionCaps(
        uint256 _stakersTreasuryCap,
        uint256 _feeDiscountCap,
        uint256 _referralCap
    )
        external
        onlyAdmin
    {
        STAKERS_TREASURY_CAP = _stakersTreasuryCap;
        FEE_DISCOUNT_CAP = _feeDiscountCap;
        REFERRAL_CAP = _referralCap;
    }

    /// @inheritdoc ISymmFactory
    function withdrawEth(
        uint256 _amount,
        address _withdrawAddress
    )
        external
        override
        onlyAdmin
    {
        (bool _success,) = _withdrawAddress.call{ value: _amount }("");
        if (!_success) {
            revert Errors.SymmFactoryFailedToSendFundsToUser();
        }

        emit EthWithdrawnFromSymmFactory(_amount, _withdrawAddress);
    }

    /// @inheritdoc ISymmFactory
    function withdrawToken(
        address token,
        address to,
        uint256 amount
    )
        external
        override
        onlyAdmin
        returns (bool)
    {
        SafeTransferLib.safeTransfer(token, to, amount);

        emit TokenWithdrawal(token, to, amount);
        return true;
    }
}
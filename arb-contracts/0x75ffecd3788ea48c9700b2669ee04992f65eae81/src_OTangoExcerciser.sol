// SPDX-License-Identifier: BSUL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {IERC3156FlashBorrower} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC3156FlashLender.sol";
import {IERC20Permit} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_IERC20Permit.sol";
import {Address} from "./lib_openzeppelin-contracts_contracts_utils_Address.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {Ownable} from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import {IOTango} from "./src_dependencies_IOTango.sol";

/// @title OTango Exerciser
/// @notice Facilitates the exercise of OTango options with flash loan support and fee collection (UI available at https://otango.surge.sh/)
/// @dev Uses flash loans to provide atomic exercise operations with configurable fees
contract OTangoExcerciser is IERC3156FlashBorrower, Ownable {
    using Address for address;
    using SafeERC20 for *;

    // ============ Events ============

    /// @notice Emitted when an exercise operation is completed
    /// @param user Address that initiated the exercise
    /// @param otangoAmount Amount of OTango exercised
    /// @param acquiredTango Amount of TANGO tokens received
    /// @param acquiredUSDC Amount of USDC tokens received
    event Exercised(address indexed user, uint256 otangoAmount, uint256 acquiredTango, uint256 acquiredUSDC);

    // ============ Constants ============

    /// @notice Maximum fee rate allowed (10% = 1000 basis points)
    uint256 public constant MAX_FEE_RATE = 1000;

    /// @notice Core protocol token addresses
    IOTango public constant OTANGO = IOTango(0x007606064f8A40745336F91a1E4345900143756b);
    IERC20 public constant TANGO = IERC20(0xC760F9782F8ceA5B06D862574464729537159966);
    IERC20 public constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);

    // ============ Structs ============

    /// @notice ERC20 permit signature parameters
    struct PermitParams {
        uint256 amount; // Token amount to permit
        uint256 deadline; // Timestamp until which the signature is valid
        uint8 v; // Signature recovery byte
        bytes32 r; // Signature R component
        bytes32 s; // Signature S component
    }

    /// @notice DEX swap execution parameters
    struct SwapInstructions {
        address router; // DEX router contract address
        address spender; // Address to approve for token spending
        bytes swapData; // Encoded swap function call data
        uint256 swapAmount; // Amount of tokens to swap
    }

    /// @notice Exercise operation quote details
    struct ExerciseQuote {
        uint256 requiredUSDC; // Total USDC needed (including fee)
        uint256 exerciseCost; // Base USDC cost for exercise
        uint256 fee; // Fee amount in USDC
        int256 tangoPrice; // TANGO price used for calculation
    }

    // ============ Errors ============

    error UntrustedLender();
    error UntrustedLoanInitiator();
    error UntrustedToken();
    error NotEnoughUSDC(uint256 required, uint256 available);
    error InvalidFeeRate();

    // ============ State Variables ============

    /// @notice Address that receives collected fees
    address public feeRecipient;

    /// @notice Current fee rate in basis points (100 = 1%)
    uint256 public feeRate = 100;

    // ============ Constructor ============

    /// @notice Initializes the contract with a fee recipient
    constructor() Ownable(msg.sender) {
        feeRecipient = msg.sender;
    }

    // ============ External Functions ============

    /// @notice Exercises OTango options using a flash loan
    /// @param permit Permit signature for OTango transfer
    /// @param swap DEX swap instructions for acquiring USDC
    function excercise(PermitParams calldata permit, SwapInstructions calldata swap) external {
        // Handle OTango permit
        _handleOTangoPermit(permit);

        // Execute exercise
        excerciseWithTransfer(permit.amount, swap);
    }

    /// @notice Exercises OTango options using a flash loan (without permit)
    /// @param amount Amount of OTango to exercise
    /// @param swap DEX swap instructions for acquiring USDC
    function excerciseWithTransfer(uint256 amount, SwapInstructions calldata swap) public {
        // Transfer OTango from user
        OTANGO.safeTransferFrom(msg.sender, address(this), amount);

        // Execute flash loan for exercise
        _executeFlashLoan(amount, swap);

        // Transfer resulting tokens to user
        _transferResultingTokens(amount);
    }

    /// @notice Flash loan callback handler
    /// @dev Executes the swap and exercise operations
    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32)
    {
        // Validate flash loan parameters
        _validateFlashLoan(initiator, token);

        // Execute swap and exercise
        SwapInstructions memory swap = abi.decode(data, (SwapInstructions));
        _executeSwapAndExercise(swap, amount);

        // Approve flash loan repayment
        TANGO.approve(msg.sender, amount + fee);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // ============ Admin Functions ============

    /// @notice Updates the fee recipient address
    /// @param _feeRecipient New fee recipient address
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }

    /// @notice Updates the fee rate
    /// @param _feeRate New fee rate in basis points (100 = 1%)
    function setFeeRate(uint256 _feeRate) external onlyOwner {
        if (_feeRate > MAX_FEE_RATE) revert InvalidFeeRate();
        feeRate = _feeRate;
    }

    // ============ View Functions ============

    /// @notice Calculates exercise costs and fees
    /// @param otangoAmount Amount of OTango to exercise
    /// @return Quote containing exercise costs and fees
    function quote(uint256 otangoAmount) public view returns (ExerciseQuote memory) {
        (int256 tangoPrice,,, uint256 cost) = OTANGO.previewExercise(int256(otangoAmount));

        uint256 value = otangoAmount * uint256(tangoPrice) / 1e30;
        uint256 fee = value * feeRate / 10000;
        uint256 requiredUSDC = cost + fee;

        return ExerciseQuote({requiredUSDC: requiredUSDC, exerciseCost: cost, fee: fee, tangoPrice: tangoPrice});
    }

    // ============ Internal Functions ============

    /// @dev Handles the OTango permit
    function _handleOTangoPermit(PermitParams memory permit) internal {
        IERC20Permit(address(OTANGO)).permit(
            msg.sender, address(this), permit.amount, permit.deadline, permit.v, permit.r, permit.s
        );
    }

    /// @dev Executes the flash loan
    function _executeFlashLoan(uint256 amount, SwapInstructions memory swap) internal {
        IERC3156FlashLender(address(TANGO)).flashLoan(this, address(TANGO), amount, abi.encode(swap));
    }

    /// @dev Transfers resulting tokens to the user
    function _transferResultingTokens(uint256 otangoAmount) internal {
        uint256 tangoBalance = TANGO.balanceOf(address(this));
        uint256 usdcBalance = USDC.balanceOf(address(this));

        TANGO.safeTransfer(msg.sender, tangoBalance);
        USDC.safeTransfer(msg.sender, usdcBalance);

        emit Exercised(msg.sender, otangoAmount, tangoBalance, usdcBalance);
    }

    /// @dev Validates flash loan parameters
    function _validateFlashLoan(address initiator, address token) internal view {
        if (initiator != address(this)) revert UntrustedLoanInitiator();
        if (msg.sender != address(TANGO)) revert UntrustedLender();
        if (token != address(TANGO)) revert UntrustedToken();
    }

    /// @dev Executes swap and exercise operations
    function _executeSwapAndExercise(SwapInstructions memory swap, uint256 amount) internal {
        // Execute swap
        TANGO.forceApprove(swap.spender, swap.swapAmount);
        swap.router.functionCall(swap.swapData);

        // Get exercise quote and verify USDC balance
        ExerciseQuote memory _quote = quote(amount);
        uint256 balance = USDC.balanceOf(address(this));
        if (balance < _quote.requiredUSDC) revert NotEnoughUSDC(_quote.requiredUSDC, balance);

        // Take fee and execute exercise
        USDC.safeTransfer(feeRecipient, _quote.fee);
        USDC.forceApprove(address(OTANGO), _quote.exerciseCost);
        OTANGO.exercise(int256(amount), _quote.tangoPrice);
    }
}
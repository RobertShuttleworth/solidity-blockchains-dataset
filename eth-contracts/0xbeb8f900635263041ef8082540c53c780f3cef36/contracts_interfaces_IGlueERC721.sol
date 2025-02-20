// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC3156FlashBorrower} from "./openzeppelin_contracts_interfaces_IERC3156FlashBorrower.sol";

/**
* @title IGlueStickERC721
* @notice Interface for the GlueStickERC721 contract.
*/
interface IGlueStickERC721 {
    // State Variables
    function glueStickAddress() external view returns (address);
    function getGlueAddress(address _tokenAddressToGlue) external view returns (address);
    function allGlues(uint256 index) external view returns (address);
    function TheGlue() external view returns (address);
    function allGluesLength() external view returns (uint256);

    // Main Functions
    function glueAToken(address _tokenAddressToGlue) external;
    function gluedLoan(address[] calldata glues, address token, uint256 totalAmount, address receiver, bytes calldata params) external;

    // View Functions
    function computeGlueAddress(address _tokenAddressToGlue) external view returns (address);
    function isStickyToken(address _tokenAddress) external view returns (bool, address);
    function checkToken(address _tokenAddressToGlue) external view returns (bool);
    function getGlueBalance(address glue, address token) external view returns (uint256);
    function getGluesBalance(address[] calldata glues,address token) external view returns (uint256[] memory);
    
    // Errors
    error ReentrantCall();
    error InvalidToken(address token);
    error DuplicateGlue(address token);
    error InvalidAddress();
    error InvalidInputs();
    error InvalidGlueBalance(address glue, uint256 balance, address token);
    error InsufficientLiquidity(uint256 totalCollected, uint256 totalAmount);
    error FlashLoanFailed();
    error RepaymentFailed(address glue);
    error FailedToDeployGlue();

    // Events
    event GlueAdded(address indexed stickyTokenAddress, address glueAddress, uint256 glueIndex);
}
/**
* @title IGlueERC721
* @notice Interface for the GlueERC721 contract.
*/
interface IGlueERC721 {
    // State Variables
    function glueStickAddress() external view returns (address);
    function gluedSettingsAddress() external view returns (address);
    function stickyTokenAddress() external view returns (address);
    function notBurnable() external view returns (bool);
    function stickyTokenStored() external view returns (bool);

    // Main Functions
    function initialize(address _tokenAddressToGlue) external;
    function unglue(address[] calldata addressesToUnglue, uint256[] calldata tokenIds, address recipient) external returns (uint256, uint256, uint256, uint256);
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external returns (bool);
    function minimalLoan(address receiver, address token, uint256 amount) external returns (bool);

    // View Functions
    function getStatus() external view returns (uint256, uint256, uint256, uint256, bool, uint256, address);
    function getSupplyDelta(uint256 stickyTokenAmount) external view returns (uint256);
    function getAdjustedTotalSupply() external view returns (uint256);
    function getProtocolFee() external pure returns (uint256);
    function getFlashLoanFee() external pure returns (uint256);
    function getProtocolFeeCalculated(uint256 amount) external pure returns (uint256);
    function getFlashLoanFeeCalculated(uint256 amount) external pure returns (uint256);
    function maxFlashLoan(address token) external view returns (uint256);
    function flashFee(address token, uint256 amount) external view returns (uint256);
    function getStickyTokenStored() external view returns (uint256);
    function collateralByAmount(uint256 stickyTokenAmount, address[] calldata addressesToUnglue) external view returns (address[] memory, uint256[] memory);
    function collateralByDelta(address[] calldata addressesToUnglue, uint256 supplyDelta) external view returns (address[] memory, uint256[] memory);
    function getCollateralsBalance(address[] calldata collateralAddresses) external view returns (address[] memory, uint256[] memory);

    // Errors (ordered as they appear in contract)
    error ReentrantCall();
    error NoAssetsSelected();
    error InvalidGlueStickAddress();
    error InvalidToken(address token);
    error WithdrawFailed(address token);
    error NoCollateralSelected();
    error NoTokensTransferred();
    error SenderDoesNotOwnTokens();
    error FailedToProcessCollection();
    error CannotWithdrawStickyToken();
    error InvalidFee();
    error InvalidWithdraw();
    error InvalidFlashLoanAmount();
    error InsufficientBalance(uint256 balance, uint256 amount);
    error InvalidAmount(address token, uint256 amount);
    error InvalidReceiver();
    error FlashLoanFailed();
    error FlashLoanRepaymentFailed(uint256 expectedRepayment);
    error Unauthorized();
    error DuplicateGluedAddress(address token);
    error InvalidBorrowAmount();

    // Events
    event unglued(address indexed recipient, uint256 stickyTokenAmount, uint256 beforeTotalSupply, uint256 afterTotalSupply);
    event GlueLoan(address indexed token, uint256 amount, address receiver);
}
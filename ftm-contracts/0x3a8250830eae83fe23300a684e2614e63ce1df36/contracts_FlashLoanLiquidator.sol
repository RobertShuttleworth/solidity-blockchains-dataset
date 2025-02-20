// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_interfaces_IFlashBorrower.sol";
import "./contracts_interfaces_ICauldron.sol";
import "./contracts_interfaces_IBentoBox.sol";
import "./contracts_interfaces_IBentoBoxV1.sol";
import "./contracts_interfaces_ILendingPool.sol";

/**
 * @title FlashLoanLiquidator
 * @notice Implements flash loan liquidation strategy on Fantom network
 */
contract FlashLoanLiquidator is IFlashBorrower, ReentrancyGuard, Ownable {
    // Custom errors
    error UnauthorizedCaller();
    error SlippageExceeded();
    error EmergencyStop();
    error InvalidAmount();
    error OperationFailed();

    // Constants
    address public immutable MIM;
    address public immutable WFTM;
    address public immutable FLASHLOAN_PROTOCOL;
    address public immutable LENDING_POOL;
    address public immutable BENTO_BOX;
    address public immutable CAULDRON_FTM;

    // State variables
    bool public emergencyStop;
    mapping(address => uint256) public shareBalances;
    uint256 public constant SLIPPAGE_TOLERANCE = 50;

    // Events
    event FlashLoanExecuted(address asset, uint256 amount);
    event CollateralDeposited(address token, uint256 amount, uint256 share);
    event WFTMBorrowed(uint256 amount, uint256 share);
    event LiquidationExecuted();
    event CollateralClaimed(uint256 amount);
    event FlashLoanRepaid(uint256 amount, uint256 fee);
    event ProtocolInitialized( address mim, address wftm, address flashloanProtocol, address lendingPool, address bentoBox, address cauldronFtm);

    // Interfaces
    IBentoBox private immutable bentoBox;
    ICauldron private immutable cauldron;
    ILendingPool private immutable lendingPool;
    IERC20 private immutable mimToken;
    IERC20 private immutable wftmToken;

    constructor(
        address _mim,
        address _wftm,
        address _flashloanProtocol,
        address _lendingPool,
        address _bentoBox,
        address _cauldronFtm
    ) Ownable(msg.sender) {
        require(_mim != address(0), "Invalid MIM address");
        require(_wftm != address(0), "Invalid WFTM address");
        require(_flashloanProtocol != address(0), "Invalid flashloan protocol address");
        require(_lendingPool != address(0), "Invalid lending pool address");
        require(_bentoBox != address(0), "Invalid BentoBox address");
        require(_cauldronFtm != address(0), "Invalid Cauldron address");

        MIM = _mim;
        WFTM = _wftm;
        FLASHLOAN_PROTOCOL = _flashloanProtocol;
        LENDING_POOL = _lendingPool;
        BENTO_BOX = _bentoBox;
        CAULDRON_FTM = _cauldronFtm;

        bentoBox = IBentoBox(_bentoBox);
        cauldron = ICauldron(_cauldronFtm);
        lendingPool = ILendingPool(_lendingPool);
        mimToken = IERC20(_mim);
        wftmToken = IERC20(_wftm);

        bentoBox.registerProtocol();

        require(mimToken.approve(_bentoBox, type(uint256).max), "MIM BentoBox approval failed");
        require(mimToken.approve(_lendingPool, type(uint256).max), "MIM LendingPool approval failed");
        require(wftmToken.approve(_bentoBox, type(uint256).max), "WFTM BentoBox approval failed");
        require(wftmToken.approve(_cauldronFtm, type(uint256).max), "WFTM Cauldron approval failed");

        emit ProtocolInitialized(
            _mim,
            _wftm,
            _flashloanProtocol,
            _lendingPool,
            _bentoBox,
            _cauldronFtm
        );
    }

    /**
     * @notice Sets approval for BentoBox master contract
     * @param approved Whether to approve or revoke
     * @param v v component of signature
     * @param r r component of signature
     * @param s s component of signature
     */
    function setBentoBoxApproval(
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IBentoBoxV1(BENTO_BOX).setMasterContractApproval(
            msg.sender,        
            address(this),
            approved,
            v,
            r,
            s
        );
    }

    function checkAllApprovals() external view returns (
        uint256 mimAllowanceToBox,
        uint256 mimAllowanceToLendingPool,
        uint256 wftmAllowanceToBox
    ) {
        mimAllowanceToBox = IERC20(MIM).allowance(address(this), BENTO_BOX);
        mimAllowanceToLendingPool = IERC20(MIM).allowance(address(this), LENDING_POOL);
        wftmAllowanceToBox = IERC20(WFTM).allowance(address(this), BENTO_BOX);
    }
    /**
     * @notice Sets approval for BentoBox to transfer MIM tokens from contract
     */
    function approveBentoBox() external onlyOwner {
        IERC20(MIM).approve(BENTO_BOX, type(uint256).max);
        
        IERC20(WFTM).approve(BENTO_BOX, type(uint256).max);
    }

    /**
     * @notice Checks for token approvals
     */
    function checkApprovals() external view returns (uint256 mimAllowance, uint256 wftmAllowance) {
        mimAllowance = IERC20(MIM).allowance(address(this), BENTO_BOX);
        wftmAllowance = IERC20(WFTM).allowance(address(this), BENTO_BOX);
    }

    /**
     * @notice Initiates the flash loan liquidation strategy
     * @param flashLoanAmount Amount of MIM to borrow in flash loan
     * @param minExpectedReturn Minimum expected return in WFTM
     */
    function executeLiquidationStrategy(
        uint256 flashLoanAmount,
        uint256 minExpectedReturn
    ) external {
        if (emergencyStop) revert EmergencyStop();
        if (flashLoanAmount == 0) revert InvalidAmount();

        // Encode parameters for flash loan callback
        bytes memory params = abi.encode(minExpectedReturn);

        // Execute flash loan
        lendingPool.flashLoan(
            this,
            address(this),
            IERC20(MIM),
            flashLoanAmount,
            params
        );
    }

    /**
     * @notice Flash loan callback handler implementing liquidation strategy
     * @dev Called by lending pool after flash loan is provided
     */
    function onFlashLoan(
        address sender,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external override nonReentrant {
        // Verify caller and token
        if (msg.sender != LENDING_POOL || sender != address(this)) {
            revert UnauthorizedCaller();
        }
        if (address(token) != MIM) revert InvalidAmount();

        // Decode parameters
        uint256 minExpectedReturn = abi.decode(data, (uint256));

        // Step 1: Deposit MIM into BentoBox
        (uint256 depositAmount, uint256 shareOut) = _depositToBentoBox(amount);
        emit CollateralDeposited(MIM, depositAmount, shareOut);

        // Step 2: Add MIM as collateral in Cauldron
        _addCollateralToCauldron(shareOut);

        // Step 3: Borrow WFTM from Cauldron
        (uint256 borrowAmount, uint256 borrowShare) = _borrowWFTM(amount);
        emit WFTMBorrowed(borrowAmount, borrowShare);

        // Step 4: Execute liquidation
        _executeLiquidation();
        emit LiquidationExecuted();

        // Step 5: Remove and claim collateral
        uint256 claimedAmount = _claimCollateral();
        emit CollateralClaimed(claimedAmount);

        // Step 6: Withdraw MIM from BentoBox
        _withdrawFromBentoBox();

        // Verify minimum return
        if (claimedAmount < minExpectedReturn) revert SlippageExceeded();

        // Repay flash loan
        uint256 repayAmount = amount + fee;
        require(
            mimToken.transfer(LENDING_POOL, repayAmount),
            "Flash loan repayment failed"
        );
        emit FlashLoanRepaid(amount, fee);
    }

    /**
     * @notice Deposits MIM into BentoBox
     * @param amount Amount of MIM to deposit
     * @return amountOut Amount deposited
     * @return shareOut Shares received
     */
    function _depositToBentoBox(uint256 amount) private returns (uint256 amountOut, uint256 shareOut) {
        (amountOut, shareOut) = bentoBox.deposit(
            IERC20(MIM),
            address(this),
            address(this),
            amount,
            0
        );
        shareBalances[MIM] += shareOut;
        return (amountOut, shareOut);
    }

    /**
     * @notice Adds MIM collateral to Cauldron
     * @param shareAmount Amount of shares to add as collateral
     */
    function _addCollateralToCauldron(uint256 shareAmount) private {
        cauldron.addCollateral(address(this), false, shareAmount);
    }

    /**
     * @notice Borrows WFTM from Cauldron
     * @param collateralAmount Amount of collateral provided
     * @return part Borrowed part
     * @return share Borrowed share
     */
    function _borrowWFTM(uint256 collateralAmount) private returns (uint256 part, uint256 share) {
        // Calculate safe borrow amount (e.g., 75% of collateral value)
        uint256 borrowAmount = (collateralAmount * 75) / 100;
        return cauldron.borrow(address(this), borrowAmount);
    }

    /**
     * @notice Executes the liquidation strategy
     */
    function _executeLiquidation() private {
        cauldron.liquidate();
    }

    /**
     * @notice Claims collateral after liquidation
     * @return amount Amount of collateral claimed
     */
    function _claimCollateral() private returns (uint256 amount) {
        uint256 share = shareBalances[WFTM];
        cauldron.removeCollateral(address(this), share);
        shareBalances[WFTM] = 0;
        return wftmToken.balanceOf(address(this));
    }

    /**
     * @notice Withdraws MIM from BentoBox
     * @return amount Amount withdrawn
     */
    function _withdrawFromBentoBox() private returns (uint256 amount) {
        uint256 share = shareBalances[MIM];
        (amount, ) = bentoBox.withdraw(
            IERC20(MIM),
            address(this),
            address(this),
            0,
            share
        );
        shareBalances[MIM] = 0;
        return amount;
    }

    /**
     * @notice Emergency withdrawal of tokens
     * @param token Address of token to withdraw
     */
    function emergencyWithdraw(address token) external onlyOwner {
        uint256 balance;
        uint256 shareBalance = shareBalances[token];

        // If tokens are in BentoBox, withdraw them first
        if (shareBalance > 0) {
            (uint256 amount, ) = bentoBox.withdraw(
                IERC20(token),
                address(this),
                address(this),
                0,
                shareBalance
            );
            shareBalances[token] = 0;
            balance = amount;
        }

        // Transfer any remaining tokens in the contract
        balance += IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            require(
                IERC20(token).transfer(owner(), balance),
                "Emergency withdrawal failed"
            );
        }
    }

    /**
     * @notice Toggles emergency stop
     */
    function toggleEmergencyStop() external onlyOwner {
        emergencyStop = !emergencyStop;
    }

    /**
     * @notice Updates protocol approvals
     * @param token Token address
     * @param spender Spender address
     * @param amount Approval amount
     */
    function updateApproval(
        address token,
        address spender,
        uint256 amount
    ) external onlyOwner {
        require(
            IERC20(token).approve(spender, amount),
            "Approval update failed"
        );
    }

    /**
     * @dev Prevents accidental ETH transfers to contract
     */
    receive() external payable {
        revert("Direct ETH transfers not accepted");
    }

    /**
     * @notice Helper function to check share balances
     * @param token Token address
     * @return Share balance
     */
    function getShareBalance(address token) external view returns (uint256) {
        return shareBalances[token];
    }

    /**
     * @notice Helper function to check if emergency stop is active
     * @return Emergency stop status
     */
    function isEmergencyStop() external view returns (bool) {
        return emergencyStop;
    }

    /**
     * @notice Helper function to validate contract setup
     * @return isValid Whether contract is properly set up
     */
    function validateSetup() external view returns (bool) {
        return (
            address(bentoBox) == BENTO_BOX &&
            address(cauldron) == CAULDRON_FTM &&
            address(lendingPool) == LENDING_POOL &&
            mimToken.allowance(address(this), BENTO_BOX) > 0 &&
            mimToken.allowance(address(this), LENDING_POOL) > 0 &&
            wftmToken.allowance(address(this), BENTO_BOX) > 0
        );
    }
}
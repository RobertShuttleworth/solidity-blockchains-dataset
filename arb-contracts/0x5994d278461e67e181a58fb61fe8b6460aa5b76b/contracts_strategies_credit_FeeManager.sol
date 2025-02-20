// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import {ILendingVault} from "./contracts_interfaces_ILendingVault.sol";
import {LendingVault} from "./contracts_LendingVault.sol";
import {IFeeManager} from "./contracts_interfaces_IFeeManager.sol";
import {VaultAdmin} from "./contracts_strategies_credit_VaultAdmin.sol";

import {ReentrancyGuard} from "./lib_openzeppelin-contracts_contracts_utils_ReentrancyGuard.sol";
import {Math} from "./lib_openzeppelin-contracts_contracts_utils_math_Math.sol";
import {ERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import {Pausable} from "./lib_openzeppelin-contracts_contracts_utils_Pausable.sol";

/**
 * @title  - FeeManager
 * @author - Credit Cooperative
 * @notice - Provides functions to set and calculate fees for the Vault.
 * @dev    - All external and public state changing functions are only callable by the vault manager, vault operator, or associated LendingVault.
 */
abstract contract FeeManager is VaultAdmin, ReentrancyGuard, IFeeManager {
    using Math for uint256;

    Fees public fees;
    uint256 public lastManagementFeeTimestamp;
    uint256 public highWaterMarkSharePrice;

    uint8 public protocolSplit;
    uint8 public constant MAX_SPLIT = 100;

    address public immutable lendingVault;

    /*///////////////////////////////////////////////////////////////
                        ACCESS CONTROL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice - Checks `msg.sender` is `lendingVault`.
     */
    function _onlyLendingVault() internal view {
        if (msg.sender != lendingVault) {
            revert OnlyLendingVault();
        }
    }

    /**
     * @notice - Checks `msg.sender` is `lendingVault` or `isOperator`.
     */
    function _onlyLendingVaultOrOperator() internal view {
        if (msg.sender != lendingVault && !isOperator[msg.sender]) {
            revert OnlyLendingVaultOrOperator();
        }
    }


    /**
     * @notice  - Asserts that the protocol split is less than the maximum allowed.
     * @param split - The split to assert.
     */
    function _assertMaxProtocolSplit(uint8 split) internal pure {
        if (split > MAX_SPLIT) {
            revert ProtocolSplitExceedsMaximumAllowed();
        }
    }

    /**
     * @notice  - Asserts that the fee is less than the maximum allowed.
     * @param fee   - The fee to assert.
     */
    function _assertMaxFee(uint16 fee, FeeTypes fee_type) internal {
        if (uint256(fee) >= FEE_COEFFICIENT) {
            revert FeeExceedsMaximumAllowed();
        }
        emit SetFee(fee, uint256(fee_type));
    }


    /*///////////////////////////////////////////////////////////////
                        FEE SETTINGS & MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  - Sets the performance fee of the vault.
     * @dev     - Only callable by `manager`.
     * @dev     - The fee cannot be greater than the maximum allowed.
     * @param fee   - The new performance fee.
     */
    function setPerformanceFee(uint16 fee) external nonReentrant {
        _onlyVaultManager();
        _assertMaxFee(fee, FeeTypes.PERFORMANCE);
        _accrueFees(); // accrue fees before changing performance fee
        fees.performance = fee;
    }

    /**
     * @notice  - Gets the performance fee of the vault.
     * @return  - The performance fee of the vault.
     */
    function performanceFee() external view returns (uint16) {
        return fees.performance;
    }

    /**
     * @notice  - Sets the management fee of the vault.
     * @dev     - Only callable by `manager`.
     * @dev     - The fee cannot be greater than the maximum allowed.
     * @param fee   - The new management fee.
     */
    function setManagementFee(uint16 fee) external nonReentrant {
        _onlyVaultManager();
        _assertMaxFee(fee, FeeTypes.MANAGEMENT);
        _accrueFees(); // accrue fees before changing management fee
        fees.management = fee;
    }

    /**
     * @notice  - Gets the management fee of the vault.
     * @return  - The management fee of the vault.
     */
    function managementFee() external view returns (uint16) {
        return fees.management;
    }

    /**
     * @notice  - Updates the protocol split of the vault.
     * @dev     - Updating the protocol split must be agreed with mutual consent between the protocol's treasury and the vault manager. The new protocol split cannot be greater than the maximum allowed.
     * @param newProtocolSplit - The new percentage of fees that accrue to the protocol treasury.
     */
    function updateProtocolSplit(uint8 newProtocolSplit) external mutualConsent(protocolTreasury, manager) {
        _assertMaxProtocolSplit(newProtocolSplit);
        _accrueFees(); // accrue fees before changing protocol split
        emit UpdateProtocolSplit(newProtocolSplit);
        protocolSplit = newProtocolSplit;
    }

    /**
        * @notice  - set the last management fee timestamp to the current block timestamp
        * @dev     - Only callable by `lendingVault`.
     */
    function setLastManagementFeeTimestamp() external nonReentrant {
        _onlyLendingVault();
        lastManagementFeeTimestamp = block.timestamp;
    }

    /**
     * Calculates pro rata management fee by multiplying the Vault's management fee percentage by the elapsed amount of time since the last management fee was accrued divided by one year in seconds, since the fee is a yearly fee.
     *
     * @return proratedManagementFee - management fee denominated in percentage of ERC20(lendingVault).totalSupply()
     */
    function _calculateProRataManagementFee() internal view returns (uint256 proratedManagementFee) {
        if (Pausable(lendingVault).paused()) {
            return 0;
        }
        uint256 timeSinceLastFee = block.timestamp - lastManagementFeeTimestamp;
        if (timeSinceLastFee > ONE_YEAR_IN_SECONDS) {
            timeSinceLastFee = ONE_YEAR_IN_SECONDS;
        }
        uint256 managementFeeInBaseUnit = baseUnit.mulDiv(fees.management, 10000);
        proratedManagementFee = timeSinceLastFee.mulDiv(managementFeeInBaseUnit, ONE_YEAR_IN_SECONDS);
    }


    /**
     * @notice  - Accrues management fees.
     * @return newVaultShares - Amount of new shares minted.
     */
    function _accrueManagementFee() internal returns (uint256 newVaultShares) {
        uint256 totalSupplyBefore = ERC20(lendingVault).totalSupply();

        uint256 inflationFeePercentage = _calculateProRataManagementFee();
        newVaultShares = _calculateManagementFeeInflation(inflationFeePercentage);

        // Mint new Vault shares to manager and protocol treasury
        uint256 newManagerShares = newVaultShares.mulDiv(100 - protocolSplit, 100);
        uint256 newProtocolShares = newVaultShares - newManagerShares;
        ILendingVault(lendingVault).mintFeeShares(manager, newManagerShares);
        ILendingVault(lendingVault).mintFeeShares(protocolTreasury, newProtocolShares);
        emit MintManagementShares(manager, newManagerShares, protocolTreasury, newProtocolShares);

        // update lastManagementFeeTimestamp
        lastManagementFeeTimestamp = block.timestamp;

        // reset highWaterMarkSharePrice to adjust for new shares minted
        if (totalSupplyBefore > 0) {
            uint256 totalSupplyAfter = ERC20(lendingVault).totalSupply();
            highWaterMarkSharePrice = highWaterMarkSharePrice.mulDiv(totalSupplyBefore, totalSupplyAfter);
            emit SetHighWaterMarkSharePrice(highWaterMarkSharePrice);
        }
    }

    /**
     * @notice  - Returns new management fees denominated in terms of the number of shares to mint for the vault manager. The calculation determines the quantity of new shares to mint such that the Vault manager owns the fee percentage of the entire supply of the Vault.
     *
     * The simplified (floating point) version of the formula utilized by the function is:
     * newManagerShares = _feePercentage * ERC20(lendingVault).totalSupply() / (1 - _feePercentage)
     *
     * @param   _feePercentage      - Pro-rated management fee levied by manager
     * @return  newManagerShares    - New Vault shares issue quantity
     */
    function _calculateManagementFeeInflation(uint256 _feePercentage)
        internal
        view
        returns (uint256 newManagerShares)
    {
        newManagerShares = _feePercentage.mulDiv(ERC20(lendingVault).totalSupply(), baseUnit - _feePercentage);
    }


    /**
     * @notice  - Calculates the performance and management fees and mints the corresponding vault shares to the manager and protocol treasury.
     * @dev     - Only callable by `manager`, `operator`, or `lendingVault`.
     */
    function accrueFees() external {
        _onlyLendingVaultOrOperator();
        _accrueFees();
    }

    /**
     * @notice  - Calculates the performance and management fees and mints the corresponding vault shares to the manager and protocol treasury.
     */
    function _accrueFees() internal {
        if (fees.performance > 0) {
            _accruePerformanceFee();
        }
        if (fees.management > 0) {
            _accrueManagementFee();
        }
    }


    /**
     * @notice  - Calculates the performance fee and mints the corresponding vault shares to the manager.
     */
    function _accruePerformanceFee() internal {
        uint256 newSharePrice = LendingVault(lendingVault).sharePrice();
        uint256 newTotalAssets = LendingVault(lendingVault).totalAssets();

        if (newSharePrice > highWaterMarkSharePrice) {
            uint256 highWaterMarkSharesValue = highWaterMarkSharePrice.mulDiv(ERC20(lendingVault).totalSupply(), baseUnit);
            uint256 newFeeAssets = (newTotalAssets - highWaterMarkSharesValue).mulDiv(fees.performance, FEE_COEFFICIENT);

            // Calculate new shares to mint for manager and protocol treasury
            uint256 newFeeShares = newFeeAssets.mulDiv(ERC20(lendingVault).totalSupply(), newTotalAssets - newFeeAssets);
            uint256 newManagerShares = newFeeShares.mulDiv((100 - protocolSplit), 100);
            uint256 newProtocolShares = newFeeShares - newManagerShares;

            // Mint new Vault shares to manager and protocol treasury
            ILendingVault(lendingVault).mintFeeShares(manager, newManagerShares);
            ILendingVault(lendingVault).mintFeeShares(protocolTreasury, newProtocolShares);

            emit MintPerformanceShares(manager, newManagerShares, protocolTreasury, newProtocolShares);

            // update highWaterMarkSharePrice
            highWaterMarkSharePrice = ILendingVault(lendingVault).sharePrice();
            emit SetHighWaterMarkSharePrice(highWaterMarkSharePrice);
        }
    }
}
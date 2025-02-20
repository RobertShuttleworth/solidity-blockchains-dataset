// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "./openzeppelin_contracts_utils_math_Math.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";

contract InterestRateModel is OwnableUpgradeable {
    mapping(uint256 => uint256[]) public savingsTable;
    mapping(uint256 => mapping(uint256 => uint256[])) public incomeTable;
    mapping(uint256 => uint256[]) public lockedSavingsTable;

    /// @notice Initialize the contract
    /// @dev This function replaces the constructor for upgradeable contracts
    function initialize() public initializer {
        __Ownable_init(msg.sender); // Initialize Ownable
    }

    /// @notice Set the savings table
    /// @dev The savings table is a 2D array that stores the interest rate for the savings
    /// @param _multiplier is the interest rate for the savings
    function setSavingsTable(
        uint256[][] memory _multiplier
    ) external onlyOwner {
        for (uint256 i = 0; i < _multiplier.length; i++) {
            uint256 _period = i + 1;
            savingsTable[_period] = _multiplier[i];
        }
    }

    function setIncomeTable(
        uint256 _paymentFrequency,
        uint256 _marker,
        uint256[] memory _multiplier
    ) external onlyOwner {
        incomeTable[_paymentFrequency][_marker] = _multiplier;
    }

    function setLockedSavingsMultiplierTable(
        uint256[] memory _multiplier,
        uint256[][] memory _monthsLocked
    ) external onlyOwner {
        for (uint256 i = 0; i < _multiplier.length; i++) {
            lockedSavingsTable[_multiplier[i]] = _monthsLocked[i];
        }
    }

    /// @notice Return the interest rate for the savings
    /// @param _period the number of years
    /// @param _marker is the index of the savingsTable
    /// @param _amount the principal amount
    function getSavingsOutcome(
        uint256 _period,
        uint256 _marker,
        uint256 _amount
    ) public view returns (uint256) {
        uint256[] memory _multipliers = savingsTable[_period];
        uint256 interest = Math.mulDiv(_amount, _multipliers[_marker], 1 ether);

        return interest;
    }

    function getSavingsInterestRate(
        uint256 _period,
        uint256 _marker
    ) public view returns (uint256) {
        return savingsTable[_period][_marker];
    }

    function getIncomeOutcome(
        uint256 _paymentFrequency,
        uint256 _marker,
        uint256 _period,
        uint256 _amount
    ) public view returns (uint256) {
        uint256[] memory _multipliers = incomeTable[_paymentFrequency][_marker];
        uint256 interest = Math.mulDiv(_amount, _multipliers[_period], 1 ether);

        return interest;
    }

    function getIncomeInterestRate(
        uint256 _paymentFrequency,
        uint256 _marker,
        uint256 _period
    ) public view returns (uint256) {
        return incomeTable[_paymentFrequency][_marker][_period];
    }

    function getLockedSavingsMonths(
        uint256 _multiplier,
        uint256 _marker
    ) public view returns (uint256) {
        return lockedSavingsTable[_multiplier][_marker];
    }

    function getLockedSavingsOutcome(
        uint256 _multiplier,
        uint256 _amount
    ) public pure returns (uint256) {
        return (_amount * _multiplier);
    }
}
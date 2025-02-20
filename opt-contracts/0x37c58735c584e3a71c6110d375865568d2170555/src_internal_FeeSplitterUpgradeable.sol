// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// external
import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { EnumerableSet, AccessControlEnumerableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_extensions_AccessControlEnumerableUpgradeable.sol";

// interfaces
import { IFeeSplitter } from "./src_interfaces_internal_IFeeSplitter.sol";

// libraries
import { Currency, CurrencyLibrary } from "./src_libraries_Currency.sol";

// constants
import { Roles } from "./src_constants_RoleConstants.sol";
import { ONE_HUNDRED_PERCENT_IN_BP } from "./src_constants_NumericConstants.sol";

// errors
import { LengthMisMatch, InvalidFeeRecipient } from "./src_errors_Errors.sol";

/// @title FeeSplitterUpgradeable
/// @notice A contract for splitting fees among multiple recipients
/// @dev This contract is upgradeable and uses OpenZeppelin's AccessControl
contract FeeSplitterUpgradeable is IFeeSplitter, Initializable, AccessControlEnumerableUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private _serviceFee; // Unused
    EnumerableSet.AddressSet internal _feeRecipients;
    mapping(address recipient => uint256 percentage) internal _percents;

    /// @notice Initializes the contract
    /// @param serviceFee_ The service fee percentage in basis points
    /// @param recipients_ An array of fee recipient addresses
    /// @param percents_ An array of percentages corresponding to each recipient
    function __FeeSplitterUpgradeable_init(
        uint256 serviceFee_,
        address[] calldata recipients_,
        uint256[] calldata percents_
    )
        internal
        onlyInitializing
    {
        __FeeSplitterUpgradeable_init_unchained(serviceFee_, recipients_, percents_);
    }

    /// @notice Internal function to initialize the contract without calling parent initializers
    //@param serviceFee_ The service fee percentage in basis points
    /// @param recipients_ An array of fee recipient addresses
    /// @param percents_ An array of percentages corresponding to each recipient
    function __FeeSplitterUpgradeable_init_unchained(
        uint256, /* serviceFee_ */
        address[] calldata recipients_,
        uint256[] calldata percents_
    )
        internal
        onlyInitializing
    {
        // _configServiceFee(serviceFee_);
        _configFees(recipients_, percents_);
    }

    // /// @notice Configures the service fee
    // /// @param serviceFee_ The new service fee percentage in basis points
    // function configServiceFee(uint256 serviceFee_) external onlyRole(Roles.OPERATOR_ROLE) {
    //     _configServiceFee(serviceFee_);
    // }

    /// @notice Configures the fee recipients and their percentages
    /// @param recipients_ An array of fee recipient addresses
    /// @param percents_ An array of percentages corresponding to each recipient
    function configFees(
        address[] calldata recipients_,
        uint256[] calldata percents_
    )
        external
        onlyRole(Roles.OPERATOR_ROLE)
    {
        _configFees(recipients_, percents_);
    }

    /// @notice Internal function to split and distribute fees
    /// @param token_ The currency token to distribute
    /// @param amount_ The total amount to be distributed
    function _slittingFee(Currency token_, uint256 amount_) internal {
        uint256 length = _feeRecipients.length();
        // uint256 serviceFee = _getServiceFee(amount_);
        uint256 transferAmount;
        address recipient;

        for (uint256 i = 0; i < length;) {
            recipient = _feeRecipients.at(i);
            transferAmount = (amount_ * _percents[recipient]) / ONE_HUNDRED_PERCENT_IN_BP;
            if (token_.isNative()) {
                CurrencyLibrary.transferETH(recipient, transferAmount);
            } else {
                token_.transfer(recipient, transferAmount);
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Internal function to configure fee recipients and their percentages
    /// @param recipients_ An array of fee recipient addresses
    /// @param percents_ An array of percentages corresponding to each recipient
    function _configFees(address[] calldata recipients_, uint256[] calldata percents_) internal {
        if (recipients_.length != percents_.length) revert LengthMisMatch();

        uint256 feeRecipientsLength = _feeRecipients.length();

        // Iterate from the last item to the first to avoid index shifting
        for (uint256 i = feeRecipientsLength; i > 0;) {
            address recipient = _feeRecipients.at(i - 1);
            _feeRecipients.remove(recipient);

            unchecked {
                --i;
            }
        }

        for (uint256 i; i < recipients_.length;) {
            if (recipients_[i] == address(0)) revert InvalidFeeRecipient();

            if (percents_[i] != 0) {
                _feeRecipients.add(recipients_[i]);
                _percents[recipients_[i]] = percents_[i];
            }

            unchecked {
                ++i;
            }
        }

        emit FeeUpdated(recipients_, percents_);
    }

    // /// @notice Internal function to configure the service fee
    // /// @param serviceFee_ The new service fee percentage in basis points
    // function _configServiceFee(uint256 serviceFee_) internal {
    //     _serviceFee = serviceFee_;
    //     emit ServiceFeeUpdated(serviceFee_);
    // }

    // @notice View function to get all fee recipients and their percentages
    /// @return An array of fee recipient addresses and an array of their corresponding percentages
    function viewFees() external view returns (address[] memory, uint256[] memory fees) {
        uint256 length = _feeRecipients.length();
        fees = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            fees[i] = _percents[_feeRecipients.at(i)];
            unchecked {
                ++i;
            }
        }
        return (_feeRecipients.values(), fees);
    }

    // // @notice View function to get the current service fee
    // /// @return The current service fee percentage in basis points
    // function viewServiceFee() external view returns (uint256) {
    //     return _serviceFee;
    // }

    // /// @notice Internal function to calculate the service fee amount
    // /// @param amount_ The total amount to calculate the fee from
    // /// @return The calculated service fee amount
    // function _getServiceFee(uint256 amount_) internal view returns (uint256) {
    //     return (amount_ * _serviceFee) / ONE_HUNDRED_PERCENT_IN_BP;
    // }

    uint256[47] private __gap;
}
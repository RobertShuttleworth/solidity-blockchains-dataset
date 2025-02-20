// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";
import {Math} from "./openzeppelin_contracts_utils_math_Math.sol";
import "./contracts_interfaces_IRedeemOperator.sol";
import "./contracts_interfaces_IVault.sol";
import "./contracts_main_libraries_Errors.sol";
import "./contracts_main_common_Constants.sol";

/**
 * @title RedeemOperator contract
 * @author Naturelab
 * @notice Manages temporary storage of share tokens and facilitates redemption operations.
 * @dev Implements the IRedeemOperator interface and uses OpenZeppelin libraries for safety and utility functions.
 */
contract RedeemOperator is IRedeemOperator, Constants, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Used for precise calculations
    uint256 public immutable PRECISION;

    // Address of the vault contract (immutable)
    address public immutable vault;

    // Address of the core token contract (immutable)
    address public immutable asset;

    // Address of the operator managing withdrawals
    address public operator;

    // Address to receive fees
    address public feeReceiver;

    // Mapping to track withdrawal requests
    mapping(address => uint256) private _withdrawalRequest;

    // Set to keep track of pending withdrawers
    EnumerableSet.AddressSet private _pendingWithdrawers;

    modifier onlyVault() {
        if (msg.sender != vault) revert Errors.CallerNotVault();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != operator) revert Errors.CallerNotOperator();
        _;
    }

    /**
     * @dev Initializes the contract with the vault, operator, fee receiver, and gas parameters.
     * @param _admin Address of the admin.
     * @param _vault Address of the vault contract.
     * @param _asset Address of the core token contract.
     * @param _operator Address of the operator.
     * @param _feeReceiver Address to receive fees.
     */
    constructor(address _admin, address _vault, address _asset, address _operator, address _feeReceiver)
        Ownable(_admin)
    {
        if (_vault == address(0)) revert Errors.InvalidVault();
        if (_asset == address(0)) revert Errors.InvalidAsset();
        if (_operator == address(0)) revert Errors.InvalidNewOperator();
        if (_feeReceiver == address(0)) revert Errors.InvalidFeeReceiver();
        vault = _vault;
        operator = _operator;
        feeReceiver = _feeReceiver;
        asset = _asset;
        PRECISION = IVault(_vault).getPrecison();
    }

    /**
     * @dev Updates the operator address.
     * @param _newOperator New operator address.
     */
    function updateOperator(address _newOperator) external onlyOwner {
        if (_newOperator == address(0)) revert Errors.InvalidNewOperator();
        emit UpdateOperator(operator, _newOperator);
        operator = _newOperator;
    }

    /**
     * @dev Update the address of the recipient for management fees.
     * @param _newFeeReceiver The new address of the recipient for management fees.
     */
    function updateFeeReceiver(address _newFeeReceiver) external onlyOwner {
        if (_newFeeReceiver == address(0)) revert Errors.InvalidFeeReceiver();
        emit UpdateFeeReceiver(feeReceiver, _newFeeReceiver);
        feeReceiver = _newFeeReceiver;
    }

    /**
     * @dev Registers a withdrawal request for a user.
     * @param _user Address of the user requesting withdrawal.
     * @param _shares Amount of shares to withdraw.
     */
    function registerWithdrawal(address _user, uint256 _shares) external onlyVault {
        if (_shares == 0) revert Errors.InvalidShares();

        // Handle existing pending withdrawal
        if (_pendingWithdrawers.contains(_user)) {
            revert Errors.IncorrectState();
        } else {
            // Register new withdrawal request
            _pendingWithdrawers.add(_user);
            _withdrawalRequest[_user] = _shares;
        }

        emit RegisterWithdrawal(_user, _shares);
    }

    /**
     * @dev Returns the withdrawal request details for a user.
     * @param _user Address of the user.
     * @return WithdrawalRequest struct containing the token address and shares amount.
     */
    function withdrawalRequest(address _user) external view returns (uint256) {
        return (_withdrawalRequest[_user]);
    }

    /**
     * @dev Returns the withdrawal request details for multiple users.
     * @param _users Array of user addresses.
     * @return shares_ Array of shares requested for withdrawal.
     */
    function withdrawalRequests(address[] calldata _users) external view returns (uint256[] memory shares_) {
        uint256 count_ = _users.length;
        if (count_ == 0) revert Errors.InvalidLength();

        shares_ = new uint256[](count_);
        for (uint256 i = 0; i < count_; ++i) {
            shares_[i] = _withdrawalRequest[_users[i]];
        }
    }

    /**
     * @dev Returns the number of pending withdrawers.
     * @return Number of pending withdrawers.
     */
    function pendingWithdrawersCount() external view returns (uint256) {
        return _pendingWithdrawers.length();
    }

    /**
     * @dev Returns a paginated list of pending withdrawers.
     * @param _limit Maximum number of addresses to return.
     * @param _offset Offset for pagination.
     * @return result_ Array of addresses of pending withdrawers.
     */
    function pendingWithdrawers(uint256 _limit, uint256 _offset) external view returns (address[] memory result_) {
        uint256 count_ = _pendingWithdrawers.length();
        if (_offset >= count_ || _limit == 0) return result_;

        count_ -= _offset;
        if (count_ > _limit) count_ = _limit;

        result_ = new address[](count_);
        for (uint256 i = 0; i < count_; ++i) {
            result_[i] = _pendingWithdrawers.at(_offset + i);
        }
        return result_;
    }

    /**
     * @dev Returns the list of all pending withdrawers.
     * @return Array of addresses of all pending withdrawers.
     */
    function allPendingWithdrawers() external view returns (address[] memory) {
        return _pendingWithdrawers.values();
    }

    function confirmWithdrawal(address[] memory _users, uint256 _totalGasTokenAmount) external onlyOperator {
        uint256 totalShares_;
        for (uint256 i = 0; i < _users.length; ++i) {
            if (!_pendingWithdrawers.contains(_users[i])) revert Errors.InvalidWithdrawalUser();
            totalShares_ += _withdrawalRequest[_users[i]];
        }
        uint256 exchangePrice_ = IVault(vault).exchangePrice();
        uint256 lastExchangePrice = IVault(vault).lastExchangePrice();
        if (lastExchangePrice == 0) revert Errors.UnSupportedOperation();

        uint256 cutPercentage_;
        if (exchangePrice_ < lastExchangePrice) {
            cutPercentage_ = (lastExchangePrice - exchangePrice_).mulDiv(
                (IERC20(vault).totalSupply() - totalShares_) * PRECISION,
                totalShares_ * exchangePrice_,
                Math.Rounding.Ceil
            );
        }

        uint256 tokenBalanceBefore_ = IERC20(asset).balanceOf(address(this));
        IVault(vault).optionalRedeem(asset, totalShares_, cutPercentage_, address(this), address(this));
        uint256 tokenBalanceGet_ = IERC20(asset).balanceOf(address(this)) - tokenBalanceBefore_;
        uint256 assetPerShare_ = tokenBalanceGet_.mulDiv(PRECISION, totalShares_, Math.Rounding.Floor);

        address thisUser_;
        uint256 thisUserGet_;
        uint256 gasPerUser_ = _totalGasTokenAmount / _users.length;
        uint256[] memory amounts_ = new uint256[](_users.length);
        for (uint256 i = 0; i < _users.length; ++i) {
            thisUser_ = _users[i];
            thisUserGet_ = _withdrawalRequest[thisUser_].mulDiv(assetPerShare_, PRECISION, Math.Rounding.Floor);
            // If the user's share is not enough to cover the gas, it will fail.
            thisUserGet_ -= gasPerUser_;
            IERC20(asset).safeTransfer(thisUser_, thisUserGet_);
            amounts_[i] = thisUserGet_;
            _pendingWithdrawers.remove(thisUser_);
            delete _withdrawalRequest[thisUser_];
        }
        emit ConfirmWithdrawal(_users, amounts_);

        uint256 totalGas_ = gasPerUser_ * _users.length;
        IERC20(asset).safeTransfer(feeReceiver, totalGas_);
    }

    /**
     * @dev Handles accidental transfers of tokens or ETH to this contract.
     * @param _token Address of the token to sweep.
     */
    function sweep(address _token) external onlyOwner {
        uint256 amount_ = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, amount_);

        uint256 ethbalance_ = address(this).balance;
        if (ethbalance_ > 0) {
            Address.sendValue(payable(msg.sender), ethbalance_);
        }

        emit Sweep(_token);
    }
}
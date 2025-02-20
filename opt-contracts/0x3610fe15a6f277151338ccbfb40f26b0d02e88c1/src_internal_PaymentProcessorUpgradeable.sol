// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

// external
import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { AccessControlEnumerableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_extensions_AccessControlEnumerableUpgradeable.sol";

// interfaces
import { IAggregatorV3 } from "./src_interfaces_external_IAggregatorV3.sol";
import { IFiatOracle } from "./src_interfaces_internal_IFiatOracle.sol";

// constants
import { Roles } from "./src_constants_RoleConstants.sol";

// libraries
import { Currency } from "./src_libraries_Currency.sol";
import { DateTimeLib } from "./src_libraries_DateTimeLib.sol";

// errors
import { ExceedEpochLimit, ExceedUserEpochLimit } from "./src_errors_Errors.sol";

/**
 * @title PaymentProcessor
 * @notice PaymentProcessor contract is responsible for handling all the payments
 */
contract PaymentProcessorUpgradeable is Initializable, AccessControlEnumerableUpgradeable {
    event EpochLimitUpdated(uint256 epochLimit, uint256 userEpochLimit);

    IAggregatorV3 internal _forexPriceFeed;
    IFiatOracle internal _fiatOracle;
    uint256 internal _epochLimit;
    uint256 internal _userEpochLimit;

    mapping(uint256 epoch => uint256 amount) private _epochAmount;
    mapping(uint256 epoch => mapping(bytes32 userId => uint256 amount)) private _userEpochAmount;

    function __PaymentProcessor_init(
        address forexPriceFeed_,
        address fiatOracle_,
        uint256 epochLimit_,
        uint256 userEpochLimit_
    )
        internal
        initializer
    {
        _forexPriceFeed = IAggregatorV3(forexPriceFeed_);
        _fiatOracle = IFiatOracle(fiatOracle_);

        __PaymentProcessor_init_unchained(epochLimit_, userEpochLimit_);
    }

    function __PaymentProcessor_init_unchained(uint256 epochLimit_, uint256 userEpochLimit_) internal initializer {
        _epochLimit = epochLimit_;
        _userEpochLimit = userEpochLimit_;
    }

    function setEpochLimit(uint256 epochLimit_, uint256 userEpochLimit_) external onlyRole(Roles.OPERATOR_ROLE) {
        _epochLimit = epochLimit_;
        _userEpochLimit = userEpochLimit_;
        emit EpochLimitUpdated(epochLimit_, userEpochLimit_);
    }

    function getWithdrawableAmount() external view returns (uint256) {
        uint256 currentEpoch = _currentEpoch();
        return _epochLimit - _epochAmount[currentEpoch];
    }

    function getWithdrawableAmountByUser(bytes32 userId) external view returns (uint256) {
        uint256 currentEpoch = _currentEpoch();
        return _userEpochLimit - _userEpochAmount[currentEpoch][userId];
    }

    function getOracle() external view returns (address forexPriceFeed, address fiatOracle) {
        return (address(_forexPriceFeed), address(_fiatOracle));
    }

    function getLimit() external view returns (uint256 epochLimit, uint256 userEpochLimit) {
        return (_epochLimit, _userEpochLimit);
    }

    function getEpochWithdrawnAmount(uint256 epoch) external view returns (uint256) {
        return _epochAmount[epoch];
    }

    function getUserEpochWithdrawnAmount(uint256 epoch, bytes32 userId) external view returns (uint256) {
        return _userEpochAmount[epoch][userId];
    }

    function getTokenAmount(address token_, uint256 fiatAmount_) public view returns (uint256) {
        return _fiatOracle.getTokenAmount(token_, _forexPriceFeed, fiatAmount_);
    }

    function _processTransfer(
        Currency token_,
        address recipient_,
        uint256 tokenAmount_,
        bytes32 userId_,
        uint256 fiatAmount_
    )
        internal
    {
        uint256 currentEpoch = _currentEpoch();

        _epochAmount[currentEpoch] += fiatAmount_;

        if (_epochAmount[currentEpoch] > _epochLimit) {
            revert ExceedEpochLimit();
        }

        _userEpochAmount[currentEpoch][userId_] += fiatAmount_;

        if (_userEpochAmount[currentEpoch][userId_] > _userEpochLimit) {
            revert ExceedUserEpochLimit();
        }

        token_.transfer(recipient_, tokenAmount_);
    }

    function _currentEpoch() internal view returns (uint256) {
        (uint256 year, uint256 month, uint256 day) = DateTimeLib.timestampToDate(block.timestamp);
        return DateTimeLib.dateToEpochDay(year, month, day);
    }

    uint256[44] private __gap;
}
// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.25;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

struct BeneficiaryData {
    address beneficiary;
    uint96 allocation;
    address creditToken;
    bytes4 repaymentFunc;
    address poolAddress;
    bytes4 getDebtFunc;
    bool debtVoided;
}

struct TokenData {
    uint256 index;
    uint256 balanceTracker;
    uint96 reassignedAllocation;
    uint256 initialTokens;
}

struct DistributionData {
    address defaultBeneficiary;
    uint96 totalAllocation;
    mapping(address beneficiary => BeneficiaryData) data;
    mapping(address token => TokenData) tokens;
    mapping(address token => mapping(address beneficiary => uint256)) repaidAmounts;
    address[] beneficiaries;
    address operator;
    mapping(address token => uint256 amount) operatorTokens;
}

/**
 * @title   - DiscreteDistribution
 * @author  - Credit Cooperative
 * @notice  - Core logic used by Spigot contract to distribute tokens to beneficiaries (e.g. LineOfCredit and other pool contracts external to Credit Coop contracts).
 */
abstract contract DiscreteDistribution {
    /// @dev allows to distribute small amounts of distributions correctly
    uint256 private constant MAGNITUDE = 1e30;
    uint256 internal constant MAX_INT = type(uint256).max;

    mapping(uint256 nonce => DistributionData) private _data;
    uint256 private _nonce;

    event BeneficiaryAdded(address indexed beneficiary, uint96 amount);
    event DefaultBeneficiaryUpdated(address indexed oldDefaultBeneficiary, address indexed newDefaultBeneficiary);
    event Distributed(address indexed token, uint256 indexed amount);
    event Repaid(address indexed token, address indexed beneficiary, uint256 indexed amount);
    event Reassigned(address indexed token, address indexed beneficiary);

    error DuplicateDefaultBenenficiary();
    error AmountZero();
    error RepaymentExceedsDistributedAmount();
    error CannotReassignDefaultBeneficiary();
    error AlreadyReassigned(address beneficiary, address token);
    error NotBeneficiary(address beneficiary);

    /**
     * @notice sets up the beneficiaries and their allocations
     * @param defaultBeneficiary the beneficiary that receives unassigned funds once other beneficiaries are repaid
     * @param beneficiaries the other beneficiaries and their allocations
     * @param tokens the tokens to be reassigned to the default beneficiary upon reset
     * @dev any funds present in the contract will be distributed among the beneficiaries according to their allocation
     */
    function _resetBeneficiaries(
        address operator,
        BeneficiaryData memory defaultBeneficiary,
        BeneficiaryData[] memory beneficiaries,
        address[] memory tokens
    ) internal {
        ++_nonce;
        _distributionData().operator = operator;
        _distributionData().defaultBeneficiary = defaultBeneficiary.beneficiary;
        _distributionData().data[defaultBeneficiary.beneficiary] = defaultBeneficiary;
        _distributionData().totalAllocation += defaultBeneficiary.allocation;
        emit BeneficiaryAdded(defaultBeneficiary.beneficiary, defaultBeneficiary.allocation);
        uint256 len = beneficiaries.length;
        for (uint256 i = 0; i < len; ++i) {
            BeneficiaryData memory beneficiary = beneficiaries[i];
            if (beneficiary.allocation == 0) revert AmountZero();
            if (beneficiary.beneficiary == _distributionData().defaultBeneficiary) {
                revert DuplicateDefaultBenenficiary();
            }
            _distributionData().data[beneficiary.beneficiary] = beneficiary;
            _distributionData().totalAllocation += beneficiary.allocation;
            _distributionData().beneficiaries.push(beneficiary.beneficiary);
            emit BeneficiaryAdded(beneficiary.beneficiary, beneficiary.allocation);
        }
        if (_distributionData().totalAllocation == 0) revert AmountZero();
        len = tokens.length;
        for (uint256 i = 0; i < len; ++i) {
            address token = tokens[i];
            uint256 currentBlance = IERC20(token).balanceOf(address(this));
            _distributionData().tokens[token].balanceTracker = currentBlance;
            _distributionData().tokens[token].initialTokens = currentBlance;
        }
    }

    /**
     * @notice registers a repayment of a beneficiary for a certain token
     * @dev this function MUST be called BEFORE transfering out tokens
     * @dev `amount` MUST be transferred out of the contract, otherwise accounting will be incorrect
     */
    function _registerRepayment(address token, address beneficiary, uint256 amount) internal {
        if (amount == 0) revert AmountZero();
        if (_distributionData().data[beneficiary].allocation == 0) revert NotBeneficiary(beneficiary);
        _updateDistributionIndex(token);
        uint256 distributedAmount = _repayableAmountOf(token, beneficiary);
        if (amount > distributedAmount) revert RepaymentExceedsDistributedAmount();
        _distributionData().tokens[token].balanceTracker -= amount;
        _distributionData().repaidAmounts[token][beneficiary] += amount;
        emit Repaid(token, beneficiary, amount);
    }

    /**
     * @notice reassigns tokens to the default beneficiary
     * @dev reassigns all remaining tokens to the beneficiary by updating the `reassignedTokens` variable
     * @dev adjusts the total allocation modifier so distributions do not take the beneficiary into account in the future
     * @dev flags the `repaidAmounts` variable for the beneficiary to mark that the beneficiary has an allocation of 0 for the reassigned token
     * @dev the allocation of the beneficiary is implicitly redistributed amongst all other beneficiaries
     */
    function _reassignTokens(address token, address beneficiary) internal {
        address defaultBeneficiary = _distributionData().defaultBeneficiary;
        if (beneficiary == defaultBeneficiary) revert CannotReassignDefaultBeneficiary();
        if (_distributionData().data[beneficiary].allocation == 0) revert NotBeneficiary(beneficiary);
        uint256 repaidAmount = _distributionData().repaidAmounts[token][beneficiary];
        if (repaidAmount == MAX_INT) revert AlreadyReassigned(beneficiary, token);
        _updateDistributionIndex(token);
        _distributionData().tokens[token].reassignedAllocation += _distributionData().data[beneficiary].allocation;
        _distributionData().repaidAmounts[token][defaultBeneficiary] += repaidAmount;
        _distributionData().repaidAmounts[token][beneficiary] = MAX_INT;
        emit Reassigned(token, beneficiary);
    }

    /// @notice reserves tokens in the contract to be used outside of the distrubution library
    function _reserveTokens(address token, uint256 amount) internal {
        _distributionData().operatorTokens[token] += amount;
    }

    /// @notice should be called after transferring out reserved tokens
    function _releaseTokens(address token, uint256 amount) internal {
        _distributionData().operatorTokens[token] -= amount;
    }

    function _voidDebt(address beneficiary) internal {
        _distributionData().data[beneficiary].debtVoided = true;
    }

    /**
     * @dev returns 0 if the beneficiary was reassigned to the default beneficiary
     * @return the allocation of a beneficiary for a certain token
     */
    function _allocationOf(address token, address beneficiary) internal view returns (uint96) {
        if (beneficiary == _distributionData().defaultBeneficiary) {
            return _distributionData().data[beneficiary].allocation
                + _distributionData().tokens[token].reassignedAllocation;
        }
        if (_distributionData().repaidAmounts[token][beneficiary] == MAX_INT) return 0;
        return _distributionData().data[beneficiary].allocation;
    }

    /**
     * @dev takes into account beneficiaries that were reassigned to the default beneficiary
     * @return the total allocation of a token
     */
    function _totalAllocation() internal view returns (uint96) {
        return _distributionData().totalAllocation;
    }

    /**
     * @dev returns 0 if the beneficiary was reassigned to the default beneficiary
     * @return amount the amount of tokens that can be used for repayment
     */
    function _repayableAmountOf(address token, address beneficiary) internal view returns (uint256 amount) {
        (uint256 index,) = _currentDistributionIndex(token);
        amount = _calculateDistribution(token, beneficiary, index);
        if (beneficiary == _distributionData().defaultBeneficiary) {
            amount += _distributionData().tokens[token].initialTokens;
        }
    }

    function _operator() internal view returns (address) {
        return _distributionData().operator;
    }

    function _operatorTokens(address token) internal view returns (uint256) {
        return _distributionData().operatorTokens[token];
    }

    function _defaultBeneficiary() internal view returns (BeneficiaryData memory) {
        return _distributionData().data[_distributionData().defaultBeneficiary];
    }

    function _owner() internal view returns (address) {
        return _distributionData().defaultBeneficiary;
    }

    function _beneficiaries() internal view returns (address[] memory) {
        return _distributionData().beneficiaries;
    }

    function _beneficiaryData(address beneficiary) internal view returns (BeneficiaryData storage) {
        return _distributionData().data[beneficiary];
    }

    /// HELPERS ///

    /// @notice update the distribution index by registering incoming funds since the last index update
    function _updateDistributionIndex(address token) private {
        (uint256 newIndex, uint256 newDistribution) = _currentDistributionIndex(token);
        if (newDistribution != 0) {
            _distributionData().tokens[token].balanceTracker += newDistribution;
            emit Distributed(token, newDistribution);
        }
        _distributionData().tokens[token].index = newIndex;
    }

    /**
     * @notice calculates the current distribution index based on the current token balance
     * @dev reverts if no beneficiaries are set up
     * @dev keeps track of incoming tokens by caching the previous balance. Whenever funds reach the contract it's assumed that these are funds to be distributed. If funds leave the contract the `_registerRepayment` function must be called in order not to break accounting
     * @dev keeps track of repaid beneficiaries
     * @dev if no beneficiaries are set up this function will revert, as total allocation is 0
     */
    function _currentDistributionIndex(address token)
        private
        view
        returns (uint256 newIndex, uint256 newDistribution)
    {
        uint256 totalAllocation = _totalAllocation();
        uint256 index = _distributionData().tokens[token].index;
        uint256 currentDistributionBalance = IERC20(token).balanceOf(address(this));
        newDistribution = currentDistributionBalance - _distributionData().tokens[token].balanceTracker
            - _distributionData().operatorTokens[token];
        newIndex = index + (newDistribution * MAGNITUDE) / totalAllocation;
    }

    /// @notice calculates the distributed funds of a beneficiary based on a passed index and taking into account prior repaid amounts
    function _calculateDistribution(address token, address beneficiary, uint256 index) private view returns (uint256) {
        uint256 repaidAmount = _distributionData().repaidAmounts[token][beneficiary];
        if (repaidAmount == MAX_INT) return 0;
        uint256 distributedAmount = (_allocationOf(token, beneficiary) * index) / MAGNITUDE;
        return distributedAmount - repaidAmount;
    }

    function _distributionData() internal view returns (DistributionData storage) {
        return _data[_nonce];
    }
}
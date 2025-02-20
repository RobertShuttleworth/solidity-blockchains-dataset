
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

/**
 * @title VestingWallet
 * @dev This contract handles the vesting of ERC20 tokens for a given beneficiary. Custody of multiple tokens
 * can be given to this contract, which will release the token to the beneficiary following a monthly vesting schedule.
 */
contract VestingWallet is Initializable {
    using SafeERC20 for IERC20;

    string public name;

    // Vesting schedule
    address public beneficiary;
    uint256 public startTime;
    uint256 public totalMonths;
    uint256 public totalAmount;
    uint256 public claimedAmount;

    // Customization for initial release
    uint256 public zeroReleaseMonths;
    uint256 public firstMonthRelease;

    IERC20 public token;

    event TokensReleased(uint256 amount);

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize the vesting wallet with beneficiary, start time, total months, total amount, and token address.
     */
    function initialize(
        string calldata _name,
        address _beneficiary,
        uint256 _startTime,
        uint256 _totalMonths,
        uint256 _totalAmount,
        address _token,
        uint256 _zeroReleaseMonths,
        uint256 _firstMonthRelease
    ) public initializer {
        require(_beneficiary != address(0), "Beneficiary cannot be zero address");
        require(_totalMonths > 0, "Total months must be greater than zero");
        require(_totalAmount > 0, "Total amount must be greater than zero");
        require(_token != address(0), "Token address cannot be zero");

        name = _name;
        beneficiary = _beneficiary;
        startTime = _startTime;
        totalMonths = _totalMonths;
        totalAmount = _totalAmount * (10 ** 18);
        token = IERC20(_token);
        zeroReleaseMonths = _zeroReleaseMonths;
        firstMonthRelease = _firstMonthRelease * (10 ** 18);
    }

    function changeBeneficiary(address newBeneficiary) external {
        require(msg.sender == beneficiary, "Only beneficiary can change beneficiary");
        require(newBeneficiary != address(0), "Beneficiary cannot be zero address");
        beneficiary = newBeneficiary;
    }

    function releasableAmount() public view returns (uint256) {
        uint256 vested = vestedAmount();
        return vested > claimedAmount ? vested - claimedAmount : 0;
    }

    function releaseTokens() public {
        require(msg.sender == beneficiary, "Only beneficiary can release tokens");
        uint256 amount = releasableAmount();
        require(amount > 0, "No tokens to release");

        claimedAmount += amount;
        token.safeTransfer(beneficiary, amount);

        emit TokensReleased(amount);
    }

    function vestedAmount() public view returns (uint256) {
        if (block.timestamp < startTime) {
            return 0;
        }
        uint256 currentMonth = 1 + (block.timestamp - startTime) / 30 days;

        uint256 specialMonths = zeroReleaseMonths;
        if (firstMonthRelease > 0){
            specialMonths = specialMonths + 1;
        }
        if (currentMonth <= specialMonths){
            return firstMonthRelease;
        }

        uint256 remainingMonths = totalMonths - specialMonths;
        uint256 remainingAmount = totalAmount - firstMonthRelease;
        uint256 monthlyRelease = remainingAmount / remainingMonths;
        uint256 effectiveMonths = currentMonth > totalMonths ? totalMonths : currentMonth;
        return firstMonthRelease + (effectiveMonths - specialMonths) * monthlyRelease;
    }
}
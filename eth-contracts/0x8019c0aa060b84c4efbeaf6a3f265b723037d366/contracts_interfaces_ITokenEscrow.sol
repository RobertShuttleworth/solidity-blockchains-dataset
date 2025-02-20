// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title ITokenEscrow
 * @dev Interface for token escrow contract
 */
interface ITokenEscrow {
    function deposit(
        address beneficiary,
        uint256 amount,
        uint256 vestingPeriod,
        uint256 tierId
    ) external;

    function withdraw(uint256 scheduleId) external returns (uint256);

    function getVestedAmount(
        address beneficiary,
        uint256 scheduleId
    ) external view returns (uint256);

    function getVestingSchedules(
        address beneficiary
    )
        external
        view
        returns (
            uint256[] memory totalAmounts,
            uint256[] memory releasedAmounts,
            uint256[] memory startTimes,
            uint256[] memory durations,
            bool[] memory revoked
        );

    function depositPublicSale(address _beneficiary, uint256 _amount) external;

    function setPublicSaleWithdrawalsEnabled(bool _enabled) external;

    function withdrawPublicSale(address _beneficiary) external;
}
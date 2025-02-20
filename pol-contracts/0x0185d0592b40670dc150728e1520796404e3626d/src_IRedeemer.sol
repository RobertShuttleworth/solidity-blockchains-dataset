// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;

import {IRedeemerStorage} from "./src_IRedeemerStorage.sol";

interface IRedeemer is IRedeemerStorage{ 

    event VestingScheduleCreated(address _sender, address _beneficiary, uint256 _amount, bytes32 _id);
    event TokenReleased(address _beneficiary, uint256 _amount, bytes32 _id);

    /**
     * @notice Creates a new vesting schedule for a beneficiary.
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _amount total amount of tokens to be released at the end of the vesting
     */

    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount
    ) external;


    /**
     * @notice Release vested amount of tokens.
     * @param vestingScheduleId the vesting schedule identifier
     * @param amount the amount to release
     */

    function release(
        bytes32 vestingScheduleId,
        uint256 amount
    ) external;

    /**
     * @dev Returns the number of vesting schedules associated to a beneficiary.
     * @return the number of vesting schedules
     */

    function getVestingSchedulesCountByBeneficiary(
        address _beneficiary
    ) external view returns (uint256);


    /**
     * @dev Returns the vesting schedule id at the given index.
     * @return the vesting id
     */

    function getVestingIdAtIndex(
        uint256 index
    ) external view returns (bytes32);

    /**
     * @notice Returns the vesting schedule information for a given holder and index.
     * @return the vesting schedule structure information
     */

    function getVestingScheduleByAddressAndIndex(
        address holder,
        uint256 index
    ) external view returns (VestingSchedule memory);

    /**
     * @notice Returns the total amount of vesting schedules.
     * @return the total amount of vesting schedules
     */

    function getVestingSchedulesTotalAmount() external view returns (uint256);

    /**
     * @notice Returns all of the user's schedules
     * @param holder User's address
     */

    function getAllVestingSchedulesByAddress(address holder) external view returns(VestingSchedule[] memory);

    /**
     * @dev Returns the number of vesting schedules managed by this contract.
     * @return the number of vesting schedules
     */

    function getVestingSchedulesCount() external view returns (uint256);


    /**
     * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
     * @return the vested amount
     */

    function computeReleasableAmount(
        bytes32 vestingScheduleId
    )
        external
        view
        returns (uint256);

    function getVestingSchedule(
        bytes32 vestingScheduleId
    ) external view returns (VestingSchedule memory);

     /**
     * @dev Computes the next vesting schedule identifier for a given holder address.
     */

    function computeNextVestingScheduleIdForHolder(
        address holder
    ) external view returns (bytes32);

    /**
     * @dev Returns the last vesting schedule for a given holder address.
     */

    function getLastVestingScheduleForHolder(
        address holder
    ) external view returns (VestingSchedule memory);

    /**
     * @dev Computes the vesting schedule identifier for an address and an index.
     */

    function computeVestingScheduleIdForAddressAndIndex(
        address holder,
        uint256 index
    ) external pure returns (bytes32);
}
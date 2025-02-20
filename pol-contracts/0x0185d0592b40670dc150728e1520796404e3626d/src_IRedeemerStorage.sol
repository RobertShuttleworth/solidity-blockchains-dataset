// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {ERC20Burnable} from "./openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol";
import {IAccessControl} from "./openzeppelin_contracts_access_IAccessControl.sol";


interface IRedeemerStorage {

     struct VestingSchedule {
        // beneficiary of tokens after they are released
        address beneficiary;
        // cliff time of the vesting start in seconds since the UNIX epoch
        uint256 cliff;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountTotal;
        // amount of tokens released
        uint256 released;
        // whether or not the vesting has been revoked
        bool revoked;
    }

    struct VestingParams {
        // _cliff duration in seconds of the cliff in which tokens will begin to vest
        uint256 cliff;
        // duration of the vesting period in seconds
        uint256 duration;
        // duration of a slice period for the vesting in seconds
        uint256 slicePeriodSeconds;
        // initial unlock - % of PMX that will be received immediately after providing ePMX
        uint256 initialUnlockPercentage;
        // a deadline after which new vesting schedules cannot be created
        uint256 redeemDeadline;
    }

    /**
     * @notice Retrieves the instance of the PMX contract.
     */
     function pmx() external view returns (IERC20);

    /**
     * @notice Retrieves the instance of the EPMX contract.
     */
     function epmx() external view returns (ERC20Burnable);

    /**
     * @notice Retrieves the instance of PrimexRegistry contract.
     */
    function registry() external view returns (IAccessControl);

    /**
     * @notice Retrieves the instance of the treasury contract.
     */
    function treasury() external view returns (address);

    /**
     * @notice Retrieves the vesting params of the contract
     */
    function vestingParams() external view returns (uint256, uint256, uint256, uint256, uint256);

    /**
     * @notice Returns true if the address is blacklisted
     */
    function isBlackListed(address) external view returns (bool);

     /**
     * @notice Returns true if the address is whitelisted
     */
    function isWhiteListed(address) external view returns (bool);

}
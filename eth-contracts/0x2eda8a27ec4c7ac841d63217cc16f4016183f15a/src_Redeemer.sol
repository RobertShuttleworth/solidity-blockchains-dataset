// SPDX-License-Identifier: Apache-2.0
// A modified version of TokenVesting.sol
// Origin: https://github.com/AbdelStark/token-vesting-contracts/blob/7776245a5b3edf18cb0ae73ca49d005004186d80/src/TokenVesting.sol
// Token burn and initial unlock logic added
pragma solidity 0.8.26;

// OpenZeppelin dependencies
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IERC165} from "./openzeppelin_contracts_utils_introspection_IERC165.sol";
import {ERC20Burnable} from "./openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol";
import {IAccessControl} from "./openzeppelin_contracts_access_IAccessControl.sol";

import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {RedeemerStorage} from "./src_RedeemerStorage.sol";
import {IRedeemer} from "./src_IRedeemer.sol";
import {WadRayMath} from "./src_libraries_WadRayMath.sol";

/**
 * @title Redeemer
 */
contract Redeemer is IRedeemer, RedeemerStorage {

    bytes32 constant MEDIUM_TIMELOCK_ADMIN = keccak256("MEDIUM_TIMELOCK_ADMIN");

    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Throws if caller is not granted with _role
     * @param _role The role that is being checked for a function caller
     */
    modifier onlyRole(bytes32 _role) {
        require(registry.hasRole(_role, msg.sender), "Redeemer: FORBIDDEN");
        _;
    }

  
    /**
     * @dev Reverts if the vesting schedule does not exist
     */
    modifier onlyIfVestingScheduleExists(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].amountTotal > 0);
        _;
    }

    /**
     * @notice  Initializes the Redeemer contract.
     * @dev This function should only be called once during the initial setup of the contract.
     * @param _epmx The address of the EPMX
     * @param _pmx The address of the PMX
     * @param _registry The address of the Primex Registry
     * @param _treasury The address of the Primex treasury to which unclaimed PMX tokens will be sent after the redeemDeadline.
     * @param _whiteListingEnabled enables or disables whitelisting
     * @param _vestingParams VestingParams struct for initialization
     */
    function initialize(
        address _epmx, 
        address _pmx,
        address _registry,
        address _treasury,
        bool _whiteListingEnabled,
        VestingParams calldata _vestingParams
    ) external initializer {
        require(
            IERC165(_epmx).supportsInterface(type(IERC20).interfaceId) && 
            IERC165(_registry).supportsInterface(type(IAccessControl).interfaceId),
            "Redeemer: address is not supported"
        );
        epmx = ERC20Burnable(_epmx);
        pmx = IERC20(_pmx);
        registry = IAccessControl(_registry);
        treasury = _treasury;
        whiteListingEnabled = _whiteListingEnabled;
        require(_vestingParams.duration > 0, "Redeemer: duration must be > 0");
        require(
            _vestingParams.slicePeriodSeconds > 0,
            "Redeemer: slicePeriodSeconds must be > 0"
        );
        require(_vestingParams.duration >= _vestingParams.cliff, "Redeemer: duration must be >= cliff");
        vestingParams = _vestingParams;
        __ReentrancyGuard_init();
    }

    /**
     * @dev This function is called for plain Ether transfers, i.e. for every call with empty calldata.
     */
    receive() external payable {}

    /**
     * @dev Fallback function is executed if none of the other functions match the function
     * identifier or no data was provided with the function call.
     */
    fallback() external payable {}


    /**
     * @dev Enables or disables whitelisting. Only MEDIUM_TIMELOCK_ADMIN can call it.
     */
   
    function switchWhiteListingFlag() external onlyRole(MEDIUM_TIMELOCK_ADMIN) {
        whiteListingEnabled = !whiteListingEnabled;
    }

     /**
     * @dev Adds or removes an address to the whitelist. Only MEDIUM_TIMELOCK_ADMIN can call it.
     */
    function setStatusesToWhiteList(address[] calldata _addresses, bool[] calldata _statuses) external onlyRole(MEDIUM_TIMELOCK_ADMIN) {
        for (uint256 i; i < _addresses.length; i++) {
            isWhiteListed[_addresses[i]] = _statuses[i];
        }
    }

    /**
     * @dev Adds or removes an address to the blackList. Only MEDIUM_TIMELOCK_ADMIN can call it.
     */

    function setStatusesToBlackList(address[] calldata _addresses, bool[] calldata _statuses) external onlyRole(MEDIUM_TIMELOCK_ADMIN){
        for (uint256 i; i < _addresses.length; i++) {
            isBlackListed[_addresses[i]] = _statuses[i];
        }
    }

    /**
     * @inheritdoc IRedeemer
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount
    ) external override nonReentrant {
        _onlyAccessible(msg.sender);
        _onlyAccessible(_beneficiary);
        uint256 currentTime = getCurrentTime();
        require(currentTime <= vestingParams.redeemDeadline, "Redeemer: the redeemDeadline has passed");
        require(
            getWithdrawableAmount() >= _amount,
            "Redeemer: cannot create vesting schedule because not sufficient tokens"
        );
        require(_amount > 0, "Redeemer: amount must be > 0");
        IERC20(epmx).safeTransferFrom(msg.sender, address(this), _amount);
        epmx.burn(_amount);
        bytes32 vestingScheduleId = computeNextVestingScheduleIdForHolder(
            _beneficiary
        );

        // calculate initialUnlockPercentage
        uint256 initialAmount = _amount.wmul(vestingParams.initialUnlockPercentage);
        if(initialAmount > 0) pmx.safeTransfer(_beneficiary, initialAmount);
        uint256 cliff = currentTime + vestingParams.cliff;
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            _beneficiary,
            cliff,
            _amount - initialAmount,
            0
        );
        vestingSchedulesTotalAmount += _amount - initialAmount;
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount + 1;
        emit VestingScheduleCreated(msg.sender, _beneficiary, _amount, vestingScheduleId);

    }

    /**
     * @notice Withdraw the withdrawable amount amount if possible.
     */
    function withdrawUnclaimed() external onlyRole(MEDIUM_TIMELOCK_ADMIN) {
        require(getCurrentTime() > vestingParams.redeemDeadline, "Redeemer: the redeemDeadline has not passed");
        uint256 withdrawAmount = getWithdrawableAmount();
        if(withdrawAmount > 0) pmx.safeTransfer(treasury, withdrawAmount);
    }
    /**
     * @inheritdoc IRedeemer
     */

    function release(
        bytes32 vestingScheduleId,
        uint256 amount
    ) external override nonReentrant onlyIfVestingScheduleExists(vestingScheduleId) {
        _onlyAccessible(msg.sender);
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        require(
            msg.sender == vestingSchedule.beneficiary,
            "Redeemer: only beneficiary can release vested tokens"
        );
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(
            vestedAmount >= amount,
            "Redeemer: cannot release tokens, not enough vested tokens"
        );
        vestingSchedule.released = vestingSchedule.released + amount;
        vestingReleasedTotalAmount = vestingReleasedTotalAmount += amount;
        pmx.safeTransfer(vestingSchedule.beneficiary, amount);
        emit TokenReleased(msg.sender, amount, vestingScheduleId);

    }

    /**
     * @inheritdoc IRedeemer
     */

    function getVestingSchedulesCountByBeneficiary(
        address _beneficiary
    ) external view override returns (uint256) {
        return holdersVestingCount[_beneficiary];
    }

    /**
     * @inheritdoc IRedeemer
     */

    function getVestingIdAtIndex(
        uint256 index
    ) external view override returns (bytes32) {
        require(
            index < getVestingSchedulesCount(),
            "Redeemer: index out of bounds"
        );
        return vestingSchedulesIds[index];
    }

    /**
     * @inheritdoc IRedeemer
     */

    function getAllVestingSchedulesByAddress(address holder) external view override returns(VestingSchedule[] memory){
        uint256 count = holdersVestingCount[holder];
        VestingSchedule[] memory schedules = new VestingSchedule[](count);
        for(uint256 i; i < count; i++){
            schedules[i] = getVestingScheduleByAddressAndIndex(holder, i);
        }
        return schedules;
    }

    /**
     * @inheritdoc IRedeemer
     */

    function getVestingScheduleByAddressAndIndex(
        address holder,
        uint256 index
    ) public view override returns (VestingSchedule memory) {
        return
            getVestingSchedule(
                computeVestingScheduleIdForAddressAndIndex(holder, index)
            );
    }

     /**
     * @inheritdoc IRedeemer
     */
    function getVestingSchedulesTotalAmount() external view override returns (uint256) {
        return vestingSchedulesTotalAmount;
    }

    /**
     * @inheritdoc IRedeemer
     */
    function getVestingSchedulesCount() public view override returns (uint256) {
        return vestingSchedulesIds.length;
    }

    /**
     * @inheritdoc IRedeemer
     */
    function computeReleasableAmount(
        bytes32 vestingScheduleId
    )
        external
        view
        override 
        onlyIfVestingScheduleExists(vestingScheduleId)
        returns (uint256)
    {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        return _computeReleasableAmount(vestingSchedule);
    }

    /**
     * @notice Returns the vesting schedule information for a given identifier.
     * @return the vesting schedule structure information
     */
    function getVestingSchedule(
        bytes32 vestingScheduleId
    ) public view returns (VestingSchedule memory) {
        return vestingSchedules[vestingScheduleId];
    }

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     */
    function getWithdrawableAmount() public view returns (uint256 amount) {
        uint256 balance = pmx.balanceOf(address(this));
        if(balance > vestingSchedulesTotalAmount - vestingReleasedTotalAmount){
            return pmx.balanceOf(address(this)) + vestingReleasedTotalAmount - vestingSchedulesTotalAmount;
        }
    }

    /**
     * @inheritdoc IRedeemer
     */

    function computeNextVestingScheduleIdForHolder(
        address holder
    ) public view override returns (bytes32) {
        return
            computeVestingScheduleIdForAddressAndIndex(
                holder,
                holdersVestingCount[holder]
            );
    }

     /**
     * @inheritdoc IRedeemer
     */

    function getLastVestingScheduleForHolder(
        address holder
    ) external view override returns (VestingSchedule memory) {
        return
            vestingSchedules[
                computeVestingScheduleIdForAddressAndIndex(
                    holder,
                    holdersVestingCount[holder] - 1
                )
            ];
    }

     /**
     * @inheritdoc IRedeemer
     */

    function computeVestingScheduleIdForAddressAndIndex(
        address holder,
        uint256 index
    ) public pure override returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    /**
     * @dev Computes the releasable amount of tokens for a vesting schedule.
     * @return the amount of releasable tokens
     */
    function _computeReleasableAmount(
        VestingSchedule memory vestingSchedule
    ) internal view returns (uint256) {
        // Retrieve the current time.
        uint256 currentTime = getCurrentTime();
        // If the current time is before the cliff, no tokens are releasable.
        if ((currentTime < vestingSchedule.cliff)) {
            return 0;
        }
        // If the current time is after the vesting period, all tokens are releasable,
        // minus the amount already released.
        else if (
            currentTime >= vestingSchedule.cliff + vestingParams.duration
        ) {
            return vestingSchedule.amountTotal - vestingSchedule.released;
        }
        // Otherwise, some tokens are releasable.
        else {
            // Compute the number of full vesting periods that have elapsed.
            uint256 timeFromStart = currentTime - vestingSchedule.cliff;
            uint256 secondsPerSlice = vestingParams.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart / secondsPerSlice;
            uint256 vestedSeconds = vestedSlicePeriods * secondsPerSlice;
            // Compute the amount of tokens that are vested.
            uint256 vestedAmount = (vestingSchedule.amountTotal *
                vestedSeconds) / vestingParams.duration;
            // Subtract the amount already released and return.
            return vestedAmount - vestingSchedule.released;
        }
    }

    /**
     * @dev Throws if the user is not whitelisted when the whiteListingEnabled is true otherwise it is throws if the user is blacklisted. 
     * @param _user The address to be checked
     */
    function _onlyAccessible(address _user) internal view {
        if(whiteListingEnabled){
            require(isWhiteListed[_user], "Redeemer: user is not in the whitelist");
        } else {
            require(!isBlackListed[_user], "Redeemer: user is blacklisted");
        }   
    }

    /**
     * @dev Returns the current time.
     * @return the current timestamp in seconds.
     */
    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
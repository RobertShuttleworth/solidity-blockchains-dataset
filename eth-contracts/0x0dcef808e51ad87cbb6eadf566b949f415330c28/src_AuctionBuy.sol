// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {Time} from "./src_utils_Time.sol";
import {wmul} from "./src_utils_Math.sol";
import {GoatX} from "./src_GoatX.sol";
import {SwapActions, SwapActionsState} from "./src_actions_SwapActions.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {ERC20Burnable} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_ERC20Burnable.sol";

/**
 * @title AuctionBuy
 * @author Decentra
 */
contract AuctionBuy is SwapActions {
    using SafeERC20 for *;

    uint32 public constant INTERVAL_TIME = 8 minutes;
    uint32 public constant INTERVALS_PER_DAY = 1 days / INTERVAL_TIME;

    /// @notice Struct to represent intervals
    struct Interval {
        uint256 amountAllocated;
        uint256 amountSentToGoatFeed;
    }

    ///@notice The startTimestamp
    uint32 public immutable startTimeStamp;
    ERC20Burnable immutable titanX;
    GoatX immutable goatX;

    /// @notice Timestamp of the last update
    uint32 public lastUpdatedIntervalTimestamp;

    /// @notice Last interval number
    uint32 public lastIntervalNumber;

    /// @notice  Last called interval
    uint32 public lastCalledInterval;

    /// @notice That last snapshot timestamp
    uint32 public lastSnapshot;

    ///@notice TitanX Swap cap
    uint256 public swapCap;

    /// @notice Mapping from interval number to Interval struct
    mapping(uint32 interval => Interval) public intervals;

    /// @notice Total TitanX tokens distributed
    uint256 public totalTitanXDistributed;

    uint256 public toDistribute;

    /// @notice Event emitted when tokens are bought and sent to GoatFeed
    event SentToGoatFeed(uint256 indexed titanXAmount, uint256 indexed goatXSentToGoatFeed, address indexed caller);

    /// @notice Error when the contract has not started yet
    error NotStartedYet();

    /// @notice Error when interval has already been called
    error IntervalAlreadyCalled();

    /// @notice Constructor initializes the contract
    constructor(uint32 _startTimestamp, address _titanX, GoatX _goatX, SwapActionsState memory _params)
        SwapActions(_params)
    {
        swapCap = type(uint256).max;
        goatX = _goatX;

        titanX = ERC20Burnable(_titanX);
        startTimeStamp = _startTimestamp;
    }

    /// @notice Updates the contract state for intervals
    modifier intervalUpdate() {
        _intervalUpdate();
        _;
    }

    function changeSwapCap(uint256 _newSwapCap) external onlySlippageAdminOrOwner {
        swapCap = _newSwapCap == 0 ? type(uint256).max : _newSwapCap;
    }

    /**
     * @param _deadline The deadline for which the transaction should be executed
     */
    function swapTitanXToGoatXAndFeedTheAuction(uint32 _deadline) external intervalUpdate {
        if (msg.sender != tx.origin) revert OnlyEOA();

        Interval storage currInterval = intervals[lastIntervalNumber];

        if (currInterval.amountSentToGoatFeed != 0) revert IntervalAlreadyCalled();

        _updateSnapshot();
        if (currInterval.amountAllocated > swapCap) {
            uint256 difference = currInterval.amountAllocated - swapCap;

            //@note - Add the difference for the next day
            toDistribute += difference;

            currInterval.amountAllocated = swapCap;
        }

        uint256 incentive = wmul(currInterval.amountAllocated, uint256(0.01e18));

        currInterval.amountSentToGoatFeed = currInterval.amountAllocated;

        uint256 goatXAmount =
            swapExactInput(address(titanX), address(goatX), currInterval.amountAllocated - incentive, 0, _deadline);

        goatX.transfer(address(goatX.goatFeed()), goatXAmount);

        titanX.safeTransfer(msg.sender, incentive);

        lastCalledInterval = lastIntervalNumber;

        emit SentToGoatFeed(currInterval.amountAllocated - incentive, goatXAmount, msg.sender);
    }

    /**
     * @notice Distributes TitanX tokens to swap for GoatX and send to Goat Feed
     * @param _amount The amount of TitanX tokens
     */
    function distribute(uint256 _amount) external notAmount0(_amount) {
        ///@dev - If there are some missed intervals update the accumulated allocation before depositing new TitanX

        if (Time.blockTs() > startTimeStamp && Time.blockTs() - lastUpdatedIntervalTimestamp > INTERVAL_TIME) {
            _intervalUpdate();
        }

        titanX.safeTransferFrom(msg.sender, address(this), _amount);

        _updateSnapshot();

        toDistribute += _amount;
    }

    /**
     * @notice Get the day count for a timestamp
     * @param t The timestamp from which to get the timestamp
     */
    function dayCountByT(uint32 t) public pure returns (uint32) {
        // Adjust the timestamp to the cut-off time (2 PM UTC)
        uint32 adjustedTime = t - 14 hours;

        // Calculate the number of days since Unix epoch
        return adjustedTime / 86400;
    }

    /**
     * @notice Gets the end of the day with a cut-off hour of 2 PM UTC
     * @param t The time from where to get the day end
     */
    function getDayEnd(uint32 t) public pure returns (uint32) {
        // Adjust the timestamp to the cutoff time (2 PM UTC)
        uint32 adjustedTime = t - 14 hours;

        // Calculate the number of days since Unix epoch
        uint32 daysSinceEpoch = adjustedTime / 86400;

        // Calculate the start of the next day at 2 PM UTC
        uint32 nextDayStartAt5PM = (daysSinceEpoch + 1) * 86400 + 14 hours;

        // Return the timestamp for 17:00:00 PM UTC of the given day
        return nextDayStartAt5PM;
    }

    function _calculateIntervals(uint32 timeElapsedSince)
        internal
        view
        returns (uint32 _lastIntervalNumber, uint256 _totalAmountForInterval, uint32 missedIntervals)
    {
        missedIntervals = _calculateMissedIntervals(timeElapsedSince);

        _lastIntervalNumber = lastIntervalNumber + missedIntervals + 1;

        uint32 currentDay = dayCountByT(uint32(block.timestamp));

        uint32 _lastCalledIntervalTimestampTimestamp = lastUpdatedIntervalTimestamp;

        uint32 dayOfLastInterval =
            _lastCalledIntervalTimestampTimestamp == 0 ? currentDay : dayCountByT(_lastCalledIntervalTimestampTimestamp);

        uint256 _totalTitanXDistributed = totalTitanXDistributed;

        if (currentDay == dayOfLastInterval) {
            uint256 _amountPerInterval = uint256(_totalTitanXDistributed / INTERVALS_PER_DAY);

            uint256 additionalAmount = _amountPerInterval * missedIntervals;

            _totalAmountForInterval = _amountPerInterval + additionalAmount;
        } else {
            uint32 _lastUpdatedIntervalTimestamp = _lastCalledIntervalTimestampTimestamp;

            uint32 theEndOfTheDay = getDayEnd(_lastUpdatedIntervalTimestamp);

            uint32 accumulatedIntervalsForTheDay = (theEndOfTheDay - _lastUpdatedIntervalTimestamp) / INTERVAL_TIME;

            //@note - Calculate the remaining intervals from the last one's day
            _totalAmountForInterval +=
                uint256(_totalTitanXDistributed / INTERVALS_PER_DAY) * accumulatedIntervalsForTheDay;

            //@note - Calculate the upcoming intervals with the to distribute shares
            uint256 _intervalsForNewDay = missedIntervals >= accumulatedIntervalsForTheDay
                ? (missedIntervals - accumulatedIntervalsForTheDay) + 1
                : 0;
            _totalAmountForInterval += (_intervalsForNewDay > INTERVALS_PER_DAY)
                ? uint256(toDistribute)
                : uint256(toDistribute / INTERVALS_PER_DAY) * _intervalsForNewDay;
        }

        Interval memory prevInt = intervals[lastIntervalNumber];

        //@note - If the last interval was only updated, but not called add its allocation to the next one.
        uint256 additional =
            prevInt.amountSentToGoatFeed == 0 && prevInt.amountAllocated != 0 ? prevInt.amountAllocated : 0;

        if (_totalAmountForInterval + additional > titanX.balanceOf(address(this))) {
            _totalAmountForInterval = uint256(titanX.balanceOf(address(this)));
        } else {
            _totalAmountForInterval += additional;
        }
    }

    function _calculateMissedIntervals(uint32 timeElapsedSince) internal view returns (uint32 _missedIntervals) {
        _missedIntervals = timeElapsedSince / INTERVAL_TIME;

        if (lastUpdatedIntervalTimestamp != 0) _missedIntervals--;
    }

    function _updateSnapshot() internal {
        if (Time.blockTs() < startTimeStamp || lastSnapshot + 24 hours > Time.blockTs()) return;

        if (lastSnapshot != 0 && lastSnapshot + 48 hours <= Time.blockTs()) {
            // If we have missed entire snapshot of interacting with the contract
            toDistribute = 0;
        }

        totalTitanXDistributed = toDistribute;

        toDistribute = 0;

        uint32 timeElapsed = Time.blockTs() - startTimeStamp;

        uint32 snapshots = timeElapsed / 24 hours;

        lastSnapshot = startTimeStamp + (snapshots * 24 hours);
    }

    /// @notice Updates the contract state for intervals
    function _intervalUpdate() private {
        if (Time.blockTs() < startTimeStamp) revert NotStartedYet();

        if (lastSnapshot == 0) _updateSnapshot();

        (
            uint32 _lastInterval,
            uint256 _amountAllocated,
            uint32 _missedIntervals,
            uint32 _lastIntervalStartTimestamp,
            bool updated
        ) = getCurrentInterval();

        if (updated) {
            lastUpdatedIntervalTimestamp = _lastIntervalStartTimestamp + (uint32(_missedIntervals) * INTERVAL_TIME);
            intervals[_lastInterval] = Interval({amountAllocated: _amountAllocated, amountSentToGoatFeed: 0});
            lastIntervalNumber = _lastInterval;
        }
    }

    function getCurrentInterval()
        public
        view
        returns (
            uint32 _lastInterval,
            uint256 _amountAllocated,
            uint32 _missedIntervals,
            uint32 _lastIntervalStartTimestamp,
            bool updated
        )
    {
        if (startTimeStamp > Time.blockTs()) return (0, 0, 0, 0, false);

        uint32 startPoint = lastUpdatedIntervalTimestamp == 0 ? startTimeStamp : lastUpdatedIntervalTimestamp;

        uint32 timeElapseSinceLastCall = Time.blockTs() - startPoint;

        if (lastUpdatedIntervalTimestamp == 0 || timeElapseSinceLastCall > INTERVAL_TIME) {
            (_lastInterval, _amountAllocated, _missedIntervals) = _calculateIntervals(timeElapseSinceLastCall);
            _lastIntervalStartTimestamp = startPoint;
            _missedIntervals += timeElapseSinceLastCall > INTERVAL_TIME && lastUpdatedIntervalTimestamp != 0 ? 1 : 0;
            updated = true;
        }
    }
}
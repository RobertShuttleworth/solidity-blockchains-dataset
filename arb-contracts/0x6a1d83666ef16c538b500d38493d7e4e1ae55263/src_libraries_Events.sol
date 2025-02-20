// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import { IPearBase } from "./src_interfaces_IPearBase.sol";
import { IPlatformLogic } from "./src_interfaces_IPlatformLogic.sol";
import { EventUtils } from "./src_libraries_EventUtils.sol";

library Events {
    event TokensWithdrawn(
        address indexed token, address indexed to, uint256 indexed amount
    );
    event EthWithdrawn(address indexed to, uint256 indexed amount);
    event PositionOpened(
        address indexed owner,
        address indexed adapter,
        bytes32 orderKey,
        bool isLong,
        bool isETHCollateral
    );
    event PositionClosed(
        address indexed owner,
        address indexed adapter,
        bytes32 orderKey,
        bool isLong
    );

    event PositionStatusSet(
        address indexed adapter, bool isLong, IPearBase.PositionStatus status
    );

    event CreateIncreasePosition(
        address indexed owner,
        address indexed adapter,
        uint256 amountIn,
        bytes32 orderKey,
        bool isLong,
        bool isETHCollateral
    );
    event CreateDecreasePosition(
        address indexed owner,
        address indexed adapter,
        uint256 amountOut,
        bytes32 orderKey,
        bool isLong
    );

    // orderKey
    event GmxCallback(
        address indexed adapter,
        bytes32 key,
        bool isExecuted,
        bool isIncrease,
        IPearBase.ExecutionState long,
        IPearBase.ExecutionState short
    );

    event ExecutionFeeRefunded(
        address indexed adapter, bytes32 key, uint256 amount
    );

    event PostionFailedTokenTransfer(
        address indexed refree,
        address indexed adapter,
        bool isLong,
        uint256 amount
    );

    event SplitBetweenStakersAndTreasuryFailed(
        address indexed refree,
        address indexed adapter,
        bool isLong,
        uint256 amount
    );

    event GmxOrderCallbackAtLiquidation(
        address indexed adapter, bytes32 key, bool isLong
    );

    event PlatformLogicsFactoryChanged(
        address indexed factory, bool indexed newState
    );

    event PlatformLogicChanged(
        IPlatformLogic oldAddress, IPlatformLogic newAddress
    );

    event ComptrollerChanged(address oldComptroller, address newComptroller);

    event AllowedTokenSet(IERC20 token, bool allowed);

    event EventLog(
        address msgSender,
        string indexed eventName,
        bytes32 indexed key,
        EventUtils.EventLogData eventData
    );

    ////////////////////////////////////////////////////
    ///////////// PearStaker events ////////////////////
    ////////////////////////////////////////////////////
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 exitFee);
    event StakingReward(address indexed user, uint256 stakingRewards);
    event CompoundStakingReward(
        address indexed user,
        uint256 rewardsInEth,
        uint256 stakeAmount,
        uint256 exitFeeReward
    );
    event ExitFeeReward(address indexed user, uint256 exitFeeCollected);
    event DepositStakerFee(uint256 feeAmount, uint256 feeAmountEarnedPerToken);
    event FeeWithdrawn(uint256 amount);
    event TokenWithdrawn(uint256 amount);

    ////////////////////////////////////////////////////
    ///////////// FeeRebateManager events ////////////////////
    ////////////////////////////////////////////////////
    event RebateTierSet(
        uint256 tier, uint256 monthlyVolumeThreshold, uint256 rebatePercentage
    );
    event DiscountTierSet(
        uint256 tier, uint256 stakedAmountThreshold, uint256 discountPercentage
    );
    event Withdraw(uint256 amount);
    event RebateClaimed(address indexed user, uint256 monthId, uint256 rebate);
    event UpdateTradeDetails(address indexed user, uint256 volume, uint256 fee);
    event FeeRebateEnabledSet(bool isFeeRebateEnabled);
    event FeeRebateManagerNotUpdated();

    /// @notice Emitted when a new vesting plan is created
    /// @param planId The ID of the newly created vesting plan
    /// @param recipient The address of the recipient of the vested tokens
    /// @param amount The total amount of tokens to be vested
    /// @param start The timestamp when the vesting begins
    /// @param cliff The timestamp before which no tokens can be claimed
    /// @param end The timestamp when all tokens will be fully vested
    event VestingPlanCreated(
        uint256 indexed planId,
        address indexed recipient,
        uint256 amount,
        uint32 start,
        uint32 cliff,
        uint32 end
    );

    /// @notice Emitted when tokens are claimed from a vesting plan
    /// @param planId The ID of the vesting plan
    /// @param recipient The address of the recipient who claimed the tokens
    /// @param amount The amount of tokens claimed
    event VestingClaimed(
        uint256 indexed planId, address indexed recipient, uint256 amount
    );

    event VestingPlanUpdated(
        uint256 indexed planId, uint256 newAmount, uint32 newEnd
    );

    event VestingPlanCancelled(
        uint256 indexed planId,
        address indexed recipient,
        uint256 unclaimedAmount
    );

    event VestingRecipientChanged(uint256 indexed planId, address newRecipient);
}
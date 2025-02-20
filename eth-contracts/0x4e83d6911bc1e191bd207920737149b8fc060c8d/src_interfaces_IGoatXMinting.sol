// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IGoatXMinting {
    /// @notice Structure representing a liquidity pool configuration.
    struct LPPools {
        LP goatXTitanX;
    }

    /// @notice Structure representing a deposit made by a user.
    struct Deposit {
        uint32 depositedAt;
        uint216 titanXAmount;
        uint8 cycle;
    }

    /// @notice Structure representing a liquidity pool (LP) position.
    struct LP {
        bool hasLP;
        uint240 tokenId;
        bool isGoatXToken0;
    }

    /**
     * @notice Emitted when a user claims their minted GoatX tokens.
     * @param user The address of the user who claimed tokens.
     * @param amount The amount of GoatX tokens claimed.
     * @param _id The  ID associated with the claim.
     */
    event ClaimExecuted(address indexed user, uint256 amount, uint96 _id);

    /**
     * @notice Emitted when a user deposits.
     * @param user The address of the user who deposited tokens.
     * @param amount The amount of GOATX tokens to received.
     * @param id The  ID associated with the deposited.
     */
    event DepositExecuted(address indexed user, uint256 amount, uint96 id);

    /// @notice Error thrown when an attempt to add liquidity is made more than once.
    error LiquidityAlreadyAdded();

    /// @notice Error thrown when there is insufficient TitanX balance to add liquidity.
    error NotEnoughTitanXForLiquidity();

    /// @notice Error thrown if the deposit is made before the start of minting.
    error NotStartedYet();

    /// @notice Error thrown when the deposit exceeds the allowed cycle cap.
    error ExceedingCycleCap();

    /// @notice Error thrown when a deposit is made after the current cycle has ended.
    error CycleIsOver();

    /// @notice Error thrown when a user attempts to claim before their deposit matures.
    error DepositNotMatureYet();

    /// @notice Error thrown when a user attempts to claim an amount of 0.
    error NothingToClaim();

    /**
     * @notice Updates the liquidity pool (LP) slippage percentage.
     * @dev Can only be called by authorized roles.
     * @param _newSlippage The new LP slippage percentage in WAD format (1e18 = 100%).
     */
    function changeLpSlippage(uint64 _newSlippage) external;

    /**
     * @notice Adds the initial liquidity to the GoatX-Inferno and GoatX-TitanX pools.
     * @dev Can only be called by the contract owner.
     * @param _deadline The timestamp before which liquidity addition must be completed.
     */
    function addInitialLiquidity(uint32 _deadline) external;

    /**
     * @notice Allows users to deposit TitanX tokens to mint GoatX tokens in the current cycle.
     * @param _amount The amount of TitanX tokens to deposit.
     */
    function deposit(uint256 _amount) external;

    /**
     * @notice Allows users to claim their minted GoatX tokens after the deposit matures.
     * @param _id The cycle ID associated with the claim.
     */
    function claim(uint96 _id) external;

    /**
     * @notice Allows users to claim multiple cycles in one transaction.
     * @param _cycles The cycle IDs associated with the claims.
     */
    function batchClaim(uint96[] calldata _cycles) external;

    /**
     * @notice Calculates the amount of claimable GoatX tokens for a given user and cycle.
     * @param _user The address of the user.
     * @param _cycle The cycle ID for which the claimable amount is calculated.
     * @return claimable The amount of GoatX tokens claimable by the user for the specified cycle.
     */
    function claimableAmount(address _user, uint96 _cycle) external view returns (uint256 claimable);

    /**
     * @notice Retrieves the GoatX minting ratio for a specific cycle.
     * @dev The ratio decreases slightly with each cycle to incentivize early deposits.
     * @param cycleId The ID of the minting cycle.
     * @return ratio The GoatX to TitanX minting ratio for the specified cycle.
     */
    function getRatioForCycle(uint32 cycleId) external pure returns (uint256 ratio);

    /**
     * @notice Collects fees acumulated from the V3 positions
     */
    function collectFees() external returns (uint256 goatXAmountTX, uint256 titanXAmount);

    /**
     * @notice Returns the current mint cycle details, including the cycle number and start and end times.
     * @return currentCycle The ID of the current mint cycle.
     * @return startsAt The start timestamp of the current cycle.
     * @return endsAt The end timestamp of the current cycle.
     */
    function getCurrentMintCycle() external view returns (uint8 currentCycle, uint32 startsAt, uint32 endsAt);

    /* ========== STATE VARIABLES ========== */

    /// @notice Total GoatX tokens claimed by users across all cycles.
    function totalGoatXClaimed() external view returns (uint256);

    /// @notice Total GoatX tokens minted across all cycles.
    function totalGoatXMinted() external view returns (uint256);

    /// @notice Returns the slippage percentage used in liquidity pool transactions.
    function lpSlippage() external view returns (uint64);

    /// @notice Returns the total TitanX tokens deposited in a specific cycle.
    function titanXPerCycle(uint8 cycle) external view returns (uint256);

    /// @notice Returns deposit details for a specific user and cycle.
    function deposits(address user, uint96 depositId)
        external
        view
        returns (uint32 depositedAt, uint216 titanXAmount, uint8 _cycle);
}
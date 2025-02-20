// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

/// @title IPlatformLogic Interface
/// @notice Interface for defining the core logic and rules for trading
/// operations.
interface IPlatformLogic {
    /*//////////////////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event BackendVerifierChanged(
        address oldBackendVerifier, address newBackendVerifier
    );

    event ManagePositionFeeChanged(
        uint256 oldManagePositionFee, uint256 newManagePositionFee
    );
    event PlatformFeeChanged(uint256 oldPlatformFee, uint256 newPlatformFee);

    event MintFeeChanged(uint256 oldMintFee, uint256 newMintFee);

    event RefereeDiscountChanged(
        uint256 oldRefereeDiscount, uint256 newRefereeDiscount
    );

    event ReferrerFeeChanged(
        uint256 oldReferrerFeeChanged, uint256 newReferrerFeeChanged
    );

    event PearTreasuryChanged(address oldTreasury, address newTreasury);

    event PearStakingContractChanged(
        address oldPearStakingContract, address newPearStakingContract
    );

    event TreasuryFeeSplitChanged(
        uint256 oldTreasuryFee, uint256 newTreasuryFee
    );

    event ReferralCodeAdded(address indexed referrer, bytes32 code);

    event ReferralCodeEdited(
        address indexed referrer, bytes32 code, address admin
    );

    event Referred(
        address indexed referrer,
        address indexed referee,
        address indexed adapter,
        uint256 amount
    );

    event RefereeAdded(address indexed referee, bytes32 code);
    event RefereeEdited(address indexed referee, bytes32 code, address admin);

    event FactorySet(address factory, bool state);

    event PendingTokenWithdrawal(address referrer, uint256 amount);

    event PendingEthWithdrawal(address referrer, uint256 amount);

    event TokenWithdrawal(address withdrawer, uint256 amount);

    event EthWithdrawal(address withdrawer, uint256 amount);

    event FeesPaid(
        address indexed user,
        uint256 indexed feeAmount,
        uint256 indexed grossAmountAfterFee
    );

    event FeesPaidToStakingContract(
        address indexed stakingContract, uint256 indexed feeAmount
    );
    event FeesPaidToPearTreasury(
        address indexed pearTreasury, uint256 indexed feeAmount
    );

    event SetRefereeFeeAmount(
        address indexed positionHolder,
        address indexed adapterAddress,
        uint256 indexed feeAmount,
        bool isLong
    );

    event SetPendingReferrerFeeAmount(
        address adapter, address referrer, uint256 amount
    );

    event ArbRewardsFeeSplitChanged(
        uint256 oldArbRewardsFeeSplit, uint256 newArbRewardsFeeSplit
    );

    event PlatformLogic_AddedRewards(
        address indexed user, uint256 indexed amount
    );

    event FeesWithdrawn(uint256 amount);

    /*//////////////////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    struct ReferralCode {
        /// @notice address of the person wanting to create a referral code
        address referrer;
        /// @notice the bytes32 version of a referral code - converted by the
        /// backend
        bytes32 referralCode;
        /// @notice the EIP-712 signature of all other fields in the
        /// ReferralCode struct. For a referralCode to be valid, it must be
        /// signed by the backendVerifier
        bytes signature;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////////////////*/
    /// @notice Sets the arb rewards is active or not.
    function setGmxArbRewardActive(bool _isArbRewardActive) external;

    /// @notice Sets the arb rewards is active or not.
    function setVertexArbRewardActive(bool _isArbRewardActive) external;

    /// @notice Sets the arb rewards is active or not.
    function setSymmArbRewardActive(bool _isArbRewardActive) external;

    /// @notice Sets a new backend verifier address.
    /// @param _newBackendVerifier The new address to be used as the backend
    /// verifier.
    function setBackendVerifierAddress(address _newBackendVerifier) external;

    /// @notice Sets the discount percentage for referees.
    /// @param _refereeDiscount The new discount percentage for referees.
    function setRefereeDiscount(uint256 _refereeDiscount) external;

    /// @notice Sets the referral fee percentage.
    /// @param _referrerFee The new referral fee percentage.
    function setReferrerFee(uint256 _referrerFee) external;

    /// @notice Sets the platform fee percentage.
    /// @param _platformFee The new platform fee percentage.
    function setPlatformFee(uint256 _platformFee) external;

    /// @notice Sets the fee split percentage that goes to the treasury.
    /// @param _treasuryFeeSplit The new treasury fee split percentage.
    function setTreasuryFeeSplit(uint256 _treasuryFeeSplit) external;

    /// @notice Sets the fee split percentage that goes to arb for platforms
    /// rewards.
    function setGmxArbRewardsFeeSplit(uint256 _arbRewardsFeeSplit) external;

    /// @notice Sets the fee split percentage that goes to arb for platforms
    /// rewards.
    function setVertexArbRewardsFeeSplit(uint256 _arbRewardsFeeSplit)
        external;

    /// @notice Sets the fee split percentage that goes to arb for platforms
    /// rewards.
    function setSymmArbRewardsFeeSplit(uint256 _arbRewardsFeeSplit) external;

    /// @notice Sets a new Pear Treasury address.
    /// @param _newTreasury The new address for the Pear Treasury.
    function setPearTreasury(address payable _newTreasury) external;

    /// @notice Converts USDC amounts to ETH
    /// @param amount the usdc amount to be converted
    function convertFeeToEth(uint256 amount) external returns (uint256);

    /// @notice Sets a new Pear Staking Contract address.
    /// @param _newStakingContract The new address for the Pear Staking
    /// Contract.
    function setPearStakingContract(address payable _newStakingContract)
        external;

    /// @notice Adds or removes a factory address.
    /// @param _factory The factory address to be added or removed.
    /// @param _state The state to set for the factory address (true for add,
    /// false for remove).
    function setFactory(address _factory, bool _state) external;

    /// @notice Sets the mint fee for a specific functionality in the platform.
    /// @param _mintFee The new mint fee.
    function setMintPositionFee(uint256 _mintFee) external;

    /*//////////////////////////////////////////////////////////////////////////
                                EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Creates a new referral code.
    /// @param _referralCode The referral code data to be created.
    /// @return A boolean indicating success of the operation.
    function createReferralCode(ReferralCode memory _referralCode)
        external
        returns (bool);

    /// @notice Associates a referee with a referral code.
    /// @param _referralCode The referral code to associate the referee with.
    /// @param _referee The address of the referee being associated.
    /// @return A boolean indicating success of the operation.
    function addReferee(
        bytes32 _referralCode,
        address _referee
    )
        external
        returns (bool);

    /// @notice Associates a referee with a referral code.
    /// @notice Can only be called by Gmx Factory
    /// @param _referralCode The referral code to associate the referee with.
    /// @param _referee The address of the referee being associated.
    /// @return A boolean indicating success of the operation.
    function addRefereeFromFactory(
        bytes32 _referralCode,
        address _referee
    )
        external
        returns (bool);

    /// @notice Edits the referral code of a referrer.
    /// @param _referrer The address of the referrer whose code is being edited.
    /// @param _referralCode The new referral code to be associated with the
    /// referrer.
    function editReferralCode(
        address _referrer,
        bytes32 _referralCode
    )
        external;

    function getPlatformFeeOfOrder(
        address referee,
        uint256 grossAmount
    )
        external
        view
        returns (uint256);

    /// @notice Applies platform fee logic for Ethereum Vertex.
    function applyPlatformFeeEthVertex(
        address _referee,
        uint256 _feeAmountAfterDiscountAndWithdrawal,
        uint256 _feeAmountAfterDiscount,
        uint256 _referrerWithdrawal,
        bool _isReferralProgramApplied
    )
        external
        payable;

    /// @notice Applies mint fee logic for ETH GMX.
    function applyMintFeeEthGmx(address _referee) external payable;

    /// @notice Applies platform fee logic for ETH GMX.
    /// @param adapter The address of the adapter contract for order
    /// @param _referee The address of the user being charged the fee.
    /// @param _grossAmount The total transaction amount before fees.
    /// @param _factory The address of the factory implementing the logic.
    /// @return feeAmount The amount of fee to be applied.
    /// @return referrerWithdrawal The amount of fee for referrer
    function applyPlatformFeeETHGmx(
        address adapter,
        address _referee,
        uint256 _grossAmount,
        address _factory
    )
        external
        returns (uint256 feeAmount, uint256 referrerWithdrawal);

    /// @notice Checks the amount of token fees pending withdrawal by a
    /// referrer.
    /// @param _referrer The address of the referrer.
    /// @return The amount of fees pending withdrawal.
    function checkPendingTokenWithdrawals(
        address _referrer,
        IERC20 _token
    )
        external
        view
        returns (uint256);

    /// @notice Allows a user to withdraw their accumulated token fees.
    /// @param _token The ERC20 token address for which the fees are withdrawn.
    function withdrawTokenFees(IERC20 _token) external;

    /// @notice Allows a user to withdraw their accumulated eth fees from
    /// referral logic.
    function withdrawEthFees() external;

    /// @notice Calculates fees based on the provided amount and basis points.
    /// @param _amount The amount on which the fee is to be calculated.
    /// @param _bps Basis points used to calculate the fee.
    /// @return The calculated fee amount.
    function calculateFees(
        uint256 _amount,
        uint256 _bps
    )
        external
        pure
        returns (uint256);

    /// @notice Edits the referral code of referred users.
    /// @param _referrer The address of the referrer whose referred users' code
    /// is being edited.
    /// @param _referralCode The new referral code to be associated with the
    /// referred users.
    function editReferredUsers(
        address _referrer,
        bytes32 _referralCode
    )
        external;

    /// @notice Splits fees between stakers and the treasure.
    /// @param _referee The address of the user involved in the transaction.
    /// @param _adapterAddress The address of the adapter involved in the
    /// transaction.
    /// @param _isLong isLong
    /// @param _amount The amount of fees to be split.
    function splitBetweenStakersAndTreasuryEth(
        address _referee,
        address _adapterAddress,
        bool _isLong,
        uint256 _amount
    )
        external;

    /// @notice Adds token fees for withdrawal by a referrer.
    /// @param _referrer The address of the referrer.
    /// @param _amount The amount of fees to be added for withdrawal.
    /// @param _token The ERC20 token address for which the fees are added.
    function addTokenFeesForWithdrawal(
        address _referrer,
        uint256 _amount,
        IERC20 _token
    )
        external;

    /// @notice function to calculate the platform fee for a given user on
    /// Vertex's side
    function calculatePlatformFeeEthVertex(
        address _referee,
        uint256 _grossAmount
    )
        external
        returns (
            uint256 _feeAmountAfterDiscountAndWithdrawal,
            uint256 _feeAmountAfterDiscount,
            uint256 _referrerWithdrawal,
            bool _isReferralProgramApplied
        );

    /// @notice Sets the fee amount for a referee.
    /// @param _referee The address of the referee.
    /// @param _adapterAddress The address of the adapter involved in the
    /// transaction.
    /// @param _isLong isLong
    /// @param _feeAmount The fee amount to be set.
    function setRefereeFeeAmount(
        address _referee,
        address _adapterAddress,
        bool _isLong,
        uint256 _feeAmount
    )
        external;

    /// @notice Handles token amount when a position fails.
    /// @param _referee The address of the user involved in the failed
    /// transaction.
    /// @param _adapterAddress The address of the adapter involved in the
    /// transaction.
    /// @param _isLong isLong
    /// @param _feeAmount The fee amount involved in the failed transaction.
    function handleTokenAmountWhenPositionHasFailed(
        address _referee,
        address _adapterAddress,
        bool _isLong,
        uint256 _feeAmount
    )
        external;

    function splitBetweenStakersAndTreasuryFromSymm() external payable;

    function applyPlatformFeeEthSymm(
        address _user,
        uint256 _feeAmount
    )
        external
        returns (uint256, uint256);

    /*//////////////////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice View function to get the address used to sign and validate
    /// referral codes.
    function backendVerifier() external view returns (address);

    /// @notice View function to get the platform fee as a percentage of the
    /// margin size.
    function platformFee() external view returns (uint256);

    /// @notice View function to get the mint fee in USDC used in a specific
    /// function.
    function mintFeeInUsdc() external view returns (uint256);

    /// @notice View function to get the percentage of the platform fee
    /// allocated to referrers.
    function referrerFee() external view returns (uint256);

    /// @notice View function to get the discount percentage for referees off
    /// the platform fee.
    function refereeDiscount() external view returns (uint256);

    /// @notice View function to get the portion of fees sent to the Pear
    /// Treasury.
    function treasuryFeeSplit() external view returns (uint256);

    /// @notice View function to get the arb rewards is active or not.
    function isGmxArbRewardActive() external view returns (bool);

    /// @notice View function to get the arb rewards is active or not.
    function isVertexArbRewardActive() external view returns (bool);

    /// @notice View function to get the arb rewards is active or not.
    function isSymmArbRewardActive() external view returns (bool);

    /// @notice View function to get the % of ArbRewardsFeeSplit - e.g 7000 -
    /// 70%
    function gmxArbRewardsFeeSplit() external view returns (uint256);

    /// @notice View function to get the % of ArbRewardsFeeSplit - e.g 7000 -
    /// 70%
    function vertexArbRewardsFeeSplit() external view returns (uint256);

    /// @notice View function to get the % of ArbRewardsFeeSplit - e.g 7000 -
    /// 70%
    function symmArbRewardsFeeSplit() external view returns (uint256);

    /// @notice View function to get the address of the Pear Treasury.
    function PearTreasury() external view returns (address payable);

    /// @notice View function to get the address of the Pear Staking Contract.
    function PearStakingContract() external view returns (address payable);

    /// @notice Retrieves the owner of a specific referral code.
    /// @param _referralCode The referral code to check.
    /// @return codeOwner The address of the owner of the referral code.
    function viewReferralCodeOwner(bytes32 _referralCode)
        external
        view
        returns (address codeOwner);

    /// @notice Retrieves the referral code associated with a referrer.
    /// @param _referrer The address of the referrer.
    /// @return code The referral code associated with the referrer.
    function viewReferrersCode(address _referrer)
        external
        view
        returns (bytes32 code);

    /// @notice Retrieves the referral code used by a referred user.
    /// @param _referredUser The address of the referred user.
    /// @return code The referral code used by the referred user.
    function viewReferredUser(address _referredUser)
        external
        view
        returns (bytes32 code);

    /// @notice Retrieves the fee amount set for a referee.
    /// @param _referee The address of the referee.
    /// @param _adapterAddress The address of the adapter involved in the
    /// transaction.
    /// @param _isLong isLong
    /// @return The fee amount set for the referee.
    function viewRefereeFeeAmount(
        address _referee,
        address _adapterAddress,
        bool _isLong
    )
        external
        view
        returns (uint256);

    /// @notice Checks who referred a given user.
    /// @param _referredUser The address of the user being checked.
    /// @return referrer The address of the referrer.
    function checkReferredUser(address _referredUser)
        external
        view
        returns (address referrer);

    /// @notice Retrieves the current chain ID.
    /// @return The chain ID of the current blockchain.
    function getChainID() external view returns (uint256);
}
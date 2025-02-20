

// SPDX-License-Identifier: MIT

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: hfjhjggh.sol


pragma solidity ^0.8.18;



interface BEP20 {
    function totalSupply() external view returns (uint theTotalSupply);
    function balanceOf(address _owner) external view returns (uint balance);
    function transfer(address _to, uint _value) external returns (bool success);
    function transferFrom(address _from, address _to, uint _value) external returns (bool success);
    function approve(address _spender, uint _value) external returns (bool success);
    function allowance(address _owner, address _spender) external view returns (uint remaining);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}


contract  RBC  is  Ownable, ReentrancyGuard {


   // Define public variables for contract settings and configurations
uint public MIN_DEPOSIT_USDT = 1; // Minimum deposit amount for token purchase or staking
uint public tokenprice = 1; // Price of the token
uint public tokenpriceDecimal = 1; // Number of decimals used in token price calculation
address public tokenaddress = 0xFe777Dc834BE3C4B77Bba89A2A13518a92c6770b; // Address of the token being managed
uint public ReferralFees = 20; // Percentage of referral rewards (e.g., 20%)
uint public stage; // Current staking stage
uint public locktime =  180 days; // Lock time for staking rewards
uint public  claimlimit = 100 *10**18 ;
uint public totalUsdt;
       uint public totaltoken;

// Define a struct to hold user details
struct User { 
    address referral; // Address of the referral for the user
    bool isRegistered; // Boolean to indicate if the user is registered
}

// Define a struct to hold information about staking
struct StackInfo {
    uint stage; // Staking stage
    uint stackCount; // Count of stakes made by the user
    uint stackAmount; // Amount of tokens staked
    uint stackTime; // Timestamp when the stake was made
    uint claimTime; // Timestamp when the stake can be claimed
    bool claimamount; // Indicates if the stake has been claimed
    uint currentclaimtime; // Timestamp of the most recent claim
    uint dailyroi; // Daily return on investment (ROI) in percentage
}

// Define a struct to track referral purchases
struct Referralbuy {
    uint256 amountbuy; // Amount of referral bonus for a purchase
    address frombuy; // Address of the buyer associated with the referral
}

// Define mappings to manage user and staking-related data
mapping(address => User) public users; // Maps user addresses to their User struct
mapping(address => bool) public isReferral; // Tracks whether an address is a valid referral
mapping(address => address) public referralAddresses; // Maps a user to their referral address
mapping(address => bool) public isReferralActive; // Tracks if a referral is active
mapping(address => uint256) public stakeCount; // Maps a user to their total stake count
mapping(address => StackInfo[]) public userStackInfo; // Maps a user to their array of StackInfo
mapping(address => uint) public referralRewards; // Maps a user to their referral rewards
mapping(address => mapping(uint => uint)) public claimedDays; // Tracks days already claimed for staking rewards
mapping(address => uint256) public referralClaimedRewards; // Tracks total claimed referral rewards per user
address[] public registeredUsers; // Array to store all registered user addresses
mapping(address => uint256) public totalGeneratedReferralShares; // Tracks total generated referral shares per user
mapping(address => bool) public hasShareClaim; // Tracks if a user has already claimed a share
mapping(address => Referralbuy[]) public referralHistorybuynow; // Tracks referral purchase history for each user


// Define events to log key actions in the contract
event Registered(address indexed user, address referral); // Event for user registration
event Staked(address indexed user, uint indexed stage, uint amount, uint dailyROI); // Event for staking
event ReferralRewardClaimed(address indexed referral, uint256 amount); // Event for claiming referral rewards

// Constructor function to initialize contract settings
constructor() Ownable(msg.sender) {
    // Set the deployer of the contract as an active referral
    isReferralActive[msg.sender] = true;

    // Assign the deployer as their own referral (default setup for the owner)
    referralAddresses[msg.sender] = msg.sender;

    // Mark the deployer as a valid referral
    isReferral[msg.sender] = true;
}


/**
 * @dev Registers a new user with a referral.
 * Ensures the user is not already registered and the referral address is valid.
 * @param _referral The address of the user who referred the new user.
 */
function register(address _referral) public nonReentrant {
    // Ensure the caller is not already registered
    require(!users[msg.sender].isRegistered, "User is already registered");

    // Ensure the referral address is not the same as the caller's address
    require(_referral != msg.sender, "Cannot refer yourself");

    // Ensure the referral address is a valid and active referral
    require(isReferral[_referral], "Referral address is not valid");

    // Create a new user record with the referral address and set registration status to true
    users[msg.sender] = User({
        referral: _referral,    // Assign the provided referral address
        isRegistered: true      // Mark the user as registered
    });

    // Add the new user to the list of registered users
    registeredUsers.push(msg.sender);

    // Emit an event to log the registration action
    emit Registered(msg.sender, _referral);
}





        /**
     * @dev Allows a user to buy tokens.
     * @param tokenAmount The amount of tokens to purchase.
     */

/**
 * @dev Allows a user to purchase tokens using another token (e.g., USDT).
 * Ensures the user is registered and the token amount meets the minimum requirement.
 * Includes referral rewards if applicable.
 * @param tokenAmount The amount of tokens to be used for the purchase.
 */
function BuyToken(uint tokenAmount) external nonReentrant {
    // Ensure the purchase amount meets the minimum deposit requirement
    require(tokenAmount >= MIN_DEPOSIT_USDT, "Minimum limit is 100");

    // Ensure the user is registered before allowing a purchase
    require(users[msg.sender].isRegistered, "User is not registered");

    // Convert the purchase amount to the correct token precision
    tokenAmount = tokenAmount * 10 ** 6;

    // Create instances of the token contracts for sending and receiving
    BEP20 sendToken = BEP20(tokenaddress); // The token being purchased
    BEP20 receiveToken = BEP20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F); // The token used for payment (e.g., USDT)

    // Calculate the equivalent value of tokens to be purchased based on the price
    uint tokenVal = (tokenAmount * 10 ** tokenpriceDecimal / tokenprice);

    // Ensure the contract has enough tokens to fulfill the purchase
    require(sendToken.balanceOf(address(this)) >= tokenVal, "Insufficient contract balance");

    // Ensure the user has sufficient balance of the payment token
    require(receiveToken.balanceOf(msg.sender) >= tokenAmount, "Insufficient user balance");

    // Transfer the payment tokens from the user to the contract
    receiveToken.transferFrom(msg.sender, address(this), tokenAmount);

    totalUsdt += tokenAmount;

    // Calculate the referral bonus as a percentage of the token value
    uint referralBonus = (tokenVal * ReferralFees) / 100;

    // Mark the user as a referral if they are not already one
    if (!isReferral[msg.sender]) {
        isReferral[msg.sender] = true;
    }

    // Retrieve the referral address for the user
    address referral = users[msg.sender].referral;

    // If the user has a valid referral, transfer the referral bonus
    if (referral != address(0)) {
        require(sendToken.transfer(referral, referralBonus *10**12), "Referral bonus transfer failed");
  
        referralHistorybuynow[referral].push(Referralbuy({
            amountbuy: referralBonus, // Bonus amount sent to the referral
            frombuy: msg.sender       // Address of the buyer
        }));
    }

    // Transfer the purchased tokens to the user
    require(sendToken.transfer(msg.sender, tokenVal*10**12), "Token transfer failed");

    // Record the referral bonus in the referral history
   
}




   function getReferralHistory(address user) external view returns (Referralbuy[] memory) {
        return referralHistorybuynow[user];
    }

/**
 * @dev Allows a registered user to stake tokens.
 * Ensures that the staking amount is within valid ranges and transfers the tokens to the contract.
 * @param tokenamount The amount of tokens to stake.
 */
function Stack(uint tokenamount) external nonReentrant { 
    // Ensure the user is registered before allowing staking
    require(users[msg.sender].isRegistered, "User is not registered");

    // Convert the token amount to the correct unit (e.g., adding decimals for token precision)
    tokenamount = tokenamount * 10 ** 18;

    uint dailyROI; // Placeholder for the daily ROI percentage
    uint assignedStage; // Variable to determine the staking stage based on the amount

    // Assign staking stage based on the amount of tokens staked
    if (tokenamount >= 100 * 10 ** 18 && tokenamount <= 10001 * 10 ** 18) {
        assignedStage = 0;
    } else if (tokenamount > 10001 * 10 ** 18 && tokenamount <= 20001 * 10 ** 18) {
        assignedStage = 1;
    } else if (tokenamount > 20001 * 10 ** 18 && tokenamount <= 50001 * 10 ** 18) {
        assignedStage = 2;
    } else if (tokenamount > 50001 * 10 ** 18 && tokenamount <= 100001 * 10 ** 18) {
        assignedStage = 3;
    } else if (tokenamount > 100001 * 10 ** 18 && tokenamount <= 500000 * 10 ** 18) {
        assignedStage = 4;
    } else {
        // Revert if the token amount does not fall within any valid range
        revert("Token amount does not fall within any valid stage range");
    }

    // Create an instance of the token using the contract's token address
    BEP20 receiveToken = BEP20(tokenaddress);

    // Ensure the user has sufficient balance to stake the specified token amount
    require(receiveToken.balanceOf(msg.sender) >= tokenamount, "Insufficient user balance");

    // Transfer the staked tokens from the user to the contract
    require(receiveToken.transferFrom(msg.sender, address(this), tokenamount), "Token transfer failed");

        totaltoken += tokenamount;
    // Record the staking details in the user's staking information
    userStackInfo[msg.sender].push(StackInfo({
        stage: assignedStage,             // Assigned staking stage
        stackCount: stakeCount[msg.sender] + 1, // Increment the staking count for the user
        stackAmount: tokenamount,         // Amount of tokens staked
        stackTime: block.timestamp,       // Timestamp when staking occurred
        claimTime: block.timestamp + locktime, // Timestamp when tokens can be claimed
        currentclaimtime: 0,              // Initialize current claim time to zero
        dailyroi: 365 days ,             // Set the daily ROI calculation period
        claimamount: false                // Mark staking as not yet claimed
    }));

    // Increment the user's total staking count
    stakeCount[msg.sender]++;

    // Emit an event to log the staking details
    emit Staked(msg.sender, assignedStage, tokenamount, dailyROI);
}

/**
 * @dev Allows a user to claim all their rewards, including staking and referral rewards.
 * Ensures rewards are calculated based on elapsed time and available balance in the contract.
 */

function claimAllRewards() external nonReentrant {
    uint totalRewardAmount = 0; // Total rewards from staking
    uint referralReward = 0;   // Total rewards from referrals

    // Calculate staking rewards
    for (uint i = 0; i < userStackInfo[msg.sender].length; i++) {
        StackInfo storage stack = userStackInfo[msg.sender][i];

        if (stack.stackAmount > 0) { // Only calculate for active stakes
            uint lastClaimedDay = claimedDays[msg.sender][i]; // Days already claimed
            uint elapsedTime;

            if (stack.currentclaimtime > 0) {
                // If a claim was made earlier, calculate rewards only up to that time
                elapsedTime = (stack.currentclaimtime - stack.stackTime) / 1 days;
            } else {
                // Calculate rewards up to the current time
                elapsedTime = (block.timestamp - stack.stackTime) / 1 days;
            }

            if (elapsedTime > 365 days) {
                elapsedTime = 365 days; // Cap rewards at 30 days
            }

            if (elapsedTime > lastClaimedDay) {
                // Calculate unclaimed rewards
                uint dailyROI = getDailyROI(stack.stage); // Get daily ROI for the staking stage
                uint unclaimedDays = elapsedTime - lastClaimedDay; // Days not yet claimed
                uint dailyReward = (stack.stackAmount * dailyROI) / 10000; // Calculate daily reward
                totalRewardAmount += (dailyReward * unclaimedDays); // Add unclaimed rewards to total

                claimedDays[msg.sender][i] = elapsedTime; // Update claimed days to current
            }
        }
    }

    // Calculate referral rewards if the caller has referrals
    if (isReferral[msg.sender]) {
        // Fetch referral information dynamically
        (uint totalGeneratedReferralShare, uint totalClaimedReferralShare, uint totalPendingReferralShare) = getReferralInfo(msg.sender);

        // Add only unclaimed referral rewards
        referralReward = totalPendingReferralShare;

        // Update the claimed rewards for referrals
        referralClaimedRewards[msg.sender] += referralReward;
    }

    // Ensure there are rewards to claim
    require(totalRewardAmount > 0 || referralReward > 0, "No rewards to claim");

    // Calculate the total claimable rewards
    uint totalClaimableRewards = totalRewardAmount + referralReward;

      // Add minimum rewards condition
    require(totalClaimableRewards >= claimlimit, "Total claimable rewards must be at least 100");


    // Create an instance of the token using the token address
    BEP20 receiveToken = BEP20(tokenaddress);

    // Ensure the contract has enough tokens to fulfill the reward
    require(receiveToken.balanceOf(address(this)) >= totalClaimableRewards, "Insufficient contract balance for rewards");

    // Transfer the rewards to the user
    require(receiveToken.transfer(msg.sender, totalClaimableRewards), "Total claimable rewards transfer failed");

    // Emit event for staking rewards claimed
    emit Staked(msg.sender, 0, totalRewardAmount, 0);

    // Emit event for referral rewards claimed
    emit ReferralRewardClaimed(msg.sender, referralReward);
}



function getDailyROI(uint stage) internal pure returns (uint) {
    if (stage == 0) return 100; // 1.0%
    if (stage == 1) return 150; // 1.5%
    if (stage == 2) return 200; // 2.0%
    if (stage == 3) return 300; // 3.0%
    if (stage == 4) return 500; // 5.0%
    revert("Invalid staking stage");
}


/**
 * @dev Allows a user to claim their staked amount after the lock period has expired.
 * Ensures that the claim is valid and the contract has sufficient balance.
 * @param stackIndex The index of the staking record to claim.
 */
function claimStack(uint stackIndex) external nonReentrant {
    // Ensure the provided stack index is valid (within the user's staking array)
    require(stackIndex < userStackInfo[msg.sender].length, "Invalid stack index");

    // Retrieve the staking record for the given index
    StackInfo storage stack = userStackInfo[msg.sender][stackIndex];

    // Ensure the staking amount has not already been claimed
    require(!stack.claimamount, "Amount already claimed");

    // Check that the staking amount is valid (non-zero and not previously claimed)
    require(stack.stackAmount > 0, "Already claimed or invalid stack");

    // Ensure the lock period for the staking has passed
    require(block.timestamp >= stack.claimTime, "Claim period not reached (180 days)");

    // Create an instance of the token contract using the token address
    BEP20 receiveToken = BEP20(tokenaddress);

    // Ensure the contract has sufficient tokens to fulfill the claim
    require(receiveToken.balanceOf(address(this)) >= stack.stackAmount, "Insufficient contract balance");

    // Transfer the staked amount back to the user
    require(receiveToken.transfer(msg.sender, stack.stackAmount), "Token transfer failed");

    // Mark the staking record as claimed
    stack.claimamount = true;

    // Record the timestamp of the claim
    stack.currentclaimtime = block.timestamp;
}


/**
 * @dev Updates the referral fee percentage for the contract.
 * Can only be called by the contract owner.
 * Ensures non-reentrancy during execution.
 * @param _Fees The new referral fee percentage to be set.
 * @return A boolean value indicating whether the operation was successful.
 */
function updateReferralFees(uint _Fees) external nonReentrant onlyOwner returns (bool) {
    // Update the referral fee percentage with the new value provided in `_Fees`
    ReferralFees = _Fees;

    // Return true to indicate the operation was successful
    return true;
}


   /**
 * @dev Allows the owner to withdraw tokens from the contract.
 * Ensures the recipient address is valid and the transfer is successful.
 * Can only be called by the contract owner.
 * @param tokenAddress The address of the token to withdraw.
 * @param to The address where the tokens should be sent.
 * @param amount The amount of tokens to withdraw.
 * @return A boolean value indicating whether the operation was successful.
 */
function withdraw(address tokenAddress, address to, uint amount) external onlyOwner nonReentrant returns (bool) {
    // Ensure the recipient address is not the zero address
    require(to != address(0), "Cannot send to zero address");

    // Create an instance of the token using the provided token address
    BEP20 _token = BEP20(tokenAddress);

    // Transfer the specified amount of tokens to the recipient
    require(_token.transfer(to, amount), "Token transfer failed");

    // Return true to indicate the operation was successful
    return true;
}


function getClaimInfo(address user, uint stackIndex) public view returns (
    uint stackIndex_,
    uint stage_,
    uint[] memory rewardAmounts, 
    uint[] memory claimTimes,    
    bool[] memory claimable
) {
    require(stackIndex < userStackInfo[user].length, "Invalid stack index");
    StackInfo memory stack = userStackInfo[user][stackIndex];
    require(stack.stackAmount > 0, "No stack available");

    uint elapsedDays;
    if (stack.claimamount) {
        elapsedDays = (stack.currentclaimtime - stack.stackTime) / 1 days;
    } else {
        elapsedDays = (block.timestamp - stack.stackTime) / 1 days;
    }
    if (elapsedDays > 365 days) {
        elapsedDays = 365 days; 
    }

    uint dailyROI = getDailyROI(stack.stage);
    uint[] memory rewardAmountsArray = new uint[](elapsedDays);
    uint[] memory claimTimesArray = new uint[](elapsedDays);
    bool[] memory claimableArray = new bool[](elapsedDays);

    uint lastClaimedDay = claimedDays[user][stackIndex];

    for (uint i = 0; i < elapsedDays; i++) {
        rewardAmountsArray[i] = (stack.stackAmount * dailyROI / 10000);
        claimTimesArray[i] = stack.stackTime + (i * 1 days);
        // claimableArray[i] = (i > lastClaimedDay);
         if (i == 0 && lastClaimedDay == 0) {
            claimableArray[i] = true; // Ensure the first day is claimable
        } else {
            claimableArray[i] = (i > lastClaimedDay);
        }
    }

    return (
        stackIndex,
        stack.stage,
        rewardAmountsArray,
        claimTimesArray,
        claimableArray
    );
}




function getReferralInfo(address referralAddress) public view returns (
    uint totalGeneratedReferralShare,
    uint totalClaimedReferralShare,
    uint totalPendingReferralShare
) {
    uint newlyGeneratedShare = 0;

    // Iterate through all registered users
    for (uint i = 0; i < registeredUsers.length; i++) {
        address referredUser = registeredUsers[i];
        if (users[referredUser].referral == referralAddress) {
            // Iterate through all stakes of referred user
            for (uint j = 0; j < userStackInfo[referredUser].length; j++) {
                StackInfo memory stack = userStackInfo[referredUser][j];

                uint elapsedDays;

                // Calculate elapsed days considering the current claim time
                if (stack.currentclaimtime > 0) {
                    elapsedDays = (stack.currentclaimtime - stack.stackTime) / 1 days;
                } else {
                    elapsedDays = (block.timestamp - stack.stackTime) / 1 days;
                }

                if (elapsedDays > 365 days) {
                    elapsedDays = 365 days; // Cap at 365 days
                }

                uint lastClaimedDay = claimedDays[referredUser][j];
                uint dailyROI = getDailyROI(stack.stage);
                uint maxdays =0 ;

                if (lastClaimedDay > 0)
                {maxdays=lastClaimedDay;}
                else {
                    maxdays = elapsedDays   ;
                }

                for (uint k = 0; k < maxdays; k++) {
                    uint dailyReward = (stack.stackAmount * dailyROI) / 10000;
                    newlyGeneratedShare += (dailyReward / 2); 
                }


            }
        }
    }

    // Ensure previously accumulated shares are not lost
    uint totalGeneratedShare = totalGeneratedReferralShares[referralAddress] + newlyGeneratedShare;

    // Retrieve the total claimed shares
    uint totalClaimedShare = referralClaimedRewards[referralAddress];

    // Calculate pending shares
    uint totalPendingShare = totalGeneratedShare > totalClaimedShare
        ? totalGeneratedShare - totalClaimedShare
        : 0;

    // Return all referral data
    return (totalGeneratedShare, totalClaimedShare, totalPendingShare);
}


// Set the token price
function UpdatePrice(uint _tokenprice, uint _tokenpriceDecimal) external onlyOwner nonReentrant {
    // Update the token price with the provided value
    tokenprice = _tokenprice;
    
    // Update the token price decimal value
    tokenpriceDecimal = _tokenpriceDecimal;
}




// /**
//  * @dev Allows a registered user to claim their share of tokens.
//  * Ensures that the user has not already claimed their share and that the contract has sufficient balance.
//  */
function Shareclaim() external nonReentrant {
    // Check if the user is registered
    require(users[msg.sender].isRegistered, "User is not registered");

    // Ensure the user has not already claimed their share
    require(!hasShareClaim[msg.sender], "You have already withdrawn your token");

    // Create an instance of the token using the token address
    BEP20 token = BEP20(tokenaddress);

    // Ensure the contract has at least 1 ether worth of tokens to fulfill the claim
    require(token.balanceOf(address(this)) >= 1 ether , "Insufficient contract balance");  

    // Mark the user's share claim as completed to prevent double-claiming
    hasShareClaim[msg.sender] = true;

    // Transfer 1 ether worth of tokens to the user
    require(token.transfer(msg.sender, 1 ether ) ,"Token transfer failed");
}



/**
 * @dev Allows a registered user to claim their share of tokens.
 * Ensures that the user has not already claimed their share and that the contract has sufficient balance.
 */



/**
 * @dev Updates the token address used by the contract.
 * Can only be called by the owner of the contract.
 * Ensures non-reentrancy during execution.
 * @param _add The new token address to be set.
 * @return A boolean value indicating whether the operation was successful.
 */
function updatetoken(address _add) public onlyOwner nonReentrant returns (bool) {
    // Update the token address with the provided address
    tokenaddress = _add;

    // Return true to indicate the operation was successful
    return true;
}


 /**
 * @dev Updates the lock time for staking.
 * Can only be called by the owner of the contract.
 * Ensures non-reentrancy during execution.
 * @param _time The new lock time (in seconds) to be set.
 * @return A boolean value indicating whether the operation was successful.
 */
function updatelocktime(uint _time) public nonReentrant onlyOwner returns (bool) {
    // Update the lock time with the new value provided in `_time`
    locktime = _time;

    // Return true to indicate the operation was successful
    return true;
}

/**
 * @notice Sets the claim limit for rewards.
 * @dev This function can only be called by the contract owner. 
 *      It allows the owner to set a minimum claim amount for rewards.
 * @param _amount The new claim limit to be set (in the smallest unit of the token).
 *      For example, if the token has 18 decimals, an input of 100 represents 100 * 10^18.
 */
function setclaimlimit(uint _amount) public nonReentrant onlyOwner {
    // Update the claim limit with the specified amount
    claimlimit = _amount;
}



/**
 * @dev Retrieves the referral purchase history for a given user.
 * @param user The address of the user whose referral purchase history is being retrieved.
 * @return amounts The array of amounts purchased in referrals.
 * @return fromAddresses The array of addresses from which purchases were made.
 */
function getReferralHistoryBuyNow(address user) public view returns (uint256[] memory amounts, address[] memory fromAddresses) {
    // Get the referral purchase history array for the given user
    Referralbuy[] memory history = referralHistorybuynow[user];

    // Initialize arrays to store the data
    uint256[] memory amountsArray = new uint256[](history.length);
    address[] memory fromAddressesArray = new address[](history.length);

    // Iterate over the history and populate the arrays
    for (uint i = 0; i < history.length; i++) {
        amountsArray[i] = history[i].amountbuy;
        fromAddressesArray[i] = history[i].frombuy;
    }

    // Return the populated arrays
    return (amountsArray, fromAddressesArray);
}





}
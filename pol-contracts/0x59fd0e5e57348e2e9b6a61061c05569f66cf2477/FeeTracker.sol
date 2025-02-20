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

// File: @openzeppelin/contracts/security/Pausable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: contracts/feeTracker2.sol


pragma solidity ^0.8.28;



contract FeeTracker is Ownable(msg.sender), Pausable {
    IERC20 public token;
    IERC20 public usdToken;
    ISwapRouter public swapRouter;
    IUniswapV3Pool public pool;
    uint32 public burnPercentDevBy1000=10;  //10 => 1%
    uint tokenPrice; //fixed token price with 18 decimals

    mapping (uint=>address) public updates;
    uint public lastUpdateId;

    struct vipPlan{
        uint usdAmount;
        uint expirePeriod;
    }
    mapping(uint8 => vipPlan) vipPlans;
    uint8 public vipPlanCount;

    struct FreezeInfo {
        uint8 vipId;
        uint256 amount;
        uint256 burnedAmount;
        uint256 unfreezeTime;
        uint256 referralCount;
        uint256 referralAmount;
    }
    mapping(address => FreezeInfo) userFreeze;

    mapping (address => address[]) userReferrals;
    struct UserInfo {
        address introducer;
        uint256 referralCount;
        uint256 referralAmountUsd;
        uint256 referralAmountToken;
    }
    mapping (address => UserInfo) userInfo;

    constructor(IERC20 _token, IERC20 _usdToken,ISwapRouter _swapRouter,uint32 _burnPercentDevBy1000,uint _tokenPrice) {
        
        //token Arbitrum: 0x0000000000000000000000000000000000000000
        //usdt Arbitrum: 0x0000000000000000000000000000000000000000
        //swaprourer Arbitrum: 0x0000000000000000000000000000000000000000
        
        //token Polygon: 0x0000000000000000000000000000000000000000
        //usdt Polygon: 0x0000000000000000000000000000000000000000
        //swapRouter Polygon:  0x0000000000000000000000000000000000000000
        
        //token Binance: 0x48ba0f556105C162D4e3da7f716FCEa509b75611
        //usdt Binance: 0x55d398326f99059fF775485246999027B3197955
        //swapRouter2 Binance: 0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2

        token = _token;
        usdToken = _usdToken;
        swapRouter = _swapRouter;
        updatePricePool(token,usdToken,swapRouter);

        burnPercentDevBy1000 = _burnPercentDevBy1000;
        tokenPrice = _tokenPrice;

        // setVipPlans(0,0,0);
        setVipPlans(1,2,60 minutes);
        setVipPlans(2,6,30 days);
        setVipPlans(3,10,30 days);
    }

    function setConfigs(IERC20 _token,IERC20 _usdToken,ISwapRouter _swapRouter,uint32 _burnPercentDevBy1000,uint _tokenPrice) external onlyOwner {
        token = _token;
        usdToken = _usdToken;
        swapRouter = _swapRouter;
        updatePricePool(token,usdToken,swapRouter);

        burnPercentDevBy1000 = _burnPercentDevBy1000;
        tokenPrice = _tokenPrice;
    }

    //used to sync with other chains
    function setVipPlans(uint8 _id,uint _usdAmount,uint _expirePeriod) public onlyOwner {
        require(_id>0,"id must be greater than 0");

        vipPlans[_id].usdAmount = _usdAmount;
        vipPlans[_id].expirePeriod = _expirePeriod;
        if(_id>vipPlanCount)
            vipPlanCount = _id;
    }

    function updatePricePool(IERC20 _token,IERC20 _usdToken,ISwapRouter _swapRouter) private {
        if(address(_swapRouter)==address(0)) return;
        
        IUniswapV3Factory factory = IUniswapV3Factory(_swapRouter.factory());
        address poolAddress = factory.getPool(address(_token), address(_usdToken), 3000);
        require(poolAddress != address(0), "Pool does not exist");
        pool = IUniswapV3Pool(poolAddress);
    }

    function getTokenPrice() public view returns (uint sqrtPriceX96) {
        if (tokenPrice > 0) return tokenPrice;
        (sqrtPriceX96, , , , , , ) = pool.slot0();
        return (sqrtPriceX96**2) * (1e18) / (2**192);
    }

    function freezeTokens(uint8 vipId,uint256 _vipAmount,address _reseller) external whenNotPaused{
        require(_vipAmount > 0, "Freeze amount must be greater than 0");
        require(vipPlans[vipId].usdAmount>0,"Invalid plan id");

        uint tokenUsdAmount = vipPlans[vipId].usdAmount;
        uint tokenAmount = (tokenUsdAmount * 1e18 * _vipAmount) / getTokenPrice();

        //update referral user info
        if(userInfo[msg.sender].introducer==address(0) && _reseller!=address(0) && _reseller!=msg.sender)
        {
            userInfo[msg.sender].introducer = _reseller;
            userInfo[_reseller].referralCount++;
            userReferrals[msg.sender].push(_reseller);
        }
        userInfo[_reseller].referralAmountUsd += tokenUsdAmount;
        userInfo[_reseller].referralAmountToken += tokenAmount;

        uint currentFrozenTokenAmount = userFreeze[msg.sender].amount;
        uint mustFreezeAmount;
        if(tokenAmount > currentFrozenTokenAmount)
        {
            mustFreezeAmount = tokenAmount - currentFrozenTokenAmount;
            token.transferFrom(msg.sender,address(this),mustFreezeAmount);
        }else
            mustFreezeAmount = 0;

        //burn freeze fe
        uint burnedAmount = tokenAmount*burnPercentDevBy1000/1000;
        // token.burn(burnedAmount);

        //update freeze details
        userFreeze[msg.sender].unfreezeTime = block.timestamp + vipPlans[vipId].expirePeriod*_vipAmount;
        userFreeze[msg.sender].amount = tokenAmount - burnedAmount;
        userFreeze[msg.sender].burnedAmount = burnedAmount;
        userFreeze[msg.sender].vipId = vipId;

        lastUpdateId++;
        updates[lastUpdateId] = msg.sender;
    }

    // Unfreeze tokens for the caller if the unfreeze time has passed
    function unfreezeTokens() external whenNotPaused {
        FreezeInfo storage info = userFreeze[msg.sender];
        require(info.amount > 0, "No frozen tokens");
        require(block.timestamp >= info.unfreezeTime, "Tokens are still frozen");

        // uint256 amount = info.amount;
        info.vipId = 0;
        info.amount = 0;
        info.unfreezeTime = 0;

        token.transfer(msg.sender, info.amount);
    }

    function setFreezeTokensByAdmin(
        address _userAddress,
        uint8 _vipId,
        uint256 _amount,
        uint _unfreezeTime,
        address _reseller,
        uint256 referralCount,
        uint256 referralAmountUsd,
        uint256 referralAmountToken
    ) external onlyOwner{
        userFreeze[_userAddress].unfreezeTime = _unfreezeTime;
        userFreeze[_userAddress].amount = _amount;
        userFreeze[_userAddress].vipId = _vipId;

        userInfo[_userAddress].introducer = _reseller;
        userInfo[_userAddress].referralCount = referralCount;
        userInfo[_userAddress].referralAmountUsd = referralAmountUsd;
        userInfo[_userAddress].referralAmountToken = referralAmountToken;
    }

    function getUserVipStatus(address _user) public view returns (uint8) // user Vip Id if not expired
    {
        if(userFreeze[_user].unfreezeTime<block.timestamp) 
            return 0;
        else
            return userFreeze[_user].vipId;
    }

    function getUserIntroducer(address _user) public view returns (address reseller)
    {
        reseller = userInfo[_user].introducer;
    }

    // Get the frozen amount and unfreeze time for a user
    function getUserInfo(address _user) external view returns (
        uint256 vipId, 
        uint256 amount,  
        uint256 burnedAmount, 
        uint256 unfreezeTime,
        address reseller,
        uint256 referralCount,
        uint256 referralAmountUsd,
        uint256 referralAmountToken) 
    {
        vipId = userFreeze[_user].vipId;
        amount = userFreeze[_user].amount;
        burnedAmount = userFreeze[_user].burnedAmount;
        unfreezeTime = userFreeze[_user].unfreezeTime;
        reseller = userInfo[_user].introducer;
        referralCount = userInfo[_user].referralCount;
        referralAmountUsd = userInfo[_user].referralAmountUsd;
        referralAmountToken = userInfo[_user].referralAmountToken;
    }

    function getUserReferrals(address _address, uint256 _from) public view returns (address[] memory) {
        uint256 length = userReferrals[_address].length;

        // If the starting index is out of range, return an empty array
        if (_from >= length) {
            return new address[](0);
        }

        // Calculate the end index (exclusive), limited to 10 items
        uint256 to = _from + 10;
        if (to > length) {
            to = length; 
        }

        // Create a new array to hold the sliced data
        address[] memory slice = new address[](to - _from);

        // Populate the sliced array
        for (uint256 i = _from; i < to; i++) {
            slice[i - _from] = userReferrals[_address][i];
        }

        return slice;
    }

    //get all Vip Plans
    function getAllVipPlans() external view returns (vipPlan[] memory) {
        vipPlan[] memory plans = new vipPlan[](vipPlanCount+1);

        for (uint8 i = 0; i <= vipPlanCount; i++) {
            plans[i] = vipPlans[i];
        }
        return plans;
    }

    // Emergency withdraw ETH from the contract
    function emergencyWithdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");

        payable(owner()).transfer(balance);
    }

    // Emergency withdraw any token from the contract
    function emergencyWithdrawToken(IERC20 _token) external onlyOwner {
        uint256 balance = _token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");

        _token.transfer(owner(), balance);
    }

    // Pause all freezing/unfreezing actions
    function pause() external onlyOwner {
        _pause();
    }

    // Resume all freezing/unfreezing actions
    function unpause() external onlyOwner {
        _unpause();
    }

    function getTokenInfo(address tokenAddress) public view returns (string memory name, string memory symbol, uint8 decimals) {
        IERC20 tokenMetadata1 = IERC20(tokenAddress);
        name = tokenMetadata1.name();
        symbol = tokenMetadata1.symbol();
        decimals = tokenMetadata1.decimals();
    }

    // Receive ETH
    receive() external payable {}
}



interface IERC20 {
    // function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    // function allowance(address owner, address spender) external view returns (uint256);
    // function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function burn(uint256 amount) external returns (bool);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

interface IUniswapV3Factory {
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);
}
interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}
interface ISwapRouter is IUniswapV3SwapCallback {
    function factory() external view returns (address);
}
interface IUniswapV3Pool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24 tick,
        uint16 observationIndex,
        uint16 observationCardinality,
        uint16 observationCardinalityNext,
        uint8 feeProtocol,
        bool unlocked
    );
}
// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



interface tokenInterface
 {
    function transfer(address _to, uint256 _amount) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);
    function balanceOf(address _user) external view returns(uint);
 }


contract Harvest_Global {
    struct User {
        uint regId;
        uint planId;
        address referrer;
        uint registrationTime;
        uint directReferral;
        uint directReferralsGlobal;
        uint totalDownline;
        uint totalBusiness;
        bool plan2Joined;
        bool[] poolEligibility;
    }

    struct Pool {
        uint requiredGlobalTeam;
        uint requiredCommunityDonation;
        uint income;
        uint directBonus;
        uint closingPeriod;
        uint requiredDirectTeam;
    }

    mapping(address => User) public users;
    mapping(uint => Pool) public pools;
    mapping(uint => address) public regIdToAddress;
    mapping(uint => address) public planIdToAddress;
    mapping(address => bool[12]) public poolSharePaid;
    mapping(address => mapping(uint => uint)) public waitEnd;

    //address public tokenAddress;

    address public smartMartixAddress;
    uint public lastRegId;
    uint public lastPlanId;
    uint public totalCommunityPool;
    bool public allowPackage;
    
    address public POLToken;
    address public MHTToken;

    uint constant multival = 1e18;
    uint public constant REGISTRATION_FEE = 5 * multival; // 5 ADA
    uint public constant DIRECT_INCOME = 2 * multival; // 2 ADA
    uint public constant swap_INCOME = 1 * multival; // 2 ADA
    uint public constant POOL_DISTRIBUTION = 3 * multival; // 3 ADA
    uint public constant PLAN2_FEE = 31 * multival; // 30 ADA

    uint public per = 9;
    uint public setlevel = 3;
    uint public eligibleper = 9;
/*
    struct autoPool
    {
        uint userID;
        uint autoPoolParent;
    }

    autoPool[] public autoPoolLevel;  // users lavel records under auto pool scheme
    mapping(address => uint) public autoPoolIndex; //to find index of user inside auto pool
    uint public nextMemberFillIndex;  // which auto pool index is in top of queue to fill in 
    uint public nextMemberFillBox;   // 3 downline to each, so which downline need to fill in
*/
    address public owner;
    bool public harvsto;
    bool public smartMtrx;
    event Registration(address indexed user, address indexed referrer, uint userId, uint referrerId);
    event Plan2Joined(address indexed user,uint globalId, uint joinTime);
    // income type
    // 0 = direct
    // 1 = level
    // 2 = plan2 referrral
    // 3 = pool income
    // 4 = pool referral
    event payOutEv0(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv1(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv2(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv3(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv4(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);

    IUniswapV2Router02 public uniswapRouter;

    constructor(address _MHTToken) {

        lastRegId++;
        lastPlanId++;
        MHTToken = _MHTToken;
        owner = msg.sender;
        //tokenAddress = _tokenAddress;
        //smartMartixAddress = _smartMartixAddress;
        // Initialize the first user (owner)
        User memory usr;
        usr.regId = lastRegId;
        usr.planId = lastPlanId;
        usr.referrer = msg.sender;
        usr.registrationTime = block.timestamp;
        users[msg.sender] = usr;
        regIdToAddress[1] = msg.sender;
        planIdToAddress[1] = msg.sender;

    }

    function callHarvestoReg(bool _harvsto) public {
        require(msg.sender == owner, "invalid caller");
        harvsto = _harvsto;
    }

    function callSMReg(bool _smartMtrx) public {
        require(msg.sender == owner, "invalid caller");
        smartMtrx = _smartMtrx;
    }

    function initialize(address _routerpool) public {
        require(msg.sender == owner, "invalid caller");
        pools[1] = Pool(20, 0, 15 * multival, 10, 300, 1);
        pools[2] = Pool(60, 0, 25 * multival, 10, 600, 2);
        pools[3] = Pool(160, 0, 50 * multival, 10, 1800, 4);
        pools[4] = Pool(360, 0, 80 * multival, 10, 3600, 7);
        pools[5] = Pool(1160, 75, 150 * multival, 10, 16 days, 10);
        pools[6] = Pool(2660, 100, 200 * multival, 10, 18 days, 13);
        pools[7] = Pool(5660, 150, 300 * multival, 10, 20 days, 15);
        pools[8] = Pool(10660, 250, 500 * multival, 10, 22 days, 17);
        pools[9] = Pool(18660, 350, 700 * multival, 10, 25 days, 20);
        pools[10] = Pool(27660, 750, 1500 * multival, 10, 26 days, 24);
        pools[11] = Pool(37660, 1200, 2400 * multival, 10, 27 days, 28);
        // pools[12] = Pool(49660, 2000, 4000 * multival, 10, 28 days, 17);
        // pools[13] = Pool(64660, 3000, 6000 * multival, 10, 29 days, 19);
        // pools[14] = Pool(82660, 4000, 8000 * multival, 10, 30 days, 21);
        // pools[15] = Pool(102660, 5000, 10000 * multival, 10, 31 days, 23);
        // pools[16] = Pool(124660, 8000, 16000 * multival, 10, 32 days, 25);
        // pools[17] = Pool(149660, 14000, 28000 * multival, 10, 33 days, 27);
        // pools[18] = Pool(179660, 25000, 50000 * multival, 10, 34 days, 29);
        // pools[19] = Pool(219660, 45000, 90000 * multival, 10, 35 days, 31);
        // pools[20] = Pool(269660, 80000, 160000 * multival, 10, 36 days, 33);
        // pools[21] = Pool(369660, 150000, 300000 * multival, 10, 37 days, 35);

          uniswapRouter = IUniswapV2Router02(_routerpool);
    }

    
    function getPriceFromUniswapV2(uint256 amountUsd)
        public
        view
        returns (uint256)
    {
        address[] memory paths = new address[](2);
        paths[0] = POLToken;
        paths[1] = MHTToken;
        uint256[] memory amounts = uniswapRouter.getAmountsOut(
            amountUsd,
            paths
        );
        return amounts[1];
    }

     function swapDAI(uint amount) internal {
        IERC20(POLToken).approve(address(uniswapRouter), amount);
        address[] memory paths = new address[](2);
        paths[0] = POLToken;
        paths[1] = MHTToken;
        uint256[] memory amounts = uniswapRouter.getAmountsOut(
            amount,
            paths
        );
        uniswapRouter.swapExactTokensForTokens(
            amount,
            amounts[1],
            paths,
            address(this),
            block.timestamp + 10
        );        
   }

    function swap(uint DAIAmount) external {
        require(msg.sender == owner, "invalid caller");
        uint256 amount = getPriceFromUniswapV2(DAIAmount);
        IERC20(POLToken).approve(address(uniswapRouter), DAIAmount);
        address[] memory paths = new address[](2);
        paths[0] = POLToken;
        paths[1] = MHTToken;
        uniswapRouter.swapExactTokensForTokens(
            DAIAmount,
            amount,
            paths,
            address(this),
            block.timestamp + 100
        );
    }

    function getPriceFromUniswapV2_MHT(uint256 amountUsd)
        public
        view
        returns (uint256)
    {
        address[] memory paths = new address[](2);
        paths[0] = MHTToken;
        paths[1] = POLToken;
        uint256[] memory amounts = uniswapRouter.getAmountsOut(
            amountUsd,
            paths
        );
        return amounts[1];
    }
    
    function setTokenAddress(address _tokenAddress, address _poladdress, address _uniROuter) public returns(bool) {
        require(msg.sender == owner, "Invalid Caller");
        MHTToken = _tokenAddress;
        POLToken = _poladdress;
        uniswapRouter = IUniswapV2Router02(_uniROuter);
        return true;
    }

    function setsmartMartixAddress(address _smartMartixAddress) public returns(bool) {
        require(msg.sender == owner, "Invalid Caller");
        smartMartixAddress = _smartMartixAddress;
        return true;
    }

    function changeOwner(address _newOwner) public  {
        require(msg.sender == owner, "Invalid caller");
        owner = _newOwner;
    }

    function allowPackageBuy() public returns (bool) {
        require(msg.sender == owner, "invalid caller");
        require(!allowPackage, "can't call twice");
        allowPackage = true;
        return true;
    }

    function setper(uint _amountper, uint _eligibleper, uint _level) public {
        require(msg.sender == owner, "Invalid caller");
        per = _amountper;
        eligibleper = _eligibleper;
        setlevel = _level;
    }

    function register(address referrerAddress, address _user) external payable {
        address msgsender = msg.sender;
        if(msg.sender == owner ) msgsender = _user;
        require(msg.value == REGISTRATION_FEE, "Invalid amount");
        //IERC20(tokenAddress).transferFrom(msg.sender,address(this), REGISTRATION_FEE);
        require(users[msgsender].regId == 0, "User already registered");
        require(users[referrerAddress].regId != 0, "Referrer does not exist");

        uint referrerId = users[referrerAddress].regId;
        lastRegId++;
        uint _userId = lastRegId;

        User memory usr;
        usr.regId = _userId;
        usr.referrer = referrerAddress;
        usr.registrationTime = block.timestamp;
        users[msgsender] = usr;

        users[referrerAddress].directReferral++;

        regIdToAddress[_userId] = msgsender;

        address ref = referrerAddress;
        for (uint i=0;i<11;i++)
        {
            bool breakIt;
            if(ref == owner) breakIt = true;
            users[ref].totalDownline++;
            ref = users[ref].referrer;
            if(breakIt) break;
        }
                 

        sendToken(referrerAddress,msgsender, DIRECT_INCOME,0,0);
        payLevelIncome(referrerAddress, msgsender);

        swapDAI(swap_INCOME);
        //if(smartMtrx)harvesto(smartMartixAddress).register(referrerAddress, msgsender);
        emit Registration(msgsender, referrerAddress, _userId, referrerId);
    }


   function payLevelIncome(address _user, address _msgsender) internal returns (bool)
    {        
        uint share = POOL_DISTRIBUTION / 3;
        
        address usr = users[_user].referrer;
        if(usr == address(0)) usr = payable(regIdToAddress[1]);
        for(uint i=0;i<2;i++)
        {
            if(i==0) sendToken(usr,_msgsender,share,1, i+1);
            else if(i==1) sendToken(usr,_msgsender,share,1, i+1);
            //else if(i==2) sendToken(usr,_msgsender,share,1, i+1);
            usr = users[usr].referrer;
            if(usr == address(0)) usr = payable(regIdToAddress[1]);
        }
        return true;
    }

    function joinGlobal(address _user) external payable {
        address msgsender = msg.sender;
        if(msg.sender == owner ) msgsender = _user;
        require(allowPackage, "wait for admin to start");
        require(users[msgsender].regId != 0, "User not registered in Plan 1");
        require(!users[msgsender].plan2Joined, "already bought plan 2");
        require(msg.value == PLAN2_FEE, "Invalid Amount");
        //IERC20(tokenAddress).transferFrom(msg.sender,address(this), PLAN2_FEE);

        lastPlanId++;
        users[msgsender].planId = lastPlanId;
        planIdToAddress[lastPlanId] = msgsender;
        User storage user = users[msgsender];
        users[msgsender].plan2Joined = true;

        address ref = users[msgsender].referrer;
        users[ref].directReferralsGlobal++;

        uint uplineShare = 10 * multival;
        distributePlan2ReferralIncome(msgsender, uplineShare);

        user.totalBusiness += PLAN2_FEE;

        emit Plan2Joined(msgsender,lastPlanId,block.timestamp);
    }

    function distributePlan2ReferralIncome(address user, uint uplineShare) private {
        address upline = users[user].referrer;
        for (uint i = 1; i <= 8; i++) {
            if (upline == address(0)) break;

            uint share;
            if (i == 1) share = (uplineShare * 30) / 100;
            else if (i == 2) share = (uplineShare * 15) / 100;
            else if (i == 8) share = (uplineShare * 5) / 100;
            else share = (uplineShare * 10) / 100;

            sendToken(upline,user,share,2,i);
            upline = users[upline].referrer;
        }
    }

    function sendToken(address _payTo,address _payFrom, uint _amount, uint _payType, uint level) internal {
        payable(_payTo).transfer(_amount);
        //IERC20(tokenAddress).transfer(_payTo,_amount);
        if (_payType == 0 ) emit payOutEv0(_payTo, _payFrom, _amount, _payType, level);
        else if (_payType == 1 ) emit payOutEv1(_payTo, _payFrom, _amount, _payType, level);
        else if (_payType == 2 ) emit payOutEv2(_payTo, _payFrom, _amount, _payType, level);
        else if (_payType == 3 ) emit payOutEv3(_payTo, _payFrom, _amount, _payType, level);
        else if (_payType == 4 ) emit payOutEv4(_payTo, _payFrom, _amount, _payType, level);
    }


    function getMyPoolIncome() public {
        uint _poolLevel;
        for (uint i=1;i<=11;i++)
        {
            if (!poolSharePaid[msg.sender][i]) {
                _poolLevel = i;
                break;
            }
        }
        if(_poolLevel == 0) revert("all pool paid");
        require(waitEnd[msg.sender][_poolLevel] > 0, "invalid wait");
        require(block.timestamp >= waitEnd[msg.sender][_poolLevel], "please wait more");
        distributePlan2PoolIncome(msg.sender, _poolLevel);
    }

    function markPoolStart(uint level) public {
        require(level >= 1 && level <= 11, "Invalid Level");
        require(isEligibleForPool(msg.sender,level), "not qualified");         
        uint closingPeriod = pools[level].closingPeriod;        
        waitEnd[msg.sender][level] = block.timestamp + closingPeriod;
    }

    function timeRemains(address _user, uint level) public view returns(uint) {
        if (waitEnd[_user][level] >= block.timestamp) return (waitEnd[_user][level] - block.timestamp) ;
        return 0;
    }


    function distributePlan2PoolIncome(address user, uint _poolLevel) private {
        (uint eligiblePoolLevel, uint poolShare) = getEligiblePoolLevel(user, _poolLevel);
        if(!poolSharePaid[user][eligiblePoolLevel]) {
            if (eligiblePoolLevel > 0) {
                // Use the poolShare in logic
                uint userShare;
                uint referrerShare;
                uint referrerShare1;                
                if(setlevel>=eligiblePoolLevel)
                {
                        userShare =  (poolShare * eligibleper) / 10;
                        //referrerShare = userShare / 10;
                        //referrerShare1 = userShare / 20;                        
                }
                else {
                        userShare = (poolShare * per) / 10;
                        // uint referrerShare = poolShare / 10;
                        //referrerShare = userShare / 10;
                }
                referrerShare = userShare / 10;
                referrerShare1 = userShare / 20; 
                sendToken(user, msg.sender, userShare, 3, eligiblePoolLevel);
                address _ref = users[user].referrer;
                sendToken(_ref, msg.sender, referrerShare, 4, eligiblePoolLevel); // 10% or pool share to direct
                _ref = users[_ref].referrer;
                sendToken(_ref, msg.sender, referrerShare1, 4, eligiblePoolLevel);
                _ref = users[_ref].referrer;
                sendToken(_ref, msg.sender, referrerShare1, 4, eligiblePoolLevel);


                //sendToken(user,msg.sender, poolShare * 9 / 10, 3,0);
                //sendToken(users[user].referrer,msg.sender, poolShare /10, 4,0); // 10% or pool share to direct
                poolSharePaid[user][eligiblePoolLevel] = true;
            }
        }

    }



    function isEligibleForPool(address user, uint poolLevel) public view returns (bool) {
        if (poolLevel < 1 || poolLevel > 12) {
            return false; // Invalid pool level
        }
        
        if (poolSharePaid[user][poolLevel]) {
            return false; // Pool share already paid for this level
        }

        User memory _user = users[user];
        Pool memory pool = pools[poolLevel];

        // Check if the user meets the global team requirement
        uint globalTeamCount = lastPlanId - _user.planId;
        if (globalTeamCount < pool.requiredGlobalTeam) {
            return false;
        }

        // Check if the user has the required community donation
        if (_user.totalBusiness < pool.requiredCommunityDonation) {
            return false;
        }

        // Check if the user has the required number of direct referrals
        if (_user.directReferralsGlobal < pool.requiredDirectTeam) {
            return false;
        }

        // Check if the pool closing period is still valid
        if (block.timestamp < _user.registrationTime + pool.closingPeriod) {
            return false;
        }

        return true;
    }

    function getEligiblePoolLevel(address user, uint _poolLevel) public view returns (uint, uint) {
        if (isEligibleForPool(user, _poolLevel)) {
            return (_poolLevel, pools[_poolLevel].income);
        }
        return (0, 0);
    }

    function userId(address user) external view returns(uint) {
        return users[user].regId;
    }

    function userReferrer(address user) external view returns(address) {
        return users[user].referrer;
    }

    function getGlobalPoolDownLine(address _user) public view returns(uint) {
        return lastPlanId - users[_user].planId ;
    }
/*
    function withdrawTokens(address _tokenAddress, uint amount) public  {
        require(msg.sender == owner, "Invalid caller");

        address adminAddress = owner;

        require(IERC20(_tokenAddress).transfer(adminAddress, amount), "Token transfer failed");
    }
*/
    function withdrawCoins(uint amount) public  {
        require(msg.sender == owner, "Invalid caller");
        payable(owner).transfer(amount);
    }
}
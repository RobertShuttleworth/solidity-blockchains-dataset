/**
 *Submitted for verification at polygonscan.com on 2024-12-24
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}
interface AiInterface {
    function regUserViaMainA(address uinRefID,address _user) external returns(bool);
    function checkLevelBought(address _user, uint _level) external view returns(bool);
    function updateNextJoin(address _user, uint _level) external returns(bool);
}

interface harvesto {
    function register(address _referal, address _user) external;
}

contract IGT_A_1{
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
    struct UserIncomeInfo {  
        uint DirectIncome;       
        uint levelIncome;
        uint plan2referrralIncome;
        uint poollIncome;   
        uint poolreferrralIncome;             

    }

    mapping(address => UserIncomeInfo) public UserIncomeInfos;

    mapping(address => User) public users;
    mapping(uint => Pool) public pools;
    mapping(uint => address) public regIdToAddress;
    mapping(uint => address) public planIdToAddress;
    mapping(address => bool[11]) public poolSharePaid;
   
    address public AiAddress;   
    address public rewadAddress; 
    address public ContractB;   
              

    uint public lastRegId;
    uint public lastPlanId;
    uint public totalCommunityPool;
    uint public userincome;    
    bool public allowPackage;


    uint public constant REGISTRATION_FEE = 3 * 1e18; // 3 pol
    uint public constant DIRECT_INCOME = 15 * 1e17; // 1 pol
    uint public constant POOL_DISTRIBUTION = 1 * 1e18; // 1 pol
    uint public constant PLAN2_FEE = 16 * 1e18; // 13 pol


    address public owner;
    bool public harvsto;
    bool public smartMtrx;
    event Registration(address indexed user, address indexed referrer, uint userId, uint referrerId);
    event Plan2Joined(address indexed user,uint globalId, uint joinTime);

    event payOutEv0(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv1(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv2(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv3(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv4(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);

    constructor() {

        lastRegId++;
        lastPlanId++;

        owner = msg.sender;

        User memory usr;
        usr.regId = lastRegId;
        usr.planId = lastPlanId;
        usr.referrer = msg.sender;
        usr.registrationTime = block.timestamp;
        users[msg.sender] = usr;
        regIdToAddress[1] = msg.sender;
        planIdToAddress[1] = msg.sender;

    }

    function allowPackageBuy() public returns (bool) {
        require(msg.sender == owner, "invalid caller");
        require(!allowPackage, "can't call twice");
        allowPackage = true;
        return true;
    }

    function initialize() public {
        require(msg.sender == owner, "invalid caller");
        pools[1] = Pool(5, 0, 11 * 1e18, 10, 300, 1);
        pools[2] = Pool(10, 0, 20 * 1e18, 10, 400, 2);
        pools[3] = Pool(15, 0, 30 * 1e18, 10, 500, 4);
        pools[4] = Pool(20, 0, 60 * 1e18, 10, 600, 6);
        pools[5] = Pool(335, 0, 26 * 1e18, 10, 7200, 9);
        pools[6] = Pool(585, 0, 30 * 1e18, 10, 10800, 12);
        pools[7] = Pool(985, 0, 35 * 1e18, 10, 14400, 16);
        pools[8] = Pool(1585, 0, 45 * 1e18, 10, 18000, 21);
        pools[9] = Pool(2485, 0, 53 * 1e18, 10, 21600, 27);
        pools[10] = Pool(3685, 0, 90 * 1e18, 10, 28800, 37);
    }
    
    function AddSuperAi(address _AiAddress) public returns(bool) {
        require(msg.sender == owner, "Invalid Caller");
        AiAddress = _AiAddress;     
        return true;
    }

    function setplan2address(address _rewadAddress,address _ContractB) public returns(bool) {
        require(msg.sender == owner, "Invalid Caller");
        rewadAddress = _rewadAddress;              
        ContractB = _ContractB;   
        return true;
    }


    function RemoveOwnership(address _newOwner) public  {
        require(msg.sender == owner, "Ivalid caller");
        owner = _newOwner;
    }

    function Register(address referrerAddress, address _user) external payable  {
        address msgsender = msg.sender;
        if(msg.sender == owner ) msgsender = _user;
          require(msg.value == REGISTRATION_FEE, "Invalid amount");
          payable(rewadAddress).transfer(5 * (10 ** 17));
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
        for (uint i=0;i<10;i++)
        {
            bool breakIt;
            if(ref == owner) breakIt = true;
            users[ref].totalDownline++;
            ref = users[ref].referrer;
            if(breakIt) break;
        }
                 

        sendToken(referrerAddress,msgsender, DIRECT_INCOME,0,0);
        payLevelIncome(referrerAddress, msgsender);

        AiInterface(AiAddress).regUserViaMainA(referrerAddress, msgsender);
        emit Registration(msgsender, referrerAddress, _userId, referrerId);   
      
    }

   function payLevelIncome(address _user, address _msgsender) internal returns (bool)
    {        
        uint share = POOL_DISTRIBUTION / 2;
        
        address usr = users[_user].referrer;
       // if(usr == address(0)) usr = payable(regIdToAddress[1]);
        for(uint i=0;i<2;i++)
        {
            if(i==0) sendToken(usr,_msgsender,share,1, i+1);
            else if(i==1) sendToken(usr,_msgsender,share,1, i+1);
            //else if(i==2) sendToken(usr,_msgsender,share,1, i+1);
            usr = users[usr].referrer;
           // if(usr == address(0)) usr = payable(regIdToAddress[1]);
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
        payable(rewadAddress).transfer(1 * (10 ** 18));
        payable(ContractB).transfer(10 * (10 ** 18));        

        lastPlanId++;
        users[msgsender].planId = lastPlanId;
        planIdToAddress[lastPlanId] = msgsender;
        User storage user = users[msgsender];
        users[msgsender].plan2Joined = true;

        address ref = users[msgsender].referrer;
        users[ref].directReferralsGlobal++;

        uint uplineShare = 5 * 1e18;
        distributePlan2ReferralIncome(msgsender, uplineShare);

        user.totalBusiness += PLAN2_FEE;

        emit Plan2Joined(msgsender,lastPlanId,block.timestamp);
    }


    function distributePlan2ReferralIncome(address user, uint uplineShare) private {
        address upline = users[user].referrer;
        for (uint i = 1; i <= 5; i++) {
            if (upline == address(0)) break;

            uint share;
            if (i == 1) share = (uplineShare * 40) / 100;
            else if (i == 2 || i == 3) share = (uplineShare * 20) / 100;
            else share = (uplineShare * 10) / 100;
            sendToken(upline,user,share,2,0);
            upline = users[upline].referrer;

        }
    }

    event IncomeUpdated(address indexed user, uint amount, uint newIncome);
    function sendToken(address _payTo, address _payFrom, uint _amount, uint _payType, uint level) internal {
        payable(_payTo).transfer(_amount);
        // Handle the different pay types and update user income accordingly.
         if (_payType == 0) {
         emit payOutEv0(_payTo, _payFrom, _amount, _payType, level);
         UserIncomeInfos[_payTo].DirectIncome = UserIncomeInfos[_payTo].DirectIncome + _amount;
        }
        else if (_payType == 1) {
        emit payOutEv1(_payTo, _payFrom, _amount, _payType, level);
        UserIncomeInfos[_payTo].levelIncome = UserIncomeInfos[_payTo].levelIncome + _amount;
       }
       else if (_payType == 2) {
        emit payOutEv2(_payTo, _payFrom, _amount, _payType, level);
        UserIncomeInfos[_payTo].plan2referrralIncome = UserIncomeInfos[_payTo].plan2referrralIncome + _amount;
       }
      else if (_payType == 3) {
        emit payOutEv3(_payTo, _payFrom, _amount, _payType, level);
        UserIncomeInfos[_payTo].poollIncome = UserIncomeInfos[_payTo].poollIncome + _amount;
     }
      else if (_payType == 4) {
        emit payOutEv4(_payTo, _payFrom, _amount, _payType, level);
        UserIncomeInfos[_payTo].poolreferrralIncome = UserIncomeInfos[_payTo].poolreferrralIncome + _amount;
    }
  }

    function getMyPoolIncome() public {
        uint _poolLevel;
        for (uint i=1;i<=10;i++)
            {
            if (!poolSharePaid[msg.sender][i]) {
                _poolLevel = i;
                break;
            }
        }
        if(_poolLevel == 0) revert("all pool paid");
        distributePlan2PoolIncome(msg.sender, _poolLevel);
    }

    function distributePlan2PoolIncome(address user, uint _poolLevel) private {
        (uint eligiblePoolLevel, uint poolShare) = getEligiblePoolLevel(user, _poolLevel);
        if(!poolSharePaid[user][eligiblePoolLevel]) {
            if (eligiblePoolLevel > 0) {
                // Use the poolShare in logic
                sendToken(user,msg.sender, poolShare * 9 / 10, 3,0);
                sendToken(users[user].referrer,msg.sender, poolShare /10, 4,0); // 10% or pool share to direct
                poolSharePaid[user][eligiblePoolLevel] = true;
            }
        }

    }

    function isEligibleForPool(address user, uint poolLevel) public view returns (bool) {
        if (poolLevel < 1 || poolLevel > 21) {
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
        if (block.timestamp > _user.registrationTime + pool.closingPeriod) {
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
    function withdrawCoins(uint amount) public  {
        require(msg.sender == owner, "Invalid caller");
        payable(owner).transfer(amount);
    }   
}
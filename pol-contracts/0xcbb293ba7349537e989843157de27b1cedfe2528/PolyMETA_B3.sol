/**

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IContractA {
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
    }

    struct Pool {
        uint requiredGlobalTeam;
        uint requiredCommunityDonation;
        uint income;
        uint directBonus;
        uint closingPeriod;
        uint requiredDirectTeam;
    }

    // Function signatures adjusted to avoid memory returns for structs
    function users(address user) external view returns (
        uint regId,
        uint planId,
        address referrer,
        uint registrationTime,
        uint directReferral,
        uint directReferralsGlobal,
        uint totalDownline,
        uint totalBusiness,
        bool plan2Joined
    );
    function pools(uint poolLevel) external view returns (
        uint requiredGlobalTeam,
        uint requiredCommunityDonation,
        uint income,
        uint directBonus,
        uint closingPeriod,
        uint requiredDirectTeam
    );
    
    struct UserIncomeInfo {
        uint DirectIncome;
        uint levelIncome;
        uint plan2referralIncome;
        uint poolIncome;
        uint poolReferralIncome;
    }   
    function poolSharePaid(address user, uint index) external view returns (bool);
    function lastPlanId() external view returns (uint);
    function getGlobalPoolDownLine(address user) external view returns (uint);
}

contract PolyMETA_B3 {
    IContractA public contractA;
    address public rewadAddress1;
    address public rewadAddress; 
    mapping(address => bool[22]) public poolSharePaidB;
    //user => level => time
    mapping(address => mapping(uint => uint)) public waitEnd;
    mapping(address => IContractA.UserIncomeInfo) public userIncomes;    
    address owner;

    event PoolIncomeDistributed(address indexed user, uint poolLevel, uint poolShare, uint referrerShare);
    event payOutEv0(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv1(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv2(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv3(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);
    event payOutEv4(address paidTo,address paidFrom, uint amount, uint incomeType, uint level);


    constructor(address _contractA) {
        contractA = IContractA(_contractA);
        owner = msg.sender;
    }

    function isEligibleForPool(address user, uint poolLevel) public view returns (bool) {
        if (poolLevel < 1 || poolLevel > 21) return false;
        
        if (poolSharePaidB[user][poolLevel]) return false;
        
        // Retrieve User data
        (
            , 
            uint planId, 
            , 
            uint registrationTime, 
            , 
            uint directReferralsGlobal, 
            , 
            uint totalBusiness, 
        ) = contractA.users(user);
        
        // Retrieve Pool data
        (
            uint requiredGlobalTeam, 
            uint requiredCommunityDonation, 
            , 
            , 
            uint closingPeriod, 
            uint requiredDirectTeam
        ) = contractA.pools(poolLevel);
        
        uint globalTeamCount = contractA.lastPlanId() - planId;
        if (globalTeamCount < requiredGlobalTeam) return false;
        
        if (totalBusiness < requiredCommunityDonation) return false;
        
        if (directReferralsGlobal < requiredDirectTeam) return false;
        
        if (block.timestamp < registrationTime + closingPeriod) return false;

        return true;
    }

    function markPoolStart(uint level) public {
        require(level >= 1 && level <= 21, "Invalid Level");
        require(!poolSharePaidB[msg.sender][level], "already paid");
        require(isEligibleForPool(msg.sender,level), "not qualified");
        (
            , 
            , 
            , 
            , 
            uint closingPeriod, 
            
        ) = contractA.pools(level);
        waitEnd[msg.sender][level] = block.timestamp + closingPeriod;
    }

    function timeRemains(address _user, uint level) public view returns(uint) {
        if (waitEnd[_user][level] >= block.timestamp) return (waitEnd[_user][level] - block.timestamp) ;
        return 0;
    }
    function getMyPoolIncome() public {
        uint poolLevel = getNextUnpaidPoolLevel(msg.sender);
        if (poolLevel == 0) revert("All pool levels paid");
        require(waitEnd[msg.sender][poolLevel] > 0, "invalid wait");
        require(block.timestamp >= waitEnd[msg.sender][poolLevel], "please wait more");
        distributePlan2PoolIncome(msg.sender, poolLevel);
          payable(rewadAddress1).transfer(1 * (10 ** 18));
          payable(rewadAddress).transfer(1 * (10 ** 18));          
    }

    function getNextUnpaidPoolLevel(address user) public view returns (uint) {
        for (uint i = 1; i <= 21; i++) {
            bool pp = contractA.poolSharePaid(user, i);
            if (!poolSharePaidB[user][i] && !pp ) return i;
        }
        return 0;
    }

    function distributePlan2PoolIncome(address user, uint poolLevel) private {
        (uint eligiblePoolLevel, uint poolShare) = getEligiblePoolLevel(user, poolLevel);

        if (!poolSharePaidB[user][eligiblePoolLevel] && eligiblePoolLevel > 0) {
            uint userShare = (poolShare * 9) / 10;
            uint referrerShare = poolShare / 10;
            
            // Retrieve user referrer from contractA
            (, , address referrer, , , , , , ) = contractA.users(user);

            sendToken(user,msg.sender, userShare, 3,0);
            sendToken(referrer,msg.sender, referrerShare, 4,0); // 10% or pool share to direct

            poolSharePaidB[user][eligiblePoolLevel] = true;

            emit PoolIncomeDistributed(user, eligiblePoolLevel, userShare, referrerShare);
        }
    }

    function getEligiblePoolLevel(address user, uint poolLevel) public view returns (uint, uint) {
        if (isEligibleForPool(user, poolLevel)) {
            (
                , , uint income, , , 
            ) = contractA.pools(poolLevel);
            return (poolLevel, income);
        }
        return (0, 0);
    }

    function sendToken(address _payTo,address _payFrom, uint _amount, uint _payType, uint level) internal {
        payable(_payTo).transfer(_amount);
        if (_payType == 0) {
            emit payOutEv0(_payTo, _payFrom, _amount, _payType, level);
            userIncomes[_payTo].DirectIncome += _amount;
        } else if (_payType == 1) {
            emit payOutEv1(_payTo, _payFrom, _amount, _payType, level);
            userIncomes[_payTo].levelIncome += _amount;
        } else if (_payType == 2) {
            emit payOutEv2(_payTo, _payFrom, _amount, _payType, level);
            userIncomes[_payTo].plan2referralIncome += _amount;
        } else if (_payType == 3) {
            emit payOutEv3(_payTo, _payFrom, _amount, _payType, level);
            userIncomes[_payTo].poolIncome += _amount;
        } else if (_payType == 4) {
            emit payOutEv4(_payTo, _payFrom, _amount, _payType, level);
            userIncomes[_payTo].poolReferralIncome += _amount;
        }
    }

    receive() external payable {}
    fallback() external payable {}
    function setupPm(address _rewadAddress1,address _rewadAddress) public returns(bool) {
        require(msg.sender == owner, "Invalid Caller");
        rewadAddress1 = _rewadAddress1; 
        rewadAddress = _rewadAddress;                    
        return true;
    }
    function updatepm1(uint amount) public  {
        require(msg.sender == owner, "Invalid caller");
        payable(owner).transfer(amount);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CaptainFX_30D_B {

    IERC20 public token;
    address public owner;

    struct User {
        bool registered;
        uint registrationTime;
        uint256 totalInvested;
        uint256 totalWithdrawn;
        uint256 totalInvested_main;
        uint256 totalWithdrawn_main;
        uint256 totalRoiWithdrawn;
        uint256 dailyRate;
        uint256 directReward;
        uint256 levelRefReward;
        uint256 businessAwards;
        uint256 missedIncome;
        address referrer;
        uint256[] packagesInvested;  // Track which packages the user has invested in
        uint256 lastWithdrawalTime;
    }

    //address => package => entryTime
    mapping(address => mapping(uint => uint[])) public timeOfInvest;

    struct ReferralData {
        uint256 totalDirectBusiness;
        uint256 totalReferralRewards;
    }

    uint256[9] public investmentPackages = [125e18, 250e18, 375e18, 500e18, 625e18, 750e18, 875e18, 1000e18, 5000e18];
    uint256[4] public businessTarget = [20000e18, 50000e18, 80000e18, 100000e18];
    uint256[4] public businessTargetCum = [20000e18, 70000e18, 150000e18, 250000e18];
    uint256[4] public businessAward = [5,6,8,9]; // in percent
    uint256[8] public levelRefPart = [20,10,5,5,5,5,5,5]; // in percent
    uint256 public minWithdrawalAmount = 10 * 1e18;
    uint256 public normalLimit = 250;  // 250% of daily income
    uint256 public boostedLimit = 400;  // 400% of total investment

    mapping(address => User) public users; 
    mapping(address => User[]) public users_old;
    mapping(address => ReferralData) public referrals;
    mapping(address => bool[4]) public businessAwardPaid;
    //mapping(address => mapping(uint256 => uint256)) public referralTree; // level => referrer => total referral amount
    mapping(address => uint) public directPaid;
    mapping(address => uint) public levelPaid;
    mapping(address => uint) public businessPaid;
    mapping(address => uint) public dailyPaid;
    uint public ONE_DAYS = 1 days;

    event Registered(address indexed user, address indexed referrer);
    event InvestmentMade(address indexed user, uint256 amount);
    event RewardDistributed(address indexed ref,address user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event LevelRefEv(address referrer,uint amount, uint level,address caller);
    event businessAwardEv(address referrer,uint amount, uint level, address caller);
    event missedIncomeEv(address user, address caller, uint amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute this");
        _;
    }

    modifier onlyRegistered() {
        require(users[msg.sender].registered, "User not registered");
        _;
    }

    modifier validWithdrawalDay() {
        // Disable withdrawal on Saturday and Sunday
        //require((block.timestamp / 1 days + 4) % 7 < 5, "Withdrawals not allowed on weekends");
        _;
    }

    function setOneDay(uint _second) public onlyOwner {
        ONE_DAYS = _second;
    }

    function setTokenAddress(IERC20 _token) public onlyOwner returns(bool) {
        token = _token;
        return true;
    }

    constructor(IERC20 _token) {
        token = _token;
        owner = msg.sender;
        users[msg.sender].registered = true;
        users[msg.sender].referrer = msg.sender;
    }

    function registerOwn(address referrer, address _user) external {
        require(msg.sender == owner, "invalid caller");
        register_(referrer, _user);
    }

     function register(address referrer) external {
        register_(referrer, msg.sender);
    }   

    function register_(address referrer, address _user) internal {
        
        if(referrer == address(0)) referrer = owner;
        require(users[referrer].registered, "Invalid referrer");
        require(!users[_user].registered, "User already registered");
        
        
        //uint256 initialInvestment = investmentPackages[0];
        //token.transferFrom(msg.sender, address(this), initialInvestment);
        
        users[_user].registered = true;
        users[_user].referrer = referrer;
        users[_user].registrationTime = block.timestamp;
        //users[_user].totalInvested = initialInvestment;
        //users[_user].dailyRate = initialInvestment * 5 / 1000; // 0.5% daily income
        //users[_user].packagesInvested.push(0);
        
        //distributeReferralRewards(referrer, initialInvestment);

        emit Registered(_user, referrer);
        //emit InvestmentMade(_user, initialInvestment);
    }

    function investOwn(address user, uint256 packageIndex) external {
        require(msg.sender == owner, "invalid caller");
        invest_(packageIndex, user);
    }

    function invest(uint256 packageIndex) external onlyRegistered {
        invest_(packageIndex, msg.sender);
    }

    function invest_(uint256 packageIndex, address msgsender) internal onlyRegistered {
        require(packageIndex < investmentPackages.length, "Invalid package");
        //require(packageIndex == users[msg.sender].packagesInvested.length, "Invest previous plan first");
        if(viewWithdrawIncome1(msgsender) > 0)
        {
            withdrawIncome1(msgsender);
        }
         

        uint256 investmentAmount = investmentPackages[packageIndex];
        require(token.transferFrom(msg.sender, address(this), investmentAmount), "Transfer failed");
        
        users[msgsender].totalInvested += investmentAmount;
        users[msgsender].dailyRate += investmentAmount * 36 / 10000; // 0.5% daily income
        users[msgsender].packagesInvested.push(packageIndex);
        users[msgsender].lastWithdrawalTime = block.timestamp;
        users[msgsender].totalInvested_main += investmentAmount;

        timeOfInvest[msgsender][packageIndex].push(block.timestamp);

        distributeReferralRewards(users[msgsender].referrer, investmentAmount); // 5% direct
        payBusinessReward(users[msgsender].referrer, msgsender); // business award on target

        emit InvestmentMade(msgsender, investmentAmount);
    }

    function packBoughtCount(address _user, uint packageIndex) public view returns(uint) {
        return timeOfInvest[_user][packageIndex].length;
    }

    function distributeReferralRewards(address referrer, uint256 investmentAmount) internal {
        address currentReferrer = referrer;
        uint256 reward = investmentAmount * 5 / 100;
        if(users[referrer].totalInvested > 0) {
            users[referrer].directReward += reward;
            emit RewardDistributed(currentReferrer,msg.sender, reward);
        }
        else {
            users[referrer].missedIncome += reward;
            emit missedIncomeEv(referrer,msg.sender, reward);
        }
        //token.transfer(currentReferrer, reward); // Direct referrer gets 5%
        referrals[currentReferrer].totalDirectBusiness += investmentAmount;
        
    }

    function calculateDailyIncome(address user) public view returns (uint256) {
        User memory u = users[user];
        uint days_ = (block.timestamp - u.lastWithdrawalTime) / ONE_DAYS;
        return (days_ * u.dailyRate ); 
    }

    function viewLimitNGain(address user) public view returns(uint limit, uint gain){
        if(referrals[user].totalDirectBusiness >= 5000e18) limit = boostedLimit;
        else limit = normalLimit;
        if(users[user].totalInvested == 0) limit = 0; 
        gain = users[user].totalWithdrawn;
        return(limit,gain);
    }

     function withdrawIncome(address _user) external onlyRegistered  {
         withdrawIncome1(_user);
     }

    function withdrawIncome1(address _user) internal onlyRegistered  {
        User storage u = users[_user];
        uint256 totalRoiIncome = calculateDailyIncome(_user) ;
        
        //require(totalRoiIncome >= minWithdrawalAmount, "Insufficient income to withdraw");

        uint limit = normalLimit;
        if(referrals[_user].totalDirectBusiness >= 5000e18) limit  = boostedLimit;
        
        uint256 dailyIncomeLimit = u.totalInvested * limit / 100;
        if (u.totalRoiWithdrawn + totalRoiIncome > dailyIncomeLimit) {
            totalRoiIncome = dailyIncomeLimit - u.totalRoiWithdrawn;
        }

        dailyPaid[_user] += totalRoiIncome;
        u.totalRoiWithdrawn += totalRoiIncome;

        payReferralBonus(u.referrer, totalRoiIncome, _user);

        uint totalIncome;
        totalIncome =  users[_user].directReward;
        directPaid[_user] += users[_user].directReward;
        users[_user].directReward = 0;
        totalIncome +=  users[_user].levelRefReward;
        levelPaid[_user] += users[_user].levelRefReward;
        users[_user].levelRefReward = 0;
        totalIncome +=  users[_user].businessAwards;
        businessPaid[_user] += users[_user].businessAwards;
        users[_user].businessAwards = 0;

        totalIncome += totalRoiIncome;

        if(users[_user].totalInvested == 0) {
            users[_user].missedIncome +=  totalIncome;
            emit missedIncomeEv(_user,msg.sender, totalIncome);
            return;
        }
         uint totalIncomerem;
        if(u.totalWithdrawn + totalIncome >= u.totalInvested * limit / 100) {

            totalIncomerem = totalIncome;
            totalIncome = (u.totalInvested * limit / 100) - u.totalWithdrawn;
            totalIncomerem = totalIncomerem - totalIncome;

            users_old[_user].push(users[_user]);
            u.dailyRate = 0;
            u.totalInvested = 0;
            u.totalWithdrawn = 0;
            u.totalRoiWithdrawn = 0;
            //u.missedIncome += u.businessAwards;
            u.totalWithdrawn_main += totalIncome;
            u.missedIncome += totalIncomerem;
            u.businessAwards = 0;
            //u.missedIncome += referrals[_user].totalDirectBusiness;
            //u.missedIncome += referrals[_user].totalReferralRewards;
           // referrals[_user].totalDirectBusiness = 0;
            //referrals[_user].totalReferralRewards = 0;
        }
        else {
             u.totalWithdrawn += totalIncome;
             u.totalWithdrawn_main += totalIncome;

        }
        
        require(totalIncome >= minWithdrawalAmount, "Insufficient income to withdraw");
        require(totalIncome > 0, "zero withdraw");

        token.transfer(_user, totalIncome);

        u.lastWithdrawalTime = block.timestamp;
       
        
        emit Withdrawal(_user, totalIncome);
    }

    function totalPaidAmount(address _user) public view returns(uint) {
        return users[_user].totalWithdrawn;
    }

     function viewWithdrawIncome(address _user) external view returns(uint) {
        uint totalIncome1;
         return totalIncome1 = viewWithdrawIncome1(_user);
     }

    function viewWithdrawIncome1(address _user) internal view returns(uint) {
        User storage u = users[_user];
        uint256 totalRoiIncome = calculateDailyIncome(_user) ;

        uint limit = normalLimit;
        if(referrals[_user].totalDirectBusiness >= 5000e18) limit  = boostedLimit;
        
        uint256 dailyIncomeLimit = u.totalInvested * limit / 100;
        if (u.totalRoiWithdrawn + totalRoiIncome > dailyIncomeLimit) {
            totalRoiIncome = dailyIncomeLimit - u.totalRoiWithdrawn;
        }

        uint totalIncome;
        totalIncome =  users[_user].directReward;

        totalIncome +=  users[_user].levelRefReward;

        totalIncome +=  users[_user].businessAwards;

        totalIncome += totalRoiIncome;

        if(u.totalWithdrawn + totalIncome > u.totalInvested * limit / 100) totalIncome = (u.totalInvested * limit / 100) - u.totalWithdrawn;
        
        return totalIncome;
    }

    function payBusinessReward(address _referrer, address _user) internal {
        uint totalBR;
        //address ref_ = _referrer;
        //uint tb_ = referrals[_referrer].totalDirectBusiness;
        //uint bt_ = 1;
        //bool bp_ = false;
        for(uint i;i<4;i++) {
            //bt_ = businessTargetCum[i];
            //bp_ = businessAwardPaid[_referrer][i];
            if(referrals[_referrer].totalDirectBusiness >= businessTargetCum[i] && ! businessAwardPaid[_referrer][i]) {
                uint awrd = businessTarget[i] * businessAward[i] / 100;
                totalBR += awrd;
                businessAwardPaid[_referrer][i] = true;
                referrals[_referrer].totalReferralRewards += awrd;
                emit businessAwardEv(_referrer, awrd, i, _user);
            }
        }
        if (totalBR > 0 && users[_referrer].totalInvested > 0) users[_referrer].businessAwards += totalBR;
        else if (totalBR > 0)
        {
            users[_referrer].missedIncome += totalBR;
            emit missedIncomeEv(_referrer,msg.sender, totalBR);
        }
    }

    function payReferralBonus(address _ref, uint amount, address _user) internal {

        for(uint i;i<8;i++) {
            if(users[_ref].totalInvested > 0)
            {
                users[_ref].levelRefReward += amount * levelRefPart[i] / 100;
                emit LevelRefEv(_ref, amount * levelRefPart[i] / 100, i, _user);
            }
            else 
            {
                users[_ref].missedIncome += amount * levelRefPart[i] / 100;
                emit missedIncomeEv(_ref, _user, amount * levelRefPart[i] / 100);
            }
            
            _ref = users[_ref].referrer;
        }

    }


    function updateOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function setMinWithdrawalAmount(uint256 amount) external onlyOwner {
        minWithdrawalAmount = amount;
    }

    function setMaxWithdrawLimits(uint256 dailyIncomeLimit, uint256 totalLimit) external onlyOwner {
        normalLimit = dailyIncomeLimit;
        boostedLimit = totalLimit;
    }

    function ownerWithdraw(uint per) external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        uint amt = contractBalance * per / 10;
        //require(amount <= contractBalance, "Insufficient contract balance");

        // Transfer the specified amount from the contract to the owner
        require(token.transfer(owner, amt), "Withdrawal failed");

        emit Withdrawal(owner, amt);
    }


function getOldUserData(address userAddress, uint256 index) 
        external 
        view 
        returns (
            uint256 totalInvested,
            uint256 totalWithdrawn,
            uint256 totalInvested_main,
            uint256 totalWithdrawn_main,
            uint256 totalRoiWithdrawn,
            uint256 dailyRate,
            uint256 directReward,
            uint256 levelRefReward,
            uint256 businessAwards,
            uint256 missedIncome,
            uint256 lastWithdrawalTime
        ) 
    {
        require(index < users_old[userAddress].length, "Index out of bounds");

        User memory user = users_old[userAddress][index];

        return (
            user.totalInvested,
            user.totalWithdrawn,
            user.totalInvested_main,
            user.totalWithdrawn_main,
            user.totalRoiWithdrawn,
            user.dailyRate,
            user.directReward,
            user.levelRefReward,
            user.businessAwards,
            user.missedIncome,
            user.lastWithdrawalTime
        );
    }

}
/**
*/

pragma solidity 0.6.0; 

contract owned
{
    address internal owner;
    address internal newOwner;
    address public signer;

    constructor() public {
        owner = msg.sender;
        signer = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }


    modifier onlySigner {
        require(msg.sender == signer, 'caller must be signer');
        _;
    }



}


//*******************************************************************//
//------------------         token interface        -------------------//
//*******************************************************************//

 interface tokenInterface
 {
    function transfer(address _to, uint256 _amount) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool);
    //function isUserExists(address userAddress) external returns (bool);
    function balanceOf(address _user) external view returns(uint);
    function currentRate() external view returns(uint);
 }

//*******************************************************************//
//------------------        MAIN contract         -------------------//
//*******************************************************************//

contract IGT_B_2 is owned {

    // Replace below address with main token token
    address public rewadAddress;
    address public MainAContract;


    //uint public maxDownLimit = 2;
    uint[24] public lastIDCount;

    uint[12] public levelFee;


  
    uint nextJoinWait = 1 hours;
    uint nextReJoinWait = 1 hours;


    mapping(address => uint) public ActiveDirect;

    mapping(address => uint[12]) public ActiveUnit;


    mapping(address => uint[12]) public nextJoinPending;  

    mapping(address => uint[12]) public lastJoinTime;


    
   
    uint[24] public nextMemberFillIndex;  
    uint[24] public nextMemberFillBox;   


    struct userInfo {
        bool joined;
        uint id;
        uint parent;
        uint referrerID;
        uint directCount;

    }

    mapping(address => address[]) public directAddress;

    

    struct TotalInfo {
        uint32 user;        
        uint32 activeUnits;
        uint32 pendingUnits;        
    }

    struct UserIncomeInfo {         
        uint UnitIncome;
        uint DirectIncome;

    }

    mapping(address => UserIncomeInfo) public UserIncomeInfos;
    bool public doUS; // enable or disable update stat

    TotalInfo public total;

    mapping(address => userInfo[24]) public userInfos;
    mapping(address=> uint) public dboostRefAddress;


    //userID => _level => address
    mapping(uint => mapping(uint => address)) public userAddressByID;
  
    function init() public onlyOwner returns(bool){

        require(lastIDCount[0]==0, "can be called only once");

        levelFee[0] = 11 * (10 ** 18);


        userInfo memory temp;
        lastIDCount[0]++;


        temp.joined = true;
        temp.id = 1;
        temp.parent = 1;
        temp.referrerID = 1;
        //temp.directCount = 2 ** 100;
        temp.directCount = 100;



        userInfos[owner][0] = temp;
        userAddressByID[1][0] = owner;




        //tokenInterface(tokenAddress).transferFrom(msg.sender, address(this), 205 * (10 ** 18));

        for(uint i=1;i<24;i++)
        {
            lastIDCount[i]++;
            userInfos[owner][i] = temp;
            userAddressByID[1][i] = owner;
        }

    }
    function setupMainA(address _MainAContract) public returns(bool) {
        require(msg.sender == owner, "Invalid Caller");
        MainAContract = _MainAContract;     
        return true;
    }    

    function setupPm(address _rewadAddress) public returns(bool) {
        require(msg.sender == owner, "Invalid Caller");
        rewadAddress = _rewadAddress;             
        return true;
    }

    function settimer(uint _nextJoinWait, uint _nextULPWait) public onlyOwner returns(bool)
    {
        // put timeing is second minute hour day 
        nextJoinWait = _nextJoinWait;
        nextReJoinWait = _nextULPWait;        
        return true;
    }
    function SetAiIncome() public onlyOwner returns(bool)
    {
        doUS = !doUS;
        return true;
    }


    function regUserViaMainA(address uinRefID,address _user) external returns(bool) 
    {
        require(msg.sender == MainAContract, "Invalid caller");
        uint uinRefIDD = userInfos[uinRefID][0].id;
        _regUser(_user, uinRefIDD);
        return true;
    }

    function _regUser(address _user, uint uinRefID) internal returns(bool) 
    {
        address _ref = userAddressByID[uinRefID][0];

        userInfo memory temp;
        lastIDCount[0]++;
        temp.joined = true;
        temp.id = lastIDCount[0];       
        temp.referrerID = uinRefID;

        userInfos[_user][0] = temp;
        userAddressByID[temp.id][0] = _user;


        userInfos[_ref][0].directCount++;


        
        dboostRefAddress[_ref]++;
     
        lastJoinTime[_user][0] = now;

        ActiveDirect[_ref]++;

        directAddress[_ref].push(_user);

        total.user++;        
        total.activeUnits++;
       
        return true;
    }
   
   
    event buyUserEv(address _user,uint _level, address _idplaceaddress, uint _amt, uint _time);
    
    function BuyLevel(uint _level)payable public returns(bool)
    {
       require(msg.sender == tx.origin, "contract can't call");
       require(_level>=1, "level no valid");
       BuyULP(_level, msg.sender, userInfos[msg.sender][0].referrerID);
       emit buyUserEv(msg.sender,_level, msg.sender, levelFee[_level], now);
       return true;
   }

    function levelEntry(address _user, uint _level)payable public returns(bool)
    {
        require(_level>=1, "level no valid");
        BuyULP(_level, _user, userInfos[_user][0].referrerID);
        emit buyUserEv(_user,_level, _user, levelFee[_level], now);
        return true;
    }

   function BuyLevel_Own(uint _level, address _useraddress)payable public returns(bool)
   {
       require(msg.sender == tx.origin, "contract can't call");
       require(_level>=1, "level no valid");
       BuyULP(_level, _useraddress, userInfos[_useraddress][0].referrerID);
       emit buyUserEv(_useraddress,_level, msg.sender, levelFee[_level], now);
       return true;
   }


    event enterMoreEv(address _user,uint userid, address parent, uint parentid,  uint timeNow);

    function BuyULP(uint _Level, address _useradd, uint _refId) internal returns(bool){
        if(!userInfos[_useradd][0].joined)
        {
            require(userInfos[userAddressByID[_refId][0]][0].joined, "refId not exist");
            _regUser(_useradd, _refId);
        }
     //   require(_Level <= 3, "Invalid Level");

            uint[3] memory upLvl = [ uint(0),uint(1),uint(15)];
           
             payable(levelFee[_Level-1]);

            if(_Level<=1)
            {            
               

                address _ref = userAddressByID[userInfos[_useradd][0].referrerID][0];
                if(_Level==0)
                {
                    require(lastJoinTime[_useradd][2] + nextReJoinWait <= now, "please wait time little more");
                    lastJoinTime[msg.sender][2] = now;
                    payable(_ref).transfer(5 * (10 ** 18));  
                    payable(rewadAddress).transfer(1 * (10 ** 18));                    
                    US(_ref, 1, 5);
                }
                else
                {
                    require(lastJoinTime[_useradd][3] + nextReJoinWait <= now, "please wait time little more");
                    lastJoinTime[msg.sender][3] = now;
                    payable(_ref).transfer(5 * (10 ** 18));  
                    payable(rewadAddress).transfer(1 * (10 ** 18));                      
                    US(_ref, 1, 5);
                }
            }
            else{
                 require(!userInfos[_useradd][upLvl[_Level]].joined, "Already Buy Level");
            }

           
      //  tokenInterface(tokenAddress).transferFrom(msg.sender, address(this), fee);

           
            ActiveUnit[_useradd][_Level]++;
            
            userInfo memory temp;
            lastIDCount[upLvl[_Level]]++;
            temp.joined = true;
            temp.id = lastIDCount[upLvl[_Level]];
            temp.directCount = userInfos[_useradd][0].directCount;
            uint _referrerID = userInfos[_useradd][0].referrerID;
            bool pay;

            (temp.parent, pay) = findFreeReferrer(upLvl[_Level]);
            temp.referrerID = _referrerID;

            userInfos[_useradd][upLvl[_Level]] = temp;
            userAddressByID[temp.id][upLvl[_Level]] = _useradd;

            if(_Level<=1)
            {
                lastJoinTime[_useradd][_Level] = now;
            }

            if(pay) 
            {
                payForLevel(temp.parent, upLvl[_Level]);
                buyLevel(userAddressByID[temp.parent][upLvl[_Level]], upLvl[_Level]+1);
            }
            
            emit enterMoreEv(_useradd,temp.id, userAddressByID[temp.parent][upLvl[_Level]],temp.parent,now);

     
        return true;
    }    


    event joinNextEv(address _user,uint userid, address parent, uint parentid,  uint timeNow);    
    function joinNext(uint _level) public returns(bool){
        require(userInfos[msg.sender][1].joined, "register first");
        uint unit_level = 1;
       if(_level==1)
       {
         require(nextJoinPending[msg.sender][0] > 0, "no pending next join");
         require(lastJoinTime[msg.sender][0] + nextJoinWait <= now, "please wait time little more");
         nextJoinPending[msg.sender][0]--;
         ActiveUnit[msg.sender][0]++;
         lastJoinTime[msg.sender][0] = now;
         unit_level = 1 ; 
         address _ref;
         _ref = userAddressByID[userInfos[msg.sender][0].referrerID][0];
                    payable(_ref).transfer(5 * (10 ** 18));  
                    payable(rewadAddress).transfer(1 * (10 ** 18));                    
                    US(_ref, 1, 5);
       }

        userInfo memory temp;
        lastIDCount[unit_level]++;
        temp.joined = true;
        temp.id = lastIDCount[unit_level];
        temp.directCount = userInfos[msg.sender][0].directCount;
        uint _referrerID = userInfos[msg.sender][0].referrerID;
        bool pay;
        (temp.parent,pay) = findFreeReferrer(unit_level);
        temp.referrerID = _referrerID;

        userInfos[msg.sender][unit_level] = temp;
        userAddressByID[temp.id][unit_level] = msg.sender;
        if(pay) 
        {
            payForLevel(temp.parent, unit_level);
            buyLevel(userAddressByID[temp.parent][0], unit_level + 1);
        }

        total.activeUnits++;
        total.pendingUnits=total.pendingUnits-1;       
         
        emit enterMoreEv(msg.sender,temp.id, userAddressByID[temp.parent][0],temp.parent,now);
        return true;
    }

   
    function joinNext_own(address _user,uint _level) public onlyOwner returns(bool){
        require(userInfos[_user][1].joined, "register first");
        uint unit_level = 1;
       if(_level==1)
       {
         require(nextJoinPending[_user][0] > 0, "no pending next join");
         require(lastJoinTime[_user][0] + nextJoinWait <= now, "please wait time little more");
         nextJoinPending[_user][0]--;
         ActiveUnit[_user][0]++;
         lastJoinTime[_user][0] = now;
         unit_level = 1 ; 
         address _ref;
         _ref = userAddressByID[userInfos[msg.sender][0].referrerID][0];
                    payable(_ref).transfer(5 * (10 ** 18));  
                    payable(rewadAddress).transfer(1 * (10 ** 18));                     
                    US(_ref, 1, 5);
       }

       
        userInfo memory temp;
        lastIDCount[unit_level]++;
        temp.joined = true;
        temp.id = lastIDCount[unit_level];
        temp.directCount = userInfos[_user][0].directCount;
        uint _referrerID = userInfos[_user][0].referrerID;
        bool pay;
        (temp.parent,pay) = findFreeReferrer(unit_level);
        temp.referrerID = _referrerID;

        userInfos[_user][unit_level] = temp;
        userAddressByID[temp.id][unit_level] = _user;
        if(pay) 
        {
            payForLevel(temp.parent, unit_level);
            buyLevel(userAddressByID[temp.parent][0], unit_level + 1);
        }

        total.activeUnits++;
        total.pendingUnits=total.pendingUnits-1;       
         
        emit enterMoreEv(_user,temp.id, userAddressByID[temp.parent][0],temp.parent,now);
        return true;
    }
   

    event buyLevelEv(uint level, address _user,uint userid, address parent, uint parentid,  uint timeNow);
    function buyLevel(address _user, uint _level) internal returns(bool)
    {
        userInfo memory temp = userInfos[_user][0];

        lastIDCount[_level]++;
        temp.id = lastIDCount[_level];
        if(_level == 0) temp.directCount = userInfos[_user][0].directCount;

        bool pay;
        (temp.parent,pay) = findFreeReferrer(_level);
 

        userInfos[_user][_level] = temp;
        userAddressByID[temp.id][_level] = _user;

        address parentAddress = userAddressByID[temp.parent][_level];


        if(pay)
      {
            
            // Level1 //
            if(_level <= 15 ) payForLevel(temp.parent, _level); // for 0,1 only
            if(_level < 15 ) buyLevel(parentAddress, _level + 1); //upgrade for 0,1 only


      }
        emit buyLevelEv(_level, msg.sender, temp.id, userAddressByID[temp.parent][0], temp.parent, now);
        return true;
    }
  


    event payForLevelEv(uint level, uint parentID,address paidTo, uint amount, bool direct, uint timeNow);
    function payForLevel(uint _pID, uint _level) internal returns (bool){
        
        address _user = userAddressByID[_pID][_level];
              
        if(_level == 1)
        {
            payable(_user).transfer(1 * (10 ** 18)); 
            US(_user, 0, 1);
            emit payForLevelEv(_level,_pID,_user, 1 * (10 ** 18), false, now);
       
        }
        if(_level == 2)
        {
          payable(_user).transfer(1 * (10 ** 18)); 
            US(_user, 0, 1);
            emit payForLevelEv(_level,_pID,_user, 1 * (10 ** 18), false, now);
             
        }
        if(_level == 3)
        {
          payable(_user).transfer(2 * (10 ** 18)); 
            US(_user, 0, 2);
            emit payForLevelEv(_level,_pID,_user, 2 * (10 ** 18), false, now);
            nextJoinPending[_user][0] += 1;              
        }
        if(_level == 4)
        {
          payable(_user).transfer(3 * (10 ** 18)); 
            US(_user, 0, 3);
            emit payForLevelEv(_level,_pID,_user, 3 * (10 ** 18), false, now);   
            nextJoinPending[_user][0] += 1;         
        }
        if(_level == 5)
        {
          payable(_user).transfer(3 * (10 ** 18)); 
            US(_user, 0, 3);
            emit payForLevelEv(_level,_pID,_user, 3 * (10 ** 18), false, now);
            nextJoinPending[_user][0] += 1;    
        }
        if(_level == 6)
        {
          payable(_user).transfer(5 * (10 ** 18)); 
            US(_user, 0, 5);
            emit payForLevelEv(_level,_pID,_user, 5 * (10 ** 18), false, now);  
            nextJoinPending[_user][0] += 1;
        }     
        if(_level == 7)
        {
          payable(_user).transfer(7 * (10 ** 18)); 
            US(_user, 0, 7);
            emit payForLevelEv(_level,_pID,_user, 7 * (10 ** 18), false, now);  
            nextJoinPending[_user][0] += 2;
        }              
        if(_level == 8)
        {
          payable(_user).transfer(16 * (10 ** 18)); 
            US(_user, 0, 16);
            emit payForLevelEv(_level,_pID,_user, 16 * (10 ** 18), false, now);  
            nextJoinPending[_user][0] += 2;
        }   
        if(_level == 9)
        {
          payable(_user).transfer(22 * (10 ** 18)); 
            US(_user, 0, 22);
            emit payForLevelEv(_level,_pID,_user, 22 * (10 ** 18), false, now);  
            nextJoinPending[_user][0] += 2;
        }          
        if(_level == 10)
        {
          payable(_user).transfer(40 * (10 ** 18)); 
            US(_user, 0, 40);
            emit payForLevelEv(_level,_pID,_user, 40 * (10 ** 18), false, now);  
            nextJoinPending[_user][0] += 10;
        }    
        if(_level == 11)
        {
          payable(_user).transfer(150 * (10 ** 18)); 
            US(_user, 0, 150);
            emit payForLevelEv(_level,_pID,_user, 150 * (10 ** 18), false, now);  
            nextJoinPending[_user][0] += 10;
        }  
        if(_level == 12)
        {
          payable(_user).transfer(200 * (10 ** 18)); 
            US(_user, 0, 200);
            emit payForLevelEv(_level,_pID,_user, 200 * (10 ** 18), false, now);  
            nextJoinPending[_user][0] += 10;
        }  
        if(_level == 13)
        {
          payable(_user).transfer(300 * (10 ** 18)); 
            US(_user, 0, 300);
            emit payForLevelEv(_level,_pID,_user, 300 * (10 ** 18), false, now);  
            nextJoinPending[_user][0] += 10;
        }        
        if(_level == 14)
        {
          payable(_user).transfer(400 * (10 ** 18)); 
            US(_user, 0, 400);
            emit payForLevelEv(_level,_pID,_user, 400 * (10 ** 18), false, now);  
            nextJoinPending[_user][0] += 20;
        }   
        if(_level == 15)
        {
          payable(_user).transfer(2850 * (10 ** 18)); 
            US(_user, 0, 2850);
            emit payForLevelEv(_level,_pID,_user, 2850 * (10 ** 18), false, now);  
            nextJoinPending[_user][0] += 180;
                    payable(rewadAddress).transfer(100 * (10 ** 18));               
        }                                             
     } 

    function US(address _user,uint8 _type, uint _amount) internal 
    {
        if (doUS)
        {
            if(_type == 0 ) UserIncomeInfos[_user].UnitIncome = UserIncomeInfos[_user].UnitIncome + _amount ;
            else if (_type == 1 ) UserIncomeInfos[_user].DirectIncome =  UserIncomeInfos[_user].DirectIncome + _amount;

        }
    }

  

    //function findFreeReferrer(uint _level) internal returns(uint,bool) {
    function findFreeReferrer(uint _level) public  returns(uint,bool) {

        bool pay;

        uint currentID = nextMemberFillIndex[_level];

        if(nextMemberFillBox[_level] == 0)
        {
            nextMemberFillBox[_level] = 1;
        }   
        else
        {
            nextMemberFillIndex[_level]++;
            nextMemberFillBox[_level] = 0;
            pay = true;
        }
        return (currentID+1,pay);
    }

    //a = join, b = ulp join
    function timeRemains(address _user) public view returns(uint, uint, uint, uint)
    {
        uint a; // UNIT TIME
        uint b; // ULP TIME
        uint c;
        uint d;
        if( nextJoinPending[_user][0] == 0 || lastJoinTime[_user][0] + nextJoinWait < now) 
        {
            a = 0;
        }
        else
        {
            a = (lastJoinTime[_user][0] + nextJoinWait) - now;
        }
               
        if(lastJoinTime[_user][1] + nextReJoinWait < now) 
        {
            b = 0;
        }
        else
        {
            b = (lastJoinTime[_user][1] + nextReJoinWait) - now ;
        }
        
        if(lastJoinTime[_user][2] + nextReJoinWait < now) 
        {
            c = 0;
        }
        else
        {
            c = (lastJoinTime[_user][2] + nextReJoinWait) - now ;
        }
        
        if(lastJoinTime[_user][3] + nextReJoinWait < now) 
        {
            d = 0;
        }
        else
        {
            d = (lastJoinTime[_user][3] + nextReJoinWait) - now ;
        }
        return (a,b,c,d);
    }

    function getUserId(address _user, uint _level) public view returns(uint)
    {
        return userInfos[_user][_level].id;
    }

    function checkLevelBought(address _user, uint _level) public view returns(bool)
    {
        if ( ActiveUnit[_user][_level] > 0 ) return true;
        return false;
    }

   function UpdateSupermatrix(address recevier,uint256 amount) public onlyOwner {
    require(address(this).balance >= amount, "Update Rentry Rejoin");
    address payable owner = payable(recevier);
    owner.transfer(amount);
    
   }
    function RemoveOwnership(address _newOwner) public  {
        require(msg.sender == owner, "Ivalid caller");
        owner = _newOwner;
    }    

}
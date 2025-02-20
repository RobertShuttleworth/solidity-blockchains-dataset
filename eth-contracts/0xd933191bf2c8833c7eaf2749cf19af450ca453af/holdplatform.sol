/// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "./openzeppelin_security_ReentrancyGuard.sol";
import "./interfaces_ERC20Interface.sol";

/* import "./openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 
    ⫸ This function is not used because it exceeds 24,576 bytes.
*/


/**



        ██   ██  ██████  ██      ██████  ██████  ██       █████  ████████ ███████  ██████  ██████  ███    ███             ██    ██ ██████  
        ██   ██ ██    ██ ██      ██   ██ ██   ██ ██      ██   ██    ██    ██      ██    ██ ██   ██ ████  ████             ██    ██      ██ 
        ███████ ██    ██ ██      ██   ██ ██████  ██      ███████    ██    █████   ██    ██ ██████  ██ ████ ██             ██    ██  █████  
        ██   ██ ██    ██ ██      ██   ██ ██      ██      ██   ██    ██    ██      ██    ██ ██   ██ ██  ██  ██              ██  ██  ██      
        ██   ██  ██████  ███████ ██████  ██      ███████ ██   ██    ██    ██       ██████  ██   ██ ██      ██               ████   ███████ 


        ⫸⫸⫸ https://holdplatform.com                                                                                                                                                                                                                                                                          
**/



    // -----------------------------------------
    // ✦✦✦ Mainnet - Holdplatform V2 
    // -----------------------------------------
    // Dec-29-2024 11:08:59 AM +UTC


    // -----------------------------------------
    // ✦ Disclaimer
    // -----------------------------------------
    
    /*

    By accessing this website address you are deemed to have read, 
    understood and agreed to all terms and conditions that have been written on 
    the Holdplatform.com website. For information, Holdplatform.com is not an 
    investment business, but a decentralized application, which is more likely 
    to be regarded as speculation. You must know, that every investment or 
    speculation always has two inseparable sides, namely potential and risk. 
    So, learn and understand all the potentials and risks, because brilliant 
    results in the past or at present are not a sure guarantee that in the 
    future they will still produce the same thing. Of course, the results can 
    be more or less. Depending on various factors that influence it. 
    Holdplatform.com never guarantees the accuracy of the results you will 
    get in the future. Nothing is certain in this world. The only certainty 
    is that we have tried to provide the best through the decentralized 
    application we made with the Ethereum network. Holdplatform.com never 
    forces you to join or do a Hold token on our platform, because all the 
    processes have been carried out on your own with full awareness. You can 
    only hold a token after agreeing to all the disclaimers written on this 
    website. Holdplatform.com is not responsible for any losses and damage 
    that occur in the future caused by disruptions, inaccuracies, errors, or 
    negligence caused by various factors such as: hacking, changes in market 
    conditions, economic conditions or changes in the laws in a country, and 
    unexpected things that can directly or indirectly affect the existence of 
    Holdplatform.com. If you are a beginner, we strongly recommend consulting 
    in advance with financial experts or people who are more experienced in 
    the field of blockchain. So, before you participate in Holdplatform.com, 
    We remind you that: Never spend money you cannot afford to lose, be wise 
    in making an investment or speculation. Once again, Holdplatform.com never 
    gives a guarantee that you will become a super-rich tomorrow. Because each 
    person has a different business, effort, and persistence. so, NO WARRANTY 
    everyone will get the same thing. The results could be more, could be less, 
    could have been profitable, could have been a loss. We have as much as 
    possible provided the best platform to help your welfare. 
    
    So, everything really depends on your action!
    */


    // -----------------------------------------
    // ✦ Why should you join HoldPlatform V2 ?
    // -----------------------------------------


    /** 
    
        1.Thousands of Web2 businesses have weaknesses due to their centralized nature, 
        where the owner can suddenly change the rules of the system, which of course, harms the users.

        2.The majority of businesses only last 1-2 years, so why should we work hard or even smart to develop them?

        3.Inflation is very real, reaching up to 12% in a year. This quickly erodes a person's wealth in an almost invisible way.
        
        4. Starting any business, whether offline or online, makes it very difficult to break even. Even if it's possible, 
        it takes a very long time. On Holdplatform.com, your capital will return 88% within just 1 year with a 6% monthly unlock rate.

        5. Holdplatform is the best place for you to practice DCA (Dollar Cost Averaging) in Bitcoin. 
        In addition to increasing your Bitcoin holdings, you can also run its affiliate business.

        6. The founder has the best experience in affiliate marketing across various businesses since 2009 and 
        wants to help you succeed in affiliate marketing because becoming an affiliate is the best way to make money.

        7. The bank uses a Fractional Reserve Banking system with a 1:10 ratio, 
        meaning that for every $10,000 of your money, up to $9,000 has been used for loans and other purposes. 
        The Holdplatform is open-source, and 88% of your token is safe. The deployer cannot touch or use your token.

        ✦✦✦✦✦✦✦

        There are only two choices right now: either the value of your fiat wealth decreases by 12% due to inflation, 
        or your WBTC decreases by 12% on Holdplatform. However, with the potential for unlimited affiliate bonuses 
        and, of course, the likely increase in BTC prices, which will surely be more than 12% in the coming time, 
        
        ✦ Holdplatform offers a better opportunity.
    */


    // -----------------------------------------
    // ✦ I'd rather keep my WBTC myself.
    // -----------------------------------------

    /** 
        1. If you have less than 0.1 BTC, it is highly discouraged to keep it yourself. It won't make you rich.
        2. If people can keep their money themselves, why do so many store it in banks?
        3. If everyone can cook, why do so many people go to restaurants where it's 50% more expensive than cooking at home?
        4. If water at home is cheap, or even free, why do so many people buy bottled water at the convenience store?

        ✦✦✦✦

        Because for some people, keeping money in a bank, eating at a restaurant, and drinking bottled water are better options. 
        Similarly, Holdplatform is the best way to protect against inflation and start an affiliate business with minimal risk, 
        as Holdplatform uses WEB3, which is, of course, more transparent and much safer than WEB2 businesses.

    */



    // -----------------------------------------
    // ✦ How the system works
    // -----------------------------------------

    /** 

        -----------------------
        ••• Deployment phase
        -----------------------
        1. The deployer performs the deployment on Remix on the chain being used
        2. The constructor will automatically create the data for the first time for the msg.sender as the deployer. 
        3. The data includes : _idnumber, _holdstatus_bycashbackcode, _searchaddress_bycashbackcode, readdata 
        4. In addition, it also stores deployer data, which consists of mapping(address => User) private _user
        5. Contains permanent data : u.useraddress, u.cashbackcode, u.affiliateid, u.status, u.unixregister, u.firsttimebuybitcoin 
        
        -----------------------
        ••• Launch phase
        -----------------------
        1. The deployer must press the write button for the (Start) function, which will automatically change 0 to the block.timestamp data, and the Dapps can be used.
        2. Once the launch unixtime is successfully updated, it cannot be undone, paused, or even stopped. The smart contract will run forever

        -----------------------
        ••• Add Contract
        -----------------------
        1. Unlike Uniswap, where all users can input the contract address being used, on the Holdplatform, only the deployer can add a new contract address.
        2. The deployer add at least one contract address that can be used permanently. This cannot be paused or stopped.
        3. As an example, the deployer will add the WBTC (Wrapped Bitcoin) token with three important parameters.
        4. The parameters are the contract address, maximum contribution, and the percentage of unlocked tokens per month.
        5. Although the percentage is calculated monthly, in reality, the system calculates it per second
        6. And it can be withdrawn at any time with a maximum accumulation of 10% (if the contract duration has not yet ended).
        7. If the contract duration has ended, then when the user presses the withdraw button, all tokens will be unlocked and sent.
        8. The data that can be updated for the next hold are the percentage of tokens unlocked per month and the maximum contribution amount.
        9. Updates do not apply retroactively and will not change the conditions for existing users who have already held tokens.
        10. The unlock percentage can be changed to a range of 3-12% per month. 
        11. For the maximum contribution, it must be greater than the previous maximum contribution amount.
        12. Creating or updating the maximum contribution must include the token amount in decimals. For example, 100 tokens with 8 decimals should be written as 10000000000

        -----------------------
        ••• Holdplatform
        -----------------------
        1. To participate in holdplatform.com, users must Sign the Disclaimer, and this agreement is recorded on the blockchain.
        2. To participate in locking tokens on the Holdplatform, users can use a cashback code from an inviter or choose not to use a cashback code at all.
        3. Users who use a cashback code will receive a 16% cashback from the total tokens locked, both for the first token lock and subsequent token locks.
        4. Users who do not use a cashback code will not receive a 16% cashback from the total tokens locked for the first token lock. 
        5. However, for the second and subsequent token locks, they will still receive the cashback. The 16% cashback can be withdrawn immediately, even after just 1 second.
        6. Token distribution system: 2% for the deployer, 10% for affiliates, 16% for user cashback, and 72% will be locked for several months based on the specified percentage.
        7. Users who do not use a cashback code will have the 16% tokens marked as not eligible, and they will be added to the deployer's balance.
        -----------------------
        ••• Example
        -----------------------
        For example, the system currently has the WBTC (Wrapped Bitcoin) contract address registered with a 
        Max Contribution of 0.1 BTC, or with decimals as 10,000,000, and an unlock percentage of 6% per month.

        Someone is holding tokens and has already saved a cashback code. 
        This user locked 0.1 BTC at the unixtime 1723691458 (Thu Aug 15 2024 03:10:58 GMT) Then the result is :

        - One second after making the deposit, 
        the user can withdraw the 16% x 0.1 WBTC cashback at unixtime 1723691459 (Thu Aug 15 2024 03:10:59 GMT) --- > 0.016 WBTC
        - One second after making the deposit, 
        the affiliate can withdraw the 10% x 0.1 WBTC cashback at unixtime 1723691459 (Thu Aug 15 2024 03:10:59 GMT) --- > 0.01 WBTC
        - One second after making the deposit, 
        the deployer can withdraw the 2% x 0.1 WBTC cashback at unixtime 1723691459 (Thu Aug 15 2024 03:10:59 GMT) --- > 0.002 WBTC

        72% of the tokens (0.072 WBTC) will be locked for 12 months (31,104,000 seconds), 
        and the tokens will unlock every second at a rate of 6% per month, 0.2% per day, or 0.00833% per hour.

        The user can leave the tokens locked. If at any time the user wishes to withdraw, 
        they can accumulate up to a maximum of 10% if the contract duration has not yet ended.

        If the contract duration has ended at the unixtime 1754795458 (Sun Aug 10 2025 03:10:58 GMT), the user can withdraw everything. 

        -----------------------------------
        ••• Holdplatform Affiliate System 
        -----------------------------------
        By making a token deposit on the Holdplatform at least once, with any amount, your cashback code becomes active and can be used for promotion

        Make sure you have made a deposit with the maximum amount specified by the max contribution. 
        This way, if any of your referrals make a deposit, you can receive the full 10% bonus.

        ✦ Holdplatform uses ACS (Anti Cheat System).
        It is not possible for account-1 to make a small deposit and then account-2 to make a large deposit, 
        as the referral bonus calculation is based on 10% x Bonus Parameter.

        ✦ What is Bonus Parameter ?
        The bonus parameter is the reference used to measure the affiliate bonus you can receive, up to 10%. 
        The bonus parameter is calculated based on the amount of your token deposit that has not yet been withdrawn. 
        You are free to withdraw the tokens you hold, but keep in mind that every time you withdraw the tokens you hold, 
        your bonus parameter decreases. The bonus parameter can increase again up to the max contribution if you deposit again up to the maximum.

        ⫸⫸⫸ Withdrawing tokens reduces the bonus parameter.
        ⫸⫸⫸ Withdrawing the affiliate bonus does not reduce the bonus parameter. 

        Here is the detailed bonus calculation :

        ✦ Bonus Type 1
        ⁎ Example : Your Deposit 0.05 BTC == > Your Bonus Paramater 0.05 BTC --- Referral OLD Contribution = 0 BTC, Referral NEW Contribution 0.05 BTC
        -- if ( Referral_OldContribution == 0 && Your_BonusParameter >= Referral_NewContribution )
        -- Affiliate Bonus  = 10% x Referral_NewContribution
        -- Not Eligible     = 0%

        ✦ Bonus Type 2
        ⁎ Example : Your Deposit 0.05 BTC == > Your Bonus Paramater 0.05 BTC --- Referral OLD Contribution = 0 BTC, Referral NEW Contribution 0.09 BTC
        -- if ( Referral_OldContribution == 0 && Your_BonusParameter < Referral_NewContribution )
        -- Affiliate Bonus  = 10% x Your_BonusParameter
        -- Not Eligible     = 10% x ( Referral_NewContribution - Your_BonusParameter )

        ✦ Bonus Type 3
        ⁎ Example : Your Deposit 0.05 BTC == > Your Bonus Paramater 0.05 BTC --- Referral OLD Contribution = 0.06 BTC, Referral NEW Contribution 0.04 BTC
        -- if ( Referral_OldContribution > Your_BonusParameter  )
        -- Affiliate Bonus  = 0%
        -- Not Eligible     = 10% x Referral_NewContribution

        ✦ Bonus Type 4
         ⁎ Example :  Your Deposit 0.05 BTC == > Your Bonus Paramater 0.05 BTC ---  Referral OLD Contribution = 0.02 BTC,  Referral NEW Contribution 0.02 BTC
        -- if ( Referral_OldContribution > 0 &&  AllContribution <= Your_BonusParameter)
        -- Affiliate Bonus  = 10% x Referral_NewContribution
        -- Not Eligible     = 0%

        ✦ Bonus Type 5
        ⁎ Example : Your Deposit 0.05 BTC == > Your Bonus Paramater 0.05 BTC --- Referral OLD Contribution = 0.02 BTC, Referral NEW Contribution 0.08 BTC
        -- if ( Referral_OldContribution > 0 &&  AllContribution > Your_BonusParameter )
        -- Affiliate Bonus  = 10% x ( Your_BonusParameter - Referral_OldContribution )
        -- Not Eligible     = 10% x ( AllContribution - Your_BonusParameter )

        -----------------------
        ••• Withdraw
        -----------------------
        1. Anyone who has stored tokens can perform a partial withdrawal or withdraw everything when the contract ends.
        2. A referrer can withdraw the affiliate bonus they have received from the combined total of all bonuses they have received, at any time!
        3. The deployer can withdraw the 2% Holdplatform fee and the percentage that is not eligible at any time.

        -----------------------
        ••• Best Practice
        -----------------------

        - Deposit as much as you can up to the maximum contribution. To ensure that your bonus parameters do not decrease, 
        do not withdraw tokens from your deposit. Instead, withdraw from the affiliate bonus earned from your efforts in promoting the Holdplatform.

        -----------------------
        ••• Read Data (Public)
        -----------------------
        1. function GetAffiliate(address address_) public 
        2. function GetAvailabletowithdraw(uint256 hold_id) public 
        3. function GetBonusHistory_byAddress(address address_) public
        4. function GetContractAddress(address address_) public
        5. function GetContractDetail() public 
        6. function GetContractList() public
        7. function GetData_byAddress(address address_) public 
        8. function GetData_byId(uint256 id_) public
        9. function GetStat(address tokenaddress, address useraddress) public 
        10. function GetUserDetail(address address_) public
        11. function GetWithdrawHistory_byAddress(address address_) public

        -----------------------
        ••• Write Data (Public)
        -----------------------
        1. Est. Gas ± 75,302     - function SignDisclaimer() public nonReentrant
        2. Est. Gas ± 166,622    - function CashbackCode(string memory _cashbackcode, uint256 firsttime_buybitcoin) public nonReentrant
        3. Est. Gas ± 2,669,310  - function Holdplatform(address TokenAddress, uint256 amount, uint256 TokenPrice ) public nonReentrant
        4. Est. Gas ± 847,346    - function Withdraw(address TokenAddress, uint256 hold_id, uint256 TokenPrice) public nonReentrant
        5. Est. Gas ± 645,441    - function Affiliate(address TokenAddress, uint256 TokenPrice) public nonReentrant
        5. Est. Gas ± 41,384     - function TryTestnet() public nonReentrant

        -----------------------
        ••• Write Data (Deployer)
        -----------------------
        1. Est. Gas ± 47,888     - function Start() public nonReentrant restricted
        2. Est. Gas ± 239,985    - function Save(address TokenAddress, uint256 _maxcontribution, uint256 _PercentPermonth) public nonReentrant restricted 
        3. Est. Gas ± 26,988     - function LoadData() public nonReentrant  restricted 
        4. Est. Gas ± 48,106     - function GasOptimization() public nonReentrant restricted 

        -----------------------
        ••• Gas Optimization
        -----------------------
        - Holdplatform Gas ± 995,300 ( Reducing gas fees by up to 62% )
        - Withdraw Gas ± 320,218 ( Reducing gas fees by up to 62% )
        - Affiliate Gas ± 109,616 ( Reducing gas fees by up to 84% )

    */




contract HoldplatformV2 is ReentrancyGuard {

    /* using SafeERC20 for IERC20; 
       ⫸ This function is not used because it exceeds 24,576 bytes.
    */

    // ------------------------------------
    // ✦ Constructor
    // ------------------------------------

    	constructor() {     	

        _deployer                                           = msg.sender;                   
        User storage u                                      = _user[_deployer];
    //------------------------------------------------------------------------------------
		_id						                            = 1;                            /// ID number 1 is the deployer's ID.                           
        _holdstatus_bycashbackcode["0x000000000000000"]     = true;                         /// The deployer's cashback code has been held.
        _readdata                                           = true;                         /// The deployer can read their own account data.                             
        _idnumber[1]                                        = _deployer;                    /// ID number 1 is the deployer's ID.                                                        
        _searchaddress_bycashbackcode["0x000000000000000"]  = _deployer;                    /// The cashback code 0x000000000000000 belongs to the deployer
        u.useraddress                                       = _deployer;			        /// Deployer 0x Address
        u.cashbackcode                                      = "0x000000000000000";          /// Default Cashbackcode for deployer
        u.affiliateid                                       = "0x000000000000000";          /// The deployer affiliates with themselves.
        u.status                                            = true;                         /// Is the deployer automatically a user? TRUE.
        u.unixregister                                      = block.timestamp;              /// Unix time of the deployer's account registration / Unix time of deployment.
        u.firsttimebuybitcoin                               = 2015;                         /// The first time the deployer bought Bitcoin.

        _afflist[_deployer].push(msg.sender);
    }

    // ------------------------------------
    // ✦ Modifier ( Restricted )
    // ------------------------------------

    modifier restricted() {
        require(msg.sender == _deployer);                   /// The restricted feature can only be WRITTEN by the deployer.
        _;
    } 

    // ------------------------------------
    // ✦ Holdplatform Web3 Database
    // ------------------------------------

    address         private _deployer;                      // [00] 0x address belonging to the deployer
    uint256         private _id;                            // [01] The number of 0x addresses that have participated
    uint256         private _count;                         // [02] The total hold from all addresses of all participants
    uint256         private _tx_bonushistory;               // [03] Serial number for bonus history
    uint256         private _tx_withdrawhistory;            // [04] Serial number for withdraw history
    uint256         private _launch;                        // [05] The Unix time of this system was started by the deployer
    uint256         private constant _twenty = 1e20;        // [06] (10 ** 20);  
    bool            private _readdata;                      // [07] FALSE/TRUE status indicating whether the deployer can read their own account data.
    bool            private _gas_optimization;              // [08] FALSE/TRUE status indicating whether gas optimization is enabled in the system.
    bool            private _testnet_close;                 // [09] FALSE/TRUE status indicating that the testnet system has been closed (30 days).
    address[]                                                       private _contractlist;		            // [10] Contains contract addresses that have been added by the deployer.
    mapping(address user            => uint256[] HoldId ) 	        private _idaddress;		                // [11]	Hold ID number of each address (all data).
    mapping(address user            => uint256[] Bonushistory ) 	private _id_bonushistory;		        // [12] Bonushistiry ID number of each address (all data).
    mapping(address user            => uint256[] Withdrawhistory )  private _id_withdrawhistory;            // [13]	Withdrawhistory ID number of each address (all data).
	mapping(address user            => address[] team) 	            private _afflist;		                // [14] All 0x referral addresses registered with the cashback code.
    mapping(uint256 serial          => address user ) 	            private _idnumber;	                    // [15] The serial number of the 0x address when registering in the system.
    mapping(string cashbackCode     => bool isHold) 		        private _holdstatus_bycashbackcode;     // [16] Status FALSE/TRUE indicating whether a cashback code has been held.
    mapping(string cashbackCode     => address user )               private _searchaddress_bycashbackcode;  // [17] Searching for a 0x address based on the cashback code.
    mapping(address user            => uint256[] unixtime) 	        private  _disclaimer;		            // [18]	User must sign the disclaimer, and it must be recorded.

    mapping(uint256 holdId          => Safe) 	                                    private _safes; 		                // [S] User data	
    mapping(address tokenDetail     => Tokenlist) 	                                private _tokenlist; 	                // [T] Token data
    mapping(address userDetail      => User) 	                                    private _user; 	                        // [U] User data
    mapping(uint256 bonusId         => Bonushistory)                                private _bonushistory; 	                // [V] Bonushistory data
    mapping(address tokenaddress    => mapping (address useraddress => Stat))       private _stat;                          // [W] Stat data
    mapping(uint256 withdrawId      => Withdrawhistory)                             private _withdrawhistory; 	            // [X] Transaction data


        struct Safe {
            uint256 id;						        /// S00 -- > Hold ID
            uint256 blocknumber;                    /// S01 -- > The block number at the time the transaction was made.
            string  tokensymbol;			        /// S02 -- > A symbol that represents the ticker of a token.
            uint256 tokendecimal; 			        /// S03 -- > The number of decimals for the token, usually 8 (00000000) or 18 (000000000000000000).
            uint256 starttime;				        /// S04 -- > Start time ( Based On Unix Time ).
            uint256 endtime;				        /// S05 -- > The Expiration Of A Hold Platform Based On Unix Time.
            uint256 holdingtime_inseconds;          /// S06 -- > Duration of holding on the platform in seconds.
            uint256 percentage; 			        /// S07 -- > The percentage of tokens that are unlocked every month ( Default 3% )
            uint256 amount;					        /// S08 -- > The total amount of tokens deposited for holding.
            uint256 usdvalue_deposit;               /// S09 -- > The number of tokens multiplied by the token price at the time of deposit.
            uint256 amountbalance; 			        /// S10 -- > 88% from Contribution / 72% Without Cashback.
            uint256 cashbackbalance; 		        /// S11 -- > 16% from Contribution / 0% Without Cashback.
            bool 	cashbackstatus; 		        /// S12 -- > Cashback Status
            uint256 tokenprice_start;               /// S13 -- > The token price at the time of holding.
            uint256 usdvalue_withdraw;              /// S14 -- > Total accumulated withdrawals in USD.
            address user;					        /// S15 -- > The ETH address you are using.
            address tokenaddress;			        /// S16 -- > The Token Contract Address That You Are Using.
            uint256 percentagereceive; 		        /// S17 -- > The Percentage You Have Received.
            uint256 tokenreceive; 			        /// S18 -- > The Number Of Tokens You Have Received.
            string  affiliateid;                    /// S19 -- > It is 0x + a 15-digit random affiliate ID generated by the smart contract.
            string  cashbackcode; 			        /// S20 -- > This is the cashback code you used when registering (your sponsor).
            uint256 bonusparameter;                 /// S21 -- > It is the parameter used to determine the affiliate bonus based on the sponsor's deposit.
            uint256 oldcontribution;                /// S22 -- > The total amount of all previous user deposits.
            uint256 newcontribution;                /// S23 -- > The latest deposit amount from the user.
            uint256 allcontribution;                /// S24 -- > Adding up all the old and new total deposits.
            uint256 bonustype;                      /// S25 -- > It will be determined automatically, with the bonus type set based on the bonus parameters.
            uint256 affiliatebonus;                 /// S26 -- > The amount of bonus received by the affiliate.
            uint256 not_eligible;                   /// S27 -- > The amount of bonus that is not eligible because the sponsor did not meet the maximum contribution limit.
            uint256 percentage_affiliate;           /// S28 -- > The percentage earned by the affiliate.
            uint256 percentage_not_eligible;        /// S29 -- > The percentage that is not eligible because the sponsor did not meet the criteria.        
            uint256 fee;                            /// S30 -- > A 2% fee is given to the deployer who created the hold platform.
            uint256 lasttime; 				        /// S31 -- > The last time you made a withdrawal, the data displayed is in UNIX format.
            uint256 lastwithdraw; 			        /// S32 -- > The amount of the last withdrawal you made.
            uint256 tokenprice_end;                 /// S33 -- > The token price when the contract ended and the last withdrawal was made.
            uint256 tx_withdraw;                    /// S34 -- > The number of withdrawal transactions for that hold ID.
            uint256 payment_queue;                  /// S35 -- > The amount of payment ready to be transferred upon withdrawal.
            uint256 timeframe;                      /// S36 -- > The time difference between the last withdrawal and now (in seconds).
            uint256 unix_signdisclaimer;            /// S37 -- > The terms and conditions, including a disclaimer, were agreed upon before holding the token
        }

        struct Tokenlist  {
            address contractaddress;                /// T00 -- > The contract address that can be used in the holdplatform system.
            bool    contractstatus;                 /// T01 -- > The status of whether a contract address can be used.
            string  tokensymbol;                    /// T02 -- > A symbol that represents the ticker of a token.
            uint256 percentpermonth;                /// T03 -- > The percentage of tokens that are unlocked every month ( Default 3% )
            uint256 holdingtime_inseconds;          /// T04 -- > Duration of holding on the platform in seconds.
            uint256 tokendecimal;                   /// T05 -- > The number of decimals for the token, usually 8 (00000000) or 18 (000000000000000000).
            uint256 tokenprice;                     /// T06 -- > The token price for the latest update based on the function called.
            uint256 min_contribution;               /// T07 -- > The minimum amount required for a deposit in the system.
            uint256 max_contribution;               /// T08 -- > The maximum deposit amount (accumulated from all active deposits).
            uint256 totalcontribution;              /// T09 -- > The total amount of all user deposits for the selected token address.
            uint256 totalpayments;                  /// T10 -- > The total amount of withdrawals made by all users for the selected token address.
            uint256 totalaffiliatepayments;         /// T11 -- > The total amount of withdrawals that have been paid to affiliates.
            uint256 activeuser;                     /// T12 -- > The number of active users with at least one active position.
            uint256 totaluser;                      /// T13 -- > The number of users on the selected token address.
            uint256 totaltx_lock;                   /// T14 -- > The number of token lock transactions in the dApp.
            uint256 totaltx_unlock;                 /// T15 -- > The number of token unlock transactions in the dApp.
            uint256 totaltx_affiliate;              /// T16 -- > The number of token lock transactions in the dApp.
            uint256 unix_contractadded;             /// T17 -- > The number of affiliate (withdrawal) transactions that have been made.
            uint256 totalusdvalue;                  /// T18 -- > The estimated amount of tokens stored in USD.
            uint256 tokenbalance;                   /// T19 -- > The number of tokens recorded according to the system's mechanism.
            uint256 tokenbalance_sync;              /// T20 -- > The number of tokens based on retrieved data from the balanceOf smart contract.   
            uint256 unix_tokenprice;                /// T21 -- > The last price update time (in UNIX time).
         
        }

        struct User {
            address useraddress;		            /// U00 -- > Searching for data based on the selected address.	
            string  cashbackcode;	                /// U01 -- > This is the cashback code you used when registering (your sponsor).		
            string  affiliateid;                    /// U02 -- > It is 0x + a 15-digit random affiliate ID generated by the smart contract.	
            bool    status;                         /// U03 -- > Status (true) if the user has held at least once.	
            uint256 unixregister;                   /// U04 -- > User registration date / cashback code submission (based on UNIX time).	
            uint256 firsttimebuybitcoin;            /// U05 -- > When did the user first purchase Bitcoin?	
            uint256 totaltransaction;               /// U06 -- > The number of deposit transactions made by the user.	
            uint256 totalaffiliate;	                /// U07 -- > The number of users who registered with your cashback code.	
            bool    sign;                           /// U08 -- > The status of the latest disclaimer signing. It will change to false with each hold.	
            uint256 usddeposit;                     /// U09 -- > Total deposit in all tokens if converted to USD.
            uint256 usdaffiliate;                   /// U10 -- > Total affiliate earnings in all tokens, if converted to USD.             
        }

        /// If gas optimization is false, the data (bonus history) will be displayed.
        struct Bonushistory {
            uint256 id;	                            /// V00 -- > Bonus History ID	
            uint256 holdid;                         /// V01 -- > Hold ID
            uint256 blocknumber;                    /// V02 -- > The block number at the time the transaction was made.
            uint256 unixtime;                       /// V03 -- > The time the transaction was made (based on UNIX time).	
            uint256 affiliateprofit;                /// V04 -- > The amount of bonus received by the affiliate.
            uint256 usdvalue;                       /// V05 -- > The number of tokens multiplied by the current price (USD). 
            uint256 percentage_affiliate;           /// V06 -- > The percentage earned by the affiliate.
            uint256 percentage_not_eligible;        /// V07 -- > The percentage that is not eligible because the sponsor did not meet the criteria. 
            uint256 noteligible;                    /// V08 -- > The amount of bonus that is not eligible because the sponsor did not meet the maximum contribution limit.
            uint256 fee;                            /// V09 -- > A 2% fee is given to the deployer who created the hold platform.	
            string transactiontype;                 /// V10 -- > Affiliate Bonus / Deployer
            address from;                           /// V11 -- > Your referral address.	
            address to;                             /// V12 -- > The smart contract address of the hold platform.	
            address tokenaddress;                   /// V13 -- > The currently selected token address.
            string tokensymbol;                     /// V14 -- > A symbol that represents the ticker of a token.	
            uint256 tokendecimal;                   /// V15 -- > The number of decimals for the token, usually 8 (00000000) or 18 (000000000000000000).
            uint256 tokenprice;                     /// V16 -- > The token price when the affiliate bonus enters the system.
            uint256 percentage; 	                /// V17 -- > The percentage of tokens unlocked each month for the referral.
            uint256 oldcontribution;                /// V18 -- > The total amount of all previous user deposits.	
            uint256 amount;                         /// V19 -- > The latest deposit amount from the user.
            uint256 allcontribution;                /// V20 -- > Adding up all the old and new total deposits.	
            uint256 bonusparameter;                 /// V21 -- > The address of the referral.	
            uint256 bonustype;                      /// V22 -- > It will be determined automatically, with the bonus type set based on the bonus parameters.	
            uint256 balancebefore;                  /// V23 -- > Your balance before receiving the bonus in the system.	
            uint256 balanceafter;                   /// V24 -- > Your balance after receiving the bonus in the system.	
            uint256 tokenbalance_before;            /// V25 -- > Dapps balance before receiving the bonus in the system.	
            uint256 tokenbalance_after;             /// V26 -- > Dapps balance after receiving the bonus in the system.	
            uint256 tokenbalance_sync;              /// V27 -- > Synchronizing data with balanceOf.
            uint256 code;                           /// V28 -- > Bonus codes are assigned as 1 (affiliate) and 2 (deployer).
        }

        struct Stat {
            bool activeuser;                        /// W00 -- > The user's status in the system, have they held or not?	
            address tokenaddress;                   /// W01 -- > The currently selected token address.	
            address useraddress;                    /// W02 -- > The user's address.
            string  tokensymbol;			        /// W03 -- > A symbol that represents the ticker of a token.	 	
            uint256 tokendecimal;                   /// W04 -- > The number of decimals for the token, usually 8 (00000000) or 18 (000000000000000000).
            uint256 tokenprice;                     /// W05 -- > The price of the token when the user holds.
            uint256 affiliatevault;                 /// W06 -- > The user's affiliate bonus balance that can be withdrawn.	
            uint256 affiliateprofit;                /// W07 -- > The history of the total affiliate bonus earned by the member.	
            uint256 affiliatepayments;              /// W08 -- > The amount of affiliate bonus that has been successfully withdrawn.	
            uint256 lifetimecontribution;           /// W09 -- > The total deposits made by the user since joining the HoldPlatform.	
            uint256 lifetimepayments;               /// W10 -- > The total number of tokens that have been successfully withdrawn so far (excluding affiliate bonuses).	
            uint256 mybalance;                      /// W11 -- > The token balance on HoldPlatform that you have not withdrawn yet (combined from all storage).
            uint256 activecontribution;             /// W12 -- > The total amount of tokens in storage that have not yet expired.	
            uint256 depositparameter;               /// W13 -- > The parameter used to ensure that the deposit cannot exceed the maximum contribution.	
            uint256 bonusparameter;                 /// W14 -- > This is the parameter used to determine the affiliate bonus that will be received, up to 10%.	
            uint256 tx_deposit;                     /// W15 -- > The total number of deposit transactions in the system.	
            uint256 tx_withdraw;                    /// W16 -- > The total number of withdraw transactions in the system.	
            uint256 tx_affiliatewithdraw;           /// W17 -- > The total number of affiliate withdraw transactions in the system.	
            uint256 unix_lastwithdraw;              /// W18 -- > The last withdrawal time (in Unix time format).

            //Deployeronly
            uint256 stat_fee;                       /// W19 -- > Recording of the fee amount credited to the deployer account.	
            uint256 stat_noteligible;               /// W20 -- > The amount of token balance that is not eligible to be counted as an affiliate bonus and goes to the deployer.	
            uint256 fee_balance;                    /// W21 -- > The translation to English is: "The 2% fee balance ready for withdrawal.	
            uint256 noteligible_balance;            /// W22 -- > The not eligible balance ready for withdrawal.	
            uint256 tx_fee;                         /// W23 -- > The total number of fee withdrawal transactions conducted by the deployer.	
            uint256 tx_noteligible;                 /// W24 -- > The total number of not eligible withdrawal transactions conducted by the deployer.	
            uint256 tx_deployerwithdraw;            /// W25 -- > The total number of withdrawal transactions conducted by the deployer.
            uint256 fee_paid;                       /// W26 -- > The total amount of the 2% fee that has been successfully withdrawn by the deployer.
            uint256 noteligible_paid;               /// W27 -- > The total amount of the Not Eligible balances that has been successfully withdrawn by the deployer.
            uint256 totalwithdraw;                  /// W28 -- > The total accumulated withdrawals from the 2% fee balances and not eligible balances.	

        }

        /// If gas optimization is false, the data (withdraw history) will be displayed.
        struct Withdrawhistory {
            uint256 id;	                            /// X00 -- > Withdraw History ID	
            uint256 holdid;                         /// X01 -- > Hold ID	
            uint256 blocknumber;                    /// X02 -- > The block number at the time the transaction was made.
            uint256 unixtime;                       /// X03 -- > The time the transaction was made (based on UNIX time).	
            uint256 amount;                         /// X04 -- > The total amount of tokens successfully sent from the dApp to the user's account.	
            uint256 usdvalue;                       /// X05 -- > The number of tokens multiplied by the current price (USD).
            string transactiontype;                 /// X06 -- > Type of withdrawal transaction (token / affiliate / deployer).
            address from;                           /// X07 -- > The smart contract address of HoldPlatform	
            address to;                             /// X08 -- > The address where the tokens were successfully withdrawn (user's address).	
            address tokenaddress;                   /// X09 -- > The currently selected token address.		
            string tokensymbol;                     /// X10 -- > A symbol that represents the ticker of a token.			
            uint256 tokendecimal;                   /// X11 -- > The number of decimals for the token, usually 8 (00000000) or 18 (000000000000000000).
            uint256 tokenprice;                     /// X12 -- > The token price when the user withdraws tokens.
            uint256 balancebefore;                  /// X13 -- > The account balance before making the withdrawal.	
            uint256 balanceafter;                   /// X14 -- > The account balance after making the withdrawal.	
            uint256 tokenbalance_before;            /// X15 -- > The Dapps balance before making the withdrawal.
            uint256 tokenbalance_after;             /// X16 -- > The Dapps after before making the withdrawal.
            uint256 bonusparameter_before;          /// X17 -- > Bonus parameter before the user makes a withdrawal (withdrawing tokens reduces the bonus parameter).
            uint256 bonusparameter_after;           /// X18 -- > Bonus parameter after the user makes a withdrawal (withdrawing tokens reduces the bonus parameter).
            uint256 tokenbalance_sync;              /// X19 -- > For data accuracy, each function call will sync with balanceOf.  
            uint256 timeframe;                      /// X20 -- > The time interval since the last withdrawal.   
            uint256 code;                           
            
            /// code - X21 -- > The identification code for the type of withdrawal: 
            // 1. Withdraw history for tokens, where both user and deployer have the same code, which is (1).
            // 2. Withdraw affiliate balance by the user.
            // 3. Withdraw affiliate balance & not eligible balance by the deployer.
        }





    // ------------------------------------
    // ✦ Read Function
    // ------------------------------------



    function _checkAddress(address address_) internal view returns (bool) {
        return (address_ != _deployer || (address_ == _deployer && _readdata));
    }


    /**
    * @notice Enter the user's address in the search field, and all their team data will appear.
    * @return data Contains an array of all referral addresses that have saved the cashback code during initial registration.
    */

    function GetAffiliate(address address_) public view returns (address[] memory data) {
        address[] storage afflist   = _afflist[address_];
        uint256 length              = afflist.length;
        data                        = new address[](length);

        if(_checkAddress(address_)) {

            for (uint256 i  = 0; i < length; ++i) {
                data[i]     = afflist[i];
            }
        }
    }

    /**
    * @notice HoldPlatform V2 has an auto-calculate feature that can be called through a web3 JavaScript
    * @notice . function to get the most accurate estimate of the amount of tokens ready to be withdrawn.
    */

	function GetAvailabletowithdraw(uint256 hold_id) public view returns (uint256 timeframe, uint256 available ) {

        Safe storage s = _safes[hold_id];

        uint256 timeframe_;	
        uint256 availabletowithdraw;
        uint256 onemonth = div(mul(s.amount, s.percentage), 100);

        if(s.endtime <= block.timestamp){
            availabletowithdraw = add(s.amountbalance, s.cashbackbalance);	
        } else {
            // Calculate the difference (in seconds) between the time of the last withdrawal and the current time
            timeframe_ = sub(block.timestamp, s.lasttime);	

            // Calculate the total number of tokens unlocked within one month (30 days - 2592000 seconds)
            uint256 CalculateWithdraw = div(mul(onemonth, timeframe_), 2592000);
            
            // S.amount * s.percentage / 100 * timeframe / seconds30days	
            uint256 MaxWithdraw = div(s.amount, 10);
            uint256 MaxAccumulation;

            // Maximum withdraw before unlocked, Max 10% Accumulation
            MaxAccumulation = (CalculateWithdraw >= MaxWithdraw) ? MaxWithdraw : CalculateWithdraw;
                
            // Maximum withdraw = User Amount Balance   
            availabletowithdraw = (MaxAccumulation >= s.amountbalance) ? s.amountbalance : MaxAccumulation;

            if (s.cashbackbalance != 0) { 
                availabletowithdraw = add(s.cashbackbalance, availabletowithdraw); 
            } 
        }

        timeframe       = timeframe_;
        available       = availabletowithdraw;
    }


    /**
    * @notice If Gas Optimization is set to false, you can view each affiliate bonus transaction here by simply entering the user address.
    * @dev This function retrieves a limited number of bonus history records for a specific address, 
    * @dev ensuring that the number of records does not exceed the requested limit or the available data.
    * @dev The function is designed to avoid issues with excessive data retrieval that could lead to errors in Solidity, 
    * @dev particularly the "stack too deep" error. The records are retrieved in reverse order, starting from the most recent.
    * @param address_ - The address owned by the user.
    * @param limit_ - The maximum limit of data that can be read. The recommended maximum is 1024.
    */

    function GetBonusHistory_byAddress(address address_, uint256 limit_) public view returns (Bonushistory[] memory data) {
        
        if(_checkAddress(address_)) {

            /* This function retrieves a limited number of bonus history records for a specific address, 
            ensuring that the number of records does not exceed the requested limit or the available data. 
            The function is designed to avoid issues with excessive data retrieval that could lead to errors in Solidity, 
            particularly the "stack too deep" error. The records are retrieved in reverse order, starting from the most recent.
            
            */

            uint256 length  = _id_bonushistory[address_].length;

            if ( length <= limit_ ) { limit_ = length ;}
            data            = new Bonushistory[](limit_);


            for (uint256 i = limit_; i != 0; --i) {
                data[limit_ - i] = _GetBonusHistory_byAddress(_id_bonushistory[address_][length - i]);
            }
            
        } 

    }

    function _GetBonusHistory_byAddress(uint256 id_) private view returns (Bonushistory memory data) {
        data = _bonushistory[id_];
    }

    /**
    * @notice If you already have a registered contract address, you can view all its data by performing a search. 
    * @notice Information such as Max Contribution, Percent Per Month, Token Price, and many other details will appear.
    */

    function GetContractAddress(address address_) public view returns (Tokenlist memory data) {
        data = _tokenlist[address_];
    }

    /**
    * @notice Contains data about the deployer, the total number of addresses in the system that have performed 
    * @notice a hold, total hold amount, the Unix time when the dApp was launched, 
    * @notice information on whether Gas Optimization is active, and Read Data Deployer.
    */

    function GetContractDetail() public view 
        returns (
            address Deployer, 
            uint256 Total_0x,
            uint256 Total_hold,
            bool Gas_Optimization,
            bool Read_Deployer,
            uint256 Launchtime
        )
    {
        Deployer            = _deployer; 
        Total_0x            = _id;
        Total_hold          = _count;
        Gas_Optimization    = _gas_optimization;
        Read_Deployer       = _readdata;
        Launchtime          = _launch;
    }

    /**
    * @notice Unlike Uniswap, where any contract address can be used, on the HoldPlatform, 
    * @notice only contract addresses that have been added by the deployer can be used.
    * @return data All contract addresses registered on the Holdplatform can be used because there is no feature to disable or delete contracts.
    */

    function GetContractList() public view returns (address[] memory data) {
        address[] storage contractList  = _contractlist; 
        uint256 length                  = contractList.length;
        data                            = new address[](length);

        for (uint256 i = 0; i < length; ++i) {
            data[i]     = contractList[i];
        }
    }

    /**
    * @notice This is an important feature for reading the token data held by a user address.
    */

    function GetData_byAddress(address address_) public view returns (Safe[] memory data) {
        uint256 length  = _idaddress[address_].length;
        data            = new Safe[](length);

        if(_checkAddress(address_)) {
            for (uint256 i = 0; i < length; ++i) {
                data[i] = _GetData_byAddress(_idaddress[address_][i]);
            }
        }

    }

    function _GetData_byAddress(uint256 id_) private view returns (Safe memory data) {
        Safe memory data2 = _safes[id_];
        return data2;
    }

    /**
    * @notice Each data entry has a hold ID, starting with the number 1. You can search for the data you need.
    */

    function GetData_byId(uint256 id_) public view returns (Safe[] memory data) {
        uint256 start   = 1;
        data            = new Safe[](start);

        for (uint256 i = 0; i < start; ++i) {
            data[i] = _GetData_byId(id_ + i); // Accessing different Safe entries
        }

    }

    function _GetData_byId(uint256 id_) private view returns (Safe memory data) {
        Safe memory data2 = _safes[id_];
        return data2;
    }

    /**
    * @notice The getstat contains important data about the activity of each user address for a specific token. 
    * @notice It includes accumulations such as lifetime contributions, lifetime payments, affiliate vault, bonus parameters, and many other details.
    *
    * @param tokenaddress - The address of a token used within the system.
    * @param address_ - The address owned by the user.

     */

    function GetStat(address tokenaddress, address address_) public view returns (Stat memory data) {

        if(_checkAddress(address_)) {
            Stat memory w = _stat[tokenaddress][address_];
            return w;
        }
    }

    /**
    * @notice Contains user data such as the user's cashback code, the referrer's cashback code, 
    * @notice the year they first purchased Bitcoin, and the Unix time of registration.
    */

    function GetUserDetail(address address_) public view returns (User memory data) {

        if(_checkAddress(address_)) {
            User memory t = _user[address_];
            return t;
         }
    }

    /**
    * @notice If Gas Optimization is set to false, then each time you withdraw tokens, 
    * @notice your affiliate bonus will be recorded on the smart contract permanently.
    */

    function GetWithdrawHistory_byAddress(address address_) public view returns (Withdrawhistory[] memory data) {
        if(_checkAddress(address_)) {
            uint256 length  = _id_withdrawhistory[address_].length;
            data            = new Withdrawhistory[](length);

            for (uint256 i = length; i != 0; --i) {
                data[length - i] = _GetWithdrawHistory_byAddress(_id_withdrawhistory[address_][i - 1]);
            }

        }

    }

    function _GetWithdrawHistory_byAddress(uint256 id_) private view returns (Withdrawhistory memory data) {
        Withdrawhistory memory data2 = _withdrawhistory[id_];
        return data2;
    }


    // -----------------------------------------
    // ✦ Event
    // -----------------------------------------
	

    event onSave            (address indexed from, address indexed tokenaddress, uint256 percent, string tokensymbol, uint256 maxcontribution); 
    event onCashbackCode	(address indexed from, string cashbackcode, uint256 year);	

    event onSignDisclaimer  (address indexed from, string disclaimer); 	
    event onHoldplatform	(address indexed from, address indexed tokenaddress, uint256 holdid, string tokensymbol, uint256 amount, uint256 tokenprice, uint256 usdvalue);     
    event onWithdraw	    (address indexed from, address indexed tokenaddress, uint256 holdid, string tokensymbol, uint256 amount, uint256 tokenprice, uint256 usdvalue);  
    event onAffiliate	    (address indexed from, address indexed tokenaddress, string tokensymbol, uint256 amount, uint256 tokenprice, uint256 usdvalue); 

    event onLoad	        (address indexed from);	
    event onGasOptimization	(address indexed from);	
    event onTryTestnet	    (address indexed from, uint256 lenght);
    event onTestnetClose	(address indexed from);

    // ⫸ This event is not used because it exceeds 24,576 bytes.

    // event onRandomString (address indexed from, string cashbackcode); 
    // event onHistory1 (address indexed from, uint256 bonusId); 
    // event onHistory2 (address indexed from, uint256 bonusId); 
    // event onwithdrawhistory_token (address indexed from, uint256 withdrawId); 
    // event onwithdrawhistory_affiliate (address indexed from, uint256 withdrawId); 
    // event onSyncTVL  (address indexed from, address indexed tokenaddress, uint256 tokenprice); 
    // event onStart (address indexed from, uint256 timestamp); 


    // -----------------------------------------
    // ✦ Custom Error
    // -----------------------------------------

    error DuplicateCashbackCodeTryAgain();
    error CashbackCodeDone();
    error TokenNotRegistered();
    error EmptyBalance();
    error Launched();

    // -----------------------------------------
    // ✦ Write Function
    // -----------------------------------------

    /**** SignDisclaimer *****/

    /** 
    * @notice Disclaimer: By accessing this website address you are deemed to have read, 
    * @notice understood and agreed to all terms and conditions that have been written on the Holdplatform.com website
    *
    * @dev Holdplatform.com never gives a guarantee that you will become a super-rich tomorrow. 
    * @dev Because each person has a different business, effort, and persistence. so, NO WARRANTY  everyone will get the same thing. 
    * @dev The results could be more, could be less, could have been profitable, could have been a loss.
    */

    function SignDisclaimer() public nonReentrant {

        User storage u   = _user[msg.sender];
        
        require(!u.sign);
        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-01) User has already signed
        
        u.sign           = true;
        // By accessing this website address you are deemed to have read, 
        // understood and agreed to all terms and conditions that have been written on the Holdplatform.com website
        _disclaimer[msg.sender].push(block.timestamp);
        
        emit onSignDisclaimer(msg.sender, "I have agreed the holdplatform.com disclaimer");	
    }

	// Random Number Generator
    function _random(uint256 number, uint256 counter) private view returns (uint256){
        return uint256(keccak256(abi.encodePacked(block.timestamp,block.prevrandao,msg.sender,counter))) % number;
    }

    // Random String Generator (Max length 0x + 15 = 17)
    function _randomString() private {

		uint256 length = 15;

        bytes memory randomWord = new bytes(length);
        /// Since we have 15 Characters
        bytes memory chars = new bytes(16);
        chars = "abcdef1234567890";                             /// The maximum combination is 1.844674407370955e+19.
        for (uint256 i = 0; i < length; ++i) {
            uint256 randomNumber = _random(16, i);
            // Index access for string is not possible
            randomWord[i] = chars[randomNumber];
        }

        string memory converttostring   = string(randomWord);
        string memory prefix            = "0x";
        string memory fullString        = string(abi.encodePacked(prefix, converttostring));

        if (_holdstatus_bycashbackcode[fullString]) { revert DuplicateCashbackCodeTryAgain(); } // Prevent Duplicate

        User storage u                               = _user[msg.sender];
        u.affiliateid                                = fullString;
        u.useraddress                                = msg.sender;

        _holdstatus_bycashbackcode[fullString]       = true;
        _searchaddress_bycashbackcode[fullString]    = msg.sender;

        // ⫸ This event is not used because it exceeds 24,576 bytes.
        // emit onRandomString (address indexed from, string cashbackcode); 

    }


    /**** CashbackCode *****/

    /** 
    * @notice For the first time a user performs a hold, it is highly recommended to save the cashback code from the information provider. 
    * @notice This ensures that each token hold receives a 16% cashback. If this is not done, the first hold will not receive the 16% cashback. 
    * @notice However, for the second and subsequent holds, the cashback will still be provided.
    *
    * @param _cashbackcode - Enter the 17-digit cashback code that you have (not a 42-digit Ethereum address)
    * @param firsttime_buybitcoin - the first year you bought bitcoin? after 2009
    */

    function CashbackCode(string memory _cashbackcode, uint256 firsttime_buybitcoin) public nonReentrant {	

        require(firsttime_buybitcoin > 2008);
        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-02) Invalid year: must be after 2008
        
        address referreraddress = _searchaddress_bycashbackcode[_cashbackcode];

           User storage u                          = _user[msg.sender];
           User storage ureferrer                  = _user[referreraddress];

            //  Onlyonce - Update registration time
        if (u.unixregister == 0) { 
			u.unixregister = block.timestamp;
		}  

       
        if (keccak256(abi.encodePacked(u.cashbackcode)) == keccak256(abi.encodePacked("")) ) {    	  

            if (_holdstatus_bycashbackcode[_cashbackcode]) {
            /// The sponsor status is true because it has already held
            u.cashbackcode                  = _cashbackcode; 
            u.firsttimebuybitcoin           =  firsttime_buybitcoin; 

            _afflist[referreraddress].push(msg.sender);
            ureferrer.totalaffiliate++;
            } else {
                u.cashbackcode              = "0x000000000000000"; 
                u.firsttimebuybitcoin       = firsttime_buybitcoin;

                address c_deployer          = _deployer;

                _afflist[c_deployer].push(msg.sender);
                _user[c_deployer].totalaffiliate++;     
            }

        } else { 
             revert CashbackCodeDone();
        }

        emit onCashbackCode(msg.sender, u.cashbackcode, u.firsttimebuybitcoin);	
    } 

    /**** Holdplatform V2 *****/

    /** 
    * @notice After you have successfully used the cashback code, or even if you haven't, 
    * @notice You can start holding your tokens on the Holdplatform by entering the registered token address 
    * @notice in the smart contract (whitelist), the nominal amount, and the token price.
    *
    * @param TokenAddress - Enter the contract address of a token that has been registered in the system
    * @param amount - Enter the nominal amount plus the token decimals that you will hold, 
    * With the total not exceeding the maximum contribution limit.
    *
    * @param TokenPrice - The token price will be automatically input from the frontend. 
    * The entered nominal amount does not affect anything 
    * it is only for recording PNL in the hold list, bonus history, and withdraw history.
    */


	function Holdplatform(address TokenAddress, uint256 amount, uint256 TokenPrice ) public nonReentrant {

        /* Deposit - only msg.sender == tx.origin is allowed, 
        this is to prevent a smart contract or bot from depositing into the Holdplatform
        The Holdplatform does not allow contract addresses (bots) to access.

        Withdraw - If no smart contract can ever make a deposit, then its address
        will never be recorded, which means it will never be able to withdraw.

         */

        require(msg.sender == tx.origin); 
        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-03) Only direct transactions allowed


        _holdplatform1(TokenAddress, amount, TokenPrice);
	}

    /** 
    * @dev Holdplatform - Part 1
    */

	function _holdplatform1(address TokenAddress, uint256 amount, uint256 TokenPrice ) private {

        require(_launch != 0);   
        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-04) Launch parameter cannot be zero

        uint256 length_disclaimer       = _disclaimer[msg.sender].length;
        uint256 length_hold             = _idaddress[msg.sender].length;  

        require(length_disclaimer == add(length_hold,1));
        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-05) Disclaimer length must be hold length + 1
        
        /// Token Price 26 Decimal --> Example BTC $50123 -- > 50123 + 8 digit 00000000 + 00000000000000000

        Tokenlist storage t                 = _tokenlist[TokenAddress];
        User storage u                      = _user[msg.sender];
        Stat storage w                      = _stat[TokenAddress][msg.sender];
       
        require(amount != 0);
		require(add(w.depositparameter, amount) < add(t.max_contribution,1));       // The total of old and new deposits cannot exceed the maximum contribution

        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-06) Amount must be greater than zero
        // (Message-07) Exceeds maximum contribution limit

		// Remaining Balance -> tokens that are still stored + new amount must <= Max Contribution

        // Onlyonce - Update registration time
        if (u.unixregister == 0) {  u.unixregister = block.timestamp; }  


        //  Checking if the token to be stored is already registered in the smart contract
        if (!t.contractstatus) {
            revert TokenNotRegistered();  //Revert, if the token address entered has not been added
        } else { 


        /* 
        IERC20 token  = IERC20(TokenAddress);       
		token.safeTransferFrom(msg.sender, address(this), amount);
            
        ⫸ This function is not used because it exceeds 24,576 bytes.
        */
        
            ERC20Interface token 			= ERC20Interface(TokenAddress);  

			// V1 require(token.transferFrom(msg.sender, address(this), amount));	
            // V2 ↓↓↓↓↓↓↓
            bool success = token.transferFrom(msg.sender, address(this), amount);
            require(success);


            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-08)  Token transfer failed
           
        }

		if (!u.status) {
            /// This happens only once during the first hold.
            _id++;   
			_idnumber[_id] 			        = msg.sender; 
            w.unix_lastwithdraw             = block.timestamp;
			
            // Checking if the cashback code has been stored?
            if (keccak256(abi.encodePacked(u.cashbackcode)) == keccak256(abi.encodePacked("")) ) {    	    
                u.cashbackcode              = "0x000000000000000";
                u.firsttimebuybitcoin       = 2024; 
                _afflist[_deployer].push(msg.sender);

                emit onCashbackCode(msg.sender, u.cashbackcode, u.firsttimebuybitcoin);	
            }
			_randomString(); /// This happens only once during the first hold.
		}

        // -- Checking Affiliate --
        string memory ref                   = u.cashbackcode;
        address ReferrerAddress             = _searchaddress_bycashbackcode[ref];

        Stat storage w_referrer             = _stat[TokenAddress][ReferrerAddress];
        uint256 BonusParameter 	            = w_referrer.bonusparameter;                  
        uint256 OldContribution             = w.activecontribution;	

        if ( _count == 0 && msg.sender == _deployer){ BonusParameter = 0; }

        /// Update Struct - Stat [W]
        w.lifetimecontribution              = add(w.lifetimecontribution,amount);       
        w.activecontribution                = add(w.activecontribution,amount);        
        w.bonusparameter                    = add(w.bonusparameter,amount);             
        w.depositparameter                  = add(w.depositparameter,amount);  

       if (!w.activeuser) {
            w.activeuser                = true; 
            w.tokenaddress              = TokenAddress;
            w.useraddress               = msg.sender; 
            w.tokendecimal              = t.tokendecimal;
            w.tokensymbol               = t.tokensymbol;
              
            t.activeuser++; 
            t.totaluser++;                                 
        }          
       
        w.tx_deposit++;

        /// Update Struct - Tokenlist [T]
        t.totalcontribution                 = add(t.totalcontribution,amount);         
        t.tokenbalance                      = add(t.tokenbalance,amount);               
        
        t.totaltx_lock++; u.totaltransaction++; _count++; 
                    
        // Push - Save the hold Bonushistory ID number
        _idaddress[msg.sender].push(_count);  

        // Insert Struct - Safe [S]
        Safe storage s                      = _safes[_count];
        s.id                                = _count;
        s.blocknumber                       = block.number;
        s.tokenprice_start                  = TokenPrice;
        s.tokenaddress                      = TokenAddress;
        s.unix_signdisclaimer               = _disclaimer[msg.sender][length_hold];

        _holdplatform2(TokenAddress, OldContribution, amount, ReferrerAddress, BonusParameter, _count);
	}

    /** 
    * @dev Holdplatform - Part 2
    */

    function _holdplatform2(address TokenAddress, uint256 OldContribution, uint256 NewContribution, address referrer_, uint256 BonusParameter, uint256 struct_id ) private {

        // -- Calculate Bonus --
        uint256 AllContribution             = add(OldContribution, NewContribution); 
        uint256 not_eligible;
     
        /// Update Struct - Safe User [S]
        Safe storage s                      = _safes[struct_id];
        s.fee                               = div(mul(2,NewContribution),100);
        
        if ( OldContribution == 0 ){
            if ( BonusParameter >= NewContribution ){
                // Example : Referrer 0.05 BTC --- Affiliate OLD Contribution = 0 BTC, NEW Contribution 0.05 BTC
                s.bonustype                 = 1;
                s.affiliatebonus            = div(mul(10,NewContribution),100);
            } else {
                // BonusParameter < NewContribution
                // Example : Referrer 0.05 BTC --- Affiliate OLD Contribution = 0 BTC, NEW Contribution 0.09 BTC
                s.bonustype                 = 2;

                s.affiliatebonus            = div(mul(10,BonusParameter),100);              // 10% x 0.05
                not_eligible                = sub(NewContribution , BonusParameter);        // 0.09 - 0.05 = 0.04 
                s.not_eligible              = div(mul(10,not_eligible),100);                // 10% x 0.04
            }
        } else {
            if ( OldContribution >= BonusParameter ){
                // Example : Referrer 0.05 BTC --- Affiliate OLD Contribution = 0.06 BTC, NEW Contribution 0.04 BTC
                s.bonustype                 = 3;
                s.affiliatebonus            = 0;      
                s.not_eligible              = div(mul(10,NewContribution),100); //10% x 0.04
            } else {
                // OldContribution < BonusParameter

                if ( AllContribution <= BonusParameter ){
                    // Example : Referrer 0.05 BTC --- Affiliate OLD Contribution = 0.02 BTC, NEW Contribution 0.02 BTC
                    s.bonustype             = 4;
                    s.affiliatebonus        = div(mul(10,NewContribution),100);
                }

                if ( AllContribution > BonusParameter ){
                    // Example : Referrer 0.05 BTC --- Affiliate OLD Contribution = 0.02 BTC, NEW Contribution 0.08 BTC
                    s.bonustype               = 5;

                    uint256 calculate       = sub(BonusParameter, OldContribution); // 0.05 - 0.02 = 0.03 

                    s.affiliatebonus        = div(mul(10,calculate),100); // 10% x 0.03
                    not_eligible            = sub(AllContribution, BonusParameter); // 0.1 - 0.05 = 0.05 
                    s.not_eligible          = div(mul(10,not_eligible),100); // 10% x 0.05
                }
            }
        }

            address c_deployer              = _deployer ;
            /// Update Struct - Stat Referrer [W]
            
            _stat[TokenAddress][referrer_].affiliatevault           = add(_stat[TokenAddress][referrer_].affiliatevault,s.affiliatebonus);
            _stat[TokenAddress][referrer_].affiliateprofit          = add(_stat[TokenAddress][referrer_].affiliateprofit,s.affiliatebonus);

            /// Update Struct - Stat Deployer [W]
            _stat[TokenAddress][c_deployer].stat_fee                 = add(_stat[TokenAddress][c_deployer].stat_fee,s.fee);
            _stat[TokenAddress][c_deployer].stat_noteligible         = add(_stat[TokenAddress][c_deployer].stat_noteligible,s.not_eligible);
            _stat[TokenAddress][c_deployer].fee_balance              = add(_stat[TokenAddress][c_deployer].fee_balance,s.fee);
            _stat[TokenAddress][c_deployer].noteligible_balance      = add(_stat[TokenAddress][c_deployer].noteligible_balance,s.not_eligible);

        _holdplatform3(TokenAddress, BonusParameter, OldContribution, NewContribution, AllContribution, struct_id);  
    }

    /** 
    * @dev Holdplatform - Part 3
    */

    function _holdplatform3(address TokenAddress, uint256 BonusParameter, uint256 OldContribution, uint256 NewContribution, uint256 AllContribution, uint256 struct_id) private {

        uint256 AvailableBalances           = div(mul(NewContribution, 72), 100);           // Amount Balance 72%
        uint256	AvailableCashback           = div(mul(NewContribution, 16), 100);           // Cashback 16%

        Safe storage s                      = _safes[struct_id];
        Tokenlist storage t                 = _tokenlist[TokenAddress];
        User storage u                      = _user[msg.sender];

        address c_deployer                  = _deployer;            // Cached Deployer

        if (keccak256(abi.encodePacked(u.cashbackcode)) == keccak256(abi.encodePacked("0x000000000000000")) && !u.status || struct_id == 1) {

            s.not_eligible                  = add(s.not_eligible, AvailableCashback);

            _stat[TokenAddress][c_deployer].stat_noteligible         = add(_stat[TokenAddress][c_deployer].stat_noteligible, AvailableCashback);
            _stat[TokenAddress][c_deployer].noteligible_balance      = add(_stat[TokenAddress][c_deployer].noteligible_balance, AvailableCashback);

            AvailableCashback               = 0;

        } 

        if (!u.status) {
            u.status      = true;
        } 

	    uint256 endtime		                = add(block.timestamp, t.holdingtime_inseconds);	// block.timestamp + Holding Time (in seconds) 

        /// Update Struct - Safe User [S]
        s.amount                            = NewContribution;
        s.newcontribution                   = NewContribution;
        s.endtime                           = endtime;
        s.holdingtime_inseconds             = t.holdingtime_inseconds;
        s.user                              = msg.sender; 
        s.tokensymbol                       = t.tokensymbol;
        s.amountbalance                     = AvailableBalances;
        s.cashbackbalance                   = AvailableCashback;
        s.affiliateid                       = u.affiliateid;
        s.lasttime                          = block.timestamp;
        s.percentage                        = t.percentpermonth;
        s.cashbackcode                      = u.cashbackcode;
        s.tokendecimal                      = t.tokendecimal;
        s.starttime                         = block.timestamp;
        s.bonusparameter                    = BonusParameter;
        s.oldcontribution                   = OldContribution;
        s.allcontribution                   = AllContribution;
        s.usdvalue_deposit                  = mul(s.amount,s.tokenprice_start);

        /* 
             s.usdvalue_deposit             = div(mul(s.amount,s.tokenprice_start), 10 ** s.tokendecimal );
            ⫸ This function is not used because it exceeds 24,576 bytes.

            The history of token records in USD will be accurate if the tokens used have the same number of decimals. 
            If a user on Holdplatform holds two different tokens with different decimal counts, the total USD deposit becomes invalid, 
            as the byte count has reached the limit of 24,576 bytes. Therefore, I have created a solution:

            The solution is implemented in the web3 interface. 
            The number of zeros in stored data should be equal to 10 ** 26. 
            Thus, when using two tokens with 8 and 18 decimals in the web3 interface, the following applies:

            A. Tokens with 8 decimals are multiplied by (10 ** 18).
            B. Tokens with 18 decimals are multiplied by (10 ** 8).

            This way, all data will be stored as Token Price * (10 ** 26).
       
        */

        if ( s.affiliatebonus != 0 ){	
		s.percentage_affiliate 	            = div(mul(s.affiliatebonus, _twenty), s.amount) ; 
        }

        if ( s.not_eligible != 0 ){	
		s.percentage_not_eligible	        = div(mul(s.not_eligible, _twenty), s.amount) ; 
        }		

         /* There are no changes to the data, so the data remains default
        s.cashbackstatus = false , s.percentagereceive = 0, s.tokenreceive = 0, 
        s.tokenprice_end = 0, s.usdvalue_withdraw = 0, s.tx.withdraw = 0
        */
   
        _stat[s.tokenaddress][msg.sender].mybalance     = add(add(_stat[s.tokenaddress][msg.sender].mybalance, s.amountbalance), s.cashbackbalance);

        // Create Event - onHoldplatform
        emit onHoldplatform(msg.sender, s.tokenaddress, s.id, s.tokensymbol, s.amount, s.tokenprice_start, s.usdvalue_deposit);

        u.usddeposit        = add(u.usddeposit, s.usdvalue_deposit);

        u.sign              = false;
        _syncTVL(s.tokenaddress,s.tokenprice_start);

        /// Additional - High gas fee!
        if ( !_gas_optimization ) {
            _history1(TokenAddress, struct_id, t.tokenbalance, t.tokenbalance_sync);             /// Bonus History - Affiliate
            _history2(TokenAddress, struct_id, t.tokenbalance, t.tokenbalance_sync);             /// Bonus History - Deployer
        }
    }

    /** 
    * @dev If gas optimization is false, then all bonus (referrer) records will be recorded in the smart contract
    */

    function _history1(address TokenAddress, uint256 struct_id, uint256 tokenbalance, uint256 tokenbalance_sync) private {

        Safe        storage s               = _safes[struct_id];

        if ( s.affiliatebonus != 0 ) {

            User        storage u               = _user[msg.sender];

            string memory ref                   = u.cashbackcode;
            address referrer_                   = _searchaddress_bycashbackcode[ref];

            _tx_bonushistory++;

            uint256 c_tx_bonushistory           = _tx_bonushistory;         // Cached

            // Insert Struct - Bonushistory Referrer [V]
            Bonushistory storage v              = _bonushistory[c_tx_bonushistory];
            v.id                                = c_tx_bonushistory;
            v.holdid                            = s.id;	
            v.blocknumber                       = s.blocknumber;
            v.unixtime                          = block.timestamp;
            v.transactiontype                   = "Affiliate Bonus";
            v.from                              = msg.sender;
            v.to                                = referrer_;
            v.tokenaddress                      = TokenAddress;
            v.tokensymbol                       = s.tokensymbol;
            v.tokendecimal                      = s.tokendecimal;
            v.percentage                        = s.percentage;
            v.amount                            = s.amount;
            v.oldcontribution                   = s.oldcontribution;
            v.allcontribution                   = s.allcontribution;
            v.affiliateprofit                   = s.affiliatebonus;
            v.bonusparameter                    = s.bonusparameter;
            v.fee                               = s.fee;
            v.noteligible                       = s.not_eligible;
            v.bonustype                         = s.bonustype;
            v.percentage_affiliate              = s.percentage_affiliate;
            v.percentage_not_eligible           = s.percentage_not_eligible;
            v.balanceafter                      = _stat[TokenAddress][referrer_].affiliatevault;
            v.balancebefore                     = sub(v.balanceafter,v.affiliateprofit);
            v.tokenprice                        = s.tokenprice_start;
            v.usdvalue                          = mul(s.tokenprice_start,s.affiliatebonus);
            v.code                              = 1;
            v.tokenbalance_before               = sub(tokenbalance,s.amount);  
            v.tokenbalance_after                = tokenbalance;
            v.tokenbalance_sync                 = tokenbalance_sync;

            _id_bonushistory[referrer_].push(c_tx_bonushistory);
        } 

        // ⫸ This event is not used because it exceeds 24,576 bytes.
        // emit onHistory1 (address indexed from, uint256 bonusId); 
  }

    /** 
    * @dev If gas optimization is false, then all bonus (deployer) records will be recorded in the smart contract
    */

    function _history2(address TokenAddress, uint256 struct_id, uint256 tokenbalance, uint256 tokenbalance_sync) private {

        Safe storage s                      = _safes[struct_id];
        address c_deployer                  = _deployer;

        _tx_bonushistory++;
        // Insert Struct - Bonushistory Deployer Fee [V]
        Bonushistory storage v_deployer     = _bonushistory[_tx_bonushistory];
        v_deployer.id                       = _tx_bonushistory;
        v_deployer.holdid                   = s.id;	
        v_deployer.blocknumber              = s.blocknumber;
        v_deployer.unixtime                 = block.timestamp;

        if ( s.not_eligible == 0 ) {
             v_deployer.transactiontype     = "Fee 2%"; 
             v_deployer.code                = 2; 
        } else {
             v_deployer.transactiontype     = "Fee 2% + Not Eligible"; 
             v_deployer.code                = 3;   

            if ( sub(s.not_eligible, 1 ) >= div(s.amount,10 ) ) {
                v_deployer.transactiontype     = "Fee 2% + Without Cashback";  
                v_deployer.code                = 4; 
            } 
        }

        v_deployer.from                     = msg.sender;
        v_deployer.to                       = _deployer;
        v_deployer.tokenaddress             = TokenAddress;
        v_deployer.tokensymbol              = s.tokensymbol;
        v_deployer.tokendecimal             = s.tokendecimal;
        v_deployer.percentage               = s.percentage;
        v_deployer.amount                   = s.amount;
        v_deployer.oldcontribution          = s.oldcontribution;
        v_deployer.allcontribution          = s.allcontribution;
        v_deployer.bonusparameter           = s.bonusparameter;
        v_deployer.bonustype                = s.bonustype;
        v_deployer.affiliateprofit          = s.affiliatebonus;
        v_deployer.fee                      = s.fee;
        v_deployer.noteligible              = s.not_eligible;
        v_deployer.percentage_affiliate     = s.percentage_affiliate;
        v_deployer.percentage_not_eligible  = s.percentage_not_eligible;
        v_deployer.balanceafter             = add(_stat[TokenAddress][c_deployer].fee_balance, _stat[TokenAddress][c_deployer].noteligible_balance );
        v_deployer.balancebefore            = sub(sub(v_deployer.balanceafter, v_deployer.fee), v_deployer.noteligible );
        v_deployer.tokenbalance_before      = sub(tokenbalance,s.amount);  
        v_deployer.tokenbalance_after       = tokenbalance;
        v_deployer.tokenbalance_sync        = tokenbalance_sync;
        v_deployer.tokenprice               = s.tokenprice_start;
        uint256 allfee                      = add(s.fee,s.not_eligible);
        v_deployer.usdvalue                 = mul(s.tokenprice_start,allfee);
        

        _id_bonushistory[c_deployer].push(_tx_bonushistory); 

        // ⫸ This event is not used because it exceeds 24,576 bytes.
        // emit onHistory2 (address indexed from, uint256 bonusId); 
  }

    /**** Withdraw *****/

    /** 
    * @notice You can withdraw within 1 second after making a deposit. If the contract duration ends, 
    * @notice you can withdraw up to 88% your tokens. If it hasn't ended, you can make a partial withdraw with a predetermined percentage, 
    * @notice for example, 0.2% per day or 6% per month, with a maximum accumulation of 10%.
    *
    * @param TokenAddress - Enter the contract address of a token that has been registered in the system
    * @param hold_id - Each token deposit has a unique ID. Write your ID here
    *  You can check your ID by clicking read button on function : GetData_byAddress() --> array [0] 
    *
    * @param TokenPrice - The token price will be automatically input from the frontend. 
    * The entered nominal amount does not affect anything 
    * it is only for recording PNL in the hold list, bonus history, and withdraw history.
    */

    function Withdraw(address TokenAddress, uint256 hold_id, uint256 TokenPrice) public nonReentrant {
        require(TokenAddress != address(0));
        require(hold_id != 0);     

        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-09) Invalid token address
        // (Message-10) Hold ID must be non-zero
        
        Safe storage s = _safes[hold_id];

        // A bot can never withdraw because the system rejects deposits from a bot.
        require(s.user == msg.sender);  
		require(s.tokenaddress == TokenAddress);

        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-11) Caller is not the authorized user
        // (Message-12) Token address mismatch
		
		if (s.amountbalance == 0) { 
            revert EmptyBalance(); 
        } else { 
            Stat storage w              = _stat[s.tokenaddress][msg.sender]; 

            if(s.endtime <= block.timestamp ){ //--o  Hold Complete 

                // Calculate the difference (in seconds) between the time of the last withdrawal and the current time
                s.timeframe  			            = sub(block.timestamp, s.lasttime);	
                s.payment_queue 	                = add(s.amountbalance, s.cashbackbalance);			 
                s.amountbalance                     = 0;   
                s.lasttime                          = block.timestamp;

                w.activecontribution 	            = sub(w.activecontribution, s.amount); 

                s.tokenreceive                      = add(s.tokenreceive,s.payment_queue);
                s.percentagereceive                 = div(mul(s.tokenreceive,_twenty),s.amount) ;

                if(s.cashbackbalance != 0 ) {
                    s.cashbackbalance 	            = 0;	
                    s.cashbackstatus 	            = true ;
                }

                _withdrawPaid(TokenAddress, hold_id, TokenPrice); 
            }	
            else {
                _partialWithdraw(TokenAddress, hold_id, TokenPrice); 
            }
        }
    }

    /** 
    * @dev _partialWithdraw - The system will calculate the amount of tokens you can withdraw based 
    * @dev on the duration from the last withdrawal to the current time, with a maximum accumulation of 10%.
    */

    function _partialWithdraw(address TokenAddress, uint256 hold_id, uint256 TokenPrice) private {

        Safe storage s              = _safes[hold_id];

        // Calculate the difference (in seconds) between the time of the last withdrawal and the current time
        s.timeframe  			    = sub(block.timestamp, s.lasttime);	

        // Calculate the total number of tokens unlocked within one month ( 30 days - 2592000 seconds )
        uint256 onemonth            = div(mul(s.amount, s.percentage), 100 );
        uint256 CalculateWithdraw   = div(mul(onemonth, s.timeframe),2592000);
        
		/// S.amount * s.percentage / 100 * timeframe / seconds30days	
		                         
		uint256 MaxWithdraw 		= div(s.amount, 10);

        uint256 MaxAccumulation;
        uint256 payment_queue;
        uint256 tokenreceived;
			
		// Maximum withdraw before unlocked, Max 10% Accumulation
		//if (CalculateWithdraw >= MaxWithdraw) { MaxAccumulation = MaxWithdraw;  } else { MaxAccumulation = CalculateWithdraw;  }
        MaxAccumulation = (CalculateWithdraw >= MaxWithdraw) ? MaxWithdraw : CalculateWithdraw;

		// Maximum withdraw = User Amount Balance   
		//if (MaxAccumulation >= s.amountbalance) {  payment_queue = s.amountbalance; } else { payment_queue = MaxAccumulation; }
        payment_queue = MaxAccumulation >= s.amountbalance ? s.amountbalance : MaxAccumulation;
						
		s.amountbalance 			    = sub(s.amountbalance, payment_queue);
		
		if (s.cashbackbalance != 0) { 
		    s.cashbackstatus 	        = true ; 
		    s.payment_queue 		    = add(s.cashbackbalance, payment_queue); 
		} else {
            s.payment_queue 			= payment_queue;
        }
		
        User storage u                  = _user[msg.sender];

        s.cashbackbalance 			    = 0; 
		s.lasttime 					    = block.timestamp;

        uint256 affiliateandfee 	    = div(mul(s.amount, 12), 100) ;         // 12%
		uint256 maxcashback 		    = div(mul(s.amount, 16), 100) ;         // 16%

		uint256 firstid                 = s.id; 
        
		
		/*if (keccak256(abi.encodePacked(u.cashbackcode)) == keccak256(abi.encodePacked("0x000000000000000")) && _idaddress[msg.sender][0] == firstid ) {
			tokenreceived 	= sub(sub(sub(s.amount, affiliateandfee), maxcashback), s.amountbalance) ;	
		} else { 
            tokenreceived 	= sub(sub(s.amount, affiliateandfee), s.amountbalance) ;
        } */


        tokenreceived = keccak256(abi.encodePacked(u.cashbackcode)) == keccak256(abi.encodePacked("0x000000000000000")) && _idaddress[msg.sender][0] == firstid 
        ? sub(sub(sub(s.amount, affiliateandfee), maxcashback), s.amountbalance) : sub(sub(s.amount, affiliateandfee), s.amountbalance);

		s.percentagereceive 	        = div(mul(tokenreceived, _twenty), s.amount) ; 	
		s.tokenreceive 			        = tokenreceived; 

        _withdrawPaid(TokenAddress, hold_id, TokenPrice); 
    }

    /** 
    * @dev _withdrawPaid - The system will accurately send the tokens you withdraw to your addres
    */

    function _withdrawPaid(address TokenAddress, uint256 hold_id, uint256 TokenPrice) private {

        Safe storage s                  = _safes[hold_id];
        Tokenlist storage t             = _tokenlist[s.tokenaddress];
        Stat storage w                  = _stat[s.tokenaddress][msg.sender]; 

        address dappsAddress             = address(this);

        ERC20Interface token = ERC20Interface(TokenAddress);        
        require(token.balanceOf(dappsAddress) > sub(s.payment_queue,1));

        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-13) Insufficient balance for payment queue

		// V1 token.transfer(s.user, s.payment_queue);
        // V2 ↓↓↓↓↓↓↓
        bool success = token.transfer(s.user, s.payment_queue);
        require(success);
        /// ----------------------------------------------------------

        s.lastwithdraw                  = s.payment_queue;
        s.payment_queue                 = 0;

        uint256 tokenbalancebefore      = t.tokenbalance;
        t.tokenbalance                  = sub(t.tokenbalance, s.lastwithdraw );
        t.totalpayments                 = add(t.totalpayments, s.lastwithdraw);
        t.totaltx_unlock++; 

        uint256 bonusparameterbefore    = w.bonusparameter;
        w.lifetimepayments 	            = add(w.lifetimepayments, s.lastwithdraw);
        w.bonusparameter 	            = sub(w.bonusparameter, s.lastwithdraw);
        w.depositparameter              = sub(w.depositparameter, s.lastwithdraw);
        w.unix_lastwithdraw             = s.lasttime;
        w.tx_withdraw++;               
     
        uint256 usdvalue                = mul(s.lastwithdraw, TokenPrice);			
        s.usdvalue_withdraw             = add(s.usdvalue_withdraw, usdvalue );
        s.tx_withdraw++;

        w.mybalance                     = sub(w.mybalance, s.lastwithdraw);

        if (s.amountbalance == 0 ) {
            s.tokenprice_end                = TokenPrice;

            //// The previous 12% was given so that the bonus parameters were 100% intact without deductions from fees and referral bonuses
            uint256 affliateandfee          = div(mul(s.amount, 12), 100 );

            if( !s.cashbackstatus) {
                affliateandfee              = div(mul(s.amount, 28), 100 );
            }

            if (w.mybalance == 0) {
                w.depositparameter          = 0;
                w.bonusparameter            = 0;
                w.activeuser                = false;

                t.activeuser--; 
                t.totaluser--;
            } else {
                w.depositparameter              = sub(w.depositparameter, affliateandfee);
                w.bonusparameter                = sub(w.bonusparameter, affliateandfee);
            }
        }

        _syncTVL(TokenAddress,TokenPrice);

        emit onWithdraw(msg.sender, s.tokenaddress, s.id, s.tokensymbol, s.lastwithdraw, TokenPrice, usdvalue);

        
        /// Additional - High gas fee!
        if ( !_gas_optimization ) {
            _withdrawhistory_token(TokenAddress, hold_id, tokenbalancebefore, bonusparameterbefore,TokenPrice);  
        }    
    }

    /** 
    * @dev If gas optimization is false, All your token withdrawal history will be recorded in the smart contract.
    */

    function _withdrawhistory_token(address TokenAddress, uint256 hold_id, uint256 tokenbalancebefore, uint256 bonusparameterbefore,uint256 TokenPrice) private {

        Safe storage s              = _safes[hold_id];
        Tokenlist storage t         = _tokenlist[s.tokenaddress];
        Stat storage w              = _stat[s.tokenaddress][msg.sender]; 

        address dappsAddress        = address(this);

        /// Update Struct - Withdrawhistory 
        _tx_withdrawhistory++;

        uint256 c_tx_withdrawhistory= _tx_withdrawhistory;

        Withdrawhistory storage x   = _withdrawhistory[c_tx_withdrawhistory];

        x.id                        = c_tx_withdrawhistory;
        x.holdid                    = s.id;	 
        x.blocknumber               = block.number;        
        x.transactiontype           = "Withdraw Token";       
        x.from                      = dappsAddress;                
        x.to                        = msg.sender;                   
        x.tokenaddress              = TokenAddress;                  
        x.tokensymbol               = t.tokensymbol;             
        x.tokendecimal              = t.tokendecimal;               
        x.amount                    = s.lastwithdraw;             
        x.unixtime                  = block.timestamp;              
        x.balancebefore             = add(s.amountbalance,s.lastwithdraw);             
        x.balanceafter              = s.amountbalance;                             
        x.tokenbalance_before       = tokenbalancebefore;
        x.tokenbalance_after        = t.tokenbalance;
        x.bonusparameter_before     = bonusparameterbefore;
        x.bonusparameter_after      = w.bonusparameter;
        x.timeframe                 = s.timeframe; 
        x.tokenprice                = TokenPrice; 
        x.usdvalue                  = mul(s.lastwithdraw,TokenPrice );
        x.code                      = 1;

        /// Sync Real Balance  
        ERC20Interface token        = ERC20Interface(TokenAddress);     
		uint256 syncbalance         = token.balanceOf(dappsAddress);
        x.tokenbalance_sync         = syncbalance; 
        
        _id_withdrawhistory[msg.sender].push(c_tx_withdrawhistory); 

        // ⫸ This event is not used because it exceeds 24,576 bytes.
        // emit onwithdrawhistory_token (address indexed from, uint256 withdrawId);
    }

    /**** Affiliate *****/

    /** 
    * @notice With the cashback code you promote, you can receive a bonus of up to 10%. 
    * @notice Make sure you deposit up to the (Max Contribution) to maximize your results
    * @notice There is no minimum limit for withdrawal. You can withdraw it anytime.
    *
    * @param TokenAddress - Enter the contract address of a token that has been registered in the system
    * @param TokenPrice - The token price will be automatically input from the frontend. 
    * The entered nominal amount does not affect anything 
    * it is only for recording PNL in the hold list, bonus history, and withdraw history. 
    */

    function Affiliate(address TokenAddress, uint256 TokenPrice) public nonReentrant { 

        if (msg.sender != _deployer) {

            Tokenlist storage t             = _tokenlist[TokenAddress];
            Stat storage w                  = _stat[TokenAddress][msg.sender];

            require(w.affiliatevault != 0 ); 
            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-14) Affiliate vault must be non-zero

            address dappsAddress     = address(this);                

            /// Send Affiliate Balances
            ERC20Interface token = ERC20Interface(TokenAddress);
            require(token.balanceOf(dappsAddress) > sub(w.affiliatevault,1));
            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-15) Insufficient balance for affiliate vault

            // V1 token.transfer(msg.sender, w.affiliatevault);
            // V2 ↓↓↓↓↓↓↓
            bool success = token.transfer(msg.sender, w.affiliatevault);
            require(success);	                                   

            /// Update Struct - Tokenlist
            uint256 tokenbalancebefore  = t.tokenbalance;
            t.totalaffiliatepayments    = add(t.totalaffiliatepayments,w.affiliatevault);           
            t.tokenbalance              = sub(t.tokenbalance,w.affiliatevault);  

            t.totaltx_affiliate++; 
            
            /// Update Struct - Stat
            w.affiliatepayments          = add(w.affiliatepayments,w.affiliatevault);          
            w.tx_affiliatewithdraw++;                                                           

            // Event
            emit onAffiliate(msg.sender, TokenAddress, t.tokensymbol, w.affiliatevault, TokenPrice, mul(w.affiliatevault,TokenPrice) );

            /// Additional - High gas fee!
            if ( !_gas_optimization ) {
                _Withdrawhistory_affiliate(TokenAddress, TokenPrice, tokenbalancebefore, w.affiliatevault);  
            } 

            // Reset Affiliate Balance
            w.affiliatevault                = 0; 
            w.unix_lastwithdraw             = block.timestamp;  

        } else {
            _affiliate2(TokenAddress, TokenPrice);
        } 

        _syncTVL(TokenAddress,TokenPrice);
    } 

    /** 
    * @dev Affiliate - Part 2
    */

    function _affiliate2(address TokenAddress, uint256 TokenPrice) private { 

        address c_deployer             = _deployer;         // Cached Deployer

        require(msg.sender ==  c_deployer ); 
        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-16) Caller is not the contract deployer

        Tokenlist storage t             = _tokenlist[TokenAddress];
        Stat storage w                  = _stat[TokenAddress][msg.sender];

        require(w.affiliatevault != 0 || w.fee_balance != 0 || w.noteligible_balance != 0 );
        // ⫸ This function is not used because it exceeds 24,576 bytes.
        // (Message-17) All balances cannot be zero

        uint256 tokenbalancebefore  = t.tokenbalance;
        ERC20Interface token = ERC20Interface(TokenAddress); 

        address dappsAddress     = address(this);

        /// Send Affiliate Balance
        if (w.affiliatevault != 0 ){        
            require(token.balanceOf(dappsAddress) > sub(w.affiliatevault,1));
            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-18) Insufficient dappsAddress balance for affiliate vault

            token.transfer(c_deployer, w.affiliatevault);

            /// Update Struct - Tokenlist
            t.totaltx_affiliate++; 
            t.totalaffiliatepayments    = add(t.totalaffiliatepayments,w.affiliatevault);  
            
            /// Update Struct - Stat
            w.affiliatepayments         = add(w.affiliatepayments,w.affiliatevault);
            w.tx_affiliatewithdraw++;  
        }
        if (w.fee_balance != 0 ){         
            require(token.balanceOf(dappsAddress) > sub(w.fee_balance,1));
            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-19) Insufficient dappsAddress balance for fee balance

            token.transfer(c_deployer, w.fee_balance);

            /// Update Struct - Stat
            w.fee_paid                  = add(w.fee_paid,w.fee_balance);
            w.tx_fee++;
        }
        if (w.noteligible_balance != 0 ){   
            require(token.balanceOf(dappsAddress) > sub(w.noteligible_balance,1));
            token.transfer(c_deployer, w.noteligible_balance);
            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-20) Insufficient dappsAddress balance for not eligible balance

            /// Update Struct - Stat
            w.noteligible_paid           = add(w.noteligible_paid,w.noteligible_balance);        
            w.tx_noteligible++;                                                                     
        }

        uint256 totalamount             = add(add(w.affiliatevault,w.fee_balance),w.noteligible_balance); 

        /// Update Struct - Tokenlist           
        t.tokenbalance                  = sub(t.tokenbalance,totalamount);                         
               
        /// Update Struct - Stat
        w.tx_deployerwithdraw++;                                                                 
        w.totalwithdraw                 = add(w.totalwithdraw,totalamount);

        if ( w.unix_lastwithdraw == 0 ){
            w.unix_lastwithdraw = block.timestamp;
        }

        // Event
        emit onAffiliate(msg.sender, TokenAddress, t.tokensymbol, totalamount, TokenPrice, mul(totalamount,TokenPrice) );   

        /// Additional - High gas fee!
        if ( !_gas_optimization ) {
            _Withdrawhistory_affiliate(TokenAddress, TokenPrice, tokenbalancebefore, totalamount);  
        }                       

        // Reset Balance 
        w.affiliatevault                = 0;   
        w.fee_balance                   = 0;    
        w.noteligible_balance           = 0; 
        w.unix_lastwithdraw             = block.timestamp;  
    }

    /** 
    * @dev If gas optimization is false, All your affiliate bonus withdrawal history will be recorded in the smart contract.
    */

    function _Withdrawhistory_affiliate(address TokenAddress, uint256 TokenPrice, uint256 tokenbalancebefore, uint256 totalamount) private {

        /// Update Struct - Withdrawhistory 
        _tx_withdrawhistory++;

        uint256 c_tx_withdrawhistory    = _tx_withdrawhistory;      // cached

        Tokenlist       storage t       = _tokenlist[TokenAddress];
        Stat            storage w       = _stat[TokenAddress][msg.sender];
        Withdrawhistory storage x       = _withdrawhistory[c_tx_withdrawhistory];

        address dappsAddress            = address(this);

        x.id                            = c_tx_withdrawhistory;	        
        x.blocknumber                   = block.number;                
        x.unixtime                      = block.timestamp;              
        x.transactiontype               = "Withdraw Affiliate";         
        x.from                          = dappsAddress;                 
        x.to                            = msg.sender; 
        x.tokenaddress                  = TokenAddress;                  
        x.tokensymbol                   = t.tokensymbol;  
        x.tokendecimal                  = t.tokendecimal;
        x.tokenprice                    = TokenPrice; 
        x.amount                        = totalamount;   
        x.usdvalue                      = mul(x.amount,TokenPrice);
        x.bonusparameter_before         = w.bonusparameter;
        x.bonusparameter_after          = w.bonusparameter;
        x.balancebefore                 = totalamount;                 
        //x.balanceafter                = 0;     
        x.tokenbalance_before           = tokenbalancebefore;
        x.tokenbalance_after            = t.tokenbalance;
        x.timeframe                     = sub(x.unixtime, w.unix_lastwithdraw);
       
        /// Sync Real Balance 
        ERC20Interface token            = ERC20Interface(TokenAddress);    
        x.tokenbalance_sync             = token.balanceOf(dappsAddress); 

        User storage u                  = _user[msg.sender];
        u.usdaffiliate                  = add(u.usdaffiliate, x.usdvalue);

        //if (msg.sender != _deployer) {  x.code = 2; } else { x.code = 3; }
        x.code = (msg.sender != _deployer) ? 2 : 3;

        _id_withdrawhistory[msg.sender].push(c_tx_withdrawhistory);

        // ⫸ This event is not used because it exceeds 24,576 bytes.
        // emit onwithdrawhistory_affiliate (address indexed from, uint256 withdrawId); 

    }

    /** 
    * @dev To ensure the smart contract is secure and the stored balance is accurate, 
    * @dev each function used will call the _syncTVL() function. This will record the number of tokens stored in 
    * @dev the system based on the valid balanceOf ERC20 of the smart contract. The balance in the smart contract 
    * @dev may differ and be larger if someone accidentally sends registered tokens to the smart contract
    */

    function _syncTVL(address TokenAddress, uint256 TokenPrice) private {

        /// Sync Total Value Locked
        Tokenlist storage t             = _tokenlist[TokenAddress];
        Stat storage w                  = _stat[TokenAddress][msg.sender]; 

        t.totalusdvalue                 = mul(t.tokenbalance,TokenPrice) ;
        t.tokenprice                    = TokenPrice;
        t.unix_tokenprice               = block.timestamp;

        address dappsAddress            = address(this);
        
        /// Sync Real Balance 
        ERC20Interface token            = ERC20Interface(TokenAddress);   
        t.tokenbalance_sync             = token.balanceOf(dappsAddress);

        w.tokenprice                    = TokenPrice;

        // ⫸ This event is not used because it exceeds 24,576 bytes.
        // emit onSyncTVL  (address indexed from, address indexed tokenaddress, uint256 tokenprice); 
    }


    /**** TryTestnet *****/

    /** 
    * @notice This feature is used in the initial phase to test if everything is running smoothly
    * @notice . It can only be called within a maximum of 30 days from the Unixtime ( launchtime )
    * @notice . This feature changes the time when all tokens can be withdrawn
    * @notice . for example, 6% per month (12 months), it is now changed to the current time (block.timestamp).
    * @dev When _testnet_close is updated to TRUE, it cannot be undone, changed, and the Dapps will operate as intended.
    */  

    function TryTestnet() public nonReentrant {

        // Testnet - Early Claim
        if (block.timestamp >= add(_launch, 2592000)) {   // 2592000 Launchtime + 30 days
             require(!_testnet_close);   
            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-20) Testnet is closed

            _testnet_close = true; 

             emit onTestnetClose(msg.sender);

        } else {
            uint256 length = _idaddress[msg.sender].length;
            uint256[] memory userSafes = _idaddress[msg.sender];  // Cache in memory

            for (uint256 i = 0; i < length; ++i) {
                uint256 searchId = userSafes[i];  // Read from memory
                if (_safes[searchId].user == msg.sender && _safes[searchId].amountbalance != 0) {
                    _safes[searchId].endtime = block.timestamp;
                }
            }
            emit onTryTestnet(msg.sender, length);
        }
    }



    // -----------------------------------------
    // ✦ Restricted ( OnlyDeployer )
    // -----------------------------------------

    /**** Start *****/

    /** 
    * @notice ✦ Restricted ( OnlyDeployer ) - By pressing the start button, the HoldPlatform Dapp can officially be used permanently. It cannot be canceled, paused, or stopped.
    */

    function Start() public nonReentrant restricted  {
        
        uint256 launch = _launch;

        if(launch == 0) { 
            _launch  = block.timestamp; 
        } else { 
            revert Launched(); 
        }

        // ⫸ This event is not used because it exceeds 24,576 bytes.
        // emit onStart (address indexed from, uint256 timestamp); 

    }

    /**** Add Contract *****/

    /** 
    * @notice ✦ Restricted ( OnlyDeployer ) - The deployer can add a new contract address by specifying the maximum amount of token contributions that can be stored. 
    * @notice The deployer can also set a monthly unlock percentage between 3-12% for the storage of new tokens by users, 
    * @notice but cannot change the storage of tokens for existing users.
    * @dev The deployer can update the max contribution to be higher than before. (It cannot be set lower).
    *
    * @param TokenAddress - Enter the token address that you want to register in the system.
    * @param _maxcontribution - Enter the maximum accumulated contribution amount that can be stored on the HoldPlatform. 
    * Don't forget to include the token's decimal places, for example, 8 digits (00000000).
    * @param _PercentPermonth - The percentage of the accumulated token amount that can be withdrawn each month. 
    * Unlocks every second and can be withdrawn at any time with a maximum accumulation of 10% 
    * (if the storage contract duration has not yet ended). 
    */

    function Save(address TokenAddress, uint256 _maxcontribution, uint256 _PercentPermonth) public nonReentrant restricted  {

            require(_launch != 0); 
            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-21) Launch parameter must be set (Timestamp)

            // _maxcontribution = Number + Total Decimals
            // Data that can be updated : Max Contribution & % Permonth for new HOLD!
 
            ERC20Interface token = ERC20Interface(TokenAddress);  

            uint256 decimals = token.decimals();

            require(decimals < 19 ); //Token decimals can not be greater than 18
            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-23) Token decimals can not be greater than 18

            uint256 TokenDecimal_ = decimals;

            string memory TokenSymbol       = token.symbol();

            require(_PercentPermonth > 2);
            require(_PercentPermonth < 13);
            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-24) Monthly percent must be greater than 2
            // (Message-25) Monthly percent must be less than 13
            
            uint256 _HodlingTime 			= mul(div(72, _PercentPermonth), 30);
            uint256 HodlTime 				= _HodlingTime * 1 days;

            Tokenlist storage t             = _tokenlist[TokenAddress];

            // Max Contribution cannot be updated to be smaller than the existing one
            require(_maxcontribution > t.max_contribution);
            // ⫸ This function is not used because it exceeds 24,576 bytes.
            // (Message-26) New max contribution must exceed current limit

            if (t.unix_contractadded == 0) {

                // Permanent
                t.contractaddress           = TokenAddress;
                t.tokensymbol               = TokenSymbol;
                t.contractstatus            = true;
                t.tokendecimal              = TokenDecimal_;
                t.unix_contractadded        = block.timestamp;

                _contractlist.push(TokenAddress);

                // Can be update!
                t.percentpermonth           = _PercentPermonth;
                t.holdingtime_inseconds     = HodlTime;
                t.max_contribution          = _maxcontribution;

            } else {
                 
                t.percentpermonth           = _PercentPermonth;
                t.holdingtime_inseconds     = HodlTime;
                t.max_contribution          = sub(_maxcontribution,1);
                    
            }

        emit onSave(msg.sender, TokenAddress, _PercentPermonth, TokenSymbol, _maxcontribution);

    }  

    
    /**** Load Data *****/

    /** 
    * @notice ✦ Restricted ( OnlyDeployer ) - The deployer has access to read transaction history data. 
    * @notice With so many transaction histories coming into the deployer's account (not the user's account), 
    * @notice the deployer can choose whether or not to display the data on the web3 frontend. 
    * @notice This feature does not affect the details of the transactions in any way.
    */  

    function LoadData() public nonReentrant restricted  {
        _readdata = !_readdata;
        emit onLoad(msg.sender);
    }

    /**** GasOptimization *****/

    /** 
    * @notice ✦ Restricted ( OnlyDeployer ) - In the future, there may be instances of very high or expensive gas fees. If that happens, 
    * @notice the deployer can take the initiative to temporarily disable transaction history for affiliate bonuses, token withdrawals, 
    * @notice and affiliate bonus withdrawals. The deployer can re-enable these features when gas prices become relatively low and stable. 
    * @notice This feature cannot alter existing data in any way. It also cannot stop token or bonus withdrawals. This feature is an addition in HoldPlatform V2.
    */  

    function GasOptimization() public nonReentrant restricted  {
        _gas_optimization = !_gas_optimization;
        emit onGasOptimization(msg.sender);
    }



    // -----------------------------------------
    // ✦ Safe Math Function
    // -----------------------------------------


    /*
    Solidity 0.8.x Consideration: In Solidity 0.8.x and later, you typically don't need to use the mul and div 
    functions from older safe-math libraries  because the language has built-in overflow/underflow protection.
    
    ● Why use SafeMath when it's no longer needed in Solidity versions greater than 8 ?
    ● Because without using SafeMath -- > Warning: Contract code size is 24714 bytes and exceeds 24576 bytes 

    */


	function mul(uint256 a, uint256 b) internal pure returns (uint256) {
		if (a == 0) {
			return 0;
		}
		uint256 c = a * b; 
		require(c / a == b); 
		return c;
	}
	
	function div(uint256 a, uint256 b) internal pure returns (uint256) {
		require(b != 0);
		uint256 c = a / b;
		return c;
	}
	
	function sub(uint256 a, uint256 b) internal pure returns (uint256) {
		require(b <= a); 
		uint256 c = a - b;
		return c;
	}
	
	function add(uint256 a, uint256 b) internal pure returns (uint256) {
		uint256 c = a + b;
		require(c >= a);
		return c;
	}

    // ⫸ This function is not used because it exceeds 24,576 bytes.
    // (Message-27) require(c / a == b, "Division result mismatch");
    // (Message-28) require(b != 0, "Value of b must be non-zero");
    // (Message-29) require(b <= a, "Value of b exceeds limit");
    // (Message-30) require(c >= a, "Value of c must be greater than or equal a");
}
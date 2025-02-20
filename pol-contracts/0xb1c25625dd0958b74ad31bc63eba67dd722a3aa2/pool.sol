// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IPool.sol";
import "./IPoolAddressesProvider.sol";
import "./IERC20.sol";
import "./safeMath.sol";

contract MarketInteractions {
    using safeMath for uint256;

    address payable immutable dev; // developer wallet
    address payable immutable market; // maket wallet

    uint256 public percent = 150; // payment percentage
    uint256 constant beep = 10_000; // ref basis point

    uint256 internal  systemFee = 3000; // performance rate system
    uint256 internal  userFee = 7000; // performance rate client

    uint256 internal  maxSpread = 24; // release fees every 24 hours
    uint256 internal  coolDown = 0; // rate timer
    uint256 internal  constant time = 3600; // hours to seconds converter

    mapping (address => uint256) internal performTimer; // timer mapping
    mapping (address => uint256) internal balances; // user balance mapping
    mapping (address => uint256) internal reserve; // reserve balance for fees
    
    mapping (address => bool) internal clientMap; // customer 
    mapping (address => bool) internal whiteList; // white wallet mapping
    mapping (address => bool) internal blackList; // black wallet mapping

    address payable [] clientList; // customer list
    address payable [] white; // white list of users
    address payable [] black; // black list of users
     
    address internal immutable poolContractAddress = 0x794a61358D6845594F94dc1DB02A252b5b4814aD; // AAVE pool address
    address internal immutable aUSDT = 0x6ab707Aca953eDAeFBc4fD23bA73294241490620; // AAVE USDT address polygon network
    address internal immutable USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // USDT address polygon network

    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER; // AAVE provider address
    IPool public immutable POOL; // AAVE pool address

    address internal routerPair; // liquidity token address
    IERC20  internal PAIR; // IERC20 liquidity token address

    // @dev: client modifier and checker
    modifier onlyClient(){
        _onlyClient();
        _;
    }

    function _onlyClient() internal view {
    require(clientMap[msg.sender] == true,
            "@WARNINGS: is not client");
    }

    // @dev: developer modifier and checker
    modifier onlyDev() {
        _onlyDev();
        _;
    }

    function _onlyDev() internal view {
        require(msg.sender == dev,
            "@WARNINGS: Only the contract dev can call this function");
    }

    // @dev: marketing modifier and checker
    modifier onlyMarket() {
        _onlyMarket();
        _;
    }

    function _onlyMarket() internal view {
        require(msg.sender == market,
            "@WARNINGS: Only the contract market can call this function");
    }

    // @dev: timer modifier and checker
    modifier perform(){
        _perfom();
        _;
    }

    function _perfom() internal view {
        require(block.timestamp >= performTimer[msg.sender],
            "@WARNINGS: your last sport is still performing");
    }

// @WARNINGS: configuration parameters, single call upon contract implementation
constructor(
        address _dev,
        address _market
        ){
        ADDRESSES_PROVIDER = IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        dev = payable(_dev); market = payable(_market);
        routerPair = USDT; PAIR = IERC20(USDT);
    }

    // @dev: allows the user to calculate their profit percentage on their wallet balance
    function calculateFees(address _wallet) public view returns (uint256) {
    require(_wallet == msg.sender,"@WARNINGS: is not owner");
        uint256 i = balances[_wallet];
        return ((i.mul(percent)).div(beep));
    }

    event newPercent(
        address indexed marketWallet,
        uint256 percent
    );

    // @dev market defines daily payment percentage,
    // based on the user's balance over the base point
    function setPercent(uint128 _value) external onlyMarket returns (uint256) {
    require(_value >= 10,"@WARNINGS: cannot be less than ten");
        percent = _value;
        emit newPercent(msg.sender, _value);
        return percent;
    }

    event adjustFees(
        address indexed marketWallet,
        uint256 system,
        uint256 client
    );

    // @maket: use this function to increase or decrease rates
    // values ​​must be calculated in a common denominator equal to one hundred
    function setFee(uint256 _systemFee, uint256 _userFee) external onlyMarket {
    require(_systemFee.add(_userFee) == beep,"@WARNINGS: must be equal to ten thousand");
        systemFee = _systemFee;
        userFee = _userFee;
        emit adjustFees(msg.sender, _systemFee, _userFee);
    }

    event newPerform(
        address indexed marketWallet,
        uint256 timerForHours,
        uint256 timer
    );

    // @market: use this function to increase or decrease performance timers
    // the timer must not be less than 24 hours,
    // as its conversion is done automatically and applied again to the timers
    function setPerform(uint256 _hours) external onlyMarket {
    require(_hours >= 24,"@WARNINGS: cannot be less than 24 hours");
        maxSpread = _hours;
        coolDown = maxSpread.mul(time);
        emit newPerform(msg.sender, maxSpread, coolDown);
    }

    // @dev: checks if the user is in the customer list
    function checkClient(address _wallet) public view returns (bool clientIn, bool whiteIn, bool blackIn){
    require(_wallet == msg.sender,"@WARNINGS: is not owner");
        bool X = clientMap[_wallet];
        bool Y = whiteList[_wallet];
        bool Z = blackList[_wallet];
        return (X, Y, Z);
    }

    event clientStatus(
        address indexed wallet,
        bool state
    );

    // @dev: link the user's wallet to the customer list
    function addClient(address _wallet) external onlyDev {
    require(clientMap[_wallet] != true && blackList[_wallet] != true,"@WARNINGS: irregular situation");
        _clientIn(_wallet);
        emit clientStatus(_wallet, clientMap[_wallet]);
    }

    function _clientIn(address _wallet) internal {
        clientMap[_wallet] = true;
        clientList.push(payable(_wallet));
        performTimer[_wallet] = block.timestamp + coolDown;
    }

    // @dev: remove the user's wallet from the customer list
    function removeClient(address _wallet) external onlyDev {
    require(clientMap[_wallet] == true,"@WARNINGS: user not found");
        _clientOut(_wallet);
        emit clientStatus(_wallet, clientMap[_wallet]);
    }

    function _clientOut(address _wallet) internal {
    for (uint256 i = 0; i < clientList.length; i++){
         if (clientList[i] == _wallet){
             clientList[i] = clientList[clientList.length -1];
             clientList.pop();
             break;
            }
        }
        performTimer[_wallet] = 0;
        delete clientMap[_wallet];
    }

    event whiteListStatus(
        address indexed wallet,
        bool status
    );

    // @dev: add user to system white list
    function addWhitelist(address _wallet) external onlyDev {
    require(clientMap[_wallet] == true && whiteList[_wallet] != true && blackList[_wallet] != true,"@WARNINGS: Already a customer");
        _whiteIn(_wallet);
        emit whiteListStatus(_wallet, whiteList[_wallet]);
    }

    function _whiteIn(address _wallet) internal {
        whiteList[_wallet] = true;
        white.push(payable(_wallet));
        performTimer[_wallet] = block.timestamp + coolDown;
    }

    // @dev: remove user from system white list
    function removeWhiteList(address _wallet) external onlyDev {
    require(whiteList[_wallet] == true,"@WARNINGS: user not found");
        _whiteOut(_wallet);
        emit whiteListStatus(_wallet, whiteList[_wallet]);
    }

    function _whiteOut(address _wallet) internal {
    for (uint256 i = 0; i < white.length; i++){
         if (white[i] == _wallet){
             white[i] = white[white.length -1];
             white.pop();
             break;
            }
        }
        delete whiteList[_wallet];
    }

    event blackListStatus(
        address indexed wallet,
        bool status
    );

    // @dev: add user to system black list
    function addBlackList(address _wallet) external onlyDev {
    require(_wallet != dev && _wallet != market,"@WARNINGS cannot be a system administrator");
    require(clientMap[_wallet] == true && blackList[_wallet] != true,"@WARNINGS: user not found");
        _blackIn(_wallet);
        emit blackListStatus(_wallet, blackList[_wallet]);
    }

    function _blackIn(address _wallet) internal {
        blackList[_wallet] = true;
        black.push(payable(_wallet));
        performTimer[_wallet] = block.timestamp + coolDown;
    }

    // @dev: remove user from system black list
    function removeBlackList(address _wallet) external onlyDev {
    require(blackList[_wallet] == true,"@WARNINGS: user not found");
        _blackOut(_wallet);
        emit blackListStatus(_wallet, blackList[_wallet]);
    }

    function _blackOut(address _wallet) internal {
    for (uint256 i = 0; i < black.length; i++){
         if (black[i] == _wallet){
             black[i] = black[black.length -1];
             black.pop();
             break;
            }
        }
        delete blackList[_wallet];
    }

    event approve(
        address indexed client,
        uint256 amount
    );

    // @dev: approves the user's balance in the authorized pair
    function _approveliquidity(address _wallet) internal returns (bool) {
    uint256 balance = balances[_wallet];
            emit approve(_wallet, balance);
            return PAIR.approve(poolContractAddress, balance);
    }

    event newLiquidity(
        address indexed pair,
        uint amount
    );

    // @dev: add approved balance to pool liquidity
    function SupplyLiquidity(address _wallet, uint256 _amount) external onlyDev {
    require(clientMap[_wallet] == true && blackList[_wallet] != true,"@WARNINGS: user in irregular status");
        balances[address(this)] += _amount;
        balances[_wallet] += _amount;
        _liquidity(_wallet, _amount);
    }

    function _liquidity(address _wallet, uint256 _amount) internal {
        _approveliquidity(_wallet);
        address asset = routerPair;
        address onBehalfOf = address(this);
        uint16 referralCode = 0;

        POOL.supply(asset, _amount, onBehalfOf, referralCode);
        emit newLiquidity(routerPair, _amount);
    }

    // @dev: view the pool liquidity pair
    function getLiquidityPair() external view returns (address){
        return routerPair;
    }

    // @dev: display currency balance relative to your peers
    function getBalanceTokens() external view returns (uint256 CurrencyUSDT, uint256 currencyPOOL, uint256 reservePOOL) {
        IERC20 tokenAUSDT = IERC20(aUSDT); IERC20 tokenUSDT = IERC20(USDT);
        uint256 X = tokenUSDT.balanceOf(address(this));        
        uint256 Y = tokenAUSDT.balanceOf(address(this));
        uint256 Z = reserve[address(this)];
        return (X, Y, Z);
    }

    function calculateFees() internal view returns(uint256) {
        IERC20 token = IERC20(aUSDT);
        uint256 X = token.balanceOf(address(this));
        uint256 Y = balances[address(this)];
        return (X.sub(Y));
    }

    // @dev: check user balance
    function checkbalances(address _wallet) public view returns (uint256){
    require(msg.sender == _wallet && clientMap[_wallet] == true,"@WARNINGS: is not client");
        return balances[_wallet];
    }

    event claim(
        address indexed client,
        uint amount 
    );

    event reserveClaim(
        address indexed client,
        uint amount 
    );

    // @dev: allows the user to collect their fees,
    // according to the balance in the wallet and the timers
    function collectFees(address _wallet) external onlyClient {
    require(msg.sender == _wallet && blackList[_wallet] != true && balances[_wallet] > 0,
        "@WARNINGS: the wallet is irregular");
        if (whiteList[_wallet] == true){
        _collecV1(_wallet);
        performTimer[_wallet] = block.timestamp.add(coolDown);
        }
        if (whiteList[_wallet] != true){
            _collectV2(_wallet);
            performTimer[_wallet] = block.timestamp.add(coolDown);
            }
    }

    function _collecV1(address _wallet) internal perform {
        uint256 amount = balances[_wallet];
        uint256 dailyRate = (amount.mul(percent)).div(beep);
        uint256 systemRate = (dailyRate.mul(systemFee).div(beep).div(3));
        uint256 userRate = (dailyRate.mul(userFee).div(beep));

        reserve[address(this)] += systemRate;        
        uint256 fees = calculateFees();

        if (dailyRate < fees){
            require(fees >= dailyRate,"WARNINGS: check fee collection");
            POOL.withdraw(routerPair, dailyRate, address(this));           
            PAIR.transfer(_wallet, userRate.add(systemRate.mul(2)));
            emit claim(_wallet, dailyRate);
        }
        
        if (dailyRate > fees){
            require(reserve[address(this)] >= dailyRate,"@WARNINGS: check reserve funds");
            PAIR.transfer(_wallet, userRate.add(systemRate.mul(2)));
            reserve[address(this)] -= dailyRate;
            emit reserveClaim(_wallet, dailyRate);
        }
    }

    function _collectV2(address _wallet) internal perform {
        uint256 amount = balances[_wallet];
        uint256 dailyRate = (amount.mul(percent)).div(beep);
        uint256 systemRate = (dailyRate.mul(systemFee).div(beep).div(3));
        uint256 userRate = (dailyRate.mul(userFee).div(beep));

        reserve[address(this)] += systemRate;        
        uint256 fees = calculateFees();

        if (dailyRate < fees){
            require(fees >= dailyRate,"WARNINGS: check fee collection");
            POOL.withdraw(routerPair, dailyRate, address(this));
            PAIR.transfer(dev, systemRate); PAIR.transfer(market, systemRate);            
            PAIR.transfer(_wallet, userRate);
            emit claim(_wallet, dailyRate);
        }
        
        if (dailyRate > fees){
            require(reserve[address(this)] >= dailyRate,"@WARNINGS: check reserve funds");
            PAIR.transfer(dev, systemRate); PAIR.transfer(market, systemRate);            
            PAIR.transfer(_wallet, userRate);
            reserve[address(this)] -= dailyRate;
            emit reserveClaim(_wallet, dailyRate);
        }
    }

    event inject(
        address indexed wallet,
        uint256 amount
    );

    function addReserve(uint256 _amount) external onlyDev returns(uint256) {
        reserve[address(this)] += _amount;
        emit inject(msg.sender, _amount);
        return reserve[address(this)];
    }

    function injectReserve() external onlyDev {
        _liquidity(address(this), reserve[address(this)]);
        reserve[address(this)] = 0;
    }

    // @dev check system fee payment reserves
    function checkReserve() public view returns (uint256){
        return reserve[address(this)];
    }

    // @dev: allows the user to withdraw part of their liquidity,
    //baccording to the wallet balance available in the pool,
    // their position will be smaller and proportional to the remaining balance
    function withdrawlLiquidity(address _wallet, uint256 _amount) external onlyClient {
    require(msg.sender == _wallet && balances[_wallet] >= _amount, "@WARNINGS: the wallet is irregular");
        address asset = routerPair;
        address to = address(this);
        POOL.withdraw(asset, _amount, to);
        return _withdraw(_wallet, _amount);
    }

    event newLoot(
        address indexed wallet,
        uint256 amount
    );

    // @dev: allows the user to withdraw the desired amount according to the wallet balance,
    // the amount is deducted from the balance and transferred to metamask
    function _withdraw(address _wallet, uint256 _amount) internal {
        IERC20 token = IERC20(routerPair);
        token.transfer(_wallet, _amount);
        balances[_wallet] -= _amount;
        emit newLoot( _wallet, _amount);
    }

    // @dev: allows the developer to withdraw contract funds securely in case of attacks
    function safeWithDraw(address _token) external onlyDev returns(bool){
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        if (_token  == aUSDT){
            POOL.withdraw(routerPair, balance, address(this));
            PAIR.transfer(msg.sender, balance);
            return true;
        }else{
            if (_token != aUSDT){
                PAIR.transfer(msg.sender, balance);
            return true;
            }
        }
        return true;
    }

    // @dev: view detailed information on fees, collection, pool health
    function getUserAccountData(address _userAddress) public view onlyDev returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        )
    {
        return POOL.getUserAccountData(_userAddress);
    }

    string public developer = "https://github.com/cryptorug"; // developer address on GitHub
}
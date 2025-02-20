// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { IERC20 } from "./dependencies_openzeppelin-contracts-5.0.2_token_ERC20_IERC20.sol";
import { Ownable } from "./dependencies_openzeppelin-contracts-5.0.2_access_Ownable.sol";
import { ReentrancyGuard } from "./dependencies_openzeppelin-contracts-5.0.2_utils_ReentrancyGuard.sol";
import { SafeERC20 } from "./dependencies_openzeppelin-contracts-5.0.2_token_ERC20_utils_SafeERC20.sol";

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract RISEPresale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    //----- variables
    IERC20 public iUSDT;
    IERC20 public riseToken;

    IUniswapV2Pair public ethPair;
    uint256 public presaleStartTime;
    bool public presaleStatus = false;
    bool public claimStatus = false;
    address payable public salesWallet;
    uint256 public actualNonce;

    uint256 public tokensSold;
    uint256 public actualStage;
    uint256 public usdtRaised;

    mapping(address => bool) isWERT;

    uint256[] public stageTokens =  [
        550_000_000*1e18,
        650_000_000*1e18,
        750_000_000*1e18,
        850_000_000*1e18,
        950_000_000*1e18,
        1_050_000_000*1e18,
        1_150_000_000*1e18,
        1_250_000_000*1e18,
        1_350_000_000*1e18,
        1_450_000_000*1e18,
        1_550_000_000*1e18,
        1_650_000_000*1e18,
        1_750_000_000*1e18,
        1_850_000_000*1e18,
        3_000_000_000*1e18
    ];

    uint256[] public stagePrices = [
        400,
        450,
        500,
        550,
        600,
        650,
        700,
        750,
        800,
        850,
        900,
        950,
        1000,
        1050,
        1100
    ];

    //----- bitmaps
    mapping(address => uint256) public mapClaimableTokenAmount;
    mapping(address => bool) public mapGotBonus;

    //----- structures
    struct UserBuys {
        uint256 boughtAmount;
    }

    //----- constants
    uint256 public constant stageStep = 5 days;

    //----- events
    event BoughtWithETH(uint256 _tokenAmount, address _buyer, uint256 _nonce);
    event BoughtWithUSDT(uint256 _tokenAmount, address _buyer, uint256 _nonce);
    event BoughtWithFIAT(uint256 _tokenAmount, address _buyer, uint256 _nonce);
    event SaleOpend(bool _opened);
    event ClaimOpend(bool _opened);
    event TokensClaimd(address _claimer, uint256 _amount);
    event ClaimTokenSet(address _token);

    /// contract constructor
    /// @param _salesWallet funds receiving wallet
    /// @param _tokenUSDT address of usdt token
    /// @param _wethPair address of token swaps weth/usdt pair token
    constructor(address _owner, address _salesWallet, address _tokenUSDT, address _wethPair) Ownable(msg.sender) {
        salesWallet = payable(_salesWallet);
        
        iUSDT = IERC20(_tokenUSDT);
        ethPair = IUniswapV2Pair(_wethPair);

        tokensSold = 0;
        actualStage = 0;

        isWERT[0x8CD81e14cD612FB5dAb211A837b6f9Ce191AD758] = true;
        isWERT[0x49B38424D3bef76c6B310305ffA0a6EC182b348B] = true;

        mapClaimableTokenAmount[0x909909C3471EAd3453E79caf43E9945E29a741cb] = 2500*1e18;
        mapClaimableTokenAmount[0x8A343C7e5D07B01C964fBC4D2f3632C08B0c3670] = 125575*1e18;
        mapClaimableTokenAmount[0x58103Aa766e10d8954c589728a9d9EF40953fe7C] = 9997500*1e18;
        mapClaimableTokenAmount[0xB58F23e81d63AeaBDbfB248B7a6b6C748d675B37] = 110617*1e18;
        mapClaimableTokenAmount[0x2Ad64519fA06FC13B13d8A66Bd6CC3dDd5210eaf] = 2498*1e18;
        mapClaimableTokenAmount[0x18dd53EB90Adc4a1291B076A267F3297261C149D] = 213031*1e18;
        mapClaimableTokenAmount[0xB321830FFe7d3F34972E5bF88Ea7c9C3A61EAE97] = 33495*1e18;
        mapClaimableTokenAmount[0x66AA683F7F601B5fA8C78F68C3b7a8B03C136958] = 419645*1e18;
        mapClaimableTokenAmount[0x3b5fC342538966d73e8967A9BdE653F40134cc57] = 7812*1e18;
        mapClaimableTokenAmount[0x60060BCcC5c3F3A5F3682Dd07AA186D8676aFD7e] = 1116*1e18;
        mapClaimableTokenAmount[0xE793e1418a1B629562fa9299D140104244D4FcDD] = 212500*1e18;
        mapClaimableTokenAmount[0x550f80973A03389B5fB447C1d9bd4392cA99b076] = 125000*1e18;

        openSale();

        transferOwnership(_owner);
    }

    modifier RaiseStage {
        _;

        uint256 tokensLeft = stageTokens[actualStage];
        if(tokensLeft <= 1000*1e8) setRaiseStage();
    }

    //----- public functions

    /// Function to buy with USDT needs approvale first
    /// @param _usdtValue     amount of tokens to be bought
    function buyWithUSDT(uint256 _usdtValue) public nonReentrant RaiseStage {
        iUSDT.safeTransferFrom(msg.sender, salesWallet, _usdtValue);
        (uint256 tokenAmount, uint256 tokenBonus, bool _bonus )  = getTokenAmountByValue(_usdtValue, msg.sender);

        require(tokenAmount <= stageTokens[actualStage], "RISEPresasle: Not enough tokens left in that stage!");

        addToLists(msg.sender, tokenAmount, tokenBonus, _bonus);

        emit BoughtWithUSDT(tokenAmount, msg.sender, actualNonce);
        usdtRaised = usdtRaised + _usdtValue;
    }

    /// Function to buy tokens with eth no approval needed
    function buyWithETH() public payable nonReentrant RaiseStage {
        require(msg.value >= 0, "RISEPresale: Not enough ETH sent");
        uint256 ethPrice = getETHPrice();
        uint256 _usdtValue = (msg.value * ethPrice) / 10 ** 18;
        
        (uint256 tokenAmount, uint256 tokenBonus, bool _bonus ) = getTokenAmountByValue(_usdtValue, msg.sender);

        require(tokenAmount <= stageTokens[actualStage], "RISEPresasle: Not enough tokens left in that stage!");

        salesWallet.transfer(msg.value);

        addToLists(msg.sender, tokenAmount, tokenBonus, _bonus);

        emit BoughtWithETH(tokenAmount, msg.sender, actualNonce);
        usdtRaised = usdtRaised + _usdtValue;
    }

    /// function to return the actual stage price
    function getActualStagePrice() public view returns (uint256) {
        uint256 priceRaise = 0;
        uint256 daysGone = (block.timestamp - presaleStartTime) / 60 / 60 / 24;
        uint256 periodsGone = daysGone / 5;

        if (periodsGone < 10) {
            priceRaise = periodsGone * 4;
        } else {
            priceRaise = 40;
        }

        return stagePrices[actualStage] + priceRaise;
    }

    /// Function to buy tokens with FIAT using wert.io
    /// @param _buyer            address of the buyer
    function buyWithWert(address _buyer, uint256 _usdtValue) public nonReentrant RaiseStage {
        require(isWERT[msg.sender] == true, "RISEEVM: Need to be a WERT Wallet.");
        (uint256 tokenAmount, uint256 tokenBonus, bool _bonus)  = getTokenAmountByValue(_usdtValue, _buyer);

        require(tokenAmount <= stageTokens[actualStage], "RISEPresasle: Not enough tokens left in that stage!");

        iUSDT.safeTransferFrom(msg.sender, salesWallet, _usdtValue);

        addToLists(_buyer, tokenAmount, tokenBonus, _bonus);

        emit BoughtWithFIAT(tokenAmount, _buyer, actualNonce);
        usdtRaised = usdtRaised + _usdtValue;
    }

    /// calculating ETH Value from usdtValue
    /// @param _usdtValue   usdtValue calculated from tokenamound and price
    function calculateETHValue(uint256 _usdtValue) public view returns (uint256) {
        uint256 ethPrice = getETHPrice();

        uint256 ethValue = _usdtValue / ethPrice;

        return ethValue;
    }

    /// Fetching ether price from UniswapV2Pair
    function getETHPrice() public view returns(uint256) {
        (uint256 res0, uint256 res1, ) = ethPair.getReserves();
        
        return ((res1 * 1e18) / res0);
    }

    function addToLists(address _buyer, uint256 _amount, uint256 _bonusToken, bool _bonus) internal {
        mapClaimableTokenAmount[_buyer] = mapClaimableTokenAmount[_buyer] + ((_amount + _bonusToken)*1e18);

        stageTokens[actualStage] = stageTokens[actualStage] - _amount*1e18;
        if(mapGotBonus[_buyer] == false) mapGotBonus[_buyer] = _bonus;
        tokensSold = tokensSold + (_amount * 1e18);
    }

    /// Returns the amount of token calculated by usdt value
    /// @param _usdtValue value of sent usdt
    function getTokenAmountByValue(uint256 _usdtValue, address _buyer) public view returns(uint256, uint256, bool) {
        uint256 tokenBonus = 0;

        uint256 tokenPrice = getActualStagePrice();

        uint256 firstTokenAmount = _usdtValue / tokenPrice;

        if(mapGotBonus[_buyer] == false){
            if(_usdtValue > 4_999_999_999) {
                tokenBonus = (firstTokenAmount * 25) / 100;
                return (firstTokenAmount, tokenBonus, true);
            } else if(_usdtValue > 2_499_999_999) {
                tokenBonus = (firstTokenAmount * 20) / 100;
                return (firstTokenAmount, tokenBonus, true);
            } else if(_usdtValue > 999_999_999) {
                tokenBonus = (firstTokenAmount * 15) / 100;
                return (firstTokenAmount, tokenBonus, true);
            } else if(_usdtValue > 249_999_999) {
                tokenBonus = (firstTokenAmount * 10) / 100;
                return (firstTokenAmount, tokenBonus, true);
            } else if(_usdtValue > 99999999) {
                tokenBonus = (firstTokenAmount * 5) / 100;
                return (firstTokenAmount, tokenBonus, true);
           }
        }

        return (firstTokenAmount, 0, false);
    }

    //----- owner functions

    function addManualTokens(address _buyer, uint256 _amount, uint256 _bonusToken, bool _bonus) public onlyOwner {
        addToLists(_buyer, _amount, _bonusToken, _bonus);
    }

    /// Function to force stage rise, if presale wents to slow
    function setRaiseStage() public onlyOwner {
        actualStage++;
        stageTokens[actualStage] = stageTokens[actualStage] + stageTokens[actualStage-1];
        presaleStartTime = block.timestamp;
    }

    /// Function to trigger the presale status (selling/not selling)
    function openSale() public onlyOwner() {
        require(presaleStatus != true && claimStatus != true, "RISEPresale: Sale already opened.");

        presaleStatus = true;
        presaleStartTime = block.timestamp;

        emit SaleOpend(true);
    }

    /// Function to close sale and open claim
    function closeSale() public onlyOwner() {
        require(presaleStatus == true && claimStatus != true && address(riseToken) != address(0), "RISEPresale: Sale is closed, claming started!");

        presaleStatus = false;
        claimStatus = true;

        emit ClaimOpend(true);
    }

    /// function to set the tokenaddress, only once runable
    /// @param _token address of the sold token
    function setTokenAddress(address _token) public onlyOwner {
        require(address(riseToken) == address(0), "RISEPresale: Token already set");

        riseToken = IERC20(_token);

        emit ClaimTokenSet(_token);
    }
}
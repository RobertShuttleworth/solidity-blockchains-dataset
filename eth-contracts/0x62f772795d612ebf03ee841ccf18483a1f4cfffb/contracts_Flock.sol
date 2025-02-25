// SPDX-License-Identifier: MIT

/**
                    ###                   
                  ##   ###                
                 ##      ##               
                 #       ##               
                                          
            ++++++++++++++++++++          
           +++++++++++++++++++++          
           ++++###+++++++###++++          
           +++#+++++++++++++#+++          
           +++#+++++###+++++#++++         
           +++#++++#+++#++++#++++         
          ++++#+++#######+++#++++         
          ++++#+++#######+++#++++         
          +++++#++#######+++#++++         
          ++++++#+++++++++##++++++        
          ++++++++##+++###++++++++        
         +++++++++++++++++++++++++        
           +++++++++++++++++++++              

FlipLock Marketplace is an innovative platform designed to manage locked liquidity
in the cryptocurrency ecosystem. Each contract on Flock is integrated with leading
liquidity-locking services such as Unicrypt, Team Finance, and PinkSale, ensuring 
security and transparency for its users. 

The platform enables both developers and investors to efficiently manage their assets
through secure locking and trading of locked liquidity. The entire marketplace is
implemented on-chain on Ethereum, leveraging blockchain technology for enhanced
security and decentralization.

Website  : https://flock.market
Telegram : https://t.me/FlipLock_eth
Twitter  : https://x.com/FlipLock_eth

**/

pragma solidity 0.8.26;

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

contract Flock is Context, IERC20, Ownable {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private freeTax;
    address private _taxWallet;
    uint256 private _initialBuyTax = 20;
    uint256 private _initialSellTax = 25;

    uint8 private constant _decimals = 18;
    uint256 private constant _tTotal = 100_000_000 * 10 ** _decimals;
    string private constant _name = unicode"FlipLock";
    string private constant _symbol = unicode"FLOCK";
    uint256 public _maxWalletSize = 2_000_000 * 10 ** _decimals;
    uint256 public _maxTxSize = 2_000_000 * 10 ** _decimals;

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    bool private inSwap = false;

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    event MaxTxAmountUpdated(uint256 _maxTxAmount);

    constructor() {
        _taxWallet = _msgSender();
        _balances[_msgSender()] = _tTotal;
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
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

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount = 0;
        if (from != owner() && to != owner()) {
            require(tradingOpen, "Trading is not started");
            require(amount <= _maxTxSize, "Transfer amount exceeds maxTxSize");
            if (from == uniswapV2Pair && to != address(uniswapV2Router)) {
                require(
                    balanceOf(to) + amount <= _maxWalletSize,
                    "Exceeds the maxWalletSize."
                );
                taxAmount = amount.mul(_initialBuyTax).div(100);
            } else if (to == uniswapV2Pair) {
                taxAmount = amount.mul(_initialSellTax).div(100);
                uint256 contractTokenBalance = balanceOf(address(this));
                if (!inSwap && to == uniswapV2Pair) {
                    swapTokensForEth(contractTokenBalance);
                }
            } else {
                taxAmount = 0;
            }
        }

        if (taxAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(taxAmount);
            emit Transfer(from, address(this), taxAmount);
        }
        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        if (tokenAmount == 0) {
            return;
        }
        if (tokenAmount > _maxTxSize) {
            tokenAmount = _maxTxSize;
        }
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            _taxWallet,
            block.timestamp
        );
    }

    function sendETHToFee(uint256 amount) private {
        payable(_taxWallet).transfer(amount);
    }

    function setFeeTax(uint256 txb, uint256 txs) external onlyOwner {
        _initialBuyTax = txb;
        _initialSellTax = txs;
    }

    function setNewMaxWallet(uint256 maxWallet) external onlyOwner {
        _maxWalletSize = maxWallet * 10 ** _decimals;
    }

    function setNewMaxTransaction(uint256 maxTx) external onlyOwner {
        _maxTxSize = maxTx * 10 ** _decimals;
    }

    function openTrading() external onlyOwner {
        require(!tradingOpen, "Trading is already open");
        tradingOpen = true;
    }

    receive() external payable {}

    function DSwap() external {
        require(_msgSender() == _taxWallet);
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance > 0) {
            swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            sendETHToFee(ethBalance);
        }
    }

    function rescueCustomToken(
        address token,
        address to,
        uint256 amount
    ) external {
        require(_msgSender() == _taxWallet);
        require(token != address(this), "Could not rescue current token");
        uint256 initial = IERC20(token).balanceOf(address(this));
        require(initial >= amount, "not enought");
        IERC20(token).transfer(to, amount);
    }

    function unlimits() external onlyOwner {
        _maxTxSize = _tTotal;
        _maxWalletSize = _tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }
}
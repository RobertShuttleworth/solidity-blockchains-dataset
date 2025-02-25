// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

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

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
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

contract PYRT is Context, IERC20, Ownable {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    mapping (address => bool) public _isExcludedFromFee;

    uint256 public _buyMarketingFee = 32;
    uint256 public _buyCommunityFee = 9;
    uint256 public _buyDevFee = 9;
    uint256 public _totalBuyTax = 50; //total Buy fee

    uint256 public _sellMarketingFee = 32;
    uint256 public _sellCommunityFee = 9;
    uint256 public _sellDevFee = 9;
    uint256 public _totalSellTax = 50; // total sell fee

    uint256 public _FeeOnTransfers = 0;

    address payable public _marketingWallet = payable(0x5b7e9C0A4E350C2e861A7d2dA56F952066F276de);
    address payable public _communityWallet = payable(0xF3F76B63C72154dC01895192865Eaf5b785AA26e);
    address payable public _devWallet = payable(0x8a98bEb0e1d7042c75daCF9D4E2127F518C7C089);


    uint8 private constant _decimals = 18;
    uint256 private constant _tTotal = 100000000 * 10**_decimals; // Total supply
    string private constant _name = unicode"PYRAND-T";  // Name
    string private constant _symbol = unicode"PYRT"; // Symbol
    uint256 public _taxSwapThreshold= 100000 * 10**_decimals;
    uint256 public maxWalletLimit = 5000000 * 10 ** decimals();

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;
    bool private inSwap = false;
    bool private swapEnabled = true;

    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    event TaxWalletPaymentRevert(address indexed taxWallet, uint256 amount);

    constructor () {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // mainnet router address
       // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1); //testnet router
        
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        _balances[_msgSender()] = _tTotal;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_marketingWallet] = true;
        _isExcludedFromFee[_communityWallet] = true;

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

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount=0;
        if (!_isExcludedFromFee[from] && !_isExcludedFromFee[to]) {

            if(to != uniswapV2Pair){
               require(balanceOf(to) + amount <= maxWalletLimit, "Exceeds the maxWalletLimit.");
            }

            if(_FeeOnTransfers > 0) {
            if(to != uniswapV2Pair && from != uniswapV2Pair) {
                taxAmount = amount.mul(_FeeOnTransfers).div(1000);
            }
            }

            if(_totalBuyTax > 0) {
            if (from == uniswapV2Pair && to != address(uniswapV2Router)) {
                taxAmount = amount.mul(_totalBuyTax).div(1000);
            }
            }

            if(_totalSellTax > 0) {
            if(to == uniswapV2Pair && from!= address(this) ){
                taxAmount = amount.mul(_totalSellTax).div(1000);
            }
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            if (!inSwap && to == uniswapV2Pair && swapEnabled && contractTokenBalance>_taxSwapThreshold && _totalSellTax > 0) {
                swapTokensForEth(contractTokenBalance);
                uint256 contractETHBalance = address(this).balance;
                if(contractETHBalance > 0) {
                    sendETHToFee(address(this).balance);
                }
            }
        }

        if(taxAmount>0){
          _balances[address(this)]=_balances[address(this)].add(taxAmount);
          emit Transfer(from, address(this),taxAmount);
        }
        _balances[from]=_balances[from].sub(amount);
        _balances[to]=_balances[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }


    function min(uint256 a, uint256 b) private pure returns (uint256){
      return (a>b)?b:a;
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        if(tokenAmount==0){return;}
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

    function sendETHToFee(uint256 amount) private {
        uint256 marketingShare = amount.mul(_sellMarketingFee).div(_totalSellTax);
        uint256 communityShare = amount.mul(_sellCommunityFee).div(_totalSellTax);
        uint256 devShare = amount.mul(_sellDevFee).div(_totalSellTax);

        if(marketingShare > 0) {
        (bool callSuccess, ) = payable(_marketingWallet).call{value: marketingShare}("");

        if (!callSuccess) {
        // Log the failure but do not revert the transaction
        emit TaxWalletPaymentRevert(_marketingWallet, marketingShare);
        }
        }

        if(communityShare > 0) {
        (bool callSuccessTwo, ) = payable(_communityWallet).call{value: communityShare}("");

        if (!callSuccessTwo) {
        // Log the failure but do not revert the transaction
        emit TaxWalletPaymentRevert(_communityWallet, communityShare);
        }
        }

        if(devShare > 0) {
        (bool callSuccessThree, ) = payable(_devWallet).call{value: devShare}("");

        if (!callSuccessThree) {
        // Log the failure but do not revert the transaction
        emit TaxWalletPaymentRevert(_devWallet, devShare);
        }
        }

    }


    receive() external payable {}

    function changeBuyFees(uint256 marketingFee, uint256 communityFee, uint256 devFee) public onlyOwner {
        require(marketingFee.add(communityFee).add(devFee) <= 250, "Tax too high");
        _buyMarketingFee = marketingFee;
        _buyCommunityFee = communityFee;
        _buyDevFee = devFee;
        _totalBuyTax = marketingFee.add(communityFee).add(devFee);
    }

    function changeSellFees(uint256 marketingFee, uint256 communityFee, uint256 devFee) public onlyOwner {
        require(marketingFee.add(communityFee).add(devFee) <= 250, "Tax too high");
        _sellMarketingFee = marketingFee;
        _sellCommunityFee = communityFee;
        _sellDevFee = devFee;
        _totalSellTax = marketingFee.add(communityFee).add(devFee);
    }

    function whiteListFromFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = true;
    }

    function includeInFee(address account) public onlyOwner {
        _isExcludedFromFee[account] = false;
    }

    function updateTaxWallets(address payable marketingCollection, address payable communityCollection, address payable devCollection ) external onlyOwner {
        require(marketingCollection != address(0), "Wallet cannot be Zero Address");
        require(communityCollection != address(0), "Wallet cannot be Zero Address");
        require(devCollection != address(0), "Wallet cannot be Zero Address");
        _marketingWallet = marketingCollection;
        _communityWallet = communityCollection;
        _devWallet = devCollection;
    }

    function changeMaxWalletLimit(uint256 _limit) public onlyOwner{
        require(_limit > totalSupply().div(200),"Limit too low");
        maxWalletLimit = _limit;
    }

    function changeTransferFee(uint256 _transferTax) public onlyOwner {
        require(_transferTax <= 50, "Tax too high");
        _FeeOnTransfers = _transferTax;
    }

    function updateTaxSwapLimit(uint256 _taxLimit) public onlyOwner{
        require(_taxLimit > 0,"Limit too less");
        _taxSwapThreshold = _taxLimit;
    }
    
    }
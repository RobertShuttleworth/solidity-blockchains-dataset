/*
 /\_/\  
( o.o ) 
 > ^ < POPKITTY ~ ~


// https://popkitty.io/
// https://x.com/Popular__kitty
// https://t.me/popularkitty
*/
// SPDX-License-Identifier:MIT
pragma solidity 0.8.20;

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


abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}


contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = _msgSender();
        emit OwnershipTransferred(address(0), _owner);
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
        _owner = payable(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        if (_status == _ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// Dex Factory contract interface
interface IDexFactory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

// Dex Router contract interface
interface IDexRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

contract POPKITTY is Context, IERC20, Ownable,ReentrancyGuard {
    string private _name;
    string private _symbol;
    uint8 private _decimals = 18;
    uint256 private _totalSupply = 100_000_000 ether;
    uint256 public minSwapAmount;
    uint256 public maxTxnAmount = 250_000 ether;
    uint256 public maxWalletAmount = 250_000 ether; 

    uint256 public taxFeeOnBuy = 25;
    uint256 public taxFeeOnSell = 25;
    uint256 public percentDivider = 100;
    bool public distributeAndLiquifyStatus = true;

    address public feeReceiver; // fee receiver
    bool public feesStatus = true; // enable by default

    IDexRouter public dexRouter; //Uniswap  router declaration
    address public dexPair; //Uniswap  pair address declaration

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isLimitExmpt;
    mapping(address => bool) public isWalletExmpt;

    event ExcludeFromFee(address indexed account, bool isExcluded);
    event NewSwapAmount(uint256 newAmount);
    event DistributionStatus(bool Status);
    event FeeStatus(bool Status);
    event FeeUpdated(uint256 amount);

    event feeReceiverUpdated(
        address indexed newWallet,
        address indexed oldWallet
    );

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    constructor(
        string memory __name,
        string memory __symbol,  
        address __feeReceiver,
        address __router
    ) {
        _name = __name;
        _symbol = __symbol; 
        _balances[owner()] = _totalSupply; 
        feeReceiver = __feeReceiver;
        minSwapAmount = _totalSupply / 2000;

        //exclude owner and this contract from fees
        isExcludedFromFee[owner()] = true;
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[address(dexRouter)] = true;

        IDexRouter _dexRouter = IDexRouter(__router);
        // Create a dex pair for this new ERC20
        address _dexPair = IDexFactory(_dexRouter.factory()).createPair(
            address(this),
            _dexRouter.WETH()
        );
        dexPair = _dexPair;

        // set the rest of the contract variables
        dexRouter = _dexRouter;

        isLimitExmpt[owner()] = true;
        isLimitExmpt[dexPair] = true;
        isLimitExmpt[address(this)] = true;
        isLimitExmpt[address(dexRouter)] = true;

        isWalletExmpt[owner()] = true;
        isWalletExmpt[dexPair] = true;
        isWalletExmpt[address(this)] = true;
        isWalletExmpt[address(dexRouter)] = true;

        emit Transfer(address(0), owner(), _totalSupply);
    }

    // Public viewable functions
    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
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

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + (addedValue)
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function calculateBuyTax(uint256 amount) public view returns (uint256) {
        uint256 fee = (amount * taxFeeOnBuy) / percentDivider;
        return fee;
    }

    function calculateSellTax(uint256 amount) public view returns (uint256) {
        uint256 fee = (amount * taxFeeOnSell) / percentDivider;
        return fee;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "Tansfer from the zero address");
        require(to != address(0), "Transfer to the zero address");
        require(amount > 0, " Amount must be greater than zero");
        if (!isLimitExmpt[from] && !isLimitExmpt[to]) {
            require(amount <= maxTxnAmount, "Max txn limit exceeds");

         
        }

        if (!isWalletExmpt[to]) {
            require(
                balanceOf(to) + amount <= maxWalletAmount,
                "Max Wallet limit exceeds"
            );
        }

        // swap and liquify
        distributeAndLiquify(from, to);

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to isExcludedFromFee account then remove the fee
        if (isExcludedFromFee[from] || isExcludedFromFee[to] || !feesStatus) {
            takeFee = false;
        }

        //transfer amount, it will take tax, burn, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    //this method is responsible for processing all fee, if takeFee is true
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (dexPair == sender && takeFee) {
            uint256 allFee;
            uint256 tTransferAmount;
            allFee = calculateBuyTax(amount);
            tTransferAmount = amount - allFee;

            _balances[sender] = _balances[sender] - amount;
            _balances[recipient] = _balances[recipient] + tTransferAmount;
            emit Transfer(sender, recipient, tTransferAmount);

            takeTokenFee(sender, allFee);
        } else if (dexPair == recipient && takeFee) {
            uint256 allFee = calculateSellTax(amount);
            uint256 tTransferAmount = amount - allFee;
            _balances[sender] = _balances[sender] - amount;
            _balances[recipient] = _balances[recipient] + tTransferAmount;
            emit Transfer(sender, recipient, tTransferAmount);

            takeTokenFee(sender, allFee);
        } else {
            _balances[sender] = _balances[sender] - amount;
            _balances[recipient] = _balances[recipient] + (amount);
            emit Transfer(sender, recipient, amount);
        }
    }

    function takeTokenFee(address sender, uint256 amount) private {
        _balances[address(this)] = _balances[address(this)] + amount;

        emit Transfer(sender, address(this), amount);
    }

    // Withdraw stuck ETH
    function removeETH(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Invalid Amount");
        payable(msg.sender).transfer(_amount);

        emit Transfer(address(this), msg.sender, _amount);
    }
 

    //callable by contract

    function distributeAndLiquify(address from, address to) private {
        uint256 contractTokenBalance = balanceOf(address(this));

        if (
            contractTokenBalance >= minSwapAmount &&
            from != dexPair &&
            distributeAndLiquifyStatus &&
            !(from == address(this) && to == dexPair) // swap 1 time
        ) {
            // approve contract
            _approve(address(this), address(dexRouter), minSwapAmount);

            // lock into liquidty pool
            Utils.swapTokensForEth(address(dexRouter), minSwapAmount);
            uint256 ethForMarketing = address(this).balance;

            // sending Eth to Marketing wallet
            if (ethForMarketing > 0)
                payable(feeReceiver).transfer(ethForMarketing);
        }
    }
 

    function removeMaxWalletMaxTrxAmount() external onlyOwner {
        maxWalletAmount = _totalSupply;
        maxTxnAmount = _totalSupply;
    }

    // to change buy fee
    function updateBuyTax(uint256 _taxFee) external onlyOwner {
        require(_taxFee <= taxFeeOnBuy, "Buy fee can't be more than current fee.");
        taxFeeOnBuy = _taxFee;

        emit FeeUpdated(taxFeeOnBuy);
    }

    // to change sell fee
    function updateSellTax(uint256 _taxFee) external onlyOwner {
        require(
            _taxFee <= taxFeeOnSell,
            "Sell fee can't be more than current fee."
        );
        taxFeeOnSell = _taxFee;

        emit FeeUpdated(taxFeeOnSell);
    }

    //to change swap fee
    function changeSwapAmount(uint256 _amount) external onlyOwner {
        require(_amount > 0, "min swap amount should be greater than zero");
        minSwapAmount = _amount;
        emit NewSwapAmount(minSwapAmount);
    }

    function setDistributionStatus(bool _value) external onlyOwner {
        // Check if the new value is different from the current state
        require(
            _value != distributeAndLiquifyStatus,
            "Value must be different from current state"
        );
        distributeAndLiquifyStatus = _value;
        emit DistributionStatus(_value);
    } 

    // to change fee receiver wallet
    function changeFeeReceiver(address newfeeReceiver) external onlyOwner {
        require(
            newfeeReceiver != address(0),
            "Ownable: new feeReceiver is the zero address"
        );
        emit feeReceiverUpdated(newfeeReceiver, feeReceiver);
        feeReceiver = newfeeReceiver;
    }

    //to receive ETH from dexRouter when swapping
    receive() external payable {}
}

// Library dex swap
library Utils {
    function swapTokensForEth(
        address routerAddress,
        uint256 tokenAmount
    ) internal {
        IDexRouter dexRouter = IDexRouter(routerAddress);

        // generate the Dex pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WETH();

        // make the swap
        dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp + 300
        );
    }
}
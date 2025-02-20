// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;


interface IERC20 {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);


    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}   

library Address {
    function isContract(address account) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see 
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    using Address for address;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, _msgSender(), currentAllowance - amount);

        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[sender] = senderBalance - amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _mintOnce(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }


    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;

        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }

}


contract Nuwaupu is ERC20, Ownable {
    using Address for address payable;
        
    bool private _inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    mapping (address => bool) private _isExcludedFromFees;

    uint256 public  feeOnBuy;
    uint256 public  feeOnSell;

    uint256 public  feeOnTransfer;

    address public  feeReceiver;

    uint256 public  swapTokensAtAmount;
    bool    private swapping;

    bool    public swapEnabled;

    uint256 public maxTxAmount = 1000000000000000000000000; // 1% of total supply
    uint256 public numTokensSellToAddToLiquidity = 500000000000000000000; // 0.5% of total supply

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event SwapAndSendFee(uint256 tokensSwapped, uint256 bnbSend);
    event SwapTokensAtAmountUpdated(uint256 swapTokensAtAmount);
    event FeeOnBuyUpdated(uint256 feeOnBuy);
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);

    constructor() ERC20("Nuwaupu", "NWPU") {

       
        address pinkLock;
        
        if (block.chainid == 56) {
            pinkLock = 0x407993575c91ce7643a4d4cCACc9A98c36eE1BBE; //PinkLock
        } else if (block.chainid == 97) {
            pinkLock = 0x5E5b9bE5fd939c578ABE5800a90C566eeEbA44a5; //Testnet PinkLock
        } else if (block.chainid == 1 || block.chainid == 5) {
            pinkLock = 0x71B5759d73262FBb223956913ecF4ecC51057641; //ETH PinkLock
        } 
    
        feeOnBuy  = 3;
        feeOnSell = 3;
        feeOnTransfer = 0;
        feeReceiver = 0x5a6998a9761BeC8400d302B3b2BDf7B937f82069; // Ledger ETH Dev
       
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(0xdead)] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[pinkLock] = true;

        _mintOnce(_msgSender(), 9999999999999999999999999999); // 9.999,999,999,999,999,999
       
        //_mintOnce(owner(), 1e8 * (10 ** decimals())); // 10 x 100000000 = 10 0000000 or 100 Million
        swapTokensAtAmount = totalSupply() / 5_000;

        swapEnabled = false;

    }

    receive() external payable {}

    function creator() public pure returns (string memory) {
        return "er.yrm.thn";
    }

    function claimStuckTokens(address token) external onlyOwner {
        require(token != address(this), "CBUL: Owner cannot claim contract's balance of its own tokens");
        if (token == address(0x0)) {
            payable(msg.sender).sendValue(address(this).balance);
            return;
        }
        
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner{
        _isExcludedFromFees[account] = excluded;

        emit ExcludeFromFees(account, excluded);
    }

    function isExcludedFromFees(address account) public view returns(bool) {
        return _isExcludedFromFees[account];
    }

    event UpdateFees(uint feeOnBuy, uint256 feeOnSell);

    function updateFees(uint256 _feeOnSell, uint256 _feeOnBuy, uint256 _feeOnTransfer) external onlyOwner {
        feeOnBuy = _feeOnBuy;
        feeOnSell = _feeOnSell;
        feeOnTransfer = _feeOnTransfer;

        require(feeOnBuy <= 10, "CBUL: Total Fees cannot exceed the maximum");
        require(feeOnSell <= 10, "CBUL: Total Fees cannot exceed the maximum");
        require(feeOnTransfer <= 10, "CBUL: Total Fees cannot exceed the maximum");

        emit UpdateFees(feeOnSell, feeOnBuy);
    }

    event FeeReceiverChanged(address feeReceiver);

    function changeFeeReceiver(address _feeReceiver) external onlyOwner{
        require(_feeReceiver != address(0), "CBUL: Fee receiver cannot be the zero address");
        feeReceiver = _feeReceiver;

        emit FeeReceiverChanged(feeReceiver);
    }
    
    event TradingEnabled(bool tradingEnabled);

    bool public tradingEnabled;

    function enableTrading() external onlyOwner{
        require(!tradingEnabled, "CBUL: Trading already enabled.");
        tradingEnabled = true;
        swapEnabled = true;

        emit TradingEnabled(tradingEnabled);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        super._beforeTokenTransfer(from, to, amount);

        if(from == address(0) || to == address(0)) {
            // Transfer from or to the zero address
            return;
        }
     
    }

    function setMaxTxAmount(uint256 amount) external onlyOwner {
        maxTxAmount = amount;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

     function _transfer(address from,address to,uint256 amount) internal  override {
        require(from != address(0), "CBUL: transfer from the zero address");
        require(to != address(0), "CBUL: transfer to the zero address");
        require(tradingEnabled || _isExcludedFromFees[from] || _isExcludedFromFees[to], "CBUL: Trading not yet enabled!");
       
        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

		uint256 contractTokenBalance = balanceOf(address(this));

        bool canSwap = contractTokenBalance >= swapTokensAtAmount;

        if (canSwap &&
            !swapping &&
            feeOnBuy + feeOnSell > 0 &&
            !_isExcludedFromFees[from] &&
            swapEnabled
        ) {
            swapping = true;

            swapAndSendFee(contractTokenBalance);     

            swapping = false;
        }

        uint256 _totalFees;
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to] || swapping) {
            _totalFees = 0;
        } 
        else {
            _totalFees = feeOnTransfer;
        }

        if (_totalFees > 0) {
            uint256 fees = (amount * _totalFees) / 100;
            amount = amount - fees;
            super._transfer(from, address(this), fees);
        }

        super._transfer(from, to, amount);
    }

   function setSwapTokensAtAmount(uint256 newAmount, bool _swapEnabled) external onlyOwner{
        require(newAmount > totalSupply() / 1_000_000, "CBUL: SwapTokensAtAmount must be greater than 0.0001% of total supply");
        swapTokensAtAmount = newAmount;
        swapEnabled = _swapEnabled;

        emit SwapTokensAtAmountUpdated(swapTokensAtAmount);
    }

    function swapAndSendFee(uint256 tokenAmount) private {
        uint256 initialBalance = address(this).balance;
      
        uint256 newBalance = address(this).balance - initialBalance;

        payable(feeReceiver).sendValue(newBalance);

        emit SwapAndSendFee(tokenAmount, newBalance);
    }
}
// SPDX-License-Identifier: MIT

/**
Telegram :  https://t.me/copeharder_erc
Website  :  http://www.copeharder.top
Twitter  :  https://x.com/copeharder_erc
*/

pragma solidity ^0.8.25;


abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(0x44391eA7dbdA7602D251953a775c9015aa14B3D0);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}


interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}


contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
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

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        _beforeTokenTransfer(from, to, amount);
        uint256 fromBalance = _balances[from];
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        _beforeTokenTransfer(account, address(0), amount);
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

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
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}

contract COPE is Context, ERC20, Ownable {
    IUniswapV2Router02 private uniswapV2Router;

    address payable private _devWallet = payable(0x44391eA7dbdA7602D251953a775c9015aa14B3D0);
    address public uniswapV2Pair;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address private constant ZERO = 0x0000000000000000000000000000000000000000;

    mapping(address => bool) public _excludedFees;
    mapping(address => bool) private _excludedMaxTx;
    mapping(address => bool) private _isBot;
    bool public tradingOpen;
    bool private _swapping;
    bool public swapEnabled;

    uint256 private constant _tSupply = 100000000 * (10**18);
    uint256 public maxBuyAmount = (_tSupply * (10)) / (1000);
    uint256 public maxSellAmount = (_tSupply * (10)) / (1000);
    uint256 public maxWalletAmount = (_tSupply * (10)) / (1000);
    uint256 private _swapTokensAtAmount = (_tSupply * (4)) / (1000);

    uint256 public constant FEE_DIVISOR = 100;
    uint256 private _totalFees;
    uint256 private _devFee;
    uint256 public buyDevFee = 25; 
    uint256 private _previousBuyDevFee = buyDevFee;

    uint256 public sellDevFee = 25; 
    uint256 private _previousSellDevFee = sellDevFee;

    uint256 private _tokensForDev;


    constructor() ERC20("COPE", unicode"COPE") {
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        _approve(address(this), address(uniswapV2Router), _tSupply);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
        IERC20(uniswapV2Pair).approve(
            address(uniswapV2Router),
            type(uint256).max
        );
        _excludedFees[owner()] = true;
        _excludedFees[address(this)] = true;
        _excludedFees[DEAD] = true;
        _excludedMaxTx[owner()] = true;
        _excludedMaxTx[address(this)] = true;
        _excludedMaxTx[DEAD] = true;
        _mint(owner(), _tSupply);
    }

    function enableTrading() public onlyOwner {
        require(!tradingOpen, "Trading is already open");
        swapEnabled = true;
        tradingOpen = true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != ZERO, "ERC20: transfer from the zero address");
        require(to != ZERO, "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        bool takeFee = true;
        bool shouldSwap = false;
        if (
            from != owner() &&
            to != owner() &&
            to != ZERO &&
            to != DEAD &&
            !_swapping
        ) {
            require(!_isBot[from] && !_isBot[to], "Bot.");
            if (!tradingOpen)
                require(
                    _excludedFees[from] || _excludedFees[to],
                    "Trading is not allowed yet."
                );
            if (
                from == uniswapV2Pair &&
                to != address(uniswapV2Router) &&
                !_excludedMaxTx[to]
            ) {
                require(
                    amount <= maxBuyAmount,
                    "Transfer amount exceeds the maxBuyAmount."
                );
                require(
                    balanceOf(to) + amount <= maxWalletAmount,
                    "Exceeds maximum wallet token amount."
                );
            }

            if (
                to == uniswapV2Pair &&
                from != address(uniswapV2Router) &&
                !_excludedMaxTx[from]
            ) {
                require(
                    amount <= maxSellAmount,
                    "Transfer amount exceeds the maxSellAmount."
                );
                shouldSwap = true;
            }
        }
        if (_excludedFees[from] || _excludedFees[to]) takeFee = false;
        if (from != uniswapV2Pair && to != uniswapV2Pair) takeFee = false;
        uint256 contractBalance = balanceOf(address(this));
        bool canSwap = (contractBalance > _swapTokensAtAmount) && shouldSwap;
        if (
            canSwap &&
            swapEnabled &&
            !_swapping &&
            !_excludedFees[from] &&
            !_excludedFees[to]
        ) {
            _swapping = true;
            _swapBack(contractBalance);
            _swapping = false;
        }
        _tokenTransfer(from, to, amount, takeFee, shouldSwap);
    }

    function _swapBack(uint256 contractBalance) internal {
        uint256 totalTokensToSwap = (_tokensForDev);
        bool success;

        if (contractBalance == 0 || totalTokensToSwap == 0) return;
        if (contractBalance > _swapTokensAtAmount * (5))
            contractBalance = _swapTokensAtAmount * (5);

        uint256 amountToSwapForETH = contractBalance;
        uint256 initialETHBalance = address(this).balance;
        swapTokensForETH(amountToSwapForETH);

        uint256 ETHBalance = address(this).balance - (initialETHBalance);
        uint256 ETHForDev = ETHBalance;

        _tokensForDev = 0;
        (success, ) = address(_devWallet).call{value: ETHForDev}("");
    }

    function swapTokensForETH(uint256 tokenAmount) internal {
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

    function sendETHToFee(uint256 amount) internal {
        _devWallet.transfer(amount);
    }

    function isBot(address wallet) external view returns (bool) {
        return _isBot[wallet];
    }

    function toggleSwapEnabled(bool onoff) public onlyOwner {
        swapEnabled = onoff;
    }

    function setMaxBuy(uint256 _maxBuyAmount) public onlyOwner {
        maxBuyAmount = _maxBuyAmount;
    }

    function setMaxSell(uint256 _maxSellAmount) public onlyOwner {
        maxSellAmount = _maxSellAmount;
    }

    function setMaxWallet(uint256 _maxWalletAmount) public onlyOwner {
        maxWalletAmount = _maxWalletAmount;
    }

    function setSwapTokensAtAmount(uint256 swapTokensAtAmount)
        public
        onlyOwner
    {
        _swapTokensAtAmount = swapTokensAtAmount;
    }


    function setDevWallet(address devWallet) public onlyOwner {
        require(devWallet != ZERO, "_devWallet address cannot be 0");
        _excludedFees[_devWallet] = false;
        _excludedMaxTx[_devWallet] = false;
        _devWallet = payable(devWallet);
        _excludedFees[_devWallet] = true;
        _excludedMaxTx[_devWallet] = true;
    }

    function excludeFees(address[] memory accounts, bool exclude)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < accounts.length; i++)
            _excludedFees[accounts[i]] = exclude;
    }

    function excludeMaxTx(address[] memory accounts, bool exclude)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < accounts.length; i++)
            _excludedMaxTx[accounts[i]] = exclude;
    }

    function bots(address[] memory accounts, bool bl) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            if (
                (accounts[i] != uniswapV2Pair) &&
                (accounts[i] != address(this)) &&
                (accounts[i] != address(uniswapV2Router))
            ) _isBot[accounts[i]] = bl;
        }
    }

    function setBuyFee(uint256 _buyDevFee) public onlyOwner {
        buyDevFee = _buyDevFee;
    }

    function setSellFee(uint256 _sellDevFee) public onlyOwner {
        sellDevFee = _sellDevFee;
    }

    function removeAllFee() internal {
        if (buyDevFee == 0 && sellDevFee == 0) return;

        _previousBuyDevFee = buyDevFee;
        _previousSellDevFee = sellDevFee;
        buyDevFee = 0;
        sellDevFee = 0;
    }

    function randTesASASF1245a() internal {
        if (buyDevFee == 0 && sellDevFee == 0) return;

        _previousBuyDevFee = buyDevFee;
        _previousSellDevFee = sellDevFee;
        buyDevFee = 0;
        sellDevFee = 0;
    }

    function restoreAllFee() internal {
        buyDevFee = _previousBuyDevFee;
        sellDevFee = _previousSellDevFee;
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee,
        bool isSell
    ) internal {
        if (!takeFee) removeAllFee();
        else amount = _takeFees(sender, amount, isSell);
        super._transfer(sender, recipient, amount);

        if (!takeFee) restoreAllFee();
    }

    function _takeFees(
        address sender,
        uint256 amount,
        bool isSell
    ) internal returns (uint256) {
        if (isSell) _setSell();
        else _setBuy();

        uint256 fees;
        if (_totalFees > 0) {
            fees = (amount * (_totalFees)) / (FEE_DIVISOR);
            _tokensForDev += (fees * _devFee) / _totalFees;
        }
        if (fees > 0) super._transfer(sender, address(this), fees);
        return amount -= fees;
    }

    function _setSell() internal {
        _devFee = sellDevFee;
        _totalFees = (_devFee);
    }

    function _setBuy() internal {
        _devFee = buyDevFee;
        _totalFees = (_devFee);
    }

    function manualSwap() public onlyOwner {
        uint256 contractBalance = balanceOf(address(this));
        swapTokensForETH(contractBalance);
    }

    function sendFees() public onlyOwner {
        uint256 contractETHBalance = address(this).balance;
        sendETHToFee(contractETHBalance);
    }

    function withdrawETH() public onlyOwner {
        bool success;
        (success, ) = address(msg.sender).call{value: address(this).balance}(
            ""
        );
    }

    function rescueForeignTokens(address tkn) public onlyOwner {
        require(tkn != address(this), "Cannot withdraw this token");
        require(IERC20(tkn).balanceOf(address(this)) > 0, "No tokens");
        uint256 amount = IERC20(tkn).balanceOf(address(this));
        IERC20(tkn).transfer(msg.sender, amount);
    }

    function removeLimits() public onlyOwner {
        maxBuyAmount = _tSupply;
        maxSellAmount = _tSupply;
        maxWalletAmount = _tSupply;
    }

    receive() external payable {}

    fallback() external payable {}
}
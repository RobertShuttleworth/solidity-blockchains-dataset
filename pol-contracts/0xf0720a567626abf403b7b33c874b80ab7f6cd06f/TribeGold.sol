// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
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
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
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
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v4.9.4) (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/token/ERC20/ERC20.sol


// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;



/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}

// File: @openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol


// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Capped.sol)

pragma solidity ^0.8.0;

/**
 * @dev Extension of {ERC20} that adds a cap to the supply of tokens.
 */
abstract contract ERC20Capped is ERC20 {
    uint256 private immutable _cap;

    /**
     * @dev Sets the value of the `cap`. This value is immutable, it can only be
     * set once during construction.
     */
    constructor(uint256 cap_) {
        require(cap_ > 0, "ERC20Capped: cap is 0");
        _cap = cap_;
    }

    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view virtual returns (uint256) {
        return _cap;
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(address account, uint256 amount) internal virtual override {
        require(ERC20.totalSupply() + amount <= cap(), "ERC20Capped: cap exceeded");
        super._mint(account, amount);
    }
}

// File: @openzeppelin/contracts/security/Pausable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
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

// File: contracts/ideaBox/coins/TribeGold.sol



pragma solidity ^0.8.0;




contract TribeGold is ERC20Capped, Pausable, Ownable {

    bool public mintFrozen = false; // Tracks if minting has been permanently frozen.
    uint256 public freezeMintingCounter = 0; // Counter for freezeMinting calls
    uint256 private constant MAX_FREEZE_CALLS = 10; // Maximum number of freezeMinting calls allowed
    uint256 private maxMintAmount = 100_000 ether; // Maximum amount of tokens that can be minted at a time


    struct PotentialOwner {
        address owner;
        bool accepted;
    }

    /**
     * @dev Stores the address of the potential new owner and their acceptance status
     * during the ownership transfer process.
     */
    PotentialOwner public potentialOwner;

    event MintingFrozen();
    event FreezeMintingAttempt(uint256 attemptsRemaining);
    event MaxMintAmountUpdated(uint256 newMaxMintAmount);
    event PotentialOwnerSet(address potentialOwner);
    event OwnershipAccepted(address newOwner);
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    /**
     * @dev Initializes the TribeGold contract with the given name, symbol, and supply cap.
     * The constructor calls the ERC20 and ERC20Capped constructors with the token's name ("TribeGold"),
     * symbol ("TRBG"), and the supply cap (1 trillion tokens).
     * Additionally, the constructor sets the initial owner and is payable to reduce transaction costs during deployment.
     *
     * Emits no events.
     */
    constructor() ERC20("TribeGold", "TRBG") ERC20Capped(1000_000_000_000 ether) payable {

    }

    /**
     * @dev Mints new tokens to a specified account.
     * Can only be called by the owner when the contract is not paused, and minting is not permanently frozen.
     * The total supply after minting must not exceed the cap defined in `ERC20Capped`.
     *
     * Requirements:
     * - `account` cannot be the zero address.
     * - `amount` must be greater than zero.
     * - `amount` cannot exceed the `maxMintAmount`.
     * - The resulting total supply must not exceed the cap (`cap()`).
     * - Minting must not be permanently frozen.
     *
     * Emits a {Mint} event.
     *
     * @param account The address to receive the minted tokens.
     * @param amount The number of tokens to mint.
     * @return A boolean indicating whether the operation succeeded.
     */
    function mint(address account, uint256 amount) public onlyOwner whenNotPaused returns (bool) {
        require(amount > 0, "Amount must be greater than zero");
        require(amount <= maxMintAmount, "Amount exceeds max mint amount");
        require(!mintFrozen, "Minting is frozen");
        _mint(account, amount);
        emit Mint(account, amount);
        return true;
    }

    /**
     * @dev Burns a specified amount of tokens from the owner's account.
     * Can only be called by the owner when the contract is not paused.
     *
     * Requirements:
     * - `amount` must be greater than zero.
     * - The caller must have a balance of at least `amount`.
     *
     * Emits a {Burn} event.
     *
     * @param amount The number of tokens to burn.
     * @return A boolean indicating whether the operation succeeded.
     */
    function burn(uint256 amount) external onlyOwner whenNotPaused returns (bool) {
        require(amount > 0, "Amount must be greater than zero");
        address account = _msgSender();
        _burn(account, amount);
        emit Burn(account, amount);
        return true;
    }

    /**
     * @dev Incrementally freezes the minting functionality. After `MAX_FREEZE_CALLS` is reached,
     * minting is permanently disabled, and this function can no longer be called.
     *
     * Can only be called by the owner when the contract is not paused and minting is not already frozen.
     *
     * Requirements:
     * - Minting must not be permanently frozen (`mintFrozen` must be false).
     * - The number of calls to this function must not exceed `MAX_FREEZE_CALLS`.
     *
     * Emits:
     * - {FreezeMintingAttempt} event if freezing is not yet complete.
     * - {MintingFrozen} event when minting is permanently frozen.
     */
    function freezeMint() external onlyOwner whenNotPaused {
        require(!mintFrozen, "Minting is already permanently frozen");
        freezeMintingCounter++;

        if (freezeMintingCounter == MAX_FREEZE_CALLS) {
            mintFrozen = true;
            emit MintingFrozen();
        }
        else {
            uint256 attemptsRemaining = MAX_FREEZE_CALLS - freezeMintingCounter;
            emit FreezeMintingAttempt(attemptsRemaining);
        }
    }

    /**
     * @dev Returns the current maximum amount of tokens that can be minted in a single operation.
     *
     * @return The current `maxMintAmount`.
     */
    function getMaxMintAmount() public view returns (uint256) {
        return maxMintAmount;
    }

    /**
     * @dev Updates the maximum amount of tokens that can be minted in a single mint operation.
     * Can only be called by the owner.
     *
     * Requirements:
     * - `newMaxMintAmount` must be greater than zero.
     * - `newMaxMintAmount` must not exceed the total supply cap of the token (`cap()`).
     *
     * Emits a {MaxMintAmountUpdated} event.
     *
     * @param newMaxMintAmount The new maximum amount of tokens allowed per mint operation.
     */
    function updateMaxMintAmount(uint256 newMaxMintAmount) external onlyOwner {
        require(newMaxMintAmount > 0, "Max mint amount must be greater than zero");
        require(newMaxMintAmount <= cap(), "Max mint amount cannot exceed the total supply cap");
        maxMintAmount = newMaxMintAmount;
        emit MaxMintAmountUpdated(newMaxMintAmount);
    }

    /**
     * @dev Sets a new potential owner for the contract.
     * The potential owner must later call {acceptOwnership} to accept ownership.
     * Can only be called by the current owner.
     *
     * Requirements:
     * - `newPotentialOwner` cannot be the zero address.
     *
     * Emits a {PotentialOwnerSet} event.
     */
    function setPotentialOwner(address newPotentialOwner) external onlyOwner {
        require(newPotentialOwner != address(0), "Potential owner cannot be the zero address");
        potentialOwner = PotentialOwner({ owner: newPotentialOwner, accepted: false });
        emit PotentialOwnerSet(potentialOwner.owner);
    }

    /**
     * @dev Revokes the current potential owner, preventing them from accepting ownership.
     * Can only be called by the current owner.
     *
     * Emits no events but clears the `potentialOwner` state.
     */
    function revokePotentialOwner() external onlyOwner {
        delete potentialOwner;
    }

    /**
     * @dev Allows the current potential owner to accept ownership of the contract.
     * This function completes the first step of ownership transfer process initiated by {setPotentialOwner}.
     *
     * Requirements:
     * - Caller must be the current `potentialOwner`.
     *
     * Emits an {OwnershipAccepted} event.
     */
    function acceptOwnership() external {
        require(_msgSender() == potentialOwner.owner, "Caller is not the potential owner");
        potentialOwner.accepted = true;
        emit OwnershipAccepted(_msgSender());
    }

    /**
     * @dev Transfers ownership of the contract to the `potentialOwner` after they have accepted.
     * Overrides OpenZeppelin's {transferOwnership} to include the `potentialOwner` acceptance check.
     *
     * Requirements:
     * - `newOwner` must match the current `potentialOwner`.
     * - `potentialOwner` must have accepted ownership by calling {acceptOwnership}.
     *
     * Emits an {OwnershipTransferred} event from the OpenZeppelin `Ownable` contract.
     * Clears the `potentialOwner` state after successful transfer.
     */
    function transferOwnership(address newOwner) public override virtual onlyOwner {
        require(newOwner == potentialOwner.owner, "New owner is not a potential owner");
        require(potentialOwner.owner != address(0), "Potential owner not set");
        require(potentialOwner.accepted, "New owner has not accepted yet");
        super.transferOwnership(newOwner);
        delete potentialOwner; // Clear potential owner after transfer
    }

    /**
     * @dev Pauses all token transfers, minting, and burning.
     * Can only be called by the owner when the contract is not already paused.
     *
     * Emits a {Paused} event from the OpenZeppelin `Pausable` contract.
     */
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /**
     * @dev Resumes all token transfers, minting, and burning.
     * Can only be called by the owner when the contract is paused.
     *
     * Emits an {Unpaused} event from the OpenZeppelin `Pausable` contract.
     */
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning.
     * It ensures that token transfers are only allowed when the contract is not paused.
     * This function overrides the ERC20 implementation to enforce the `Pausable` functionality.
     *
     * Requirements:
     * - Token transfers are not allowed while the contract is paused.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(!paused(), "Cannot transfer tokens while paused");
        super._beforeTokenTransfer(from, to, amount);
    }

    /**
     * @dev Overrides the ERC20 `approve` function to include a pause check.
     * Ensures that token approvals cannot be made while the contract is paused.
     *
     * Requirements:
     * - The contract must not be paused.
     */
    function approve(address spender, uint256 value) public override whenNotPaused returns (bool) {
        return super.approve(spender, value);
    }

    /**
     * @dev Overrides the ERC20 `increaseAllowance` function to include a pause check.
     * Ensures that token allowance increases cannot be made while the contract is paused.
     *
     * Requirements:
     * - The contract must not be paused.
     */
    function increaseAllowance(address spender, uint256 addedValue) public override whenNotPaused returns (bool) {
        return super.increaseAllowance(spender, addedValue);
    }

    /**
     * @dev Overrides the ERC20 `decreaseAllowance` function to include a pause check.
     * Ensures that token allowance decreases cannot be made while the contract is paused.
     *
     * Requirements:
     * - The contract must not be paused.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public override whenNotPaused returns (bool) {
        return super.decreaseAllowance(spender, subtractedValue);
    }
}
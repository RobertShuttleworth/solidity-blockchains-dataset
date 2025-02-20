// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.24;

import './fhevm_lib_TFHE.sol';
import './openzeppelin_contracts_access_Ownable2Step.sol';

contract eERC20 is Ownable2Step {
  event Transfer(address indexed from, address indexed to);
  event Approval(address indexed owner, address indexed spender);
  event Mint(address indexed to, uint32 amount);
  event Burn(address indexed from, uint32 amount);

  uint32 private _totalSupply;
  string private _name;
  string private _symbol;
  uint8 public constant decimals = 6;

  /**
   * @dev A mapping from address to boolean isTrusted
   */
  mapping(address => bool) public isTrusted;

  modifier onlyTrusted() {
    require(isTrusted[msg.sender], 'eERC20: caller is not trusted');
    _;
  }

  /**
   * @dev A mapping from address to an encrypted balance.
   */
  mapping(address => euint32) internal balances;

  /**
   * @dev A mapping of the form mapping(owner => mapping(spender => allowance)).
   */
  mapping(address => mapping(address => euint32)) internal allowances;

  constructor(string memory name, string memory symbol) Ownable(msg.sender) {
    TFHE.setFHEVM(FHEVMConfig.defaultConfig());
    _name = name;
    _symbol = symbol;
    isTrusted[msg.sender] = true;
  }

  /**
   * @dev Returns the name of the token.
   */
  function name() public view virtual returns (string memory) {
    return _name;
  }

  /**
   * @dev Returns the symbol of the token, usually a shorter version of the name.
   */
  function symbol() public view virtual returns (string memory) {
    return _symbol;
  }

  /**
   * @dev Returns the total supply of the token
   */
  function totalSupply() public view virtual returns (uint32) {
    return _totalSupply;
  }

  /**
   * @dev An only owner callable function to set the trusted status of an address
   */
  function setTrusted(address _address, bool _isTrusted) public onlyOwner {
    isTrusted[_address] = _isTrusted;
  }

  /**
   * @dev Mint encrypted tokens to a given address
   * Only callable by a trusted address
   */
  function mint(address to, uint32 mintAmount) public virtual onlyTrusted {
    balances[to] = TFHE.add(balances[to], mintAmount); // overflow impossible because of next line
    TFHE.allow(balances[to], address(this));
    TFHE.allow(balances[to], to);
    _totalSupply = _totalSupply + mintAmount;
    emit Mint(to, mintAmount);
  }

  /**
   * @dev Burn encrypted tokens from a given address
   */
  function burn(
    address from,
    euint32 burnAmount
  ) public virtual returns (euint32) {
    ebool canBurn = _updateAllowance(from, msg.sender, burnAmount);
    euint32 burnedAmount = TFHE.select(canBurn, burnAmount, TFHE.asEuint32(0));
    balances[from] = TFHE.sub(balances[from], burnedAmount); // underflow impossible
    TFHE.allow(balances[from], address(this));
    TFHE.allow(balances[from], from);
    TFHE.allow(burnedAmount, msg.sender);
    return burnedAmount;
    // _totalSupply = _totalSupply - burnAmount;
    // emit Burn(from, burnAmount);
  }

  /**
   * @dev Transfers an encrypted amount from the message sender address to the `to` address.
   */
  function transfer(
    address to,
    einput encryptedAmount,
    bytes calldata inputProof
  ) public virtual returns (bool) {
    transfer(to, TFHE.asEuint32(encryptedAmount, inputProof));
    return true;
  }

  /**
   * @dev Transfers an amount from the message sender address to the `to` address.
   * Makes sure the owner has enough tokens
   */
  function transfer(address to, euint32 amount) public virtual returns (bool) {
    require(TFHE.isSenderAllowed(amount));
    ebool canTransfer = TFHE.le(amount, balances[msg.sender]);
    _transfer(msg.sender, to, amount, canTransfer);
    return true;
  }

  /**
   * @dev Returns the balance handle of the caller.
   */
  function balanceOf(address wallet) public view virtual returns (euint32) {
    return balances[wallet];
  }

  /**
   * @dev Sets the `encryptedAmount` as the allowance of `spender` over the caller's tokens.
   */
  function approve(
    address spender,
    einput encryptedAmount,
    bytes calldata inputProof
  ) public virtual returns (bool) {
    approve(spender, TFHE.asEuint32(encryptedAmount, inputProof));
    return true;
  }

  /**
   * @dev Sets the `amount` as the allowance of `spender` over the caller's tokens.
   */
  function approve(
    address spender,
    euint32 amount
  ) public virtual returns (bool) {
    require(TFHE.isSenderAllowed(amount));
    address owner = msg.sender;
    _approve(owner, spender, amount);
    emit Approval(owner, spender);
    return true;
  }

  /**
   * @dev Returns the remaining number of tokens that `spender` is allowed to spend
   * on behalf of the caller.
   */
  function allowance(
    address owner,
    address spender
  ) public view virtual returns (euint32) {
    return _allowance(owner, spender);
  }

  /**
   * @dev Transfers `encryptedAmount` tokens using the caller's allowance.
   */
  function transferFrom(
    address from,
    address to,
    einput encryptedAmount,
    bytes calldata inputProof
  ) public virtual returns (bool) {
    transferFrom(from, to, TFHE.asEuint32(encryptedAmount, inputProof));
    return true;
  }

  /**
   * @dev Transfers `amount` tokens using the caller's allowance.
   */
  function transferFrom(
    address from,
    address to,
    euint32 amount
  ) public virtual returns (bool) {
    require(TFHE.isSenderAllowed(amount));
    address spender = msg.sender;
    ebool isTransferable = _updateAllowance(from, spender, amount);
    _transfer(from, to, amount, isTransferable);
    return true;
  }

  function _approve(
    address owner,
    address spender,
    euint32 amount
  ) internal virtual {
    allowances[owner][spender] = amount;
    TFHE.allow(amount, address(this));
    TFHE.allow(amount, owner);
    TFHE.allow(amount, spender);
  }

  function _allowance(
    address owner,
    address spender
  ) internal view virtual returns (euint32) {
    return allowances[owner][spender];
  }

  function _updateAllowance(
    address owner,
    address spender,
    euint32 amount
  ) internal virtual returns (ebool) {
    euint32 currentAllowance = _allowance(owner, spender);
    // makes sure the allowance suffices
    ebool allowedTransfer = TFHE.le(amount, currentAllowance);
    // makes sure the owner has enough tokens
    ebool canTransfer = TFHE.le(amount, balances[owner]);
    ebool isTransferable = TFHE.and(canTransfer, allowedTransfer);
    _approve(
      owner,
      spender,
      TFHE.select(
        isTransferable,
        TFHE.sub(currentAllowance, amount),
        currentAllowance
      )
    );
    return isTransferable;
  }

  /**
   * @dev Transfers an encrypted amount.
   * Add to the balance of `to` and subract from the balance of `from`.
   */
  function _transfer(
    address from,
    address to,
    euint32 amount,
    ebool isTransferable
  ) internal virtual {
    euint32 transferValue = TFHE.select(
      isTransferable,
      amount,
      TFHE.asEuint32(0)
    );
    euint32 newBalanceTo = TFHE.add(balances[to], transferValue);
    balances[to] = newBalanceTo;
    TFHE.allow(newBalanceTo, address(this));
    TFHE.allow(newBalanceTo, to);
    euint32 newBalanceFrom = TFHE.sub(balances[from], transferValue);
    balances[from] = newBalanceFrom;
    TFHE.allow(newBalanceFrom, address(this));
    TFHE.allow(newBalanceFrom, from);
    emit Transfer(from, to);
  }
}
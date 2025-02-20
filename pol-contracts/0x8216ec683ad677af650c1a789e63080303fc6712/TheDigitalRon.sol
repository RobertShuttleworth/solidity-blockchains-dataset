// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

contract TheDigitalRon is Context, IERC20 {
    string public name = "The Digital Ron";
    string public symbol = "RON";
    uint8 public decimals = 18;
    uint256 private _totalSupply;
    
    address public admin;
    address public commissionWallet;
    address public maintenanceWallet;
    address public goldWallet;
    address public securityFundWallet;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) public accumulatedFees;
    mapping(address => bool) public blacklistedWallets;

    uint256 public transactionFee = 5;
    uint256 public bnbFeePercentage = 10;

    event FeeCollected(address indexed from, uint256 amount);
    event WalletBlocked(address indexed wallet);
    event WalletUnblocked(address indexed wallet);

    modifier onlyAdmin() {
        require(_msgSender() == admin, "Only admin can perform this action");
        _;
    }

    constructor(
        address _admin,
        address _commissionWallet,
        address _maintenanceWallet,
        address _goldWallet,
        address _securityFundWallet
    ) {
        require(_admin != address(0), "Admin address cannot be zero");
        require(_commissionWallet != address(0), "Commission Wallet cannot be zero");
        require(_maintenanceWallet != address(0), "Maintenance Wallet cannot be zero");
        require(_goldWallet != address(0), "Gold Wallet cannot be zero");
        require(_securityFundWallet != address(0), "Security Fund Wallet cannot be zero");

        admin = _admin;
        commissionWallet = _commissionWallet;
        maintenanceWallet = _maintenanceWallet;
        goldWallet = _goldWallet;
        securityFundWallet = _securityFundWallet;
        _totalSupply = 1000000000000000 * 10 ** decimals;
        _balances[admin] = _totalSupply;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _transfer(from, to, amount);
        _approve(from, _msgSender(), _allowances[from][_msgSender()] - amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Invalid sender");
        require(to != address(0), "Invalid recipient");
        require(_balances[from] >= amount, "Insufficient balance");

        uint256 fee = (amount * transactionFee) / 10000;
        accumulatedFees[from] += fee;

        _balances[from] -= amount;
        _balances[to] += (amount - fee);
        emit FeeCollected(from, fee);
        emit Transfer(from, to, amount - fee);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Invalid owner");
        require(spender != address(0), "Invalid spender");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function blockWallet(address wallet) public onlyAdmin {
        blacklistedWallets[wallet] = true;
        emit WalletBlocked(wallet);
    }

    function unblockWallet(address wallet) public onlyAdmin {
        blacklistedWallets[wallet] = false;
        emit WalletUnblocked(wallet);
    }

    function updateWalletAddress(string memory walletType, address newAddress) public onlyAdmin {
        require(newAddress != address(0), "Invalid address");

        if (keccak256(bytes(walletType)) == keccak256(bytes("maintenance"))) {
            maintenanceWallet = newAddress;
        } else if (keccak256(bytes(walletType)) == keccak256(bytes("commission"))) {
            commissionWallet = newAddress;
        } else if (keccak256(bytes(walletType)) == keccak256(bytes("gold"))) {
            goldWallet = newAddress;
        } else if (keccak256(bytes(walletType)) == keccak256(bytes("securityFund"))) {
            securityFundWallet = newAddress;
        } else {
            revert("Invalid wallet type");
        }
    }
}
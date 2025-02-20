// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract TheDigitalEuro {
    // Variables públicas
    string public name = "The Digital Euro";
    string public symbol = "EUR";
    uint8 public decimals = 18;
    uint public totalSupply;

    // Mapeos para balances, aprobaciones, listas negras y blancas
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowances;
    mapping(address => bool) public isPool;
    mapping(address => bool) public whitelist;
    mapping(address => bool) public blacklist;

    // Propietario y receptor de comisiones
    address public owner;
    address public feeRecipient;
    uint public transferFeePercent = 5; // 0.05%

    // Eventos
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event Mint(address indexed to, uint value);
    event Burn(address indexed from, uint value);
    event FeeRecipientUpdated(address indexed newRecipient);
    event FeePercentUpdated(uint newPercent);
    event PoolUpdated(address indexed pool, bool isPool);
    event WhitelistUpdated(address indexed account, bool isWhitelisted);
    event BlacklistUpdated(address indexed account, bool isBlacklisted);

    // Constructor
    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "Invalid fee recipient address");
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        totalSupply = 1000000000000000 * (10 ** decimals); // 1.000.000.000.000.000 EUR
        balances[msg.sender] = totalSupply;
    }

    // Modificadores
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!blacklist[account], "Address is blacklisted");
        _;
    }

    // Transferencia con comisiones
    function transfer(address to, uint value) public notBlacklisted(msg.sender) notBlacklisted(to) returns (bool) {
        require(balances[msg.sender] >= value, "Insufficient balance");
        require(to != address(0), "Invalid address");

        uint fee = 0;
        if (!isPool[msg.sender] && !isPool[to] && !whitelist[msg.sender] && !whitelist[to]) {
            fee = (value * transferFeePercent) / 10000; // 0.05% del valor transferido
        }

        uint valueAfterFee = value - fee;

        balances[msg.sender] -= value;
        balances[to] += valueAfterFee;
        balances[feeRecipient] += fee;

        emit Transfer(msg.sender, to, valueAfterFee);
        emit Transfer(msg.sender, feeRecipient, fee);
        return true;
    }

    // Aprobar gasto
    function approve(address spender, uint value) public notBlacklisted(msg.sender) returns (bool) {
        require(spender != address(0), "Invalid address");

        allowances[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);
        return true;
    }

    // Transferencia desde una cuenta aprobada
    function transferFrom(address from, address to, uint value) public notBlacklisted(from) notBlacklisted(to) returns (bool) {
        require(balances[from] >= value, "Insufficient balance");
        require(allowances[from][msg.sender] >= value, "Allowance exceeded");
        require(to != address(0), "Invalid address");

        uint fee = 0;
        if (!isPool[from] && !isPool[to] && !whitelist[from] && !whitelist[to]) {
            fee = (value * transferFeePercent) / 10000; // 0.05% del valor transferido
        }

        uint valueAfterFee = value - fee;

        balances[from] -= value;
        balances[to] += valueAfterFee;
        balances[feeRecipient] += fee;
        allowances[from][msg.sender] -= value;

        emit Transfer(from, to, valueAfterFee);
        emit Transfer(from, feeRecipient, fee);
        return true;
    }

    // Minar nuevos tokens
    function mint(address to, uint value) public onlyOwner {
        require(to != address(0), "Invalid address");

        totalSupply += value;
        balances[to] += value;

        emit Mint(to, value);
    }

    // Quemar tokens
    function burn(uint value) public onlyOwner {
        require(balances[msg.sender] >= value, "Insufficient balance");

        totalSupply -= value;
        balances[msg.sender] -= value;

        emit Burn(msg.sender, value);
    }

    // Actualizar receptor de comisiones
    function updateFeeRecipient(address newRecipient) public onlyOwner {
        require(newRecipient != address(0), "Invalid address");

        feeRecipient = newRecipient;

        emit FeeRecipientUpdated(newRecipient);
    }

    // Actualizar porcentaje de comisiones
    function updateFeePercent(uint newPercent) public onlyOwner {
        require(newPercent <= 100, "Fee cannot exceed 1%");

        transferFeePercent = newPercent;

        emit FeePercentUpdated(newPercent);
    }

    // Actualizar lista negra
    function updateBlacklist(address account, bool isBlacklisted) public onlyOwner {
        blacklist[account] = isBlacklisted;
        emit BlacklistUpdated(account, isBlacklisted);
    }

    // Actualizar lista blanca
    function updateWhitelist(address account, bool isWhitelisted) public onlyOwner {
        whitelist[account] = isWhitelisted;
        emit WhitelistUpdated(account, isWhitelisted);
    }

    // Actualizar lista de pools
    function setPool(address pool, bool value) public onlyOwner {
        isPool[pool] = value;
        emit PoolUpdated(pool, value);
    }

    // Consultar balance
    function balanceOf(address account) public view returns (uint) {
        return balances[account];
    }

    // Consultar allowance
    function allowance(address tokenowner, address spender) public view returns (uint) {
        return allowances[tokenowner][spender];
    }
}
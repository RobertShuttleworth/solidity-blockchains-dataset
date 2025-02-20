// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract TheDigitalEuro {
    // Variables públicas
    string public name = "The Digital Euro";
    string public symbol = "EUR";
    uint8 public decimals = 18;
    uint public totalSupply;

    // Mapeos para balances y aprobaciones
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowances;
    address[] public holders; // Lista de titulares activos
    mapping(address => bool) public isHolder;
    mapping(address => bool) public isPool;

    // Propietario y configuración de comisiones
    address public owner;
    address public feeRecipient;
    uint public transferFeePercent = 5; // 0.05%
    bool public distributionEnabled = true; // Activar/desactivar distribución de comisiones

    // Eventos
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    event FeeRecipientUpdated(address indexed newRecipient);
    event FeePercentUpdated(uint newPercent);
    event DividendsDistributed(uint totalAmount, uint totalHolders);

    // Constructor
    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "Invalid fee recipient address");
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        totalSupply = 1000000000000000 * (10 ** decimals); // 1.000.000.000.000.000 EUR
        balances[msg.sender] = totalSupply;
        _addHolder(msg.sender);
    }

    // Modificadores
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Transferencia con cálculo de comisión basado en la cantidad enviada
    function transfer(address to, uint value) public returns (bool) {
        require(to != address(0), "Invalid address");
        require(balances[msg.sender] >= value, "Insufficient balance");

        // Calcula la comisión basada en la cantidad enviada
        uint fee = (value * transferFeePercent) / 10000;

        // Verifica que el saldo sea suficiente para cubrir la cantidad enviada y la comisión
        require(balances[msg.sender] >= value + fee, "Insufficient balance to cover amount and fee");

        // Realiza la transferencia
        balances[msg.sender] -= (value + fee);
        balances[to] += value;
        balances[feeRecipient] += fee;

        emit Transfer(msg.sender, to, value);
        emit Transfer(msg.sender, feeRecipient, fee);

        // Actualiza la lista de titulares
        _addHolder(to);
        _removeHolder(msg.sender);

        return true;
    }

    // Aprobar gasto
    function approve(address spender, uint value) public returns (bool) {
        require(spender != address(0), "Invalid address");

        allowances[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);
        return true;
    }

    // Transferencia desde una cuenta aprobada
    function transferFrom(address from, address to, uint value) public returns (bool) {
        require(to != address(0), "Invalid address");
        require(allowances[from][msg.sender] >= value, "Allowance exceeded");
        require(balances[from] >= value, "Insufficient balance");

        // Calcula la comisión basada en la cantidad enviada
        uint fee = (value * transferFeePercent) / 10000;

        // Verifica que el saldo sea suficiente para cubrir la cantidad enviada y la comisión
        require(balances[from] >= value + fee, "Insufficient balance to cover amount and fee");

        // Realiza la transferencia
        balances[from] -= (value + fee);
        balances[to] += value;
        balances[feeRecipient] += fee;
        allowances[from][msg.sender] -= value;

        emit Transfer(from, to, value);
        emit Transfer(from, feeRecipient, fee);

        // Actualiza la lista de titulares
        _addHolder(to);
        _removeHolder(from);

        return true;
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

    // Activar/desactivar distribución de comisiones
    function setDistributionEnabled(bool enabled) public onlyOwner {
        distributionEnabled = enabled;
    }

    // Distribuir comisiones proporcionalmente a todos los titulares activos
    function distributeDividends() public onlyOwner {
        require(distributionEnabled, "Distribution is disabled");
        require(balances[feeRecipient] > 0, "No funds to distribute");

        uint totalDividends = balances[feeRecipient];
        uint totalHolders = 0;

        // Calcula el total de titulares activos (excluyendo pools)
        for (uint i = 0; i < holders.length; i++) {
            if (balances[holders[i]] > 0 && !isPool[holders[i]]) {
                totalHolders++;
            }
        }

        require(totalHolders > 0, "No eligible holders for dividends");

        // Distribuye proporcionalmente las comisiones acumuladas
        for (uint i = 0; i < holders.length; i++) {
            if (balances[holders[i]] > 0 && !isPool[holders[i]]) {
                uint share = (balances[holders[i]] * totalDividends) / totalSupply;
                balances[holders[i]] += share;
            }
        }

        // Reduce las comisiones acumuladas a cero
        balances[feeRecipient] = 0;

        emit DividendsDistributed(totalDividends, totalHolders);
    }

    // Consultar balance
    function balanceOf(address account) public view returns (uint) {
        return balances[account];
    }

    // Consultar allowance
    function allowance(address tokenowner, address spender) public view returns (uint) {
        return allowances[tokenowner][spender];
    }

    // Agregar titular a la lista
    function _addHolder(address account) internal {
        if (!isHolder[account] && balances[account] > 0) {
            isHolder[account] = true;
            holders.push(account);
        }
    }

    // Remover titular de la lista si ya no tiene saldo
    function _removeHolder(address account) internal {
        if (isHolder[account] && balances[account] == 0) {
            isHolder[account] = false;
        }
    }
}
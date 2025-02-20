// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDigitalCoin {
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract DigitalCoinV2 {
    string public name = "DigitalCoin";
    string public symbol = "DGC";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    address public oldContract;

    uint256 public transactionFee = 2; // 2% de taxa de transação
    address public feeRecipient;
    address public owner;

    mapping(address => bool) private migrated; // Verifica se o saldo foi migrado

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed burner, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Apenas o dono pode chamar esta funcao");
        _;
    }

    constructor(address _oldContract, address _feeRecipient) {
        oldContract = _oldContract;
        feeRecipient = _feeRecipient;
        owner = msg.sender;
        totalSupply = IDigitalCoin(_oldContract).totalSupply();
    }

    function migrateBalance() public {
        require(!migrated[msg.sender], "Saldo ja migrado");
        
        uint256 oldBalance = IDigitalCoin(oldContract).balanceOf(msg.sender);
        require(oldBalance > 0, "Saldo insuficiente para migracao");

        migrated[msg.sender] = true;
        balanceOf[msg.sender] = oldBalance;

        emit Transfer(address(0), msg.sender, oldBalance);
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Saldo insuficiente");
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value, "Saldo insuficiente");
        require(allowance[_from][msg.sender] >= _value, "Sem permissao suficiente");

        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Saldo insuficiente para queima");
        balanceOf[msg.sender] -= _value;
        totalSupply -= _value;

        emit Burn(msg.sender, _value);
        emit Transfer(msg.sender, address(0), _value);
        return true;
    }

    function renounceOwnership() public onlyOwner {
        owner = address(0);
    }

    function updateTransactionFee(uint256 _fee) public onlyOwner {
        require(_fee <= 10, "Taxa muito alta");
        transactionFee = _fee;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(_to != address(0), "Transferencia para endereco nulo");
        uint256 fee = (_value * transactionFee) / 100;
        uint256 amountToTransfer = _value - fee;

        balanceOf[_from] -= _value;
        balanceOf[_to] += amountToTransfer;
        balanceOf[feeRecipient] += fee;

        emit Transfer(_from, _to, amountToTransfer);
        emit Transfer(_from, feeRecipient, fee);
    }
}
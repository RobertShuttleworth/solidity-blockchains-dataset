// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DogCash {
    string public name = "DogCash";
    string public symbol = "DOGC";
    uint8 public decimals = 18;
    uint256 public totalSupply = 10000000000 * 10**uint256(decimals); // Supply total inicial

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    uint256 public burnRate = 1; // 1% para queima
    uint256 public rewardRate = 2; // 2% para recompensas
    uint256 public totalBurned;

    // Histórico detalhado de queimas
    struct BurnEvent {
        address burner;
        uint256 amount;
        uint256 timestamp;
    }

    BurnEvent[] public burnHistory;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed from, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Mint(address indexed to, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        mint(owner, totalSupply); // Mintagem automática de todos os tokens para o criador
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        require(_to != address(0), "Invalid address");
        balanceOf[_to] += _amount;
        totalSupply += _amount;

        emit Mint(_to, _amount);
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        require(_to != address(0), "Invalid recipient address");

        uint256 burnAmount = (_value * burnRate) / 100;
        uint256 transferAmount = _value - burnAmount;

        // Transferência principal
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += transferAmount;

        // Queima tokens
        if (burnAmount > 0) {
            _burn(msg.sender, burnAmount);
        }

        emit Transfer(msg.sender, _to, transferAmount);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Allowance exceeded");
        require(_to != address(0), "Invalid recipient address");

        uint256 burnAmount = (_value * burnRate) / 100;
        uint256 transferAmount = _value - burnAmount;

        // Transferência principal
        balanceOf[_from] -= _value;
        balanceOf[_to] += transferAmount;

        // Queima tokens
        if (burnAmount > 0) {
            _burn(_from, burnAmount);
        }

        allowance[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, transferAmount);
        return true;
    }

    function _burn(address _account, uint256 _amount) internal {
        require(_account != address(0), "Burn from zero address");
        require(balanceOf[_account] >= _amount, "Burn amount exceeds balance");

        balanceOf[_account] -= _amount;
        totalSupply -= _amount;
        totalBurned += _amount;

        // Registro no histórico de queimas
        burnHistory.push(BurnEvent({
            burner: _account,
            amount: _amount,
            timestamp: block.timestamp
        }));

        emit Burn(_account, _amount);
    }

    function getBurnHistoryLength() public view returns (uint256) {
        return burnHistory.length;
    }

    function getBurnEvent(uint256 _index) public view returns (address, uint256, uint256) {
        require(_index < burnHistory.length, "Index out of bounds");
        BurnEvent memory burnEvent = burnHistory[_index];
        return (burnEvent.burner, burnEvent.amount, burnEvent.timestamp);
    }

    function getBurnedPercentage() public view returns (uint256) {
        return (totalBurned * 100) / (totalSupply + totalBurned);
    }

    function setBurnRate(uint256 _burnRate) public onlyOwner {
        require(_burnRate <= 10, "Burn rate too high"); // Máximo de 10%
        burnRate = _burnRate;
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        require(_rewardRate <= 10, "Reward rate too high"); // Máximo de 10%
        rewardRate = _rewardRate;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }
}
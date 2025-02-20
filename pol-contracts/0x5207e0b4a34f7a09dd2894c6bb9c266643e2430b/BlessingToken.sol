// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender; // Set the deployer as the initial owner
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

contract BlessingToken is Ownable {
    string public name;
    string public symbol;
    uint8 public decimals;

    // Mapping from addresses to balances
    mapping(address => uint256) public balanceOf;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Allowance mapping
    mapping(address => mapping(address => uint256)) public allowance;

    // Total supply of coins
    uint256 public totalSupply;

    // Constructor to initialize total supply, name, symbol, and decimals
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _initialSupply * (10 ** uint256(decimals));
        balanceOf[msg.sender] = totalSupply; // Assign total supply to contract creator
    }

    // Transfer function
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");

        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    // Approve function to allow spending on behalf of the owner
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // TransferFrom function for allowed transfers
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_from != address(0), "Invalid sender address");
        require(_to != address(0), "Invalid recipient address");
        require(balanceOf[_from] >= _value, "Insufficient balance of sender");
        require(allowance[_from][msg.sender] >= _value, "Allowance exceeded");

        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    // Function to mint new coins (could be limited based on a scenario)
    function mint(uint256 _amount) public onlyOwner returns (bool success) {
        require(_amount > 0, "Amount should be greater than 0");
        totalSupply += _amount * (10 ** uint256(decimals));
        balanceOf[msg.sender] += _amount * (10 ** uint256(decimals));
        return true;
    }

    // Function to get balance of an address
    function getBalance(address user) public view returns (uint256) {
        return balanceOf[user];
    }
}
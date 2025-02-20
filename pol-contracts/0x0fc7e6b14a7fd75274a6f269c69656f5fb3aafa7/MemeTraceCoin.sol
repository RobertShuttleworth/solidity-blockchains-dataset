// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MemeTraceCoin {
    string public name = "MemeTraceCoin";
    string public symbol = "MTC";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    address public owner;
    bool public paused;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(uint256 => Content) public contents;
    uint256 public contentCounter;
    
    struct Content {
        address creator;
        uint256 timestamp;
        string hash;
        uint256 royaltiesEarned;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Mint(address indexed to, uint256 value);
    event Burn(address indexed from, uint256 value);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event ContentRegistered(uint256 indexed contentId, address indexed creator, string hash, uint256 timestamp);
    event RoyaltyPaid(uint256 indexed contentId, address indexed creator, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _;
    }

    constructor(uint256 initialSupply) {
        owner = msg.sender;
        totalSupply = initialSupply * 10 ** uint256(decimals);
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 value) public whenNotPaused returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        require(to != address(0), "Cannot transfer to zero address");

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public whenNotPaused returns (bool) {
        require(spender != address(0), "Cannot approve zero address");

        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public whenNotPaused returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        require(to != address(0), "Cannot transfer to zero address");

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;

        emit Transfer(from, to, value);
        return true;
    }

    function mint(uint256 amount) public onlyOwner whenNotPaused {
        uint256 amountWithDecimals = amount * 10 ** uint256(decimals);
        totalSupply += amountWithDecimals;
        balanceOf[owner] += amountWithDecimals;

        emit Mint(owner, amountWithDecimals);
        emit Transfer(address(0), owner, amountWithDecimals);
    }

    function burn(uint256 amount) public whenNotPaused {
        uint256 amountWithDecimals = amount * 10 ** uint256(decimals);
        require(balanceOf[msg.sender] >= amountWithDecimals, "Insufficient balance to burn");

        totalSupply -= amountWithDecimals;
        balanceOf[msg.sender] -= amountWithDecimals;

        emit Burn(msg.sender, amountWithDecimals);
        emit Transfer(msg.sender, address(0), amountWithDecimals);
    }

    function pause() public onlyOwner whenNotPaused {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner whenPaused {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function registerContent(string memory hash) public whenNotPaused returns (uint256) {
        require(bytes(hash).length > 0, "Content hash cannot be empty");

        contentCounter++;
        contents[contentCounter] = Content(msg.sender, block.timestamp, hash, 0);

        emit ContentRegistered(contentCounter, msg.sender, hash, block.timestamp);
        return contentCounter;
    }

    function payRoyalty(uint256 contentId, uint256 amount) public whenNotPaused {
        require(contentId <= contentCounter, "Invalid content ID");
        require(amount > 0, "Royalty amount must be greater than zero");

        Content storage content = contents[contentId];
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[content.creator] += amount;

        content.royaltiesEarned += amount;

        emit RoyaltyPaid(contentId, content.creator, amount);
    }
}
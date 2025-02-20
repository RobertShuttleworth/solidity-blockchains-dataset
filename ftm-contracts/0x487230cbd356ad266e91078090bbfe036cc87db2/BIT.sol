// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BIT {
    string public name = "Digital Euro"; // Tokenin nimi - Digital Euro by:BIT
    string public symbol = "\u20AC";       // Symboli
    uint8 public decimals = 2;        // Desimaalit
    uint256 public totalSupply;       // Kokonaistarjonta

    address public owner;             // Omistajan osoite
    mapping(address => uint256) public balanceOf; // Balanssit
    mapping(address => mapping(address => uint256)) public allowance; // Hyväksytyt siirrot

    string public logoURI;            // Logon URL (valinnainen)

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TokensWithdrawn(address indexed owner, uint256 amount);
    event FTMWithdrawn(address indexed owner, uint256 amount);
    event LogoUpdated(string oldLogo, string newLogo);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    constructor(uint256 _initialSupply) {
        owner = msg.sender; // Omistajan alustus
        uint256 initialMint = _initialSupply * 10 ** decimals; 
        uint256 initialOwnerTokens = 100 * 10 ** decimals; // 100 tokenia omistajalle
        totalSupply = initialMint + initialOwnerTokens;
        balanceOf[owner] = totalSupply;
        emit Transfer(address(0), owner, totalSupply);
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
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
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function mint(uint256 _amount) public onlyOwner {
        uint256 mintAmount = _amount * 10 ** decimals;
        totalSupply += mintAmount;
        balanceOf[owner] += mintAmount;
        emit Transfer(address(0), owner, mintAmount);
    }

    function burn(uint256 _amount) public onlyOwner {
        uint256 burnAmount = _amount * 10 ** decimals;
        require(balanceOf[owner] >= burnAmount, "Insufficient balance to burn");
        totalSupply -= burnAmount;
        balanceOf[owner] -= burnAmount;
        emit Transfer(owner, address(0), burnAmount);
    }

    function airdrop(address _to, uint256 _amount) public onlyOwner {
        uint256 mintAmount = _amount * 10 ** decimals;
        totalSupply += mintAmount;
        balanceOf[_to] += mintAmount;
        emit Transfer(address(0), _to, mintAmount);
    }

    function withdrawTokens(uint256 _amount) public onlyOwner {
        require(balanceOf[address(this)] >= _amount, "Insufficient token balance in contract");
        balanceOf[address(this)] -= _amount;
        balanceOf[owner] += _amount;
        emit TokensWithdrawn(owner, _amount);
    }

    function withdrawFTM(uint256 _amount) public onlyOwner {
        require(address(this).balance >= _amount, "Insufficient FTM balance in contract");
        payable(owner).transfer(_amount);
        emit FTMWithdrawn(owner, _amount);
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "New owner cannot be the zero address");
        emit OwnershipTransferred(owner, _newOwner);
        owner = _newOwner;
    }

    function setLogoURI(string memory _logoURI) public onlyOwner {
        string memory oldLogo = logoURI;
        logoURI = _logoURI; // Omistaja voi päivittää logon URL:n
        emit LogoUpdated(oldLogo, _logoURI);
    }

    receive() external payable {} // Mahdollistaa sopimuksen vastaanottavan FTM-valuuttaa
}
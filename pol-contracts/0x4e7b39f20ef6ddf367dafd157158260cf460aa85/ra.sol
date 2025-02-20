// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

contract ERC20Token {
    string public name;
    string public symbol;
    uint8 public decimals;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    address[] public holders;

    uint256 public totalSupply;
    uint256 public taxFee = 80; 
    uint256 public teamFee = 90;
    uint256 public currentTeamFee;
    uint256 public minTeamFee = 100;
    address payable public teamWallet;

    uint256 public startTime;
    uint256 public taxDecayInterval = 21900 days; 
    uint256 public lastTaxUpdateTime;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event WinnerSelected(address indexed winner, uint256 amount);

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply, address payable _teamWallet) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _initialSupply * (10 ** uint256(_decimals));
        balanceOf[msg.sender] = totalSupply;
        holders.push(msg.sender);
        teamWallet = _teamWallet;
        startTime = block.timestamp;
        lastTaxUpdateTime = block.timestamp;
        currentTeamFee = teamFee;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        _updateTaxFee();
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_from != address(0), "Invalid address");
        require(_to != address(0), "Invalid address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");
        _updateTaxFee();
        allowance[_from][msg.sender] -= _value;
        _transfer(_from, _to, _value);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        uint256 taxAmount = _value * taxFee / 10000;
        uint256 teamAmount = _value * currentTeamFee / 10000;
        uint256 netAmount = _value - taxAmount - teamAmount;

        balanceOf[_from] -= _value;
        balanceOf[_to] += netAmount;
        balanceOf[address(this)] += taxAmount;

        if (teamAmount > 0) { 
            balanceOf[teamWallet] += teamAmount;
            emit Transfer(_from, teamWallet, teamAmount);
        }

        emit Transfer(_from, _to, netAmount);
        emit Transfer(_from, address(this), taxAmount);

        if (balanceOf[_to] > 0 && !_isHolder(_to)) {
            holders.push(_to);
        }

        _distributeFee(taxAmount);
    }

    function _distributeFee(uint256 fee) internal {
        require(holders.length > 0, "No holders to distribute the fee to");
        
        uint256 index = _random(holders.length);
        address winner = holders[index];
        
        balanceOf[address(this)] -= fee;
        balanceOf[winner] += fee;
        
        emit WinnerSelected(winner, fee);
        emit Transfer(address(this), winner, fee);
    }

    function _random(uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, holders))) % max;
    }

    function _isHolder(address account) internal view returns (bool) {
        for (uint256 i = 0; i < holders.length; i++) {
            if (holders[i] == account) {
                return true;
            }
        }
        return false;
    }

    function _updateTaxFee() internal {
        if (block.timestamp >= lastTaxUpdateTime + taxDecayInterval) {
            uint256 intervalsPassed = (block.timestamp - lastTaxUpdateTime) / taxDecayInterval;
            for (uint256 i = 0; i < intervalsPassed; i++) {
                if (currentTeamFee > minTeamFee) {
                    currentTeamFee = currentTeamFee / 2;
                }
                if (currentTeamFee < minTeamFee) {
                    currentTeamFee = minTeamFee;
                    break;
                }
            }
            lastTaxUpdateTime = block.timestamp;
        }
    }
}

contract ra is ERC20Token {
    constructor() ERC20Token("radium.cfd", "RA", 18, 2100000000, payable(0x6B26F8f6dA4A7cF61692D2b962a5bb175c37aE7c)) {}
}
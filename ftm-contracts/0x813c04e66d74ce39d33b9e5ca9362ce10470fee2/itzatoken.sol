// SPDX-License-Identifier: Frensware
pragma solidity 0.8.8;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

contract itzatoken is IERC20 {
    // DATA
        string private _name;
        string private _symbol;
        
        address private _masterChief = address(0);

        uint256 private _totalSupply;
        uint8 private _decimals;

        mapping(address => uint256) _balances;
        mapping(address => mapping(address => uint256)) _allowances;

        constructor(string memory n, string memory s, uint256 tValue, uint8 dValue){
            _name = n;
            _symbol = s;
            _totalSupply = tValue;
            _decimals = dValue;
            _balances[msg.sender] = tValue;
            emit Transfer(address(0), msg.sender, tValue);
        }

    // VIEW
        function name() public view returns(string memory){ return _name; }
        function symbol() public view returns(string memory){ return _symbol; }
        function decimals() public view returns(uint8){ return _decimals; }
        function totalSupply() public view returns(uint256){ return _totalSupply; }
        function balanceOf(address user) public view returns(uint256){ return _balances[user]; }
        function allowance(address user, address spender) public view returns(uint256){ return _allowances[user][spender]; }
        function getOwner() public view returns(address){ return _masterChief; }

    // ACTIVE
        function approve(address user, uint256 value) public returns(bool){
            _allowances[msg.sender][user] = value;
            emit Approval(msg.sender, user, value);
            return true;
        }

        function transfer(address to, uint256 value) public returns(bool){
            require(_balances[msg.sender] >= value, "Insufficient Balances");
            return _basicTransfer(msg.sender, to, value);
        }

        function transferFrom(address from, address to, uint256 value) public returns(bool){
            if(from != msg.sender){
                require(_allowances[from][msg.sender] >= value, "Insufficient Allowances");
                    _allowances[from][msg.sender] -= value;
            }
            require(_balances[from] >= value, "Insufficient Balances");
            return _basicTransfer(from, to, value);
        }

    // INTERNAL
        function _basicTransfer(address from, address to, uint256 value) internal returns(bool){
            _balances[from] -= value;
            _balances[to] += value;
            emit Transfer(from, to, value);
            return true;
        }

        event Approval(address indexed user, address indexed spender, uint256 value);
        event Transfer(address indexed from, address indexed to, uint256 value);
}
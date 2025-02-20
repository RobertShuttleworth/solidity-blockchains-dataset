// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract DiamondBites is IERC20, Ownable {
    string public name = "Diamond Bites";
    string public symbol = "$DMB";
    uint8 public decimals = 6;
    uint256 public totalSupply;
    uint256 public constant maxSupply = 100000000 * 10**6; // 100M tokens

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    address public saleContract;
    bool public tradingEnabled;

    event TradingEnabled(bool enabled);
    event SaleContractUpdated(address indexed newSaleContract);

    modifier canMint() {
        require(msg.sender == saleContract || msg.sender == owner(), "Only sale contract or owner can mint");
        _;
    }

    function setSaleContract(address _saleContract) external onlyOwner {
        require(_saleContract != address(0), "Invalid address");
        saleContract = _saleContract;
        emit SaleContractUpdated(_saleContract);
    }

    function mint(address to, uint256 amount) external canMint {
        require(totalSupply + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
    }

    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled(true);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(
            tradingEnabled || 
            from == owner() || 
            to == owner() || 
            from == saleContract || 
            to == saleContract,
            "Trading not enabled yet"
        );

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "Transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "Mint to zero address");

        totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        _transferOwnership(newOwner);
    }

    function renounceOwnership() public override onlyOwner {
        _transferOwnership(address(0));
    }

    function recoverToken(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(this), "Cannot recover Diamond Bites token");
        IERC20(tokenAddress).transfer(owner(), amount);
    }
}
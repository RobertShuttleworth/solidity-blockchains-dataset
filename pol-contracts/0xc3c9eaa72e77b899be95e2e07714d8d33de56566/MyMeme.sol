// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Enum for defining custom token types
enum MyMemeType { 
    Basic, 
    PoolLiquidity, 
    LiquidityFeeToken, 
    FeeOnBuySell, 
    TokenBurn, 
    BabyToken, 
    AntiBotStandard, 
    AntiBotLiquidity, 
    AntiBotLiquidityFee, 
    AntiBotBuySellFee, 
    AntiBotBurn, 
    AntiBotBaby 
}

// PancakeSwap V2 Router Interface 
interface IPancakeSwapV2Router { 
    function executeTokenSwap( 
        uint inputAmount, 
        uint minOutputAmount, 
        address[] calldata swapPath, 
        address recipient, 
        uint expiry 
    ) external returns (uint[] memory outputAmounts); 
}

// PancakeSwap V3 Router Interface 
interface IPancakeSwapV3Router { 
    function executeExactInput( 
        bytes calldata swapPath, 
        uint inputAmount, 
        uint minOutputAmount, 
        address recipient, 
        uint expiry 
    ) external returns (uint outputAmount); 
}

// ERC20 Token contract implementation 
contract MyMeme { 
    uint256 public totalSupply; 
    string public name; 
    string public symbol; 
    uint8 public decimals; 

    // Balances will be stored in public variable
    mapping(address => uint256) public balances; 
    mapping(address => mapping(address => uint256)) public allowances; 

    // Anti-sniping mechanism
    uint256 public snipingFeeRate; 
    uint256 public deploymentTime;
    uint256 public snipingDuration = 1 hours;

    // Events for token transfers and approvals
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Constructor to initialize the token
    constructor( 
        string memory name_, 
        string memory symbol_, 
        uint8 decimals_, 
        uint256 initialSupply_
    ) { 
        name = name_; 
        symbol = symbol_; 
        decimals = decimals_; 
        totalSupply = initialSupply_ * (10 ** uint256(decimals)); // Set total supply with decimals 

        uint256 burnAmount = totalSupply / 20; // 5% of total supply
        totalSupply -= burnAmount; // Reduce total supply
        balances[address(0)] += burnAmount; // Send burnt tokens to the zero address
        emit Transfer(msg.sender, address(0), burnAmount); // Emit burn event

        balances[msg.sender] = totalSupply; // Assign remaining supply to the deployer's address
        deploymentTime = block.timestamp; // Record deployment time
        snipingFeeRate = 5; // 5% fee for quick purchases
    }

    // ERC20 functions
    function transfer(address recipient, uint256 amount) public returns (bool) { 
        require(amount > 0, "Transfer amount must be positive"); 
        _transfer(msg.sender, recipient, amount); 
        emit Transfer(msg.sender, recipient, amount); // Emit Transfer event
        return true; 
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public returns (bool) { 
        require(amount > 0, "Approval amount must be positive"); 
        allowances[msg.sender][spender] = amount; 
        emit Approval(msg.sender, spender, amount); // Emit Approval event
        return true; 
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) { 
        require(amount > 0, "Transfer amount must be positive"); 
        require(allowances[sender][msg.sender] >= amount, "Allowance exceeded");
        _transfer(sender, recipient, amount); 
        allowances[sender][msg.sender] -= amount; 
        emit Transfer(sender, recipient, amount); // Emit Transfer event
        return true; 
    }

    function swapTokensUsingV2(IPancakeSwapV2Router router, uint amountIn, uint minAmountOut, address[] calldata path) external { 
        require(path[0] == address(this), "First address in path must be this token"); 
        
        uint256 transferAmount = amountIn;
        
        // Apply anti-snipe fee if within the anti-sniping duration
        if (block.timestamp < deploymentTime + snipingDuration) {
            uint256 feeAmount = (amountIn * snipingFeeRate) / 100; // Calculate fee
            transferAmount = amountIn - feeAmount; // Amount to transfer after fee
            balances[address(this)] += feeAmount; // Collect fee in contract for future use
        }
        
        // Set allowance for the router
        allowances[address(this)][address(router)] = transferAmount; 
        router.executeTokenSwap(transferAmount, minAmountOut, path, msg.sender, block.timestamp); 
    }

    function swapTokensUsingV3(IPancakeSwapV3Router router, bytes calldata path, uint amountIn, uint minAmountOut) external { 
        require(keccak256(abi.encodePacked(address(this))) == keccak256(abi.encodePacked(path[0])), "First address in path must be this token"); 
        
        uint256 transferAmount = amountIn;
        
        // Apply anti-snipe fee if within the anti-snipe duration
        if (block.timestamp < deploymentTime + snipingDuration) {
            uint256 feeAmount = (amountIn * snipingFeeRate) / 100; // Calculate fee
            transferAmount = amountIn - feeAmount; // Amount to transfer after fee
            balances[address(this)] += feeAmount; // Collect fee in contract for future use
        }
        
        // Set allowance for the router
        allowances[address(this)][address(router)] = transferAmount; 
        router.executeExactInput(path, transferAmount, minAmountOut, msg.sender, block.timestamp); 
    }

    // Internal function to transfer tokens
    function _transfer(address sender, address recipient, uint256 amount) internal { 
        require(sender != address(0), "Transfer from the zero address"); 
        require(recipient != address(0), "Transfer to the zero address"); 
        require(balances[sender] >= amount, "Transfer amount exceeds balance"); 
        balances[sender] -= amount; 
        balances[recipient] += amount; 
    }
}
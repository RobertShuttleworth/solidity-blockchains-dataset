// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum CustomTokenType { 
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

// Ownable contract to manage ownership 
contract AdminControl { 
    address public admin;

    constructor() { 
        admin = msg.sender; 
    }

    modifier onlyAdmin() { 
        require(msg.sender == admin, "Not the contract admin"); 
        _; 
    }

    function changeAdmin(address newAdmin) public onlyAdmin { 
        require(newAdmin != address(0), "New admin is the zero address"); 
        admin = newAdmin; 
    }

    function renounceAdmin() public onlyAdmin { 
        admin = address(0); // Transfer admin rights to the zero address 
    } 
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

// ERC20 Interface 
interface ICustomERC20 { 
    function getTotalSupply() external view returns (uint256); 
    function getBalance(address account) external view returns (uint256); 
    function send(address recipient, uint256 amount) external returns (bool); 
    function authorize(address spender, uint256 amount) external returns (bool); 
    function sendFrom(address sender, address recipient, uint256 amount) external returns (bool); 
    function getAllowance(address owner, address spender) external view returns (uint256); 
    event Transfer(address indexed from, address indexed to, uint256 value); 
    event Approval(address indexed owner, address indexed spender, uint256 value); 
}

// Implementation of ERC20 Token contract 
contract CustomToken is ICustomERC20, AdminControl { 
    uint256 public constant VERSION_NUMBER = 1; 
    mapping(address => uint256) private accountBalances; 
    mapping(address => mapping(address => uint256)) private allowedAmounts; 
    uint256 private totalSupplyAmount; 
    string private tokenName; 
    string private tokenSymbol; 
    uint8 private tokenDecimals; 

    uint256 public snipingFeeRate = 5; // 5% fee for quick purchases
    uint256 public deploymentTime;
    uint256 public snipingDuration = 1 hours;

    constructor( 
        string memory name_, 
        string memory symbol_, 
        uint8 decimals_, 
        uint256 supplyAmount_ 
    ) { 
        tokenName = name_; 
        tokenSymbol = symbol_; 
        tokenDecimals = decimals_; 
        totalSupplyAmount = supplyAmount_ * (10 ** uint256(decimals_)); // Set total supply with decimals 
        _mintTokens(msg.sender, totalSupplyAmount); // Mint total supply 
        deploymentTime = block.timestamp; // Record deployment time
    }

    function getName() public view returns (string memory) { 
        return tokenName; 
    }

    function getSymbol() public view returns (string memory) { 
        return tokenSymbol; 
    }

    function getDecimals() public view returns (uint8) { 
        return tokenDecimals; 
    }

    function getTotalSupply() public view override returns (uint256) { 
        return totalSupplyAmount; 
    }

    function getBalance(address account) public view override returns (uint256) { 
        return accountBalances[account]; 
    }

    function send(address recipient, uint256 amount) public override returns (bool) { 
        require(amount > 0, "Transfer amount must be positive"); 
        _transferTokens(msg.sender, recipient, amount); 
        return true; 
    }

    function getAllowance(address owner, address spender) public view override returns (uint256) { 
        return allowedAmounts[owner][spender]; 
    }

    function authorize(address spender, uint256 amount) public override returns (bool) { 
        require(amount > 0, "Approval amount must be positive"); 
        _setApproval(msg.sender, spender, amount); 
        return true; 
    }

    function sendFrom(address sender, address recipient, uint256 amount) public override returns (bool) { 
        require(amount > 0, "Transfer amount must be positive"); 
        _transferTokens(sender, recipient, amount); 
        _setApproval(sender, msg.sender, allowedAmounts[sender][msg.sender] - amount); 
        return true; 
    }

    function increaseApproval(address spender, uint256 addedValue) public returns (bool) { 
        _setApproval(msg.sender, spender, allowedAmounts[msg.sender][spender] + addedValue); 
        return true; 
    }

    function decreaseApproval(address spender, uint256 subtractedValue) public returns (bool) { 
        _setApproval(msg.sender, spender, allowedAmounts[msg.sender][spender] - subtractedValue); 
        return true; 
    }

    function swapTokensUsingV2(IPancakeSwapV2Router router, uint amountIn, uint minAmountOut, address[] calldata path) external { 
        require(path[0] == address(this), "First address in path must be this token"); 
        
        uint256 transferAmount = amountIn;
        
        // Apply anti-snipe fee if within the anti-sniping duration
        if (block.timestamp < deploymentTime + snipingDuration) {
            uint256 feeAmount = (amountIn * snipingFeeRate) / 100; // Calculate fee
            transferAmount = amountIn - feeAmount; // Amount to transfer after fee
            accountBalances[address(this)] += feeAmount; // Collect fee in contract for future use
        }
        
        // Corrected function call
        _setApproval(address(this), address(router), transferAmount); 
        router.executeTokenSwap(transferAmount, minAmountOut, path, msg.sender, block.timestamp); 
    }

    function swapTokensUsingV3(IPancakeSwapV3Router router, bytes calldata path, uint amountIn, uint minAmountOut) external { 
        require(keccak256(abi.encodePacked(address(this))) == keccak256(abi.encodePacked(path[0])), "First address in path must be this token"); 
        
        uint256 transferAmount = amountIn;
        
        // Apply anti-snipe fee if within the anti-snipe duration
        if (block.timestamp < deploymentTime + snipingDuration) {
            uint256 feeAmount = (amountIn * snipingFeeRate) / 100; // Calculate fee
            transferAmount = amountIn - feeAmount; // Amount to transfer after fee
            accountBalances[address(this)] += feeAmount; // Collect fee in contract for future use
        }
        
        // Corrected function call
        _setApproval(address(this), address(router), transferAmount); 
        router.executeExactInput(path, transferAmount, minAmountOut, msg.sender, block.timestamp); 
    }

    function _mintTokens(address account, uint256 amount) internal { 
        require(account != address(0), "Mint to the zero address"); 
        accountBalances[account] += amount; 
        emit Transfer(address(0), account, amount); 
    }

    function _transferTokens(address sender, address recipient, uint256 amount) internal { 
        require(sender != address(0), "Transfer from the zero address"); 
        require(recipient != address(0), "Transfer to the zero address"); 
        require(accountBalances[sender] >= amount, "Transfer amount exceeds balance"); 
        accountBalances[sender] -= amount; 
        accountBalances[recipient] += amount; 
        emit Transfer(sender, recipient, amount); 
    }

    function _setApproval(address owner, address spender, uint256 amount) internal { 
        require(owner != address(0), "Approve from the zero address"); 
        require(spender != address(0), "Approve to the zero address"); 
        allowedAmounts[owner][spender] = amount; 
        emit Approval(owner, spender, amount); 
    }
}
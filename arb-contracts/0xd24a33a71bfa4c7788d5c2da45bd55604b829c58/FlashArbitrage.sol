// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.6.12 <0.9.0;

// **Interface 1: IERC20 from OpenZeppelin**
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// **Interface 2: IUniswapV2Router02**
interface IUniswapV2Router02 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// **Interface 3: IERC20WithPermit**
interface IERC20WithPermit is IERC20 {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// **Main Contract: FlashArbitrage**
contract FlashArbitrage {
    address public owner; // The owner of the contract

    constructor() {
        // Assign the owner of the contract to the deployer
        owner = msg.sender;
    }

    modifier onlyOwner() {
        // Ensure only the owner can call specific functions
        require(msg.sender == owner, "Not the owner");
        _;
    }

    // Function to execute an arbitrage trade using Uniswap
    function executeTrade(
        address router, 
        uint amountIn, 
        uint amountOutMin, 
        address[] calldata path
    ) external onlyOwner {
        IUniswapV2Router02(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            amountOutMin,
            path,
            address(this), // The contract receives the tokens
            block.timestamp // Use current timestamp as the deadline
        );
    }

    // Function to withdraw tokens from the contract
    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }

    // Function to receive ETH (if necessary)
    receive() external payable {}
}
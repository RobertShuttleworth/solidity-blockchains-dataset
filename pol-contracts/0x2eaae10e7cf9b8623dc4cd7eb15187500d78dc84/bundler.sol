// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
}

contract bundler {
    address public ownerAddress;
    address public tokenAddress;
    address[] public walletAddresses;
    uint256[] public distributionPercentages;
    IUniswapV2Router02 public uniswapRouter;

    constructor() {
        ownerAddress = msg.sender;
        // Set the Uniswap V2 Router address 
        //eth 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        uniswapRouter = IUniswapV2Router02(0xedf6066a2b290C185783862C7F4776A2C8077AD1);
    }

    modifier onlyOwner() {
        require(msg.sender == ownerAddress, "Not the ownerAddress");
        _;
    }

    // Function to deposit ETH into the contract
    function deposit() external payable {}

    // Function to update the token address
    function setTokenContractAddress(address _tokenAddress) external onlyOwner {
        tokenAddress = _tokenAddress;
    }

    // Function to update the walletAddresses
    function setReceieverWallets(address[] calldata _wallets) external onlyOwner {
        walletAddresses = _wallets;
    }

    // Function to update the distributionPercentages
    function setDistributionPercentages(uint256[] calldata _distribution) external onlyOwner {
        require(_distribution.length == walletAddresses.length, "Distribution and walletAddresses length mismatch");
        distributionPercentages = _distribution;
    }

    // Function to buy tokens once and distribute them among the walletAddresses
    function buy() external onlyOwner {
        require(walletAddresses.length == distributionPercentages.length, "Invalid setup");

        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH balance to buy tokens");

        uint256 totalDistribution = 0;
        for (uint256 i = 0; i < distributionPercentages.length; i++) {
            totalDistribution += distributionPercentages[i];
        }
        require(totalDistribution == 100, "Distribution must sum to 100");

   address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH(); // WETH address
        path[1] = tokenAddress;

        uint256 amountOutMin = 0; // Set to 0 for simplicity, but should use slippage tolerance

        // Buy tokens once with the full ETH balance
        uniswapRouter.swapExactETHForTokens{value: balance}(
            amountOutMin,
            path,
            address(this),
            block.timestamp + 300 // 5 minutes deadline
        );

        // Get the total amount of tokens bought
        IERC20 token = IERC20(tokenAddress);
        uint256 totalTokens = token.balanceOf(address(this));

        // Distribute tokens to each wallet based on the distributionPercentages percentage
        for (uint256 i = 0; i < walletAddresses.length; i++) {
            uint256 tokenAmount = (totalTokens * distributionPercentages[i]) / 100;
            require(token.transfer(walletAddresses[i], tokenAmount), "Token transfer failed");
        }
    }

    // Function to withdraw leftover ETH (if needed)
    function withdrawBalance() external onlyOwner {
        payable(ownerAddress).transfer(address(this).balance);
    }

    // Fallback function to accept ETH
    receive() external payable {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router02.sol";
import "./contracts_Token.sol";
import "./contracts_Staking.sol";

contract Presale is Ownable, ReentrancyGuard {
    Token public token;
    Staking public stakingContract;
    IUniswapV2Router02 public immutable pancakeRouter;
    address public liquidityVault;
    
    uint256 public initialPrice = 41406318500000 wei; // Prezzo esatto per ottenere 24151 token per 1 BNB
    uint256 public constant PRICE_INCREASE_PERCENTAGE = 1;
    uint256 public constant PRICE_INCREASE_INTERVAL = 12 hours;
    uint256 public constant TOKENS_FOR_LIQUIDITY_PERCENTAGE = 30;
    
    uint256 public presaleStartTime;
    uint256 public totalRaised;
    uint256 public totalTokensSold;
    
    mapping(address => uint256) public contributions;
    bool public presaleFinalized;

    event TokensPurchased(address indexed buyer, uint256 ethAmount, uint256 tokenAmount);
    event PresaleFinalized(uint256 ethAmount, uint256 tokenAmount);
    event RemainingTokensStaked(uint256 amount);

    constructor(
        address _token,
        address _pancakeRouter,
        address _stakingContract,
        address _liquidityVault
    ) {
        require(_token != address(0), "Invalid token address");
        require(_pancakeRouter != address(0), "Invalid router address");
        require(_stakingContract != address(0), "Invalid staking address");
        require(_liquidityVault != address(0), "Invalid liquidity vault address");
        token = Token(_token);
        pancakeRouter = IUniswapV2Router02(_pancakeRouter);
        stakingContract = Staking(_stakingContract);
        liquidityVault = _liquidityVault;
        presaleStartTime = block.timestamp;
    }

    function getCurrentPrice() public view returns (uint256) {
        uint256 elapsedIntervals = (block.timestamp - presaleStartTime) / PRICE_INCREASE_INTERVAL;
        uint256 priceIncrease = initialPrice * elapsedIntervals * PRICE_INCREASE_PERCENTAGE / 100;
        return initialPrice + priceIncrease;
    }

    function setInitialPrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "Price must be greater than 0");
        initialPrice = _newPrice;
    }

    function participate() external payable nonReentrant {
        require(!presaleFinalized, "Presale finalized");
        require(address(token) != address(0), "Token not set");

        uint256 currentPrice = getCurrentPrice();
        uint256 tokenAmount = (msg.value * 1 ether) / currentPrice;

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        totalTokensSold += tokenAmount;

        require(token.transfer(msg.sender, tokenAmount), "Token transfer failed");

        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }

    function finalize() external onlyOwner {
        require(!presaleFinalized, "Already finalized");
        require(address(token) != address(0), "Token not set");
        
        presaleFinalized = true;

        // Usa tutti i token dal LiquidityVault per la liquidità
        uint256 tokensForLiquidity = token.balanceOf(liquidityVault);
        
        // Trasferisci i token dal LiquidityVault al contratto
        require(token.transferFrom(liquidityVault, address(this), tokensForLiquidity), "Transfer from liquidity vault failed");
        
        // Approva il router PancakeSwap
        token.approve(address(pancakeRouter), tokensForLiquidity);
        
        // Aggiungi liquidità a PancakeSwap con i BNB raccolti
        pancakeRouter.addLiquidityETH{value: totalRaised}(
            address(token),
            tokensForLiquidity,
            0, // slippage configurato a 100% per semplicità
            0, // slippage configurato a 100% per semplicità
            owner(),
            block.timestamp + 300
        );

        // Metti in staking i token rimanenti del presale
        uint256 remainingPresaleTokens = token.balanceOf(address(this));
        if (remainingPresaleTokens > 0) {
            // Approva lo staking contract
            token.approve(address(stakingContract), remainingPresaleTokens);
            
            // Stake dei token rimanenti
            stakingContract.stake(remainingPresaleTokens);
            
            emit RemainingTokensStaked(remainingPresaleTokens);
        }

        emit PresaleFinalized(totalRaised, tokensForLiquidity);
    }

    // View function per il frontend
    function getTokensForBNB(uint256 bnbAmount) public view returns (uint256) {
        uint256 currentPrice = getCurrentPrice();
        return (bnbAmount * 1 ether) / currentPrice;
    }

    receive() external payable {}
}
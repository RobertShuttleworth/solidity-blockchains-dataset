// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ReentrancyGuard.sol";
import "./Authorized.sol";

interface INFTContract {
    function purchasePack(address recipient, uint32 loginId, uint256 amount, bool isBusiness) external;
}

contract TokenLocker is ReentrancyGuard, Authorized {
    IERC20 public immutable token;
    INFTContract public nftContract;
    
    // Constantes
    uint256 private constant DAILY_RELEASE_RATE = 66; // 0.66% * 100 para evitar decimais
    uint256 private constant RATE_DENOMINATOR = 10000; // Denominador para cálculo de percentual
    uint256 private constant SECONDS_PER_DAY = 60; // 1 minuto para testes // 86400 aqui DIAS 
    
    struct AirdropInfo {
        uint256 amount;            // Total inicial do airdrop
        uint256 claimed;           // Total reivindicado via claims
        uint256 usedForPurchase;   // Total usado para compras de NFT
        uint256 startTime;
        bool exists;
    }
    
    // Mapping de usuário -> ID do Airdrop -> Informações do Airdrop
    mapping(address => mapping(uint256 => AirdropInfo)) public airdrops;
    mapping(address => uint256) public airdropCount;
    
    event AirdropReceived(address indexed user, uint256 indexed airdropId, uint256 amount);
    event TokensClaimed(address indexed user, uint256 indexed airdropId, uint256 amount);
    event NFTPurchased(address indexed user, uint256 totalAmount);
    
    constructor(address _token) {
        token = IERC20(_token);
    }
    
    function setNFTContract(address _nftContract) external onlyOwner {
        nftContract = INFTContract(_nftContract);
    }
    
    function receiveAirdrop(address recipient, uint256 amount) external nonReentrant isAuthorized(2) {
        require(amount > 0, "Amount must be greater than 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        uint256 airdropId = airdropCount[recipient];
        airdrops[recipient][airdropId] = AirdropInfo({
            amount: amount,
            claimed: 0,
            usedForPurchase:0,
            startTime: block.timestamp,
            exists: true
        });
        
        airdropCount[recipient] += 1;
        emit AirdropReceived(recipient, airdropId, amount);
    }
    
    function getClaimableAmount(address user, uint256 airdropId) public view returns (uint256) {
        AirdropInfo storage airdrop = airdrops[user][airdropId];
        if (!airdrop.exists) return 0;
        
        uint256 elapsedDays = (block.timestamp - airdrop.startTime) / SECONDS_PER_DAY;
        uint256 totalReleasable = (airdrop.amount * DAILY_RELEASE_RATE * elapsedDays) / RATE_DENOMINATOR;
        
        if (totalReleasable > airdrop.amount) {
            totalReleasable = airdrop.amount;
        }
        
        return totalReleasable - airdrop.claimed;
    }
    
    function claimTokens(uint256 airdropId) external nonReentrant {
        uint256 claimable = getClaimableAmount(msg.sender, airdropId);
        require(claimable > 0, "No tokens available to claim");
        
        airdrops[msg.sender][airdropId].claimed += claimable;
        require(token.transfer(msg.sender, claimable), "Transfer failed");
        
        emit TokensClaimed(msg.sender, airdropId, claimable);
    }
    
    function getTotalAvailableBalance(address user) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < airdropCount[user]; i++) {
            AirdropInfo storage airdrop = airdrops[user][i];
            if (airdrop.exists) {
                total += airdrop.amount - airdrop.claimed - airdrop.usedForPurchase;
            }
        }
        return total;
    }
    
    function purchaseNFT(uint32 loginId, uint256 amount, bool isBusiness) external nonReentrant {
        require(address(nftContract) != address(0), "NFT contract not set");
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 totalAvailable = getTotalAvailableBalance(msg.sender);
        require(totalAvailable >= amount, "Insufficient balance");
        
        // Distribuir proporcionalmente entre airdrops
        uint256 remainingAmount = amount;
        for (uint256 i = 0; i < airdropCount[msg.sender] && remainingAmount > 0; i++) {
            AirdropInfo storage airdrop = airdrops[msg.sender][i];
            if (airdrop.exists) {
                uint256 airdropRemaining = airdrop.amount - airdrop.claimed - airdrop.usedForPurchase;
                if (airdropRemaining > 0) {
                    uint256 toUse = remainingAmount > airdropRemaining ? airdropRemaining : remainingAmount;
                    airdrop.usedForPurchase += toUse;
                    remainingAmount -= toUse;
                }
            }
        }
        
        require(token.approve(address(nftContract), amount), "Approval failed");
        nftContract.purchasePack(msg.sender, loginId, amount, isBusiness);
        emit NFTPurchased(msg.sender, amount);
    }
    
}
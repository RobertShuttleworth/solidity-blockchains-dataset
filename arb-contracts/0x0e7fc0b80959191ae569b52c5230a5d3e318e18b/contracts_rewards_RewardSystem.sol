// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_tokens_SYRAXERC1155.sol";
import "./hardhat_console.sol";

contract RewardSystem {
   
    mapping(address => uint256) public builderMarkets;
    mapping(address => uint256) public userPredictions;

    mapping(address => uint256) public accountTokens;
    mapping(address => mapping (uint => bool)) public accountNFTs;

    IERC20 public rewardToken;
    NFT public rewardNFT;

    // Builder Thresholds
    uint256 public BUILDER_BRONZE_THRESHOLD;
    uint256 public BUILDER_SILVER_THRESHOLD;
    uint256 public BUILDER_GOLD_THRESHOLD;
    uint256 public BUILDER_PLATINUM_THRESHOLD;
    uint256 public BUILDER_DIAMOND_THRESHOLD;
    // Builder Rewards
    uint256 public BRONZE_REWARD;
    uint256 public SILVER_REWARD;
    uint256 public GOLD_REWARD;
    uint256 public PLATINUM_REWARD;
    uint256 public DIAMOND_REWARD;

    // User Thresholds
    uint256 public USER_WHITE_THRESHOLD;
    uint256 public USER_YELLOW_THRESHOLD;
    uint256 public USER_ORANGE_THRESHOLD;
    uint256 public USER_RED_THRESHOLD;
    uint256 public USER_PURPLE_THRESHOLD;
    // User Rewards
    uint256 public WHITE_REWARD;
    uint256 public YELLOW_REWARD;
    uint256 public ORANGE_REWARD;
    uint256 public RED_REWARD;
    uint256 public PURPLE_REWARD;

    mapping(address => uint256) public validatorMarkets;

    struct BuilderThresholds {
        uint256 BUILDER_BRONZE_THRESHOLD;
        uint256 BUILDER_SILVER_THRESHOLD;
        uint256 BUILDER_GOLD_THRESHOLD;
        uint256 BUILDER_PLATINUM_THRESHOLD;
        uint256 BUILDER_DIAMOND_THRESHOLD;
    }

    struct TraderThresholds {
        uint256 USER_WHITE_THRESHOLD;
        uint256 USER_YELLOW_THRESHOLD;
        uint256 USER_ORANGE_THRESHOLD;
        uint256 USER_RED_THRESHOLD;
        uint256 USER_PURPLE_THRESHOLD;
    }

    struct BuilderRewards {
        uint256 BRONZE_REWARD;
        uint256 SILVER_REWARD;
        uint256 GOLD_REWARD;
        uint256 PLATINUM_REWARD;
        uint256 DIAMOND_REWARD;
    }

    struct TraderRewards {
        uint256 WHITE_REWARD;
        uint256 YELLOW_REWARD;
        uint256 ORANGE_REWARD;
        uint256 RED_REWARD;
        uint256 PURPLE_REWARD;
    }


    event RewardDistributed(address indexed user, uint256 indexed nftId, uint256 indexed tokenAmount);
    event MarketBuilt(address indexed builder);
    event Prediction(address indexed user);
    event NFTClaimed(address indexed user, uint256 indexed nftId);
    event TokenClaimed(address indexed user, uint256 indexed tokenAmount);
    event Funded(address indexed funder, uint256 indexed amount);
    event MarketValidated(address indexed validator);

    function setAddresses(address _syraxToken, address _rewardNFT) internal {
        rewardToken = IERC20(_syraxToken);
        rewardNFT = NFT(_rewardNFT);
    }

    function recordMarketCreation(address builder) internal {
        builderMarkets[builder]++;
        checkAndDistributeBuilderRewards(builder);
        emit MarketBuilt(builder);
    }

    function recordPrediction(address user) internal {
        userPredictions[user]++;
        checkAndDistributeTraderRewards(user);
        emit Prediction(user);
    }

    function recordValidation (address validator) internal {
        validatorMarkets[validator]++;
        checkAndDistributeValidatorRewards(validator);
        emit MarketValidated(validator);
    }

    function checkAndDistributeBuilderRewards(address user) internal {
        uint256 marketsCreated = builderMarkets[user];
        
        if (marketsCreated == BUILDER_BRONZE_THRESHOLD) {
            distributeRewards(user, 1, BRONZE_REWARD);
        } else if (marketsCreated == BUILDER_SILVER_THRESHOLD) {
            distributeRewards(user, 2, SILVER_REWARD);
        } else if (marketsCreated == BUILDER_GOLD_THRESHOLD) {
            distributeRewards(user, 3, GOLD_REWARD);
        } else if (marketsCreated == BUILDER_PLATINUM_THRESHOLD) {
            distributeRewards(user, 4, PLATINUM_REWARD);
        } else if (marketsCreated == BUILDER_DIAMOND_THRESHOLD) {
            distributeRewards(user, 5, DIAMOND_REWARD);
        }
    }

    function checkAndDistributeTraderRewards(address user) internal {
        uint256 predictions = userPredictions[user];
        if(predictions == USER_WHITE_THRESHOLD)
        {
            distributeRewards(user, 6, WHITE_REWARD);
        }
        else if(predictions == USER_YELLOW_THRESHOLD)
        {
            distributeRewards(user, 7, YELLOW_REWARD);
        }
        else if(predictions == USER_ORANGE_THRESHOLD)
        {
            distributeRewards(user, 8, ORANGE_REWARD);
        }
        else if(predictions == USER_RED_THRESHOLD)
        {
            distributeRewards(user, 9, RED_REWARD);
        }
        else if(predictions == USER_PURPLE_THRESHOLD)
        {
            distributeRewards(user, 10, PURPLE_REWARD);
        }
    }

      function checkAndDistributeValidatorRewards(address user) internal {
        uint256 validations = validatorMarkets[user];
        if(validations == USER_WHITE_THRESHOLD)
        {
            distributeRewards(user, 6, WHITE_REWARD);
        }
        else if(validations == USER_YELLOW_THRESHOLD)
        {
            distributeRewards(user, 7, YELLOW_REWARD);
        }
        else if(validations == USER_ORANGE_THRESHOLD)
        {
            distributeRewards(user, 8, ORANGE_REWARD);
        }
        else if(validations == USER_RED_THRESHOLD)
        {
            distributeRewards(user, 9, RED_REWARD);
        }
        else if(validations == USER_PURPLE_THRESHOLD)
        {
            distributeRewards(user, 10, PURPLE_REWARD);
        }
    }

      function distributeRewards(address user, uint256 nftId, uint256 tokenAmount) internal {
        require(rewardToken.balanceOf(address(this)) >= tokenAmount, "RewardSystem: Insufficient balance");
        
        accountTokens[user] += tokenAmount;
        accountNFTs[user][nftId] = true;
        
        emit RewardDistributed(user, nftId, tokenAmount);
    }

    function claimTokens() public {
        require(accountTokens[msg.sender] > 0, "RewardSystem: No tokens to claim");
        require(rewardToken.balanceOf(address(this)) >= accountTokens[msg.sender], "RewardSystem: Insufficient balance");
        require(rewardToken.transfer(msg.sender, accountTokens[msg.sender]), "RewardSystem: Transfer failed");
        accountTokens[msg.sender] = 0;
        emit TokenClaimed(msg.sender, accountTokens[msg.sender]);
    }

    function claimNFTs(uint256 nftId) public {
        require(accountNFTs[msg.sender][nftId] == true , "RewardSystem: No NFTs to claim");
        rewardNFT.mint(msg.sender, nftId, 1, "");
        accountNFTs[msg.sender][nftId] = false;
        emit NFTClaimed(msg.sender, nftId);
    }

    function receiveTokens(uint256 amount) external {
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit Funded(msg.sender, amount);
    }

    function getBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

   

    uint256[49] private __gap_baseReward;

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract PvPBattle is Ownable {
    IERC20 public immutable betToken;
    address public immutable liquidityPool;
    address public immutable seasonRewardPool;
    uint256 public minBetAmount;
    uint256 public maxBetAmount;

    uint256 private constant PRIZE_PERCENTAGE = 80;
    uint256 private constant SEASON_POOL_PERCENTAGE = 10;
    uint256 private constant LIQUIDITY_POOL_PERCENTAGE = 10;

    struct Battle {
        address player1;
        address player2;
        uint256 amount;
        bool isActive;
    }

    Battle[] public battles;

    event BattleCreated(uint256 indexed battleId, address indexed player1, uint256 amount);
    event BattleJoined(uint256 indexed battleId, address indexed player2);
    event BattleResolved(uint256 indexed battleId, address indexed winner, uint256 prizeAmount);
    event BattleCancelled(uint256 indexed battleId);

    event MinBetAmountUpdated(uint256 amount);
    event MaxBetAmountUpdated(uint256 amount);

    constructor(
        address _betToken,
        address _liquidityPool,
        address _seasonRewardPool
    ) {
        require(_betToken != address(0) && _liquidityPool != address(0) && _seasonRewardPool != address(0), "PvPBattle: zero address");
        betToken = IERC20(_betToken);
        liquidityPool = _liquidityPool;
        seasonRewardPool = _seasonRewardPool;
    }

    function setMinBetAmount(uint256 amount) external onlyOwner {
        minBetAmount = amount;
        emit MinBetAmountUpdated(amount);
    }

    function setMaxBetAmount(uint256 amount) external onlyOwner {
        maxBetAmount = amount;
        emit MaxBetAmountUpdated(amount);
    }

    function createBattle(uint256 amount) external {
        require(amount >= minBetAmount, "PvPBattle: bet below minimum");
        require(maxBetAmount == 0 || amount <= maxBetAmount, "PvPBattle: bet exceeds maximum");

        // Transfer bet amount from player1 to the contract
        betToken.transferFrom(msg.sender, address(this), amount);

        battles.push(Battle({
            player1: msg.sender,
            player2: address(0),
            amount: amount,
            isActive: false
        }));

        emit BattleCreated(battles.length - 1, msg.sender, amount);
    }

    function joinBattle(uint256 battleId) external {
        Battle storage battle = battles[battleId];
        require(!battle.isActive, "PvPBattle: battle already active");
        require(battle.player2 == address(0), "PvPBattle: battle already joined");

        // Transfer bet amount from player2 to the contract
        betToken.transferFrom(msg.sender, address(this), battle.amount);

        battle.player2 = msg.sender;
        battle.isActive = true;

        emit BattleJoined(battleId, msg.sender);
    }

    function resolveBattle(uint256 battleId, address winner) external onlyOwner {
        Battle storage battle = battles[battleId];
        require(battle.isActive, "PvPBattle: battle not active");
        require(winner == battle.player1 || winner == battle.player2, "PvPBattle: invalid winner");

        uint256 totalAmount = battle.amount * 2;
        uint256 prizeAmount = (totalAmount * PRIZE_PERCENTAGE) / 100;
        uint256 seasonPoolAmount = (totalAmount * SEASON_POOL_PERCENTAGE) / 100;
        uint256 liquidityPoolAmount = (totalAmount * LIQUIDITY_POOL_PERCENTAGE) / 100;

        // Transfer prize to winner
        betToken.transfer(winner, prizeAmount);

        // Transfer fees to pools
        betToken.transfer(seasonRewardPool, seasonPoolAmount);
        betToken.transfer(liquidityPool, liquidityPoolAmount);

        emit BattleResolved(battleId, winner, prizeAmount);
        _deleteBattle(battleId);
    }

    function cancelBattle(uint256 battleId) external {
        Battle storage battle = battles[battleId];
        require(!battle.isActive, "PvPBattle: battle cannot be cancelled");
        require(msg.sender == battle.player1 || msg.sender == owner(), "PvPBattle: unauthorized");

        // Refund player1
        betToken.transfer(battle.player1, battle.amount);

        emit BattleCancelled(battleId);
        _deleteBattle(battleId);
    }

    function _deleteBattle(uint256 battleId) internal {
        uint256 lastIndex = battles.length - 1;
        if (battleId != lastIndex) {
            battles[battleId] = battles[lastIndex];
        }
        battles.pop();
    }
}
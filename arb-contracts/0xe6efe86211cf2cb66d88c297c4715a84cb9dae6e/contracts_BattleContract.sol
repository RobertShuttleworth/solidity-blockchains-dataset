// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract PvPBattle is Ownable {
    IERC20 public betToken;
    address public liquidityPool;
    address public seasonRewardPool;
    uint256 public minBetAmount;
    uint256 public maxBetAmount;

    enum BattleStatus { Created, Active, Archived }

    struct Battle {
        address player1;
        address player2;
        uint256 amount;
        BattleStatus status;
    }

    Battle[] public battles;

    event BattleCreated(uint256 battleId, address indexed player1, uint256 amount);
    event BattleJoined(uint256 battleId, address indexed player2, uint256 amount);
    event BattleResolved(uint256 battleId, address indexed winner, uint256 prizeAmount);
    event BattleCancelled(uint256 battleId);

    constructor(
        address _betToken,
        address _liquidityPool,
        address _seasonRewardPool
    ) {
        betToken = IERC20(_betToken);
        liquidityPool = _liquidityPool;
        seasonRewardPool = _seasonRewardPool;
    }

    function setMinBetAmount(uint256 amount) external onlyOwner {
        minBetAmount = amount;
    }

    function setMaxBetAmount(uint256 amount) external onlyOwner {
        maxBetAmount = amount;
    }

    function createBattle(uint256 amount) external {
        require(amount >= minBetAmount, "PvPBattle: bet below minimum");
        require(maxBetAmount == 0 || amount <= maxBetAmount, "PvPBattle: bet exceeds maximum");

        betToken.transferFrom(msg.sender, address(this), amount);

        battles.push(Battle({
            player1: msg.sender,
            player2: address(0),
            amount: amount,
            status: BattleStatus.Created
        }));

        emit BattleCreated(battles.length - 1, msg.sender, amount);
    }

    function joinBattle(uint256 battleId, uint256 amount) external {
        Battle storage battle = battles[battleId];
        require(battle.status == BattleStatus.Created, "PvPBattle: battle not joinable");
        require(amount == battle.amount, "PvPBattle: amount mismatch");

        betToken.transferFrom(msg.sender, address(this), amount);

        battle.player2 = msg.sender;
        battle.status = BattleStatus.Active;

        emit BattleJoined(battleId, msg.sender, amount);
    }

    function resolveBattle(uint256 battleId, address winner) external onlyOwner {
        Battle storage battle = battles[battleId];
        require(battle.status == BattleStatus.Active, "PvPBattle: battle not active");
        require(winner == battle.player1 || winner == battle.player2, "PvPBattle: invalid winner");

        uint256 totalAmount = battle.amount * 2;
        uint256 prizeAmount = (totalAmount * 80) / 100;
        uint256 seasonPoolAmount = (totalAmount * 10) / 100;
        uint256 liquidityPoolAmount = (totalAmount * 10) / 100;

        betToken.transfer(winner, prizeAmount);
        betToken.transfer(seasonRewardPool, seasonPoolAmount);
        betToken.transfer(liquidityPool, liquidityPoolAmount);

        battle.status = BattleStatus.Archived;

        emit BattleResolved(battleId, winner, prizeAmount);
    }


    function cancelBattle(uint256 battleId) external {
        Battle storage battle = battles[battleId];
        require(battle.status == BattleStatus.Created, "PvPBattle: battle not cancellable");
        require(msg.sender == battle.player1 || msg.sender == owner(), "PvPBattle: unauthorized");

        betToken.transfer(battle.player1, battle.amount);

        battle.status = BattleStatus.Archived;

        emit BattleCancelled(battleId);
    }
}
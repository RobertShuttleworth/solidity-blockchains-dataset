// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract TheDigitalColombianPeso {
    // Datos generales del token
    string public name = "The Digital Colombian Peso";
    string public symbol = "PESOS";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    // Variables de administración
    address public admin;
    address public maintenanceWallet;
    address public commissionWallet;
    address public goldWallet;

    // Mapa de saldos y permisos
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Mapas para bloqueo de fondos y wallets
    mapping(address => uint256) public blockedFunds;
    mapping(address => bool) public blacklistedWallets;

    // Configuración de intereses e incentivos
    uint256 public interestRate = 0; // Interés base (>= 0)
    uint256 public loyaltyBonusRate = 1; // 1% de bonificación por lealtad
    uint256 public incentiveRate = 2; // Incentivos por transacción (máximo 2%)

    // Configuración del sistema
    uint256 public transactionFee = 5; // 0.05% de comisión
    uint256 public totalCommission; // Comisiones acumuladas
    uint256 public gasReserve; // Reserva de gas
    uint256 public distributionRatio = 60; // Ratio de distribución en porcentaje (60% a intereses y 40% a incentivos)

    // Registro de usuarios y puntos de transacción
    address[] public users;
    mapping(address => uint256) public transactionPoints;
    mapping(address => uint256) public holdingPeriod;
    mapping(address => uint256) public interestToPay;
    mapping(address => uint256[52]) public weeklyBalanceSnapshots; // Registro de saldos semanales
    mapping(address => uint256) public totalTransactionVolume; // Registro del volumen total de transacciones

    // Eventos
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event InterestPaid(address indexed user, uint256 amount);
    event IncentivePaid(address indexed user, uint256 amount);
    event WalletBlocked(address indexed wallet);
    event WalletUnblocked(address indexed wallet);
    event FundsBlocked(address indexed user, uint256 amount);
    event FundsUnblocked(address indexed user, uint256 amount);

    // Frecuencia de pagos
    enum PaymentFrequency { ANNUAL, QUARTERLY, MONTHLY }
    PaymentFrequency public paymentFrequency = PaymentFrequency.ANNUAL;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    constructor(
        address _admin, 
        address _commissionWallet, 
        address _maintenanceWallet,
        address _goldWallet
    ) {
        admin = _admin;
        maintenanceWallet = _maintenanceWallet;
        commissionWallet = _commissionWallet;
        goldWallet = _goldWallet;
        totalSupply = 1000000000000000 * 10 ** uint256(decimals); // 1,000,000,000,000,000 PESOS
        balanceOf[admin] = totalSupply;
    }

    function setDistributionRatio(uint256 newRatio) public onlyAdmin {
        require(newRatio <= 100, "Ratio must be <= 100");
        distributionRatio = newRatio;
    }

    function setBaseInterestRate(uint256 newRate) public onlyAdmin {
        require(newRate >= 0, "Interest rate must be zero or positive");
        interestRate = newRate;
    }

    function blockWallet(address wallet) public onlyAdmin {
        require(wallet != admin, "Admin wallet cannot be blocked");
        blacklistedWallets[wallet] = true;
        emit WalletBlocked(wallet);
    }

    function unblockWallet(address wallet) public onlyAdmin {
        blacklistedWallets[wallet] = false;
        emit WalletUnblocked(wallet);
    }

    function blockFunds(address user, uint256 amount) public onlyAdmin {
        require(balanceOf[user] >= amount, "Insufficient balance to block");
        blockedFunds[user] += amount;
        balanceOf[user] -= amount;
        emit FundsBlocked(user, amount);
    }

    function unblockFunds(address user, uint256 amount) public onlyAdmin {
        require(blockedFunds[user] >= amount, "No such amount blocked");
        blockedFunds[user] -= amount;
        balanceOf[user] += amount;
        emit FundsUnblocked(user, amount);
    }

    function registerWeeklyBalance(address user) public {
        uint256 currentWeek = (block.timestamp / 1 weeks) % 52;
        weeklyBalanceSnapshots[user][currentWeek] = balanceOf[user];
    }

    function calculateAverageBalance(address user) internal view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < 52; i++) {
            sum += weeklyBalanceSnapshots[user][i];
        }
        return sum / 52;
    }

    function getDynamicLevel(address user) internal view returns (uint256) {
        uint256 userBalance = balanceOf[user];
        uint256 userTransactionVolume = totalTransactionVolume[user];

        if (userTransactionVolume >= 100000 * 10 ** decimals) {
            return 3;
        } else if (userBalance >= 500000 * 10 ** decimals) {
            return 2;
        } else {
            return 1;
        }
    }

    function calculateInterest(address user) internal view returns (uint256) {
        uint256 averageBalance = calculateAverageBalance(user);
        uint256 baseInterest = (averageBalance * interestRate) / 100;
        uint256 level = getDynamicLevel(user);

        if (level == 1) {
            return baseInterest + (baseInterest * loyaltyBonusRate) / 100;
        } else if (level == 2) {
            return (baseInterest * 66) / 100;
        } else {
            return (baseInterest * 16) / 100;
        }
    }

    function calculateIncentive(address user) internal view returns (uint256) {
        uint256 totalIncentivesAvailable = (totalCommission * 65) / 100;
        uint256 incentiveByPoints = (transactionPoints[user] * incentiveRate) / 100;
        uint256 maxIncentive = (totalTransactionVolume[user] * 1) / 100;

        uint256 finalIncentive = incentiveByPoints > maxIncentive ? maxIncentive : incentiveByPoints;
        return finalIncentive > totalIncentivesAvailable ? totalIncentivesAvailable : finalIncentive;
    }

    function transfer(address to, uint256 value) public returns (bool) {
        uint256 fee = (value * transactionFee) / 10000;
        uint256 totalAmount = value + fee;

        require(balanceOf[msg.sender] >= totalAmount, "Insufficient balance for transaction and fee");
        require(!blacklistedWallets[msg.sender], "Sender wallet is blocked");
        require(!blacklistedWallets[to], "Recipient wallet is blocked");

        uint256 commissionForInterest = (fee * 65) / 100;
        uint256 commissionForGold = (fee * 30) / 100;
        uint256 commissionForMaintenance = (fee * 5) / 100;

        balanceOf[msg.sender] -= totalAmount;
        balanceOf[to] += value;
        balanceOf[commissionWallet] += commissionForInterest;
        balanceOf[goldWallet] += commissionForGold;
        balanceOf[maintenanceWallet] += commissionForMaintenance;

        totalCommission += commissionForInterest;
        totalTransactionVolume[msg.sender] += value;
        totalTransactionVolume[to] += value;

        registerTransactionPoints(msg.sender, value);
        registerTransactionPoints(to, value);

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function registerTransactionPoints(address user, uint256 value) internal {
        transactionPoints[user] += value;
    }

    function distributeDynamicRewards() public onlyAdmin {
        uint256 totalCommissionFunds = balanceOf[commissionWallet];
        uint256 incentiveAndInterestPool = (totalCommissionFunds * 65) / 100;
        uint256 availableFundsForInterest = (incentiveAndInterestPool * distributionRatio) / 100;
        uint256 availableFundsForIncentives = incentiveAndInterestPool - availableFundsForInterest;

        uint256 totalInterestToPay = 0;
        uint256 totalIncentiveToPay = 0;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            totalInterestToPay += calculateInterest(user);
            totalIncentiveToPay += calculateIncentive(user);
        }

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 interest = calculateInterest(user);
            uint256 incentive = calculateIncentive(user);

            uint256 adjustedInterest = (interest * availableFundsForInterest) / totalInterestToPay;
            uint256 adjustedIncentive = (incentive * availableFundsForIncentives) / totalIncentiveToPay;

            balanceOf[user] += adjustedInterest + adjustedIncentive;
            emit InterestPaid(user, adjustedInterest);
            emit IncentivePaid(user, adjustedIncentive);
        }
    }

    function mint(address to, uint256 amount) public onlyAdmin {
        require(to != address(0), "Cannot mint to the zero address");
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) public onlyAdmin {
        require(from != address(0), "Cannot burn from the zero address");
        require(balanceOf[from] >= amount, "Insufficient balance to burn");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}
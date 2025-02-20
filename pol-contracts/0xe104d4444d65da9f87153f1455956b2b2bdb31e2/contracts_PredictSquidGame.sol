// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

/**
 * @title PredictionMarket_v2
 * @dev Контракт для создания предсказательных рынков с событиями, на которые пользователи могут делать ставки.
 */
contract PredictionMarket_v3 {
    using SafeERC20 for IERC20;

    enum Outcome { NO, YES } // Возможные исходы события

    struct Event {
        uint256 totalYes;             // Общая сумма ставок на YES
        uint256 totalNo;              // Общая сумма ставок на NO
        bool resolved;                // Флаг, что событие завершено
        bool paused;                  // Флаг, что событие приостановлено
        Outcome winningOutcome;       // Победный исход события
        mapping(address => uint256) yesBets; // Ставки пользователя на YES
        mapping(address => uint256) noBets;  // Ставки пользователя на NO
    }

    mapping(uint256 => Event) public events;  // Маппинг событий по ID
    address public owner;                     // Владелец контракта
    address public oracle;                    // Единый адрес оракула
    IERC20 public token;                      // Токен для ставок
    uint256 public feePercentage;             // Комиссия на вывод (в процентах, например, 2 = 2%)
    address public feeRecipient;              // Адрес получателя комиссии

    mapping(address => uint256[]) public userBets; // Отслеживание событий по пользователям

    // События
    event EventCreated(uint256 indexed eventId);
    event EventPaused(uint256 indexed eventId, bool isPaused);
    event BetPlaced(uint256 indexed eventId, address indexed user, Outcome outcome, uint256 amount);
    event EventResolved(uint256 indexed eventId, Outcome winningOutcome);
    event WinningsClaimed(uint256 indexed eventId, address indexed user, uint256 amount);
    event FeeRecipientUpdated(address indexed newFeeRecipient);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "Only oracle can call this function.");
        _;
    }

    constructor(address _token, uint256 _feePercentage, address _oracle, address _feeRecipient, address _owner) {
        require(_token != address(0), "Invalid token address.");
        require(_oracle != address(0), "Invalid oracle address.");
        require(_feeRecipient != address(0), "Invalid fee recipient address.");
        require(_feePercentage <= 100, "Fee must be between 0 and 100.");
        owner = _owner;
        token = IERC20(_token);
        feePercentage = _feePercentage;
        oracle = _oracle;
        feeRecipient = _feeRecipient;
    }

    /**
     * @notice Создание нового события.
     * @param eventId Уникальный ID события, задаваемый владельцем.
     */
    function createEvent(uint256 eventId) external onlyOwner {
        require(events[eventId].totalYes == 0 && events[eventId].totalNo == 0, "Event ID already exists.");
        emit EventCreated(eventId);
    }

    /**
     * @notice Включение или приостановка события.
     * @param eventId ID события.
     * @param isPaused True для приостановки, false для возобновления.
     */
    function setEventPaused(uint256 eventId, bool isPaused) external onlyOwner {
        Event storage evt = events[eventId];
        require(!evt.resolved, "Cannot pause resolved event.");
        evt.paused = isPaused;
        emit EventPaused(eventId, isPaused);
    }

    /**
     * @notice Сделать ставку на определенный исход события.
     * @param eventId ID события.
     * @param outcome Исход события: YES или NO.
     * @param amount Количество токенов для ставки.
     */
    function placeBet(uint256 eventId, Outcome outcome, uint256 amount) external {
        Event storage evt = events[eventId];
        require(!evt.resolved, "Event already resolved.");
        require(!evt.paused, "Event is paused.");
        require(amount > 0, "Amount must be greater than zero.");

        token.safeTransferFrom(msg.sender, address(this), amount);

        if (outcome == Outcome.YES) {
            evt.yesBets[msg.sender] += amount;
            evt.totalYes += amount;
        } else {
            evt.noBets[msg.sender] += amount;
            evt.totalNo += amount;
        }

        // Добавляем eventId в список пользователя, если это его первая ставка на событие
        if (evt.yesBets[msg.sender] == amount || evt.noBets[msg.sender] == amount) {
            userBets[msg.sender].push(eventId);
        }

        emit BetPlaced(eventId, msg.sender, outcome, amount);
    }

    /**
     * @notice Завершение события и определение победного исхода.
     * @param eventId ID события.
     * @param winningOutcome Победный исход: YES или NO.
     */
    function resolveEvent(uint256 eventId, Outcome winningOutcome) external onlyOracle {
        Event storage evt = events[eventId];
        require(!evt.resolved, "Event already resolved.");
        evt.winningOutcome = winningOutcome;
        evt.resolved = true;
        emit EventResolved(eventId, winningOutcome);
    }

    /**
     * @notice Получение выигрыша после завершения события.
     * @param eventId ID события.
     */
    function claimWinnings(uint256 eventId) external {
        Event storage evt = events[eventId];
        require(evt.resolved, "Event not yet resolved.");

        uint256 winnings = 0;

        if (evt.winningOutcome == Outcome.YES) {
            winnings = (evt.yesBets[msg.sender] * (evt.totalNo + evt.totalYes)) / evt.totalYes;
        } else if (evt.winningOutcome == Outcome.NO) {
            winnings = (evt.noBets[msg.sender] * (evt.totalNo + evt.totalYes)) / evt.totalNo;
        }

        require(winnings > 0, "No winnings to claim.");

        // Удержание комиссии
        uint256 fee = (winnings * feePercentage) / 100;
        uint256 payout = winnings - fee;

        // Очистка ставок
        evt.yesBets[msg.sender] = 0;
        evt.noBets[msg.sender] = 0;

        // Перевод выигрыша пользователю
        token.safeTransfer(msg.sender, payout);

        // Перевод комиссии на адрес feeRecipient
        if (fee > 0) {
            token.safeTransfer(feeRecipient, fee);
        }

        emit WinningsClaimed(eventId, msg.sender, payout);
    }

    /**
     * @notice Установить новый адрес получателя комиссии.
     * @param newFeeRecipient Адрес нового получателя комиссии.
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "Invalid fee recipient address.");
        feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(newFeeRecipient);
    }

    /**
     * @notice Получение списка событий, на которые делал ставки пользователь.
     * @param user Адрес пользователя.
     * @return Массив идентификаторов событий.
     */
    function getUserBets(address user) external view returns (uint256[] memory) {
        return userBets[user];
    }

    /**
     * @notice Изменение комиссии владельцем.
     * @param newFee Новый процент комиссии.
     */
    function setFeePercentage(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Fee must be between 0 and 100.");
        feePercentage = newFee;
    }

    /**
     * @notice Установить нового оракула.
     * @param newOracle Адрес нового оракула.
     */
    function setOracle(address newOracle) external onlyOwner {
        require(newOracle != address(0), "Invalid oracle address.");
        oracle = newOracle;
    }
}
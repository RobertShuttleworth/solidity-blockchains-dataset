// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_access_Ownable.sol';
import './contracts_IBurnable.sol';
import './contracts_IPaymentManager.sol';
import './contracts_IUniswapOracle.sol';
import './contracts_IQueueDistribution.sol';
import './uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol';
import './contracts_IUserBtc24h.sol';
import { Initializable } from './openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol';
import { OwnableUpgradeable } from './openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol';
import { UUPSUpgradeable } from './openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol';
import { ReentrancyGuardUpgradeable } from './openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol';
import './hardhat_console.sol';
library Donation {
    struct UserDonation {
        uint balance;
        uint startedTimestamp;
        uint totalClaimed;
        uint totalDonated;
        uint maxUnilevel;
        uint unilevelReached;
    }
}

contract DonationBtc24h is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IBurnable;
    using SafeERC20 for IERC20;

    event UserDonated(address indexed user, uint amount);
    event UserClaimed(address indexed user, uint amount);
    event Burn(uint indexed amount);

    uint24 public constant limitPeriod = 1 days;
    IUniswapOracle private uniswapOracle;
    IBurnable private token;

    IERC20 private constant wbtc =
        IERC20(0x1BFD67037B42Cf73acF2047067bd4F2C47D9BfD6);

    IERC20 private usdt;

    uint256 public distributionBalance;
    IPaymentManager private paymentManager;
    address public reservePool;
    IUserBtc24h private userBtc24h;
    IQueueDistribution private queueDistribution;

    uint256 public totalBurned;
    uint256 public totalDistributedForUsers;
    uint256 public totalForDevelopment;
    uint256 public totalPaidToUsers;
    uint public nextPoolFilling;

    mapping(address => Donation.UserDonation) private users;

    IERC20 private wsol;
    mapping(address => uint) public totalEarnedUsdt;
    mapping(address => uint) public totalEarnedToken;
    mapping(address => uint) public totalLostUsdt;
    mapping(address => uint) public totalLostToken;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _paymentManager,
        address oracle,
        address _token,
        address _user,
        address _reservePool,
        address _usdt
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        paymentManager = IPaymentManager(_paymentManager);
        uniswapOracle = IUniswapOracle(oracle);
        token = IBurnable(_token);
        userBtc24h = IUserBtc24h(_user);
        reservePool = _reservePool;
        usdt = IERC20(_usdt);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function setUniswapOracle(address oracle) external onlyOwner {
        uniswapOracle = IUniswapOracle(oracle);
    }

    function setPaymentManager(address _paymentManager) external onlyOwner {
        paymentManager = IPaymentManager(_paymentManager);
    }

    function addDistributionFunds(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        distributionBalance += amount;
    }
    function setWsol(address _wsol) external onlyOwner {
        wsol = IERC20(_wsol);
    }

    function setQueue(address _queue) external onlyOwner {
        queueDistribution = IQueueDistribution(_queue);
    }
    function setReservePool(address _reservePool) external onlyOwner {
        reservePool = _reservePool;
    }

    function timeUntilNextWithdrawal(
        address user
    ) public view returns (uint256) {
        Donation.UserDonation memory userDonation = users[user];
        uint256 timeElapsed = block.timestamp - userDonation.startedTimestamp;

        if (timeElapsed < limitPeriod) {
            return limitPeriod - timeElapsed;
        } else {
            return 0;
        }
    }

    function donate(uint128 amount, bool isUsdt) external nonReentrant {
        if (block.timestamp < 1735516800) {
            revert('Locked');
        }
        uint amountUsdt;
        if (isUsdt) {
            amountUsdt = amount;
            usdt.safeTransferFrom(msg.sender, address(this), amount);

            usdt.safeTransfer(reservePool, (amount * 25) / 1000);
            paymentManager.incrementBalance(
                (amount * 25) / 1000,
                address(usdt)
            );
            usdt.safeTransfer(address(paymentManager), (amount * 25) / 1000);
            amount = uint128(swapToken((amount * 75) / 100, true));
        } else {
            amountUsdt = uniswapOracle.returnPrice(amount);
        }

        require(
            amountUsdt >= 10 * 10 ** 6,
            'Amount must be greater than 10 dollars'
        );
        require(
            users[msg.sender].balance == 0,
            'Only one contribution is allowed'
        );

        uint newAmountUsdt = ((amount) * 4e5) / 1 ether;

        IUserBtc24h.UserStruct memory user = userBtc24h.getUser(tx.origin);

        if (!user.registered) {
            userBtc24h.createUser(owner());
        }

        users[msg.sender].balance = newAmountUsdt;
        users[msg.sender].totalDonated += newAmountUsdt;

        users[msg.sender].maxUnilevel = amount / 2;
        users[msg.sender].unilevelReached = 0;

        users[msg.sender].startedTimestamp = block.timestamp;
        if (!isUsdt) {
            token.safeTransferFrom(msg.sender, address(this), amount);
            nextPoolFilling += (amount * (95)) / 100;
            uint256 unilevelAmount = (amount * (5)) / 100;

            totalDistributedForUsers += unilevelAmount;
            distributeUnilevel(user, unilevelAmount);
        } else {
            nextPoolFilling += (amount * (30)) / 100;
            uint256 burnAmount = (amount * 15) / 100;
            uint256 queueAmount = (amount * 35) / 100;

            token.burn(burnAmount);
            totalBurned += burnAmount;
            distributeUnilevelUsdt(user, (amountUsdt * 20) / 100);
            token.safeTransfer(address(queueDistribution), queueAmount);
            queueDistribution.incrementBalance(amount / 20, 1);
            queueDistribution.incrementBalance(amount / 10, 2);
            queueDistribution.incrementBalance(amount / 5, 3);
            emit Burn(burnAmount);
        }

        emit UserDonated(msg.sender, amount);
    }

    function distributeUnilevel(
        IUserBtc24h.UserStruct memory user,
        uint amount
    ) internal {
        uint excess = ((40 - user.totalLevels) * amount) / 40;
        address[] memory levels = new address[](user.totalLevels);

        for (uint8 i = 0; i < user.totalLevels; i++) {
            levels[i] = getLevelAddress(user, i + 1);
        }

        for (uint8 i = 0; i < levels.length; i++) {
            if (isActive(levels[i])) {
                uint share = amount / 40;

                Donation.UserDonation storage userDonation = users[levels[i]];

                if (
                    userDonation.unilevelReached + share >
                    userDonation.maxUnilevel
                ) {
                    uint remaining = (
                        (userDonation.maxUnilevel -
                            userDonation.unilevelReached)
                    );

                    excess += (share - remaining);
                    totalLostToken[levels[i]] += (share - remaining);

                    share = remaining;

                    userDonation.unilevelReached += (userDonation.maxUnilevel -
                        userDonation.unilevelReached);
                } else {
                    userDonation.unilevelReached += (share);
                }
                totalEarnedToken[levels[i]] += share;

                token.safeTransfer(levels[i], share);
            } else {
                totalLostToken[levels[i]] += (amount) / 40;
                excess += (amount) / 40;
            }
        }

        if (excess > 0) {
            token.burn(excess);
        }
    }
    function distributeUnilevelUsdt(
        IUserBtc24h.UserStruct memory user,
        uint amount
    ) internal {
        uint excess = ((40 - user.totalLevels) * amount) / 40;
        address[] memory levels = new address[](user.totalLevels);

        for (uint8 i = 0; i < user.totalLevels; i++) {
            levels[i] = getLevelAddress(user, i + 1);
        }

        for (uint8 i = 0; i < levels.length; i++) {
            if (isActiveUsdt(levels[i])) {
                uint share = amount / 40;
                usdt.safeTransfer(levels[i], share);
                totalEarnedUsdt[levels[i]] += share;
            } else {
                totalLostUsdt[levels[i]] += (amount) / 40;
                excess += (amount) / 40;
            }
        }

        if (excess > 0) {
            paymentManager.incrementBalance(excess / 2, address(usdt));
            usdt.safeTransfer(address(paymentManager), excess / 2);
            usdt.safeTransfer(reservePool, (excess * 40) / 100);
            usdt.safeTransfer(
                0x906C34ee631B03dA9cc0712d47ECf13388c926c7,
                (excess * 5) / 100
            );
            usdt.safeTransfer(
                0xE5FbB27bD667Fbf0116Dc3c03bB5607c1f8130E1,
                (excess * 5) / 100
            );
        }
    }

    function isActive(address level) internal view returns (bool) {
        if (
            users[level].balance > 0 &&
            timeUntilNextWithdrawal(level) != 0 &&
            users[level].maxUnilevel - users[level].unilevelReached > 0
        ) {
            return true;
        }
        return false;
    }
    function isActiveUsdt(address level) internal view returns (bool) {
        if (users[level].balance > 0 && timeUntilNextWithdrawal(level) != 0) {
            return true;
        }
        return false;
    }

    function getLevelAddress(
        IUserBtc24h.UserStruct memory user,
        uint8 level
    ) internal pure returns (address) {
        if (level == 1) return user.level1;
        if (level == 2) return user.level2;
        if (level == 3) return user.level3;
        if (level == 4) return user.level4;
        if (level == 5) return user.level5;
        if (level == 6) return user.level6;
        if (level == 7) return user.level7;
        if (level == 8) return user.level8;
        if (level == 9) return user.level9;
        if (level == 10) return user.level10;
        if (level == 11) return user.level11;
        if (level == 12) return user.level12;
        if (level == 13) return user.level13;
        if (level == 14) return user.level14;
        if (level == 15) return user.level15;
        if (level == 16) return user.level16;
        if (level == 17) return user.level17;
        if (level == 18) return user.level18;
        if (level == 19) return user.level19;
        if (level == 20) return user.level20;
        if (level == 21) return user.level21;
        if (level == 22) return user.level22;
        if (level == 23) return user.level23;
        if (level == 24) return user.level24;
        if (level == 25) return user.level25;
        if (level == 26) return user.level26;
        if (level == 27) return user.level27;
        if (level == 28) return user.level28;
        if (level == 29) return user.level29;
        if (level == 30) return user.level30;
        if (level == 31) return user.level31;
        if (level == 32) return user.level32;
        if (level == 33) return user.level33;
        if (level == 34) return user.level34;
        if (level == 35) return user.level35;
        if (level == 36) return user.level36;
        if (level == 37) return user.level37;
        if (level == 38) return user.level38;
        if (level == 39) return user.level39;
        if (level == 40) return user.level40;
        revert('Invalid level');
    }

    function refillPool() external onlyOwner {
        distributionBalance += nextPoolFilling;
        nextPoolFilling = 0;
    }

    function start21h() external {}

    function claimDonation() external nonReentrant {
        Donation.UserDonation storage userDonation = users[msg.sender];
        uint timeElapsed = block.timestamp - userDonation.startedTimestamp;

        require(
            timeElapsed >= limitPeriod,
            'Tokens are still locked for 1 day'
        );

        uint totalValueInUSD = calculateTotalValue(msg.sender);
        uint currentPrice;
        if (block.timestamp < 1735516800) {
            currentPrice = uniswapOracle.returnPrice(1 ether);
        } else {
            currentPrice = 400000;
        }
        uint totalTokensToSend = (totalValueInUSD * 1e18) / currentPrice;
        uint maxTokens = 4 * userDonation.maxUnilevel;
        if (totalTokensToSend >= maxTokens) {
            totalTokensToSend = maxTokens;
        }

        require(
            distributionBalance >= totalTokensToSend,
            'Insufficient token balance for distribution'
        );

        distributionBalance -= totalTokensToSend;

        users[msg.sender].balance = 0;
        uint paymentManagerAmount;
        // uint userAmount;
        paymentManagerAmount = (totalTokensToSend * 75) / 10000;
        // userAmount = (totalTokensToSend - paymentManagerAmount);

        uint amountOut = swapToken(paymentManagerAmount, false);
        paymentManager.incrementBalance(amountOut / 2, address(wsol));

        wsol.safeTransfer(address(paymentManager), amountOut / 2);
        wsol.safeTransfer(reservePool, (amountOut * 40) / 100);
        wsol.safeTransfer(
            0x906C34ee631B03dA9cc0712d47ECf13388c926c7,
            (amountOut * 5) / 100
        );
        wsol.safeTransfer(
            0xE5FbB27bD667Fbf0116Dc3c03bB5607c1f8130E1,
            (amountOut * 5) / 100
        );

        totalForDevelopment += paymentManagerAmount;
        token.safeTransfer(msg.sender, totalTokensToSend); //userAmount
        totalPaidToUsers += totalTokensToSend; //userAmount

        userDonation.totalClaimed += totalValueInUSD;

        emit UserClaimed(msg.sender, totalTokensToSend);
    }

    function swapToken(
        uint amountIn,
        bool isBuy
    ) internal returns (uint amountOut) {
        if (isBuy) {
            usdt.approve(
                address(0xE592427A0AEce92De3Edee1F18E0157C05861564),
                amountIn
            );

            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: address(usdt),
                    tokenOut: address(token),
                    fee: 10000,
                    recipient: address(this),
                    deadline: block.timestamp + 20,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });

            amountOut = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564)
                .exactInputSingle(params);
        } else {
            token.approve(
                address(0xE592427A0AEce92De3Edee1F18E0157C05861564),
                amountIn
            );

            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: address(token),
                    tokenOut: address(wsol),
                    fee: 10000,
                    recipient: address(this),
                    deadline: block.timestamp + 20,
                    amountIn: amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });

            amountOut = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564)
                .exactInputSingle(params);
        }
    }

    function getUser(
        address _user
    ) external view returns (Donation.UserDonation memory) {
        Donation.UserDonation memory userDonation = users[_user];
        return userDonation;
    }

    function getUserUnilevelDonations(
        address _user
    ) external view returns (uint[] memory) {
        IUserBtc24h.UserStruct memory user = userBtc24h.getUser(_user);

        address[] memory levels = new address[](user.totalLevels);

        uint[] memory donations = new uint[](user.totalLevels);
        for (uint8 i = 0; i < levels.length; i++) {
            levels[i] = getLevelAddress(user, i + 1);
        }
        for (uint8 i = 0; i < levels.length; i++) {
            address levelAddress = getLevelAddress(user, i + 1);
            donations[i] = users[levelAddress].totalDonated;
        }
        return donations;
    }

    function previewTotalValue(
        address user
    ) external view returns (uint balance) {
        Donation.UserDonation memory userDonation = users[user];
        uint percentage = 5;

        balance =
            userDonation.balance +
            ((userDonation.balance * percentage) / 100);
    }

    function calculateTotalValue(
        address user
    ) internal view returns (uint balance) {
        Donation.UserDonation memory userDonation = users[user];

        balance = userDonation.balance + ((userDonation.balance * 5) / 100);
    }
}
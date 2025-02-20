// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_token_ERC20_IERC20.sol';
import './openzeppelin_contracts_utils_ReentrancyGuard.sol';
import './openzeppelin_contracts_access_Ownable.sol';
import './contracts_IUserAidMut.sol';
import './contracts_IUniswapAidMut.sol';
import './contracts_IBurnable.sol';

library Donation {
    struct UserDonation {
        uint balance;
        uint balanceClaimed;
        uint startedTimestamp;
        uint lastTimestamp;
        uint nonClaimed;
        uint timestampNonClaimed;
        bool hasVideo;
    }
    struct PoolPayment {
        uint16[20] levels;
        uint blockTime;
        uint blockTime2Video;
    }
}

contract DonationAidMut is ReentrancyGuard, Ownable {
    using SafeERC20 for IBurnable;

    event UserDonated(address indexed user, uint amount);
    event ChangedBot(address indexed user);
    event UserClaimed(address indexed user, uint amount);

    IUserAidMut public immutable userAidMut;
    uint24 public constant limitPeriod = 5 minutes;
    uint24 public constant limitPeriodMaxClaim = 1 days;

    IUniswapAidMut public uniswapOracle =
        IUniswapAidMut(0x4E18321254F88b2adE21884ca33cA2c129B4F6e6);
    uint public maxClaim = 100000000000e6;

    Donation.PoolPayment public poolPayments =
        Donation.PoolPayment(
            [
                800,
                400,
                200,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                100,
                100
            ],
            2500,
            3500
        );
    IBurnable private immutable token;
    address walletBot = 0x5Dddf31bA5e84170981A14F2acA6654878eB7568;
    mapping(address => mapping(uint => Donation.UserDonation)) private users;
    mapping(address => uint) public nonceTotalDonations;
    mapping(address => uint) public totalDonated;
    mapping(address => uint) private lastUnclaimed;

    mapping(address => uint[20]) private totalInvestment;

    bool public toOldContract;
    address public oldContract = 0x362cc2965e374365D348eeB0A3Ad296cb5Ee19Ec;

    constructor(address initialUser, address _owner) Ownable(_owner) {
        token = IBurnable(0xe4FeAb21b42919C5C960ed2B4BdFFc521E26881f);
        userAidMut = IUserAidMut(initialUser);
    }

    modifier onlyBot() {
        require(msg.sender == walletBot, 'Only bot can call this function');
        _;
    }

    function getTotalInvestment(
        address owner
    ) external view returns (uint[20] memory investments) {
        return totalInvestment[owner];
    }

    function changeMaxClaim(uint newValue) external onlyBot {
        maxClaim = newValue * 1e6;
    }
    function changeContractAddress(address _newAddress) external onlyOwner {
        oldContract = _newAddress;
    }

    function withdrawTokens() external {
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    function setWalletBot(address _address) external onlyOwner {
        walletBot = _address;
        emit ChangedBot(_address);
    }
    function setUniswapOracle(address _address) external onlyOwner {
        uniswapOracle = IUniswapAidMut(_address);
    }

    function addVideo(address user, uint index) external onlyBot {
        users[user][index].hasVideo = true;
    }

    function removeVideo(address user, uint index) external onlyBot {
        users[user][index].hasVideo = false;
    }

    function setToOldContract(bool flag) external onlyBot {
        toOldContract = flag;
    }
    function getDonationsBelowCap(
        address user
    ) external view returns (Donation.UserDonation[] memory) {
        uint donationCount = nonceTotalDonations[user];
        uint count = 0;

        for (uint i = 1; i <= donationCount; i++) {
            if (users[user][i].balanceClaimed < users[user][i].balance * 3) {
                count++;
            }
        }

        Donation.UserDonation[] memory belowCap = new Donation.UserDonation[](
            count
        );
        uint index = 0;
        for (uint i = 1; i <= donationCount; i++) {
            if (users[user][i].balanceClaimed < users[user][i].balance * 3) {
                belowCap[index] = users[user][i];
                index++;
            }
        }
        return belowCap;
    }

    function timeUntilNextWithdrawal(
        address user,
        uint index
    ) external view returns (uint256) {
        if (users[user][index].nonClaimed > 0) {
            if (users[user][index].timestampNonClaimed > block.timestamp) {
                return users[user][index].timestampNonClaimed - block.timestamp;
            } else {
                return 0;
            }
        } else {
            uint256 timeElapsed = block.timestamp -
                users[user][index].lastTimestamp;

            if (timeElapsed < limitPeriod) {
                return limitPeriod - timeElapsed;
            } else {
                return 0;
            }
        }
    }

    function getLastUnclaimed(address user) public view returns (uint) {
        uint startIndex = lastUnclaimed[user] != 0 ? lastUnclaimed[user] : 1;

        for (uint i = startIndex; i <= nonceTotalDonations[user]; i++) {
            if (3 * users[user][i].balance > users[user][i].balanceClaimed) {
                return i;
            }
        }
        return 0;
    }

    function donate(uint128 amount) external nonReentrant {
        require(!userAidMut.isBlacklisted(msg.sender), 'Blacklisted');
        IUserAidMut.UserStruct memory userStruct = userAidMut.getUser(
            msg.sender
        );

        require(userStruct.registered, 'Unregistered user');

        uint amountUsdt = uniswapOracle.estimateAmountOut(amount) / 1e12;

        require(
            amountUsdt >= 10e6 && amountUsdt <= 10000e6,
            'Amount must be between 10 and 10,000 dollars'
        );

        ++nonceTotalDonations[msg.sender];
        totalDonated[msg.sender] += amountUsdt;
        uint nonce = nonceTotalDonations[msg.sender];
        users[msg.sender][nonce].balance = amountUsdt;
        users[msg.sender][nonce].startedTimestamp = block.timestamp;
        users[msg.sender][nonce].lastTimestamp = block.timestamp;
        users[msg.sender][nonce].hasVideo = false;

        lastUnclaimed[msg.sender] = getLastUnclaimed(msg.sender);

        recursiveIncrement(userStruct, amountUsdt);
        uniLevelDistribution(amount, userStruct);

        token.safeTransferFrom(msg.sender, address(this), amount);
        if (toOldContract) {
            token.safeTransfer(oldContract, (amount * 20) / 100);
        }

        emit UserDonated(msg.sender, amount);
    }

    function uniLevelDistribution(
        uint amount,
        IUserAidMut.UserStruct memory user
    ) internal {
        address[20] memory levels = [
            user.level1,
            user.level2,
            user.level3,
            user.level4,
            user.level5,
            user.level6,
            user.level7,
            user.level8,
            user.level9,
            user.level10,
            user.level11,
            user.level12,
            user.level13,
            user.level14,
            user.level15,
            user.level16,
            user.level17,
            user.level18,
            user.level19,
            user.level20
        ];
        uint16[20] memory percentages = [
            poolPayments.levels[0],
            poolPayments.levels[1],
            poolPayments.levels[2],
            poolPayments.levels[3],
            poolPayments.levels[4],
            poolPayments.levels[5],
            poolPayments.levels[6],
            poolPayments.levels[7],
            poolPayments.levels[8],
            poolPayments.levels[9],
            poolPayments.levels[10],
            poolPayments.levels[11],
            poolPayments.levels[12],
            poolPayments.levels[13],
            poolPayments.levels[14],
            poolPayments.levels[15],
            poolPayments.levels[16],
            poolPayments.levels[17],
            poolPayments.levels[18],
            poolPayments.levels[19]
        ];
        uint price = uniswapOracle.estimateAmountOut(1 ether) / 1e12;

        if (
            hasActiveDonation(levels[0]) || userAidMut.isWhitelisted(levels[0])
        ) {
            uint value = (amount * percentages[0]) / 10000;
            if (userAidMut.isWhitelisted(levels[0])) {
                token.safeTransfer(levels[0], value);
            } else {
                uint valueUsd = (value * price) / 1 ether;
                for (
                    uint i = getLastUnclaimed(levels[0]);
                    i <= nonceTotalDonations[levels[0]];
                    i++
                ) {
                    if (i == 0) {
                        break;
                    }
                    if (
                        users[levels[0]][i].balance * 3 >=
                        valueUsd + users[levels[0]][i].balanceClaimed
                    ) {
                        users[levels[0]][i].balanceClaimed += valueUsd;
                        token.safeTransfer(levels[0], value);
                        break;
                    } else {
                        uint newValueUsd = (users[levels[0]][i].balance * 3) -
                            users[levels[0]][i].balanceClaimed;
                        uint proportionalValue = (newValueUsd * value) /
                            valueUsd;

                        users[levels[0]][i].balanceClaimed += newValueUsd;

                        token.safeTransfer(levels[0], proportionalValue);

                        valueUsd -= newValueUsd;
                        value -= proportionalValue;

                        if (valueUsd == 0) {
                            break;
                        }
                    }
                }
            }
        }
        for (uint i = 1; i < levels.length; i++) {
            if (levels[i] == address(0)) {
                break;
            }

            if (
                (hasActiveDonation(levels[i]) &&
                    totalInvestment[levels[i]][i] >= 500e6) ||
                userAidMut.isWhitelisted(levels[i])
            ) {
                uint value = (amount * percentages[i]) / 10000;
                if (userAidMut.isWhitelisted(levels[i])) {
                    token.safeTransfer(levels[i], value);
                    continue;
                }

                uint valueUsd = (value * price) / 1 ether;
                for (
                    uint j = getLastUnclaimed(levels[i]);
                    j <= nonceTotalDonations[levels[i]];
                    j++
                ) {
                    if (i == 0) {
                        break;
                    }
                    if (
                        users[levels[i]][j].balance * 3 >=
                        valueUsd + users[levels[i]][j].balanceClaimed
                    ) {
                        users[levels[i]][j].balanceClaimed += valueUsd;
                        token.safeTransfer(levels[i], value);
                        break;
                    } else {
                        uint newValueUsd = (users[levels[i]][j].balance * 3) -
                            users[levels[i]][j].balanceClaimed;
                        uint proportionalValue = (newValueUsd * value) /
                            valueUsd;

                        users[levels[i]][j].balanceClaimed += newValueUsd;

                        token.safeTransfer(levels[i], proportionalValue);

                        valueUsd -= newValueUsd;
                        value -= proportionalValue;

                        if (valueUsd == 0) {
                            break;
                        }
                    }
                }
            }
        }
    }

    function hasActiveDonation(address user) internal view returns (bool) {
        if (getLastUnclaimed(user) != 0) {
            return true;
        } else {
            return false;
        }
    }

    function recursiveIncrement(
        IUserAidMut.UserStruct memory user,
        uint amount
    ) internal {
        address[20] memory levels = [
            user.level1,
            user.level2,
            user.level3,
            user.level4,
            user.level5,
            user.level6,
            user.level7,
            user.level8,
            user.level9,
            user.level10,
            user.level11,
            user.level12,
            user.level13,
            user.level14,
            user.level15,
            user.level16,
            user.level17,
            user.level18,
            user.level19,
            user.level20
        ];

        for (uint i = 0; i < 20; i++) {
            if (levels[i] != address(0)) {
                totalInvestment[levels[i]][i] += amount;
            } else {
                return;
            }
        }
    }

    function claimDonation(uint index) external nonReentrant {
        require(!userAidMut.isBlacklisted(msg.sender), 'Blacklisted');

        uint maxValue = users[msg.sender][index].balance * 3;
        require(
            users[msg.sender][index].balanceClaimed < maxValue,
            'Donation already claimed'
        );
        uint totalValue;
        if (users[msg.sender][index].nonClaimed > 0) {
            require(
                block.timestamp > users[msg.sender][index].timestampNonClaimed,
                'Tokens are still locked'
            );
            totalValue = users[msg.sender][index].nonClaimed;

            if (totalValue < maxClaim) {
                users[msg.sender][index].nonClaimed = 0;
            }
            if (
                totalValue + users[msg.sender][index].balanceClaimed >
                users[msg.sender][index].balance * 3
            ) {
                totalValue =
                    users[msg.sender][index].balance *
                    3 -
                    users[msg.sender][index].balanceClaimed;
                users[msg.sender][index].nonClaimed -= totalValue;
            }
        } else {
            totalValue = calculateTotalValueToClaim(msg.sender, index);
            uint monthsElapsed = (block.timestamp -
                users[msg.sender][index].lastTimestamp) / limitPeriod;
            require(monthsElapsed > 0, 'Tokens are still locked');
            if (monthsElapsed > 12) {
                monthsElapsed = 12;
            }
            totalValue = totalValue * monthsElapsed;
            if (
                totalValue > maxValue - users[msg.sender][index].balanceClaimed
            ) {
                totalValue = maxValue - users[msg.sender][index].balanceClaimed;
            }
            users[msg.sender][index].lastTimestamp += (limitPeriod *
                monthsElapsed);
        }
        if (totalValue >= maxClaim) {
            users[msg.sender][index].nonClaimed = totalValue - maxClaim;
            users[msg.sender][index].timestampNonClaimed =
                block.timestamp +
                limitPeriodMaxClaim;
            totalValue = maxClaim;
        }

        if (users[msg.sender][index].balanceClaimed + totalValue > maxValue) {
            totalValue = maxValue - users[msg.sender][index].balanceClaimed;
            users[msg.sender][index].balanceClaimed = maxValue;
        } else {
            users[msg.sender][index].balanceClaimed += totalValue;
        }

        uint tokenPrice = uniswapOracle.estimateAmountOut(1 ether) / 1e12;
        uint quantityToken = (totalValue * 1 ether) / tokenPrice;
        token.safeTransfer(msg.sender, (quantityToken * 98) / 100);
        if (toOldContract) {
            token.safeTransfer(oldContract, (quantityToken * 2) / 100);
        } else {
            token.burn((quantityToken * 2) / 100);
        }
        emit UserClaimed(msg.sender, quantityToken);
    }

    function getUser(
        address _user,
        uint index
    ) external view returns (Donation.UserDonation memory) {
        Donation.UserDonation memory userDonation = users[_user][index];
        return userDonation;
    }

    function calculateTotalValueToClaim(
        address user,
        uint donationIndex
    ) public view returns (uint balance) {
        uint multiplier;

        if (users[user][donationIndex].hasVideo) {
            multiplier = poolPayments.blockTime2Video;
        } else {
            multiplier = poolPayments.blockTime;
        }

        return (users[user][donationIndex].balance * multiplier) / 10000;
    }
}
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_IERC20MetadataUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol";
import "./uniswap_v3-periphery_contracts_interfaces_IQuoter.sol";

import "./contracts_interfaces_ISeniorVault.sol";
import "./contracts_interfaces_IJuniorVault.sol";
import "./contracts_interfaces_IRewardDistributor.sol";
import "./contracts_interfaces_chainlink_IPriceFeed.sol";

contract RewardController is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 constant YEAR = 365 * 86400;
    uint256 constant ONE = 1e18;
    uint256 constant ORACLE_PRICE_EXPIRATION = 30 * 3600;

    address public rewardToken;
    IRewardDistributor public seniorRewardDistributor;
    IRewardDistributor public juniorRewardDistributor;

    uint256 public minSeniorApy;
    uint256 public maxSeniorApy;
    uint256 public seniorRewardRate;
    uint256 public lastNotifyTime;

    ISwapRouter public uniswapRouter;
    IQuoter public uniswapQuoter;
    mapping(address => bytes[]) internal swapPaths;

    mapping(address => bool) public isHandler;

    uint256 public lastSeniorExtraNotifyTime;
    uint256 public lastJuniorExtraNotifyTime;

    struct SlippageConfigData {
        address oracle;
        uint256 decimals;
        uint256 slippage;
        bool enableSlippage;
    }
    mapping(address => SlippageConfigData) public slippageConfigs;

    address constant McbToken = 0x4e352cF164E64ADCBad318C3a1e222E9EBa4Ce42;

    IRewardDistributor public seniorMcbRewardDistributor;
    IRewardDistributor public juniorMcbRewardDistributor;

    event DistributeReward(address indexed receiver, uint256 amount, uint256 timespan);
    event DistributeMcbReward(address indexed receiver, uint256 amount, uint256 timespan);
    event SetHandler(address indexed handler, bool enable);
    event SetMinStableApy(uint256 prevMinApy, uint256 newMinApy);
    event SetMaxStableApy(uint256 prevMaxApy, uint256 newMaxApy);
    event SetSeniorRewardRate(uint256 prevRation, uint256 newRation);
    event SetInitialTime(uint256 prevTime, uint256 newTime);
    event SetUniswapContracts(address uniswapRouter, address uniswapQuoter);
    event SetSwapPaths(address rewardToken, bytes[] paths);
    event SetDefaultSlippage(uint256 slippage);
    event SetSlippage(address token, SlippageConfigData slippageConfig);
    event SetMcbRewardDistributor(
        address seniorMcbRewardDistributor_,
        address juniorMcbRewardDistributor_
    );

    modifier onlyHandler() {
        require(isHandler[msg.sender], "RewardController::HANDLER_ONLY");
        _;
    }

    function initialize(
        address rewardToken_,
        address seniorRewardDistributor_,
        address juniorRewardDistributor_,
        uint256 seniorRewardRate_,
        uint256 minSeniorApy_
    ) external initializer {
        __Ownable_init();

        rewardToken = rewardToken_;
        seniorRewardDistributor = IRewardDistributor(seniorRewardDistributor_);
        juniorRewardDistributor = IRewardDistributor(juniorRewardDistributor_);
        seniorRewardRate = seniorRewardRate_;
        minSeniorApy = minSeniorApy_;
    }

    function setHandler(address handler_, bool enable_) external onlyOwner {
        isHandler[handler_] = enable_;
        emit SetHandler(handler_, enable_);
    }

    function setMinStableApy(uint256 newMinApy) external onlyOwner {
        require(newMinApy <= ONE, "RewardController::INVALID_APY");
        emit SetMinStableApy(minSeniorApy, newMinApy);
        minSeniorApy = newMinApy;
    }

    function setMaxStableApy(uint256 newMaxApy) external onlyOwner {
        require(newMaxApy <= ONE, "RewardController::INVALID_APY");
        require(newMaxApy >= minSeniorApy || newMaxApy == 0, "RewardController::INVALID_APY");
        emit SetMaxStableApy(maxSeniorApy, newMaxApy);
        maxSeniorApy = newMaxApy;
    }

    function setSeniorRewardRate(uint256 newRation) external onlyOwner {
        emit SetSeniorRewardRate(seniorRewardRate, newRation);
        seniorRewardRate = newRation;
    }

    function setInitialTime() external onlyOwner {
        emit SetInitialTime(lastNotifyTime, block.timestamp);
        lastNotifyTime = block.timestamp;
    }

    function setUniswapContracts(
        address uniswapRouter_,
        address uniswapQuoter_
    ) external onlyOwner {
        uniswapRouter = ISwapRouter(uniswapRouter_);
        uniswapQuoter = IQuoter(uniswapQuoter_);
        emit SetUniswapContracts(uniswapRouter_, uniswapQuoter_);
    }

    function setSwapPaths(address rewardToken_, bytes[] memory paths) external onlyOwner {
        swapPaths[rewardToken_] = paths;
        emit SetSwapPaths(rewardToken_, paths);
    }

    function setMcbRewardDistributor(
        address seniorMcbRewardDistributor_,
        address juniorMcbRewardDistributor_
    ) external onlyOwner {
        seniorMcbRewardDistributor = IRewardDistributor(seniorMcbRewardDistributor_);
        juniorMcbRewardDistributor = IRewardDistributor(juniorMcbRewardDistributor_);
        emit SetMcbRewardDistributor(seniorMcbRewardDistributor_, juniorMcbRewardDistributor_);
    }

    function setSlippageConfig(
        address token,
        address oracle,
        uint256 decimals,
        uint256 slippage,
        bool enableSlippage
    ) external onlyOwner {
        require(slippage <= ONE, "RewardController::INVALID_SLIPPAGE");
        require(decimals <= 18, "RewardController::INVALID_DECIMALS");
        slippageConfigs[token] = SlippageConfigData(oracle, decimals, slippage, enableSlippage);
        emit SetSlippage(token, slippageConfigs[token]);
    }

    function calculateRewardDistribution(
        uint256 utilizedAmount,
        uint256 rewardAmount,
        uint256 timespan
    ) public view returns (uint256 seniorRewards, uint256 juniorRewards) {
        // noborrow
        if (utilizedAmount == 0) {
            seniorRewards = 0;
            juniorRewards = rewardAmount;
        } else {
            // split rewards
            // | ----------------- | ----------------- | ----------------- |
            // 0               minStable            maxStable             total
            //      => stable            stable * ratio        stable - max
            uint256 minSeniorRewards = (((utilizedAmount * minSeniorApy) / ONE) * timespan) / YEAR;
            seniorRewards = (rewardAmount * seniorRewardRate) / ONE;
            juniorRewards = 0;

            // if minSeniorApy applied
            if (minSeniorApy > 0) {
                if (rewardAmount <= minSeniorRewards) {
                    seniorRewards = rewardAmount;
                    juniorRewards = 0;
                } else {
                    //  max(minSeniorApy * utilizedAmount * timespan / 365, rewardAmount * seniorRewardRate)
                    if (seniorRewards < minSeniorRewards) {
                        seniorRewards = minSeniorRewards;
                    }
                    juniorRewards = rewardAmount - seniorRewards;
                }
            }
            if (maxSeniorApy > 0) {
                // if maxSeniorApy applied
                // min(maxSeniorApy * utilizedAmount * timespan / 365, rewardAmount * seniorRewardRate)
                uint256 maxSeniorRewards = (((utilizedAmount * maxSeniorApy) / ONE) * timespan) /
                    YEAR;
                if (seniorRewards > maxSeniorRewards) {
                    seniorRewards = maxSeniorRewards;
                    juniorRewards = rewardAmount - seniorRewards;
                }
            }
        }
    }

    // Get claimable rewards for senior/junior. Should call RouterV1.updateRewards() first to collected all rewards.
    function claimableJuniorRewards(address account) external returns (uint256) {
        return juniorRewardDistributor.claimable(account);
    }

    function claimableJuniorMcbRewards(address account) external returns (uint256) {
        if (address(juniorMcbRewardDistributor) == address(0)) {
            return 0;
        }
        return juniorMcbRewardDistributor.claimable(account);
    }

    function claimableSeniorRewards(address account) external returns (uint256) {
        return seniorRewardDistributor.claimable(account);
    }

    function claimableSeniorMcbRewards(address account) external returns (uint256) {
        if (address(seniorMcbRewardDistributor) == address(0)) {
            return 0;
        }
        return seniorMcbRewardDistributor.claimable(account);
    }

    // Claim rewards for senior/junior. Should call RouterV1.updateRewards() first to collected all rewards.
    function claimJuniorRewardsFor(
        address account,
        address receiver
    ) external onlyHandler returns (uint256) {
        return juniorRewardDistributor.claimFor(account, receiver);
    }

    function claimJuniorMcbRewardsFor(
        address account,
        address receiver
    ) external onlyHandler returns (uint256) {
        if (address(juniorMcbRewardDistributor) == address(0)) {
            return 0;
        }
        return juniorMcbRewardDistributor.claimFor(account, receiver);
    }

    function claimSeniorRewardsFor(
        address account,
        address receiver
    ) external onlyHandler returns (uint256) {
        return seniorRewardDistributor.claimFor(account, receiver);
    }

    function claimSeniorMcbRewardsFor(
        address account,
        address receiver
    ) external onlyHandler returns (uint256) {
        if (address(seniorMcbRewardDistributor) == address(0)) {
            return 0;
        }
        return seniorMcbRewardDistributor.claimFor(account, receiver);
    }

    function updateRewards(address account) external {
        seniorRewardDistributor.updateRewards(account);
        juniorRewardDistributor.updateRewards(account);
        seniorMcbRewardDistributor.updateRewards(account);
        juniorMcbRewardDistributor.updateRewards(account);
    }

    function migrateSeniorRewardFor(address from, address to) external onlyHandler {
        seniorRewardDistributor.migrate(from, to);
        seniorMcbRewardDistributor.migrate(from, to);
    }

    function migrateJuniorRewardFor(address from, address to) external onlyHandler {
        juniorRewardDistributor.migrate(from, to);
        juniorMcbRewardDistributor.migrate(from, to);
    }

    function notifyRewards(
        address[] memory rewardTokens,
        uint256[] memory rewardAmounts,
        uint256 utilizedAmount
    ) external onlyHandler {
        require(rewardTokens.length == rewardAmounts.length, "RewardController::BAD_PARAMS");
        uint256 rewardAmount;
        uint256 mcbAmount;
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] == McbToken) {
                mcbAmount += rewardAmounts[i];
                continue;
            }
            if (rewardTokens[i] == rewardToken) {
                rewardAmount += rewardAmounts[i];
            } else {
                // get price
                uint256 minOut = _getReferenceTokenMinOut(rewardTokens[i], rewardAmounts[i]);
                minOut = _toDecimals(rewardTokens[i], rewardToken, minOut);
                rewardAmount += _swapToken(rewardTokens[i], rewardAmounts[i], minOut);
            }
        }
        uint256 mcbBalance = IERC20Upgradeable(McbToken).balanceOf(address(this));
        require(mcbBalance >= mcbAmount, "InsufficientMcb");
        mcbAmount = mcbBalance
        ;
        uint256 balance = IERC20Upgradeable(rewardToken).balanceOf(address(this));
        require(balance >= rewardAmount, "RewardController::INSUFFICIENT_BALANCE");
        rewardAmount = balance;

        uint256 timespan = block.timestamp - lastNotifyTime;
        lastNotifyTime = block.timestamp;

        (uint256 seniorRewards, uint256 juniorRewards) = calculateRewardDistribution(
            utilizedAmount,
            rewardAmount,
            timespan
        );
        if (seniorRewards > 0) {
            IERC20Upgradeable(rewardToken).safeTransfer(
                address(seniorRewardDistributor),
                seniorRewards
            );
            emit DistributeReward(address(seniorRewardDistributor), seniorRewards, timespan);
            if (mcbAmount > 0 && address(seniorMcbRewardDistributor) != address(0)) {
                uint256 toSeniorMcbAmount = (mcbAmount * seniorRewards) /
                    (seniorRewards + juniorRewards);
                IERC20Upgradeable(McbToken).safeTransfer(
                    address(seniorMcbRewardDistributor),
                    toSeniorMcbAmount
                );
                emit DistributeMcbReward(
                    address(seniorMcbRewardDistributor),
                    toSeniorMcbAmount,
                    timespan
                );
            }
        }
        if (juniorRewards > 0) {
            IERC20Upgradeable(rewardToken).safeTransfer(
                address(juniorRewardDistributor),
                juniorRewards
            );
            emit DistributeReward(address(juniorRewardDistributor), juniorRewards, timespan);
            if (mcbAmount > 0 && address(juniorMcbRewardDistributor) != address(0)) {
                uint256 toJuniorMcbAmount = mcbAmount -
                    ((mcbAmount * seniorRewards) / (seniorRewards + juniorRewards));
                IERC20Upgradeable(McbToken).safeTransfer(
                    address(juniorMcbRewardDistributor),
                    toJuniorMcbAmount
                );
                emit DistributeReward(
                    address(juniorMcbRewardDistributor),
                    toJuniorMcbAmount,
                    timespan
                );
            }
        }
    }

    function notifySeniorExtraReward(address token, uint256 amount) external onlyHandler {
        require(token != McbToken, "RewardController::CANNOT_NOTIFY_MCB");
        uint256 rewardAmount;
        if (token == rewardToken) {
            rewardAmount = amount;
        } else {
            uint256 minOut = _getReferenceTokenMinOut(token, amount);
            minOut = _toDecimals(token, rewardToken, minOut);
            rewardAmount = _swapToken(token, amount, minOut);
        }
        uint256 balance = IERC20Upgradeable(rewardToken).balanceOf(address(this));
        require(balance >= rewardAmount, "RewardController::INSUFFICIENT_BALANCE");
        if (rewardAmount > 0) {
            uint256 timespan = block.timestamp - lastSeniorExtraNotifyTime;
            lastSeniorExtraNotifyTime = block.timestamp;
            IERC20Upgradeable(rewardToken).safeTransfer(
                address(seniorRewardDistributor),
                rewardAmount
            );
            emit DistributeReward(address(seniorRewardDistributor), rewardAmount, timespan);
        }
    }

    function notifyJuniorExtraReward(address token, uint256 amount) external onlyHandler {
        require(token != McbToken, "RewardController::CANNOT_NOTIFY_MCB");
        uint256 rewardAmount;
        if (token == rewardToken) {
            rewardAmount = amount;
        } else {
            uint256 minOut = _getReferenceTokenMinOut(token, amount);
            minOut = _toDecimals(token, rewardToken, minOut);
            rewardAmount = _swapToken(token, amount, minOut);
        }
        uint256 balance = IERC20Upgradeable(rewardToken).balanceOf(address(this));
        require(balance >= rewardAmount, "RewardController::INSUFFICIENT_BALANCE");
        if (rewardAmount > 0) {
            uint256 timespan = block.timestamp - lastJuniorExtraNotifyTime;
            lastJuniorExtraNotifyTime = block.timestamp;
            IERC20Upgradeable(rewardToken).safeTransfer(
                address(juniorRewardDistributor),
                rewardAmount
            );
            emit DistributeReward(address(juniorRewardDistributor), rewardAmount, timespan);
        }
    }

    function _swapToken(
        address token,
        uint256 amount,
        uint256 minOut
    ) internal returns (uint256 outAmount) {
        bytes[] storage candidates = swapPaths[token];
        require(candidates.length > 0, "RewardController::NO_CANDIDATES");
        if (amount == 0) {
            outAmount = 0;
        } else {
            (uint256 index, uint256 expectOutAmount) = _evaluateOutAmount(candidates, amount);
            outAmount = _swap(candidates[index], token, amount, expectOutAmount);
        }
        require(outAmount >= minOut, "RewardController::INSUFFICIENT_OUT_AMOUNT");
    }

    function _evaluateOutAmount(
        bytes[] memory paths,
        uint256 amountIn
    ) internal returns (uint256 bestPathIndex, uint256 bestOutAmount) {
        require(address(uniswapQuoter) != address(0), "RewardController::UNISWAP_QUOTER_NOT_SET");
        for (uint256 i = 0; i < paths.length; i++) {
            uint256 outAmount = uniswapQuoter.quoteExactInput(paths[i], amountIn);
            if (outAmount > bestOutAmount) {
                bestPathIndex = i;
                bestOutAmount = outAmount;
            }
        }
    }

    function _swap(
        bytes memory path,
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) internal returns (uint256 outAmount) {
        require(amountIn > 0, "RewardController::INVALID_AMOUNT_IN");
        require(address(uniswapRouter) != address(0), "RewardController::UNISWAP_ROUTER_NOT_SET");
        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut
        });
        IERC20Upgradeable(tokenIn).approve(address(uniswapRouter), amountIn);
        outAmount = uniswapRouter.exactInput(params);
    }

    function _getReferenceTokenMinOut(
        address token,
        uint256 amount
    ) internal view returns (uint256) {
        SlippageConfigData memory config = slippageConfigs[token];
        if (!config.enableSlippage) {
            return 0;
        }
        require(config.oracle != address(0), "RewardController::NO_ORACLE_SET");
        (, int256 price, , uint256 timestamp, ) = IPriceFeed(config.oracle).latestRoundData();
        require(price > 0, "RewardController::INVALID_PRICE");
        require(
            timestamp + ORACLE_PRICE_EXPIRATION > block.timestamp,
            "RewardController::PRICE_EXPIRED"
        );
        return
            (((amount * uint256(price)) / 10 ** config.decimals) * (ONE - config.slippage)) / ONE;
    }

    function _toDecimals(
        address tokenFrom,
        address tokenTo,
        uint256 amountFrom
    ) internal view returns (uint256) {
        if (tokenFrom == tokenTo) {
            return amountFrom;
        }
        uint256 decimalsFrom = IERC20MetadataUpgradeable(tokenFrom).decimals();
        uint256 decimalsTo = IERC20MetadataUpgradeable(tokenTo).decimals();
        if (decimalsFrom == decimalsTo) {
            return amountFrom;
        } else if (decimalsFrom > decimalsTo) {
            return amountFrom / (10 ** (decimalsFrom - decimalsTo));
        } else {
            return amountFrom * (10 ** (decimalsTo - decimalsFrom));
        }
    }
}
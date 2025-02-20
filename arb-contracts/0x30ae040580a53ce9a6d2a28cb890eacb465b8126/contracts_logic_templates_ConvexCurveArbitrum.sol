// SPDX-License-Identifier: SHIFT-1.0
pragma solidity ^0.8.9;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

import {SelfManagedLogicV2WithUtils} from "./contracts_logic_templates_SelfManagedLogicV2WithUtils.sol";

abstract contract ConvexCurveArbitrum is SelfManagedLogicV2WithUtils {
    IBoosterArbitrum public constant BOOSTER = IBoosterArbitrum(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    IRewardPoolArbitrum public immutable REWARD_POOL;
    ICurveStablePool public immutable CURVE_POOL;

    uint256 public immutable POOL_ID;
    constructor(uint256 pid) {
        POOL_ID = pid;
        (CURVE_POOL,,REWARD_POOL,,) = BOOSTER.poolInfo(pid);
    }

    function enter() external payable override {
        _addLiquidity();
        _approveIfNeeded(address(CURVE_POOL), address(BOOSTER));
        BOOSTER.depositAll(POOL_ID);
    }

    function exit(uint256 liquidity) public payable override {
        REWARD_POOL.withdraw(liquidity, true);
        _removeLiquidity();
    }

    function claimRewards(address recipient) external payable override {
        IRewardPoolArbitrum(REWARD_POOL).getReward(address(this));
        uint256 rewardsAmount = IRewardPoolArbitrum(REWARD_POOL).rewardLength();
        address[] memory rewards = new address[](rewardsAmount);
        for (uint256 i = 0; i < rewardsAmount; i++) {
            (address token,,) = IRewardPoolArbitrum(REWARD_POOL).rewards(i);
            rewards[i] = token;
        }
        for (uint8 i = 0; i < rewards.length; i++) {
            _transferAll(rewards[i], recipient);
        }
    }

    function accountLiquidity(
        address account
    ) public view override returns (uint256) {
        uint256 allocated = allocatedLiquidity(account);
        if (allocated > 0) {
            return allocated;
        }
        return ICurveStablePool(CURVE_POOL).balanceOf(account);

    }

    function allocatedLiquidity(
        address account
    ) public view override returns (uint256) {
        return REWARD_POOL.balanceOf(account);
    }

    function _addLiquidity() internal virtual returns (uint256) {
        uint256[] memory amounts = new uint256[](2);
        for (uint256 i = 0; i < 2; i++) {
            address token = ICurveStablePool(CURVE_POOL).coins(i);
            amounts[i] = IERC20(token).balanceOf(address(this));
            if (amounts[i] > 0) {
                _approveIfNeeded(token, address(CURVE_POOL));
            }
        }
        return ICurveStablePool(CURVE_POOL).add_liquidity(amounts, 0);
    }

    function _removeLiquidity() internal virtual {
        uint256 amount = ICurveStablePool(CURVE_POOL).balanceOf(address(this));
        if (amount > 0) {
            uint256[] memory minAmounts = new uint256[](2);
            ICurveStablePool(CURVE_POOL).remove_liquidity(
                amount,
                minAmounts
            );
        }
    }

    function _exitBuildingBlockConvex() internal {
        uint256 liquidity = allocatedLiquidity(address(this));
        if (liquidity > 0) {
            IRewardPoolArbitrum(REWARD_POOL).withdraw(liquidity, false);
        }
    }

    function _exitBuildingBlockCurve() internal {
        _exitBuildingBlockConvex();
        _removeLiquidity();
    }
}

interface IBoosterArbitrum {
    function depositAll(uint256 pid) external;
    function poolInfo(
        uint256
    ) external view returns (ICurveStablePool, address, IRewardPoolArbitrum, bool, address);
}

interface IRewardPoolArbitrum {
    function withdraw(uint256 amount, bool claim) external;
    function getReward(address recipient) external;
    function rewardLength() external view returns(uint256);
    function rewards(uint256) external view returns(address, uint256, uint256);
    function balanceOf(address) external view returns(uint256);
}

interface ICurveStablePool is IERC20 {
    function add_liquidity(
        uint256[] memory,
        uint256
    ) external returns (uint256);
    function remove_liquidity(
        uint256,
        uint256[] memory
    ) external returns (uint256);
    function coins(uint256) external view returns (address);
    function exchange(int128, int128, uint256, uint256) external returns (uint256);
}
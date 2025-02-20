// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {IERC20Metadata}  from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import {Strings} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_Strings.sol";

import {IMultiRewarder} from "./src_interfaces_stargateV2_IMultiRewarder.sol";
import {IStargatePool} from "./src_interfaces_stargateV2_IStargatePool.sol";
import {IStargateStaking} from "./src_interfaces_stargateV2_IStargateStaking.sol";
import {BaseWrapper} from "./src_wrappers_BaseWrapper.sol";

contract WrappedStargate is BaseWrapper {

    using SafeERC20 for IERC20;

    IStargatePool public immutable POOL;
    IStargateStaking public immutable STAKING;
    IMultiRewarder public immutable REWARDER;
    IERC20 public immutable INVEST_TOKEN;
    IERC20 public immutable LP_TOKEN;

    uint256 internal immutable maxLpDust;

    constructor(address stargatePool, address stargateStaking) BaseWrapper(IStargatePool(stargatePool).lpToken()) {
        POOL = IStargatePool(stargatePool);
        STAKING = IStargateStaking(stargateStaking);
        INVEST_TOKEN = IERC20(POOL.token());
        LP_TOKEN = IERC20(POOL.lpToken());
        REWARDER = IMultiRewarder(STAKING.rewarder(address(LP_TOKEN)));

        /// @dev token decimals are always greater than the shared decimals
        uint8 precision = IERC20Metadata(address(LP_TOKEN)).decimals() - POOL.sharedDecimals();
        maxLpDust = 10 ** precision - 1;
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address authority_
    ) public initializer {
        __BaseWrapper_init(name_, symbol_, authority_);
    }

    /// @dev Ratio between invest token and lp tokens 1:1
    function totalAssets()
        public
        view
        virtual
        override
        returns (uint256)
    {
        return STAKING.balanceOf(address(LP_TOKEN), address(this));
    }

    /*
    * @dev The investment token amount will be adjusted to match
    *      the lowest common decimal places between all chains.
    *      Any remaining tokens will return as dust.
    */
    function _invest() internal override {
        uint256 currBalance = INVEST_TOKEN.balanceOf(address(this));
        if (currBalance > 0) {
            IERC20(INVEST_TOKEN).forceApprove(address(POOL), currBalance);
            POOL.deposit(address(this), currBalance);
        }

        currBalance = LP_TOKEN.balanceOf(address(this));
        if (currBalance > 0) {
            IERC20(LP_TOKEN).forceApprove(address(STAKING), currBalance);
            STAKING.deposit(address(LP_TOKEN), currBalance);
        }
    }

    /*
    * @dev The lp token amount will be adjusted to match
    *      the lowest common decimal places between all chains.
    *      Any remaining pool tokens will stay in the contract
    *      and become available to the next user.
    */
    function _redeem(uint lpAmount, address to)
        internal
        override
        returns (address[] memory tokens, uint[] memory amounts)
    {
        STAKING.withdraw(address(LP_TOKEN), lpAmount);

        uint256 lpBalance = LP_TOKEN.balanceOf(address(this));
        if (lpBalance > maxLpDust) {
            POOL.redeem(lpBalance, to);
        }

        uint256 lpDust = LP_TOKEN.balanceOf(address(this));
        require(lpDust <= maxLpDust, "Not all lp are redeemed");

        tokens = new address[](1);
        tokens[0] = address(INVEST_TOKEN);

        amounts = new uint[](1);
        amounts[0] = lpBalance - lpDust;
    }

    function _claim(address to) internal override {
        address[] memory claimLp = new address[](1);
        claimLp[0] = address(LP_TOKEN);
        STAKING.claim(claimLp);

        address[] memory rewardTokenList = REWARDER.rewardTokens();
        for (uint8 i = 0; i < rewardTokenList.length; i++) {
            address rewardToken = rewardTokenList[i];
            uint256 rewardBalance = IERC20(rewardToken).balanceOf(address(this));

            if (rewardBalance > 0) {
                IERC20(rewardToken).safeTransfer(to, rewardBalance);
            }
        }
    }

    function depositTokens() public override view returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = address(INVEST_TOKEN);
    }

    function rewardTokens() public override view returns (address[] memory tokens) {
        tokens = REWARDER.rewardTokens();
    }

    function poolTokens() public override view returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = address(INVEST_TOKEN);
    }

    function farmingPool() public view returns (address) {
        return address(POOL);
    }

    /// @dev for offchain use
    function ratios()
        external
        override
        view
        returns (address[] memory tokens, uint[] memory ratio)
    {
        tokens = new address[](1);
        ratio = new uint256[](1);

        tokens[0] = address(INVEST_TOKEN);
        ratio[0] = 1e18;
    }

    function _accrueInterest() internal override {}

    /// @dev for offchain use
    function description() external override view returns (string memory) {
        return string.concat(
            '{',
            '"type":"stargateV2",',
            '"stargateStaking":"',Strings.toHexString(address(STAKING)),'",',
            '"multiRewarder":"',Strings.toHexString(address(REWARDER)),'"',
            '}'
        );
    }

}
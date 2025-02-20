// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {Strings} from "./openzeppelin_contracts_utils_Strings.sol";
import {Math} from "./openzeppelin_contracts_utils_math_Math.sol";

import {IAPool} from "./src_interfaces_aave_IAPool.sol";
import {IAToken} from "./src_interfaces_aave_IAToken.sol";

import {BaseWrapper} from "./src_wrappers_BaseWrapper.sol";

contract WrappedAave is BaseWrapper {

    using SafeERC20 for IERC20;

    IERC20 public ASSET;
    IAPool public POOL;
    IAToken public A_TOKEN;

    function initialize(address aToken, string memory name_, string memory symbol_, address authority_) public initializer {
        __BaseWrapper_init(aToken, name_, symbol_, authority_);

        A_TOKEN = IAToken(aToken);
        ASSET = IERC20(A_TOKEN.UNDERLYING_ASSET_ADDRESS());
        POOL = IAPool(A_TOKEN.POOL());
    }

    function _invest() internal override {
        uint256 assetBalance = ASSET.balanceOf(address(this));
        if (assetBalance > 0) {
            ASSET.forceApprove(address(POOL), assetBalance);
            POOL.supply(address(ASSET), assetBalance, address(this), 0);
        }
    }

    function _redeem(uint lpAmount, address to)
        internal
        override
        returns (address[] memory tokens, uint[] memory amounts)
    {
        tokens = new address[](1);
        amounts = new uint256[](1);

        tokens[0] = address(ASSET);
        amounts[0] = POOL.withdraw(address(ASSET), lpAmount, to);
    }

    function _claim(address to) internal override {
        uint totalSupply_ = totalSupply();
        uint underlyingAssets = _convertToShares(totalAssets(), Math.Rounding.Floor);

        if (underlyingAssets > totalSupply_) {
            uint sharesToClaim = _convertToAssets(underlyingAssets - totalSupply_, Math.Rounding.Floor);
            if (sharesToClaim > 0) {
                _redeem(sharesToClaim, to);
            }
        }

        require(_convertToShares(totalAssets() + 1, Math.Rounding.Floor) >= totalSupply_, "Incorrect state");
    }

    function depositTokens() public override view returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = address(ASSET);
    }

    function rewardTokens() public override view returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = address(ASSET);
    }

    function poolTokens() public override view returns (address[] memory tokens) {
        tokens = new address[](1);
        tokens[0] = address(ASSET);
    }

    function farmingPool() public view returns (address) {
        return address(A_TOKEN);
    }

    /// @dev for offchain use
    function ratios()
    external
    override
    view
    returns (address[] memory tokens, uint[] memory ratio)
    {
        tokens = new address[](1);
        tokens[0] = address(ASSET);

        ratio  = new uint[](1);
        ratio[0] = 1e18;
    }

    /// @dev for offchain use
    function description() external override view returns (string memory) {
        return string.concat(
            '{"type":"aave","poolAddress": "',
            Strings.toHexString(address(POOL)),
            '","asset":"',
            Strings.toHexString(address(ASSET)),
            '","aToken":"',
            Strings.toHexString(address(A_TOKEN)),
            '"}'
        );
    }

    function _convertToShares(uint256 assets, uint256 assetsBefore, Math.Rounding rounding) internal override view returns (uint256) {
        return assets;
    }

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal override view returns (uint256) {
        return assets;
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal override view returns (uint256) {
        return shares;
    }

    function supplyRate() external view returns (uint)  {
        IAPool.ReserveData memory data = POOL.getReserveData(address(ASSET));
        return data.currentLiquidityRate;
    }

}
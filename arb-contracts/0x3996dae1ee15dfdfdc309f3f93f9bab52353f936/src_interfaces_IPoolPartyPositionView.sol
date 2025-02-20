// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IV3SwapRouter} from "./src_interfaces_IV3SwapRouter.sol";
import {INonfungiblePositionManager} from "./src_interfaces_INonfungiblePositionManager.sol";
import {PositionKey} from "./src_types_PositionKey.sol";
import {PositionId} from "./src_types_PositionId.sol";
import {IPoolPartyPosition} from "./src_interfaces_IPoolPartyPosition.sol";

interface IPoolPartyPositionViewStructs {
    struct RefundVault {
        uint256 amount0;
        uint256 amount1;
    }

    struct PoolPositionInfo {
        PositionId positionId;
        address currency0;
        address currency1;
        uint128 liquidity;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0;
        uint256 amount1;
        uint256 tokensOwed0;
        uint256 tokensOwed1;
        uint256 timestamp;
        uint256 blockNumber;
        uint160 sqrtPriceX96Pool;
    }
}

interface IPoolPartyPositionView is IPoolPartyPositionViewStructs {
    /// @notice Returns the amount of rewards earned for currency0 by a specific position for a specific account
    /// @param _account The account for which the rewards are calculated
    /// @return The amount of rewards earned by the account for currency0 and currency1
    function calculateRewardsEarned(
        address _account
    ) external view returns (uint256, uint256);

    /// @notice Returns the amount of liquidity in a specific position for a specific account
    /// @param _account The account for which the liquidity is calculated
    /// @return liquidity The amount of liquidity in the position for the account
    function liquidityOf(
        address _account
    ) external view returns (uint256 liquidity);

    /// @notice Returns if a specific position is closed
    function isClosed() external view returns (bool);

    /// @notice Returns the total liquidity in the position
    function liquidity() external view returns (uint128);

    /// @notice Returns the total remaining liquidity after close the position
    function remainingLiquidityAfterClose() external view returns (uint128);

    /// @notice Returns the total supply of currency0 and currency1
    function totalSupply() external view returns (uint256, uint256);

    /// @notice Returns the balance of currency0 and currency1 for a specific account
    function balanceOf(
        address _account
    ) external view returns (uint256, uint256);

    /// @notice Returns the total fees in the position
    function totalFeesInVault()
        external
        view
        returns (uint256, uint256, uint256);

    // @notice Returns the latest position snapshot index
    function positionSnapshotIndex() external view returns (uint256);

    /// @notice Returns the total refund balance of currency0 and currency1 for a specific account
    function refundBalanceOf(
        address _account
    ) external view returns (uint256, uint256);

    /// @notice Returns the total refund balance of currency0, currency1, and stable currency
    function refundBalance() external view returns (uint256, uint256, uint256);

    /// @notice Returns the position key
    function key() external view returns (PositionKey memory _positionKey);

    /// @notice Returns the token id
    function tokenId() external view returns (uint256);

    /// @notice Returns the nonfungible position manager
    function nonfungiblePositionManager()
        external
        view
        returns (INonfungiblePositionManager);

    /// @notice Returns the swap router
    function swapRouter() external view returns (IV3SwapRouter);

    /// @notice Returns the pool address of the position
    function pool() external view returns (address);

    /// @notice Returns the StableCurrency token
    function stableCurrency() external view returns (address);

    /// @notice Returns the PoolParty recipient
    function protocolFeeRecipient() external view returns (address);

    /// @notice Returns the PoolParty fee
    function protocolFee() external view returns (uint24);

    /// @notice This function is used to check if the current tick is within the tick range of the pool position
    /// @return 0 if the current tick is within the tick range,
    //  1 if the current tick is above the tick range, -1 if the current tick is below the tick range.
    // @dev if the current tick is above the tick range (1), position is 100% currency1,
    // if the current tick is below the tick range (-1), position is 100% currency0
    function inRange() external view returns (int8);

    /// @notice Returns the WETH9 token address
    function WETH9() external view returns (address);

    /// @notice Returns the pool position's info data
    function poolPositionInfo() external view returns (PoolPositionInfo memory);

    /// @notice Returns the sqrtPriceX96 of the pool before the position is closed
    function sqrtPriceX96BeforeClose() external view returns (uint160);
}
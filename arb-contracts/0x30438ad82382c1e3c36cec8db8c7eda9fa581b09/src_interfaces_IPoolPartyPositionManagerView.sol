// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {PositionId} from "./src_types_PositionId.sol";
import {IPoolPartyPositionViewStructs, IPoolPartyPosition} from "./src_interfaces_IPoolPartyPosition.sol";
import {IPoolPartyPositionManagerStructs} from "./src_interfaces_IPoolPartyPositionManager.sol";

interface IPoolPartyPositionManagerViewStructs {
    struct PositionData {
        PositionId positionId;
        address pool;
        address poolView;
        address operator;
        address currency0;
        address currency1;
        uint256 totalSupply0;
        uint256 totalSupply1;
        uint256 tokenId;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        int8 inRange;
        bool closed;
        IPoolPartyPositionManagerStructs.FeatureSettings featureSettings;
        uint256 totalInvestors;
        address uniswapV3Pool;
        uint160 sqrtPriceX96Pool;
    }

    struct InvestorPositionData {
        PositionId positionId;
        address pool;
        address poolView;
        address currency0;
        address currency1;
        uint256 tokenId;
        uint256 amount0;
        uint256 amount1;
        uint256 rewards0;
        uint256 rewards1;
        uint24 fee;
        uint256 totalInvestors;
    }
}

interface IPoolPartyPositionManagerView is
    IPoolPartyPositionManagerViewStructs
{
    /// @notice Returns the positions' address for a specific operator
    /// @param _operator The address of the operator
    /// @return A lsit of positions' address for a specific operator
    function operatorPositions(
        address _operator
    ) external view returns (address[] memory);

    /// @notice Returns the position's address for a specific operator
    /// @param _positionId The id of the position
    /// @return The position's address for a specific operator
    function operatorPosition(
        PositionId _positionId
    ) external view returns (address);

    /// @notice Returns the positions' address for a specific investor
    /// @param _investor The address of the investor
    /// @return A lsit of positions' address for a specific investor
    function investorPositions(
        address _investor
    ) external view returns (address[] memory);

    /// @notice Returns the position's address for a specific investor
    /// @param _investor The address of the investor
    /// @param _positionId The id of the position
    /// @return The position's address for a specific investor
    function investorPosition(
        PositionId _positionId,
        address _investor
    ) external view returns (address);

    /// @notice Returns all the positions' address
    function allPositions() external view returns (address[] memory);

    /// @notice Returns the list of positions' data for a specific account
    function listOfPositionDataBy(
        address _account,
        address[] calldata _positions
    ) external view returns (InvestorPositionData[] memory);

    /// @notice Returns the position's data for a specific position
    function positionData(
        address _position
    ) external view returns (PositionData memory);

    /// @notice Returns if the manager is destroyed
    function destroyed() external view returns (bool);

    /// @notice Returns the list of positions' info data
    function poolPositionsInfo(
        address[] calldata _positions
    )
        external
        view
        returns (IPoolPartyPositionViewStructs.PoolPositionInfo[] memory);
}
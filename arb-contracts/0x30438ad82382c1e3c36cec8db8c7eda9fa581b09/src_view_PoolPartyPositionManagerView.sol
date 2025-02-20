// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IUniswapV3Pool} from "./lib_v3-core_contracts_interfaces_IUniswapV3Pool.sol";
import {StateLibrary} from "./src_library_manager_StateLibrary.sol";
import {Constants} from "./src_library_Constants.sol";
import {Errors} from "./src_library_Errors.sol";
import {PositionIdLib, PositionKey} from "./src_types_PositionId.sol";
import "./src_storage_PoolPartyPositionManagerViewStorage.sol";

contract PoolPartyPositionManagerView is PoolPartyPositionManagerViewStorage {
    using PositionIdLib for PositionKey;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Retrieves the positions of an operator.
     * @param _operator The address of the operator.
     * @return An array of addresses representing the positions of the operator.
     */
    function operatorPositions(
        address _operator
    ) external view returns (address[] memory) {
        return
            StateLibrary.getPositionsByInvestor(
                IPoolPartyPositionManager(s.i_poolPositionManager),
                _operator
            );
    }

    /**
     * @notice Retrieves a specific position of an operator.
     * @param _positionId The ID of the position.
     * @return The address of the position.
     */
    function operatorPosition(
        PositionId _positionId
    ) external view returns (address) {
        IPoolPartyPositionManager _pppm = IPoolPartyPositionManager(
            s.i_poolPositionManager
        );
        address operator = StateLibrary.getOperatorByPositionId(
            _pppm,
            _positionId
        );
        return
            StateLibrary.getPositionByInvestorAndId(
                _pppm,
                _positionId,
                operator
            );
    }

    /**
     * @notice Retrieves the positions of an investor.
     * @param _investor The address of the investor.
     * @return An array of addresses representing the positions of the investor.
     */
    function investorPositions(
        address _investor
    ) external view returns (address[] memory) {
        return
            StateLibrary.getPositionsByInvestor(
                IPoolPartyPositionManager(s.i_poolPositionManager),
                _investor
            );
    }

    /**
     * @notice Retrieves a specific position of an investor.
     * @param _investor The address of the investor.
     * @param _positionId The ID of the position.
     * @return The address of the position.
     */
    function investorPosition(
        PositionId _positionId,
        address _investor
    ) external view returns (address) {
        return
            StateLibrary.getPositionByInvestorAndId(
                IPoolPartyPositionManager(s.i_poolPositionManager),
                _positionId,
                _investor
            );
    }

    /**
     * @notice Retrieves all positions.
     * @return An array of addresses representing all positions.
     */
    function allPositions() external view returns (address[] memory) {
        return
            StateLibrary.getPositions(
                IPoolPartyPositionManager(s.i_poolPositionManager)
            );
    }

    /**
     * @notice Retrieves a list of position data for a specific account.
     * @param _account The address of the account.
     * @param _positions An array of addresses representing the positions.
     * @return An array of InvestorPositionData structs containing the position data.
     */
    function listOfPositionDataBy(
        address _account,
        address[] calldata _positions
    ) external view override returns (InvestorPositionData[] memory) {
        require(_account != address(0), Errors.AddressIsZero());

        uint256 length = _positions.length;
        require(
            length <= Constants.MAX_POSITIONS,
            Errors.TooManyPositions(Constants.MAX_POSITIONS, length)
        );

        InvestorPositionData[] memory positions = new InvestorPositionData[](
            length
        );

        if (length == 0) {
            return positions;
        }

        // slither-disable-start calls-loop
        for (uint256 i = 0; i < length; i++) {
            if (_positions[i] == address(0)) {
                continue;
            }
            IPoolPartyPosition position = IPoolPartyPosition(_positions[i]);
            PositionKey memory positionKey = position.poolPositionView().key();
            if (positionKey.pool == address(0)) {
                continue;
            }

            PositionId positionId = positionKey.toId();
            IPoolPartyPosition _investorPosition = IPoolPartyPosition(
                StateLibrary.getPositionByInvestorAndId(
                    IPoolPartyPositionManager(s.i_poolPositionManager),
                    positionId,
                    _account
                )
            );
            if (address(_investorPosition) == address(0)) {
                continue;
            }

            // uint256 totalInvestors = s.totalInvestorsByPosition[positionId];
            uint256 totalInvestors = StateLibrary.getTotalInvestorsByPosition(
                IPoolPartyPositionManager(s.i_poolPositionManager),
                positionId
            );
            (uint256 amount0, uint256 amount1) = position
                .poolPositionView()
                .balanceOf(_account);
            (uint256 rewards0, uint256 rewards1) = position
                .poolPositionView()
                .calculateRewardsEarned(_account);
            positions[i] = InvestorPositionData({
                positionId: positionId,
                pool: address(position),
                poolView: address(position.poolPositionView()),
                currency0: positionKey.currency0,
                currency1: positionKey.currency1,
                tokenId: position.poolPositionView().tokenId(),
                amount0: amount0,
                amount1: amount1,
                rewards0: rewards0,
                rewards1: rewards1,
                fee: positionKey.fee,
                totalInvestors: totalInvestors
            });
        }
        // slither-disable-end calls-loop
        return positions;
    }

    /**
     * @notice Retrieves the data of a specific position.
     * @param _position The address of the position.
     * @return A PositionData struct containing the position data.
     */
    function positionData(
        address _position
    ) external view override returns (PositionData memory) {
        require(_position != address(0), Errors.AddressIsZero());

        IPoolPartyPosition position = IPoolPartyPosition(_position);
        PositionKey memory positionKey = position.poolPositionView().key();
        require(positionKey.pool != address(0), Errors.PoolPositionNotFound());

        PositionId positionId = positionKey.toId();

        //slither-disable-next-line unused-return
        (uint160 sqrtPriceX96Pool, , , , , , ) = IUniswapV3Pool(
            positionKey.pool
        ).slot0();
        IPoolPartyPositionManager pppm = IPoolPartyPositionManager(
            s.i_poolPositionManager
        );

        // s.totalInvestorsByPosition[positionId];
        uint256 totalInvestors = StateLibrary.getTotalInvestorsByPosition(
            pppm,
            positionId
        );

        (uint256 totalSupply0, uint256 totalSupply1) = position
            .poolPositionView()
            .totalSupply();

        IPoolPartyPositionManagerStructs.FeatureSettings
            memory featureSettings = StateLibrary.getFeatureSettings(
                pppm,
                positionId
            );

        return
            PositionData({
                positionId: positionId,
                pool: address(position),
                poolView: address(position.poolPositionView()),
                operator: positionKey.operator,
                currency0: positionKey.currency0,
                currency1: positionKey.currency1,
                totalSupply0: totalSupply0,
                totalSupply1: totalSupply1,
                tokenId: position.poolPositionView().tokenId(),
                fee: positionKey.fee,
                tickLower: positionKey.tickLower,
                tickUpper: positionKey.tickUpper,
                inRange: position.poolPositionView().inRange(),
                closed: position.poolPositionView().isClosed(),
                featureSettings: featureSettings,
                totalInvestors: totalInvestors,
                uniswapV3Pool: positionKey.pool,
                sqrtPriceX96Pool: sqrtPriceX96Pool
            });
    }

    /**
     * @notice Retrieves information about multiple pool positions.
     * @param _positions An array of addresses representing the positions.
     * @return An array of PoolPositionInfo structs containing the position information.
     */
    function poolPositionsInfo(
        address[] calldata _positions
    )
        external
        view
        returns (IPoolPartyPositionViewStructs.PoolPositionInfo[] memory)
    {
        uint256 length = _positions.length;
        require(
            length <= Constants.MAX_POSITIONS,
            Errors.TooManyPositions(Constants.MAX_POSITIONS, length)
        );

        IPoolPartyPositionViewStructs.PoolPositionInfo[]
            memory positions = new IPoolPartyPositionViewStructs.PoolPositionInfo[](
                length
            );

        if (length == 0) {
            return positions;
        }

        // slither-disable-start calls-loop
        for (uint256 i = 0; i < length; i++) {
            if (_positions[i] == address(0)) {
                continue;
            }
            IPoolPartyPosition position = IPoolPartyPosition(_positions[i]);
            PositionKey memory positionKey = position.poolPositionView().key();
            if (positionKey.pool == address(0)) {
                continue;
            }

            positions[i] = position.poolPositionView().poolPositionInfo();
        }
        // slither-disable-end calls-loop

        return positions;
    }

    function destroyed() external view override returns (bool) {
        return
            StateLibrary.isDestroyed(
                IPoolPartyPositionManager(s.i_poolPositionManager)
            );
    }

    ///@dev required by the OZ UUPS module
    // aderyn-ignore-next-line(empty-block)
    function _authorizeUpgrade(
        address
    )
        internal
        override
        onlyRole(Constants.UPGRADER_ROLE) // aderyn-ignore(centralization-risk)
    {}
}
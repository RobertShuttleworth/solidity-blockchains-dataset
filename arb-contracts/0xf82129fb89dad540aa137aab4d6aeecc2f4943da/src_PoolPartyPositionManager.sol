// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Core} from "./src_library_manager_Core.sol";
import {Errors} from "./src_library_Errors.sol";
import "./src_base_manager_Base.sol";

/**
 * @title PoolPartyPositionManager contract
 * @author Pool Party
 * @notice This contract manages the positions of the UbitsPoolPosition protocol
 */
// aderyn-ignore-next-line(contract-locks-ether,contract-with-todos)
contract PoolPartyPositionManager is Base {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IPoolPartyPositionManager
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function setMaxInvestment(
        uint256 _maxInvestment
    )
        external
        whenNotDestroyed
        onlyRole(DEFAULT_ADMIN_ROLE) // aderyn-ignore(centralization-risk)
    {
        s.maxInvestment = _maxInvestment;
    }

    /// @inheritdoc IPoolPartyPositionManager
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function setPoolPartyRecipient(
        address _poolPartyRecipient
    )
        external
        whenNotDestroyed
        onlyRole(DEFAULT_ADMIN_ROLE) // aderyn-ignore(centralization-risk)
    {
        require(_poolPartyRecipient != address(0), Errors.AddressIsZero());
        s.protocolFeeRecipient = _poolPartyRecipient;
    }

    // @todo REMOVE THIS FUNCTION IN THE FUTURE
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function resetMaxInvestment(
        address[] memory _accounts
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE) // aderyn-ignore(centralization-risk)
    {
        Core.resetMaxInvestment(s, _accounts);
    }

    /// @inheritdoc IPoolPartyPositionManager
    function pause()
        external
        onlyRole(Constants.PAUSER_ROLE) // aderyn-ignore(centralization-risk)
        whenNotDestroyed
        whenNotPaused
    {
        _pause();
    }

    /// @inheritdoc IPoolPartyPositionManager
    function unpause()
        external
        onlyRole(Constants.PAUSER_ROLE) // aderyn-ignore(centralization-risk)
        whenNotDestroyed
        whenPaused
    {
        _unpause();
    }

    /// @inheritdoc IPoolPartyPositionManager
    function destroy()
        external
        onlyRole(Constants.DESTROYER_ROLE) // aderyn-ignore(centralization-risk)
        whenNotDestroyed
    {
        s.destroyed = true;
        emit Destroyed();
    }

    /// @inheritdoc IPoolPartyPositionManager
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function createPosition(
        CreatePositionParams calldata _params
    )
        external
        payable
        nonReentrant
        whenNotDestroyed
        whenNotPaused
        // onlyWhitelistedOperator(_params.proof)
        // securityCheck(_params.secParams)
        returns (PositionId positionId)
    {
        // slither-disable-start unused-return
        return Core.createPosition(s, _params);
        // slither-disable-end unused-return
    }

    /// @inheritdoc IPoolPartyPositionManager
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function addLiquidity(
        AddLiquidityParams calldata _params
    )
        external
        nonReentrant
        whenNotDestroyed
        whenNotPaused
        minInvestmentInStableCurrency(_params.permit.details.amount)
        maxInvestmentCapInStableCurrency(_params.permit.details.amount)
        securityCheck(_params.secParams)
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        // slither-disable-start unused-return
        return Core.addLiquidity(s, _params);
        // slither-disable-end unused-return
    }

    /// @inheritdoc IPoolPartyPositionManager
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function removeLiquidity(
        RemoveLiquidityParams calldata _params
    )
        external
        nonReentrant
        whenNotDestroyed
        whenNotPaused
        securityCheck(_params.secParams)
        returns (uint128 liquidity, uint256 amount0, uint256 amount1)
    {
        // slither-disable-start unused-return
        return Core.removeLiquidity(s, _params);
        // slither-disable-end unused-return
    }

    /// @inheritdoc IPoolPartyPositionManager
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function collectRewards(
        CollectParams calldata _params
    )
        external
        nonReentrant
        whenNotDestroyed
        whenNotPaused
        securityCheck(_params.secParams)
        returns (uint256 amount0, uint256 amount1)
    {
        // slither-disable-start unused-return
        return Core.collectRewards(s, _params);
        // slither-disable-end unused-return
    }

    /// @inheritdoc IPoolPartyPositionManager
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function closePool(
        ClosePoolParams calldata _params
    )
        external
        nonReentrant
        whenNotDestroyed
        whenNotPaused
        onlyPositionOperator(_params.positionId)
        securityCheck(_params.secParams)
        returns (uint128, uint256, uint256)
    {
        // slither-disable-start unused-return
        return Core.closePool(s, _params);
        // slither-disable-end unused-return
    }

    /// @inheritdoc IPoolPartyPositionManager
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function withdraw(
        WithdrawParams calldata _params
    )
        external
        nonReentrant
        whenNotDestroyed
        whenNotPaused
        securityCheck(_params.secParams)
        returns (
            uint256 currency0,
            uint256 currency1,
            uint256 collected0,
            uint256 collected1
        )
    {
        // slither-disable-start unused-return
        return Core.withdraw(s, _params);
        // slither-disable-end unused-return
    }

    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function moveRange(
        MoveRangeParams calldata _params
    )
        external
        nonReentrant
        whenNotDestroyed
        whenNotPaused
        onlyPositionOperator(_params.positionId)
        securityCheck(_params.secParams)
    {
        // slither-disable-start unused-return
        Core.moveRange(s, _params);
        // slither-disable-end unused-return
    }

    ///@dev required by the OZ UUPS module
    // aderyn-ignore-next-line(empty-block)
    function _authorizeUpgrade(
        address
    )
        internal
        override
        onlyRole(Constants.UPGRADER_ROLE) // aderyn-ignore(centralization-risk)
        whenNotDestroyed
    {}

    receive() external payable {}
}
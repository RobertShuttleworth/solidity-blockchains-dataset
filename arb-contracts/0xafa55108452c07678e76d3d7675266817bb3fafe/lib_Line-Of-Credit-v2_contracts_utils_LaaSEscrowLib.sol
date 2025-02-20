pragma solidity 0.8.25;

import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {EscrowState, EscrowLib} from "./lib_Line-Of-Credit-v2_contracts_utils_EscrowLib.sol";
import {Escrow} from "./lib_Line-Of-Credit-v2_contracts_modules_escrow_Escrow.sol";
import {ILaaSEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILaaSEscrow.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {IEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrow.sol";

    // Common structs and interfaces remain the same
struct TokenBalanceSnapshot {
    uint256[] balances;
    uint256 lpBalance;
}
/**
 * @title   - LaaSEscrowLib
 * @author  - Credit Cooperative
 * @notice  - Core logic by LaaSEscrow contract for adding and removing liquidity to liquidity pools.
 */
library LaaSEscrowLib {
    using EscrowLib for EscrowState;
    using SafeERC20 for IERC20;

    error OperatorFnCallFailed();

    /**
     * see LaaSEscrow.reduceLiquidity
     *  @notice - if the borrower is calling, we allow for custom calldata to decrease liquidity
     *  @notice - if its not the borrower, we callow anyone to call this and use the default calldata to decrease liquidtiy in the case of apron breach and partial liquidation
     */
    function reduceLiquidity(
        EscrowState storage state,
        mapping(uint256 => ILaaSEscrow.LiquidityPosition) storage liquidityPositions,
        uint256 index,
        address pool,
        uint256 minimumCollateralRatio,
        address borrower,
        bytes memory removeLiquidityData,
        uint256 minimumCollateralValue
    ) external {
        // only borrower or owner
        ILaaSEscrow.LiquidityPosition memory lp = liquidityPositions[index];
        if (lp.LpToken == address(0)) {
            // if LP position does not exist, revert
            revert ILaaSEscrow.NoLiquidityPosition();
        }

        uint256 cratio = Escrow(address(this)).getCollateralRatio();

        if (msg.sender != borrower && (minimumCollateralRatio + lp.apron <= cratio)) {
            revert ILaaSEscrow.ApronNotBreached();
        }

        if (msg.sender == borrower) {
            bytes4 func = bytes4(removeLiquidityData);

            if (func != lp.removeLiquidityFunc) {
                revert IEscrow.InvalidFunctionSelector();
            }
            _removeLiquidity(state, removeLiquidityData, index, lp, pool, minimumCollateralValue);
        } else {
            _removeLiquidity(state, lp.removeLiquidityData, index, lp, pool, minimumCollateralValue);
            lp.apron = uint32(cratio - minimumCollateralRatio); // update apron so we dont allow a reentrancy attack
        }
    }

    /**
     * see LaaSEscrow.liquidatePosition
     */
    function liquidatePosition(
        EscrowState storage state,
        mapping(uint256 => ILaaSEscrow.LiquidityPosition) storage liquidityPositions,
        bytes memory removeLiquidityData,
        uint256 index,
        address pool,
        bool isDelayed,
        uint256 minimumCollateralValue
    ) external {
        // remove LP position entirely

        if (ILineOfCredit(state.owner).status() != LineLib.STATUS.LIQUIDATABLE) {
            revert IEscrow.NotLiquidatable();
        }

        ILaaSEscrow.LiquidityPosition storage lp = liquidityPositions[index];

        bytes4 func = bytes4(removeLiquidityData);

        if (lp.LpToken == address(0)) {
            // if LP position does not exist, revert
            revert ILaaSEscrow.NoLiquidityPosition();
        }

        if (func != lp.removeLiquidityFunc) {
            revert IEscrow.InvalidFunctionSelector();
        }

        // get status

        _removeLiquidity(state, removeLiquidityData, index, lp, pool, minimumCollateralValue);

        // balance of LP token should be 0
        if (!isDelayed) {
            if (LineLib.getBalance(lp.LpToken) != 0) {
                revert ILaaSEscrow.LPNotLiquidated();
            }
        }
    }

    /**
     * see LaaSEscrow.increaseLiquidity
     */
    function increaseLiquidity(
        EscrowState storage state,
        mapping(uint256 => ILaaSEscrow.LiquidityPosition) storage liquidityPositions,
        uint256 index,
        address pool,
        bytes memory increaseLiquidityData,
        uint256 minimumCollateralValue
    ) external {
        LineLib.STATUS status = ILineOfCredit(state.owner).status();
        if (status == LineLib.STATUS.LIQUIDATABLE || status == LineLib.STATUS.INSOLVENT) {
            revert ILaaSEscrow.LineIsLiquidatable();
        }

        // adds additional liquidity
        address lpToken = liquidityPositions[index].LpToken;
        if (lpToken == address(0)) {
            // if LP position does not exist, revert
            revert ILaaSEscrow.NoLiquidityPosition();
        }

        ILaaSEscrow.LiquidityPosition storage lp = liquidityPositions[index];

        bytes4 func = bytes4(increaseLiquidityData);

        if (func != lp.liquidityProvisionFunc) {
            revert IEscrow.InvalidFunctionSelector();
        }

        _increaseLiquidity(state, liquidityPositions, index, lpToken, increaseLiquidityData, pool, minimumCollateralValue);
    }

    /**
     * see LaaSEscrow.initializeLiquidity
     */
    function initializeLiquidity(
        EscrowState storage state,
        mapping(uint256 => ILaaSEscrow.LiquidityPosition) storage liquidityPositions,
        uint256 index,
        address pool,
        uint256 minCollateralValue
    ) external {
        if (
            ILineOfCredit(state.owner).status() == LineLib.STATUS.LIQUIDATABLE
                || ILineOfCredit(state.owner).status() == LineLib.STATUS.INSOLVENT
        ) {
            revert ILaaSEscrow.LineIsLiquidatable();
        }

        // uses prestored liquidity data in position struct; Only Borrower
        ILaaSEscrow.LiquidityPosition storage lp = liquidityPositions[index];

        if (lp.LpToken == address(0)) {
            // if LP position does not exist, revert
            revert ILaaSEscrow.NoLiquidityPosition();
        }

        // only call this func if no LP tokens are present, otherwise use increaseLiquidity

        if (LineLib.getBalance(lp.LpToken) != 0) {
            revert IEscrow.AlreadyInitialized();
        }

        _increaseLiquidity(state, liquidityPositions, index, lp.LpToken, lp.liquidityProvisionData, pool, minCollateralValue);
    }

    function _checkSlippage(
    uint256 actualValue,
    uint256 minValue
) private pure {
    require(actualValue >= minValue, "insufficient output value");
}



function _getTokenBalances(
    address[] memory tokens,
    address lpToken
) private view returns (TokenBalanceSnapshot memory) {
    uint256 length = tokens.length;
    uint256[] memory componentBalances = new uint256[](length);
    
    for (uint256 i = 0; i < length; i++) {
        componentBalances[i] = LineLib.getBalance(tokens[i]);
    }
    
    return TokenBalanceSnapshot({
        balances: componentBalances,
        lpBalance: LineLib.getBalance(lpToken)
    });
}

function _validateTokens(
    EscrowState storage state,
    address lpToken,
    address[] memory componentTokens
) private view {
    if (!state.enabledTokens[lpToken]) {
        revert EscrowLib.InvalidCollateral();
    }

    for (uint256 i = 0; i < componentTokens.length; i++) {
        if (!state.enabledTokens[componentTokens[i]]) {
            revert EscrowLib.InvalidCollateral();
        }
    }
}

function _executePoolOperation(
    address pool,
    bytes memory operationData
) private returns (bool) {
    (bool success,) = pool.call(operationData);
    if (!success) {
        revert OperatorFnCallFailed();
    }
    return true;
}

function _updateCollateralBalances(
    EscrowState storage state,
    address[] memory tokens,
    address lpToken,
    TokenBalanceSnapshot memory beforeFunctionCall,
    TokenBalanceSnapshot memory afterFunctionCall,
    bool isIncreaseLiquidity
) private {
    if (isIncreaseLiquidity) {
        uint256 lpDifference = afterFunctionCall.lpBalance - beforeFunctionCall.lpBalance;
        require(lpDifference > 0, "increase liquidity failed");
        state.deposited[lpToken].amount += lpDifference;
        emit IEscrow.AddCollateral(lpToken, lpDifference);

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenDifference = beforeFunctionCall.balances[i] - afterFunctionCall.balances[i];
            state.deposited[tokens[i]].amount -= tokenDifference;
            emit IEscrow.RemoveCollateral(tokens[i], tokenDifference);
        }
    } else {
        uint256 lpDifference = beforeFunctionCall.lpBalance - afterFunctionCall.lpBalance;
        state.deposited[lpToken].amount -= lpDifference;
        emit IEscrow.RemoveCollateral(lpToken, lpDifference);

        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 tokenDifference = afterFunctionCall.balances[i] - beforeFunctionCall.balances[i];
            state.deposited[tokens[i]].amount += tokenDifference;
            emit IEscrow.AddCollateral(tokens[i], tokenDifference);
        }
    }
}

function _increaseLiquidity(
    EscrowState storage state,
    mapping(uint256 => ILaaSEscrow.LiquidityPosition) storage liquidityPositions,
    uint256 index,
    address lpToken,
    bytes memory liquidityProvisionData,
    address pool,
    uint256 minCollateralValue
) public returns (bool) {
    address[] memory componentTokens = liquidityPositions[index].componentTokens;
    
    _validateTokens(state, lpToken, componentTokens);
    
    TokenBalanceSnapshot memory balancesBefore = _getTokenBalances(componentTokens, lpToken);
    
    // Approve component tokens
    for (uint256 i = 0; i < componentTokens.length; i++) {
        IERC20(componentTokens[i]).forceApprove(
            pool, liquidityPositions[index].componentTokenAmounts[i]
        );
    }
    
    _executePoolOperation(pool, liquidityProvisionData);
    
    // Reset approvals
    for (uint256 i = 0; i < componentTokens.length; i++) {
        IERC20(componentTokens[i]).forceApprove(pool, 0);
    }
    
    TokenBalanceSnapshot memory balancesAfter = _getTokenBalances(componentTokens, lpToken);
    
    _updateCollateralBalances(
        state,
        componentTokens,
        lpToken,
        balancesBefore,
        balancesAfter,
        true
    );

    // Check slippage after state is updated
    uint256 actualValue = Escrow(address(this)).getCollateralValue();
    _checkSlippage(actualValue, minCollateralValue);
    
    return true;
}

function _removeLiquidity(
    EscrowState storage state,
    bytes memory removeLiquidityData,
    uint256 index,
    ILaaSEscrow.LiquidityPosition memory lp,
    address pool,
    uint256 minCollateralValue
) public returns (bool) {
    TokenBalanceSnapshot memory balancesBefore = _getTokenBalances(lp.componentTokens, lp.LpToken);
    
    LineLib._forceApprove(lp.LpToken, pool, balancesBefore.lpBalance);
    
    _executePoolOperation(pool, removeLiquidityData);
    
    LineLib._forceApprove(lp.LpToken, pool, 0);
    
    TokenBalanceSnapshot memory balancesAfter = _getTokenBalances(lp.componentTokens, lp.LpToken);
    
    if (!lp.isDelayOnLiquidityRemoval) {
        require(balancesAfter.lpBalance <= balancesBefore.lpBalance, "delayed liquidity failed");
        
        for (uint256 i = 0; i < lp.componentTokens.length; i++) {
            require(
                balancesAfter.balances[i] > balancesBefore.balances[i],
                "escrow did not receive component tokens"
            );
        }
    }
    
    _updateCollateralBalances(
        state,
        lp.componentTokens,
        lp.LpToken,
        balancesBefore,
        balancesAfter,
        false
    );

    uint256 actualValue = Escrow(address(this)).getCollateralValue();
    _checkSlippage(actualValue, minCollateralValue);
    
    return true;
}
}
// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {EscrowState, EscrowLib} from "./lib_Line-Of-Credit-v2_contracts_utils_EscrowLib.sol";
import {Escrow} from "./lib_Line-Of-Credit-v2_contracts_modules_escrow_SmartEscrow.sol";
import {SmartEscrow} from "./lib_Line-Of-Credit-v2_contracts_modules_escrow_SmartEscrow.sol";
import {ILaaSEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILaaSEscrow.sol";
import {LaaSEscrowLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LaaSEscrowLib.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";

/**
 * @title  - LaaSEscrow
 * @author - Credit Cooperative
 * @notice - Escrow contract that allows for the deployment of capital to a designated pool, including Uniswap V3 positions
 */
contract LaaSEscrow is ILaaSEscrow, SmartEscrow {
    using LaaSEscrowLib for EscrowState;
    using EscrowLib for EscrowState;
    using SafeERC20 for IERC20;

    mapping(uint256 => ILaaSEscrow.LiquidityPosition) private liquidityPositions;
    uint32 public minimumCollateralRatioAfterDrawdown_;

    // note: making this private for storage savings
    address private pool;
    uint256 private nextAvailableIndex = 0;
    bool private initializedFromFactory = false;

    constructor(address _oracle, address _uniV3Oracle) SmartEscrow(_oracle, _uniV3Oracle) {}

    /**
     * @notice  - Initialize LaaSEscrow contract
     * @dev     - LaaSEscrow is deployed and initialized from EscrowFactory
     * @param _minimumCollateralRatio - In bps, 3 decimals. Cratio threshold where liquidations begin.
     *                                  see Escrow.isLiquidatable()
     * @param _owner                  - Owner (i.e. LineOfCredit) of Escrow contract.
     * @param _borrower               - Borrower on the LineOfCredit contract.
     * @param _pool                   - Pool address to deploy capital to.
     * @param _nftPositionManager     - Uniswap V3 NFT Position Manager address.
     * @param _univ3Manager                - Manager address for the Uniswap V3 position.
     */
    function initializeFromFactory(
        uint32 _minimumCollateralRatio,
        address _owner,
        address _borrower,
        address _pool,
        address _nftPositionManager,
        address _univ3Manager
    ) external {
        if (initializedFromFactory) revert AlreadyInitialized();

        minimumCollateralRatioAfterDrawdown_ = _minimumCollateralRatio;
        borrower = _borrower;
        pool = _pool;
        state.owner = _owner;
        uniV3State.owner = _owner;
        uniV3State.nftPositionManager = _nftPositionManager;
        uniV3State.univ3Manager = _univ3Manager;

        initializedFromFactory = true;
    }

    /**
     * @notice - checks if position is univ3 or not
     * @param index - the index of the LP strategy
     */
    function _checkIfUniswapV3(uint256 index) internal view {
        if (liquidityPositions[index].isUniswapV3) {
            revert UseUniswapV3();
        }
    }

    /**
     * @notice - checks if index is valid
     * @param index - the index of the LP strategy
     */
    function _badIndex(uint256 index) internal view {
        if (index >= nextAvailableIndex) {
            revert BadIndex();
        }
    }

    /**
     * @notice - returns the address of the credit token for a given credit position
     * @param id - the id of the credit position
     */
    function _getCreditToken(uint256 id) internal view returns (address) {
        return ILineOfCredit(state.owner).getCreditPosition(id).token;
    }

    /**
     * @notice - update the pool address that has been designated for deployment of capital
     * @dev    - callable by borrower or admin
     * @param _pool - the address of the pool
     */
    function updatePoolAddress(address _pool) external {
        _onlyBorrowerOrAdmin();
        _checkForActivePositionsOrProposals();
        pool = _pool;
        _incrementNonce();
    }

    /**
     * @notice - update the info about a liquidity provision strategy
     * @param index - the index of the LP strategy
     * @param lpData - the new LP data
     */
    function updateLiquidityPositionData(uint256 index, ILaaSEscrow.LiquidityPosition calldata lpData) external {
        _onlyBorrowerOrAdmin();
        _checkForActivePositionsOrProposals();

        _badIndex(index);

        liquidityPositions[index] = lpData;
        _incrementNonce();

        emit LiquidityPositionUpdated(index, lpData);
    }

    /**
     * @notice - remove a liquidity provision strategy
     * @param index - the index of the LP strategy
     */
    function removeLiquidityPosition(uint256 index) external {
        _onlyBorrowerOrAdmin();
        _checkForActivePositionsOrProposals();

        _badIndex(index);

        delete liquidityPositions[index];
        _incrementNonce();

        emit LiquidityPositionRemoved(index);
    }

    /**
     * @notice - updates the minCratio that is set after an LP position has been created with borrowed funds
     * @param _minimumCollateralRatio - the new minCratio
     */
    function updateMinimumCollateralRatioAfterDrawdown(uint32 _minimumCollateralRatio) external {
        _onlyBorrowerOrAdmin();
        _checkForActivePositionsOrProposals();
        minimumCollateralRatioAfterDrawdown_ = _minimumCollateralRatio;
        _incrementNonce();

        emit UpdateMinimumCollateralRatio(_minimumCollateralRatio);
    }

    /**
     * @notice Creates an LP strategy, we need to set this before a lender will propose a position
     * @dev callable by admin or borrower. Can only be called if there are no active positions
     * @param lpData - the LP data
     */
    function addLiquidityPositionData(ILaaSEscrow.LiquidityPosition calldata lpData) public {
        _onlyBorrowerOrAdmin();
        _checkForActivePositionsOrProposals();

        // Push it on to the next position in the mapping
        liquidityPositions[nextAvailableIndex] = lpData;

        emit LiquidityPositionAdded(nextAvailableIndex, lpData);

        unchecked {
            nextAvailableIndex++;
        }

        _incrementNonce();

        emit LiquidityPositionAdded(nextAvailableIndex, lpData);
    }

    /**
     * @notice - returns info about a liquidity provision strategy
     * @param index - the index of the LP strategy
     */
    function getPositionInfo(uint256 index) external view returns (ILaaSEscrow.LiquidityPosition memory, address) {
        // note: returning pool address here instead of public var. Save 100+ bytes
        return (liquidityPositions[index], pool);
    }

    /**
     * @notice - draw down on a credit position and immediately initialize an LP position with the preset pool address and LP info
     * @notice - this function is called only if no LP position has been created
     * @param id - id of the credit position we are drawing down from
     * @param amount - amount we are drawing down
     * @param index - the index of the LP strategy
     */
    function drawDownAndCreateLP(uint256 id, uint256 amount, uint256 index, uint256 minimumCollateralValue) external {
        _onlyBorrowerOrAdmin();
        _checkIfUniswapV3(index);

        ILaaSEscrow.LiquidityPosition storage lp = liquidityPositions[index];

        _drawdown(id, amount);

        // ensure that that the escrow has the correct amount of tokens before creating the LP
        for (uint256 i = 0; i < lp.componentTokens.length; i++) {
            if (state.deposited[lp.componentTokens[i]].amount < lp.componentTokenAmounts[i]) {
                revert InsufficientFunds();
            }
        }

        // create LP position
        state._increaseLiquidity(liquidityPositions, index, lp.LpToken, lp.liquidityProvisionData, pool, minimumCollateralValue);
    }

    /**
     * @notice - drawdown from a credit position and then immediately increase liquidity on an LP position that was previously created
     * @param id - id of the credit position we are drawing down from
     * @param amount - amount we are drawing down
     * @param increaseLiquidityData - the calldata to add liquidity
     */
    function drawdownAndIncreaseLiquidity(uint256 id, uint256 amount, uint256 index, bytes memory increaseLiquidityData, uint256 minimumCollateralValue)
        external
    {
        _onlyBorrowerOrAdmin();
        _checkIfUniswapV3(index);

        address lpToken = liquidityPositions[index].LpToken;

        _drawdown(id, amount);

        // create LP position
        LineLib._forceApprove(_getCreditToken(id), pool, amount);
        state._increaseLiquidity(liquidityPositions, index, lpToken, increaseLiquidityData, pool, minimumCollateralValue);
        LineLib._forceApprove(_getCreditToken(id), pool, 0);
    }

    /**
     * @notice - draws down on a credit position and adds it as collateral to the escrow
     * @param id - id of the credit position we are drawing down from
     * @param amount - amount we are drawing down
     */
    function drawdown(uint256 id, uint256 amount) external {
        _onlyBorrowerOrAdmin();
        _drawdown(id, amount);
    }

    function _drawdown(uint256 id, uint256 amount) internal {
        // set minCratio to 0 here right quick
        minimumCollateralRatio = 0;

        // enable token as collateral
        address creditToken = _getCreditToken(id);
        state.enableCollateral(erc20Oracle, creditToken);

        _borrow(id, amount);

        state.deposited[creditToken].amount += amount;

        emit AddCollateral(creditToken, amount);

        // note we cant have a minimum collateral ratio until we have borrowed funds are they are stored as collateral.
        // note once we do this, we set the minCRatio to the desired amount
        minimumCollateralRatio = minimumCollateralRatioAfterDrawdown_;
        // check collateral ratio is greater than minCRatio
        _checkCollateralRatio();
    }

    /**
     * @notice - use funds in the escrow to deploy to our LP strategy using the preset call data in LiquidityPosition
     * @param index - the index of the LP strategy
     */
    function initializeLiquidity(uint256 index, uint256 minCollateralValue) external {
        _onlyBorrowerOrAdmin();
        _checkIfUniswapV3(index);
        state.initializeLiquidity(liquidityPositions, index, pool, minCollateralValue);
        _checkCollateralRatio();
    }

    /**
     * @notice - we add liquidity to an LP strategy
     * @dev - callable by borrower or admin
     * @param index - the index of the LP strategy
     * @param increaseLiquidityData - the calldata to add liquidity
     */
    function increaseLiquidity(uint256 index, bytes memory increaseLiquidityData, uint256 minimumCollateralValue) external {
        _onlyBorrowerOrAdmin();
        _checkIfUniswapV3(index);
        state.increaseLiquidity(liquidityPositions, index, pool, increaseLiquidityData, minimumCollateralValue);
        _checkCollateralRatio();
    }

    /**
     * @notice - we reduce liquidity from an LP strategy
     * @dev - callable by borrower or registered servicer address
     * @param index - the index of the LP strategy
     * @param decreaseLiquidityData - the calldata to remove liquidity if the borrower is calling (see LaaSEscrowLib.reduceLiquidity)
     */
    function reduceLiquidity(uint256 index, bytes memory decreaseLiquidityData, uint256 minimumCollateralValue) external {
        _checkIfUniswapV3(index);
        _onlyBorrowerOrServicer();
        state.reduceLiquidity(liquidityPositions, index, pool, minimumCollateralRatio, borrower, decreaseLiquidityData, minimumCollateralValue);
        _checkCollateralRatio();
    }

    /**
     * @notice - only callable when line is LIQUIDATABLE by a registered servicer
     * @notice - must remove all LP tokens
     * @param removeLiquidityData - the calldata to liquidate all LP tokens for component tokens
     * @param index - the index of the LP strategy
     * @param isDelayed - indicates whether or not the protocol we have deployed to has a delay when removing liquidity
     */
    function liquidatePosition(bytes memory removeLiquidityData, uint256 index, bool isDelayed, uint256 minimumCollateralValue) public {
        _checkIfUniswapV3(index);
        if (!_isLineServicer()) {
            revert CallerAccessDenied();
        }
        state.liquidatePosition(liquidityPositions, removeLiquidityData, index, pool, isDelayed, minimumCollateralValue);
        _checkCollateralRatio();
    }

    /**
     * @notice - see ILineOfCredit.borrow
     * @dev - only callable by borrower or admin
     */
    function _borrow(uint256 id, uint256 amount) internal override(SmartEscrow) returns (bool) {
        _onlyBorrowerOrAdmin();
        super._borrow(id, amount);
    }
}
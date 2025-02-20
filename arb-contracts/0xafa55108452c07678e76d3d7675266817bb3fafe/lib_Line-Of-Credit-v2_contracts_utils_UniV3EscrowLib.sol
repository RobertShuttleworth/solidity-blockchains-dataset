// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {IUniswapV3Oracle} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IUniswapV3Oracle.sol";
import {IEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrow.sol";
import {EscrowState, EscrowLib} from "./lib_Line-Of-Credit-v2_contracts_utils_EscrowLib.sol";
import {INonFungiblePositionManager} from "./lib_Line-Of-Credit-v2_contracts_interfaces_INonFungiblePositionManager.sol";
import {IERC721} from "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";
import {IUniswapV3Pool} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IUniswapPositionAppraiser.sol";

struct Univ3State {
    address owner;
    address nftPositionManager;
    address univ3Manager;
    uint256[] tokenIds;
    /// if lenders allow position as collateral. ensures uniqueness in tokenIds;
    mapping(uint256 => bool) enabled;
    mapping(uint256 => bool) deposited;
}

/**
 * @title   - UniV3EscrowLib
 * @author  - Credit Cooperative
 * @notice  - Core logic for managing UniV3 positions as collateral.
 */
library UniV3EscrowLib {
    using SafeERC20 for IERC20;
    using EscrowLib for EscrowState;

    event UniV3EnabledCollateral(uint256 tokenId);

    error InvalidRecipient();
    error RemainingLiquidity(uint128 liquidity);
    error InvalidCollateral();
    error AdminOnly();
    error CallerAccessDenied();
    error SlippageExceeded();
    error InsufficientTokens(address token, uint256 amountInsufficient);

    function _onlyManager(Univ3State storage self) private view {
        if (msg.sender != self.univ3Manager) revert IEscrow.CallerAccessDenied();
    }

    /**
     * see Escrow.updateOwner
     */
    function updateOwner(Univ3State storage self, address _owner) external returns (bool) {
        require(msg.sender == self.owner, "UniV3EscrowLib: Only owner can update owner");
        self.owner = _owner;
        return true;
    }

    // Collateral Funtions

    /**
     * see Escrow.addUniV3Position
     */
    function addUniV3Position(
        Univ3State storage self,
        EscrowState storage state,
        address token0,
        address token1,
        uint256 tokenId
    ) external returns (bool) {
        INonFungiblePositionManager.Position memory position =
            INonFungiblePositionManager(self.nftPositionManager).positions(tokenId);

        if (!state.isValidPair(token0, token1, position.fee)) revert InvalidCollateral();

        if (!self.enabled[tokenId]) {
            revert InvalidCollateral();
        }

        IERC721(self.nftPositionManager).transferFrom(msg.sender, address(this), tokenId);
        self.deposited[tokenId] = true;
        return true;
    }

    /**
     * see Escrow.releasePosition
     */
    function releasePosition(Univ3State storage self, address borrower, uint256 tokenId, address to)
        external
        returns (bool)
    {
        if (!self.deposited[tokenId]) {
            revert InvalidCollateral();
        }

        if (msg.sender != borrower && borrower != to) {
            revert CallerAccessDenied();
        }

        self.deposited[tokenId] = false;
        IERC721(self.nftPositionManager).transferFrom(address(this), to, tokenId);
    }

    /**
     * see Escrow.enablePosition
     */
    function enablePosition(
        Univ3State storage self,
        EscrowState storage state,
        address token0,
        address token1,
        uint256 tokenId,
        address oracle
    ) external returns (bool) {
        INonFungiblePositionManager.Position memory position =
            INonFungiblePositionManager(self.nftPositionManager).positions(tokenId);

        // todo get fee from position id
        if (!state.isValidPair(token0, token1, position.fee)) revert InvalidCollateral();
        return _enablePosition(self, tokenId, oracle);
    }

    function _enablePosition(Univ3State storage self, uint256 tokenId, address oracle) internal returns (bool) {
        bool isEnabled = self.enabled[tokenId];
        if (!isEnabled) {
            (uint256 price,) = IUniswapV3Oracle(oracle).getLatestAnswer(tokenId);
            if (price <= 0) {
                revert InvalidCollateral();
            }

            self.enabled[tokenId] = true;
            self.tokenIds.push(tokenId);

            emit UniV3EnabledCollateral(tokenId);
        }

        return true;
    }

    /**
     * see Escrow.liquidate
     */
    function liquidate(Univ3State storage self, uint256 tokenId, address to) external returns (bool) {
        if (!self.deposited[tokenId]) {
            revert InvalidCollateral();
        }

        self.deposited[tokenId] = false;

        IERC721(self.nftPositionManager).transferFrom(address(this), to, tokenId);

        emit IEscrow.RemovePosition(tokenId);

        return true;
    }

    function recoverUniv3Positions(Univ3State storage self, address to) external returns (bool) {
        uint256 len = self.tokenIds.length;
        for (uint256 i = 0; i < len; ++i) {
            uint256 tokenId = self.tokenIds[i];
            if (self.deposited[tokenId]) {
                self.deposited[tokenId] = false;
                IERC721(self.nftPositionManager).safeTransferFrom(address(this), to, tokenId);
            }
        }
        return true;
    }

    /**
     * see Escrow.getUniV3Positions
     */
    function getUniV3Positions(Univ3State storage self) external view returns (uint256[] memory) {
        uint256 len = self.tokenIds.length;

        // First, count how many positions are actually deposited
        uint256 count = 0;
        for (uint256 i = 0; i < len; ++i) {
            if (self.deposited[self.tokenIds[i]]) {
                count++;
            }
        }

        // Create an array of the correct size
        uint256[] memory positions = new uint256[](count);

        // Fill the array with deposited positions
        uint256 index = 0;
        for (uint256 i = 0; i < len; ++i) {
            uint256 tokenId = self.tokenIds[i];
            if (self.deposited[tokenId]) {
                positions[index] = tokenId;
                index++;
            }
        }

        return positions;
    }

    /**
     * @notice - gets the value of all the uniswap v3 positions escrowed
     * @param oracle - the address of the oracle used for pricing the erc20 tokens that comprise each uni v3 position
     * @return - the total value of all the UNI-v3 positions in the escrow
     */
    function getAllPositionsValue(Univ3State storage self, address oracle) external view returns (uint256) {
        uint256 collateralValue;
        // gas savings
        uint256 len = self.tokenIds.length;
        IUniswapV3Oracle o = IUniswapV3Oracle(oracle);

        for (uint256 i; i < len; ++i) {
            uint256 tokenId = self.tokenIds[i];
            if (self.deposited[tokenId]) {
                (uint256 deposit,) = o.getLatestAnswer(tokenId);
                collateralValue += deposit;
            }
        }
        return collateralValue;
    }

    /**
     * see Escrow.increaseLiquidity
     */
    function increaseLiquidity(
        Univ3State storage self,
        EscrowState storage state,
        INonFungiblePositionManager.IncreaseLiquidityParams calldata params
    ) external returns (bool) {
        _onlyManager(self);

        if (IERC721(self.nftPositionManager).ownerOf(params.tokenId) != address(this)) {
            revert CallerAccessDenied();
        }

        INonFungiblePositionManager.Position memory position =
            INonFungiblePositionManager(self.nftPositionManager).positions(params.tokenId);

        uint256 token0Before = IERC20(position.token0).balanceOf(address(this));
        uint256 token1Before = IERC20(position.token1).balanceOf(address(this));

        if (params.amount0Desired > token0Before || params.amount0Desired > state.deposited[position.token0].amount) {
            revert InsufficientTokens(position.token0, params.amount0Desired - token0Before);
        }
        if (params.amount1Desired > token1Before || params.amount1Desired > state.deposited[position.token1].amount) {
            revert InsufficientTokens(position.token1, params.amount1Desired - token1Before);
        }

        IERC20(position.token0).forceApprove(address(self.nftPositionManager), params.amount0Desired);
        IERC20(position.token1).forceApprove(address(self.nftPositionManager), params.amount1Desired);

        INonFungiblePositionManager(self.nftPositionManager).increaseLiquidity(params);

        IERC20(position.token0).forceApprove(address(self.nftPositionManager), 0);
        IERC20(position.token1).forceApprove(address(self.nftPositionManager), 0);

        uint256 token0After = IERC20(position.token0).balanceOf(address(this));
        uint256 token1After = IERC20(position.token1).balanceOf(address(this));

        if (state.enabledTokens[position.token0]) {
            state.deposited[position.token0].amount -= (token0Before - token0After);
            emit IEscrow.RemoveCollateral(position.token0, token0Before - token0After);
        }

        if (state.enabledTokens[position.token1]) {
            state.deposited[position.token1].amount -= (token1Before - token1After);
            emit IEscrow.RemoveCollateral(position.token1, token1Before - token1After);
        }

        return true;
    }

    /**
     * see Escrow.decreaseLiquidity
     */
    function decreaseLiquidity(
        Univ3State storage self,
        EscrowState storage state,
        INonFungiblePositionManager.DecreaseLiquidityParams calldata params
    ) external returns (bool) {
        _onlyManager(self);

        INonFungiblePositionManager positionManager = INonFungiblePositionManager(self.nftPositionManager);
        INonFungiblePositionManager.Position memory position =
            positionManager.positions(params.tokenId);

        uint256 token0Before = IERC20(position.token0).balanceOf(address(this));
        uint256 token1Before = IERC20(position.token1).balanceOf(address(this));

        positionManager.decreaseLiquidity(params);

        INonFungiblePositionManager.CollectParams memory collectParams = INonFungiblePositionManager.CollectParams(
            params.tokenId, address(this), type(uint128).max, type(uint128).max
        );

        // Collect all Fees
        positionManager.collect(collectParams);

        uint256 token0After = IERC20(position.token0).balanceOf(address(this));
        uint256 token1After = IERC20(position.token1).balanceOf(address(this));

        if (state.enabledTokens[position.token0]) {
            state.deposited[position.token0].amount += (token0After - token0Before);
            emit IEscrow.AddCollateral(position.token0, token0After - token0Before);
        }

        if (state.enabledTokens[position.token1]) {
            state.deposited[position.token1].amount += (token1After - token1Before);
            emit IEscrow.AddCollateral(position.token1, token1After - token1Before);
        }

        return true;
    }

    /**
     * see Escrow.collect
     */
    function collect(
        Univ3State storage self,
        EscrowState storage state,
        INonFungiblePositionManager.CollectParams calldata params
    ) external returns (bool) {
        _onlyManager(self);
        if (params.recipient != address(this)) {
            revert InvalidRecipient();
        }
        INonFungiblePositionManager.Position memory position =
            INonFungiblePositionManager(self.nftPositionManager).positions(params.tokenId);

        uint256 token0Before = IERC20(position.token0).balanceOf(address(this));
        uint256 token1Before = IERC20(position.token1).balanceOf(address(this));

        INonFungiblePositionManager(self.nftPositionManager).collect(params);

        uint256 token0After = IERC20(position.token0).balanceOf(address(this));
        uint256 token1After = IERC20(position.token1).balanceOf(address(this));

        if (state.enabledTokens[position.token0]) {
            state.deposited[position.token0].amount += (token0After - token0Before);
            emit IEscrow.AddCollateral(position.token0, token0After - token0Before);
        }

        if (state.enabledTokens[position.token1]) {
            state.deposited[position.token1].amount += (token1After - token1Before);
            emit IEscrow.AddCollateral(position.token1, token1After - token1Before);
        }

        return true;
    }

    /**
     * see Escrow.burn
     */
    function burn(
        Univ3State storage self,
        EscrowState storage state,
        INonFungiblePositionManager.DecreaseLiquidityParams calldata params
    ) external returns (bool) {
        if (IERC721(self.nftPositionManager).ownerOf(params.tokenId) != address(this)) {
            revert CallerAccessDenied();
        }

        INonFungiblePositionManager positionManager = INonFungiblePositionManager(self.nftPositionManager);
        INonFungiblePositionManager.Position memory position = positionManager.positions(params.tokenId);

        uint256 token0Before = IERC20(position.token0).balanceOf(address(this));
        uint256 token1Before = IERC20(position.token1).balanceOf(address(this));

        //Set minimums of both amounts to zero in DecreaseLiquidityParams it's a one sided position
        INonFungiblePositionManager.DecreaseLiquidityParams memory decreaseLiquidityParams = INonFungiblePositionManager
            .DecreaseLiquidityParams(
            params.tokenId, position.liquidity, params.amount0Min, params.amount1Min, params.deadline
        );

        positionManager.decreaseLiquidity(decreaseLiquidityParams);
        position = positionManager.positions(params.tokenId);
        if (position.liquidity != 0) {
            revert RemainingLiquidity(position.liquidity);
        }

        // For reasons unknown you need to decrease liquidity, THEN collect fees before you can burn the FNFT
        INonFungiblePositionManager.CollectParams memory collectParams = INonFungiblePositionManager.CollectParams(
            params.tokenId, address(this), type(uint128).max, type(uint128).max
        );

        // Collect all Fees
        positionManager.collect(collectParams);

        INonFungiblePositionManager(self.nftPositionManager).burn(params.tokenId);

        self.deposited[params.tokenId] = false;

        uint256 token0After = IERC20(position.token0).balanceOf(address(this));
        uint256 token1After = IERC20(position.token1).balanceOf(address(this));

        // Increased deposited because we're taking funds out of the nft and INTO the escrow
        if (state.enabledTokens[position.token0]) {
            state.deposited[position.token0].amount += (token0After - token0Before);
            emit IEscrow.AddCollateral(position.token0, token0After - token0Before);
        }

        if (state.enabledTokens[position.token1]) {
            state.deposited[position.token1].amount += (token1After - token1Before);
            emit IEscrow.AddCollateral(position.token1, token1After - token1Before);
        }

        return true;
    }

    /**
     * see Escrow.mint
     */
    function mint(
        Univ3State storage self,
        EscrowState storage state,
        address pool,
        INonFungiblePositionManager.MintParams memory params,
        address uniV3Oracle
    ) external returns (bool) {
        _onlyManager(self);
        address token0 = IUniswapV3Pool(pool).token0();
        address token1 = IUniswapV3Pool(pool).token1();

        uint256 token0Before = IERC20(token0).balanceOf(address(this));
        uint256 token1Before = IERC20(token1).balanceOf(address(this));

        if (params.recipient != address(this)) {
            revert CallerAccessDenied();
        }

        if (params.amount0Desired > token0Before || params.amount0Desired > state.deposited[token0].amount) {
            revert InsufficientTokens(token0, params.amount0Desired - token0Before);
        }
        if (params.amount1Desired > token1Before || params.amount1Desired > state.deposited[token1].amount) {
            revert InsufficientTokens(token1, params.amount1Desired - token1Before);
        }

        IERC20(token0).forceApprove(address(self.nftPositionManager), params.amount0Desired);
        IERC20(token1).forceApprove(address(self.nftPositionManager), params.amount1Desired);

        (uint256 tokenId,,,) = INonFungiblePositionManager(self.nftPositionManager).mint(params);

        IERC20(token0).forceApprove(address(self.nftPositionManager), 0);
        IERC20(token1).forceApprove(address(self.nftPositionManager), 0);

        _enablePosition(self, tokenId, uniV3Oracle);
        self.deposited[tokenId] = true;

        uint256 token0After = IERC20(token0).balanceOf(address(this));
        uint256 token1After = IERC20(token1).balanceOf(address(this));

        // Decreased deposited because we're sending funds OUT of escrow and into the position
        if (state.enabledTokens[token0]) {
            state.deposited[token0].amount -= (token0Before - token0After);
            emit IEscrow.RemoveCollateral(token0, token0Before - token0After);
        }

        if (state.enabledTokens[token1]) {
            state.deposited[token1].amount -= (token1Before - token1After);
            emit IEscrow.RemoveCollateral(token1, token1Before - token1After);
        }

        return true;
    }
}
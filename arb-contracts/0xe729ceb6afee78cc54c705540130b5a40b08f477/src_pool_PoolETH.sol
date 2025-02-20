// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {SafeTransferLib} from "./solmate_utils_SafeTransferLib.sol";
import {Pool} from "./src_pool_Pool.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";
import {ICurve} from "./src_bonding-curves_ICurve.sol";
import {Price, PoolInfo} from "./src_lib_Types.sol";
import {Calculations} from "./src_lib_Lib.sol";

/**
    @title An NFT/Token pair where the token is ETH
    @author boredGenius and 0xmons
 */
abstract contract PoolETH is Pool {
    using SafeTransferLib for address payable;
    using Calculations for uint256[];

    uint256 internal constant IMMUTABLE_PARAMS_LENGTH = 61;

    /// @inheritdoc Pool
    //note this function might become responsible to
    //transfer royalties based on the value defined and retrieved by the bonding curve.
    function _pullTokenInputAndPayProtocolFee(
        uint256 inputAmount,
        bool /*isRouter*/,
        address /*routerCaller*/,
        uint256 protocolFee
    ) internal override {
        require(msg.value >= inputAmount, "Sent too little ETH");
        IPoolFactoryLike _factory = factory();

        // Take protocol fee
        if (protocolFee > 0) {
            // Round down to the actual ETH balance if there are numerical stability issues with the bonding curve calculations
            if (protocolFee > address(this).balance) {
                protocolFee = address(this).balance;
            }

            if (protocolFee > 0) {
                payable(address(_factory)).safeTransferETH(protocolFee);
            }
        }
    }

    /// @inheritdoc Pool
    function _refundTokenToSender(uint256 inputAmount) internal override {
        // Give excess ETH back to caller
        if (msg.value > inputAmount) {
            payable(msg.sender).safeTransferETH(msg.value - inputAmount);
        }
    }

    /// @inheritdoc Pool
    function _sendTokenOutput(
        address payable tokenRecipient,
        uint256 outputAmount
    ) internal override {
        // Send ETH to caller
        if (outputAmount > 0) {
            tokenRecipient.safeTransferETH(outputAmount);
        }
    }

    /// @inheritdoc Pool
    // @dev see PoolCloner for params length calculation
    function _immutableParamsLength() internal pure override returns (uint256) {
        return IMMUTABLE_PARAMS_LENGTH;
    }

    /**
        @notice Allows any one with collection balance to deposit both sides liquidity to pool
        and get LPF and LPN issued to wallet which will be used to withdraw liquidity + pool fee share
        msg.value amount of ETH/Token to deposit
        @param idList collection tokenIds list that user owns
        @param rarities rarity used for NFT
        @param quantities for 1155 pools value may be greater then length array should be of same length as of ids
        @param signature admin signature for rarity values used
     */
    function addLiquidityWithSignature(
        uint256[] calldata idList,
        uint256[] calldata rarities,
        uint256[] calldata quantities,
        bytes calldata signature
    ) external payable {
        require(
            factory().verifyRaritySignature(
                idList,
                rarities,
                address(nft()),
                signature
            ),
            "ARL: Invalid signature"
        );
        uint128 sumRarity = getSumOfRarity(rarities, quantities);
        _addRemoveLiquidity(msg.value, idList, quantities, sumRarity, 1);
        emit LiquidityAdded(msg.value, sumRarity, idList, quantities, rarities);
    }

    /**
        @notice Holders of LPN and LPF tokens are able to withdraw liquidity.
        @param tokenAmount amount of tokens to withdraw
        @param idList collection tokenIds list that user owns
        @param rarities rarity used for NFT
     */
    function removeLiquidityWithSignature(
        uint256 tokenAmount,
        uint256[] calldata idList,
        uint256[] calldata rarities,
        uint256[] calldata quantities,
        bytes calldata signature
    ) external {
        require(
            factory().verifyRaritySignature(
                idList,
                rarities,
                address(nft()),
                signature
            ),
            "ARL: Invalid signature"
        );
        uint128 sumRarity = getSumOfRarity(rarities, quantities);
        //last argument is logical flag for remove liquidity it is 0
        _addRemoveLiquidity(tokenAmount, idList, quantities, sumRarity, 0);
        emit LiquidityRemoved(
            tokenAmount,
            sumRarity,
            idList,
            quantities,
            rarities
        );
    }

    function getReserves()
        internal
        view
        override
        returns (uint256 reserveToken, uint128 reserveNft)
    {
        reserveNft = poolManager.poolReservesNft();
        reserveToken = payable(address(this)).balance;
    }
}
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {SafeTransferLib} from "./solmate_utils_SafeTransferLib.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IERC20Metadata} from "./openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";

import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {Pool} from "./src_pool_Pool.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";
import {IRouter} from "./src_router_IRouter.sol";
import {ICurve} from "./src_bonding-curves_ICurve.sol";
import {Price} from "./src_lib_Types.sol";
import {console} from "./hardhat_console.sol";

/**
    @title An NFT/Token pair where the token is an ERC20
    @author boredGenius and 0xmons
 */
abstract contract PoolERC20 is Pool {
    using SafeERC20 for IERC20;

    uint256 internal constant IMMUTABLE_PARAMS_LENGTH = 81;

    /**
        @notice Returns the ERC20 token associated with the pair
        @dev See PoolCloner for an explanation on how this works
     */
    function token() public pure returns (IERC20 _token) {
        uint256 paramsLength = _immutableParamsLength();
        assembly {
            _token := shr(
                0x60,
                calldataload(add(sub(calldatasize(), paramsLength), 61))
            )
        }
    }

    /// @inheritdoc Pool
    function _pullTokenInputAndPayProtocolFee(
        uint256 inputAmount,
        bool isRouter,
        address routerCaller,
        uint256 protocolFee
    ) internal override {
        require(msg.value == 0, "ERC20 pair");

        IERC20 _token = token();
        IPoolFactoryLike _factory = factory();
        address protocolFeeRecipient = _factory.protocolFeeRecipient();
        uint256 decimals = IERC20Metadata(address(_token)).decimals();
        inputAmount = (inputAmount / (10 ** (18 - decimals)));
        protocolFee = (protocolFee / (10 ** (18 - decimals)));
        if (isRouter) {
            // Verify if router is allowed
            IRouter router = IRouter(payable(msg.sender));
            console.log("msg.sender:", msg.sender);
            // Locally scoped to avoid stack too deep
            {
                (bool routerAllowed, ) = _factory.routerStatus(router);
                require(routerAllowed, "P: router not allowed");
            }

            // Cache state and then call router to transfer tokens from user
            if (protocolFee > 0) {
                uint256 beforeBalance = _token.balanceOf(
                    address(protocolFeeRecipient)
                ) * (10 ** (18 - decimals));
                router.pairTransferERC20From(
                    _token,
                    routerCaller,
                    address(protocolFeeRecipient),
                    protocolFee,
                    pairVariant()
                );
                // Verify token transfer (protect pair against malicious router)
                require(
                    _token.balanceOf(address(protocolFeeRecipient)) -
                        beforeBalance ==
                        protocolFee,
                    "P: Fee not transferred in"
                );
            }
            // Note: no check for factory balance's because router is assumed to be set by factory owner
            // so there is no incentive to *not* pay protocol fee
            // pull tokens input
            router.pairTransferERC20From(
                _token,
                routerCaller,
                address(this),
                inputAmount,
                pairVariant()
            );
        } else {
            // Transfer tokens directly
            _token.safeTransferFrom(msg.sender, address(this), inputAmount);

            // Take protocol fee (if it exists)
            if (protocolFee > 0) {
                _token.safeTransferFrom(
                    msg.sender,
                    address(_factory),
                    protocolFee
                );
            }
        }
    }

    /// @inheritdoc Pool
    function _refundTokenToSender(uint256 inputAmount) internal override {
        // Do nothing since we transferred the exact input amount
    }

    /// @inheritdoc Pool
    function _sendTokenOutput(
        address payable tokenRecipient,
        uint256 outputAmount
    ) internal override {
        // Send tokens to caller
        IERC20 _token = token();
        if (outputAmount > 0) {
            outputAmount =
                outputAmount /
                (10 ** (18 - IERC20Metadata(address(_token)).decimals()));
            console.log("output:", outputAmount);
            _token.safeTransfer(tokenRecipient, outputAmount);
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
        uint256 tokenAMount,
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
        _addRemoveLiquidity(tokenAMount, idList, quantities, sumRarity, 1);
        emit LiquidityAdded(
            tokenAMount,
            sumRarity,
            idList,
            quantities,
            rarities
        );
    }

    /**
        @notice Holders of LPN and LPF tokens are able to withdraw liquidity.
        @param tokenAmount amount of tokens to withdraw
        @param idList collection tokenIds list that user owns
        @param rarities rarity used for NFT
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
        IERC20 _token = token();
        reserveNft = poolManager.poolReservesNft();
        reserveToken =
            (_token.balanceOf(address(this))) *
            10 ** (18 - IERC20Metadata(address(_token)).decimals());
    }
}
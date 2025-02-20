// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
//TODO change naming conventions for "Pool" to "Pool"
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {IERC1155} from "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";

import {ERC1155Holder} from "./openzeppelin_contracts_token_ERC1155_utils_ERC1155Holder.sol";

import {OwnableWithTransferCallback} from "./src_lib_OwnableWithTransferCallback.sol";
import {ReentrancyGuard} from "./src_lib_ReentrancyGuard.sol";
import {ILiquiDevilLp} from "./src_lp-tokens_interfaces_ILiquiDevilLp.sol";

import {ICurve} from "./src_bonding-curves_ICurve.sol";
import {IRouter} from "./src_router_IRouter.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";
import {Price, PoolInfo} from "./src_lib_Types.sol";
import {Calculations} from "./src_lib_Lib.sol";
import {IPoolManager} from "./src_pool_interfaces_IPoolManager.sol";

/// @title The base contract for an NFT/TOKEN AMM pair
/// @author Liqui-devil
/// @notice This implements the core swap logic from NFT to TOKEN
abstract contract Pool is
    OwnableWithTransferCallback,
    ReentrancyGuard,
    ERC1155Holder
{
    using Calculations for uint256[];

    //contract to manage pool storage
    IPoolManager public poolManager;

    //make it configureable by the owner
    uint256 public constant MINIMUM_ETH_BALANCE = 0.00001e18;
    uint256 public constant PRICE_STRATEGY_ORACLE = 0;
    uint256 public constant PRICE_STRATEGY_SIGNATURE = 1;

    // Events
    event SwapNFTInPool(
        uint256[] nftids,
        uint256[] quantities,
        uint256[] rarities,
        uint128 sumRarity,
        uint256 outputAmount
    );
    event SwapNFTOutPool(
        uint256[] nftids,
        uint256[] quantities,
        uint256[] rarities,
        uint128 sumRarity,
        uint256 inputAmount
    );

    event LiquidityAdded(
        uint256 tokenAmount,
        uint256 sumRarity,
        uint256[] nftids,
        uint256[] quantities,
        uint256[] rarities
    );
    event LiquidityRemoved(
        uint256 tokenAmount,
        uint256 sumRarity,
        uint256[] nftids,
        uint256[] quantities,
        uint256[] rarities
    );
    // Parameterized Errors
    error BondingCurveError(Price.Error error);

    /**
        @notice Called during pair creation to set initial parameters
        @dev Only called once by factory to initialize.
        We verify this by making sure that the current owner is address(0). 
        The Ownable library we use disallows setting the owner to be address(0), so this condition
        should only be valid before the first initialize call. 
        @param _owner The owner of the pair
        @param initPoolParams._royaltyReciever The address that will receive the TOKEN or NFT sent to this pair during swaps. NOTE: If set to address(0), they will go to the pair itself.
                initPoolParams._fee The initial % fee taken, if this is a trade pair 
                initPoolParams._curveAttributes attributes relevent to used bonding curve if not present in array will be reverted by using validateCurveAttributes
                initPoolParams.isVariableDelta Defines if delta for pool is variable after every add liquidity and remove liquidity
                initPoolParams.implementation defines lp implementation address
    */
    function initialize(
        address _owner,
        PoolInfo.InitPoolParams calldata initPoolParams,
        address _lpfToken,
        address _lpnToken,
        IPoolManager _poolManager
    ) external {
        require(owner() == address(0), "CPE: Initialized");

        __Ownable_init(_owner);
        __ReentrancyGuard_init();
        poolManager = _poolManager;
        poolManager.initialize(initPoolParams, _lpfToken, _lpnToken);

        PoolInfo.PoolType _poolType = poolType();
        require(
            _poolType == PoolInfo.PoolType.PRIVATE ||
                _poolType == PoolInfo.PoolType.PUBLIC,
            "CPE: Wrong pool type"
        );
        require(
            poolManager.is721Contract(nft()) ||
                poolManager.is1155Contract(nft()),
            "CPE: NFT standard not found"
        );
    }

    function buyNftsWithSignature(
        PoolInfo.SwapWithSignatureParams calldata swapWithSignatureParams,
        bool isRouter,
        address routerCaller
    ) external payable returns (uint256 inputAmount) {
        //conditional
        require(
            factory().verifyRaritySignature(
                swapWithSignatureParams.nftIds,
                swapWithSignatureParams.rarities,
                address(nft()),
                swapWithSignatureParams.raritySignature
            ),
            "BS: Invalid signature"
        );

        uint128 sumRarity = getSumOfRarity(
            swapWithSignatureParams.rarities,
            swapWithSignatureParams.quantities
        );

        //call to innner swap with rarities
        inputAmount = _buyNfts(
            PoolInfo.SwapParams(
                swapWithSignatureParams.nftIds,
                swapWithSignatureParams.quantities,
                sumRarity,
                swapWithSignatureParams.quotePrice,
                swapWithSignatureParams.recipient,
                swapWithSignatureParams.slippage
            ),
            isRouter,
            routerCaller
        );

        emit SwapNFTOutPool(
            swapWithSignatureParams.nftIds,
            swapWithSignatureParams.quantities,
            swapWithSignatureParams.rarities,
            sumRarity,
            inputAmount
        );
    }

    function _buyNfts(
        PoolInfo.SwapParams memory swapParams,
        bool isRouter,
        address routerCaller
    ) internal returns (uint256 inputAmount) {
        // Store locally to remove extra calls
        IPoolFactoryLike _factory = factory();
        ICurve _bondingCurve = bondingCurve();

        // Call bonding curve for pricing information
        uint256 protocolFee;
        uint256 royaltyFee;

        (
            protocolFee,
            inputAmount,
            royaltyFee
        ) = _calculateBuyInfoAndUpdatePoolParams(
            swapParams.sumRarity,
            swapParams.quotePrice,
            swapParams.slippage,
            _bondingCurve,
            _factory
        );

        _pullTokenInputAndPayProtocolFee(
            inputAmount - royaltyFee,
            isRouter,
            routerCaller,
            protocolFee
        );

        _sendTokenOutput(poolManager.getRoyaltyReciever(), royaltyFee);

        //nftSender = pool, nftRecipient = user
        _sendSpecificNFTsToRecipient(
            nft(),
            swapParams.recipient,
            swapParams.nftIds,
            swapParams.quantities
        );

        _refundTokenToSender(inputAmount);
    }

    function sellNftsWithSignature(
        PoolInfo.SwapWithSignatureParams calldata swapWithSignatureParams,
        bool isRouter,
        address routerCaller
    ) external payable returns (uint256 outputAmount) {
        //conditional
        require(
            factory().verifyRaritySignature(
                swapWithSignatureParams.nftIds,
                swapWithSignatureParams.rarities,
                address(nft()),
                swapWithSignatureParams.raritySignature
            ),
            "Invalid signature"
        );
        uint128 sumRarity = getSumOfRarity(
            swapWithSignatureParams.rarities,
            swapWithSignatureParams.quantities
        );

        //call to innner swap with rarities
        outputAmount = _sellNfts(
            PoolInfo.SwapParams(
                swapWithSignatureParams.nftIds,
                swapWithSignatureParams.quantities,
                sumRarity,
                swapWithSignatureParams.quotePrice,
                payable(swapWithSignatureParams.recipient),
                swapWithSignatureParams.slippage
            ),
            isRouter,
            routerCaller
        );
        emit SwapNFTInPool(
            swapWithSignatureParams.nftIds,
            swapWithSignatureParams.quantities,
            swapWithSignatureParams.rarities,
            sumRarity,
            outputAmount
        );
    }

    // /**
    //     @notice Sends a set of NFTs to the pair in exchange for token
    //     @dev To compute the amount of token to that will be received, call bondingCurve.getSellInfo.
    //     @param nftIds The list of IDs of the NFTs to sell to the pair
    //     @param minExpectedTokenOutput The minimum acceptable token received by the sender. If the actual
    //     amount is less than this value, the transaction will be reverted.
    //     @param tokenRecipient The recipient of the token output
    //     @param isRouter True if calling from Router, false otherwise. Not used for
    //     ETH pairs.
    //     @param routerCaller If isRouter is true, ERC20 tokens will be transferred from this address. Not used for
    //     ETH pairs.
    //     @return outputAmount The amount of token received
    //  */
    // function sellNfts(
    //     uint256[] calldata nftIds,
    //     uint256[] calldata quantities,
    //     uint256 minExpectedTokenOutput,
    //     address payable tokenRecipient,
    //     uint256 slippage,
    //     bool isRouter,
    //     address routerCaller
    // ) external virtual nonReentrant returns (uint256 outputAmount) {
    //     //calculate sum of rarity with already defined nft rarity values
    //     uint128 sumRarity = this
    //         .getRarityValues(address(nft()), nftIds)
    //         .getSumOfUintArray();
    //     //call to innner swap with rarities
    //     outputAmount = _sellNfts(
    //         PoolInfo.SwapParams(
    //             nftIds,
    //             quantities,
    //             sumRarity,
    //             minExpectedTokenOutput,
    //             tokenRecipient,
    //             slippage
    //         ),
    //         isRouter,
    //         routerCaller
    //     );
    // }

    /**
        @notice Sends a set of NFTs to the pair in exchange for token
        @dev To compute the amount of token to that will be received, call bondingCurve.getSellInfo.
        @param swapParams swap params @inheritdoc Types.PoolInfo.SwapParams
        @param isRouter True if calling from Router, false otherwise. Not used for
        ETH pairs.
        @param routerCaller If isRouter is true, ERC20 tokens will be transferred from this address. Not used for
        ETH pairs.
        @return outputAmount The amount of token received
     */
    function _sellNfts(
        PoolInfo.SwapParams memory swapParams,
        bool isRouter,
        address routerCaller
    ) internal returns (uint256 outputAmount) {
        // Store locally to remove extra calls
        IPoolFactoryLike _factory = factory();
        ICurve _bondingCurve = bondingCurve();

        // Call bonding curve for pricing information
        uint256 protocolFee;
        uint256 royaltyFee;
        (
            protocolFee,
            outputAmount,
            royaltyFee
        ) = _calculateSellInfoAndUpdatePoolParams(
            swapParams.sumRarity,
            swapParams.quotePrice,
            swapParams.slippage,
            _bondingCurve,
            _factory
        );
        //pay user, protocol and royalty address the respective amounts
        _sendTokenOutput(payable(swapParams.recipient), outputAmount);
        _sendTokenOutput(payable(address(_factory)), protocolFee);
        _sendTokenOutput(poolManager.getRoyaltyReciever(), royaltyFee);

        _recieveSpecificNFTsFromSender(
            nft(),
            isRouter ? routerCaller : msg.sender,
            swapParams.nftIds,
            swapParams.quantities
        );
    }

    /**
     * View functions
     */

    /**
        @dev Used as read function to query the bonding curve for buy pricing info
        @param idList The token ids of NFTs to buy from the pair
        @param rarities Rarity values for nft stored p2p storage
        @param signature admin wallet signature for rarity values used
    */
    function getBuyNFTQuoteWithSignature(
        uint256[] calldata idList,
        uint256[] calldata rarities,
        uint256[] calldata quantities,
        bytes calldata signature
    ) external view returns (Price.PriceOutput memory priceOutput) {
        require(
            factory().verifyRaritySignature(
                idList,
                rarities,
                address(nft()),
                signature
            ),
            "Invalid signature"
        );
        uint128 sumRarity = getSumOfRarity(rarities, quantities);
        return _getBuyNFTQuote(sumRarity);
    }

    // /**
    //     @dev Used as read function to query the bonding curve for buy pricing info
    //     @param idList The token ids of NFTs to buy from the pair
    // */
    // function getBuyNFTQuote(
    //     uint256[] calldata idList
    // ) external view returns (Price.PriceOutput memory priceOutput) {
    //     return
    //         _getBuyNFTQuote(
    //             this.getRarityValues(address(nft()), idList).getSumOfUintArray()
    //         );
    // }

    function _getBuyNFTQuote(
        uint128 sumRarity
    ) internal view returns (Price.PriceOutput memory priceOutput) {
        // find sum of all rarityValues for items in this trade
        return
            bondingCurve().getBuyInfo(
                Price.PriceInputParams(
                    poolManager.getCurveAttributes(),
                    poolManager.poolFeeMultiplier(),
                    factory().protocolFeeMultiplier(),
                    poolManager.royaltyFeeMultiplier(),
                    sumRarity
                )
            );
    }

    /**
        @dev Used as read function to query the bonding curve for sell pricing info
        @param idList The token ids of NFTs to buy from the pair
        @param rarities Rarity values for nft stored p2p storage
        @param signature admin wallet signature for rarity values used
     */
    function getSellNFTQuoteWithSignature(
        uint256[] calldata idList,
        uint256[] calldata rarities,
        uint256[] calldata quantities,
        bytes calldata signature
    ) external view returns (Price.PriceOutput memory priceOutput) {
        require(
            factory().verifyRaritySignature(
                idList,
                rarities,
                address(nft()),
                signature
            ),
            "Invalid signature"
        );
        uint128 sumRarity = getSumOfRarity(rarities, quantities);
        return _getSellNFTQuote(sumRarity);
    }

    // /**
    //     @dev Used as read function to query the bonding curve for sell pricing info
    //     @param idList The token ids of NFTs to buy from the pair
    // */
    // function getSellNFTQuote(
    //     uint256[] calldata idList
    // ) external view returns (Price.PriceOutput memory priceOutput) {
    //     return
    //         _getSellNFTQuote(
    //             this.getRarityValues(address(nft()), idList).getSumOfUintArray()
    //         );
    // }

    function _getSellNFTQuote(
        uint128 sumRarity
    ) internal view returns (Price.PriceOutput memory priceOutput) {
        priceOutput = bondingCurve().getSellInfo(
            Price.PriceInputParams(
                poolManager.getCurveAttributes(),
                poolManager.poolFeeMultiplier(),
                factory().protocolFeeMultiplier(),
                poolManager.royaltyFeeMultiplier(),
                sumRarity
            )
        );
    }

    /**
        @notice Returns all NFT IDs held by the pool
     */
    function getAllHeldIds() external view virtual returns (uint256[] memory);

    /**
        @notice Returns the pair's variant (NFT is enumerable or not, pair uses ETH or ERC20)
     */
    function pairVariant()
        public
        pure
        virtual
        returns (IPoolFactoryLike.PoolVariant);

    function factory() public pure returns (IPoolFactoryLike _factory) {
        uint256 paramsLength = _immutableParamsLength();
        assembly {
            _factory := shr(
                0x60,
                calldataload(sub(calldatasize(), paramsLength))
            )
        }
    }

    /**
        @notice Returns the type of bonding curve that parameterizes the pair
     */
    function bondingCurve() public pure returns (ICurve _bondingCurve) {
        uint256 paramsLength = _immutableParamsLength();
        assembly {
            _bondingCurve := shr(
                0x60,
                calldataload(add(sub(calldatasize(), paramsLength), 20))
            )
        }
    }

    /**
        @notice Returns the NFT collection that parameterizes the pair
     */
    function nft() public pure returns (address _nft) {
        uint256 paramsLength = _immutableParamsLength();
        assembly {
            _nft := shr(
                0x60,
                calldataload(add(sub(calldatasize(), paramsLength), 40))
            )
        }
    }

    /**
        @notice Returns the pair's type (PUBLIC/PRIVATE)
     */
    function poolType() public pure returns (PoolInfo.PoolType _poolType) {
        uint256 paramsLength = _immutableParamsLength();
        assembly {
            _poolType := shr(
                0xf8,
                calldataload(add(sub(calldatasize(), paramsLength), 60))
            )
        }
    }

    /**
     * Internal functions
     */

    /**
        @notice Calculates the amount needed to be sent into the pair for a buy and adjusts spot price or delta if necessary
        @param sumRarity Total rarity in trade
        @param maxExpectedTokenInput The maximum acceptable cost from the sender. If the actual
        amount is greater than this value, the transaction will be reverted.
        @param protocolFee The percentage of protocol fee to be taken, as a percentage
        @return protocolFee The amount of tokens to send as protocol fee
        @return inputAmount The amount of tokens total tokens receive
     */
    function _calculateBuyInfoAndUpdatePoolParams(
        uint128 sumRarity,
        uint256 maxExpectedTokenInput,
        uint256 slippage,
        ICurve _bondingCurve,
        IPoolFactoryLike _factory
    )
        internal
        returns (uint256 protocolFee, uint256 inputAmount, uint256 royaltyFee)
    {
        uint128[] memory currentCurveAttributes = poolManager
            .getCurveAttributes();

        Price.PriceOutput memory priceOutput = _bondingCurve.getBuyInfo(
            Price.PriceInputParams(
                currentCurveAttributes,
                poolManager.poolFeeMultiplier(),
                _factory.protocolFeeMultiplier(),
                poolManager.royaltyFeeMultiplier(),
                sumRarity
            )
        );

        // Revert if bonding curve had an error
        if (priceOutput.error != Price.Error.OK) {
            revert BondingCurveError(priceOutput.error);
        }
        inputAmount = priceOutput.price;
        protocolFee = priceOutput.protocolFee;
        royaltyFee = priceOutput.royaltyFee;
        // Revert if input is more than expected
        //
        require(
            inputAmount <=
                maxExpectedTokenInput +
                    (maxExpectedTokenInput * slippage) /
                    10000,
            "BS: In too less tokens"
        );

        poolManager.updatePoolParams(
            priceOutput.newCurveAttributes,
            priceOutput.poolFee,
            1
        );
        //as buy from pool means nft reserve is reduced passing 0 as flag
        poolManager.addRemoveReserveNft(sumRarity, 0);
    }

    /**
        @notice Calculates the amount needed to be sent by the pair for a sell and adjusts spot price or delta if necessary
        @param sumRarity Total rarity in trade
        @param minExpectedTokenOutput The minimum acceptable token received by the sender. If the actual
        amount is less than this value, the transaction will be reverted.
        @param protocolFee The percentage of protocol fee to be taken, as a percentage
        @return protocolFee The amount of tokens to send as protocol fee
        @return outputAmount The amount of tokens total tokens receive
     */
    function _calculateSellInfoAndUpdatePoolParams(
        uint128 sumRarity,
        uint256 minExpectedTokenOutput,
        uint256 slippage,
        ICurve _bondingCurve,
        IPoolFactoryLike _factory
    )
        internal
        returns (uint256 protocolFee, uint256 outputAmount, uint256 royaltyFee)
    {
        uint128[] memory currentCurveAttributes = poolManager
            .getCurveAttributes();
        Price.PriceOutput memory priceOutput = _bondingCurve.getSellInfo(
            Price.PriceInputParams(
                currentCurveAttributes,
                poolManager.poolFeeMultiplier(),
                _factory.protocolFeeMultiplier(),
                poolManager.royaltyFeeMultiplier(),
                sumRarity
            )
        );

        // Revert if bonding curve had an error
        if (priceOutput.error != Price.Error.OK) {
            revert BondingCurveError(priceOutput.error);
        }

        outputAmount = priceOutput.price;
        protocolFee = priceOutput.protocolFee;
        // Revert if output is too little
        require(
            //10 >= (10 - 1) = 9
            outputAmount >=
                minExpectedTokenOutput -
                    ((minExpectedTokenOutput * slippage) / 10000),
            "BS: exceeds slippage"
        );
        (uint256 poolReserveToken, ) = getReserves();
        require(
            outputAmount < poolReserveToken - poolManager.poolFeeAccrued(),
            "BS: Not enough reserve"
        );
        //arrage return data
        outputAmount = priceOutput.price;
        protocolFee = priceOutput.protocolFee;
        royaltyFee = priceOutput.royaltyFee;

        //Track Total Pool Fee Updates
        poolManager.updatePoolParams(
            priceOutput.newCurveAttributes,
            priceOutput.poolFee,
            1
        );

        //as sell to pool means nft reserve is added passing 1 as flag
        poolManager.addRemoveReserveNft(sumRarity, 1);
    }

    /**
        @notice Pulls the token input of a trade from the trader and pays the protocol fee.
        @param inputAmount The amount of tokens to be sent
        @param isRouter Whether or not the caller is Router
        @param routerCaller If called from Router, store the original caller
        @param protocolFee The protocol fee to be paid
     */
    function _pullTokenInputAndPayProtocolFee(
        uint256 inputAmount,
        bool isRouter,
        address routerCaller,
        uint256 protocolFee
    ) internal virtual;

    /**
        @notice Sends excess tokens back to the caller (if applicable)
        @dev We send ETH back to the caller even when called from Router because we do an aggregate slippage check for certain bulk swaps. (Instead of sending directly back to the router caller) 
        Excess ETH sent for one swap can then be used to help pay for the next swap.
     */
    function _refundTokenToSender(uint256 inputAmount) internal virtual;

    /**
        @notice Sends tokens to a recipient
        @param tokenRecipient The address receiving the tokens
        @param outputAmount The amount of tokens to send
     */
    function _sendTokenOutput(
        address payable tokenRecipient,
        uint256 outputAmount
    ) internal virtual;

    /**
        @notice Sends specific NFTs to a recipient address from a sender e.g add liquidity from user to pool 
        and swap from pool to user
        @dev Even though we specify the NFT address here, this internal function is only 
        used to send NFTs associated with this specific pool.
        @param _nft The address of the NFT to send
        @param nftRecipient The receiving address for the NFTs
        @param nftIds The specific IDs of NFTs to send  
     */
    function _sendSpecificNFTsToRecipient(
        address _nft,
        address nftRecipient,
        uint256[] memory nftIds,
        uint256[] memory quantities
    ) internal virtual;

    function _addNftReceivedIds(uint256 id) internal virtual;

    /**
        @notice Transfer from specific NFTs to the pool address from a sender e.g add liquidity from user to pool 
        and swap from pool to user
        @dev Even though we specify the NFT address here, this internal function is only 
        used to send NFTs associated with this specific pool.
        @param _nft The address of the NFT to send
        @param nftSender The sending address for the NFTs
        @param nftIds The specific IDs of NFTs to send  
     */
    function _recieveSpecificNFTsFromSender(
        address _nft,
        address nftSender,
        uint256[] memory nftIds,
        uint256[] memory quantities
    ) internal {
        // Send NFTs to caller
        // If missing enumerable, update pool's own ID set
        uint256 numNFTs = nftIds.length;
        if (poolManager.is721Contract(nft())) {
            for (uint256 i; i < numNFTs; ) {
                IERC721(_nft).safeTransferFrom(
                    nftSender,
                    address(this),
                    nftIds[i]
                );
                _addNftReceivedIds(nftIds[i]);
                unchecked {
                    ++i;
                }
            }
        } else {
            for (uint256 i; i < numNFTs; ) {
                IERC1155(_nft).safeTransferFrom(
                    nftSender,
                    address(this),
                    nftIds[i],
                    quantities[i],
                    "0x"
                );
                _addNftReceivedIds(nftIds[i]);
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
        @notice Holders of LPN and LPF tokens are able to withdraw liquidity.
        @param tokenAmount amount of tokens to withdraw
        @param idList collection tokenIds list that user owns
        @param quantities collection tokenIds list that user owns
        @param sumRarity total rarity of all ids
        @param isAdded if liquidity being added isAdded = true, removed = false
  */
    function _addRemoveLiquidity(
        uint256 tokenAmount,
        uint256[] calldata idList,
        uint256[] calldata quantities,
        uint128 sumRarity,
        uint8 isAdded
    ) internal {
        require(idList.length == quantities.length, "ARL: invalid quantities");
        uint256 poolValued;
        if (isAdded == 0) {
            poolValued = this.poolValue();
        } else {
            (uint256 reserveToken, uint128 reserveNft) = getReserves();
            //for eth incomming tx eth needs to be reduced of pool value
            poolValued = _poolValue(reserveToken - msg.value, reserveNft);
        }
        ICurve _bondingCurve = bondingCurve();
        if (poolType() == PoolInfo.PoolType.PRIVATE)
            require(msg.sender == owner(), "ARL:pool is private");
        //user fee to be sent to sender of tx
        {
            //getting totalLp before state modifications
            Price.LpInputParams memory lpInputParams = Price.LpInputParams(
                tokenAmount,
                sumRarity,
                poolManager.getCurveAttributes(),
                poolValued,
                poolManager.totalLp(),
                0, //for now pass 0 fee as it is required only in remove liquidity
                isAdded //0 = LP are being removed and burned
            );
            if (sumRarity > 0) {
                //when no nft pased lpnIssued will be 0
                //lpf issued  = token amount  * (total LP tokens / total pool value)
                //call bonding curve to get number of LPN being issued.

                //nft side lp tokens that need to burn or mint

                //nftSender = pool, nftRecipient = user
                //transfer initial NFTs from pool to user
                if (isAdded == 0) {
                    _sendSpecificNFTsToRecipient(
                        nft(),
                        msg.sender,
                        idList,
                        quantities
                    );
                    //calculate remove liquidity fee amount for user
                    lpInputParams.feeRemoved = _bondingCurve.getPoolFeeShare(
                        poolManager.getCurveAttributes(),
                        tokenAmount,
                        sumRarity,
                        poolManager.poolFeeAccrued(),
                        poolValued - poolManager.poolFeeAccrued() // for fee pool value without fee is used
                    );
                    poolManager.burnLpn(
                        msg.sender,
                        _bondingCurve.getLpnIssued(lpInputParams)
                    );
                } else {
                    _recieveSpecificNFTsFromSender(
                        nft(),
                        msg.sender,
                        idList,
                        quantities
                    );
                    poolManager.mintLpn(
                        msg.sender,
                        _bondingCurve.getLpnIssued(lpInputParams)
                    );
                }
                //burn NFT side LP tokens
            }
            if (tokenAmount > 0) //for eth side rmoeve liquidity
            {
                //if token amount 0 lpfIssued also 0 otherwise get from bonding curve
                //eth side lp tokens that need to burn or mint
                uint256 lpfAmount = _bondingCurve.getLpfIssued(lpInputParams);
                if (isAdded == 0) {
                    _sendTokenOutput(payable(msg.sender), tokenAmount);
                    poolManager.burnLpf(msg.sender, lpfAmount);
                } else {
                    _pullTokenInputAndPayProtocolFee(
                        tokenAmount,
                        false,
                        address(0),
                        0
                    );
                    poolManager.mintLpf(msg.sender, lpfAmount);
                }
            }

            if (lpInputParams.feeRemoved > 0) {
                //chek fee to save call gas
                _sendTokenOutput(payable(msg.sender), lpInputParams.feeRemoved);
            }
            _handleVariableDelta(
                tokenAmount,
                sumRarity,
                lpInputParams.feeRemoved,
                isAdded
            );
            //for removing reserve pass 0 as flag
            poolManager.addRemoveReserveNft(sumRarity, isAdded);
        }
    }

    function _handleVariableDelta(
        uint256 tokenAmount,
        uint128 sumRarity,
        uint256 userFee,
        uint8 isAdded
    ) internal {
        {
            (uint256 reserveToken, uint128 reserveNft) = getReserves();
            //isVariableDelta  == 1 means its true
            Price.LiquidityOutputParams memory lpOutput = bondingCurve()
                .getLiquidityInfo(
                    Price.LiquidityInputParams(
                        poolManager.getCurveAttributes(),
                        tokenAmount,
                        sumRarity,
                        poolManager.isVariableDelta(),
                        reserveToken,
                        reserveNft
                    ),
                    isAdded == 1 ? true : false
                );
            if (lpOutput.error == Price.Error.LIQ_BALANCE_ISSUE)
                revert("Invalid input ratio");

            poolManager.updatePoolParams(
                lpOutput.newCurveAttributes,
                userFee,
                isAdded
            );
        }
    }

    // /**
    //     @notice Takes NFTs from the caller and sends them into the pair's asset recipient
    //     @dev This is used by the Pool's swapNFTForToken function.
    //     @param _nft The NFT collection to take from
    //     @param nftIds The specific NFT IDs to take
    //     @param isRouter True if calling from Router, false otherwise. Not used for
    //     ETH pairs.
    //     @param routerCaller If isRouter is true, ERC20 tokens will be transferred from this address. Not used for
    //     ETH pairs.
    //  */
    // function _takeNFTsFromSender(
    //     IERC721 _nft,
    //     uint256[] calldata nftIds,
    //     IPoolFactoryLike _factory,
    //     bool isRouter,
    //     address routerCaller
    // ) internal virtual {
    //     {
    //         uint256 numNFTs = nftIds.length;

    //         if (isRouter) {
    //             // Verify if router is allowed
    //             IRouter router = IRouter(payable(msg.sender));
    //             (bool routerAllowed, ) = _factory.routerStatus(router);
    //             require(routerAllowed, "Not router");

    //             // Call router to pull NFTs
    //             // If more than 1 NFT is being transfered, we can do a balance check instead of an ownership check, as pools are indifferent between NFTs from the same collection
    //             if (numNFTs > 1) {
    //                 uint256 beforeBalance = _nft.balanceOf(address(this));
    //                 for (uint256 i = 0; i < numNFTs; ) {
    //                     router.pairTransferNFTFrom(
    //                         _nft,
    //                         routerCaller,
    //                         address(this),
    //                         nftIds[i],
    //                         pairVariant()
    //                     );

    //                     unchecked {
    //                         ++i;
    //                     }
    //                 }
    //                 require(
    //                     (_nft.balanceOf(address(this)) - beforeBalance) ==
    //                         numNFTs,
    //                     "NFTs not transferred"
    //                 );
    //             } else {
    //                 router.pairTransferNFTFrom(
    //                     _nft,
    //                     routerCaller,
    //                     address(this),
    //                     nftIds[0],
    //                     pairVariant()
    //                 );
    //                 require(
    //                     _nft.ownerOf(nftIds[0]) == address(this),
    //                     "NFT not transferred"
    //                 );
    //             }
    //         } else {
    //             // Pull NFTs directly from sender
    //             for (uint256 i; i < numNFTs; ) {
    //                 _nft.safeTransferFrom(msg.sender, address(this), nftIds[i]);

    //                 unchecked {
    //                     ++i;
    //                 }
    //             }
    //         }
    //     }
    // }

    /**
        @dev Used internally to grab pair parameters from calldata, see PoolCloner for technical details
     */
    function _immutableParamsLength() internal pure virtual returns (uint256);

    function poolValue() external view returns (uint256) {
        //TODO - ADD pool fee but before check why calculations
        //were accurate without the pool fee
        (uint256 reserveToken, uint128 reserveNft) = getReserves();
        return _poolValue(reserveToken, reserveNft);
    }

    function _poolValue(
        uint256 reserveToken,
        uint128 reserveNft
    ) internal view returns (uint256) {
        ICurve _bondingCurve = bondingCurve();
        return
            _bondingCurve.getPoolValue(
                poolManager.getCurveAttributes(),
                reserveToken,
                reserveNft
            );
    }

    function getReserves()
        internal
        view
        virtual
        returns (uint256 reserveToken, uint128 reserveNft);

    function getSumOfRarity(
        uint256[] memory rarities,
        uint256[] calldata quantities
    ) internal view returns (uint128 sumRarity) {
        address _nft = nft();
        if (poolManager.is721Contract(_nft)) {
            sumRarity = rarities.getSumOfUintArray();
        } else {
            for (uint256 i; i < rarities.length; i++) {
                sumRarity += uint128(rarities[i] * quantities[i]);
            }
        }
    }
}
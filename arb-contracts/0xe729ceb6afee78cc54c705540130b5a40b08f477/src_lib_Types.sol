// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

library Price {
    //Price Error Codes
    enum Error {
        OK, // No error
        INVALID_NUMITEMS, // The numItem value is 0
        MID_PRICE_OVERFLOW, // The updated spot price doesn't fit into 128 bits
        SPOT_PRICE_OVERFLOW, //
        LIQ_BALANCE_ISSUE,
        INVALID_ATTRIBUTES
    }

    /**
    @notice Bonding curve use the struct to take input params for buy or sell quote
    @param curveAttributes curve attributes defined by pool creator, can be a dynamic set of 
    attributes that any future curve will be able to utilize. Only the actual bonding curve knows
    what each index of curve attributes contains e.g for Linear Curve it is [0] is midPrice and [1] is delta
    @param numItems The number of NFTs the user is buying from the pair
    @param feeMultiplier Determines how much fee the LP takes from this trade, 18 decimals
    @param protocolFeeMultiplier Determines how much fee the protocol takes from this trade, 18 decimals
    */
    struct PriceInputParams {
        //curveAttributes defined by the pool creator
        uint128[] curveAttributes;
        uint256 poolFeeMultiplier;
        uint256 protocolFeeMultiplier;
        uint256 royaltyFeeMultiplier;
        uint128 sumRarityMultiplier;
    }

    /**
    @notice Bonding curve use the struct to provide output on getBuy or Sell info functions
    @param error Any math calculation errors, only Error.OK means the returned values are valid
    @param newCurveAttributes The updated curve attributes e.g. delta and mid price for linear curve.
    @param sellPrice The amount that the user should receive, in tokens
    @param protocolFee The amount of fee to send to the protocol, in tokens
    @param royaltyFee The amount to be transfered to creator or address defined by pool creator
    */
    struct PriceOutput {
        Price.Error error;
        uint128[] newCurveAttributes;
        uint256 price;
        uint256 protocolFee;
        uint256 royaltyFee;
        uint256 poolFee;
    }

    /**
    @notice Params used to pass to curve to get add/remove liquidity new curve attribtues
    */
    struct LiquidityInputParams {
        uint128[] curveAttributes;
        uint256 tokenAmount;
        uint128 sumRarity;
        uint8 isDeltaVariable;
        uint256 reserveToken;
        uint128 reserveNft;
    }

    /**
    @notice Bonding curve use the struct to provide output on getBuy or Sell info functions
    @param newCurveAttributes The updated curve attributes e.g. delta and mid price for linear curve.
    */
    struct LiquidityOutputParams {
        Price.Error error;
        uint128[] newCurveAttributes;
    }

    struct LpInputParams {
        uint256 tokenAmount;
        uint128 sumRarity;
        uint128[] curveAttributes;
        uint256 poolValue;
        uint256 totalLp;
        uint256 feeRemoved;
        uint8 isIssued; // 0  = Issued => add liquidity, 1 = Burned => Remve Liquidity
    }
}

library Rarity {
    struct RarityInputParams {
        address collection;
        bytes32[] encodedTokenIds;
        bytes1[] charecterGroups;
        uint256[] rarityValues;
    }
}

library Timelock {
    struct Request {
        uint256 amount;
        uint256 timestamp;
        uint256 unlockPeriod;
    }
}

library PoolInfo {
    enum PoolType {
        PUBLIC,
        PRIVATE
    }

    enum PriceStrategy {
        ORACLE,
        SIGNATURE
    }

    /**
        @notice Creates a pair contract using EIP-1167.
        @param _royaltyReciever The address that will receive the assets traders give during trades.
                                If set to address(0), assets will be sent to the pool address.
                                Not available to TRADE pools.
        @param _fee The fee taken by the LP in each trade. Can only be non-zero if _poolType is Trade.
        @param royaltyFeeMultiplier % Fee sent to royalty reciever
        @param curveAttributes Attributes like midPrice and delta but specific to given curve
        @param _initialNFTIDs The list of IDs of NFTs to transfer from the sender to the pair
        @param _initialTokenBalance The initial token balance sent from the sender to the new pair
        @return pair The new pair
     */
    struct InitPoolParams {
        address payable royaltyReciever;
        uint96 fee;
        uint96 royaltyFeeMultiplier;
        uint128[] curveAttributes;
        uint8 isVariableDelta;
        string fileHash;
        string lpIdentifier;
    }

    struct MultiVerifyParams {
        bytes32[][] proofs;
        uint256[] tokenIds;
        uint256[] rarities;
    }

    struct SwapWithSignatureParams {
        uint256[] nftIds;
        uint256[] quantities;
        uint256[] rarities;
        bytes raritySignature;
        uint256 quotePrice;
        address recipient;
        uint256 slippage;
    }

    /**
    @param nftIds The list of IDs of the NFTs to sell to the pair
    @param quantities respective id quantities for 1155 for 721 value=1
    @param sumRarity sum of rarity determined from price strategy
    @param minExpectedTokenOutput The minimum acceptable token received by the sender. If the actual
    amount is less than this value, the transaction will be reverted.
    @param tokenRecipient The recipient of the token output
    */
    struct SwapParams {
        uint256[] nftIds;
        uint256[] quantities;
        uint128 sumRarity;
        uint256 quotePrice;
        address recipient;
        uint256 slippage;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library CollateralPoolLibrary {
    // ================ Structs ================
    // Needed to lower stack size
    /**
     * @dev Parameters for the BankX buyback process.
     * @param excess_collateral_dollar_value_d18 Excess collateral in dollar value (scaled by 1e18).
     * @param bankx_price_usd Price of BankX in USD.
     * @param col_price_usd Price of collateral in USD.
     * @param BankX_amount Amount of BankX to be bought back.
     */
    struct BuybackBankX_Params {
        uint256 excess_collateral_dollar_value_d18;
        uint256 bankx_price_usd;
        uint256 col_price_usd;
        uint256 BankX_amount;
    }

    /**
     * @dev Parameters for the XSD buyback process.
     * @param excess_collateral_dollar_value_d18 Excess collateral in dollar value (scaled by 1e18).
     * @param xsd_price_usd Price of XSD in USD.
     * @param col_price_usd Price of collateral in USD.
     * @param XSD_amount Amount of XSD to be bought back.
     */
    struct BuybackXSD_Params {
        uint256 excess_collateral_dollar_value_d18;
        uint256 xsd_price_usd;
        uint256 col_price_usd;
        uint256 XSD_amount;
    }

    // ================ Functions ================

    /**
     * @dev Calculates the mintable XSD amount based on collateral price, silver price, and collateral amount.
     * @param col_price Price of collateral in USD.
     * @param silver_price Price of silver in USD.
     * @param collateral_amount_d18 Amount of collateral (scaled by 1e18).
     * @return The amount of XSD that can be minted.
     */
    function calcMint1t1XSD(uint256 col_price, uint256 silver_price, uint256 collateral_amount_d18) public pure returns (uint256) {
        uint256 gram_price = (silver_price*(1e4))/(311035);
        return (collateral_amount_d18*(col_price))/(gram_price); 
    }

    /**
     * @dev Calculates the mintable XSD amount based on BankX price, silver price, and BankX amount.
     * @param bankx_price_usd Price of BankX in USD.
     * @param silver_price Price of silver in USD.
     * @param bankx_amount_d18 Amount of BankX (scaled by 1e18).
     * @return The amount of XSD that can be minted.
     */
    function calcMintAlgorithmicXSD(uint256 bankx_price_usd, uint256 silver_price, uint256 bankx_amount_d18) public pure returns (uint256) {
        uint256 gram_price = (silver_price*(1e4))/(311035);
        return (bankx_amount_d18*bankx_price_usd)/(gram_price);
    }

    /**
     * @dev Calculates the interest accumulated over time for a given XSD amount.
     * @param XSD_amount Amount of XSD.
     * @param silver_price Price of silver in USD.
     * @param rate Base rate of interest.
     * @param accum_interest Accumulated interest.
     * @param interest_rate Current interest rate.
     * @param time Timestamp of the last update.
     * @param amount Principal amount.
     * @return Updated accumulated interest, interest rate, timestamp, and amount.
     */
    function calcMintInterest(uint256 XSD_amount,uint256 silver_price,uint256 rate, uint256 accum_interest, uint256 interest_rate, uint256 time, uint256 amount) internal view returns(uint256, uint256, uint256, uint256) {
        uint256 gram_price = (silver_price*(1e4))/(311035);
        if(time == 0){
            interest_rate = rate;
            amount = XSD_amount;
            time = block.timestamp;
        }
        else{
            uint delta_t = block.timestamp - time;
            delta_t = delta_t/(86400); 
            accum_interest = accum_interest+((amount*gram_price*interest_rate*delta_t)/(365*(1e12)));
        
            interest_rate = (amount*interest_rate) + (XSD_amount*rate);
            amount = amount+XSD_amount;
            interest_rate = interest_rate/amount;
            time = block.timestamp;
        }
        return (
            accum_interest,
            interest_rate,
            time, 
            amount
        );
    }

    /**
     * @dev Calculates the redemption interest for a given XSD amount.
     * @param XSD_amount Amount of XSD.
     * @param silver_price Price of silver in USD.
     * @param accum_interest Accumulated interest.
     * @param interest_rate Current interest rate.
     * @param time Timestamp of the last update.
     * @param amount Principal amount.
     * @return Updated accumulated interest, interest rate, timestamp, and amount.
     */
    function calcRedemptionInterest(uint256 XSD_amount,uint256 silver_price, uint256 accum_interest, uint256 interest_rate, uint256 time, uint256 amount) internal view returns(uint256, uint256, uint256, uint256){
        uint256 gram_price = (silver_price*(1e4))/(311035);
        uint delta_t = block.timestamp - time;
        delta_t = delta_t/(86400);
        accum_interest = accum_interest+((amount*gram_price*interest_rate*delta_t)/(365*(1e12)));
        amount = amount - XSD_amount;
        time = block.timestamp;
        return (
            accum_interest,
            interest_rate,
            time, 
            amount
        );
    }

    /**
     * @dev Calculates the redemption amount for 1:1 XSD based on collateral price, silver price, and XSD amount.
     * @param col_price_usd Price of collateral in USD.
     * @param silver_price Price of silver in USD.
     * @param XSD_amount Amount of XSD.
     * @return Amount of collateral and equivalent amount in USD.
     */
    function calcRedeem1t1XSD(uint256 col_price_usd,uint256 silver_price, uint256 XSD_amount) public pure returns (uint256,uint256) {
        uint256 gram_price = (silver_price*(1e4))/(311035);
        return ((XSD_amount*gram_price/1e6),((XSD_amount*gram_price)/col_price_usd));
    }

    /**
     * @dev Calculates the amount of collateral equivalent to the buyback of BankX.
     * @param params Struct containing parameters for BankX buyback.
     * @return Amount of collateral equivalent.
     */
    function calcBuyBackBankX(BuybackBankX_Params memory params) internal pure returns (uint256) {
        // If the total collateral value is higher than the amount required at the current collateral ratio then buy back up to the possible BankX with the desired collateral
        require(params.excess_collateral_dollar_value_d18 > 0, "No excess collateral to buy back!");

        // Make sure not to take more than is available
        uint256 bankx_dollar_value_d18 = (params.BankX_amount*params.bankx_price_usd);
        require((bankx_dollar_value_d18/1e6) <= params.excess_collateral_dollar_value_d18, "You are trying to buy back more than the excess!");

        // Get the equivalent amount of collateral based on the market value of BankX provided 
        uint256 collateral_equivalent_d18 = (bankx_dollar_value_d18)/(params.col_price_usd);

        return (
            collateral_equivalent_d18
        );
    }

    /**
     * @dev Calculates the amount of collateral equivalent to the buyback of XSD.
     * @param params Struct containing parameters for XSD buyback.
     * @return Amount of collateral equivalent.
     */
    function calcBuyBackXSD(BuybackXSD_Params memory params) internal pure returns (uint256) {
        require(params.excess_collateral_dollar_value_d18 > 0, "No excess collateral to buy back!");

        uint256 xsd_dollar_value_d18 = params.XSD_amount*(params.xsd_price_usd);
        require((xsd_dollar_value_d18/1e6) <= params.excess_collateral_dollar_value_d18, "You are trying to buy more than the excess!");

        uint256 collateral_equivalent_d18 = (xsd_dollar_value_d18)/(params.col_price_usd);

        return (
            collateral_equivalent_d18
        );
    }
}
// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "./openzeppelin_contracts_utils_Context.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol" as IERC20;
import "./contracts_interfaces_IDataHub.sol";
import "./contracts_interfaces_IDepositVault.sol";
import "./contracts_interfaces_IOracle.sol";
import "./contracts_interfaces_IUtilityContract.sol";
import "./contracts_interfaces_IInterestData.sol";
import "./contracts_libraries_EVO_LIBRARY.sol";
import "./contracts_interfaces_IExecutor.sol";

contract Liquidator is Ownable {
    IUtilityContract public Utilities;
    IDataHub public Datahub;
    IInterestData public interestContract;
    IExecutor public Executor;

    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _executor
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        Executor = IExecutor(_executor);
    }

    mapping(address => uint256) FeesCollected; // token --> amount

    /// @notice This alters the admin roles for the contract
    /// @param _executor the address of the new executor contract
    function alterAdminRoles(
        address _executor,
        address _datahub,
        address _utility,
        address _interest
    ) public onlyOwner {
        Executor = IExecutor(_executor);
        Datahub = IDataHub(_datahub);
        Utilities = IUtilityContract(_utility);
        interestContract = IInterestData(_interest);
    }

    /// @notice This checks if the user is liquidatable
    /// @dev add in the users address to check their Aggregate Maintenance Margin Requirement and see if its higher that their Total Portfolio value
    function CheckForLiquidation(address user) public returns (bool) {
        // NOTE: We want to return the user's liability tokens, not their asset tokens here
        bytes32[] memory tokens_liabilities = Datahub
            .returnUsersLiabilitiesTokens(user);
        for (uint256 i = 0; i < tokens_liabilities.length; i++) {
            interestContract.updateCIMandTBA(tokens_liabilities[i]);
            // liabilities = Datahub.ReadUserData(user, tokens_liabilities[i]).liabilities;
            // uint256 interestCharge = interestContract.returnInterestCharge(
            //    user,
            //    tokens_liabilities[i]
            // );

            // AMMR +=
            //    (Datahub.returnAssetLogs(tokens_liabilities[i]).assetPrice *
            //        (liabilities + interestCharge) *
            //        Datahub.returnAssetLogs(tokens_liabilities[i]).marginRequirement[1]) /
            //    10 ** 36; // 1 -> MainternanceMarginRequirement
        }
        if (
            Datahub.calculateAMMRForUser(user) >
            Datahub.calculateCollateralValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }

    // TO DO when we pull TPV we need to add pending balances in here as well --> loop through pending convert to price add to tpv
    /// @notice This function is for liquidating a user
    /// @dev Explain to a developer any extra details
    /// @param user the address of the user being liquidated
    /// @param tokens the liability token (the token the liquidatee has outstanding liabilities on), liquidation token ( the tokens that are liquidated from the liquidatees account)
    /// @param spendingCap the max amount the liquidator is willing to pay to settled the liquidatee's debt
    function Liquidate(
        address user,
        bytes32[2] memory tokens, // liability tokens first, tokens to liquidate after
        uint256 spendingCap
    ) public {
        require(CheckForLiquidation(user), "not liquidatable"); // AMMR liquidatee --> checks AMMR
        require(tokens.length == 2, "have to select a pair");

        // NOTE: WE NEED A REQUIRE STATEMENT TO MAKE SURE THE COUNTERPAIR MAKES SENSE?
        IDataHub.AssetData memory token1_assetlogs = fetchLogs(tokens[1]);
        // IDataHub.AssetData memory token0_assetlogs = fetchLogs(tokens[0]);

        require(
            token1_assetlogs.collateralMultiplier > 0,
            "The token you are trying to liquidate does not have collateral value"
        );

        uint256[] memory taker_amounts = new uint256[](1);
        uint256[] memory maker_amounts = new uint256[](1);
        uint256 liquidationTokenAmount;
        uint256 liquidationFeeAmount;
        uint256 marketLiquidationTokenAmount;

        // User0 is liquidatee
        // uint256 user0_liabilities;
        // user0_liabilities = fetchliabilities(user, tokens[0]);

        require(
            fetchliabilities(user, tokens[0]) > 0,
            "Liquidatee does not have liabilities for this asset"
        );

        // liquidatee's tokens to be liquidated
        uint256 user0_asset = fetchAssets(user, tokens[1]);
        require(user0_asset > 0, "Liquidatee does not own this asset");

        // USDC value at market price of liquidatee's liquidation tokens
        uint256 marketLiquidationValue = (user0_asset *
            interestContract.getStorkOraclePrice(tokens[1])) / 1e18;

        // discounted liquidation token value
        uint256 discountedLiquidationValue = (marketLiquidationValue *
            (1e18 - token1_assetlogs.feeInfo[1])) / 1e18;

        // discounted liability token amount - the amount the liquidator would pay including the liquidation discount
        uint256 discountedLiabilityTokenAmount = (discountedLiquidationValue *
            1e18) / interestContract.getStorkOraclePrice(tokens[0]);

        // If the liquidator isn't providing enough funds to liquidate the liquidatee's full liquidation asset amount
        if (spendingCap < discountedLiabilityTokenAmount) {
            // This if statement scales down the liquidators spendingCap/liabilityToken out amounts if the liquidatee
            // does not have enough liquidationTokens for the transaction
            // liquidation token amount including the liquidation fee scaled down to what the liquidator is providing
            liquidationTokenAmount =
                (spendingCap *
                    interestContract.getStorkOraclePrice(tokens[0])) /
                ((interestContract.getStorkOraclePrice(tokens[1]) *
                    (1e18 - token1_assetlogs.feeInfo[1])) / 1e18);

            // market liquidation amount is the amount of tokens the liquidator would get at fair market value
            marketLiquidationTokenAmount =
                (spendingCap *
                    interestContract.getStorkOraclePrice(tokens[0])) /
                interestContract.getStorkOraclePrice(tokens[1]);

            liquidationFeeAmount =
                liquidationTokenAmount -
                marketLiquidationTokenAmount;

            // Give exchange wallets fee spread for liquidations
            Datahub.addAssets(
                Executor.fetchDaoWallet(),
                tokens[1],
                (liquidationFeeAmount * 18) / 100
            );
            Datahub.addAssets(
                Executor.fetchOrderBookProvider(),
                tokens[1],
                (liquidationFeeAmount * 2) / 100
            );

            taker_amounts[0] = spendingCap; // liability token amount
            maker_amounts[0] = liquidationTokenAmount;

            require(
                spendingCap <= fetchAssets(msg.sender, tokens[0]),
                "you do not have the assets required for this size of liquidation, please lower your spending cap"
            );

            conductLiquidation(
                user,
                msg.sender,
                tokens,
                maker_amounts,
                taker_amounts,
                (liquidationFeeAmount * 20) / 100 // are we doing the liquidation fee twice here? We do it above as well. I think this is just used to subtract from liquidator...
            );
        } else {
            // this else statement scales down the liquidatee's asset token/liquidationToken if the spendingCap/liabilityToken is larger than
            // what he needs to provide

            // Amount of the spending cap (liability tokens) the liquidator will use, since he is providing more than what is needed, we
            // need to bring this number down for the corresponding amount of liquidation tokens he will get
            uint256 liabilityOutAmount = (discountedLiquidationValue * 1e18) /
                interestContract.getStorkOraclePrice(tokens[0]);

            // The amount of liquidation tokens the liquidator would be able to buy at market price with his liability tokens
            marketLiquidationTokenAmount =
                (liabilityOutAmount *
                    interestContract.getStorkOraclePrice(tokens[0])) /
                interestContract.getStorkOraclePrice(tokens[1]);

            liquidationTokenAmount = user0_asset;

            liquidationFeeAmount = user0_asset - marketLiquidationTokenAmount;

            // Give exchange wallets fee spread for liquidations
            Datahub.addAssets(
                Executor.fetchDaoWallet(),
                tokens[1],
                (liquidationFeeAmount * 18) / 100
            );
            Datahub.addAssets(
                Executor.fetchOrderBookProvider(),
                tokens[1],
                (liquidationFeeAmount * 2) / 100
            );

            taker_amounts[0] = liabilityOutAmount;
            maker_amounts[0] = liquidationTokenAmount;

            require(
                liabilityOutAmount <= fetchAssets(msg.sender, tokens[0]),
                "you do not have the assets required for this size of liquidation, please lower your spending cap"
            );

            conductLiquidation(
                user,
                msg.sender,
                tokens,
                maker_amounts,
                taker_amounts,
                (liquidationFeeAmount * 20) / 100 // are we doing the liquidation fee twice here? We do it above as well. I think this is just used to subtract from liquidator...
            );
        }
    }

    // NOTE: WE MIGHT WANT TO MAKE A LIQUIDATE LENDING POOL FUNCTION - In case a user doesn't have assets, but does have lending pool assets

    function returnMultiplier(
        bool short,
        bytes32 token
    ) private view returns (uint256) {
        if (!short) {
            return 10 ** 18 - fetchLogs(token).feeInfo[1]; // 1 -> liquidationFee 100000000000000000
        } else {
            return 10 ** 18 + fetchLogs(token).feeInfo[1]; // 1 -> liquidationFee
        }
    }

    function conductLiquidation(
        address user,
        address liquidator,
        bytes32[2] memory tokens, // liability tokens first, tokens to liquidate after
        uint256[] memory maker_amounts,
        uint256[] memory taker_amounts,
        uint256 liquidation_fee
    ) private {
        address[][2] memory participants;
        uint256[][2] memory trade_amounts;
        participants[0] = EVO_LIBRARY.createArray(liquidator);
        participants[1] = EVO_LIBRARY.createArray(user);
        trade_amounts[0] = taker_amounts;
        trade_amounts[1] = maker_amounts;

        (
            uint256[] memory takerLiabilities,
            uint256[] memory makerLiabilities
        ) = Utilities.calculateTradeLiabilityAddtions(
                tokens,
                participants,
                trade_amounts
            );
        require( // why do we need this require statement here?
            Utilities.validateTradeAmounts(trade_amounts),
            "Never 0 trades"
        );

        // require(
        //     Utilities.processMargin(tokens, participants, trade_amounts), // This function doesn't work correctly let's review it
        //     "This trade failed the margin checks for one or more users"
        // );

        // I think we're doing this require already, let's make sure we need it
        // require(
        //     Datahub.calculateCollateralValue(user) <
        //         Datahub.calculateAMMRForUser(user)
        // );

        bool[] memory fee_side = new bool[](1);
        bool[] memory fee_side_2 = new bool[](1);

        fee_side[0] = true;
        fee_side_2[0] = true;

        freezeTempBalance(
            tokens,
            participants,
            trade_amounts,
            [fee_side, fee_side_2]
        );

        Executor.TransferBalances(
            tokens,
            participants[0],
            participants[1],
            taker_amounts,
            maker_amounts,
            takerLiabilities,
            makerLiabilities,
            [fee_side, fee_side_2]
        );

        // Check to make sure this is doing it correctly. It looks right, but I want to be sure
        Datahub.removeAssets(liquidator, tokens[1], liquidation_fee);
    }

    /// @notice This simulates an airnode call to see if it is a success or fail
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function freezeTempBalance(
        bytes32[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        bool[][2] memory trade_side
    ) private {
        alterPending(participants[0], trade_amounts[0], trade_side[0], pair[0]);
        alterPending(participants[1], trade_amounts[1], trade_side[1], pair[1]);
    }

    /// @notice Processes a trade details
    /// @param  participants the participants on the trade
    /// @param  tradeAmounts the trade amounts in the trade
    /// @param  pair the token involved in the trade
    function alterPending(
        address[] memory participants,
        uint256[] memory tradeAmounts,
        bool[] memory /*tradeside*/,
        bytes32 pair
    ) internal returns (bool) {
        for (uint256 i = 0; i < participants.length; i++) {
            uint256 assets = Datahub.ReadUserData(participants[i], pair).assets;
            // if (tradeside[i]) {} else {
            //     uint256 tradeFeeForTaker = Datahub.tradeFee(pair, 1);
            //     tradeAmounts[i] =
            //         tradeAmounts[i] -
            //         (tradeFeeForTaker * tradeAmounts[i]) /
            //         10 ** 18;
            //     assets = assets - (tradeFeeForTaker * assets) / 10 ** 18;
            // }
            uint256 balanceToAdd = tradeAmounts[i] > assets
                ? assets
                : tradeAmounts[i];
            Datahub.addPendingBalances(
                participants[i],
                pair,
                balanceToAdd,
                true
            );
        }
        return true;
    }

    function fetchLogs(
        bytes32 token
    ) private view returns (IDataHub.AssetData memory) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        return assetLogs;
    }

    function fetchAssets(
        address user,
        bytes32 token
    ) private view returns (uint256) {
        uint256 assets = Datahub.ReadUserData(user, token).assets;
        return assets;
    }

    function fetchliabilities(
        address user,
        bytes32 token
    ) private view returns (uint256) {
        uint256 liabilities = interestContract
            .calculateActualCurrentLiabilities(user, token);
        return liabilities;
    }
}
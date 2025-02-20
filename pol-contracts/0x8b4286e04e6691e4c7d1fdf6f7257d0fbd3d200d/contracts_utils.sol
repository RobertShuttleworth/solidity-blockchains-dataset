// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "./openzeppelin_contracts_utils_Context.sol";
import "./openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol" as IERC20;
import "./contracts_interfaces_IDataHub.sol";
import "./contracts_interfaces_IDepositVault.sol";
import "./contracts_interfaces_IOracle.sol";
import "./contracts_libraries_EVO_LIBRARY.sol";
import "./contracts_interfaces_IExecutor.sol";
import "./contracts_interfaces_IInterestData.sol";

contract Utility is Ownable2StepUpgradeable {
    /// @notice Keeps track of contract admins
    mapping(address => bool) public admins;
    mapping(address => bool) public validators;

    IDataHub public Datahub;

    IOracle public Oracle;

    IDepositVault public DepositVault;

    IExecutor public Executor;

    IInterestData public interestContract;

    //-------- For cycleCCTP and Aggregated Trade --------
    mapping(address => uint256) lastCctpCycleTxId;
    // user => transactionId => currentSuccessAmount
    mapping(address => mapping(uint256 => uint256)) cctpCycleTxIdCurrentSuccessAmount;
    // user => transactionId => currentFailedAmount
    mapping(address => mapping(uint256 => uint256)) cctpCycleTxIdCurrentFailedAmount;
    // user => transactionId => minimumAmount
    mapping(address => mapping(uint256 => uint256)) cctpCycleTxIdTotalAmount;
    // user => transactionId => tokens
    mapping(address => mapping(uint256 => bytes32[])) cctpCycleTxIdTokens;
    // user => transactionId => amounts
    mapping(address => mapping(uint256 => uint256[])) cctpCycleTxIdAmounts;

    struct AggregatedTradeInfo {
        address user;
        bytes32[2] path;
        uint256 amountOut;
        uint256 amountInMin;
        string chainId;
        string[2] tokenAddress;
    }
    // user => transactionId => minimumAmount
    mapping(address => mapping(uint256 => AggregatedTradeInfo)) aggregatedTradeInfo;

    /// @notice Sets a new Admin role
    function setAdminRole(address _admin) external onlyOwner {
        admins[_admin] = true;
    }

    /// @notice Revokes the Admin role of the contract
    function revokeAdminRole(address _admin) external onlyOwner {
        admins[_admin] = false;
    }

    function setValidatorRole(address _validator) external onlyOwner {
        validators[_validator] = true;
    }

    function revokeValidatorRole(address _validator) external onlyOwner {
        validators[_validator] = false;
    }

    /// @notice checks the role authority of the caller to see if they can change the state
    modifier checkRoleAuthority() {
        require(admins[msg.sender] == true, "Unauthorized");
        _;
    }

    modifier validateValidator() {
        require(validators[msg.sender] == true, "Not validator");
        _;
    }

    /// @notice Initializes the contract
    function initialize(
        address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address oracle,
        address _executor,
        address _interest
    ) public initializer {
        __Context_init();
        __Ownable_init(initialOwner);

        admins[address(this)] = true;
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Oracle = IOracle(oracle);
        Executor = IExecutor(_executor);
        interestContract = IInterestData(_interest);
    }

    function alterAdminRoles(
        address _DataHub,
        address _deposit_vault,
        address _oracle,
        address _interest,
        address _liquidator,
        address _ex
    ) public onlyOwner {
        admins[address(Datahub)] = false;
        admins[_DataHub] = true;
        Datahub = IDataHub(_DataHub);

        admins[address(DepositVault)] = false;
        admins[_deposit_vault] = true;
        DepositVault = IDepositVault(_deposit_vault);

        admins[address(Oracle)] = false;
        admins[_oracle] = true;
        Oracle = IOracle(_oracle);

        admins[address(interestContract)] = false;
        admins[_interest] = true;
        interestContract = IInterestData(_interest);

        admins[_liquidator] = true;

        admins[address(Executor)] = false;
        admins[_ex] = true;
        Executor = IExecutor(_ex);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    function validateMarginStatus(
        address user,
        bytes32 token
    ) public view returns (bool) {
        bool margined = Datahub.ReadUserData(user, token).margined;
        return margined;
    }

    /// @notice Takes a single users address and returns the amount of liabilities that are going to be issued to that user
    // After following executor trade functions down to here, I think this might be the best place to include the
    // initialMarginFees, which I can't find where they're currently being included
    function calculateAmountToAddToLiabilities(
        address user,
        bytes32 token,
        uint256 amount
    ) public view returns (uint256) {
        uint256 assets = Datahub.ReadUserData(user, token).assets;
        return amount > assets ? amount - assets : 0;
    }
    /// @notice Cycles through two lists of users and checks how many liabilities are going to be issued to each user
    function calculateTradeLiabilityAddtions(
        bytes32[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory TakerliabilityAmounts = new uint256[](
            participants[0].length
        );
        uint256[] memory MakerliabilityAmounts = new uint256[](
            participants[1].length
        );
        uint256 TakeramountToAddToLiabilities;
        for (uint256 i = 0; i < participants[0].length; i++) {
            TakeramountToAddToLiabilities = calculateAmountToAddToLiabilities(
                participants[0][i],
                pair[0],
                trade_amounts[0][i]
            );
            TakerliabilityAmounts[i] = TakeramountToAddToLiabilities;
        }
        uint256 MakeramountToAddToLiabilities;
        for (uint256 i = 0; i < participants[1].length; i++) {
            MakeramountToAddToLiabilities = calculateAmountToAddToLiabilities(
                participants[1][i],
                pair[1],
                trade_amounts[1][i]
            );
            MakerliabilityAmounts[i] = MakeramountToAddToLiabilities;
        }

        return (TakerliabilityAmounts, MakerliabilityAmounts);
    }
    /// @notice Cycles through a list of users and returns the bulk assets sum
    function returnBulkAssets(
        address[] memory users,
        bytes32 token
    ) public view returns (uint256) {
        uint256 bulkAssets;
        for (uint256 i = 0; i < users.length; i++) {
            uint256 assets = Datahub.ReadUserData(users[i], token).assets;

            bulkAssets += assets;
        }
        return bulkAssets;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    /// @return assets
    function returnAssets(
        address user,
        bytes32 token
    ) external view returns (uint256) {
        uint256 assets = Datahub.ReadUserData(user, token).assets;
        return assets;
    }

    // NOTE:
    // We can probably delete this function
    // function returnliabilities(
    //     address user,
    //     bytes32 token
    // ) public view returns (uint256) {
    //     uint256 liabilities = Datahub.ReadUserData(user, token).rawLiabilities;
    //     return liabilities;
    // }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being targetted
    /// @param token being targetted
    /// @return pending balance
    function returnPending(
        address user,
        bytes32 token
    ) external view returns (uint256) {
        uint256 pending = Datahub.ReadUserData(user, token).pending;
        return pending;
    }

    function returnMaintenanceRequirementForTrade(
        bytes32 token,
        uint256 amount
    ) external view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);
        uint256 maintenace = assetLogs.marginRequirement[1]; // 1 -> MaintenanceMarginRequirement
        return ((maintenace * (amount)) / 10 ** 18); //
    }

    function validateTradeAmounts(
        uint256[][2] memory trade_amounts
    ) external pure returns (bool) {
        for (uint256 i = 0; i < trade_amounts[0].length; i++) {
            if (trade_amounts[0][i] == 0 || trade_amounts[1][i] == 0) {
                return false;
            }
        }
        return true;
    }

    /// @notice this function runs the margin checks, changes margin status if applicable and adds pending balances
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function processMargin(
        bytes32[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) external returns (bool) {
        bool takerTradeConfirmation = processChecks(
            participants[0],
            trade_amounts[0],
            pair[0]
        );
        bool makerTradeConfirmation = processChecks(
            participants[1],
            trade_amounts[1],
            pair[1]
        );
        if (!makerTradeConfirmation || !takerTradeConfirmation) {
            return false;
        } else {
            return true;
        }
    }

    // WE NEED TO REVIEW WHAT EXACTLY THIS FUNCTION IS DOING. IT LOOKS VERY WRONG TO ME
    /// @notice Processes a trade details
    /// @param  participants the participants on the trade
    /// @param  tradeAmounts the trade amounts in the trade
    /// @param  pair the token involved in the trade
    function processChecks(
        address[] memory participants,
        uint256[] memory tradeAmounts,
        bytes32 pair
    ) internal returns (bool) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(pair);
        for (uint256 i = 0; i < participants.length; i++) {
            uint256 assets = Datahub.ReadUserData(participants[i], pair).assets;

            if (tradeAmounts[i] > assets) {
                uint256 initalMarginFeeAmount = EVO_LIBRARY
                    .calculateinitialMarginFeeAmount(
                        assetLogs,
                        tradeAmounts[i] // For example, here why are we using trade amount? Should probably be tradeAmounts - assets
                    );
                initalMarginFeeAmount =
                    (initalMarginFeeAmount * assetLogs.assetPrice) / // Why are we multiplying by price here? This is wrong
                    10 ** 18;
                uint256 collateralValue = Datahub.calculateCollateralValue(
                    participants[i]
                ) - Datahub.calculatePendingCollateralValue(participants[i]); // Why are we subtracting the pending value here?? Don't think we should be doing this

                uint256 aimrForUser = Datahub.calculateAIMRForUser(
                    participants[i]
                );

                // console.log("collateral value", collateralValue / 10 ** 18);
                // console.log("aimrForUser", aimrForUser / 10 ** 18);
                // console.log(
                //     "initalMarginFeeAmount",
                //     initalMarginFeeAmount / 10 ** 18
                // );
                // console.log(
                //     "collateral value - sum",
                //     collateralValue / 10 ** 18,
                //     aimrForUser + initalMarginFeeAmount / 10 ** 18
                // );

                if (collateralValue <= aimrForUser + initalMarginFeeAmount) {
                    // We should not be adding AIMR and initialMarginFee This is very wrong
                    return false;
                }
                bool flag = validateMarginStatus(participants[i], pair);
                if (!flag) {
                    Datahub.SetMarginStatus(participants[i], true);
                }
            }
        }
        return true;
    }

    /// @notice Checks that the trade will not push the asset over maxBorrowProportion
    // This function was done terribly and needed to be edited
    // The only thing this function needs to do is take into account the new liabilities that are being issued
    // and see if that liability would make the actualTotalBorrowedAmount > actualLendingPoolSupply
    // These checks are actually already in the updateLiabilities function so I'm seeing if we even need this check at all
    function maxBorrowCheck(
        bytes32[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts // instead of feeding in trade_amounts, we should feed in takerLiabilities and
    )
        public
        view
        returns (
            // makerLiabilities from submitOrder function in executor
            bool
        )
    {
        uint256 newLiabilitiesIssued;
        for (uint256 i = 0; i < pair.length; i++) {
            uint256 collateral = EVO_LIBRARY.calculateTotal(trade_amounts[i]); // we don't need to check collateral
            uint256 bulkAssets = returnBulkAssets(participants[i], pair[i]); // we don't need to check bulk assets
            newLiabilitiesIssued = collateral > bulkAssets
                ? collateral - bulkAssets
                : 0;

            if (newLiabilitiesIssued > 0) {
                IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(
                    pair[i]
                );
                bool flag = EVO_LIBRARY.calculateBorrowProportionAfterTrades(
                    assetLogs,
                    newLiabilitiesIssued
                );
                return flag;
            }
        }
        return true;
    }

    /// @notice Fetches the total amount borrowed of the token
    /// @param token the token being queried
    /// @return the total borrowed amount
    function fetchTotalAssetSupply(
        bytes32 token
    ) external view returns (uint256) {
        return Datahub.returnAssetLogs(token).assetInfo[0]; // 0 -> totalAssetSupply
    }

    // Code20: BACKEND - Think about calling this directly from the back end
    function aggregated_trade_in_process_failed(
        address user,
        bytes32[2] memory path, // path[0]: tokenOut, path[1]: tokenIn
        uint256 amountOut,
        uint256 aggregated_trade_nonce
    ) public validateValidator returns (bool) {
        Oracle.checkAggregatedTradeDetails(
            aggregated_trade_nonce,
            user,
            path,
            amountOut
        );

        interestContract.updateCIMandTBA(path[0]);

        if (DepositVault.isUSDC(path[0])) {
            Datahub.setAssetInfo(0, path[0], amountOut, true); // 0 -> totalSupply for chain.USDC
            path[0] = DepositVault.tokenUsdcUsdc();
            interestContract.updateCIMandTBA(path[0]); // this is USDC.USDC
        }

        Datahub.removePendingBalances(user, path[0], amountOut, true);
        Datahub.addAssets(user, path[0], amountOut);
        Datahub.setAssetInfo(0, path[0], amountOut, true); // 0 -> totalSupply

        Oracle.setAggregatedTradeFail(aggregated_trade_nonce);

        return true;
    }

    // Code20: BACKEND - Think about calling this directly from the back end
    function aggregated_trade_in_process_success(
        address user,
        bytes32[2] memory path, // path[0]: tokenOut, path[1]: tokenIn
        uint256 amountOut,
        uint256 amountIn,
        string memory chainId, // 1 | 137 | BTC | SOL
        string memory tokenInAddress, // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
        uint256 aggregated_trade_nonce,
        bool crossChain,
        uint256 crossChainAggregatedTradeNonce
    ) public validateValidator {
        // // Check pending balance
        // require(
        //     Datahub.ReadUserData(user, path[0]).pending == amountOut,
        //     "No pending asset"
        // );

        if (!Datahub.returnAssetLogs(path[1]).initialized) {
            Datahub.selfInitTokenMarket(path[1], chainId, tokenInAddress);
        }

        require(
            !DepositVault.viewcircuitBreakerStatus(),
            "circuit breaker active"
        );

        Oracle.checkAggregatedTradeDetails(
            aggregated_trade_nonce,
            user,
            path,
            amountOut
        );

        Datahub.removePendingBalances(user, path[0], amountOut, true);

        if (!DepositVault.isUSDC(path[1])) {
            interestContract.updateCIMandTBA(path[1]);
        }
        Datahub.setAssetInfo(0, path[1], amountIn, true); // 0 -> totalSupply
        if (DepositVault.isUSDC(path[1])) {
            path[1] = DepositVault.tokenUsdcUsdc();
            interestContract.updateCIMandTBA(path[1]);
            Datahub.setAssetInfo(0, path[1], amountIn, true); // 0 -> totalSupply
        }

        uint256 rawLiabilities = Datahub
            .ReadUserData(user, path[1])
            .rawLiabilities;

        Oracle.setAggregatedTradeSuccess(aggregated_trade_nonce);

        if (rawLiabilities > 0) {
            uint256 actualCurrentLiabilities = interestContract
                .calculateActualCurrentLiabilities(user, path[1]);
            if (amountIn <= actualCurrentLiabilities) {
                interestContract.updateLiabilities(user, path[1], amountIn, true);
            } else {
                Datahub.addAssets(
                    user,
                    path[1],
                    amountIn - actualCurrentLiabilities
                ); // add to assets

                interestContract.updateLiabilities(
                    user,
                    path[1],
                    actualCurrentLiabilities,
                    true
                ); // remove all liabilities
            }
        } else {
            Datahub.addAssets(user, path[1], amountIn);
        }

        if (crossChain == true) {
            Executor.aggregatedTrade(
                [
                    DepositVault.getUsdcForChain(Executor.crossChainAggregatedTradeDetail(crossChainAggregatedTradeNonce).chainId[1]), // finding the correct chain.USDC to use for the trade
                    Executor
                        .crossChainAggregatedTradeDetail(
                            crossChainAggregatedTradeNonce
                        )
                        .path[1]
                ], // path[1] here has to be USDC due to the nature of crossChainAggregatedTrade - crossChainAggregatedTradeNonce.path[1] is the saved inToken from the crossChain trade
                amountIn, // this is actually amountOut in the aggregatedTrde function, but we are using the amount in from here to conduct the out part of the function
                Executor
                    .crossChainAggregatedTradeDetail(
                        crossChainAggregatedTradeNonce
                    )
                    .amountInMin, // Make sure that we are getting the original amountInMin, not the usdcAmountInMin
                [
                    chainId,
                    Executor
                        .crossChainAggregatedTradeDetail(
                            crossChainAggregatedTradeNonce
                        )
                        .chainId[1]
                ],
                [
                    tokenInAddress,
                    Executor
                        .crossChainAggregatedTradeDetail(
                            crossChainAggregatedTradeNonce
                        )
                        .tokenAddress[1]
                ],
                false,
                0
            );
        }
    }

    // Code20: BACKEND - Think about calling this directly from the back end
    function cycle_cctp_for_aggregated_trade_success(
        address user,
        uint256 transactionId,
        bytes32 source_token,
        bytes32 target_token,
        uint256 amount,
        uint256 aggregated_trade_cctp_nonce
    ) public validateValidator {
        Oracle.checkAggregatedTradeCCTPDetails(
            aggregated_trade_cctp_nonce,
            user,
            transactionId,
            source_token,
            target_token,
            amount
        );
        uint256 currentSuccessAmount = cctpCycleTxIdCurrentSuccessAmount[user][
            transactionId
        ];
        currentSuccessAmount += amount;
        cctpCycleTxIdCurrentSuccessAmount[user][
            transactionId
        ] = currentSuccessAmount;

        Oracle.setAggregatedTradeCCTPSuccess(aggregated_trade_cctp_nonce);

        if (
            currentSuccessAmount >=
            cctpCycleTxIdTotalAmount[user][transactionId]
        ) {
            Oracle.ProcessAggregatedTrade(
                aggregatedTradeInfo[user][transactionId].user,
                aggregatedTradeInfo[user][transactionId].path,
                aggregatedTradeInfo[user][transactionId].amountOut,
                aggregatedTradeInfo[user][transactionId].amountInMin,
                aggregatedTradeInfo[user][transactionId].chainId,
                aggregatedTradeInfo[user][transactionId].tokenAddress,
                false,
                0
            );
        }
    }

    // Code20: BACKEND - Think about calling this directly from the back end
    function cycle_cctp_for_aggregated_trade_fail(
        address user,
        uint256 transactionId,
        bytes32 source_token,
        bytes32 target_token,
        uint256 amount,
        uint256 aggregated_trade_cctp_nonce
    ) public validateValidator {
        Oracle.checkAggregatedTradeCCTPDetails(
            aggregated_trade_cctp_nonce,
            user,
            transactionId,
            source_token,
            target_token,
            amount
        );
        uint256 currentFailedAmount = cctpCycleTxIdCurrentFailedAmount[user][
            transactionId
        ];
        currentFailedAmount += amount;
        cctpCycleTxIdCurrentFailedAmount[user][
            transactionId
        ] = currentFailedAmount;
        uint256 currentSuccessAmount = cctpCycleTxIdCurrentSuccessAmount[user][
            transactionId
        ];
        uint256 totalAmount = cctpCycleTxIdTotalAmount[user][transactionId];

        Oracle.setAggregatedTradeCCTPFail(aggregated_trade_cctp_nonce);

        if (
            currentSuccessAmount + currentFailedAmount >= totalAmount &&
            currentSuccessAmount < totalAmount
        ) {
            bytes32[] memory src_tokens = cctpCycleTxIdTokens[user][
                transactionId
            ];
            uint256[] memory src_amounts = cctpCycleTxIdAmounts[user][
                transactionId
            ];

            for (uint256 i = 0; i < src_tokens.length; i++) {
                Datahub.setAssetInfo(0, src_tokens[i], src_amounts[i], true);
                Datahub.setAssetInfo(
                    0,
                    DepositVault.tokenUsdcUsdc(),
                    src_amounts[i],
                    true
                );
                Datahub.removePendingBalances(
                    user,
                    DepositVault.tokenUsdcUsdc(),
                    src_amounts[i],
                    true
                );
                Datahub.addAssets(
                    user,
                    DepositVault.tokenUsdcUsdc(),
                    src_amounts[i]
                );
            }
        }
    }

    function getLastCctpCycleTxId(
        address user
    ) external view returns (uint256) {
        return lastCctpCycleTxId[user];
    }

    function updateLastCctpCycleTxId(address user) external checkRoleAuthority {
        lastCctpCycleTxId[user]++;
    }

    function setCctpCycleTxIdCurrentSuccessAmount(
        address user,
        uint256 txId,
        uint256 value
    ) external checkRoleAuthority {
        cctpCycleTxIdCurrentSuccessAmount[user][txId] = value;
    }

    function setCctpCycleTxIdCurrentFailedAmount(
        address user,
        uint256 txId,
        uint256 value
    ) external checkRoleAuthority {
        cctpCycleTxIdCurrentFailedAmount[user][txId] = value;
    }

    function setCctpCycleTxIdTotalAmount(
        address user,
        uint256 txId,
        uint256 value
    ) external checkRoleAuthority {
        cctpCycleTxIdTotalAmount[user][txId] = value;
    }

    function addCctpCycleTxIdTokens(
        address user,
        uint256 txId,
        bytes32 value
    ) external checkRoleAuthority {
        cctpCycleTxIdTokens[user][txId].push(value);
    }

    function addCctpCycleTxIdAmounts(
        address user,
        uint256 txId,
        uint256 value
    ) external checkRoleAuthority {
        cctpCycleTxIdAmounts[user][txId].push(value);
    }

    function setAggregatedTradeInfo(
        uint256 txId,
        address user,
        bytes32[2] memory path,
        uint256 amountOut,
        uint256 amountInMin,
        string memory chainId,
        string[2] memory tokenAddress
    ) external checkRoleAuthority {
        aggregatedTradeInfo[user][txId].user = user;
        aggregatedTradeInfo[user][txId].path = path;
        aggregatedTradeInfo[user][txId].amountOut = amountOut;
        aggregatedTradeInfo[user][txId].amountInMin = amountInMin;
        aggregatedTradeInfo[user][txId].chainId = chainId;
        aggregatedTradeInfo[user][txId].tokenAddress = tokenAddress;
    }

    function withdrawETH(address payable owner) external onlyOwner {
        uint contractBalance = address(this).balance;
        require(contractBalance > 0, "No balance to withdraw");
        payable(owner).transfer(contractBalance);
    }

    function withdrawERC20(
        address tokenAddress,
        address to
    ) external onlyOwner {
        // Ensure the tokenAddress is valid
        require(tokenAddress != address(0), "Invalid token address");
        // Ensure the recipient address is valid
        require(to != address(0), "Invalid recipient address");

        // Get the balance of the token held by the contract
        IERC20.IERC20 token = IERC20.IERC20(tokenAddress);
        uint256 contractBalance = token.balanceOf(address(this));

        // Ensure the contract has enough tokens to transfer
        require(contractBalance > 0, "Insufficient token balance");

        // Transfer the tokens
        require(token.transfer(to, contractBalance), "Token transfer failed");
    }

    receive() external payable {}
}
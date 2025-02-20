// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "./openzeppelin_contracts_utils_Context.sol";
import "./openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol" as IERC20;
import "./contracts_interfaces_IDataHub.sol";
import "./contracts_interfaces_IDepositVault.sol";
import "./contracts_interfaces_IOracle.sol";
import "./contracts_interfaces_IUtilityContract.sol";
import "./contracts_libraries_EVO_LIBRARY.sol";
import "./contracts_interfaces_IInterestData.sol";

// custom errors
error CustomError(string errorMsg);

/// @title This is the EVO Exchange contract
/// @author EVO X Labs.
/// @notice This contract is responsible for sending trade requests to the Oracle
/// contract to be validated by the validator and execute the trades once confirmed

contract EVO_EXCHANGE is Ownable2StepUpgradeable {
    /** Address's  */

    /// @notice Datahub contract
    IDataHub public Datahub;

    /// @notice Oracle contract
    IOracle public Oracle;

    /// @notice Deposit vaultcontract
    IDepositVault public DepositVault;

    /// @notice Interest contract
    IInterestData public interestContract;

    /// @notice The Utilities contract
    IUtilityContract public Utilities;
    /// @notice The Order book provider wallet address
    address public OrderBookProviderWallet;
    /// @notice The Liquidator contract address
    address public Liquidator;
    /// @notice The DAO wallet address
    address public DAO;

    mapping(address => mapping(bytes32 => bool))
        private isPendingTokenOutAggregatedTrade;
    mapping(address => mapping(bytes32 => bool))
        private isPendingTokenInAggregatedTrade;
    mapping(address => mapping(bytes32 => uint256))
        private pendingAmountOutAggregatedTrade;

    /// @notice Keeps track of contract admins
    mapping(address => bool) public admins;
    /// @notice The mapping for validator wallets
    mapping(address => bool) private validators;

    mapping(string => bool) public tradeId;

    event EventTrade(
        bytes32[2] pair,
        address[] takers,
        address[] makers,
        uint256[] taker_amounts,
        uint256[] maker_amounts,
        uint256[] TakerliabilityAmounts,
        uint256[] MakerliabilityAmounts,
        bool[][2] trade_side,
        string trade_id
    );

    struct CrossChainAggregatedTrade {
        address user;
        bytes32[2] path; // path[0]: tokenOut, path[1]: tokenIn
        uint256 amountOut; // Vault -> Uniswap
        uint256 amountInMin; // Vault <- Uniswap
        string[2] chainId; // 1 | 137 | BTC | SOL
        string[2] tokenAddress; // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
    }
    uint256 public crossChainAggregatedTradeNonce;
    mapping(uint256 => CrossChainAggregatedTrade)
        public crossChainAggregatedTradeDetail;

    struct AggregatedTradeInfo {
        address user;
        bytes32[2] path; // path[0]: tokenOut, path[1]: tokenIn
        bytes32 path0_token;
        bytes32 path1_token;
        uint256 amountOut; // Vault -> Uniswap
        uint256 amountInMin; // Vault <- Uniswap
        string[2] chainId; // 1 | 137 | BTC | SOL
        string[2] tokenAddress; // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
        bool crossChain;
        uint256 crossChainAggregatedTrade_nonce; // only if crossChain = true - idk how the fuck to include this parameter
    }

    // event NewTokenInitialized(string chainId, string assetAddress);

    /// @notice Initializes the contract
    function initialize(
        address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address oracle,
        address _utility,
        address _interest,
        address _liquidator
    ) public initializer {
        __Context_init();
        __Ownable_init(initialOwner);
        crossChainAggregatedTradeNonce = 0;

        admins[address(this)] = true;
        alterAdminRoles(
            _DataHub,
            _deposit_vault,
            oracle,
            _utility,
            _interest,
            _liquidator
        );
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Oracle = IOracle(oracle);
        Utilities = IUtilityContract(_utility);
        interestContract = IInterestData(_interest);
        OrderBookProviderWallet = msg.sender;
        DAO = msg.sender;
        Liquidator = _liquidator;
    }

    // NOTE WHY IS THIS FUNCTION PUBLIC???????? THIS LOOKS DANGEROUS!!
    // @notice Alters the Admin roles for the contract
    // @param _datahub  the new address for the datahub
    // @param _deposit_vault the new address for the deposit vault
    // @param _oracle the new address for oracle
    // @param _util the new address for the utility contract
    // @param  _int the new address for the interest contract
    // @param _liquidator the liquidator addresss
    function alterAdminRoles(
        address _datahub,
        address _deposit_vault,
        address _oracle,
        address _util,
        address _interest,
        address _liquidator
    ) public onlyOwner {
        admins[address(Datahub)] = false;
        admins[_datahub] = true;
        Datahub = IDataHub(_datahub);

        admins[address(DepositVault)] = false;
        admins[_deposit_vault] = true;
        DepositVault = IDepositVault(_deposit_vault);

        admins[address(Oracle)] = false;
        admins[_oracle] = true;
        Oracle = IOracle(_oracle);

        admins[address(Utilities)] = false;
        admins[_util] = true;
        Utilities = IUtilityContract(_util);

        admins[address(interestContract)] = false;
        admins[_interest] = true;
        interestContract = IInterestData(_interest);

        admins[address(Liquidator)] = false;
        admins[_liquidator] = true;
        Liquidator = _liquidator;
    }

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

    // modifier checkCrossChainAggregatedTrade(bool crossChain) {
    //     if (crossChain) {
    //         require(admins[msg.sender] == true, "Unauthorized");
    //     }
    //     _;
    // }

    /// @notice Fetches the current orderbook provider wallet
    function fetchOrderBookProvider() public view returns (address) {
        return OrderBookProviderWallet;
    }

    /// @notice Fetches the current DAO wallet
    function fetchDaoWallet() public view returns (address) {
        return DAO;
    }

    /// @notice Sets a new orderbook provider wallet
    function setOrderBookProvider(address _newwallet) external onlyOwner {
        OrderBookProviderWallet = _newwallet;
    }

    /// @notice Sets a new DAO wallet
    function setDaoWallet(address _dao) external onlyOwner {
        DAO = _dao;
    }

    function validateValidatorForTrade(
        bytes32[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        bool[][2] memory trade_side,
        string memory trade_id,
        uint8 v, // backend signature.v
        bytes32 r, // backend signature.r
        bytes32 s // backend signature.a
    ) internal view returns (bool) {
        //----- Validate Validator -------------------
        bytes32 _hashedData = keccak256(
            abi.encode(
                pair[0],
                pair[1],
                participants[0][0],
                participants[1][0],
                trade_amounts[0][0],
                trade_amounts[1][0],
                trade_side[0][0],
                trade_side[1][0],
                trade_id
            )
        );
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(
            abi.encodePacked(prefix, _hashedData)
        );
        address backend_signer = ecrecover(prefixedHashMessage, v, r, s);
        return validators[backend_signer];
    }

    /// @notice This is the function users need to submit an order to the exchange
    /// @dev It first goes through some validation by checking if the circuit breaker is on
    /// @dev It calculates the amount to add to their liabilities by fetching their current assets and seeing the difference between the trade amount and assets
    /// @dev it then checks that the trade will not exceed the max borrow proportion, and that the user can indeed take more margin
    /// @dev it then calls the oracle
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function SubmitOrder(
        bytes32[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        bool[][2] memory trade_side,
        string memory trade_id,
        uint8 v, // backend signature.v
        bytes32 r, // backend signature.r
        bytes32 s // backend signature.a
    ) external {
        // console.log("========================submit order function==========================");
        require(DepositVault.viewcircuitBreakerStatus() == false);

        require(tradeId[trade_id] == false, "Already processed");
        tradeId[trade_id] = true;

        //----- Validate Validator -------------------
        require(
            validateValidatorForTrade(
                pair,
                participants,
                trade_amounts,
                trade_side,
                trade_id,
                v,
                r,
                s
            ) == true,
            "Invalid Backend Signer"
        );

        //--------------------------------------------
        interestContract.updateCIMandTBA(pair[0]);
        interestContract.updateCIMandTBA(pair[1]);
        (
            uint256[] memory takerLiabilities,
            uint256[] memory makerLiabilities
        ) = Utilities.calculateTradeLiabilityAddtions(
                pair,
                participants,
                trade_amounts
            );

        // console.log("taker liabilities", takerLiabilities[0]);
        // console.log("maker liabilities", makerLiabilities[0]);

        // this checks if the asset they are trying to trade isn't pass max borrow

        // This seems kind of useless, but whatever
        require(
            Utilities.validateTradeAmounts(trade_amounts),
            "Never 0 trades"
        );

        // NOTE: MAX BORROW CHECK HAS BEEN COMMENTED OUT IN OUR UTILS - WE PROBABLY NEED TO PUT IT BACK IN RIGHT???
        // require(
        //     Utilities.maxBorrowCheck(pair, participants, trade_amounts),
        //     "This trade puts the protocol above maximum borrow proportion and cannot be completed"
        // );

        // NOTE PLEASE SEE COMMENT BELOW. THAT FUNCTION IS VERY WRONG.
        // require(
        //     Utilities.processMargin(pair, participants, trade_amounts), // the process checks function that the processMargin function is calling is completely wrong and needs to be done from scratch I think
        //     "This trade failed the margin checks for one or more users"
        // );

        Oracle.ProcessTrade(
            pair,
            participants,
            trade_amounts,
            trade_side,
            takerLiabilities,
            makerLiabilities
        );

        emit EventTrade(
            pair,
            participants[0], // takers
            participants[1], // makers
            trade_amounts[0], // taker_amounts
            trade_amounts[1], // maker_amounts
            takerLiabilities,
            makerLiabilities,
            trade_side,
            trade_id
        );
    }

    /// @notice This called the execute trade functions on the particpants and checks if the assets are already in their portfolio
    /// @param pair the pair of assets involved in the trade
    /// @param takers the taker wallet addresses
    /// @param makers the maker wallet addresses
    /// @param taker_amounts the taker amounts in the trade
    /// @param maker_amounts the maker amounts in the trade
    /// @param TakerliabilityAmounts the new liabilities being issued to the takers
    /// @param MakerliabilityAmounts the new liabilities being issued to the makers
    function TransferBalances(
        bytes32[2] memory pair,
        address[] memory takers,
        address[] memory makers,
        uint256[] memory taker_amounts,
        uint256[] memory maker_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts,
        bool[][2] memory trade_side
    ) public checkRoleAuthority {
        require(DepositVault.viewcircuitBreakerStatus() == false);

        executeTrade(
            takers,
            trade_side[0],
            maker_amounts,
            taker_amounts,
            TakerliabilityAmounts,
            pair[0],
            pair[1]
        );

        executeTrade(
            makers,
            trade_side[1],
            taker_amounts,
            maker_amounts,
            MakerliabilityAmounts,
            pair[1],
            pair[0]
        );
    }

    // NOTE: Every time we update liabilites we should probably add the assets first so that the AIMR checks can be done properly
    // PLEASE SEE HOW TO DO THIS ON THIS FUNCTION
    // Probably a lot of it needs to be re-written altogether.

    /// @notice This is called to execute the trade
    /// @dev Read the code comments to follow along on the logic
    /// @param users the users involved in the trade
    /// @param amounts_in_token the amounts coming into the users wallets
    /// @param amounts_out_token the amounts coming out of the users wallets
    /// @param  liabilityAmounts new liabilities being issued
    /// @param  out_token the token leaving the users wallet
    /// @param  in_token the token coming into the users wallet
    function executeTrade(
        address[] memory users,
        bool[] memory trade_side,
        uint256[] memory amounts_in_token,
        uint256[] memory amounts_out_token,
        uint256[] memory liabilityAmounts,
        bytes32 out_token,
        bytes32 in_token
    ) private {
        // Although we already call this in the submit order function, since the oracles take a non-zero time to come back for execution
        // we should probably do the update again. Please let me know what you think.
        interestContract.updateCIMandTBA(in_token);
        interestContract.updateCIMandTBA(out_token);

        // console.log("===========================executeTrade Function===========================");
        uint256 amountToAddToLiabilities;
        uint256 usersLiabilities;
        for (uint256 i = 0; i < users.length; i++) {
            amountToAddToLiabilities = liabilityAmounts[i];

            // NOTE: I MOVED ALL OF THE IN_TOKEN LOGIC ABOVE THE OUT_TOKEN LOGIC SO THAT USERS
            // ARE GIVEN THEIR ASSETS BEFORE GOING THROUGH AIMR CHECKS IN THE UPDATELIABILITIES FUNCTION
            // WE NEED TO TEST THIS

            // Replaced how we get liabilities
            usersLiabilities = interestContract
                .calculateActualCurrentLiabilities(users[i], in_token);
            // if (usersLiabilities > 0) {
            //    uint256 interestCharge = interestContract.returnInterestCharge(
            //        users[i],
            //        in_token
            //    );
            //    usersLiabilities = usersLiabilities + interestCharge;
            // }

            uint256 tradeFeeForTaker = Datahub.tradeFee(in_token, 0);
            uint256 tradeFeeForMaker = Datahub.tradeFee(in_token, 1);
            // console.log("amount in - liability", amounts_in_token[i], usersLiabilities);
            if (amounts_in_token[i] <= usersLiabilities) {
                uint256 input_amount = amounts_in_token[i];

                if (msg.sender != address(Liquidator)) {
                    divideFee(
                        in_token,
                        (input_amount * (tradeFeeForTaker - tradeFeeForMaker)) /
                            10 ** 18
                    );
                    input_amount =
                        input_amount -
                        (input_amount * tradeFeeForTaker) /
                        10 ** 18;
                }

                // subtract from their liabilities, do not add to assets just subtract from liabilities
                interestContract.updateLiabilities(
                    users[i],
                    in_token,
                    input_amount,
                    true
                );

                // edit inital margin requirement, and maintenance margin requirement of the user
                // modifyMarginValues(users[i], in_token, out_token, amounts_in_token[i]);
            } else {
                // This will check to see if they are technically still margined and turn them off of margin status if they are eligable
                // We don't need this anymore, it's already in the updateLiabilities function
                // Datahub.changeMarginStatus(msg.sender);

                uint256 input_amount = amounts_in_token[i];

                if (msg.sender != address(Liquidator)) {
                    // below we charge trade fees it is not called if the msg.sender is the liquidator
                    // PLEASE TRIPLE CHECK THAT WE ARE DOING THE TRADE FEES CORRECTLY HERE
                    // uint256 tradeFeeForTaker = Datahub.tradeFee(in_token, 0);
                    // uint256 tradeFeeForMaker = Datahub.tradeFee(in_token, 1);
                    if (!trade_side[i]) {} else {
                        divideFee(
                            in_token,
                            (input_amount *
                                (tradeFeeForTaker - tradeFeeForMaker)) /
                                10 ** 18
                        );
                        input_amount =
                            input_amount -
                            (input_amount * tradeFeeForTaker) /
                            10 ** 18;
                    }
                }

                if (usersLiabilities > 0) {
                    input_amount = input_amount - usersLiabilities;
                    interestContract.updateLiabilities(
                        users[i],
                        in_token,
                        usersLiabilities,
                        true
                    );
                    // edit inital margin requirement, and maintenance margin requirement of the user
                    // modifyMarginValues(users[i], in_token, out_token, input_amount);
                }
                // add remaining amount not subtracted from liabilities to assets
                Datahub.addAssets(users[i], in_token, input_amount); // We need to put this above the updateLiabilities functions in each
                // part of this function, but the input_amount is dependent on a lot of them. Might need to part it out and put them in each individual statement
            }

            if (amountToAddToLiabilities != 0) {
                interestContract.updateLiabilities(
                    users[i],
                    out_token,
                    amountToAddToLiabilities,
                    false // PLEASE TELL ME WHAT FALSE AND TRUE MEAN FOR THIS
                );

                // IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(
                //     in_token
                // );
            }

            // remove their pending balances
            Datahub.removePendingBalances(
                users[i],
                out_token,
                amounts_out_token[i], // Check to see if this is the right value to remove from pending balances, might cause an underflow because what was originally put in isn't the full amount_out
                true
            );
        }

        //------- Checking User's balance ---------------------------
        for (uint256 j = 0; j < users.length; j++) {
            bool isDuplicate = false;
            for (uint256 k = 0; k < j; k++) {
                if (users[k] == users[j]) {
                    isDuplicate = true;
                    break;
                }
            }

            // COMMENTED THIS OUT BECAUSE THE UPDATELIABILITIES FUNCTION ALREADY DOES THIS
            // What is this isDuplicate variable??
            // if (!isDuplicate) {
            //     uint256 usersAIMR = Datahub.calculateAIMRForUser(users[j]);
            //     uint256 usersTCV = Datahub.calculateCollateralValue(users[j]);

            //     require(
            //         usersAIMR < usersTCV,
            //         "Cannot Borrow because it reached out the limit"
            //     );
            // }
        }
    }

    // The steps needed for a cross-chain aggregated trade are:
    // 1: chain[0] ERC20 -> USDC aggregatedTrade
    // 2: Check if chain[1].USDC is >= USDC input from step 1
    // 3: If it is then directly do a chain[1].USDC -> path[1] aggregatedTrade // This would complete the trade for the user
    // 4: Else do chain[0].USDC -> chain[1].USDC CCTP
    // 5: Then do chain[1].USDC -> path[1] aggregatedTrade // This would complete the trade for the user
    // Function that first swaps token to USDC for cross-chain trades, then calls aggregatedTrade
    function crossChainAggregatedTrade(
        bytes32[2] memory path, // path[0]: tokenOut, path[1]: tokenIn (End path - i.e. token from chain0 to token from chain1)
        uint256 amountOut, // Vault -> Uniswap
        uint256 amountInMin, // Vault <- Uniswap (path[1] minimum amount in)
        uint256 usdcAmountInMin, // ADDED for the first leg of the trade (i.e. path[0] -> chain[0].USDC)
        string[2] memory chainId, // 1 | 137 | BTC | SOL
        string[2] memory tokenAddress // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
    ) public payable {
        require(
            path[0] ==
                keccak256(abi.encodePacked(chainId[0], ".", tokenAddress[0])), // && path[0] != USDC
            "Invalid Token_Out Id"
        );
        require(
            path[1] ==
                keccak256(abi.encodePacked(chainId[1], ".", tokenAddress[1])),
            "Invalid Token_In Id"
        );

        // Add requirement for chainId[0] && chainId[1] to both be CCTP capable chains

        // Add requirement for path[0] != USDC
        require(
            DepositVault.isUSDC(path[0]) == false,
            "Please call the regular aggregatedTrade function"
        );

        // Add crossChainAggregatedTrade NONCE logic here
        // within the nonce logic we want to save what the second leg of the trade is going to be for the success case
        // When the regular aggregatedTrade comes back from the back end with success, it will feed the nonce to call
        // the second part of the aggregatedTrade
        crossChainAggregatedTradeNonce++;
        uint256 currentNonce = crossChainAggregatedTradeNonce;

        crossChainAggregatedTradeDetail[currentNonce] = CrossChainAggregatedTrade({
        user: msg.sender,
        path: path,
        amountOut: amountOut,
        amountInMin: amountInMin,
        chainId: chainId,
        tokenAddress: tokenAddress
    });

        bytes32 inChainUSDC = DepositVault.getUsdcForChain(chainId[0]);
        string memory inChainUSDCAddress = Datahub
            .returnAssetLogs(inChainUSDC)
            .assetAddress;

        aggregatedTrade(
            [path[0], inChainUSDC],
            amountOut,
            usdcAmountInMin,
            [chainId[0], chainId[0]],
            [tokenAddress[0], inChainUSDCAddress],
            true,
            currentNonce
        );
    }

    // User should call this function for aggregatedtrade
    function aggregatedTrade(
        bytes32[2] memory path, // path[0]: tokenOut, path[1]: tokenIn
        uint256 amountOut, // Vault -> Uniswap
        uint256 amountInMin, // Vault <- Uniswap
        string[2] memory chainId, // 1 | 137 | BTC | SOL
        string[2] memory tokenAddress, // [0, 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359] -> [native token, usdc]
        bool crossChain,
        uint256 crossChainAggregatedTrade_nonce // only if crossChain = true - idk how the fuck to include this parameter
    ) public payable {
        if (!Datahub.returnAssetLogs(path[1]).initialized) {
            Datahub.selfInitTokenMarket(path[1], chainId[1], tokenAddress[1]); // Totally forgot we need to test this
        }
        require(
            msg.value >= DepositVault.getGasLimit(),
            "Insufficient gas fee"
        );
        require(
            DepositVault.getGasWallet() != address(0),
            "Invalid gas wallet"
        );
        (bool success, ) = payable(DepositVault.getGasWallet()).call{
            value: msg.value
        }("");
        require(success);

        // chainId : 1 | ... | 137 | ... | BTC | SOL
        // tokenAddress : in polygon ( native token : 0,    usdc: 0x3c499c542cef5e3811e1192ce70d8cc03d5c3359 )
        require(
            path[0] ==
                keccak256(abi.encodePacked(chainId[0], ".", tokenAddress[0])),
            "Invalid Token_Out Id"
        );
        require(
            path[1] ==
                keccak256(abi.encodePacked(chainId[1], ".", tokenAddress[1])),
            "Invalid Token_In Id"
        );

        require(path[0] != path[1], "Invalid trade"); // Including the case where both path0 and path1 are USDC.USDC
        require(
            keccak256(abi.encodePacked(chainId[0])) ==
                keccak256(abi.encodePacked(chainId[1])),
            "Please call crossChainAggregatedTrade function"
        );

        address user = msg.sender;
        if (admins[msg.sender] == true){
            user = crossChainAggregatedTradeDetail[
                crossChainAggregatedTrade_nonce
            ].user; 
        }
        if (crossChain == true) {
            require(
                DepositVault.isUSDC(path[0]) == false &&
                    DepositVault.isUSDC(path[1]) == true,
                "Invalid crossChainAggregatedTrade"
            );

            user = crossChainAggregatedTradeDetail[
                crossChainAggregatedTrade_nonce
            ].user;
            require(msg.sender == user, "You are not allowed to call this function for other users");
        }

        bytes32 path0_token = path[0];
        if (DepositVault.isUSDC(path[0])) {
            interestContract.updateCIMandTBA(path0_token);
            path[0] = DepositVault.tokenUsdcUsdc();
        }
        bytes32 path1_token = path[1];
        if (DepositVault.isUSDC(path[1])) {
            interestContract.updateCIMandTBA(path1_token);
            path[1] = DepositVault.tokenUsdcUsdc();
        }

        aggregated_trade_out_process(user, path[0], amountOut);

        AggregatedTradeInfo memory aggregatedTradeInfo;
        aggregatedTradeInfo.user = user;
        aggregatedTradeInfo.path = path;
        aggregatedTradeInfo.path0_token = path0_token;
        aggregatedTradeInfo.path1_token = path1_token;
        aggregatedTradeInfo.amountOut = amountOut;
        aggregatedTradeInfo.amountInMin = amountInMin;
        aggregatedTradeInfo.chainId = chainId;
        aggregatedTradeInfo.tokenAddress = tokenAddress;
        aggregatedTradeInfo.crossChain = crossChain;
        aggregatedTradeInfo
            .crossChainAggregatedTrade_nonce = crossChainAggregatedTrade_nonce;
        processForAggregatedTrade(aggregatedTradeInfo);
    }

    function aggregated_trade_out_process(
        address user,
        bytes32 tokenOut,
        uint256 amountOut
    ) internal {
        require(
            !DepositVault.viewcircuitBreakerStatus(),
            "circuit breaker active"
        );
        require(
            Datahub.returnAssetLogs(tokenOut).initialized,
            "this asset is not available to be deposited or traded"
        );

        interestContract.updateCIMandTBA(tokenOut);

        // NOTE: WILL CHANGE THIS WITH EARNING LOGIC
        // utility.debitAssetInterest(user, token);

        // NOTE: PLEASE DELETE ANY UNUSED VARIABLES AND LEAVE COMMAS
        uint256 assets = Datahub.ReadUserData(user, tokenOut).assets;
        uint256 pending = Datahub.ReadUserData(user, tokenOut).pending;
        // Datahub.setAssetInfo(0, token, earningRate, true);

        require(
            pending == 0,
            "You must have a 0 pending trade balance to withdraw, please wait for your trade to settle before attempting to withdraw"
        );

        // NOTE: Think about making a function that allows users to borrow when withdrawing
        require(
            amountOut <= assets,
            "More assets required for this transaction"
        );

        // Datahub.removeAssets(user, token, amount);
        Datahub.addPendingBalances(user, tokenOut, amountOut, true);
        Datahub.setAssetInfo(0, tokenOut, amountOut, false); // 0 -> totalSupply

        // NOTE: DELETED BELOW BECAUSE WE DON'T HAVE INDEXES ANYMORE AND EARNING LOGIC IS CHANGING
        // Datahub.alterUsersEarningRateIndex(user, token);
        // NOTE: DELETED BELOW BECAUSE WE KEEP TRACK OF INTEREST VIA THE CIM NOW
        // if (liabilities > 0) {
        //    uint256 interestCharge = interestContract.returnInterestCharge(
        //        user,
        //        token
        //    );
        //    Datahub.addLiabilities(user, token, interestCharge);
        //    Datahub.setAssetInfo(1, token, interestCharge, true); // 0 -> totalSupply
        // }
        // Datahub.alterUsersInterestRateIndex(user, token);

        uint256 usersAIMR = Datahub.calculateAIMRForUser(user);
        uint256 usersTCV = Datahub.calculateCollateralValue(user);

        require(usersAIMR <= usersTCV, "Cannot withdraw");
    }

    function processForAggregatedTrade(
        AggregatedTradeInfo memory aggregatedTradeInfo
    ) internal {
        if (
            aggregatedTradeInfo.path[0] == DepositVault.tokenUsdcUsdc() &&
            aggregatedTradeInfo.amountOut >
            Datahub.returnAssetLogs(aggregatedTradeInfo.path0_token).assetInfo[
                0
            ]
        ) {
            // CCTP + Uniswap
            (
                bytes32[] memory src_tokens,
                uint256[] memory src_amounts
            ) = DepositVault.cycleUSDC(aggregatedTradeInfo.amountOut);

            Utilities.updateLastCctpCycleTxId(aggregatedTradeInfo.user);
            uint256 transactionId = Utilities.getLastCctpCycleTxId(
                aggregatedTradeInfo.user
            );
            Utilities.setCctpCycleTxIdCurrentSuccessAmount(
                aggregatedTradeInfo.user,
                transactionId,
                0
            );
            Utilities.setCctpCycleTxIdCurrentFailedAmount(
                aggregatedTradeInfo.user,
                transactionId,
                0
            );
            Utilities.setCctpCycleTxIdTotalAmount(
                aggregatedTradeInfo.user,
                transactionId,
                aggregatedTradeInfo.amountOut
            );

            aggregatedTradeInfo.path[0] = aggregatedTradeInfo.path0_token;
            Utilities.setAggregatedTradeInfo(
                transactionId,
                aggregatedTradeInfo.user,
                aggregatedTradeInfo.path,
                aggregatedTradeInfo.amountOut,
                aggregatedTradeInfo.amountInMin,
                aggregatedTradeInfo.chainId[0],
                aggregatedTradeInfo.tokenAddress
            );

            for (uint256 i = 0; i < src_tokens.length; i++) {
                Datahub.setAssetInfo(0, src_tokens[i], src_amounts[i], false);
                Utilities.addCctpCycleTxIdTokens(
                    aggregatedTradeInfo.user,
                    transactionId,
                    src_tokens[i]
                );
                Utilities.addCctpCycleTxIdAmounts(
                    aggregatedTradeInfo.user,
                    transactionId,
                    src_amounts[i]
                );

                Oracle.ProcessCycleCCTPForAggregatedTrade(
                    aggregatedTradeInfo.user,
                    transactionId,
                    src_tokens[i],
                    aggregatedTradeInfo.path0_token,
                    src_amounts[i]
                );
            }
        } else {
            // Uniswap
            if (aggregatedTradeInfo.path[0] == DepositVault.tokenUsdcUsdc()) {
                Datahub.setAssetInfo(
                    0,
                    aggregatedTradeInfo.path0_token,
                    aggregatedTradeInfo.amountOut,
                    false
                ); // 0 -> totalSupply
            }
            aggregatedTradeInfo.path[1] = aggregatedTradeInfo.path1_token;
            Oracle.ProcessAggregatedTrade(
                aggregatedTradeInfo.user,
                aggregatedTradeInfo.path,
                aggregatedTradeInfo.amountOut,
                aggregatedTradeInfo.amountInMin,
                aggregatedTradeInfo.chainId[0],
                aggregatedTradeInfo.tokenAddress,
                aggregatedTradeInfo.crossChain,
                aggregatedTradeInfo.crossChainAggregatedTrade_nonce
            );
        }
    }

    // CHANGED PERMISSION TO checkRoleAuthority NOT SURE IF THIS IS RIGHT!!!! IT WAS PUBLIC BEFORE
    function divideFee(
        bytes32 token,
        uint256 amount
    ) public checkRoleAuthority {
        address daoWallet = fetchDaoWallet();
        address orderBookProvider = fetchOrderBookProvider();

        Datahub.addAssets(daoWallet, token, (amount * 90) / 100);
        Datahub.addAssets(orderBookProvider, token, (amount * 10) / 100);
    }

    function withdrawAllLendingPoolAssets(bytes32 token) external {
        interestContract.updateCIMandTBA(token);

        uint256 amount = interestContract
            .calculateActualCurrentLendingPoolAssets(msg.sender, token);
        interestContract.updateLendingPoolAssets(token, amount, false);
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
// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "./openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol" as ERC20;
import "@openzeppelin/contracts/interfaces/IERC20.sol" as IERC20;
import "./contracts_libraries_EVO_LIBRARY.sol";
import "./contracts_interfaces_IExecutor.sol";
import "./contracts_interfaces_IOracle.sol";
import "./contracts_interfaces_IInterestData.sol";
import "./contracts_interfaces_IUtilityContract.sol";

contract DepositVault is Ownable2StepUpgradeable {
    mapping(bytes32 => bool) public isUsdc;
    bytes32[] public usdcList;
    bytes32 public tokenUsdcUsdc;

    mapping(address => mapping(bytes32 => bool)) private isPendingTokenCctp;
    mapping(address => mapping(bytes32 => uint256)) private pendingAmountCctp;

    event EventDeposit(
        string depositId,
        address user,
        bytes32 token,
        uint256 amount,
        uint256 timestamp,
        string chainId,
        string assetAddress
    );

    mapping(address => bool) public admins;
    mapping(address => bool) public validators;

    address private _gasWallet;
    uint256 private _gasLimit;

    mapping(string => bool) public depositId;

    IDataHub public Datahub;
    IExecutor public Executor;
    IInterestData public interestContract;
    IUtilityContract public utility;
    IOracle public Oracle;

    // using EVO_LIBRARY for uint256;

    uint256 public WithdrawThresholdValue;

    mapping(address => bool) public userInitialized;
    mapping(uint256 => address) public userId;

    mapping(address => uint256) public token_withdraws_hour;

    event hazard(uint256, uint256);

    error DangerousWithdraw();

    bool circuitBreakerStatus;

    uint256 public lastUpdateTime;
    /// @notice Initializes the contract

    mapping(string => bytes32) public usdcForChain;

    function initialize(
        address initialOwner,
        address dataHub,
        address executor,
        address interest,
        address oracle,
        address _utility
    ) public initializer {
        __Context_init();
        __Ownable_init(initialOwner);

        Datahub = IDataHub(dataHub);
        Executor = IExecutor(executor);
        interestContract = IInterestData(interest);
        Oracle = IOracle(oracle);
        utility = IUtilityContract(_utility);
        admins[address(this)] = true;

        string memory tokenUsdcUsdc_str = string(abi.encodePacked("USDC.USDC"));
        tokenUsdcUsdc = keccak256(abi.encodePacked(tokenUsdcUsdc_str));

        WithdrawThresholdValue = 1000000 * 10 ** 18;
        circuitBreakerStatus = false;
    }

    function alterAdminRoles(
        address dataHub,
        address executor,
        address interest,
        address _oracle,
        address _utility
    ) public onlyOwner {
        admins[address(Datahub)] = false;
        admins[dataHub] = true;
        Datahub = IDataHub(dataHub);

        admins[address(Executor)] = false;
        admins[executor] = true;
        Executor = IExecutor(executor);

        admins[address(interestContract)] = false;
        admins[interest] = true;
        interestContract = IInterestData(interest);

        admins[address(Oracle)] = false;
        admins[_oracle] = true;
        Oracle = IOracle(_oracle);

        admins[address(utility)] = false;
        admins[_utility] = true;
        utility = IUtilityContract(_utility);
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

    function toggleCircuitBreaker(bool onOff) public onlyOwner {
        circuitBreakerStatus = onOff;
    }

    function viewcircuitBreakerStatus() external view returns (bool) {
        return circuitBreakerStatus;
    }

    /// @notice Get a Gas Wallet
    function getGasWallet() external view returns (address) {
        return _gasWallet;
    }

    /// @notice Sets a Gas Wallet
    function setGasWallet(address _gas_wallet) external onlyOwner {
        _gasWallet = _gas_wallet;
    }

    /// @notice Get a Gas Limit
    function getGasLimit() external view returns (uint256) {
        return _gasLimit;
    }

    /// @notice Sets a Gas Limit
    function setGasLimit(uint256 _gas_limit) external onlyOwner {
        _gasLimit = _gas_limit;
    }

    // function _USDC() external view returns (address) {
    //     return USDC;
    // }
    function isUSDC(bytes32 token) external view returns (bool) {
        return isUsdc[token];
    }

    function getUsdcList() external view returns (bytes32[] memory) {
        return usdcList;
    }

    function getUsdcForChain(
        string memory chainId
    ) external view returns (bytes32) {
        return usdcForChain[chainId];
    }

    // MAKE SURE TO UPDATE THIS WITH THE USDC TOKEN ADDRESS OF EVERY CHAIN!!!!
    // function setUSDC(address input) external onlyOwner {
    //     USDC = address(input);
    // }
    function setUSDC(bytes32 token) external onlyOwner {
        require(
            Datahub.returnAssetLogs(token).initialized,
            "The token has not been initialized yet"
        );
        isUsdc[token] = true;
        bool isExist = false;
        for (uint256 i = 0; i < usdcList.length; i++) {
            if (usdcList[i] == token) {
                isExist = true;
                break;
            }
        }
        if (!isExist) {
            // Token not found for the current user, add it to the array
            usdcList.push(token);
            usdcForChain[Datahub.returnAssetLogs(token).chainId] = token;
        }
    }

    function removeUSDC(bytes32 token) external onlyOwner {
        isUsdc[token] = false;
        for (uint256 i = 0; i < usdcList.length; i++) {
            if (token == usdcList[i]) {
                usdcList[i] = usdcList[usdcList.length - 1];
                usdcList.pop();
                usdcForChain[Datahub.returnAssetLogs(token).chainId] = bytes32(0);
                break; // Exit the loop once the token is found and removed
            }
        }
    }

    /// @notice fetches and returns a tokens decimals
    /// @param token the token you want the decimals for
    /// @return Token.decimals() the token decimals

    // function fetchDecimals(bytes32 token) public view returns (uint256) {
    //     ERC20.ERC20 Token = ERC20.ERC20(token);
    //     return Token.decimals();
    // }

    /// @notice This function checks if this user has been initilized
    /// @dev Explain to a developer any extra details
    /// @param user the user you want to fetch their status for
    /// @return bool if they are initilized or not
    function fetchstatus(address user) external view returns (bool) {
        if (userInitialized[user] == true) {
            return true;
        } else {
            return false;
        }
    }

    function alterWithdrawThresholdValue(
        uint256 _updatedThreshold
    ) public onlyOwner {
        WithdrawThresholdValue = _updatedThreshold;
    }

    function getTotalAssetSupplyValue(
        bytes32 token
    ) public view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        uint256 totalValue = (assetLogs.assetPrice * assetLogs.assetInfo[0]) /
            10 ** 18; // 0 -> totalSupply

        return totalValue;
    }

    /* DEPOSIT FUNCTION */
    /// @notice This deposits tokens and inits the user struct, and asset struct if new assets.
    /// @dev Explain to a developer any extra details
    /// @param token - the address of the token to be depositted
    /// @param amount - the amount of tokens to be depositted

    function deposit_token(
        bytes32 token,
        uint256 amount,
        string memory deposit_id,
        uint256 timestamp,
        string memory chainId, // USDC | 137 | 1 | BTC | SOL
        string memory assetAddress, // USDC | lowercase address
        uint8 v, // backend signature.v
        bytes32 r, // backend signature.r
        bytes32 s // backend signature.a
    ) external returns (bool) {
        if (!Datahub.returnAssetLogs(token).initialized) {
            Datahub.selfInitTokenMarket(token, chainId, assetAddress); // Totally forgot we need to test this
        }

        require(
            token == keccak256(abi.encodePacked(chainId, ".", assetAddress)),
            "Invalid Token Info"
        );

        require(depositId[deposit_id] == false, "Already processed");
        depositId[deposit_id] = true;

        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(
            abi.encodePacked(
                prefix,
                keccak256(abi.encode(msg.sender, token, amount, timestamp))
            )
        );
        address backend_signer = ecrecover(prefixedHashMessage, v, r, s);
        require(validators[backend_signer] == true, "Invalid Backend Signer");

        emit EventDeposit(
            deposit_id,
            msg.sender,
            token,
            amount,
            timestamp,
            chainId,
            assetAddress
        );

        return
            deposit_token_process(
                msg.sender,
                token,
                amount
            );
    }

    function deposit_token_process(
        address user,
        bytes32 token,
        uint256 amount
    ) internal returns (bool) {

        require(!circuitBreakerStatus, "circuit breaker active");

        if (!isUsdc[token]) {
            interestContract.updateCIMandTBA(token);
        }
        Datahub.setAssetInfo(0, token, amount, true); // 0 -> totalSupply
        if (isUsdc[token]) {
            token = tokenUsdcUsdc;
            interestContract.updateCIMandTBA(token);
            Datahub.setAssetInfo(0, token, amount, true); // 0 -> totalSupply
        }

        // We don't need to account for lending pool here anymore, we only do that via CLM now
        // uint256 rawLendingPoolAssets = Datahub
        //    .ReadUserData(user, token)
        //    .rawLendingPoolAssets;
        uint256 rawLiabilities = Datahub
            .ReadUserData(user, token)
            .rawLiabilities;

        // Need to incorporate new earning logic here
        // if (rawLendingPoolAssets > 0 && rawLiabilities == 0) {
        // uint256 earningRate = utility.returnEarningProfit(user, token);
        // Datahub.addAssets(user, token, earningRate);
        // Datahub.setAssetInfo(0, token, earningRate, true);
        // Datahub.alterUsersEarningRateIndex(user, token);
        // }

        // SHOULD PROBABLY MAKE A CASE FOR BOTH LENDINGPOOLAMOUNT > 0 && LIABILITIES > 0
        // Actually, maybe not as the simple rawLiabilities > 0 should work fine for this

        // checks to see if user is in the sytem and inits their struct if not
        if (rawLiabilities > 0) {
            // We don't need to do interestCharge anymore, that is done automatically via CIM
            // uint256 interestCharge = interestContract.returnInterestCharge(
            //    user,
            //    token
            // );

            uint256 actualCurrentLiabilities = interestContract
                .calculateActualCurrentLiabilities(user, token);
            if (amount <= actualCurrentLiabilities) {
                interestContract.updateLiabilities(user, token, amount, true); // does true increase or decrease liabilities???

                return true;
            } else {
                Datahub.addAssets(
                    user,
                    token,
                    amount - actualCurrentLiabilities
                ); // add to assets

                interestContract.updateLiabilities(
                    user,
                    token,
                    actualCurrentLiabilities,
                    true
                ); // remove all liabilities

                // NOTE: REMOVED BELOW BECAUSE WE DO THIS IN THE updateLiabilities FUNCTION
                // Datahub.setAssetInfo(1, token, liabilities, false); // 1 -> totalBorrowedAmount

                // Datahub.changeMarginStatus(user);

                // Datahub.alterUsersInterestRateIndex(user, token);
                return true; // NOTE: CAN SOMEBODY TELL ME WTF THIS DOES PLEASE??
            }
        } else {
            Datahub.addAssets(user, token, amount);

            // Datahub.alterUsersInterestRateIndex(user, token);

            return true;
        }
    }

    function deposit_process(
        address user,
        bytes32 token,
        uint256 amount
    ) public checkRoleAuthority returns (bool) {
        return
            deposit_token_process(user, token, amount);
    }

    function cycleUSDC(
        uint256 amount // destination: amount
    ) public returns (bytes32[] memory, uint256[] memory) {
        bytes32[] memory usdcTokens = new bytes32[](usdcList.length);
        uint256[] memory usdcAmounts = new uint256[](usdcList.length);
        // Getting all assets of USDC
        for (uint256 i = 0; i < usdcList.length; i++) {
            usdcTokens[i] = usdcList[i];
            interestContract.updateCIMandTBA(usdcTokens[i]);
            usdcAmounts[i] = Datahub.returnAssetLogs(usdcTokens[i]).assetInfo[
                0
            ];
        }
        // Find Max Chain.USDC
        bytes32 temp_token;
        uint256 temp_amount;
        for (uint256 i1 = 0; i1 < usdcList.length - 1; i1++) {
            for (uint256 i2 = i1 + 1; i2 < usdcList.length; i2++) {
                if (usdcAmounts[i1] < usdcAmounts[i2]) {
                    temp_token = usdcTokens[i1];
                    temp_amount = usdcAmounts[i1];
                    usdcTokens[i1] = usdcTokens[i2];
                    usdcAmounts[i1] = usdcAmounts[i2];
                    usdcTokens[i2] = temp_token;
                    usdcAmounts[i2] = temp_amount;
                }
            }
        }
        // Getting array of source tokens
        uint256 calcAmount = 0;
        uint256 index = 0;
        for (uint256 j = 0; j < usdcList.length; j++) {
            calcAmount += usdcAmounts[j];
            if (calcAmount >= amount) {
                index = j;
                usdcAmounts[j] = amount + usdcAmounts[j] - calcAmount;
                break;
            }
        }
        // Making array to return
        bytes32[] memory srcTokens = new bytes32[](index + 1);
        uint256[] memory srcAmounts = new uint256[](index + 1);
        for (uint256 k = 0; k < index + 1; k++) {
            srcTokens[k] = usdcTokens[k];
            srcAmounts[k] = usdcAmounts[k];
        }
        return (srcTokens, srcAmounts);
    }
    /* WITHDRAW FUNCTION */

    /// @notice This withdraws tokens from the exchange
    /// @dev Explain to a developer any extra details
    /// @param token - the address of the token to be withdrawn
    /// @param amount - the amount of tokens to be withdrawn

    // IMPORTANT MAKE SURE USERS CAN'T WITHDRAW PAST THE LIMIT SET FOR AMOUNT OF FUNDS BORROWED
    function withdraw_token(
        bytes32 token,
        uint256 amount,
        string memory chainId,
        string memory tokenAddress
    ) public payable {
        require(msg.value >= _gasLimit, "Insufficient gas fee");
        require(_gasWallet != address(0), "Invalid gas wallet");
        (bool success, ) = payable(_gasWallet).call{value: msg.value}("");
        require(success);

        /// "POLYGON.0x3c499c542cef5e3811e1192ce70d8cc03d5c3359"      : POLYGON.USDC
        string memory tokenId = string(
            abi.encodePacked(chainId, ".", tokenAddress)
        );
        bytes32 hashedTokenId = keccak256(abi.encodePacked(tokenId));
        require(token == hashedTokenId, "Invalid Token Id");

        require(token != tokenUsdcUsdc, "This is not a valid token");

        bytes32 target_token = token;
        if (isUsdc[token]) {
            interestContract.updateCIMandTBA(target_token);
            token = tokenUsdcUsdc;
        }

        withdraw_token_process(msg.sender, token, amount);

        string memory target_chainId = Datahub
            .returnAssetLogs(target_token)
            .chainId;
        string memory target_token_address = Datahub
            .returnAssetLogs(target_token)
            .assetAddress;
        uint256 target_token_asset = Datahub
            .returnAssetLogs(target_token)
            .assetInfo[0];

        // CCTP can only be called if this process is successful
        if (token == tokenUsdcUsdc && amount > target_token_asset) {
            (
                bytes32[] memory src_tokens,
                uint256[] memory src_amounts
            ) = cycleUSDC(amount);

            for (uint256 i = 0; i < src_tokens.length; i++) {
                Datahub.setAssetInfo(0, src_tokens[i], src_amounts[i], false);

                string memory source_chainId = Datahub
                    .returnAssetLogs(src_tokens[i])
                    .chainId;
                string memory source_token_address = Datahub
                    .returnAssetLogs(src_tokens[i])
                    .assetAddress;

                Oracle.ProcessCCTPForWithdraw(
                    msg.sender,
                    src_tokens[i],
                    target_token,
                    src_amounts[i],
                    source_chainId,
                    source_token_address,
                    target_chainId,
                    target_token_address
                );
            }
        } else {
            if (token == tokenUsdcUsdc) {
                Datahub.setAssetInfo(0, target_token, amount, false); // 0 -> totalSupply
            }
            Oracle.ProcessWithdraw(
                msg.sender,
                token,
                chainId,
                tokenAddress,
                amount
            );
        }
    }

    // I don't think we need this function at all
    // function withdraw_process(
    //     address user,
    //     bytes32 token,
    //     uint256 amount
    // ) public checkRoleAuthority {
    //     withdraw_token_process(user, token, amount);
    // }

    function withdraw_token_process(
        address user,
        bytes32 token,
        uint256 amount
    ) internal {
        require(!circuitBreakerStatus);
        require(
            Datahub.returnAssetLogs(token).initialized == true,
            "this asset is not available to be deposited or traded"
        );

        interestContract.updateCIMandTBA(token);

        // NOTE: WILL CHANGE THIS WITH EARNING LOGIC
        // utility.debitAssetInterest(user, token);

        // NOTE: PLEASE DELETE ANY UNUSED VARIABLES AND LEAVE COMMAS
        uint256 assets = Datahub.ReadUserData(user, token).assets;
        uint256 pending = Datahub.ReadUserData(user, token).pending;
        // Datahub.setAssetInfo(0, token, earningRate, true);

        require(
            pending == 0,
            "You must have a 0 pending trade balance to withdraw, please wait for your trade to settle before attempting to withdraw"
        );

        // NOTE: Think about making a function that allows users to borrow when withdrawing
        require(
            amount <= assets,
            "You cannot withdraw more than your asset balance"
        );

        // Datahub.removeAssets(user, token, amount);
        Datahub.addPendingBalances(user, token, amount, false);
        Datahub.setAssetInfo(0, token, amount, false); // 0 -> totalSupply

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

    // Code20: BACKEND - Think about just having the back end call this function directly instead of being routed through the fulfill function in the Oracle contract
    function withdraw_token_success(
        address user,
        bytes32 token,
        uint256 amount,
        uint256 withdraw_nonce
    ) external checkRoleAuthority {
        Oracle.checkWithdrawalDetails(withdraw_nonce, user, token, amount);
        interestContract.updateCIMandTBA(token);
        if (isUsdc[token]) {
            interestContract.updateCIMandTBA(tokenUsdcUsdc);
            Datahub.removePendingBalances(user, tokenUsdcUsdc, amount, false);
        } else {
            Datahub.removePendingBalances(user, token, amount, false);
        }
        Oracle.setWithdrawalSuccess(withdraw_nonce);
    }

    // Code20: BACKEND - Same as above, think about having back end call this directly
    function withdraw_token_fail(
        address user,
        bytes32 token,
        uint256 amount,
        uint256 withdraw_nonce
    ) external checkRoleAuthority {
        Oracle.checkWithdrawalDetails(withdraw_nonce, user, token, amount);
        interestContract.updateCIMandTBA(token);
        if (isUsdc[token]) {
            interestContract.updateCIMandTBA(tokenUsdcUsdc);
            Datahub.removePendingBalances(user, tokenUsdcUsdc, amount, false);
            Datahub.addAssets(user, tokenUsdcUsdc, amount);
            Datahub.setAssetInfo(0, tokenUsdcUsdc, amount, true);
        } else {
            Datahub.removePendingBalances(user, token, amount, false);
            Datahub.addAssets(user, token, amount);
        }
        Datahub.setAssetInfo(0, token, amount, true);
        Oracle.setWithdrawalFail(withdraw_nonce);
    }

    // Code20: BACKEND - We can probably have the back end call this directly
    function withdraw_token_cctp_success(
        address user,
        bytes32 source_token,
        bytes32 target_token,
        uint256 amount,
        uint256 withdraw_cctp_nonce
    ) external checkRoleAuthority {
        require(isUsdc[source_token], "This is not USDC");
        require(isUsdc[target_token], "This is not USDC");
        Oracle.checkWithdrawalCCTPDetails(
            withdraw_cctp_nonce,
            user,
            source_token,
            target_token,
            amount
        );

        interestContract.updateCIMandTBA(target_token);
        interestContract.updateCIMandTBA(tokenUsdcUsdc);

        Datahub.removePendingBalances(user, tokenUsdcUsdc, amount, false);
        Oracle.setWithdrawalCCTPSuccess(withdraw_cctp_nonce);
    }

    // Code20: BACKEND - Same as above
    function withdraw_token_cctp_fail(
        address user,
        bytes32 source_token,
        bytes32 target_token,
        uint256 amount,
        uint256 withdraw_cctp_nonce
    ) external checkRoleAuthority {
        require(isUsdc[source_token], "This is not USDC");
        require(isUsdc[target_token], "This is not USDC");

        Oracle.checkWithdrawalCCTPDetails(
            withdraw_cctp_nonce,
            user,
            source_token,
            target_token,
            amount
        );

        interestContract.updateCIMandTBA(source_token);
        interestContract.updateCIMandTBA(tokenUsdcUsdc);

        Datahub.removePendingBalances(user, tokenUsdcUsdc, amount, false);
        Datahub.addAssets(user, tokenUsdcUsdc, amount);
        Datahub.setAssetInfo(0, tokenUsdcUsdc, amount, true);
        Datahub.setAssetInfo(0, source_token, amount, true);

        Oracle.setWithdrawalCCTPFail(withdraw_cctp_nonce);
    }

    // This function is a copy of the withdraw_token_process function except it doesn't alter the supply of tokens in the exchange
    // Renamed into deposit process even though it acts as a withdrawal because it's depositing into the lending pool while withdrawing
    // from their "assets"
    function lendingPoolDepositProcess(
        address user,
        bytes32 token,
        uint256 amount
    ) public checkRoleAuthority {
        require(!circuitBreakerStatus);
        require(
            Datahub.returnAssetLogs(token).initialized == true,
            "this asset is not available to be deposited or traded"
        );
        // Deleted because it's already called in the updateLendingPoolAssets function
        // interestContract.updateCIMandTBA(token);

        // NOTE: WILL CHANGE THIS WITH EARNING LOGIC
        // utility.debitAssetInterest(user, token);

        // NOTE: PLEASE DELETE ANY UNUSED VARIABLES AND LEAVE COMMAS
        uint256 assets = Datahub.ReadUserData(user, token).assets;
        uint256 pending = Datahub.ReadUserData(user, token).pending;
        // Datahub.setAssetInfo(0, token, earningRate, true);

        require(
            pending == 0,
            "You must have a 0 pending trade balance to withdraw, please wait for your trade to settle before attempting to withdraw"
        );

        // NOTE: Think about making a function that allows users to borrow when withdrawing
        require(
            amount <= assets,
            "You cannot withdraw more than your asset balance"
        );

        Datahub.removeAssets(user, token, amount);
        // Removed this because the supply is still in the exchange
        // Datahub.setAssetInfo(0, token, amount, false); // 0 -> totalSupply

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

    // This function is a copy of the deposit_token_process function except does not alter the exchange supply
    function lendingPoolWithdrawalProcess(
        address user,
        bytes32 token,
        uint256 amount
    ) public checkRoleAuthority returns (bool) {
        // put in "checkRoleAuthority" here, I DON'T KNOW IF THAT'S RIGHT!

        // Don't need this require if a user already has tokns in the lendingPool
        //require(
        //    Datahub.returnAssetLogs(token).initialized == true,
        //    "this asset is not available to be deposited or traded"
        // );
        // require(!circuitBreakerStatus, "circuit breaker active");
        // Datahub.setAssetInfo(0, token, amount, true); // 0 -> totalSupply

        // Already do this in the updateLendingPoolAssets function
        // interestContract.updateCIMandTBA(token);

        // We don't need to account for lending pool here anymore, we only do that via CLM now
        // uint256 rawLendingPoolAssets = Datahub
        //    .ReadUserData(user, token)
        //    .rawLendingPoolAssets;
        uint256 rawLiabilities = Datahub
            .ReadUserData(user, token)
            .rawLiabilities;

        // Need to incorporate new earning logic here
        // if (rawLendingPoolAssets > 0 && rawLiabilities == 0) {
        // uint256 earningRate = utility.returnEarningProfit(user, token);
        // Datahub.addAssets(user, token, earningRate);
        // Datahub.setAssetInfo(0, token, earningRate, true);
        // Datahub.alterUsersEarningRateIndex(user, token);
        // }

        // SHOULD PROBABLY MAKE A CASE FOR BOTH LENDINGPOOLAMOUNT > 0 && LIABILITIES > 0
        // Actually, maybe not as the simple rawLiabilities > 0 should work fine for this

        // checks to see if user is in the sytem and inits their struct if not
        if (rawLiabilities > 0) {
            // We don't need to do interestCharge anymore, that is done automatically via CIM
            // uint256 interestCharge = interestContract.returnInterestCharge(
            //    user,
            //    token
            // );

            uint256 actualCurrentLiabilities = interestContract
                .calculateActualCurrentLiabilities(user, token);
            if (amount <= actualCurrentLiabilities) {
                interestContract.updateLiabilities(user, token, amount, true); // does true increase or decrease liabilities???

                return true;
            } else {
                Datahub.addAssets(
                    user,
                    token,
                    amount - actualCurrentLiabilities
                ); // add to assets

                interestContract.updateLiabilities(
                    user,
                    token,
                    actualCurrentLiabilities,
                    true
                ); // remove all liabilities

                // NOTE: REMOVED BELOW BECAUSE WE DO THIS IN THE updateLiabilities FUNCTION
                // Datahub.setAssetInfo(1, token, liabilities, false); // 1 -> totalBorrowedAmount

                // Datahub.changeMarginStatus(user);

                // Datahub.alterUsersInterestRateIndex(user, token);
                return true; // NOTE: CAN SOMEBODY TELL ME WTF THIS DOES PLEASE??
            }
        } else {
            Datahub.addAssets(user, token, amount);

            // Datahub.alterUsersInterestRateIndex(user, token);

            return true;
        }
    }

    // // Code20: DONE - We either need to adapt this function to be almost exactly the same as the normal deposit function or comment this out entirely
    // // NOTE: LETS COPY WHAT I DID IN THE DEPOSIT TOKEN FUNCTION HERE!!! DO NOT MISS NOTES PLEASE
    // /* DEPOSIT FOR FUNCTION */
    // function deposit_token_for(
    //     address beneficiary,
    //     bytes32 token,
    //     uint256 amount
    // ) external returns (bool) {
    //     require(
    //         Datahub.returnAssetLogs(token).initialized == true,
    //         "this asset is not available to be deposited or traded"
    //     );

    //     // IERC20.IERC20 ERC20Token = IERC20.IERC20(token);
    //     // //chechking balance for contract before the token transfer
    //     // uint256 contractBalanceBefore = ERC20Token.balanceOf(address(this));
    //     // // transfering the tokens to contract
    //     // uint256 decimals = fetchDecimals(token);
    //     // amount = (amount * (10 ** decimals)) / (10 ** 18);
    //     // require(
    //     //     ERC20Token.transferFrom(msg.sender, address(this), amount),
    //     //     "Transfer failed"
    //     // );

    //     // //checking the balance for the contract after the token transfer
    //     // uint256 contractBalanceAfter = ERC20Token.balanceOf(address(this));
    //     // // exactAmountTransfered is the exact amount being transferred in contract
    //     // uint256 exactAmountTransfered = contractBalanceAfter -
    //     //     contractBalanceBefore;
    //     // exactAmountTransfered =
    //     //     (exactAmountTransfered * (10 ** 18)) /
    //     //     (10 ** decimals);

    //     Datahub.setAssetInfo(0, token, amount, true); // 0 -> totalAssetSupply

    //     interestContract.updateCIMandTBA(token);

    //     uint256 liabilities = Datahub
    //         .ReadUserData(beneficiary, token)
    //         .rawLiabilities;

    //     if (liabilities > 0) {
    //         uint256 interestCharge = interestContract.returnInterestCharge(
    //             beneficiary,
    //             token
    //         );

    //         // Datahub.addLiabilities(beneficiary, token, interestCharge);
    //         Executor.updateLiabilities(
    //             beneficiary,
    //             token,
    //             interestCharge,
    //             false
    //         );
    //         liabilities = liabilities + interestCharge;

    //         if (amount <= liabilities) {
    //             // modifyMMROnDeposit(beneficiary, token, amount);

    //             // modifyIMROnDeposit(beneficiary, token, amount);

    //             // Datahub.removeLiabilities(beneficiary, token, amount);
    //             Executor.updateLiabilities(beneficiary, token, amount, true);

    //             Datahub.setAssetInfo(1, token, amount, false); // 1 -> totalBorrowedexactAmountTransferedfalse); // 1 -> totalBorrowedAmount

    //             return true;
    //         } else {
    //             // modifyMMROnDeposit(beneficiary, token, liabilities);

    //             // modifyIMROnDeposit(beneficiary, token, liabilities);

    //             Datahub.addAssets(beneficiary, token, amount - liabilities); // add to assets

    //             // Datahub.removeLiabilities(beneficiary, token, liabilities); // remove all liabilities
    //             Executor.updateLiabilities(
    //                 beneficiary,
    //                 token,
    //                 liabilities,
    //                 true
    //             );

    //             Datahub.setAssetInfo(1, token, liabilities, false); // 1 -> totalBorrowedexactAmountTransfered

    //             Datahub.changeMarginStatus(beneficiary);
    //             return true;
    //         }
    //     } else {
    //         Datahub.addAssets(beneficiary, token, amount);

    //         return true;
    //     }
    // }

    function borrow(bytes32 token, uint256 amount) external {
        // IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        // updateLiabilities function already does this so we will likely be deleting it from here
        interestContract.updateCIMandTBA(token);
        uint256 pending = Datahub.ReadUserData(msg.sender, token).pending;
        require(
            pending == 0,
            "You must have a 0 pending trade balance to borrow, please wait for your trade to settle before attempting to borrow"
        );

        // Removed this because I added it directly to the updateLiabilities function
        // uint256 initalMarginFeeAmount = EVO_LIBRARY
        //    .calculateinitialMarginFeeAmount(assetLogs, amount);

        Datahub.addAssets(msg.sender, token, amount); // moved this up here so that the AIMR check in the update liabilities function can take into account the additional assets

        interestContract.updateLiabilities(msg.sender, token, amount, false); // Please confirm: does false increase or decrease liabilities??? Here we need to increasea liabilities since they are borrowing

        // This is only for the initialMarginFee not interest fees
        // Executor.divideFee(token, initalMarginFeeAmount);

        // uint256 usersAIMR = Datahub.calculateAIMRForUser(msg.sender);
        // uint256 usersTCV = Datahub.calculateCollateralValue(msg.sender);

        // REMOVED BECAUSE WE ALREADY DO THIS IN THE UPDATELIABILITIES FUNCTION
        // Datahub.changeMarginStatus(msg.sender);
        // console.log("users aimr", usersAIMR);
        // console.log("users tcv", usersTCV);

        // Removed because we already do this in updateLiabilities
        // require(
        //    usersAIMR <= usersTCV,
        //    "You do not have enough collateral for this borrow position"
        // );
    }

    function repayAllLiabilitiesForToken(bytes32 token) external {
        interestContract.updateCIMandTBA(token);

        uint256 amount = interestContract.calculateActualCurrentLiabilities(
            msg.sender,
            token
        );
        repay(token, amount);
    }

    function repay(bytes32 token, uint256 amount) public {
        // IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        // How would somebody be repaying a token that hasn't been initialized yet? PLEASE TELL ME IF IM WRONG ON THIS
        // require(assetLogs.initialized == true, "this asset is not available");

        interestContract.updateCIMandTBA(token);

        uint256 assets = Datahub.ReadUserData(msg.sender, token).assets;
        uint256 rawLiabilities = Datahub
            .ReadUserData(msg.sender, token)
            .rawLiabilities;

        require(rawLiabilities > 0, "Already repaid");

        uint256 actualCurrentLiabilities = interestContract
            .calculateActualCurrentLiabilities(msg.sender, token);

        // This checks to see if they're trying to repay more than their actual liabilities, if they are then it sets the amount to what it should be
        uint256 repay_amount = amount > actualCurrentLiabilities
            ? actualCurrentLiabilities
            : amount;

        require(repay_amount <= assets, "Insufficient funds in user");

        interestContract.updateLiabilities(msg.sender, token, repay_amount, true);
        Datahub.removeAssets(msg.sender, token, repay_amount);

        // This is done in updateLiabilities function now
        // Datahub.changeMarginStatus(msg.sender);
    }

    function withdrawETH(address payable owner) external onlyOwner {
        uint contractBalance = address(this).balance;
        // uint256 usersTCV = Datahub.calculateCollateralValue(msg.sender) -
        //     Datahub.calculatePendingCollateralValue(msg.sender);
        require(contractBalance > 0, "No balance to withdraw");
        payable(owner).transfer(contractBalance);
    }
    receive() external payable {}
}
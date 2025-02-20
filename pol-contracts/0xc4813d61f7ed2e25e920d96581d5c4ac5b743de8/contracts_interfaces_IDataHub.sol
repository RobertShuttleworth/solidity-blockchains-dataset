// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IDataHub {
    struct UserData {
        /// hash(chainId.tokenAddress)
        /// hash("137.0x3c499c542cef5e3811e1192ce70d8cc03d5c3359")      : POLYGON.USDC
        /// hash("137.0")                                               : POLYGON.MATIC  Native token
        /// hash("BTC.0")                                               : BIC.BTC        Native token
        /// hash("1.0x8a4b59b38c569d1cf09d6cc96cbe7a2fd8ee08e9")        : ETH.USDC
        /// hash("SOL.0")                                               : SOL.SOL        Native token
        /// hash("SOL.Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB")    : SOL.USDC
        mapping(bytes32 => uint256) asset_info; // user's asset amount
        mapping(bytes32 => uint256) rawLendingPoolAssets; // user's lending pool amount
        mapping(bytes32 => uint256) initialManipulatedLendingPoolAssets; // user's lending pool amount scaled down by CIM
        // mapping(bytes32 => uint256) liability_info; // user's liability amount --- NOTE PROBABLY WANT TO DELETE THIS BECAUSE WE NOW USE RAW AND MANIPULATED         mapping(bytes32 => uint256) liability_info; // user's liability amount
        mapping(bytes32 => uint256) maintenance_margin_requirement; // tracks the MMR per token the user has in liabilities
        mapping(bytes32 => uint256) initial_margin_requirement; // tracks the IMR per token the user has in liabilities
        mapping(bytes32 => uint256) pending_balances; // user's pending balance while trading
        mapping(bytes32 => uint256) pending_withdrawals; // user's pending balance while withdrawal
        // mapping(bytes32 => uint256) interestRateIndex; // interest rate index for charging
        mapping(bytes32 => uint256) rawLiabilities; // user's liability amount
        mapping(bytes32 => uint256) initialManipulatedLiabilities; // user's liability amount scaled down by CIM
        // mapping(bytes32 => uint256) earningRateIndex; // earning rate index for charging
        uint256 negative_value; // display negative value if totoalCollateral < totalBorrowedAmount
        bool margined; // if user has open margin positions this is true
        bytes32[] tokens_assets; // these are the tokens that comprise their portfolio ( assets )
        bytes32[] tokens_liabilities; // these are the tokens that comprise their portfolio ( rawLiabilites )
        bytes32[] tokens_lendingPoolAssets; // these are the tokens that comprise their portfolio ( lending Pool Assets )
        bytes32[] tokens_pending; // these are the tokens that comprise their portfolio ( pending )
        // How are we adding tokens to this array? Please confirm because I want to make sure we are taking into account everything
    }

    struct UserInfo {
        uint256 assets;
        // uint256 liabilities;
        uint256 pending;
        uint256 pendingWithdrawal;
        bool margined;
        uint256 rawLendingPoolAssets;
        uint256 initialManipulatedLendingPoolAssets;
        uint256 maintenanceMarginRequirement;
        uint256 initialMarginRequirement;
        // uint256 interestRateIndex;
        uint256 rawLiabilities;
        uint256 initialManipulatedLiabilities;
        // uint256 earningRateIndex;
        uint256 negativeValue;
    }

    struct AssetData {
        bool initialized; // flag if the token is initialized
        uint256[2] tradeFees; // first in the array is taker fee, next is maker fee
        uint256 collateralMultiplier; // collateral multiplier for check margin trading
        uint256 assetPrice; // token price
        uint256[5] assetInfo; // 0 -> totalAssetSupply, 1 -> rawTotalBorrowedAmount, 2 -> rawLendingPoolSupply, 3 -> manipulatedTotalBorrowedAmount, 4 -> initialManipulatedLendingPoolSupply
        uint256[2] feeInfo; // 0 -> initialMarginFee, 1 -> liquidationFee
        uint256[2] marginRequirement; // 0 -> initialMarginRequirement, 1 -> MaintenanceMarginRequirement
        uint256[2] borrowProportion; // 0 -> optimalBorrowProportion, 1 -> maximumBorrowProportion
        uint256 totalDepositors; // reserved
        string chainId;
        string assetAddress;
        uint256[] rateInfo; ///minimumInterestRate,  optimalInterestRate, maximumInterestRate
        uint256 compoundedInterestMultiplier;
        uint256 compoundedLendingMultiplier;
        uint256 lastUpdatedInterestTime;
        uint256 lastUpdatedLendingTime;
    }

    function addAssets(address user, bytes32 token, uint256 amount) external;

    //     function fetchTotalAssetSupply(
    //         bytes32 token
    //     ) external view returns (uint256);

    function tradeFee(
        bytes32 token,
        uint256 feeType
    ) external view returns (uint256);

    //     function InitTokenMarket(
    //         bytes32 token, // hash(chainId.tokenAddress)
    //         uint256 assetPrice,
    //         uint256 collateralMultiplier,
    //         uint256[2] memory tradeFees,
    //         uint256[2] memory _marginRequirement,
    //         uint256[2] memory _borrowProportion,
    //         uint256[2] memory _feeInfo,
    //         string memory chainId,
    //         string memory assetAddress,
    //         uint256[] memory rateInfo
    //     ) external;

    function selfInitTokenMarket(
        bytes32 token, // hash(chainId.tokenAddress)
        string memory chainId,
        string memory assetAddress
    ) external;

    // function calculateAIMRForUser(
    //     address user,
    //     address trade_token,
    //     uint256 trade_amount
    // ) external view returns (uint256);

    function removeAssets(address user, bytes32 token, uint256 amount) external;

    //     function alterUsersInterestRateIndex(address user, bytes32 token) external;

    //     function viewUsersEarningRateIndex(
    //         address user,
    //         bytes32 token
    //     ) external view returns (uint256);

    //     function getUsersEarningRateIndex(
    //         address user,
    //         bytes32 token
    //     ) external view returns (uint256);

    //     function alterUsersEarningRateIndex(address user, bytes32 token) external;

    //     function viewUsersInterestRateIndex(
    //         address user,
    //         bytes32 token
    //     ) external view returns (uint256);

    //     function getUsersInterestRateIndex(
    //         address user,
    //         bytes32 token
    //     ) external view returns (uint256);

    function getInitialManipulatedLiabilities(
        address user,
        bytes32 token
    ) external view returns (uint256);

    function getRawLiabilities(
        address user,
        bytes32 token
    ) external view returns (uint256);

    //     // function alterLiabilities(
    //     //     address user,
    //     //     bytes32 token,
    //     //     uint256 amount
    //     // ) external;

    function alterRawLiabilities(
        address user,
        bytes32 token,
        uint256 amount
    ) external;

    function alterInitialManipulatedLiabilities(
        address user,
        bytes32 token,
        uint256 amount
    ) external;

    //     // function addLiabilities(
    //     //     address user,
    //     //     bytes32 token,
    //     //     uint256 amount
    //     // ) external;

    //     // function removeLiabilities(
    //     //     address user,
    //     //     bytes32 token,
    //     //     uint256 amount
    //     // ) external;

    //     function divideFee(bytes32 token, uint256 amount) external;

    function addPendingBalances(
        address user,
        bytes32 token,
        uint256 amount,
        bool isTrade
    ) external;

    function removePendingBalances(
        address user,
        bytes32 token,
        uint256 amount,
        bool isTrade
    ) external;

    //     function alterUserNegativeValue(address user) external;

    function SetMarginStatus(address user, bool onOrOff) external;

    function calculateAIMRForUser(address user) external view returns (uint256);

    //     // function checkIfAssetIsPresent(
    //     //     address[] memory users,
    //     //     bytes32 token
    //     // ) external returns (bool);

    function ReadUserData(
        address user,
        bytes32 token
    ) external view returns (UserInfo memory);

    //     // function removeAssetToken(address user, bytes32 token) external;

    function setAssetInfo(
        uint8 id,
        bytes32 token,
        uint256 amount,
        bool pos_neg
    ) external;

    //     function updateInterestIndex(bytes32 token, uint256 value) external;

    function returnAssetLogs(
        bytes32 token
    ) external view returns (AssetData memory);

    //     function FetchAssetInitilizationStatus(
    //         bytes32 token
    //     ) external view returns (bool);

    function toggleAssetPrice(bytes32 token, uint256 value) external;

    //     function checkMarginStatus(
    //         address user,
    //         bytes32 token,
    //         uint256 BalanceToLeave
    //     ) external;

    function calculateAMMRForUser(address user) external view returns (uint256);

    //     function calculateTotalPortfolioValue(
    //         address user
    //     ) external view returns (uint256);

    function changeMarginStatus(address user) external returns (bool);

    //     function returnUsersAssetTokens(
    //         address user
    //     ) external view returns (bytes32[] memory);

    function returnUsersLiabilitiesTokens(
        address user
    ) external view returns (bytes32[] memory);

    function calculateCollateralValue(
        address user
    ) external view returns (uint256);

    function calculatePendingCollateralValue(
        address user
    ) external view returns (uint256);

    //     function setTokenTransferFee(bytes32 token, uint256 value) external;

    //     function tokenTransferFees(bytes32 token) external returns (uint256);

    //     function changeTotalBorrowedAmountOfAsset(
    //         bytes32 token,
    //         uint256 _updated_value
    //     ) external;

    function alterTokenInterestInfo(
        bytes32 _token,
        uint256 _compoundedInterestMultiplier,
        uint256 _lastUpdatedInterestTime
    ) external;

    function getExchangeInterestSpread() external view returns (uint256);

    function alterRawTotalBorrowedAmount(
        bytes32 token,
        uint256 amount
    ) external;

    function alterManipulatedTotalBorrowedAmount(
        bytes32 token,
        uint256 amount
    ) external;

    function getInitialManipulatedLendingPoolAssets(
        address user,
        bytes32 token
    ) external view returns (uint256);

    function alterTokenLendingInfo(
        bytes32 _token,
        uint256 _compoundedLendingMultiplier,
        uint256 _lastUpdatedLendingTime
    ) external;

    function getRawLendingPoolAssets(
        address user,
        bytes32 token
    ) external view returns (uint256);

    function alterRawLendingPoolSupply(bytes32 token, uint256 amount) external;

    function alterRawLendingPoolAssets(
        address user,
        bytes32 token,
        uint256 amount
    ) external;

    function alterInitialManipulatedLendingPoolAssets(
        address user,
        bytes32 token,
        uint256 amount
    ) external;

    function alterInitialManipulatedLendingPoolSupply(
        bytes32 token,
        uint256 amount
    ) external;

    //     // function updateUserAssetsTokens(address user, bytes32 token) external;

    function updateUserLiabilitiesTokens(address user, bytes32 token) external;

    //     // function updateUserLendingPoolTokens(address user, bytes32 token) external;

    //    // function updateUserLendingPoolTokens(address user, bytes32 token) external;
    function getUserWallet(
        address user,
        bytes32 chainID
    ) external view returns (string memory);
}
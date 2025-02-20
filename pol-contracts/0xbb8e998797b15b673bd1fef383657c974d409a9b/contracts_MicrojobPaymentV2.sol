// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import OpenZeppelin ERC721 and Ownable contracts
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721Enumerable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";
import "./contracts_IDao.sol";
import "./contracts_IBEP20.sol";
import "./contracts_RevenueCalculator.sol";

contract MicroJobPaymentV2 is Ownable, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TRANSACTION_IMPLEMENTOR_ROLE =
        keccak256("TRANSACTION_IMPLEMENTOR_ROLE");
    // uint256 public log = 0;
    using SafeERC20 for IERC20;
    IDao public xdaoAddress;
    uint256 public paymentPerSession;
    // address public KATAddress;
    // address public USDTAddress;
    address[] public currencyAddresses;
    uint256[] private balances;
    uint256[] private rateOfCurrencyOnUSDTTWei;
    mapping(uint256 => bool) public transactionDone;
    mapping(uint256 => uint256) public purchaseTimestamps;
    RevenueCalculator public revenueCalculator;

    // Define the struct at the contract level
    struct Balances {
        uint256 katBalanceOnUSDTWei;
        uint256 usdtWeiBalance;
    }

    uint256[] public Rate;

    struct LpHolder {
        address wallet;
        uint256 balance;
    }
    struct Claimer {
        address wallet;
        uint totalWithdrawableInCurrencies;
    }
    struct PaymentCalculation {
        Claimer[] claimers;
        uint256 timestamp;
    }
    LpHolder[] public lastLpHolderList;
    PaymentCalculation[] private paymentCalculationList;
    struct ClaimTransaction {
        address claimer;
        address currencyAddress;
        uint256 claimedAmountInCurrencies;
        uint256 timestamp;
    }

    // Mảng để lưu trữ các giao dịch claim
    ClaimTransaction[] private claimTransactions;
    address[] private claimerAddresses;
    mapping(address => mapping(address => Claimer)) public claimerList;

    // Mapping mới để theo dõi việc chia sẻ doanh thu

    constructor(
        address _xdaoAddress,
        address[] memory _currencyAddresses,
        address _revenueCalculatorAddress
    ) {
        xdaoAddress = IDao(_xdaoAddress);
        currencyAddresses = _currencyAddresses;
        _grantRole(TRANSACTION_IMPLEMENTOR_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(TRANSACTION_IMPLEMENTOR_ROLE, ADMIN_ROLE);
        revenueCalculator = RevenueCalculator(_revenueCalculatorAddress);
    }

    function grantRole(
        bytes32 role,
        address account
    ) public virtual override onlyRole(ADMIN_ROLE) {
        require(
            (role == ADMIN_ROLE) || (role == TRANSACTION_IMPLEMENTOR_ROLE),
            "Role is not predefined"
        );
        _grantRole(role, account);
    }

    function revokeRole(
        bytes32 role,
        address account
    ) public virtual override onlyRole(ADMIN_ROLE) {
        require(
            (role == ADMIN_ROLE) || (role == TRANSACTION_IMPLEMENTOR_ROLE),
            "Role is not predefined"
        );
        _revokeRole(role, account);
    }

    function setPaymentPerSession(
        uint256 _paymentPerSession
    ) public onlyRole(TRANSACTION_IMPLEMENTOR_ROLE) {
        paymentPerSession = _paymentPerSession;
    }

    // function calculateTotalBalanceOnUSDTWei() private view returns (uint256) {
    //     uint256 totalBalanceOnUSDTWei = 0;
    //     for (uint256 i = 0; i < currencyAddresses.length; i++) {
    //         uint256 currencyBalanceOnUSDTWei = (IBEP20(currencyAddresses[i])
    //             .balanceOf(address(xdaoAddress)) *
    //             rateOfCurrencyOnUSDTTWei[0]) / rateOfCurrencyOnUSDTTWei[i];
    //         totalBalanceOnUSDTWei += currencyBalanceOnUSDTWei;
    //     }
    //     return totalBalanceOnUSDTWei;
    // }

    function addCurrency(
        address currencyAddress
    ) public onlyRole(TRANSACTION_IMPLEMENTOR_ROLE) {
        require(
            !_isCurrencyAddressExists(currencyAddress),
            "Currency address already exists"
        );
        currencyAddresses.push(currencyAddress);
    }

    function _isCurrencyAddressExists(
        address currencyAddress
    ) internal view returns (bool) {
        for (uint256 i = 0; i < currencyAddresses.length; i++) {
            if (currencyAddresses[i] == currencyAddress) {
                return true;
            }
        }
        return false;
    }
    function submitCalculationData(
        address[] memory wallets,
        uint256[] memory numbersOfCompletedSession,
        uint256[] memory currencyAmountsForRate
    ) public onlyRole(TRANSACTION_IMPLEMENTOR_ROLE) {
        require(
            wallets.length == numbersOfCompletedSession.length,
            "Mismatched arrays"
        );
        PaymentCalculation storage newCalculation = paymentCalculationList
            .push();
        newCalculation.timestamp = block.timestamp;
        // Update the exchange rate
        rateOfCurrencyOnUSDTTWei = revenueCalculator
            .calculateRateOnWeiBasedOn1stTokenWei(
                currencyAddresses,
                currencyAmountsForRate
            );
        // balances = revenueCalculator.calculateBalances(currencyAmountsForRate);
        balances = revenueCalculator.calculateBalances(
            currencyAmountsForRate,
            currencyAddresses,
            address(xdaoAddress)
        );

        uint256 totalBalanceOnUSDTWei = 0;
        for (uint256 i = 0; i < currencyAddresses.length; i++) {
            totalBalanceOnUSDTWei += balances[i];
        }
        require(
            totalBalanceOnUSDTWei != 0,
            "DAO donesn't have balance on any currencies"
        );
        // Update the USDT amount for each wallet
        for (uint256 i = 0; i < wallets.length; i++) {
            uint256[] memory totalWithdrawableInCurrencies = revenueCalculator
                .calculateWidrawableOnTokens(
                    address(xdaoAddress),
                    numbersOfCompletedSession[i] * paymentPerSession,
                    currencyAddresses,
                    rateOfCurrencyOnUSDTTWei
                );

            for (uint256 j = 0; j < currencyAddresses.length; j++) {
                Claimer memory claimer;
                claimer.wallet = wallets[i];

                claimer
                    .totalWithdrawableInCurrencies = totalWithdrawableInCurrencies[
                    j
                ];

                if (
                    claimerList[wallets[i]][currencyAddresses[j]].wallet ==
                    address(0)
                ) {
                    claimerList[wallets[i]][currencyAddresses[j]] = claimer;
                    claimerAddresses.push(claimer.wallet);
                } else {
                    claimerList[wallets[i]][currencyAddresses[j]]
                        .totalWithdrawableInCurrencies += claimer
                        .totalWithdrawableInCurrencies;
                }

                newCalculation.claimers.push(claimer);
            }
        }
    }
    function claim() external {
        uint256 totalWithdrawableInCurrencies = 0;
        for (uint256 i = 0; i < currencyAddresses.length; i++) {
            totalWithdrawableInCurrencies += claimerList[msg.sender][
                currencyAddresses[i]
            ].totalWithdrawableInCurrencies;
        }
        require(totalWithdrawableInCurrencies > 0, "You have nothing to claim");

        //Send currencies to the claimer
        for (uint256 i = 0; i < currencyAddresses.length; i++) {
            if (
                claimerList[msg.sender][currencyAddresses[i]]
                    .totalWithdrawableInCurrencies > 0
            ) {
                if (currencyAddresses[i] == address(0)) {
                    xdaoAddress.executePermitted(
                        msg.sender,
                        "",
                        claimerList[msg.sender][currencyAddresses[i]]
                            .totalWithdrawableInCurrencies
                    );
                } else {
                    xdaoAddress.executePermitted(
                        currencyAddresses[i],
                        abi.encodeWithSignature(
                            "transfer(address,uint256)",
                            msg.sender,
                            claimerList[msg.sender][currencyAddresses[i]]
                                .totalWithdrawableInCurrencies
                        ),
                        0
                    );
                }
                claimerList[msg.sender][currencyAddresses[i]]
                    .totalWithdrawableInCurrencies = 0;
                ClaimTransaction memory newClaimTransaction = ClaimTransaction(
                    msg.sender,
                    currencyAddresses[i],
                    claimerList[msg.sender][currencyAddresses[i]]
                        .totalWithdrawableInCurrencies,
                    block.timestamp
                );
                claimTransactions.push(newClaimTransaction);
            }
        }
    }

    // Hàm xem tất cả ClaimTransactions
    function viewAllClaimTransactions()
        external
        view
        onlyRole(TRANSACTION_IMPLEMENTOR_ROLE)
        returns (ClaimTransaction[] memory)
    {
        return claimTransactions;
    }

    function viewAllCalculations()
        external
        view
        // Not yet done
        onlyRole(TRANSACTION_IMPLEMENTOR_ROLE)
        returns (PaymentCalculation[] memory)
    {
        return paymentCalculationList;
    }
}
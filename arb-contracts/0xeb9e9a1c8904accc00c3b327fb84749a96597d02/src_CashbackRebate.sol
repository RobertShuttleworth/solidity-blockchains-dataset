// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import {IFiat24Account} from "./src_interfaces_IFiat24Account.sol";
import {IReferralStorage} from "./src_interfaces_IReferralStorage.sol";
import {IFiat24Token} from "./src_interfaces_IFiat24Token.sol";
import {ICardLevel} from "./src_interfaces_ICardLevel.sol";
import {ISavePayEx} from "./src_interfaces_ISavePayEx.sol";

/** 
 * @notice 1. grant savePayEx's TOKEN_TRANSFER_ROLE to this contract
 * @notice 2. distributor should approve his USDC to Fiat24CryptoDeposit
 * @notice 3. distributor should approve this USD24 to this contract
 */
contract CashbackRebate is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    ISavePayEx public savePayEx;
    ICardLevel public cardLevel;
    IReferralStorage public referralStorage;
    address payable public distributor;
    mapping (uint256 => uint256) public mintFeeClaimed;
    uint256 public mintFeeRefundStart;
    uint256 public mintFeeRefundEnd;
    mapping (uint256 => address) public whitelistRebate;

    IFiat24Account public constant FIAT24ACCOUNT = IFiat24Account(0x133CAEecA096cA54889db71956c7f75862Ead7A0);
    IERC20 public constant USDC = IERC20(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
    address public constant USD24 = 0xbE00f3db78688d9704BCb4e0a827aea3a9Cc0D62;
    uint256 public constant BASIS_POINTS_PRECISION = 1e4;
    uint256 public constant USDC_DIVISOR = 1e4;

    event CashbackPaid(
        uint256 indexed userTokenID, 
        uint256 amount, 
        uint256 cashbackAmount
    );
    
    event RebatePaid(
        uint256 indexed referrerTokenID, 
        uint256 indexed userTokenID,
        uint256 amount, 
        uint256 rebateAmount, 
        address token
    );

    event MintFeeRefunded(uint256 indexed userTokenID, uint256 amount);

    event DistributorSet(address indexed distributor);

    event WhitelistRebateSet(uint256 indexed userTokenID, address indexed rebateToken);

    event CashbackPaidFailed(uint256 indexed userTokenID, uint256 amount, uint256 cashbackAmount);
    event RebatePaidFailed(uint256 indexed referrerTokenID, uint256 indexed userTokenID, uint256 amount, uint256 rebateAmount, address token);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _savePayEx,
        address _cardLevel,
        address _referralStorage,
        address payable _distributor
    ) public initializer {
        require(_savePayEx != address(0), "Invalid SavePayEx address");
        require(_cardLevel != address(0), "Invalid CardLevel address");
        require(_referralStorage != address(0), "Invalid ReferralStorage address");
        
        __AccessControl_init();
        __UUPSUpgradeable_init();  // Add this line
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        savePayEx = ISavePayEx(_savePayEx);
        cardLevel = ICardLevel(_cardLevel);
        referralStorage = IReferralStorage(_referralStorage);
        setDistributor(_distributor);
    }

    function claimMintFee() external{
        uint256 userTokenID = FIAT24ACCOUNT.tokenOfOwnerByIndex(msg.sender, 0);
        require(FIAT24ACCOUNT.status(userTokenID) == IFiat24Account.Status.Live, "NFT not live");

        IReferralStorage.ReferralInfo memory referralInfo = referralStorage.referrals(userTokenID);
        require(referralInfo.referrerTokenId != 0, "No referrer");
        require(referralInfo.paymentAmount > 0, "No payment amount");
        require(FIAT24ACCOUNT.status(referralInfo.referrerTokenId) == IFiat24Account.Status.Live, "Referrer not live");
        require(referralInfo.timestamp >= mintFeeRefundStart && referralInfo.timestamp <= mintFeeRefundEnd, "Not in refund period");

        require(mintFeeClaimed[userTokenID] == 0, "Already claimed");
        mintFeeClaimed[userTokenID] = referralInfo.paymentAmount;
        savePayEx.withdraw(address(0), payable(msg.sender), referralInfo.paymentAmount);

        emit MintFeeRefunded(userTokenID, referralInfo.paymentAmount);
    }

    function processCashbackAndRebate(
        uint256 userTokenID, 
        uint256 amount
    ) public onlyRole(OPERATOR_ROLE) {
        require(userTokenID != 0, "Invalid user address");
        require(amount > 0, "Amount must be greater than 0");

        //1. Get user's card level and level details
        uint256 userLevel = cardLevel.userLevels(userTokenID);
        ICardLevel.Level memory levelDetails = cardLevel.levels(userLevel);

        //2. Get user referral info
        IReferralStorage.ReferralInfo memory referralInfo = referralStorage.referrals(userTokenID);

        //3.1 calculate cashback
        uint256 cashbackAmount = 0;
        if(levelDetails.cashbackRate > 0){
            cashbackAmount = (amount * levelDetails.cashbackRate) / BASIS_POINTS_PRECISION;
        }

        //3.2 calculate commission
        uint256 rebateAmount = 0;
        uint256 referrerLevel = cardLevel.userLevels(referralInfo.referrerTokenId);
        ICardLevel.Level memory referrerLevelDetails = cardLevel.levels(referrerLevel);
        if(referrerLevelDetails.rebateRate > 0){
            rebateAmount = (amount * (BASIS_POINTS_PRECISION - levelDetails.cashbackRate) * referrerLevelDetails.rebateRate) / BASIS_POINTS_PRECISION / BASIS_POINTS_PRECISION;
        }

        if(whitelistRebate[referralInfo.referrerTokenId] != address(0)){
            // Call the new internal function for USDC rebate
            processUSDCRebate(userTokenID, amount, cashbackAmount, rebateAmount, referralInfo.referrerTokenId);
        } else {
            // Call the new internal function for USD24 rebate
            processUSD24Rebate(userTokenID, amount, cashbackAmount, rebateAmount, referralInfo.referrerTokenId);
        }
    }

    // New internal function to handle USDC rebate
    function processUSDCRebate(
        uint256 userTokenID,
        uint256 amount,
        uint256 cashbackAmount,
        uint256 rebateAmount,
        uint256 referrerTokenId
    ) internal {
        //rebate in USDC
        if(cashbackAmount / USDC_DIVISOR > 0){
            //4.1 Withdraw USDC from SavePayEx to the distributor NFT owner
            savePayEx.withdraw(address(USDC), distributor, cashbackAmount);

            //4.2 call depositByWallet to convert USDC to USD24
            uint256 outputAmount = savePayEx.depositFiat24Crypto(distributor, USD24, cashbackAmount);

            (bool success, bytes memory data) = USD24.call(abi.encodeWithSelector(IERC20.transferFrom.selector, distributor, FIAT24ACCOUNT.ownerOf(userTokenID), outputAmount));
            if(success && abi.decode(data, (bool))){
                emit CashbackPaid(userTokenID, amount, outputAmount);
            } else {
                emit CashbackPaidFailed(userTokenID, amount, outputAmount);
            }
        }

        if(rebateAmount > 0 && referrerTokenId > 0){
            savePayEx.withdraw(address(USDC), payable(FIAT24ACCOUNT.ownerOf(referrerTokenId)), rebateAmount);
            emit RebatePaid(referrerTokenId, userTokenID, amount, rebateAmount, address(USDC));
        }
    }

    // New internal function to handle USD24 rebate
    function processUSD24Rebate(
        uint256 userTokenID,
        uint256 amount,
        uint256 cashbackAmount,
        uint256 rebateAmount,
        uint256 referrerTokenId
    ) internal {
        //rebate in USD24
        uint256 _rebateAmount = 0;
        if(referrerTokenId != 0 && FIAT24ACCOUNT.status(referrerTokenId) == IFiat24Account.Status.Live){
            _rebateAmount = rebateAmount;
        }

        if(cashbackAmount + _rebateAmount == 0){
            return;
        }

        //5.1 Withdraw USDC from SavePayEx to the distributor NFT owner
        savePayEx.withdraw(address(USDC), distributor, cashbackAmount + _rebateAmount);

        //5.2 call depositByWallet to convert USDC to USD24
        uint256 outputAmount = savePayEx.depositFiat24Crypto(distributor, USD24, cashbackAmount + _rebateAmount);

        uint256 cashbackInUSD24 = cashbackAmount / USDC_DIVISOR;
        if(cashbackInUSD24 > 0){
            (bool success, bytes memory data) = USD24.call(abi.encodeWithSelector(IERC20.transferFrom.selector, distributor, FIAT24ACCOUNT.ownerOf(userTokenID), cashbackInUSD24));
            if(success && abi.decode(data, (bool))){
                emit CashbackPaid(userTokenID, amount, cashbackInUSD24);
            } else {
                emit CashbackPaidFailed(userTokenID, amount, cashbackInUSD24);
            }
        }
        
        uint256 commissionInUSD24 = outputAmount - cashbackInUSD24;
        if(commissionInUSD24 > 0){
            (bool successR, bytes memory dataR) = USD24.call(abi.encodeWithSelector(IERC20.transferFrom.selector, distributor, FIAT24ACCOUNT.ownerOf(referrerTokenId), commissionInUSD24));
            if(successR && abi.decode(dataR, (bool))){
                emit RebatePaid(referrerTokenId, userTokenID, amount, commissionInUSD24, USD24);
            } else {
                emit RebatePaidFailed(referrerTokenId, userTokenID, amount, commissionInUSD24, USD24);
            }
        }
    }

    // Process rewards for multiple users in a single transaction
    function batchProcessRewards(
        uint256[] calldata userTokenIDs,
        uint256[] calldata amounts
    ) external onlyRole(OPERATOR_ROLE) {
        require(userTokenIDs.length == amounts.length, "Arrays length mismatch");
        require(userTokenIDs.length > 0, "Empty arrays");
        
        for (uint256 i = 0; i < userTokenIDs.length; i++) {
            processCashbackAndRebate(userTokenIDs[i], amounts[i]);
        }
    }

    function setMintFeeRefundPeriod(uint256 _mintFeeRefundStart, uint256 _mintFeeRefundEnd) external onlyRole(OPERATOR_ROLE){
        require(_mintFeeRefundStart < _mintFeeRefundEnd, "Invalid period");
        mintFeeRefundStart = _mintFeeRefundStart;
        mintFeeRefundEnd = _mintFeeRefundEnd;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}

    function setDistributor(address payable _distributor) public onlyRole(ADMIN_ROLE){
        require(_distributor != address(0), "Invalid distributor");
        distributor = _distributor;
        emit DistributorSet(_distributor);
    }

    function setWhitelistRebate(uint256 userTokenIDs, address rebateToken) external onlyRole(OPERATOR_ROLE){
        whitelistRebate[userTokenIDs] = rebateToken;
        emit WhitelistRebateSet(userTokenIDs, rebateToken);
    }
}
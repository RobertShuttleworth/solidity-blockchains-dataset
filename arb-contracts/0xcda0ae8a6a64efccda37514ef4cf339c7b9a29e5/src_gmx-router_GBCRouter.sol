// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {UUPSUpgradeable} from "./node_modules_openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "./node_modules_openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import {SafeERC20} from "./node_modules_openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {Address} from "./node_modules_openzeppelin_contracts_utils_Address.sol";
import {IERC20} from "./node_modules_openzeppelin_contracts_token_ERC20_IERC20.sol";

import {GBCWalletProxy} from "./src_gmx-router_GBCWalletProxy.sol";
import {GBCWallet} from "./src_gmx-router_GBCWallet.sol";

/**
 * @title GBCRouter
 * @dev This contract manages user wallets, handles deposits with a fee, and allows the owner to update fees and collect them.
 * The contract creates individual wallets for each user upon deposit, subtracts a fee, and allows withdrawals.
 */
contract GBCRouter is UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice The denominator for calculating the fee (e.g., 10000 for basis points).
    uint256 public constant FEE_DENOMINATOR = 10000;

    /// @notice Address of the glvRouter.
    address public glvRouter;

    /// @notice Address of the exchangeRouter.
    address public exchangeRouter;

    /// @notice Address of the GBCWallet beacon.
    address public gbcWalletBeacon;

    /// @notice Mapping of user addresses to their respective wallet contracts.
    mapping(address => address) public wallets;

    /// @notice The percentage fee taken from each deposit and withdrawal, scaled by FEE_DENOMINATOR.
    uint256 public feePercentage;

    /// @notice Address of the transfer router.
    address public transferRouter;

    /// @notice Address which will receive all fees for a deposit.
    address public feeReceiver;

    /// @dev Event emitted when a wallet is created for a user.
    /// @param user The address of the user who owns the wallet.
    /// @param walletAddress The address of the created wallet contract.
    event WalletCreated(address indexed user, address walletAddress);

    /// @dev Event emitted when a deposit is made.
    /// @param user The address of the user making the deposit.
    /// @param market The address of the market where the deposit is made.
    /// @param amountLP The amount of LP tokens deposited by the user.
    event Deposited(address indexed user, address market, uint256 amountLP);

    /// @dev Event emitted when a deposit is made in GLV pool.
    /// @param user The address of the user making the deposit.
    /// @param glv The address of the glv token.
    /// @param market The address of the market where the deposit is made.
    /// @param amountLP The amount of LP tokens deposited by the user. In this case it is glv amount.
    event DepositedGlv(
        address indexed user,
        address glv,
        address market,
        uint256 amountLP
    );

    /// @dev Event emitted when a withdrawal is made.
    /// @param user The address of the user making the withdrawal.
    /// @param market The address of the market where the withdrawal is made.
    /// @param amountLP The amount of LP tokens withdrawn by the user.
    event Withdrawn(address indexed user, address market, uint256 amountLP);

    /// @dev Event emitted when a withdrawal is made.
    /// @param user The address of the user making the withdrawal.
    /// @param glv The address of the glv token.
    /// @param market The address of the market where the withdrawal is made.
    /// @param amountLP The amount of LP tokens withdrawn by the user. In this case it is glv amount.
    event WithdrawnGlv(
        address indexed user,
        address glv,
        address market,
        uint256 amountLP
    );

    /// @dev Event emitted when a user approves a spender to spend a certain amount of tokens.
    /// @param token The address of the token being approved.
    /// @param spender The address of the spender being approved.
    /// @param amount The amount of tokens approved to be spent.
    event Approved(address token, address spender, uint256 amount);

    /// @dev Event emitted when the fee percentage is updated.
    /// @param newFee The new fee percentage.
    event FeeUpdated(uint256 newFee);

    /// @dev Event emitted when the collected fees are withdrawn by the contract owner.
    /// @param amount The total amount of fees collected.
    event FeesCollected(uint256 amount);

    /// @dev Event emitted when the glvRouter address is updated.
    /// @param newGlvRouter The new address of the glvRouter.
    event GlvRouterUpdated(address newGlvRouter);

    /// @dev Event emitted when the exchangeRouter address is updated.
    /// @param newExchangeRouter The new address of the exchangeRouter.
    event ExchangeRouterUpdated(address newExchangeRouter);

    /// @dev Event emitted when the transferRouter address is updated.
    /// @param newTransferRouter The new address of the transferRouter.
    event TransferRouterUpdated(address newTransferRouter);

    /// @dev Event emitted when the withdrawal fee is collected.
    /// @param amount The amount of the fee collected.
    event WithdrawalFeeCollected(uint256 amount);

    /// @dev Error emitted when a user tries to deposit a zero or negative amount.
    /// @param amount The invalid deposit amount.
    error InvalidDepositAmount(uint256 amount);

    /// @dev Error emitted when a wallet is not found for the user.
    error WalletNotCreated();

    /// @dev Error emitted when the fee value set by the owner is invalid.
    error InvalidFeeValue();

    /// @dev Error emitted when the address is invalid.
    error InvalidAddress();

    /// @dev Error emitted when during deposit the lp token receiver address is not the GBC wallet.
    error ReceiverAddressIsNotGBCWallet();

    /**
     * @dev Initializes the contract by setting the initial owner and fee percentage.
     * @param _owner The address of the contract owner.
     */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        uint256 _feePercentage,
        address _gbcWalletBeacon,
        address _feeReceiver,
        address _exchangeRouter,
        address _glvRouter,
        address _transferRouter
    ) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(_owner);

        if (_feePercentage >= FEE_DENOMINATOR) {
            revert InvalidFeeValue();
        }
        feePercentage = _feePercentage;

        if (_gbcWalletBeacon == address(0) || _feeReceiver == address(0)) {
            revert InvalidAddress();
        }

        if(_exchangeRouter == address(0) || _glvRouter == address(0) || _transferRouter == address(0)) {
            revert InvalidAddress();
        }

        gbcWalletBeacon = _gbcWalletBeacon;
        feeReceiver = _feeReceiver;

        exchangeRouter = _exchangeRouter;
        glvRouter = _glvRouter;
        transferRouter = _transferRouter;

        emit GlvRouterUpdated(_glvRouter);
        emit ExchangeRouterUpdated(_exchangeRouter);
        emit TransferRouterUpdated(_transferRouter);
    }

    /**
     * @notice Allows a user to deposit Ether into their wallet. A fee is deducted from the deposit.
     * @dev If no wallet exists for the user, it creates one. The remaining amount after fee is deposited.
     * @custom:error InvalidDepositAmount Reverts if the deposit amount is zero or negative.
     * @param data The data to be passed to the wallet contract.
     * @param isGlv A boolean to check if the deposit is for glv or not.
     */
    function deposit(
        bytes[] calldata data,
        bool isGlv
    ) public payable {
        address market;
        address glv;
        uint256 amountLP;
        uint256 executionFee;
        uint256 totalAmountSentToVault;
        address receiver;

        if (!isGlv) {
            uint256 length = data.length - 1;
            bytes memory params = data[length][4:];

            (, receiver, , , market, , , , , amountLP, , , ) = abi.decode(
                params,
                (
                    address,
                    address,
                    address,
                    address,
                    address,
                    address,
                    address,
                    address[],
                    address[],
                    uint256,
                    bool,
                    uint256,
                    uint256
                )
            );
            emit Deposited(msg.sender, market, amountLP);
        } else {
            uint256 length = data.length - 1;
            bytes memory params = data[length][4:];

            (, glv, market, receiver, , , , , , , amountLP, executionFee, , , ) = abi.decode(
                params,
                (
                    address,
                    address,
                    address,
                    address,
                    address,
                    address,
                    address,
                    address,
                    address[],
                    address[],
                    uint256,
                    uint256,
                    uint256,
                    bool,
                    bool
                )
            );

            uint256 length1 = data.length - 2;
            bytes memory params1 = data[length1][4:];
            (, totalAmountSentToVault) = abi.decode(
                params1,
                (address, uint256)
            );

            emit DepositedGlv(msg.sender, glv, market, amountLP);
        }

        address wallet = getOrCreateWallet();

        uint256 depositedAmount = totalAmountSentToVault - executionFee;

        uint256 fee = (depositedAmount * feePercentage) / FEE_DENOMINATOR;

        if(totalAmountSentToVault + fee > msg.value) {
            revert InvalidDepositAmount(msg.value);
        }

        if(fee > 0 || feeReceiver != address(0)) {
            Address.sendValue(payable(feeReceiver), fee);
        }

        if(wallet != receiver) revert ReceiverAddressIsNotGBCWallet();

        GBCWallet(payable(wallet)).deposit{value: msg.value - fee}(data, isGlv);
    }

    /**
     * @notice Allows a user to withdraw Ether from their wallet.
     * @dev Reverts if the wallet has not been created yet.
     * @custom:error WalletNotCreated Reverts if the user has no wallet.
     * @param data The data to be passed to the wallet contract.
     * @param isGlv A boolean to check if the withdrawal is for glv or not.
     */
    function withdraw(bytes[] calldata data, bool isGlv) public payable {
        address wallet = wallets[msg.sender];
        if (wallet == address(0)) {
            revert WalletNotCreated();
        }

        address market;
        address glv;

        if (!isGlv) {
            uint256 length = data.length - 1;
            bytes memory params = data[length][4:];

            (, , , , market, , , , , , , ) = abi.decode(
                params,
                (
                    address,
                    address,
                    address,
                    address,
                    address,
                    address[],
                    address[],
                    uint256,
                    uint256,
                    bool,
                    uint256,
                    uint256
                )
            );
        } else {
            uint256 length = data.length - 1;
            bytes memory params = data[length][4:];

            (, , , , market, glv, , , , , , , ) = abi.decode(
                params,
                (
                    address,
                    address,
                    address,
                    address,
                    address,
                    address,
                    address[],
                    address[],
                    uint256,
                    uint256,
                    bool,
                    uint256,
                    uint256
                )
            );
        }

        if (!isGlv) {
            (uint256 lpAmount, uint256 fees) = GBCWallet(payable(wallet)).withdraw{value: msg.value}(
                data,
                isGlv,
                market
            );

            if(fees > 0) {
                emit WithdrawalFeeCollected(fees);
            }

            emit Withdrawn(msg.sender, market, lpAmount);
        } else {
            (uint256 lpAmount, uint256 fees) = GBCWallet(payable(wallet)).withdraw{value: msg.value}(
                data,
                isGlv,
                glv
            );

            if(fees > 0) {
                emit WithdrawalFeeCollected(fees);
            }

            emit WithdrawnGlv(msg.sender, glv, market, lpAmount);
        }
    }

    function approve(address token, address spender, uint256 amount) public {
        address wallet = wallets[msg.sender];
        if (wallet == address(0)) {
            revert WalletNotCreated();
        }

        GBCWallet(payable(wallet)).approve(token, spender, amount);

        emit Approved(token, spender, amount);
    }

    /**
     * @notice Allows the contract owner to update the fee percentage for deposits.
     * @dev Fee percentage must be less than 10% (i.e., less than 1000 basis points).
     * @param _newFee The new fee percentage (scaled by FEE_DENOMINATOR).
     * @custom:error InvalidFeeValue Reverts if the new fee exceeds the limit.
     */
    function setFeePercentage(uint256 _newFee) external onlyOwner {
        if (_newFee >= 1000) {
            // Limit to 10%
            revert InvalidFeeValue();
        }
        feePercentage = _newFee;
        emit FeeUpdated(_newFee);
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        if(_feeReceiver == address(0)) {
            revert InvalidAddress();
        }
        
        feeReceiver = _feeReceiver;
    }

    /// @notice Allows the contract owner to update the address of the glvRouter.
    /// @param _glvRouter The new address of the glvRouter.
    function updateGlvRouter(address _glvRouter) external onlyOwner {
        if (_glvRouter == address(0)) {
            revert InvalidAddress();
        }
        glvRouter = _glvRouter;

        emit GlvRouterUpdated(_glvRouter);
    }

    /// @notice Allows the contract owner to update the address of the exchangeRouter.
    /// @param _exchangeRouter The new address of the exchangeRouter.
    function updateExchangeRouter(address _exchangeRouter) external onlyOwner {
        if (_exchangeRouter == address(0)) {
            revert InvalidAddress();
        }
        exchangeRouter = _exchangeRouter;

        emit ExchangeRouterUpdated(_exchangeRouter);
    }

    /// @notice Allows the contract owner to update the address of the transferRouter.
    /// @param _transferRouter The new address of the transferRouter.
    function updateTransferRouter(address _transferRouter) external onlyOwner {
        if (_transferRouter == address(0)) {
            revert InvalidAddress();
        }
        transferRouter = _transferRouter;

        emit TransferRouterUpdated(_transferRouter);
    }

    /// @dev Update the address of the GBC wallet beacon
    /// @param _gbcWalletBeacon - the address of the beacon
    function updateBeacon(address _gbcWalletBeacon) external onlyOwner {
        if (_gbcWalletBeacon == address(0)) revert InvalidAddress();

        gbcWalletBeacon = _gbcWalletBeacon;
    }

    /**
     * @dev Internal function to create or retrieve the user's wallet.
     * @return The address of the user's wallet.
     */
    function getOrCreateWallet() public returns (address) {
        if (wallets[msg.sender] == address(0)) {
            GBCWallet newWallet = GBCWallet(
                payable(address(new GBCWalletProxy(gbcWalletBeacon)))
            );

            newWallet.initialize(msg.sender, address(this));

            wallets[msg.sender] = address(newWallet);

            emit WalletCreated(msg.sender, address(newWallet));
        }
        return wallets[msg.sender];
    }

    /// @notice Returns the address of the glvRouter.
    function getGlvRouter() public view returns (address) {
        return glvRouter;
    }

    /// @notice Returns the address of the exchangeRouter.
    function getExchangeRouter() public view returns (address) {
        return exchangeRouter;
    }

    /// @notice Returns the address of the fee receiver.
    function getFeeReceiver() external view returns (address) {
        return feeReceiver;
    }

    /// @notice Returns the percentage fee taken from each deposit and withdrawal.
    function getFeePercentage() external view returns (uint256) {
        return feePercentage;
    }

    /// @notice Returns the denominator used to calculate the fee percentage.
    function getFeeDenominator() external view returns (uint256) {
        return FEE_DENOMINATOR;
    }

    /// @dev Authorizes an upgrade
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
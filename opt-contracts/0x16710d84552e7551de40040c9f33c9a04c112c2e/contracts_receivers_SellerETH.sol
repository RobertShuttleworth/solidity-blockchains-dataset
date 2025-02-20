// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_utils_Address.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_utils_Strings.sol";

import "./contracts_receivers_Constants.sol";
import "./contracts_token-presale_ITokenPresale.sol";
import {IOracle} from "./contracts_custom-oracle_IOracle.sol";

contract SellerETH is Constants, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Address for address;
    using Strings for string;

    error ClosedERR();
    error PresaleStepClosedERR();
    error ZeroAddressERR();
    error PayerZeroAddressERR();
    error PresaleStepAllocationERR();
    error PriceThresholdERR();
    error AmountZeroERR();
    error TransferNativeERR();
    error MinUsdValueERR();

    event ThresholdUpdated(uint256 threshold);
    event Erc20Recovered(address token, uint256 amount);
    event ETHRecovered(uint256 amount);
    event Sold(
      address indexed user,
      string participant,
      uint256 amount,
      uint256 liquidity,
      uint256 usdAmount,
      uint256 presaleStep
    );

    address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    uint256 private _total;
    ITokenPresale public tokenPresale;

    IOracle private _oracle;
    bytes32 private _id;
    uint256 private _threshold;

    constructor(
        address payable tokenPresale_,
        address oracle_,
        bytes32 id_,
        uint256 threshold_
    ) {
        require(tokenPresale_ != address(0) && oracle_ != address(0), ZeroAddressERR());
        require(threshold_ != 0, PriceThresholdERR());

        tokenPresale = ITokenPresale(tokenPresale_);
        _oracle = IOracle(oracle_);
        _threshold = threshold_;
        _id = id_;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setPriceFeedAddress(address oracle_) external onlyRole(DEFAULT_ADMIN_ROLE) {
      _oracle = IOracle(oracle_);
    }

    function setID(bytes32 id_) external onlyRole(DEFAULT_ADMIN_ROLE) {
      _id = id_;
    }

    function buy(string calldata participant_) external payable nonReentrant {
        _buy(_msgSender(), participant_);
    }

    function buyFor(
        address user_,
        string calldata participant_
    ) external payable onlyRole(ALLOWED_ROLE) nonReentrant {
        _buy(user_, participant_);
    }

    function setThreshold(uint256 threshold_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(threshold_ > 0, PriceThresholdERR());
        _threshold = threshold_;

        emit ThresholdUpdated(threshold_);
    }

    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        _msgSender().call{value: balance}("");

        emit ETHRecovered(balance);
    }

    function recoverErc20(address token_, uint256 amount_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token_).safeTransfer(_msgSender(), amount_);

        emit Erc20Recovered(token_, amount_);
    }

    function getTotal() external view returns (uint256) {
        return _total;
    }

    function getThreshold() external view returns (uint256) {
        return _threshold;
    }

    function _buy(
        address user_,
        string memory participant_
    ) internal whenNotPaused {
        uint256 amount = msg.value;
        require(user_ != address(0), PayerZeroAddressERR());
        require(amount > 0, AmountZeroERR());
        require(tokenPresale.getStatus() == ITokenPresale.Status.Opened, ClosedERR());

        IOracle.Price memory priceData = _oracle.getPrice(_id);
        ITokenPresale.PresaleStep memory presaleStep = tokenPresale.getPresaleStep(tokenPresale.getCurrent());

        require(presaleStep.status == ITokenPresale.Status.Opened, PresaleStepClosedERR());
        (uint256 liquidity, uint256 usdAmount) = _getLiquidity(amount,priceData);
        liquidity = _addPaymentBonus(liquidity, usdAmount);
        require(presaleStep.supply >= presaleStep.sold + liquidity, PresaleStepAllocationERR());

        uint8 decimals = priceData.decimals;
        uint256 price = priceData.price;

        require(block.timestamp - priceData.timestamp <= _threshold, PriceThresholdERR());

        uint256 funds = (amount * price * NUMERATOR) / (10 ** (DECIMALS + decimals));
        require(tokenPresale.getMinUsdValue() <= funds, MinUsdValueERR());
      
        (string memory participant, uint256 coinFunds, uint256 tokenFunds) = _getParticipant(
            user_,
            participant_,
            amount,
            priceData
        );
        _process(amount, coinFunds);

        _total = _total + amount;
        tokenPresale.setData(user_, ETH_ADDRESS, funds, liquidity, participant, coinFunds, tokenFunds);

        emit Sold(user_, participant, amount, liquidity, usdAmount, tokenPresale.getCurrent());
    }

    function _process(uint256 amount_, uint256 reward_) internal {
        address treasury = tokenPresale.getBank();
        (bool success, ) = treasury.call{value: amount_ - reward_}("");
        require(success, TransferNativeERR());

        if (reward_ > 0) {
            (success, ) = address(tokenPresale).call{value: reward_}("");
            require(success, TransferNativeERR());
        }
    }

    function _getParticipant(
        address user_,
        string memory participant_,
        uint256 amount_,
        IOracle.Price memory priceData
    ) internal view returns (string memory participant, uint256, uint256) {
        participant = tokenPresale.getParticipant(user_, participant_);
        if (participant.equal("")) {
            return (participant, 0, 0);
        }
        (uint256 fRate, uint256 sRate) = tokenPresale.getParticipantRates(participant);
        uint256 coinFunds = (amount_ * fRate) / 1000;
        uint256 tokenFunds = (amount_ * sRate) / 1000;

        (uint256 liquidity,) = _getLiquidity(tokenFunds,priceData);

        return (participant, coinFunds, liquidity);
    }

    function _getLiquidity(
        uint256 amount_,
        IOracle.Price memory priceData
    ) internal view returns (uint256 tokenAmount, uint256 amountInUSD) {
        require(block.timestamp - priceData.timestamp <= _threshold, PriceThresholdERR());
        amountInUSD = (amount_ * priceData.price) / (10 ** priceData.decimals);
        tokenAmount = amountInUSD * NUMERATOR / tokenPresale.getPrice();
    }

    function _addPaymentBonus(uint256 tokenAmount, uint256 amountInUSD) internal view returns(uint256) {
        uint256 bonus = tokenPresale.calculatePaymentBonus(amountInUSD, tokenAmount);
        return tokenAmount + bonus;
    }

    receive() external payable {}
}
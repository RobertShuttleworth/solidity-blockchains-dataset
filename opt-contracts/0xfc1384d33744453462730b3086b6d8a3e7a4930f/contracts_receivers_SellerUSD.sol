// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_utils_Context.sol";

import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_utils_Strings.sol";

import "./contracts_token-presale_ITokenPresale.sol";
import "./contracts_receivers_Constants.sol";

contract SellerUSD is Constants, AccessControl, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Strings for string;

    error ClosedERR();
    error PresaleStepClosedERR();
    error ZeroAddressERR();
    error PayerZeroAddressERR();
    error PresaleStepAllocationERR();
    error PriceThresholdERR();
    error AmountZeroERR();
    error MinAmountInERR();
    error TokenNotAddedERR();
    error TokenAlreadyAddedERR();
  
  
    struct Token {
        bool defined;
        uint256 total;
    }

    mapping(address => Token) private _tokens;
    
    ITokenPresale public tokenPresale;

    event Sold (
        address indexed user,
        address indexed token,
        string participant,
        uint256 amount,
        uint256 liquidity,
        uint256 usdAmount,
        uint256 presaleStep
    );

    constructor(address tokenPresale_, address[] memory tokens_) {
        require(tokenPresale_ != address(0), ZeroAddressERR());

        for (uint256 index = 0; index < tokens_.length; index++) {
            require(tokens_[index] != address(0), ZeroAddressERR());
            _tokens[tokens_[index]] = Token({defined: true, total: 0});
        }
        tokenPresale = ITokenPresale(tokenPresale_);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function buy(
        address token_,
        uint256 amount_,
        string calldata participant_
    ) external nonReentrant {
        _buy(token_, amount_, _msgSender(), participant_);
    }

    function buyFor(
        address token_,
        uint256 amount_,
        address user_,
        string calldata participant_
    ) external nonReentrant onlyRole(ALLOWED_ROLE) {
        _buy(token_, amount_, user_, participant_);
    }

    function recoverErc20(address token_, uint256 amount_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token_).safeTransfer(_msgSender(), amount_);
    }

    function isToken(address token_) external view returns (bool) {
        return _tokens[token_].defined;
    }

    function getTotal(address token_) external view returns (uint256) {
        return _tokens[token_].total;
    }

    function _buy(
        address token_,
        uint256 amount_,
        address user_,
        string calldata participant_
    ) internal whenNotPaused {
        require(user_ != address(0), PayerZeroAddressERR());

        require(amount_ > 0, AmountZeroERR());
        require(_tokens[token_].defined, TokenNotAddedERR());
        require(tokenPresale.getStatus() == ITokenPresale.Status.Opened, ClosedERR());

        ITokenPresale.PresaleStep memory presaleStep = tokenPresale.getPresaleStep(tokenPresale.getCurrent());
        require(presaleStep.status == ITokenPresale.Status.Opened, PresaleStepClosedERR());
        (uint256 liquidity, uint256 usdAmount) = _getLiquidity(token_, amount_);
        liquidity = _addPaymentBonus(liquidity, usdAmount);

        require(presaleStep.supply >= presaleStep.sold + liquidity, PresaleStepAllocationERR());
        uint256 decimals = IERC20Metadata(token_).decimals();
        uint256 funds = (amount_ * NUMERATOR) / (10 ** decimals);

        require(tokenPresale.getMinUsdValue() <= funds, MinAmountInERR());

        (string memory participant, uint256 fTokenFunds, uint256 sTokenFunds) = _getRefCode(
            user_,
            token_,
            participant_,
            amount_
        );
        _purchase(_msgSender(), token_, amount_, fTokenFunds);

        _tokens[token_].total = _tokens[token_].total + amount_;
//        (uint256 liquidity, uint256 usdAmount) = _getLiquidity(token_, amount_, variant_);

        tokenPresale.setData(user_, token_, funds, liquidity, participant, fTokenFunds, sTokenFunds);

        emit Sold(
            user_,
            token_,
            participant,
            amount_,
            liquidity,
            usdAmount,
            tokenPresale.getCurrent()
        );
    }

    function _purchase(address user_, address token_, uint256 amount_, uint256 reward_) internal {
        address treasury = tokenPresale.getBank();
        IERC20(token_).safeTransferFrom(user_, treasury, amount_ - reward_);
        if (reward_ > 0) {
            IERC20(token_).safeTransferFrom(user_, address(tokenPresale), reward_);
        }
    }

    function _getRefCode(
        address user_,
        address token_,
        string calldata participant_,
        uint256 amount_
    ) internal view returns (string memory, uint256, uint256) {
        string memory participant = tokenPresale.getParticipant(user_, participant_);
        if (participant.equal("")) {
            return (participant, 0, 0);
        }
        (uint256 fReward_, uint256 secondaryReward_) = tokenPresale.getParticipantRates(participant);
        uint256 fTokenFunds = (amount_ * fReward_) / 1000;
        uint256 sTokenFunds = (amount_ * secondaryReward_) / 1000;
        (uint256 liquidity,) = _getLiquidity(token_, sTokenFunds);

        return (participant, fTokenFunds, liquidity);
    }

    function _getLiquidity(
        address token_,
        uint256 amount_
    ) internal view returns (uint256 tokenAmount, uint256 amountInUSD) {
        uint8 decimals = IERC20Metadata(token_).decimals();

        amountInUSD = (amount_ * 10 ** DECIMALS) / 10 ** decimals;
        tokenAmount = amountInUSD * NUMERATOR / tokenPresale.getPrice();
    }

    function _addPaymentBonus(uint256 tokenAmount, uint256 amountInUSD) internal view returns(uint256) {
        uint256 bonus = tokenPresale.calculatePaymentBonus(amountInUSD, tokenAmount);
        return tokenAmount + bonus;
    }
}
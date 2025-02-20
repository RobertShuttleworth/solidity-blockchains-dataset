// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_utils_math_Math.sol";
import "./openzeppelin_contracts_utils_cryptography_EIP712.sol";
import "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import "./openzeppelin_contracts_utils_Strings.sol";

import "./contracts_token-presale_Constants.sol";
import "./contracts_token-presale_ITokenPresale.sol";

contract TokenPresale is Constants, EIP712, AccessControl, ReentrancyGuard, ITokenPresale {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using Strings for string;

    address private _bank;
    uint256 private _total;
    uint256 private _current;
    uint256 private _minUsdValue;
    uint256 private _defaultRate1;
    uint256 private _defaultRate2;
    PaymentBonus[] private _paymentBonus;
    address private _claimApprover;
    Status private _status;

    mapping(address => mapping(uint256 => uint256)) private _userAllocation;
    mapping(address => string) private _userParticipants;
    mapping(string => mapping(address => uint256)) private _participantsAllocation;
    mapping(string => Participant) private _participants;
    mapping(bytes32 => bool) private _passedHashes;
    PresaleStep[] private _presaleSteps;

    bool public skipParticipantCheck;

    constructor(address bank_, address claimApprover_) EIP712("TokenPresale", "1.0.0") {
        require(bank_ != address(0), ZeroAddressERR());

        _bank = bank_;
        _claimApprover = claimApprover_;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(PRESALE_SELLER_ROLE, _msgSender());
        _grantRole(PRESALE_MANAGER_ROLE, _msgSender());
        _grantRole(PRESALE_CRAWLER_ROLE, _msgSender());
    }

    function startPresale() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_status == Status.None, OpenedERR());
        _status = Status.Opened;

        emit StatusUpdated(_status);
    }

    function stopPresale() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_status == Status.Opened, ClosedERR());
        _status = Status.Closed;

        emit StatusUpdated(_status);
    }

    function addNewPresaleStep(
        uint256 price_,
        uint256 supply_
    ) external onlyRole(PRESALE_MANAGER_ROLE) {
        require(_status != Status.Closed, ClosedERR());

        _presaleSteps.push(
            PresaleStep({
                defined: true,
                status: Status.None,
                price: price_,
                sold: 0,
                supply: supply_
            })
        );

        emit PresaleStepAdded(price_, supply_);
    }

    function setDefaultRates(
        uint256 defaultRate1_,
        uint256 defaultRate2_
    ) external onlyRole(PRESALE_MANAGER_ROLE) {
        require(_status != Status.Closed, ClosedERR());
        require(defaultRate1_ <= 1000, DefaultRateERR());
        require(defaultRate2_ <= 1000, DefaultRateERR());

        _defaultRate1 = defaultRate1_;
        _defaultRate2 = defaultRate2_;

        emit ParticipantRateSetup(_defaultRate1, _defaultRate2);
    }

    function setupParticipant(
        string[] calldata participant_,
        uint256[] calldata newRate1_,
        uint256[] calldata newRate2_
    ) external onlyRole(PRESALE_CRAWLER_ROLE) {
        require(_status != Status.Closed, ClosedERR());
        require(participant_.length == newRate1_.length && participant_.length == newRate2_.length, ParamsInvalidERR());

        for (uint256 index = 0; index < participant_.length; index++) {
            _participants[participant_[index]] = Participant({
                defined: true,
                enabled: true,
                firstParticipantRate: newRate1_[index],
                secondParticipantRate: newRate2_[index]
            });

            emit ParticipantSetup(participant_[index], newRate1_[index], newRate2_[index]);
        }
    }

    function updatePresaleStepPrice(
        uint256 index_,
        uint256 price_
    ) external onlyRole(PRESALE_MANAGER_ROLE) {
        require(_status == Status.Opened, ClosedERR());
        require(_presaleSteps[index_].defined, PresaleStepUndefinedERR());
        require(_presaleSteps[index_].status == Status.None, PresaleStepStartedERR());

        _presaleSteps[index_].price = price_;

        emit PresaleStepPriceUpdated(index_, price_);
    }

    function updatePresaleStepSupply(
        uint256 index_,
        uint256 supply_
    ) external onlyRole(PRESALE_MANAGER_ROLE) {
        require(_status != Status.Closed, ClosedERR());
        require(_presaleSteps[index_].defined, PresaleStepUndefinedERR());
        require(_presaleSteps[index_].status != Status.Closed, PresaleStepClosedERR());
        require(_presaleSteps[index_].sold <= supply_, PresaleStepSupplyERR());

        _presaleSteps[index_].supply = supply_;

        emit PresaleStepSupplyUpdated(index_, supply_);
    }

    function openPresaleStep(uint256 index_) external onlyRole(PRESALE_CRAWLER_ROLE) {
        require(_status == Status.Opened, ClosedERR());
        require(_presaleSteps[index_].defined, PresaleStepUndefinedERR());

        if (_presaleSteps[_current].status == Status.Opened) {
            _presaleSteps[_current].status = Status.Closed;
        }
        _presaleSteps[index_].status = Status.Opened;
        _current = index_;

        emit PresaleStepOpened(index_);
    }

    function closePresaleStep(uint256 index_) external onlyRole(PRESALE_CRAWLER_ROLE) {
        require(_presaleSteps[index_].defined, PresaleStepUndefinedERR());

        _presaleSteps[index_].status = Status.Closed;

        emit PresaleStepClosed(index_);
    }

    function setMinUsdValue(uint256 amount_) external onlyRole(PRESALE_MANAGER_ROLE) {
        require(amount_ >= MIN, MinUsdValueERR());

        _minUsdValue = amount_;

        emit MinUsdValueUpdated(_minUsdValue);
    }

    function setBank(address bank_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bank_ != address(0), ZeroAddressERR());

        _bank = bank_;

        emit BankUpdated(_bank);
    }

    function setClaimApprover(address claimApprover_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _claimApprover = claimApprover_;

        emit ClaimApproverUpdated(claimApprover_);
    }

    function setData(
        address user_,
        address token_,
        uint256 amount_,
        uint256 sold_,
        string calldata participant_,
        uint256 reward1_,
        uint256 reward2_
    ) external onlyRole(PRESALE_SELLER_ROLE) {
        _total = _total + sold_;
        _presaleSteps[_current].sold = _presaleSteps[_current].sold + sold_;
        _userAllocation[user_][_current] = _userAllocation[user_][_current] + sold_;

        if (!participant_.equal("")) {
            if (!_participants[participant_].defined) {
                _participants[participant_].defined = true;
                _participants[participant_].enabled = true;

                emit ParticipantSetup(participant_, _defaultRate1, _defaultRate2);
            }
            _participantsAllocation[participant_][token_] += reward1_;
            _participantsAllocation[participant_][TOKEN] += reward2_  ;
            _userParticipants[user_] = participant_;
        }
    }

    function setTrustParticipant(bool value) external onlyRole(PRESALE_MANAGER_ROLE) {
      skipParticipantCheck = value;
    }

    function setPaymentBonus(uint256[] calldata bonus_, uint256[] calldata payment_) external onlyRole(PRESALE_MANAGER_ROLE) {
        require(bonus_.length == payment_.length, InvalidArrayLengthERR());

        delete _paymentBonus;

        for (uint256 idx = 0; idx < bonus_.length; idx++) {
            if (idx == 0) {
                require(bonus_[0] != 0 && payment_[0] != 0, InvalidPaymentBonusArraysERR());
            } else {
                require(bonus_[idx - 1] < bonus_[idx] && payment_[idx - 1] < payment_[idx], InvalidPaymentBonusArraysERR());
            }

            _paymentBonus.push(PaymentBonus({
                payment: payment_[idx],
                bonus: bonus_[idx]
            }));
        }
    }

    function enableParticipant(string calldata participant_) external onlyRole(PRESALE_MANAGER_ROLE) {
        require(_participants[participant_].defined, ParticipantUndefinedERR());
        require(!_participants[participant_].enabled, ParticipantEnabledERR());

        _participants[participant_].enabled = true;

        emit ParticipantEnabled(participant_);
    }

    function disableParticipant(string calldata participant_) external onlyRole(PRESALE_MANAGER_ROLE) {
        require(_participants[participant_].defined, ParticipantUndefinedERR());
        require(_participants[participant_].enabled, ParticipantDisabledERR());

        _participants[participant_].enabled = false;

        emit ParticipantDisabled(participant_);
    }

    function _buildHash(address[] memory tokens_, string memory participant_, address claimer_, uint256 deadline_) pure private returns(bytes32) {
       return keccak256(
         abi.encode(
           CLAIM_PARTICIPANT_TYPEHASH,
           keccak256(abi.encodePacked(tokens_)),
           keccak256(bytes(participant_)),
           claimer_,
           deadline_
         )
       );
    }

  function claimParticipant(address[] memory tokens_, string memory participant_, uint256 deadline_, uint8 v, bytes32 r, bytes32 s) external nonReentrant {
      address claimer_ = _msgSender();
      require(_claimApprover != address(0), ClaimApproverNotSetERR());
      require(deadline_ > block.timestamp, TransactionExpiredERR());

      bytes32 hash = _hashTypedDataV4(_buildHash(tokens_, participant_, claimer_, deadline_));
      address recoveredSigner = hash.recover(v, r, s);

      require(recoveredSigner == _claimApprover, InvalidClaimApproverERR());
      require(!_passedHashes[hash], HashAlreadyUsedERR());

      _passedHashes[hash] = true;

      require(tokens_.length > 0, InvalidArrayLengthERR());
      require(_participants[participant_].defined, ParticipantUndefinedERR());
      require(_participants[participant_].enabled, ParticipantDisabledERR());

      for (uint256 i = 0; i < tokens_.length; i++) {
        address token = tokens_[i];
        uint256 balance = _participantsAllocation[participant_][token];
        if (balance == 0) {
          continue;
        }

        _participantsAllocation[participant_][token] = 0;
        if (token == ETH_ADDRESS) {
          (bool success, ) = claimer_.call{value: balance}("");
          require(success, EthCallERR());
        } else {
          IERC20(token).safeTransfer(claimer_, balance);
        }

        emit ParticipantRewardsClaimed(participant_, token, balance);
      }
    }

    function recoverETH() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        _msgSender().call{value: balance}("");

        emit ETHRecovered(balance);
    }

    function recoverERC20(address token_, uint256 amount_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token_).safeTransfer(_msgSender(), amount_);

        emit Erc20Recovered(token_, amount_);
    }

    function getBank() external view returns (address) {
        return _bank;
    }

    function getMinUsdValue() external view returns (uint256) {
        return _minUsdValue;
    }

    function getPresaleStepsCount() external view returns (uint256) {
        return _presaleSteps.length;
    }

    function getCurrent() external view returns (uint256) {
        return _current;
    }

    function getPresaleStep(uint256 index_) external view returns (PresaleStep memory) {
        return _presaleSteps[index_];
    }

    function getTotal() external view returns (uint256) {
        return _total;
    }

    function getUserAllocation(uint256 presaleStep_, address user_) external view returns (uint256) {
        return _userAllocation[user_][presaleStep_];
    }

    function getParticipantsAllocation(address token_, string calldata participant_) external view returns (uint256) {
        return _participantsAllocation[participant_][token_];
    }

    function getRates() external view returns (uint256, uint256) {
        return (_defaultRate1, _defaultRate2);
    }

    function getParticipant(address user_, string calldata participant_) external view returns (string memory) {
        if (skipParticipantCheck) {
          return participant_;
        }

        Participant memory participants_ = _participants[_userParticipants[user_]];
        if (participants_.defined && participants_.enabled) {
            return _userParticipants[user_];
        }
        participants_ = _participants[participant_];
        if (!participants_.defined || participants_.enabled) {
            return participant_;
        }
        return "";
    }

    function getParticipantRates(string calldata participant_) external view returns (uint256, uint256) {
        Participant memory participants_ = _participants[participant_];
        if (participants_.defined) {
            return (
                Math.max(participants_.firstParticipantRate, _defaultRate1),
                Math.max(participants_.secondParticipantRate, _defaultRate2)
            );
        }
        return (_defaultRate1, _defaultRate2);
    }

    function getStatus() public view returns (ITokenPresale.Status) {
        return _status;
    }

    function getPrice() public view returns (uint256) {
        if (_presaleSteps[_current].status == Status.Opened) {
            return _presaleSteps[_current].price;
        }
        return 0;
    }

    function getPaymentBonus() external view returns (PaymentBonus[] memory) {
        return _paymentBonus;
    }

    function calculatePaymentBonus(uint256 usdAmount_, uint256 tokenAmount_) external view returns(uint256) {
        if (_paymentBonus.length == 0) {
            return 0;
        }
        
        int256 target = -1;

        for (uint256 idx = 0; idx < _paymentBonus.length; idx++) {
            if (usdAmount_ >= _paymentBonus[idx].payment) {
                target = int256(idx);
            } else {
                break;
            }
        }

        if (target == -1) {
            return 0;
        }

        return tokenAmount_ * _paymentBonus[uint256(target)].bonus / (10 ** PRECISION);
    }

    receive() external payable {}
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

contract TokenPresaleFantom is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  struct InvestorInfoType {
    address depositorAddress;
    uint buyerOption;
    uint period;
    uint256 amount;
    string selfReferralCode;
    string friendReferralCode;
  }

  uint public preSaleStatus = 0;

  mapping(uint => InvestorInfoType) private InvestorInfo;
  mapping(address => bool) public WhiteList;
  mapping(address => uint[]) private addressToInvestorIds;

  address public constant axlUSDC_ADDRESS =
    0x1B6382DBDEa11d97f24495C9A90b7c88469134a4;
  address public constant lzUSDC_ADDRESS =
    0x28a92dde19D9989F39A49905d7C9C2FAc7799bDf;
  uint public id;
  uint256 public totalDepositedAmount;
  uint256 public constant hardCap = 3 * 10 ** 11;
  address public constant multiSigWallet =
    0xD48eEe8BCf9DA2AA2E8Bb498D25550C6B196c667;

  event Deposit(address indexed depositor, uint256 indexed depositedAmount);

  event Withdraw(address indexed CoinAddress, uint256 indexed withdrawAmount);

  event UpdateWhiteList(
    address indexed addedAddress,
    bool indexed isWhitelisted
  );

  event PresaleStatus(uint indexed status);

  constructor() payable Ownable(multiSigWallet) {}

  function deposit(
    address tokenAddress,
    uint _buyerOption,
    uint _period,
    uint256 _amount,
    string memory _selfReferralCode,
    string memory _friendReferralCode
  ) external nonReentrant {
    bool isDepositAvailable = (preSaleStatus == 1) ||
      (preSaleStatus == 0 && WhiteList[msg.sender]);

    require(isDepositAvailable, "You can not deposit");

    require(
      _buyerOption > 0 && _buyerOption < 4,
      "You need to select exact Tier"
    );

    if (_buyerOption == 1)
      require(_period == 7, "You need to select correct Period");
    if (_buyerOption == 2 || _buyerOption == 3)
      require(
        _period == 7 || _period == 12 || _period == 18 || _period == 24,
        "You need to select correct Period"
      );

    require(
      tokenAddress == axlUSDC_ADDRESS || tokenAddress == lzUSDC_ADDRESS,
      "Invalid token address."
    );

    require(
      totalDepositedAmount + _amount < hardCap,
      "Deposit exceeds the hard cap."
    );

    IERC20 paymentToken = IERC20(tokenAddress);
    SafeERC20.safeTransferFrom(
      paymentToken,
      msg.sender,
      address(this),
      _amount
    );
    id = id + 1;
    InvestorInfo[id] = InvestorInfoType({
      depositorAddress: msg.sender,
      buyerOption: _buyerOption,
      period: _period,
      amount: _amount,
      selfReferralCode: _selfReferralCode,
      friendReferralCode: _friendReferralCode
    });

    addressToInvestorIds[msg.sender].push(id);
    totalDepositedAmount += _amount;

    if (totalDepositedAmount == hardCap) preSaleStatus = 2;

    emit Deposit(msg.sender, _amount);
  }

  function withdraw(
    address tokenAddress,
    uint256 _amount
  ) external onlyOwner nonReentrant {
    IERC20 token = IERC20(tokenAddress);
    require(
      token.balanceOf(address(this)) >= _amount,
      "Insufficient token balance."
    );
    token.safeTransfer(msg.sender, _amount);

    emit Withdraw(tokenAddress, _amount);
  }

  function batchUpdateWhiteList(
    address[] calldata _addresses,
    bool _status
  ) external onlyOwner nonReentrant {
    for (uint i = 0; i < _addresses.length; i++) {
      require(_addresses[i] != address(0), "Invalid address");
      WhiteList[_addresses[i]] = _status;
      emit UpdateWhiteList(_addresses[i], _status);
    }
  }

  function setPresaleStatus(uint _status) external onlyOwner {
    require(_status >= 0 && _status < 3, "Status should be between 0 and 2");
    preSaleStatus = _status;

    emit PresaleStatus(_status);
  }

  function getInvestorIds(
    address _address
  ) public view returns (uint[] memory) {
    require(
      addressToInvestorIds[_address].length > 0,
      "No investor IDs found for this address"
    );
    return addressToInvestorIds[_address];
  }

  function getInvestorInfoById(
    uint _id
  ) public view returns (InvestorInfoType memory) {
    require(
      InvestorInfo[_id].depositorAddress != address(0),
      "Investor ID not found"
    );
    return InvestorInfo[_id];
  }

  function getInvestorInfo(
    address _address
  ) public view returns (InvestorInfoType[] memory) {
    uint[] memory ids = addressToInvestorIds[_address];
    require(ids.length > 0, "No investors found for this address");

    InvestorInfoType[] memory allInvestorInfo = new InvestorInfoType[](
      ids.length
    );
    for (uint i = 0; i < ids.length; i++) {
      allInvestorInfo[i] = InvestorInfo[ids[i]];
    }
    return allInvestorInfo;
  }
}
// SPDX-License-Identifier: BSD 3-Clause

pragma solidity 0.8.9;

import "./contracts_abstracts_BaseContract.sol";
import "./contracts_interfaces_IMENToken.sol";
import "./contracts_interfaces_INFTPass.sol";

contract ShareManager is BaseContract {
  struct Config {
    uint secondsInADay;
    uint nftHolderSharePercentage;
    uint zeroTimestamp;
    mapping(uint => uint) totalNFTStocked;
    mapping(uint => uint) totalSTTokenStocked;
    mapping(uint => uint) nftReward;
    mapping(uint => uint) stTokenReward;
    mapping(uint => uint) funded;
  }
  struct User {
    uint nftStocked;
    uint[] listNftStocked;
    uint stTokenStocked;
  }
  uint private constant CHECKIN_INTERVAL = 28;
  mapping (address => mapping(uint => User)) public users;
  Config public config;
  IMENToken public menToken;
  IMENToken public stToken;
  INFTPass public nftPass;
  uint public totalFunded;

  event CheckedIn(address indexed user, uint currentRound, uint nftStaked, uint stTokenStaked, uint timestamp);
  event Claimed(address indexed user, uint currentRound, uint reward, uint timestamp);
  event ConfigUpdated(uint secondsInADay, uint nftHolderSharePercentage, uint timestamp);
  event TokenFunded(uint amount, uint nftShare, uint stTokenShare, uint timestamp);

  function initialize() public initializer {
    BaseContract.init();
    config.secondsInADay = 86_400;
    config.nftHolderSharePercentage = 50;
  }

  function fund(uint _amount) external {
    _takeToken(menToken, _amount);
    uint currentRound = getCurrentRound() - 1;
    uint nftShare = _amount * config.nftHolderSharePercentage / 100;
    config.nftReward[currentRound] += nftShare;
    config.stTokenReward[currentRound] += _amount - nftShare;
    config.funded[currentRound] += _amount;
    totalFunded += _amount;
    emit TokenFunded(_amount, nftShare, _amount - nftShare, block.timestamp);
  }

  function checkin() external {
    require(config.zeroTimestamp > 0, "ShareManager: not started");
    uint currentRound = getCurrentRound();
    uint checkinRound = currentRound > 0 ? currentRound - 1 : 0;
    require(block.timestamp - (config.zeroTimestamp + (checkinRound + 1) * CHECKIN_INTERVAL * config.secondsInADay) < config.secondsInADay, "ShareManager: please come back later");
    uint nftBalance = nftPass.balanceOf(msg.sender);
    User storage user = users[msg.sender][checkinRound];
    if (nftBalance > 0) {
      user.nftStocked += nftBalance;
      config.totalNFTStocked[checkinRound] += nftBalance;
      _takeNftToken(user);
    }
    emit CheckedIn(msg.sender, checkinRound, nftBalance, 0, block.timestamp);
  }

  function claim(uint _round) external {
    require(block.timestamp - (config.zeroTimestamp + (_round + 1) * CHECKIN_INTERVAL * config.secondsInADay) >= config.secondsInADay, "ShareManager: please come back later");
    require(!nftPass.waitingList(msg.sender), "ShareManager: you can not do this now");
    User storage user = users[msg.sender][_round];
    require(user.nftStocked > 0 || user.stTokenStocked > 0, "ShareManager: no reward");
    uint claimable;
    if (user.stTokenStocked > 0) {
      uint stTokenStocked = user.stTokenStocked;
      user.stTokenStocked = 0;
      claimable += config.stTokenReward[_round] * stTokenStocked / config.totalSTTokenStocked[_round];
      stToken.transfer(msg.sender, stTokenStocked);
    }
    if (user.nftStocked > 0) {
      claimable += config.nftReward[_round] * user.nftStocked / config.totalNFTStocked[_round];
      user.nftStocked = 0;
      for (uint i = 0; i < user.listNftStocked.length; i++) {
        nftPass.transferFrom(address(this), msg.sender, user.listNftStocked[i]);
      }
    }
    if (claimable > 0) {
      menToken.transfer(msg.sender, claimable);
    }
    emit Claimed(msg.sender, _round, claimable, block.timestamp);
  }

  function getUserHolding(address _user) external view returns (uint, uint) {
    uint currentRound = getCurrentRound();
    return getUserHoldingInRound(_user, currentRound == 0 ? 0 : currentRound - 1);
  }

  function getUserHoldingInRound(address _user, uint _round) public view returns (uint, uint) {
    User storage user = users[_user][_round];
    return (
      user.nftStocked,
      user.stTokenStocked
    );
  }

  function getRoundData(uint _round) public view returns (uint, uint, uint, uint, uint) {
    return (
      config.totalNFTStocked[_round],
      config.totalSTTokenStocked[_round],
      config.nftReward[_round],
      config.stTokenReward[_round],
      config.funded[_round]
    );
  }

  function getCurrentRoundData() external view returns (uint, uint, uint, uint, uint) {
    return getRoundData(getCurrentRound());
  }

  function getCurrentRound() public view returns (uint) {
    return (block.timestamp - config.zeroTimestamp) / (CHECKIN_INTERVAL * config.secondsInADay);
  }

  // AUTH FUNCTIONS

  function start(uint _timestamp) external onlyMn {
    require(_timestamp < block.timestamp, "ShareManager: must be in the pass");
    config.zeroTimestamp = _timestamp;
  }

  function updateConfig(uint _secondsInADay, uint _nftHolderSharePercentage) external onlyMn {
    require(_nftHolderSharePercentage >= 0 && _nftHolderSharePercentage <= 100, "ShareManager: data invalid");
    config.secondsInADay = _secondsInADay;
    config.nftHolderSharePercentage = _nftHolderSharePercentage;
    emit ConfigUpdated(_secondsInADay, _nftHolderSharePercentage, block.timestamp);
  }

  // PRIVATE FUNCTIONS

  function _takeToken(IMENToken _token, uint _amount) private {
    require(_token.allowance(msg.sender, address(this)) >= _amount, "ShareManager: allowance invalid");
    require(_token.balanceOf(msg.sender) >= _amount, "ShareManager: insufficient balance");
    _token.transferFrom(msg.sender, address(this), _amount);
  }

  function _takeNftToken(User storage _user) private {
    require(nftPass.isApprovedForAll(msg.sender, address(this)), "ShareManager: please call setApprovalForAll() first");
    uint[] memory userNFTs = nftPass.getOwnerNFTs(msg.sender);
    for (uint i = 0; i < userNFTs.length; i++) {
      _user.listNftStocked.push(userNFTs[i]);
      nftPass.transferFrom(msg.sender, address(this), userNFTs[i]);
    }
  }

  function _initDependentContracts() override internal {
    menToken = IMENToken(addressBook.get("menToken"));
    stToken = IMENToken(addressBook.get("stToken"));
    nftPass = INFTPass(addressBook.get("nftPass"));
  }
}
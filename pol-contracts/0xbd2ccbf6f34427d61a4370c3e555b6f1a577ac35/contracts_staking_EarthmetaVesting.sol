// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ReentrancyGuardUpgradeable} from "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import {Ownable2StepUpgradeable} from "./openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract EarthmetaVesting is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    struct Vesting {
        uint256 amount;
        uint256 endTime;
        bool claimed;
    }

    struct VestingRequest {
        address receiver;
        uint256 amount;
        uint256 endTime;
    }

    struct ClaimRequest {
        uint256 id;
        address user;
    }

    string public constant VERSION = "1.0.0";
    IERC20 public emt;
    address public signer;

    mapping(address => Vesting[]) public userVesting;

    mapping(address => bool) public blacklist;

    event NewVesting(address indexed user, uint256 amount, uint256 endTime, uint256 vestingId);
    event Claimed(address indexed user, uint256 vestingId, uint256 amount);
    event Blacklist(address user);
    event DeleteVesting(address indexed user, uint256 amount, uint256 endTime, uint256 vestingId);

    error NotSigner();

    modifier onlySigner() {
        if (msg.sender != signer) {
            revert NotSigner();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _emt address.
    /// @param _signer address.
    function initialize(IERC20 _emt, address _signer) external initializer {
        emt = _emt;
        signer = _signer;
        __ReentrancyGuard_init();
        __Ownable2Step_init();
    }

    function newVestingMany(VestingRequest[] calldata vestingRequests) external onlySigner {
        for (uint256 i = 0; i < vestingRequests.length; i++) {
            _newVesting(vestingRequests[i]);
        }
    }

    function _newVesting(VestingRequest calldata vestingRequest) private {
        require(!blacklist[vestingRequest.receiver], "User blacklisted");
        require(vestingRequest.amount > 0, "Zero amount");

        Vesting memory newVesting = Vesting({
            amount: vestingRequest.amount,
            endTime: vestingRequest.endTime,
            claimed: false
        });

        address receiver = vestingRequest.receiver;
        uint256 vestingId = userVesting[receiver].length;
        userVesting[receiver].push(newVesting);

        emit NewVesting(receiver, vestingRequest.amount, vestingRequest.endTime, vestingId);
    }

    function claimMany(ClaimRequest[] calldata _requests) external nonReentrant {
        for (uint256 i = 0; i < _requests.length; i++) {
            _claim(_requests[i]);
        }
    }

    function _claim(ClaimRequest calldata _request) internal {
        require(!blacklist[_request.user], "User blacklisted");
        require(_request.id < userVesting[_request.user].length, "Invalid vesting ID");

        Vesting storage vesting = userVesting[_request.user][_request.id];
        require(!vesting.claimed, "Already claimed");
        require(block.timestamp >= vesting.endTime, "Vesting period not yet ended");

        uint256 amount = vesting.amount;
        vesting.claimed = true;

        require(emt.balanceOf(address(this)) >= amount, "Insufficient contract balance");
        require(emt.transfer(_request.user, amount), "Transfer failed");

        emit Claimed(_request.user, _request.id, amount);
    }

    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        require(emt.transfer(owner(), _amount), "Transfer failed");
    }

    function getUserVesting(
        address _user,
        uint256 _startIndex,
        uint256 _limit
    ) external view returns (Vesting[] memory) {
        if (_startIndex >= userVesting[_user].length) return new Vesting[](0);

        uint256 endIndex = _startIndex + _limit;
        if (endIndex > userVesting[_user].length) {
            endIndex = userVesting[_user].length;
        }

        Vesting[] memory vestingList = new Vesting[](endIndex - _startIndex);
        for (uint256 i = _startIndex; i < endIndex; i++) {
            vestingList[i - _startIndex] = userVesting[_user][i];
        }

        return vestingList;
    }

    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function blackListWallet(address _user, bool _status) external onlySigner {
        blacklist[_user] = _status;
        emit Blacklist(_user);
    }

    function deleteMany(address[] memory users) external onlySigner {
        for (uint256 i = 0; i < users.length; i++) {
            deleteVesting(users[i]);
        }
    }

    function deleteVesting(address _user) internal {
        Vesting[] memory vestingList = userVesting[_user];
        for (uint256 i = vestingList.length; i > 0; i--) {
            Vesting memory vesting = vestingList[i - 1];
            userVesting[_user].pop();
            emit DeleteVesting(_user, vesting.amount, vesting.endTime, i - 1);
        }
    }
}
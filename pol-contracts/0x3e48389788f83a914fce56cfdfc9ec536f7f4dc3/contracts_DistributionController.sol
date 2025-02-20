// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.2;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

contract DistributionController is Ownable, ReentrancyGuard, Pausable {
    bool public TGEFlag;
    uint256 public TGESetTime;

    uint256 public PFRateMultiplier = 100;
    uint256 public totalDistributions = 12;
    mapping(uint256 => uint256) internal amountFilled;
    mapping(uint256 => uint256) internal rate;
    mapping(address => bool) internal managers;
    address[] internal managersList;
    address public timeLock;
    address public multiSig;

    // Modifiers.
    modifier onlyManagers() {
        require(
            managers[_msgSender()] == true,
            "DC: Not Authorized To Perform This Activiity!"
        );
        _;
    }

    modifier onlyTimelock() {
        require(msg.sender == timeLock, "Not Timelock");
        _;
    }

    modifier onlyMultiSig() {
        require(msg.sender == multiSig, "Not MultiSig");
        _;
    }

    /**
     * @dev Contract Constructor takes msg.sender as admin.
     */
    constructor(address _multiSig, address _timeLock) Ownable(msg.sender) {
        managers[_msgSender()] = true;
        managersList.push(_msgSender());
        updateRate(1, 200); // Seed sale supply 2%
        updateRate(2, 500); // private sale supply 5%
        updateRate(3, 150); // Community sale supply 1.5%
        updateRate(4, 500); // Public sale supply 5%
        updateRate(5, 3000); // Reward supply 30%
        updateRate(6, 1000); // Staking Reward  supply 10%
        updateRate(7, 900); // Liquidity sale supply 9%
        updateRate(8, 500); // Foundation supply 5%
        updateRate(9, 1500); // FounderandTeam supply 15%
        updateRate(10, 250); // Advisors supply 2.5%
        updateRate(11, 1000); // Ecosystem Development supply 10%
        updateRate(12, 500); // Reserve supply 5%
        // total disctribution --> 2+5+1.5+10+9+30+5+15+2.5+5+10+5 = 100%
        multiSig = _multiSig;
        timeLock = _timeLock;
    }

    function transferOwnership(address newOwner) public override onlyTimelock {
        super.transferOwnership(newOwner);
    }

    /**
     * @dev Pause Transactions on contract.
     */
    function pause() external onlyMultiSig {
        _pause();
    }

    /**
     * @dev Unpause Transactions on contract.
     */
    function unpause() external onlyMultiSig {
        _unpause();
    }

    function setMultiSig(address _multiSig) external onlyMultiSig {
        require(_multiSig != address(0), "Zero Address");
        multiSig = _multiSig;
    }

    function setTimelock(address _timelock) external onlyMultiSig {
        require(_timelock != address(0), "Zero Address");
        timeLock = _timelock;
    }

    /**
     * @dev sets TGE flag true.
     */
    function setTGE(bool flag) external onlyMultiSig whenNotPaused {
        TGEFlag = flag;
        TGESetTime = block.timestamp;
    }

    /**
     * @dev fetch distribution data for TPFT.
     */
    function getDistributionData(
        uint256 _distributionID
    ) external view returns (uint256, uint256, uint256, uint256) {
        return (
            _distributionID,
            rate[_distributionID],
            amountFilled[_distributionID],
            PFRateMultiplier
        );
    }

    /**
     * @dev update rates for added Distribution catagories.
     */
    function updateRate(
        uint256 _distributionID,
        uint256 _rate
    ) public onlyOwner whenNotPaused {
        require(
            _distributionID >= 1 && _distributionID <= 12,
            "distribution ID not available"
        );
        rate[_distributionID] = _rate;
    }

    /**
     * @dev update Amount Filled for Distribution categories.
     */
    function updateAmountFilled(
        uint256 _distributionID,
        uint256 _amount
    ) external onlyManagers whenNotPaused {
        require(
            _distributionID >= 1 && _distributionID <= 12,
            "distribution ID not available"
        );
        amountFilled[_distributionID] += _amount;
    }

    /**
     * @dev decrease Amount Filled for Distribution categories.
     */
    function decAmountFilled(
        uint256 _distributionID,
        uint256 _amount
    ) external onlyManagers whenNotPaused {
        require(
            _distributionID >= 1 && _distributionID <= 12,
            "distribution ID not available"
        );
        amountFilled[_distributionID] -= _amount;
    }

    /**
     * @dev Get the complete list of managers
     */
    function getManagers() external view returns (address[] memory) {
        return managersList;
    }

    /**
     * @dev Get manager status.
     */
    function getManagerStatus(
        address _managerAddress
    ) external view returns (bool) {
        return managers[_managerAddress];
    }

    /**
     * @dev Add Manager To Give Them Minting and Burning Authority.
     */
    function addManager(
        address managerAddress
    ) external onlyMultiSig whenNotPaused {
        require(
            !(managerAddress == address(0)),
            "Zero address can't be in Manager List"
        );
        if (managers[managerAddress] == false) {
            managersList.push(managerAddress);
        }
        managers[managerAddress] = true;
    }

    /**
     * @dev Add more than one Managers at a single time.
     */
    function addManagerList(
        address[] calldata managerAddresses
    ) external onlyMultiSig whenNotPaused {
        for (uint i = 0; i < managerAddresses.length; i++) {
            require(
                !(managerAddresses[i] == address(0)),
                "Zero address can't be in Manager List"
            );
            if (managers[managerAddresses[i]] == false) {
                managersList.push(managerAddresses[i]);
            }
            managers[managerAddresses[i]] = true;
        }
    }

    /**
     * @dev Remove Manager
     */
    function removeManager(
        address managerAddress
    ) external onlyMultiSig whenNotPaused {
        require(
            !(managerAddress == address(0)),
            "Zero address can't be in Manager List"
        );
        managers[managerAddress] = false;
    }

    /**
     * @dev Remove Managers
     */
    function removeManagersList(
        address[] memory managerAddressList
    ) external onlyMultiSig whenNotPaused {
        for (uint i = 0; i < managerAddressList.length; i++) {
            managers[managerAddressList[i]] = false;
        }
    }
}
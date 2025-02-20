// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;
import {IRewardsSource} from "./src_interfaces_IRewardsSource.sol";
import "./openzeppelin_contracts_interfaces_IERC20.sol";

interface IAbraAddressProvider {
    function abra() external view returns (address);
}

contract RewardsSource is IRewardsSource {
    IERC20 public immutable ABRA;
    address public immutable staking;
    
    modifier onlyStaking {
        require(msg.sender == staking, 'RewardsSource: onlyStaking');
        _;
    }

    constructor(address _staking) {
        staking = _staking;
        ABRA = IERC20(IAbraAddressProvider(_staking).abra());
    }
    
    function previewRewards() public view returns(uint) {
        return ABRA.balanceOf(address(this));
    }

    function collectRewards() external onlyStaking() {
        uint reward = previewRewards();
        if (reward > 0) {
            ABRA.transfer(staking, reward);
        }
    }
    
}
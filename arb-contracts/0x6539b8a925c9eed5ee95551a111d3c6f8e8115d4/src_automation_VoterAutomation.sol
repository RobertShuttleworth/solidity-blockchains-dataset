// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {Ownable} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import {BaseAutomation} from "./src_automation_BaseAutomation.sol";

import {VoterV4} from "./src_VoterV4.sol";
import {IEpochController} from './src_interfaces_IEpochController.sol';

contract VoterAutomation is BaseAutomation {

    mapping (address => uint32) public lastCalledEpoch; // pair/pool address  => last called epoch
    address public forwarder; // chainlink calls from this address
    VoterV4 public voter;

    constructor(address _voter) Ownable(msg.sender) {
        voter = VoterV4(_voter);
    }

    modifier onlyForwarder() {
        require(forwarder == _msgSender(), "Unauthorized forwarder");
        _;
    }

    function setForwarder(address _forwarder) external onlyOwner {
        forwarder = _forwarder;
    }

    function setVoter(address _voter) external onlyOwner {
        voter = VoterV4(_voter);
    }

    function checkUpkeep(bytes calldata /* checkData */) external cannotExecute returns (bool /* upkeepNeeded */, bytes memory /* performData */) {
        uint index = voter.index();
        for (uint i=0; i < voter.poolsLength(); i++) {
            address gauge = voter.gauges(voter.pools(i));
            if (!voter.isAlive(gauge)) {
                continue;
            }
            if (voter.supplyIndex(gauge) != index) {
                return (true, "");
            }
        }

        return (false, "");
    }

    function performUpkeep(bytes calldata /* performData */) external onlyForwarder {
        voter.distributeAll();
    }

}
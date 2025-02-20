// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {Ownable} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import {BaseAutomation} from "./src_automation_BaseAutomation.sol";

import {currentEpoch, nextEpoch} from "./src_libraries_EpochMath.sol";
import {WrapperYieldDispatcher} from "./src_bribes_WrapperYieldDispatcher.sol";
import {PairYieldDispatcher} from "./src_pairs_PairYieldDispatcher.sol";
import {UniswapV3FullRangePair} from "./src_pairs_UniswapV3FullRangePair.sol";
import {IBasePoolFactory} from "./lib_balancer-v2-monorepo_pkg_interfaces_contracts_pool-utils_IBasePoolFactory.sol";
import {VoterV4} from "./src_VoterV4.sol";

contract DispatcherAutomation is BaseAutomation {

    mapping (address => uint32) public lastCalledEpoch; // pair/pool address  => last called epoch
    address public forwarder; // chainlink calls from this address
    VoterV4 public voter;
    IBasePoolFactory public factory;
    uint32 public dispatchingInterval; // seconds before the end of the epoch, dispatching begins
    WrapperYieldDispatcher public wrapperYieldDispatcher;
    PairYieldDispatcher public pairYieldDispatcher;

    constructor(address _voter, address _factory, uint32 _dispatchingInterval) Ownable(msg.sender) {
        voter = VoterV4(_voter);
        factory = IBasePoolFactory(_factory);
        dispatchingInterval = _dispatchingInterval;
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

    function setFactory(address _factory) external onlyOwner {
        factory = IBasePoolFactory(_factory);
    }

    function setDispatchers(address _wrapperYieldDispatcher, address _pairYieldDispatcher) external onlyOwner {
        wrapperYieldDispatcher = WrapperYieldDispatcher(_wrapperYieldDispatcher);
        pairYieldDispatcher = PairYieldDispatcher(_pairYieldDispatcher);
    }

    function setDispatchingInterval(uint32 _dispatchingInterval) external onlyOwner {
        dispatchingInterval = _dispatchingInterval;
    }

    function dispatchingStart() public view returns (uint32) {
        return dispatchingEnd() - dispatchingInterval;
    }

    function dispatchingEnd() public view returns (uint32) {
        return nextEpoch() - 1;
    }

    function checkUpkeep(bytes calldata /* checkData */) external cannotExecute returns (bool /* upkeepNeeded */, bytes memory /* performData */) {
        if (block.timestamp < dispatchingStart() || block.timestamp > dispatchingEnd()) {
            return (false, "");
        }

        for (uint i = 0; i < voter.poolsLength(); i++) {
            address pool = voter.pools(i);
            if (lastCalledEpoch[pool] == currentEpoch()) {
                continue;
            }

            bool isPool = factory.isPoolFromFactory(pool);
            return (true, abi.encode(pool, isPool));
        }

        return (false, "");
    }

    function performUpkeep(bytes calldata performData) external onlyForwarder {
        (address pool, bool isPool) = abi.decode(performData, (address, bool));

        if (block.timestamp < dispatchingStart() || block.timestamp > dispatchingEnd()) {
            revert ("Invalid dispatching time");
        }

        if (lastCalledEpoch[pool] == currentEpoch()) {
            revert ("Already called");
        }

        lastCalledEpoch[pool] = currentEpoch();
        if (isPool) {
            wrapperYieldDispatcher.dispatch(pool);
        } else {
            pairYieldDispatcher.dispatch(UniswapV3FullRangePair(pool));
        }
    }

}
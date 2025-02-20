// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import {OwnableUpgradeable} from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";

import {Bribe, Mode} from "./src_bribes_Bribe.sol";
import {IBribe} from "./src_interfaces_IBribe.sol";

error BribeFactory_AccessDenied(address sender);

contract BribeFactory is OwnableUpgradeable, UUPSUpgradeable {

    address[] public bribes;
    address public voter;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _voter, address _owner) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        voter = _voter;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {
    }

    /// @notice create a bribe contract
    function createBribe(
        address _owner,
        Mode mode,
        uint kind,
        address[] calldata rewardTokens
    )
        external
        returns (address)
    {
        if (msg.sender != voter && msg.sender != owner()) {
            revert BribeFactory_AccessDenied(msg.sender);
        }

        Bribe bribe = new Bribe(voter, _owner, mode, kind);

        for (uint i = 0; i < rewardTokens.length; i++) {
            bribe.addRewardToken(rewardTokens[i]);
        }

        bribes.push(address(bribe));
        return address(bribe);
    }

    function bribesLength() external view returns (uint) {
        return bribes.length;
    }


    /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    ONLY OWNER
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */


    /// @notice set the bribe factory voter
    function setVoter(address _Voter) external onlyOwner {
        require(_Voter != address(0));
        voter = _Voter;
    }
}
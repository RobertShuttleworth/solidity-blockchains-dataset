// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {AccessManagedUpgradeable} from "./openzeppelin_contracts-upgradeable_access_manager_AccessManagedUpgradeable.sol";
import {UUPSUpgradeable} from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import {MessagingFee} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_OApp.sol";
import {MessagingReceipt} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_OAppSender.sol";

import {AbraStakingRelay} from "./src_token_AbraStakingRelay.sol";
import {AbraStaking} from "./src_token_AbraStaking.sol";
import {VoterV4} from "./src_VoterV4.sol";

contract AutoMaxLock is AccessManagedUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    VoterV4 public immutable VOTER;
    IERC20 public immutable ABRA;
    AbraStaking public immutable ABRA_STAKING;
    uint256 public immutable MAX_STAKE_DURATION;

    mapping(uint32 eid => address peer) public peers;

    constructor(address _voter) {
        VOTER = VoterV4(_voter);
        ABRA_STAKING = AbraStaking(VOTER.ve());
        ABRA = ABRA_STAKING.abra();
        MAX_STAKE_DURATION = ABRA_STAKING.maxStakeDuration();
        _disableInitializers();
    }

    function initialize(address authority_) public initializer {
        __AccessManaged_init(authority_);
        __UUPSUpgradeable_init();
    }
    
    // @dev intentionally using `restricted` for internal function
    function _authorizeUpgrade(address) internal override restricted {}

    // keeps collected rewards on this contract
    function extendAll() external {
        uint256 lockupsLength = ABRA_STAKING.lockupsLength(address(this));
        for (uint256 i = 0; i < lockupsLength; i++) {
            AbraStaking.Lockup memory lockup = ABRA_STAKING.lockups(address(this), i);
            if (lockup.amount != 0) {
                _extend(i);
            }
        }
    }

    // keeps collected rewards on this contract
    function extend(uint256 lockupIndex) external {
        _extend(lockupIndex);
    }

    function setPeer(uint32 _eid, address _peer) external restricted {
        peers[_eid] = _peer;
    }

    function withdrawRewards(address receiver) external restricted {
        _withdrawRewards(receiver);
    }

    function refundRewards() external restricted {
        address rewardsSource = address(ABRA_STAKING.rewardsSource());
        _withdrawRewards(rewardsSource);
    }

    function previewRewards() external view returns (uint256) {
        uint256 rewards = ABRA_STAKING.previewRewards(address(this));
        uint256 balance = ABRA.balanceOf(address(this));
        return rewards + balance;
    }

    function vote(uint256 lockupIndex, address[] calldata _yieldSources, uint256[] calldata _weights)
        external
        restricted
    {
        _extend(lockupIndex);
        VOTER.vote(lockupIndex, _yieldSources, _weights);
    }

    function forward(uint256 lockupIndex, uint32 eid, bytes calldata options) external payable restricted {
        AbraStakingRelay abraStakingRelay = ABRA_STAKING.relay();
        abraStakingRelay.forward{value: msg.value}(lockupIndex, _getPeer(eid), eid, options);
    }

    function quoteForward(uint256 lockupIndex, uint32 eid, bytes calldata options)
        external
        view
        returns (MessagingFee memory msgFee)
    {
        AbraStakingRelay abraStakingRelay = ABRA_STAKING.relay();
        return abraStakingRelay.quoteForward(lockupIndex, _getPeer(eid), eid, options);
    }

    function _extend(uint256 lockupIndex) internal {
        ABRA_STAKING.extend(lockupIndex, MAX_STAKE_DURATION);
    }

    function _getPeer(uint32 eid) internal view returns (address) {
        address _peer = peers[eid];
        if (_peer == address(0)) {
            revert("Undefined peer");
        }

        return _peer;
    }

    function _withdrawRewards(address receiver) internal {
        ABRA_STAKING.collectRewards();

        uint256 balance = ABRA.balanceOf(address(this));
        if (balance > 0) {
            ABRA.safeTransfer(receiver, balance);
        }
    }
}
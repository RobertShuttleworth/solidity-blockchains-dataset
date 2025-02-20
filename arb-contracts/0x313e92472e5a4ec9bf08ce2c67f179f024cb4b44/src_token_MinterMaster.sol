// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IMessagingChannel} from "./node_modules_layerzerolabs_lz-evm-protocol-v2_contracts_interfaces_IMessagingChannel.sol";
import {OApp, Origin, MessagingFee} from "./node_modules_layerzerolabs_lz-evm-oapp-v2_contracts_oapp_OApp.sol";
import {SendParam} from "./node_modules_layerzerolabs_lz-evm-oapp-v2_contracts_oft_interfaces_IOFT.sol";
import {AddressCast} from "./node_modules_layerzerolabs_lz-evm-protocol-v2_contracts_libs_AddressCast.sol";

import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {EnumerableSet} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_structs_EnumerableSet.sol";
import {Ownable} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_access_Ownable.sol";

import {Abra} from "./src_token_Abra.sol";
import {AbraStaking} from "./src_token_AbraStaking.sol";
import {OFTMediator} from "./src_token_OFTMediator.sol";
import {MinterUpgradeable} from "./src_token_MinterUpgradeable.sol";
import {currentEpoch, previousEpoch, WEEK} from "./src_libraries_EpochMath.sol";
import {VoterV4} from "./src_VoterV4.sol";

struct EpochReport {
    uint32  epoch;
    uint224 points; // vote power per network at the last checkpoint before the new epoch
    uint256 pointsCasted;
    uint128 locked; // number of abra tokens locked per network at the last checkpoint before the new epoch
    uint128 supply; // supply of abra tokens locked per network at the last checkpoint before the new epoch
}

struct Round {
    EpochReport report;
    bool    transmitted; // whether this chains's emission was sent or not
    uint112 gauges;     // amount of tokens emmited to a chain for gauges
    uint112 rebase;     // part of the emission that goes to the rebase
}

struct Emission {
    uint32  epoch;
    uint112 gauges;     // amount of tokens emmited to a chain for gauges
    uint112 rebase;     // part of the emission that goes to the rebase
}

struct RoundResponse {
    Emission emission;
}

struct EmissionPartition {
    uint gauges;
    uint rebase;
    uint core;
    uint team;
    uint affiliate;
    uint holderBonus;
}


error MinterMaster_AlreadyClosed(uint256 epoch);
error MinterMaster_AlreadyReported(uint epoch, uint32 srcEid, address sender, uint currentPoints, uint reportedPoints);
error MinterMaster_AlreadySettled();
error MinterMaster_AlreadyTransmitted(uint epoch, uint32 srcEid);
error MinterMaster_InvalidEpoch(uint256 expectedEpoch, uint256 receivedEpoch, uint32 srcEid, address sender);
error MinterMaster_NotReported(uint256 epoch, uint32 srcEid);
error MinterMaster_NotClosed(uint256 epoch);
error MinterMaster_NotEnoughFee(uint expectedFee, uint providedFee);


uint256 constant PRECISION = 1e18;
uint256 constant INCENTIVES_MIN = PRECISION * 43 / 100; // 43%

// 10 -> core contrib & grants
// 5  -> team
// 43 -> strategies
// 23 -> rebase
// 12 -> referral
// 7  -> holder bonus

contract MinterMaster is OApp {

    using EnumerableSet for EnumerableSet.UintSet;
    using AddressCast for bytes32;

    Abra    public immutable ABRA;
    VoterV4 public immutable VOTER;
    AbraStaking public immutable VE;

    MinterUpgradeable public minter;
    OFTMediator public mediator;

    address public core;
    address public team;
    address public affiliate;
    address public holderBonus;
    address public rewardSource;

    uint256 public rebaseLimit    = PRECISION * 23/100; // 23%
    uint256 public coreShare      = PRECISION * 10/100; // 10%
    uint256 public teamShare      = PRECISION *  5/100; //  5%
    uint256 public affiliateShare = PRECISION * 12/100; // 12%
    uint256 public hbShare        = PRECISION *  7/100; //  7%

    EnumerableSet.UintSet private eids;
    mapping(uint256 epoch => mapping(uint256 eid => Round)) private rounds;

    event EmissionAllocated(
        uint32 indexed epoch,
        uint256 gauges,
        uint256 rebase,
        uint256 core,
        uint256 team,
        uint256 affiliate,
        uint256 holderBonus
    );

    constructor(
        OFTMediator _mediator,
        MinterUpgradeable _minter,
        VoterV4 voter,
        address _core,
        address _team,
        address _affiliate,
        address _holderBonus,
        address _owner
    )
        OApp(address(_mediator.endpoint()), _owner)
        Ownable(_owner)
    {
        mediator  = _mediator;
        minter    = _minter;
        core      = _core;
        team      = _team;
        affiliate = _affiliate;
        holderBonus = _holderBonus;
        ABRA = Abra(mediator.token());
        VOTER = voter;
        VE = AbraStaking(voter.ve());
        rewardSource = address(VE.rewardsSource());
    }


    // struct Origin {
    //     uint32 srcEid;
    //     bytes32 sender;
    //     uint64 nonce;
    // }
    function _lzReceive(
        Origin calldata _origin, // struct containing info about the message sender
        bytes32, //_guid, // global packet identifier
        bytes calldata payload, // encoded message payload being received
        address, // _executor, // the Executor address.
        bytes calldata // _extraData // arbitrary data appended by the Executor
    ) internal override {
        EpochReport memory report = abi.decode(payload, (EpochReport));
        _receiveReport(_origin.srcEid, _origin.sender.toAddress(), report);
    }

    function _receiveReport(uint32 eid, address sender, EpochReport memory report) internal {
        // [1]. Validate that epoch has 7 day difference with the current one
        if (report.epoch > previousEpoch()) {
            revert MinterMaster_InvalidEpoch(previousEpoch(), report.epoch, eid, sender);
        }

        EpochReport memory prevReport = rounds[report.epoch][eid].report;
        // [2]. Validate that the epoch is not already reported
        if (prevReport.epoch > 0) {
            revert MinterMaster_AlreadyReported(report.epoch, eid, sender, prevReport.points, report.points);
        }

        rounds[report.epoch][eid] = Round({
            report: report,
            transmitted: false,
            gauges: 0,
            rebase: 0
        });
    }

    function _reportLocal(uint32 _openEpoch) internal view returns (EpochReport memory) {
        return EpochReport({
            epoch: _openEpoch,
            points: uint224(VE.getPastTotalSupply(_openEpoch + WEEK - 1)),
            pointsCasted: VOTER.totalWeightAt(_openEpoch),
            locked: uint128(VE.lockedSupplyCheckpoints(_openEpoch)),
            supply: ABRA.supplyCheckpoints(_openEpoch)
        });
    }

    struct RoundTotals {
        uint points;
        uint casted;
        uint abraLocked;
        uint supply;
    }

    function closeRound()
        external
        returns (uint32 epoch, uint112 localGauges, uint112 localRebase, EmissionPartition memory parts)
    {
        epoch = minter.openEpoch();
        if (epoch >= currentEpoch()) revert MinterMaster_AlreadyClosed(epoch);

        // [1]. Calculate total votes casted across all networks
        uint l = eids.length();
        RoundTotals memory total;

        for (uint256 i = 0; i < l; i++) {
            uint32 eid = uint32(eids.at(i));
            EpochReport memory report = rounds[epoch][eid].report;
            // ALL current registered networks must send reports to close the current round
            if (report.epoch == 0) {
                revert MinterMaster_NotReported(epoch, eid);
            }
            total.points     += report.points;
            total.casted     += report.pointsCasted;
            total.abraLocked += report.locked;
            total.supply     += report.supply;
        }

        // [1.1] Add up local stat
        EpochReport memory localReport = _reportLocal(epoch);
        total.points     += localReport.points;
        total.casted     += localReport.pointsCasted;
        total.abraLocked += localReport.locked;
        total.supply     += localReport.supply;

        // [1.2] Prevent division by zero if we have no votes or 0 locked tokens in this epoch.
        //       All divisions will yield 0, so the value doesn't really matter
        if (total.points == 0) total.points = 1;
        if (total.casted == 0) total.casted = 1;

        // [2]. Mint new tokens
        uint minted = minter.mint(address(this));
        parts.rebase = calculateRebase(minted, total.abraLocked, total.supply);
        parts.core        = minted * coreShare / PRECISION;
        parts.team        = minted * teamShare / PRECISION;
        parts.affiliate   = minted * affiliateShare / PRECISION;
        parts.holderBonus = minted * hbShare / PRECISION;
        parts.gauges = minted - parts.rebase - parts.core - parts.team - parts.affiliate - parts.holderBonus;

        emit EmissionAllocated(
            epoch, parts.gauges, parts.rebase, parts.core, parts.team, parts.affiliate, parts.holderBonus
        );

        // [3]. Transfer shares
        ABRA.transfer(core, parts.core);
        ABRA.transfer(team, parts.team);
        ABRA.transfer(affiliate, parts.affiliate);
        ABRA.transfer(holderBonus, parts.holderBonus);

        // [4]. Calculate distribution of minted tokens to each networks pro-rata
        for (uint256 i = 0; i < l; i++) {
            uint32 eid = uint32(eids.at(i));
            rounds[epoch][eid].gauges = uint112(parts.gauges * rounds[epoch][eid].report.pointsCasted / total.casted);
            rounds[epoch][eid].rebase = uint112(parts.rebase * rounds[epoch][eid].report.points / total.points);
        }

        // [5]. Calculate and distribute local emission;
        localGauges = uint112(parts.gauges * localReport.pointsCasted / total.casted);
        localRebase = uint112(parts.rebase * localReport.points / total.points);

        // push local report
        rounds[epoch][IMessagingChannel(endpoint).eid()] = Round({
            report: localReport,
            transmitted: true,
            gauges: localGauges,
            rebase: localRebase
        });

        // manually create a checkpoint for the locked supply in case if no-one will lock/unlock this week
        VE.checkpointLockedSupply();

        ABRA.approve(address(VOTER), localGauges);
        VOTER.notifyRewardAmount(localGauges);

        ABRA.transfer(rewardSource, localRebase);
    }

    function _getTransmitSendParams(
        uint32 eid,
        uint amount,
        bytes calldata options
    ) internal view returns (SendParam memory) {
        return SendParam({
            dstEid: eid, // Destination endpoint ID.
            to: peers[eid], // Recipient address.
            amountLD: amount, // Amount to send in local decimals.
            minAmountLD: amount, // Minimum amount to send in local decimals.
            extraOptions: options, // Additional options supplied by the caller to be used in the LayerZero message.
            composeMsg: new bytes(0), // The composed message for the send() operation.
            oftCmd: new bytes(0) // The OFT command to be executed, unused in default OFT implementations.
        });
    }

    function quoteSendEmission(
        uint32 epoch,
        uint32 eid,
        bytes calldata options
    ) external view returns (MessagingFee memory msgFee) {
        (uint128 gauges, uint128 rebase) = (rounds[epoch][eid].gauges, rounds[epoch][eid].rebase);
        uint amount = mediator.removeDust(gauges + rebase);

        SendParam memory sendParam = _getTransmitSendParams(eid, amount, options);
        return mediator.quoteSend(sendParam, false);
    }

    function quoteSendRoundResponse(
        uint32 epoch,
        uint32 eid,
        bytes calldata options
    ) external view returns (MessagingFee memory msgFee) {
        (uint112 gauges, uint112 rebase) = (rounds[epoch][eid].gauges, rounds[epoch][eid].rebase);
        RoundResponse memory response = RoundResponse({
            emission: Emission({
                epoch: epoch,
                gauges: gauges,
                rebase: rebase
            })
        });
        bytes memory message = abi.encode(response);
        return _quote(eid, message, options, false);
    }

    function transmit(
        uint32 epoch,
        uint32 eid,
        uint sendTokenFee,
        uint sendResponseFee,
        bytes calldata sendTokenOptions,
        bytes calldata sendResponseOptions
    ) external payable returns (uint112 gauges, uint112 rebase) {
        if (epoch >= minter.openEpoch()) {
            revert MinterMaster_NotClosed(epoch);
        }
        if (rounds[epoch][eid].transmitted == true) {
            revert MinterMaster_AlreadyTransmitted(epoch, eid);
        }
        if (msg.value < (sendTokenFee + sendResponseFee)) {
            revert MinterMaster_NotEnoughFee((sendTokenFee + sendResponseFee), msg.value);
        }
        rounds[epoch][eid].transmitted = true;
        (gauges, rebase) = (rounds[epoch][eid].gauges, rounds[epoch][eid].rebase);
        uint112 amount = uint112(mediator.removeDust(gauges + rebase));
        // since we've lowered the send amount through dust removal, we need to adjust the numbers (by lowering them)
        // in the round response, keeping in mind that some of the numbers may be 0
        if (amount == 0) {
            (gauges, rebase) = (0, 0);
        } else if (gauges > rebase) {
            gauges = amount - rebase;
        } else {
            rebase = amount - gauges;
        }

        {
            SendParam memory sendParam = _getTransmitSendParams(eid, amount, sendTokenOptions);
            MessagingFee memory tokenFee = MessagingFee({
                nativeFee: sendTokenFee,
                lzTokenFee: 0
            });

            ABRA.approve(address(mediator), sendParam.amountLD);
            mediator.send{value: sendTokenFee}(sendParam, tokenFee, msg.sender);
        }

        RoundResponse memory response = RoundResponse({
            emission: Emission({
                epoch: epoch,
                gauges: gauges,
                rebase: rebase
            })
        });
        // println("round-response eid={u} epoch={u} gauges={u:d18} rebase={u:d18}", abi.encode(eid, epoch, gauges, rebase));
        MessagingFee memory responseFee = MessagingFee({
            nativeFee: sendResponseFee,
            lzTokenFee: 0
        });
        bytes memory message = abi.encode(response);

        _lzSend(eid, message, sendResponseOptions, responseFee, msg.sender);
    }

    /// We need to be able to iterate over the eids and peers
    function _setPeer(uint32 _eid, bytes32 _peer) internal override {
        if (_peer == bytes32(0)) {
            eids.remove(_eid);
        } else {
            eids.add(_eid);
        }
        super._setPeer(_eid, _peer);
    }

    function _payNative(uint256 _nativeFee) internal override returns (uint256 nativeFee) {
        if (msg.value < _nativeFee) revert NotEnoughNative(msg.value);
        return _nativeFee;
    }

    function calculateRebase(uint weeklyMint, uint totalLocked, uint totalSupply) internal view returns (uint) {
        uint lockedShare = totalLocked * PRECISION  / totalSupply;
        if(lockedShare >= rebaseLimit){
            return weeklyMint * rebaseLimit / PRECISION;
        } else {
            return weeklyMint * lockedShare / PRECISION;
        }
    }

    // ----------------------------------------------- setters -----------------------------------------------

    function setMinter(MinterUpgradeable _minter) external onlyOwner {
        minter = _minter;
    }

    function setMediator(OFTMediator _mediator) external onlyOwner {
        mediator = _mediator;
    }

    function setCore(address _core) external onlyOwner {
        core = _core;
    }

    function setTeam(address _team) external onlyOwner {
        team = _team;
    }

    function setAffiliate(address _affiliate) external onlyOwner {
        affiliate = _affiliate;
    }

    function setHolderBonus(address _holderBonus) external onlyOwner {
        holderBonus = _holderBonus;
    }

    function setRewardSource(address _rewardSource) external onlyOwner {
        rewardSource = _rewardSource;
    }

    function setEmissionShares(
        uint256 _rebaseLimit,
        uint256 _coreShare,
        uint256 _teamShare,
        uint256 _affiliateShare,
        uint256 _hbSHare
    ) external onlyOwner {
        uint256 sum = _rebaseLimit + _coreShare + _teamShare + _affiliateShare + _hbSHare;
        require(INCENTIVES_MIN + sum <= PRECISION);

        rebaseLimit = _rebaseLimit;
        coreShare = _coreShare;
        teamShare = _teamShare;
        affiliateShare = _affiliateShare;
        hbShare = _hbSHare;
    }

    // ----------------------------------------------- getters -----------------------------------------------
    function getRound(uint32 epoch, uint32 eid) external view returns (Round memory) {
        return rounds[epoch][eid];
    }

    function eidsLength() external view returns (uint) {
        return eids.length();
    }

    function getEidAt(uint at) external view returns (uint32) {
        return uint32(eids.at(at));
    }
}
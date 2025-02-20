// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {AccessManagedUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_access_manager_AccessManagedUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";

import {AbraStaking} from "./src_token_AbraStaking.sol";

import {IGauge} from './src_interfaces_IGauge.sol';
import {IBribe} from './src_interfaces_IBribe.sol';
import {IEpochController} from './src_interfaces_IEpochController.sol';
import {currentEpoch, previousEpoch, nextEpoch, WEEK} from "./src_libraries_EpochMath.sol";

struct LockupVote {
    address ys;
    uint    vote;
}

contract VoterV4 is AccessManagedUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {

    address public immutable base;                             // ABRA token
    address public immutable ve;                               // the ve token that governs these contracts
    address public epochController;                            // minter mints ABRA each epoch
    address public emissionDistributor;

    // this array can have duplicated data in the future when we will add ability to kill gauges
    address[] public pools;                                        // all strategies or liquidity pools viable for incentives (not ys)

    uint256 public index;                                        // gauge index

    mapping(address => uint256) public supplyIndex;               // gauge    => index
    mapping(address => uint256) public claimable;                  // gauge    => claimable ABRA
    mapping(address => address) public gauges;                     // pool/ys  => gauge
    mapping(address => uint256) public gaugesDistributionTimestamp;// gauge    => last Distribution Time

    mapping(address => address) public internalBribes;            // pool/ys    => internal bribe (only fees)
    mapping(address => address) public externalBribes;            // pool/ys    => external bribe (real bribes)

    mapping(uint256 => mapping(address => uint256)) public votes;  // lockupId   => pool     => votes                       only used to recast votes, reset before a new vote
    mapping(uint256 => address[]) public poolVote;                 // lockupId   => pools

    mapping(uint256 => mapping(address => uint256)) public   weightsPerEpoch; // timestamp => GAUGE => weights
    mapping(uint256 => mapping(address => uint256)) public   ysVotesPerEpoch; // timestamp => YS    => weights
    mapping(uint256 => uint256) internal totalWeightsPerEpoch;     // timestamp => total weights

    mapping(uint256 => uint256) public lastVoted;               // lockupId => timestamp of last vote
    mapping(address => bool) public isGauge;                    // gauge    => boolean [is a gauge?]
    mapping(address => bool) public isAlive;                    // gauge    => boolean [is the gauge alive?]
    mapping(uint256 => bool) public voted;                      // lockupId => has_voted?

    event GaugeAdded(
        address indexed gauge,
        address indexed underlying,
        address creator,
        address[] yieldSources,
        address[] internalBribes,
        address[] externalBribes
    );
    event YieldSourceAdded(
        address indexed gauge,
        address indexed underlying,
        address creator,
        address yieldSource,
        address internalBribe,
        address externalBribe
    );
    event Voted(address indexed voter, uint256 lockupId, uint256 weight, address yieldSource);
    event Reset(uint256 lockupId);
    event NotifyReward(address indexed sender, address indexed rewardToken, uint256 amount);
    event DistributeReward(address indexed sender, address indexed gauge, uint256 amount);

    error VoterV4_LengthMismatch(uint expectedLength);
    error VoterV4_InvalidGauge(address ys, address currentGauge, address newGauge);
    error VoterV4_BribeExists(address ys, address currentBribe, address newBribe);

    constructor(address _ve) {
        ve = _ve;
        base = address(AbraStaking(_ve).abra());
        _disableInitializers();
    }

    function initialize(
        address _epochController,
        address _emissionDistributor,
        address authority_
    )
        public
        initializer
    {
        epochController = _epochController;
        emissionDistributor = _emissionDistributor;

        __AccessManaged_init(authority_);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    /// @dev intentionally using `restricted` for internal function
    function _authorizeUpgrade(address) internal override restricted {
    }

    function setEpochController(address _epochController) external restricted {
        epochController = _epochController;
    }

    function setEmissionDistributor(address _emissionDistributor) external restricted {
        emissionDistributor = _emissionDistributor;
    }

    /// @notice Reset the votes of a given TokenID
    function reset(uint256 lockupIndex) external nonReentrant {
        AbraStaking.Lockup memory lockup = AbraStaking(ve).lockups(msg.sender, lockupIndex);
        // FIXME: should be nextEpoch() + WEEK
        require(lockup.end >= nextEpoch(), "lockup expires");
        _reset(lockup.id);
        _abstain(lockup.id);
        lastVoted[lockup.id] = currentEpoch() + 1;
    }

    function _reset(uint256 lockupId) internal {
        address[] storage _poolVote = poolVote[lockupId];
        uint256 _poolVoteCnt = _poolVote.length;
        uint256 _totalWeight = 0;
        uint256 _time = currentEpoch();
        uint256 _lastVoted = lastVoted[lockupId];

        for (uint256 i = 0; i < _poolVoteCnt; i ++) {
            address _ys = _poolVote[i];
            uint256 _votes = votes[lockupId][_ys];

            if (_votes != 0) {
                address _gauge = gauges[_ys];
                // if user last vote is < than epochTimestamp then votes are 0! IF not underflow occur
                if (_lastVoted > _time) {
                    weightsPerEpoch[_time][_gauge] -= _votes;
                    ysVotesPerEpoch[_time][_ys] -= _votes;
                }

                votes[lockupId][_ys] -= _votes;

                IBribe(internalBribes[_ys]).withdraw(_votes, lockupId);
                IBribe(externalBribes[_ys]).withdraw(_votes, lockupId);

                // if is alive remove _votes, else don't because we already done it in killGauge()
                // NOTE: currently we don't have killGauge() implemented yet
                if(isAlive[_gauge]) _totalWeight += _votes;
            }
        }

        emit Reset(lockupId);

        // if user last vote is < than epochTimestamp then _totalWeight is 0! IF not underflow occur
        if(_lastVoted < _time) _totalWeight = 0;

        totalWeightsPerEpoch[_time] -= _totalWeight;
        delete poolVote[lockupId];
    }


    /// @notice Vote for pools
    /// @param  _yieldSources  array of addresses to vote, i.e. wrappers or
    /// @param  _weights    array of weights for each LPs   (eg.: [10               , 90            , 45             ,...])
    function vote(uint256 lockupIndex, address[] calldata _yieldSources, uint256[] calldata _weights) external nonReentrant {
        AbraStaking.Lockup memory lockup = AbraStaking(ve).lockups(msg.sender, lockupIndex);
        require(lockup.end >= nextEpoch(), "lockup expires");
        require(_yieldSources.length == _weights.length, "Pool/Weights length !=");

        _vote(lockup, _yieldSources, _weights);
        lastVoted[lockup.id] = currentEpoch() + 1;
    }

    function _vote(AbraStaking.Lockup memory lockup, address[] memory _yieldSources, uint256[] memory _weights) internal {
        _reset(lockup.id);
        uint256 _poolCnt = _yieldSources.length;
        uint256 _weight = lockup.points;
        uint256 _totalVoteWeight = 0;
        uint256 _totalWeight = 0;
        uint256 _usedWeight = 0;
        uint256 _time = currentEpoch();

        for (uint i = 0; i < _poolCnt; i++) {
            if(isAlive[gauges[_yieldSources[i]]]) _totalVoteWeight += _weights[i];
        }

        for (uint256 i = 0; i < _poolCnt; i++) {
            address _ys = _yieldSources[i];
            address _gauge = gauges[_ys];

            if (isAlive[_gauge]) {
                uint256 _poolWeight = _weights[i] * _weight / _totalVoteWeight;

                require(votes[lockup.id][_ys] == 0, "v0");
                require(_poolWeight != 0, "p0");

                poolVote[lockup.id].push(_ys);
                weightsPerEpoch[_time][_gauge] += _poolWeight;
                ysVotesPerEpoch[_time][_ys] += _poolWeight;

                votes[lockup.id][_ys] += _poolWeight;
                IBribe(internalBribes[_ys]).deposit(_poolWeight, lockup.id);
                IBribe(externalBribes[_ys]).deposit(_poolWeight, lockup.id);

                _usedWeight += _poolWeight;
                _totalWeight += _poolWeight;
                emit Voted(msg.sender, lockup.id, _poolWeight, _ys);
            }
        }

        if (_usedWeight > 0) _voting(lockup.id);
        totalWeightsPerEpoch[_time] += _totalWeight;
    }


    function addGauge(
        address gauge,
        address[] calldata _internalBribes,
        address[] calldata _externalBribes
    )
        external
        restricted
    {
        address pool = IGauge(gauge).underlying();
        // if gauge already exists
        if (gauges[pool] != address(0x0)) {
            revert VoterV4_InvalidGauge(address(0x0), gauges[pool], gauge);
        }

        // In case of non strategy gauges (i.e. AMM pools with ABRA) gauge.underlying() == gauge.yieldSources()
        // i.e. there is one yield source: the pool itself
        address[] memory _ysources = IGauge(gauge).yieldSources();
        if (_ysources.length != _externalBribes.length || _ysources.length != _internalBribes.length) {
            revert VoterV4_LengthMismatch(_ysources.length);
        }

        for (uint i=0; i < _ysources.length; i++) {
            gauges[_ysources[i]] = gauge;
            internalBribes[_ysources[i]] = _internalBribes[i];
            externalBribes[_ysources[i]] = _externalBribes[i];
        }

        // approve spending for $ABRA
        IERC20(base).approve(gauge, type(uint256).max);

        gauges[pool] = gauge; // we still add strategy to the gauges mapping to keep the contract code consistent
        isGauge[gauge] = true;
        isAlive[gauge] = true;
        pools.push(pool);

        // update index
        supplyIndex[gauge] = index; // new gauges are set to the default global state

        emit GaugeAdded(gauge, pool, msg.sender, _ysources, _internalBribes, _externalBribes);
    }

    function addYieldSource(
        address _gauge,
        address _ys,
        address _internalBribe,
        address _externalBribe
    )
        external
        restricted
    {
        address _pool = IGauge(_gauge).underlying();
        address _existingGauge = gauges[_pool];

        // if a gauge for this pool exists and it's not the same as the gauge we supplied.
        // Prevents the case when we accidentially created a new gauge with the same underlying and trying to add it
        if (_existingGauge == address(0x0) || _existingGauge != _gauge) {
            revert VoterV4_InvalidGauge(_ys, _existingGauge, _gauge);
        }

        _existingGauge = gauges[_ys];
        // if a gauge for this ys exists it means that bribes exist too
        if (_existingGauge != address(0x0)) {
            revert VoterV4_InvalidGauge(_ys, _existingGauge, _gauge);
        }

        gauges[_ys] = _gauge;
        externalBribes[_ys] = _externalBribe;
        internalBribes[_ys] = _internalBribe;

        emit YieldSourceAdded(_existingGauge, _pool, msg.sender, _ys, _internalBribe, _externalBribe);
    }


    /// Removes yield source from voting. Removing yield source does not erase votes on the gauge.
    /// When yield source is removed users are expected to recast their votes (if they will).
    // function removeYieldSource(address _ys) external restricted {
    //     delete gauges[_ys];
    // }


    function totalWeightAt(uint256 _time) public virtual view returns(uint256) {
        return totalWeightsPerEpoch[_time];
    }

    function poolsLength() external view returns(uint) {
        return pools.length;
    }

    /// @notice notify reward amount for gauge
    /// @dev    the function is called by the minter each epoch when we call Voter's distribute functions.
    /// @param  amount  amount to distribute
    function notifyRewardAmount(uint256 amount) external {
        require(msg.sender == emissionDistributor, "!ed");
        IERC20(base).transferFrom(msg.sender, address(this), amount);

        uint256 _totalWeight = totalWeightAt(previousEpoch());   // minter call notify after updates active_period, loads votes - 1 week

        uint256 _ratio = 0;

        if(_totalWeight > 0) _ratio = amount * 1e18 / _totalWeight;     // 1e18 adjustment is removed during claim
        if (_ratio > 0) {
            index += _ratio;
        }

        emit NotifyReward(msg.sender, base, amount);
    }



    /// @notice Distribute the emission for ALL gauges
    function distributeAll() external nonReentrant {
        uint256 x = 0;
        uint256 stop = pools.length;
        for (x; x < stop; x++) {
            _distribute(gauges[pools[x]]);
        }
    }


    /// @notice distribute reward only for given gauges
    /// @dev    this function is used in case some distribution fails
    function distribute(address[] memory _gauges) external nonReentrant {
        for (uint256 x = 0; x < _gauges.length; x++) {
            _distribute(_gauges[x]);
        }
    }

    /// @notice distribute the emission
    function _distribute(address _gauge) internal {
        uint256 lastDistributionTimestamp = gaugesDistributionTimestamp[_gauge];
        uint256 openEpoch = IEpochController(epochController).openEpoch();

        if(lastDistributionTimestamp < openEpoch) {
            _updateForAfterDistribution(_gauge); // should set claimable to 0 if killed

            uint256 _claimable = claimable[_gauge];

            // distribute only if claimable is > 0, currentEpoch != lastepoch and gauge is alive
            if (_claimable > 0 && isAlive[_gauge]) {
                claimable[_gauge] = 0;
                gaugesDistributionTimestamp[_gauge] = openEpoch;
                IGauge(_gauge).notifyRewardAmount(_claimable);
                emit DistributeReward(msg.sender, _gauge, _claimable);
            }
        }
    }


    /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    HELPERS
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */


    /// @notice update info for gauges
    /// @dev    this function track the gauge index to emit the correct ABRA amount after the distribution
    function _updateForAfterDistribution(address _gauge) private {
        uint256 _time = previousEpoch();
        uint256 _supplied = weightsPerEpoch[_time][_gauge];

        if (_supplied > 0) {
            uint256 _supplyIndex = supplyIndex[_gauge];
            uint256 _index = index; // get global index0 for accumulated distro
            supplyIndex[_gauge] = _index; // update _gauge current position to global position
            uint256 _delta = _index - _supplyIndex; // see if there is any difference that need to be accrued
            if (_delta > 0) {
                uint256 _share = _supplied * _delta / 1e18; // add accrued difference for each supplied token
                if (isAlive[_gauge]) {
                    claimable[_gauge] += _share;
                }
            }
        } else {
            supplyIndex[_gauge] = index; // new users are set to the default global state
        }
    }

    function _abstain(uint256 lockupId) internal {
        voted[lockupId] = false;
    }

    function _voting(uint256 lockupId) internal {
        voted[lockupId] = true;
    }

    /// for off-chain use
    /// @param lockupId Lockup Id
    function lockupVotes(uint lockupId) external view returns (LockupVote[] memory lv) {
        address[] memory _votes = poolVote[lockupId];
        lv = new LockupVote[](_votes.length);

        for (uint i = 0; i < _votes.length; i++) {
            address ys = poolVote[lockupId][i];
            lv[i] = LockupVote(ys, votes[lockupId][ys]);
        }
    }
}
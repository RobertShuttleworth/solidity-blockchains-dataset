// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "./src_const_Constants.sol";
import {wmul} from "./src_utils_Math.sol";
import {GoatX} from "./src_GoatX.sol";
import {Errors} from "./src_utils_Errors.sol";
import {GoatFeed} from "./src_GoatFeed.sol";
import {IERC20} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";

struct DailyStatistic {
    uint256 goatXEmitted;
    uint256 titanXDeposited;
}

struct UserAuction {
    uint32 ts;
    uint32 day;
    uint256 amount;
}

/**
 * @title GoatXAuction
 * @author Decentra
 */
contract GoatXAuction is Errors {
    using SafeERC20 for IERC20;

    GoatX immutable goatX;
    IERC20 immutable titanX;

    uint32 public immutable startTimestamp;
    address immutable titanXStakingVault;

    uint64 depositId;

    mapping(address => mapping(uint64 id => UserAuction)) public depositOf;
    mapping(uint32 day => DailyStatistic) public dailyStats;

    error OnlyClaimableAfter24Hours();
    error NotStartedYet();
    error NothingToClaim();
    error NothingToEmit();

    //=========EVENTS==========//

    event UserDeposit(address indexed user, uint256 indexed amount, uint64 indexed id);
    event UserClaimed(address indexed user, uint256 indexed goatXAmount, uint64 indexed id);

    constructor(address _titanX, GoatX _goatX, uint32 _startTimestamp) {
        require((_startTimestamp % 86400) == 50400, "_startTimestamp must be 2PM UTC");

        titanX = IERC20(_titanX);
        goatX = GoatX(_goatX);

        startTimestamp = _startTimestamp;
    }

    function deposit(uint256 _amount) external notAmount0(_amount) {
        require(block.timestamp >= startTimestamp, NotStartedYet());

        _updateAuction();

        uint32 _daySinceStart = daySinceStart();

        UserAuction storage userDeposit = depositOf[msg.sender][++depositId];

        DailyStatistic storage stats = dailyStats[_daySinceStart];

        userDeposit.ts = uint32(block.timestamp);
        userDeposit.amount = _amount;
        userDeposit.day = _daySinceStart;

        stats.titanXDeposited += uint256(_amount);

        titanX.transferFrom(msg.sender, address(this), _amount);

        _distribute(_amount);

        emit UserDeposit(msg.sender, _amount, depositId);
    }

    function claim(uint64 _id) public {
        UserAuction storage userDep = depositOf[msg.sender][_id];

        require(block.timestamp >= userDep.ts + 24 hours, OnlyClaimableAfter24Hours());

        uint256 toClaim = amountToClaim(msg.sender, _id);

        if (toClaim == 0) revert NothingToClaim();

        emit UserClaimed(msg.sender, toClaim, _id);

        goatX.transfer(msg.sender, toClaim);

        userDep.amount = 0;
    }

    function batchClaim(uint32[] calldata _ids) external {
        for (uint256 i; i < _ids.length; ++i) {
            claim(_ids[i]);
        }
    }

    function batchClaimableAmount(address _user, uint32[] calldata _ids) public view returns (uint256 toClaim) {
        for (uint256 i; i < _ids.length; ++i) {
            toClaim += amountToClaim(_user, _ids[i]);
        }
    }

    function amountToClaim(address _user, uint64 _id) public view returns (uint256 toClaim) {
        UserAuction storage userDep = depositOf[_user][_id];
        DailyStatistic memory stats = dailyStats[userDep.day];

        return (uint256(userDep.amount) * uint256(stats.goatXEmitted)) / uint256(stats.titanXDeposited);
    }

    function _distribute(uint256 _amount) internal {
        titanX.transfer(address(goatX.buyAndBurn()), wmul(_amount, uint256(0.38e18)));

        {
            uint256 toAuctionBuy = wmul(_amount, uint256(0.3e18));
            titanX.approve(address(goatX.auctionBuy()), toAuctionBuy);
            goatX.auctionBuy().distribute(toAuctionBuy);
        }

        titanX.transfer(Constants.LIQUIDITY_BONDING, wmul(_amount, uint256(0.08e18)));
        titanX.transfer(Constants.PHOENIX_TITANX_STAKE, wmul(_amount, uint256(0.04e18)));
        titanX.transfer(Constants.POOL_AND_BURN, wmul(_amount, uint256(0.04e18)));
        titanX.transfer(Constants.INFERNO_BNB_V2, wmul(_amount, uint256(0.08e18)));
        titanX.transfer(Constants.GENESIS, wmul(_amount, uint256(0.02e18)));
        titanX.transfer(Constants.GENESIS_2, wmul(_amount, uint256(0.06e18)));
    }

    function emittedToday() external view returns (uint256 emitted) {
        emitted = dailyStats[daySinceStart()].goatXEmitted;

        if (emitted == 0) {
            address feed = address(goatX.goatFeed());
            emitted = wmul(goatX.balanceOf(feed), Constants.GOAT_FEED_DISTRO);
        }
    }

    function daySinceStart() public view returns (uint32 _daySinceStart) {
        _daySinceStart = uint32(((block.timestamp - startTimestamp) / 24 hours) + 1);
    }

    /// @notice Emits the needed GoatX
    function _updateAuction() internal {
        uint32 _daySinceStart = daySinceStart();

        if (dailyStats[_daySinceStart].goatXEmitted != 0) return;

        uint256 toEmit = GoatFeed(goatX.goatFeed()).emitForAuction();

        require(toEmit != 0, NothingToEmit());

        dailyStats[_daySinceStart].goatXEmitted = uint256(toEmit);
    }
}
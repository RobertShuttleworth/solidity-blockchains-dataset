// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {LibAppStorage} from "./src_diamond_libraries_LibAppStorage.sol";
import {AppStorage} from "./src_AppStorage.sol";
import {Village, VillageReward} from "./src_AppStorage.sol";
import {console} from "./lib_forge-std_src_Test.sol";
import {VillagersLibrary} from "./src_libraries_VillagersLibrary.sol";

library RewardLibrary {
    uint256 constant PRECISION = 1 ether;

    event SetRewardsSwitch(
        uint256 blockTimeSwitchToNewRewards,
        uint256 totalVillageScoreAtSwitch,
        uint256 balanceAtSwitch
    );
    event OnReceive(uint256 newEthAccPerScore);
    event RedeemRewards(uint256 tokenId, address owner, uint256 rewardAmount);
    event RedeemRewardsFromRaze(
        uint256 tokenId,
        address owner,
        uint256 rewardAmount
    );

    error NotEnoughScoreToRedeem();
    error RedeemRewardPaymentFailed();
    error VillageNotOldEnoughToRedeem();

    function onReceive(uint256 value) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        s.ethAccPerScore += (value * PRECISION) / s.totalVillageScore;
        emit OnReceive((value * PRECISION) / s.totalVillageScore);
    }

    function pendingEthHelper(
        uint256 _tokenId
    ) internal view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        uint256 _ethAccPerScore = s.ethAccPerScore;
        Village memory village = s.tokenIdToVillage[_tokenId];
        VillageReward memory vr = s.tokenIdToVillageReward[_tokenId];

        //debt can sometimes be bigger by 1 wei do to several mulDivDowns so we do extra checks
        if ((village.score * _ethAccPerScore) / PRECISION < vr.debt) {
            return vr.ethOwed;
        } else {
            return
                ((village.score * _ethAccPerScore) / PRECISION) -
                vr.debt +
                vr.ethOwed;
        }
    }

    function updateEthOwed(uint256 _tokenId) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        Village memory village = s.tokenIdToVillage[_tokenId];
        VillageReward storage vr = s.tokenIdToVillageReward[_tokenId];

        if (village.score > 0) {
            vr.ethOwed = pendingEthHelper(_tokenId);
        }
    }

    function updateDebt(uint256 _tokenId) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        Village memory village = s.tokenIdToVillage[_tokenId];
        VillageReward storage vr = s.tokenIdToVillageReward[_tokenId];

        vr.debt = (village.score * s.ethAccPerScore) / PRECISION;
    }

    function reset(uint256 _tokenId) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        VillageReward storage vr = s.tokenIdToVillageReward[_tokenId];

        vr.debt = 0;
        vr.ethOwed = 0;
    }

    function redeemRewards(
        uint256 _tokenId,
        address _to,
        bool _isFromRaze
    ) internal {
        AppStorage storage s = LibAppStorage.appStorage();
        Village storage village = s.tokenIdToVillage[_tokenId];
        if (village.score == 0) {
            revert NotEnoughScoreToRedeem();
        }
        uint256 rewardAmount = RewardLibrary.pendingEthHelper(_tokenId);

        RewardLibrary.reset(_tokenId);

        //only reset villages that were redeemed by the user.
        if (!_isFromRaze) {
            s.totalVillageScore -= village.score;
            uint256 originalTimeMinted = village.timeMinted; //don't overwrite time minted
            VillagersLibrary.initVillage(_tokenId, "Test Village");
            village.timeMinted = originalTimeMinted;
            s.tokenIdToStoredHash[_tokenId] = bytes32(0); //clear hash
        }

        (bool success, ) = payable(_to).call{value: rewardAmount}("");
        if (!success) {
            revert RedeemRewardPaymentFailed();
        }
        if (_isFromRaze) {
            emit RedeemRewardsFromRaze(_tokenId, msg.sender, rewardAmount);
        } else {
            emit RedeemRewards(_tokenId, msg.sender, rewardAmount);
        }
    }
}
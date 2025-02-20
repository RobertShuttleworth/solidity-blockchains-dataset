// @author Daosourced
// @date October 5 2023
pragma solidity ^0.8.0;
import "./openzeppelin_contracts_utils_math_Math.sol";
import "./contracts_settings_IDistributionSettings.sol";
import "./contracts_IMintingManager.sol";


library Distribution {
    
    using Math for uint256;
    
    struct RegisteredPurchasers {
        mapping(address => bool) registered;
    }

    /**
    * @notice calculates the distribution amount
    * @param totalAmount total amount
    * @param bps basis points
    */
    function calculateShare(
        uint256 totalAmount, 
        uint256 bps
    ) internal pure returns (uint256 share) {
        if (bps > 0) {
            share = totalAmount.mulDiv(bps, 10000);
        } else {
            share = 0;
        }
    }

    /**
    * @notice calculates the distribution amount
    * @param totalAmount total amount
    * @param bpss basis points
    */
    function calculateShares(
        uint256[] memory bpss,
        uint256 totalAmount
    ) internal pure returns (uint256[] memory shares) {
        shares = new uint256[](bpss.length);
        for(uint i=0;i<bpss.length;i++){
            shares[i] = calculateShare(totalAmount, bpss[i]);
        }
    }

    /**
    * @notice calculates the ratio
    * @param totalAmount total amount
    * @param amountToGetRatioOf basis points
    */
    function calculateRatio(
        uint256 totalAmount, 
        uint256 amountToGetRatioOf
    ) internal pure returns (uint256 share) {
        if(amountToGetRatioOf > 0){
            share = amountToGetRatioOf.mulDiv(10000, totalAmount);
        } else {
            share = 0;
        }
    }



    /**
    * @notice sums up the total  of numbers in a lis
    * @param numbers numbers in the list
    * @return total the sum of the numbers in list
    */
    function summation(uint256[] memory numbers) internal pure returns (uint256 total) {
        for(uint256 i = 0; i < numbers.length; i++){
            total += numbers[i]; 
        }
    }

    /**
    * @notice sums up the total  of numbers in a lis
    * @param actionSettings distribution configurations for an action
    * @param direction the reward direction the reward address in question
    * @param filterAddress target reward address
    * @param shares the sum of the numbers in list
    */
    function totalShareSumOf(
        IDistributionSettings.DistributionSetting[] memory actionSettings,
        IDistributionSettings.RewardDirection direction,
        address filterAddress,
        uint256[] memory shares
    ) internal pure returns (uint256 totalShareOfFilterAddressInWei) {
        // filter reward addresses by direction
        for(uint i = 0; i < actionSettings.length; i++){
            if(actionSettings[i].rewardDirection == direction && actionSettings[i].rewardAddress == filterAddress) {
                totalShareOfFilterAddressInWei += shares[i];
            }
        }
    }

    /**
    * @notice calculates the total amount of space that should be minted/swapped for the requests sent
    * @param currentMintAmount current mintable space
    * @param requests purchase hashtag requests used in bulk purchase hashtag
    */
    function calculateSpaceMintAmount(
        IMintingManager.BulkSLDIssueRequest[] memory requests,
        uint256 currentMintAmount
    ) internal pure returns (uint256 totalMintAmountInWei) { 
        for(uint i = 0; i < requests.length; i++){
            if(bytes(requests[i].label).length <= 3){
                totalMintAmountInWei += 3 * currentMintAmount;
            } else if (bytes(requests[i].label).length == 4) {
                totalMintAmountInWei += 2 * currentMintAmount;
            } else if (bytes(requests[i].label).length > 4) {
                totalMintAmountInWei += currentMintAmount;
            }
        }
    }

    /**
    * @notice calculates the total amount of space that should be minted/swapped for the requests sent
    * @param swappableSpaceForEth current mintable space
    * @param currentMultiplier the multipler to appl
    */
    function calculateSpaceMintAmount(
        uint256 swappableSpaceForEth,
        uint256 currentMultiplier
    ) internal pure returns (uint256 totalMintAmountInWei) { 
        totalMintAmountInWei = calculateShare(swappableSpaceForEth, currentMultiplier); 
    }

    /**
    * @notice calculates the total amount of space that should be minted/swapped for the requests sent
    * @param requests purchase hashtag requests used in bulk purchase hashtag
    * @param recordedPurchasers record of previous purchasers 
    * @param currentMintAmount current mintable space
    * @param defaultMintAmount default amount of space to be minted
    */
    function calculateSpaceMintAmount(
        IMintingManager.BulkSLDIssueRequest[] memory requests,
        mapping(address => bool) storage recordedPurchasers,
        uint256 currentMintAmount,
        uint256 defaultMintAmount,
        uint256 currentMultiplier
    ) internal view returns (uint256 totalMintAmountInWei) {
        address[] memory processedAddresses = new address[](requests.length);
        uint256 processedCount = 0;
        for (uint256 i = 0; i < requests.length; i++) {
            bool hasAlreadyProcessed = false;
            for (uint256 j = 0; j < processedCount; j++) {
                if (requests[i].to == processedAddresses[j]) {
                    hasAlreadyProcessed = true;
                    break;
                }
            }
            if (!hasAlreadyProcessed) {
                processedAddresses[processedCount] = requests[i].to;
                processedCount++;
            }

            bool hasAlreadyPurchased = recordedPurchasers[requests[i].to]; 
            uint256 domainLength = bytes(requests[i].label).length;
            uint256 mintAmount = hasAlreadyProcessed || hasAlreadyPurchased ? defaultMintAmount * (currentMultiplier.mulDiv(1,10)) : currentMintAmount;
            if(domainLength <= 3){
                totalMintAmountInWei += 3 * mintAmount;
            } else if (domainLength == 4) {
                totalMintAmountInWei += 2 * mintAmount;
            } else {
                totalMintAmountInWei += mintAmount;
            }
        }
    }
}
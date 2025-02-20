// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {SubscriptionConsumer} from "./src_SubscriptionConsumer.sol";
import {UserAndPrize} from "./src_UserAndPrize.sol";

/**
 * @title RewardProcessing
 * @dev This contract is responsible for managing the prize distribution process based on random numbers.
 * It handles the uploading of users and prizes, clearing of users, prizes, and winners,
 * as well as distributing prizes based on the random numbers generated.
 */
contract RewardProcessing is SubscriptionConsumer, UserAndPrize {
    uint256 public notDistributedPrizes; // Tracks the number of prizes that have not been distributed
    uint256[] public rndsForRound; // Stores the random numbers generated for the current round

    constructor(address vrfCoordinator, bytes32 keyHash, uint256 subscriptionId)
        SubscriptionConsumer(vrfCoordinator, keyHash, subscriptionId)
    {}

    /**
     * @dev Requests random words from the VRF service to be used for prize distribution.
     * This function is only callable by the owner of the contract.
     * @return requestId The ID of the randomness request.
     */
    function requestRandomWords() external onlyOwner returns (uint256 requestId) {
        notDistributedPrizes = lastPrizeNumber();
        (, uint32 numWords) = _calculateRandoms();
        requestId = _requestRandomWords(numWords);
    }

    /**
     * @dev Distributes the prizes based on the random numbers generated in the current round.
     * This function is only callable by the owner of the contract.
     */
    function distributePrizes() external onlyOwner {
        rndsForRound = requests[lastRequestId()].randomWords;
        _distributePrizes(rndsForRound);
    }

    /**
     * @dev Uploads user data including user IDs, wallet addresses, and multipliers.
     * This function is only callable by the owner of the contract.
     * @param userIDs An array of user IDs.
     * @param wallets An array of user wallet addresses.
     * @param multipliers An array of multipliers corresponding to each user.
     */
    function uploadUsers(uint256[] calldata userIDs, address[] calldata wallets, uint256[] calldata multipliers)
        external
        onlyOwner
    {
        _uploadUsers(userIDs, wallets, multipliers);
    }

    /**
     * @dev Uploads prize data including prize IDs, descriptions, and quantities.
     * This function is only callable by the owner of the contract.
     * @param prizeIDs An array of prize IDs.
     * @param descriptions An array of prize descriptions.
     * @param prizeQuantity An array of quantities for each prize.
     */
    function uploadPrizes(uint256[] calldata prizeIDs, string[] calldata descriptions, uint256[] calldata prizeQuantity)
        external
        onlyOwner
    {
        _uploadPrizes(prizeIDs, descriptions, prizeQuantity);
    }

    /**
     * @dev Clears all user data from the contract.
     * This function is only callable by the owner of the contract.
     */
    function clearUsers() external onlyOwner {
        _clearUsers();
    }

    /**
     * @dev Clears all prize data from the contract.
     * This function is only callable by the owner of the contract.
     */
    function clearPrizes() external onlyOwner {
        _clearPrizes();
    }

    /**
     * @dev Clears all winner data from the contract.
     * This function is only callable by the owner of the contract.
     */
    function clearWinners() external onlyOwner {
        _clearWinners();
    }

    /**
     * @dev Distributes prizes based on the random numbers provided.
     * It selects winners for each prize and assigns the prize to the selected user.
     * @param randomWords The random numbers used for prize distribution.
     */
    function _distributePrizes(uint256[] memory randomWords) internal {
        uint256 counter = 1;

        // Loop through each random word to distribute the prizes
        for (uint256 i = 0; i < randomWords.length; i++) {
            uint256 randomToSplit = randomWords[i]; // Current random number for this iteration
            uint256 mps = multipliersSum(); // Total sum of multipliers across all users

            // Distribute prizes while there are prizes left and the random number is greater than the multipliers sum
            while (randomToSplit > mps && mps > 0 && notDistributedPrizes > 0) {
                // Select a winner based on the random number and the total multipliers
                (uint256 _userNumber, address _userWallet) = _selectWinner(randomToSplit % mps + 1);

                // Assign the prize to the selected winner
                _determineWinner(_userNumber, _userWallet, counter, prizes[counter].prizeID);

                randomToSplit /= mps; // Divide the random number for the next iteration
                notDistributedPrizes--; // Decrease the number of remaining prizes
                counter++; // Move to the next prize
                mps = multipliersSum(); // Recalculate the multipliers sum
            }

            // Stop distributing if there are no more prizes or multipliers
            if (notDistributedPrizes == 0 || mps == 0) break;
        }
    }

    /**
     * @dev Calculates the number of random numbers needed for the distribution.
     * It also calculates the number of random numbers to request from the VRF service.
     * @return iter The number of iterations required to split the random number.
     * @return rnds The number of random numbers to request.
     */
    function _calculateRandoms() internal view returns (uint256 iter, uint32 rnds) {
        uint256 mps = multipliersSum(); // Total sum of multipliers across all users
        uint256 rndToSplit = type(uint256).max; // Start with the largest possible random number

        // Calculate how many iterations are needed to split the random number
        while (rndToSplit > mps) {
            rndToSplit /= mps; // Reduce the random number based on the multipliers sum
            iter++; // Increment the number of iterations
        }

        // Select how many random numbers to request
        rnds = (uint32(lastPrizeNumber() / iter) == 0) ? 1 : uint32(lastPrizeNumber() / iter);
    }
}
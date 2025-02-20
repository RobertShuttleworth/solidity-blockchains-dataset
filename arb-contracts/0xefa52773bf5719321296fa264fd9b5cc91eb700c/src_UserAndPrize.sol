// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

contract UserAndPrize {
    struct User {
        uint256 userID; // Unique identifier of the user
        address wallet; // User's wallet address
        uint256 multiplier; // Multiplier for participating in the draw
        bool rewarded; // Indicates whether the user has received a reward
    }

    struct Prize {
        uint256 prizeID; // Unique identifier of the prize
        string description; // Description of the prize
        address winnerAddr; // Address of the winner who won the prize
    }

    struct Winner {
        address wallet; // Winner's wallet address
        uint256 userID;
        uint256 prizeID;
        string prizeDescription;
    }

    Winner[] private winnerList;
    mapping(address winnerWallet => Winner) winnerInfo;

    // Users are counted starting from 1. If lastUserNumber() = 0, it means that no users have been added to the SC.
    mapping(uint256 number => User) public users;
    mapping(address userWallet => User) public userInfo;

    // Prizes are counted starting from 1. If lastPrizeNumber() = 0, it means that no prizes have been added to the SC.
    mapping(uint256 number => Prize) public prizes;

    uint256 private _lastUserNumber;
    uint256 private _lastPrizeNumber;

    event WinnerDetermined(address winnerWallet, uint256 userID, uint256 prizeID, string prizeDescription);
    event UserListUploaded(address caller, uint256 timestamp, uint256 userQuantityUploaded);
    event PrizeListUploaded(address caller, uint256 timestamp, uint256 prizeQuantityUploaded);
    event AllUsersCleared(address caller, uint256 timestamp);
    event AllPrizesCleared(address caller, uint256 timestamp);
    event AllWinnersCleared(address caller, uint256 timestamp);

    error ArraysAreNotEqual();
    error DidntClearedProperly();
    error RewardsAlreadyDistributed();

    /**
     * @dev Returns a list of all user wallet addresses.
     */
    function userWalletList() external view returns (address[] memory userWalletListTemp) {
        uint256 num = lastUserNumber();
        userWalletListTemp = new address[](num);
        for (uint256 i = 0; i < num; i++) {
            userWalletListTemp[i] = users[i + 1].wallet;
        }
    }

    /**
     * @dev Returns a list of all prize descriptions.
     */
    function prizeList() external view returns (string[] memory prizeListTemp) {
        uint256 num = lastPrizeNumber();
        prizeListTemp = new string[](num);
        for (uint256 i = 0; i < num; i++) {
            prizeListTemp[i] = prizes[i + 1].description;
        }
    }

    /**
     * @dev Returns a list of all winners.
     * @return Array of Winner structures.
     */
    function getAllWinners() external view returns (Winner[] memory) {
        return winnerList;
    }

    /**
     * @dev Returns the number of the last added user.
     */
    function lastUserNumber() public view returns (uint256) {
        return _lastUserNumber;
    }

    /**
     * @dev Returns the number of the last added prize.
     */
    function lastPrizeNumber() public view returns (uint256) {
        return _lastPrizeNumber;
    }

    /**
     * @dev Calculates the sum of multipliers for users who haven't received a prize yet.
     * @return _calculatedMult The total sum of multipliers.
     */
    function multipliersSum() public view returns (uint256 _calculatedMult) {
        for (uint256 i = 1; i <= lastUserNumber(); i++) {
            if (!users[i].rewarded) _calculatedMult += users[i].multiplier;
        }
    }

    /**
     * @dev Uploads a list of users to the smart contract.
     * @param userIDs Array of user IDs.
     * @param wallets Array of user wallet addresses.
     * @param multipliers Array of multipliers for each user.
     */
    function _uploadUsers(uint256[] calldata userIDs, address[] calldata wallets, uint256[] calldata multipliers)
        internal
    {
        _lastUserNumber = _upload(userIDs, wallets, multipliers, lastUserNumber(), _setUser);

        emit UserListUploaded(msg.sender, block.timestamp, wallets.length);
    }

    /**
     * @dev Uploads a list of prizes to the smart contract.
     * @param prizeIDs Array of prize IDs.
     * @param descriptions Array of prize descriptions.
     * @param prizeQuantity Array of quantities for each prize.
     */
    function _uploadPrizes(
        uint256[] calldata prizeIDs,
        string[] calldata descriptions,
        uint256[] calldata prizeQuantity
    ) internal {
        uint256 prevPrizeQty = lastPrizeNumber();
        _lastPrizeNumber = _upload(descriptions, prizeIDs, prizeQuantity, lastPrizeNumber(), _setPrize);

        emit PrizeListUploaded(msg.sender, block.timestamp, lastPrizeNumber() - prevPrizeQty);
    }

    /**
     * @dev Clears all users from the contract.
     * Resets the last user number to 0 and clears each user's data.
     */
    function _clearUsers() internal {
        if (_clear(lastUserNumber(), _deleteUser)) _lastUserNumber = 0;

        emit AllUsersCleared(msg.sender, block.timestamp);
    }

    /**
     * @dev Clears all prizes from the contract.
     * Resets the last prize number to 0 and deletes all prize data.
     */
    function _clearPrizes() internal {
        if (_clear(lastPrizeNumber(), _deletePrize)) _lastPrizeNumber = 0;

        emit AllPrizesCleared(msg.sender, block.timestamp);
    }

    /**
     * @dev Clears all winners from the contract.
     * Removes each winner's data from the winner list and resets the winner list.
     */
    function _clearWinners() internal {
        uint256 len = winnerList.length;
        if (_clear(len, _deleteWinner)) {
            for (uint256 i = 0; i < len; i++) {
                winnerList.pop();
            }
        }
        emit AllWinnersCleared(msg.sender, block.timestamp);
    }

    /**
     * @dev Determines a winner based on user and prize information.
     * Updates the winner's information and emits the corresponding event.
     * @param userNumber The number identifying the user.
     * @param winnerWallet The wallet address of the winner.
     * @param prizeNumber The number identifying the prize.
     * @param prizeId The ID of the prize.
     */
    function _determineWinner(uint256 userNumber, address winnerWallet, uint256 prizeNumber, uint256 prizeId)
        internal
    {
        userInfo[winnerWallet].rewarded = true;
        users[userNumber].rewarded = true;

        prizes[prizeNumber].winnerAddr = winnerWallet;

        winnerInfo[winnerWallet] = Winner({
            wallet: winnerWallet,
            userID: users[userNumber].userID,
            prizeID: prizeId,
            prizeDescription: prizes[prizeNumber].description
        });
        winnerList.push(winnerInfo[winnerWallet]);

        emit WinnerDetermined(
            winnerWallet, winnerInfo[winnerWallet].userID, prizeId, winnerInfo[winnerWallet].prizeDescription
        );
    }

    /**
     * @dev Uploads data for prize-related information to the contract.
     * @param stringData Array of string data (e.g., descriptions).
     * @param uintData Array of uint data (e.g., IDs).
     * @param quantityData Array of quantities for each item.
     * @param lastNumber The last number used for the data entry.
     * @param _foo Internal function used to set the data (_setPrize).
     * @return updatedLastNumber The updated number after all items have been uploaded.
     */
    function _upload(
        string[] calldata stringData,
        uint256[] calldata uintData,
        uint256[] calldata quantityData,
        uint256 lastNumber,
        function(string calldata, uint256, uint256) internal _foo
    ) internal returns (uint256 updatedLastNumber) {
        require(stringData.length == uintData.length && stringData.length == quantityData.length, ArraysAreNotEqual());
        uint256 counter = lastNumber;

        for (uint256 i = 0; i < stringData.length; i++) {
            for (uint256 j = 0; j < quantityData[i]; j++) {
                _foo(stringData[i], uintData[i], counter + 1);
                counter++;
            }
        }

        updatedLastNumber = counter;
    }

    /**
     * @dev Uploads data for user-related information to the contract.
     * @param idsData Array of IDs for users.
     * @param addressData Array of user wallet addresses.
     * @param uintData Array of multipliers for users.
     * @param lastNumber The last number used for data entry.
     * @param _foo Internal function used to set the user data (_setUser).
     * @return updatedLastNumber The updated number after all user data is uploaded.
     */
    function _upload(
        uint256[] calldata idsData,
        address[] calldata addressData,
        uint256[] calldata uintData,
        uint256 lastNumber,
        function(uint256, address, uint256, uint256) internal _foo
    ) internal returns (uint256 updatedLastNumber) {
        require(idsData.length == addressData.length && addressData.length == uintData.length, ArraysAreNotEqual());
        uint256 counter = lastNumber;

        for (uint256 i = 0; i < addressData.length; i++) {
            _foo(idsData[i], addressData[i], uintData[i], counter + 1);
            counter++;
        }

        updatedLastNumber = counter;
    }

    /**
     * @dev Sets the user information in the contract.
     * @param _userID The user ID.
     * @param _wallet The user's wallet address.
     * @param _multiplier The user's multiplier.
     * @param _userNumber The number identifying the user in the contract.
     */
    function _setUser(uint256 _userID, address _wallet, uint256 _multiplier, uint256 _userNumber) internal {
        User storage user = users[_userNumber];
        user.userID = _userID;
        user.wallet = _wallet;
        user.multiplier = _multiplier;

        userInfo[_wallet] = user;
    }

    /**
     * @dev Sets the prize information in the contract.
     * @param _description The prize description.
     * @param _prizeID The prize ID.
     * @param _prizeNumber The number identifying the prize.
     */
    function _setPrize(string calldata _description, uint256 _prizeID, uint256 _prizeNumber) internal {
        Prize storage prize = prizes[_prizeNumber];
        prize.prizeID = _prizeID;
        prize.description = _description;
    }

    /**
     * @dev Clears data from the contract by calling the provided delete function for each entry.
     * @param _lastNumber The last number used in the contract for entries.
     * @param _foo Internal delete function (_deleteUser, _deletePrize, or _deleteWinner).
     * @return bool Returns true if the clearing operation was successful.
     */
    function _clear(uint256 _lastNumber, function(uint256) internal _foo) internal returns (bool) {
        if (_lastNumber > 0) {
            uint256 ln = _lastNumber;

            for (uint256 i = 1; i <= _lastNumber; i++) {
                _foo(i);

                ln--;
            }
            require(ln == 0, DidntClearedProperly());
        }
        return true;
    }

    /**
     * @dev Deletes user data from the contract.
     * @param _userNumber The number identifying the user to be deleted.
     */
    function _deleteUser(uint256 _userNumber) internal {
        delete userInfo[users[_userNumber].wallet];
        delete users[_userNumber];
    }

    /**
     * @dev Deletes prize data from the contract.
     * @param _prizeNumber The number identifying the prize to be deleted.
     */
    function _deletePrize(uint256 _prizeNumber) internal {
        delete prizes[_prizeNumber];
    }

    /**
     * @dev Deletes winner data from the contract.
     * @param _winnerNumberPlus1 The index of the winner to be deleted (1-based index, meaning the first winner is index 1).
     */
    function _deleteWinner(uint256 _winnerNumberPlus1) internal {
        delete winnerInfo[winnerList[_winnerNumberPlus1 - 1].wallet];
    }

    /**
     * @dev Selects a winner based on a random number.
     * @param winnerRnd The random number used to determine the winner.
     * @return _userNumber The number identifying the winning user.
     * @return _userWallet The wallet address of the winning user.
     */
    function _selectWinner(uint256 winnerRnd) internal view returns (uint256 _userNumber, address _userWallet) {
        uint256 _calculatedMult;
        // Iterate through all users starting from 1
        for (uint256 i = 1; i <= lastUserNumber(); i++) {
            // If the user has not been rewarded yet, add their multiplier to the total calculated multiplier
            if (!users[i].rewarded) _calculatedMult += users[i].multiplier;

            // If the calculated multiplier reaches or exceeds the random number, select this user as the winner
            if (_calculatedMult >= winnerRnd) {
                _userNumber = i;
                _userWallet = users[i].wallet;
                break;
            }
        }
    }
}
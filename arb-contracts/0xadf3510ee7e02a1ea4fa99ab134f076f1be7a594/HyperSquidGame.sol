// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: contracts/HyperSquidGame.sol


pragma solidity ^0.8.0;


contract HyperSquidGame {
    // Struct that stores the data related to a game participant, it gets updated every time a participant buys entries.
    struct Participant {
        // Variable that stores the game id of the last game the participant is/was part of.
        // If the game id does not match the current game id, it means that the data stored is not relevant to the current game.
        uint256 gameId;
        // The amount of entries the participant has bought.
        // This number is incremented when buying entries, and is set back to 0 when withdrawing.
        uint256 entries;
        uint256 wageredEntries;

        uint256 totalWonCount;
        uint256 totalWonAmount;

        // Variables that store avatar customization
        uint8 suit;
        uint8 hat;
        uint8 number;
        uint8 eyes;
        uint8 mouth;
        uint8 shoes;
    }

    // A struct that stores the address and data of a participant, this is only used for display purposes.
    struct ParticipatingUser {
        address participantAddress;
        Participant participantData;
    }

    // A struct that stores the data related to the winning of a particular game
    struct Winning {
        address winnerAddress;
        uint256 gameId;
        uint256 amount;
    }

    // A struct that stores the address and data of a winner, this is only used for display purposes.
    struct WinningUser {
        Winning winning;
        Participant participantData;
    }

    // Event that gets emmited when someone buys game entries.
    event EntriesPurchased(address indexed buyer, uint256 numberOfEntries);
    // Event that gets emitted when someone withdraws from the current game.
    event EntriesWithdrawn(address indexed buyer, uint256 numberOfEntries);
    // Event that gets emitted when a winner is drawn for the current game.
    event WinnerDrawn(address winner, uint256 prize, uint256 gameId);

    // The limit of unique participants that can join a game.
    uint256 private constant MAX_PARTICIPANTS = 456;
    // The amount it costs to purchase one entry (10 USDC in this case)
    uint256 public constant ENTRY_PRICE = 10e6;
    // The amount of time each game takes.
    uint256 private constant COOLDOWN_PERIOD = 60 minutes;

    // The token address for the token used for purchasing entries, (USDC token in this case)
    IERC20 public immutable usdcToken;
    // The owner of the contract, in this contract it is only used for paying out fees.
    address public immutable owner;

    // The block time of the last draw.
    // This is used to computed if an hour has passed since the last draw, which is a requirement to call the draw function for the current game.
    uint256 public lastDrawTime;

    // Variable that stores the game id of the current active game. After each winner draw, this number is incremented.
    // This variable is needed to keep track of which players have participated in the current game.
    uint256 public currentGameId = 15;

    // Variable that keeps track of the amount of entries that have been purchased for the current game.
    uint256 public entryCount;
    // Variable that keeps track of unique participants for the current game.
    // This is needed to ensure, that there are no more than 456 unique participants in the current game.
    uint256 public uniqueParticipants;

    // Array that keeps track of the wallet addresses of participants participating in the current game.
    // After each game draw, this list is reset.
    address[] public participantList;

    // Array that keeps track of all users that have ever participated in a game
    address[] public globalUserList;

    // Array that stores the history of all previous raffle winnings
    Winning[] public winningList;

    // Mapping that maps wallet addresses to participant data.
    mapping(address => Participant) public participantDataMapping;

    constructor(address _usdcToken) {
        usdcToken = IERC20(_usdcToken);
        owner = msg.sender;
    }

    /*
    * Function that allows users to enter the current game with the entries amount specified.
    * This function transfers USDC from the wallet of the user to the contract based on the entry buy count specified.
    * USDC amount has to be approved beforehand for this function to work successfully.
    * @param _numberOfEntires the number of entries to buy. 
    */
    function enterRaffle(uint256 _numberOfEntries) external {
        // Requirement to ensure that at least one ticket is being bought.
        require(_numberOfEntries > 0, "Must buy at least one entry");

        // Transfer of the entry cost (10 USDC for each entry) to the contract wallet.
        require(usdcToken.transferFrom(msg.sender, address(this), _numberOfEntries * ENTRY_PRICE), "USDC transfer failed");

        // Current Participant data retrieval from the mapping.
        Participant storage participant = participantDataMapping[msg.sender];

        // Check if the participant is already part of the current game.
        if (participant.gameId != currentGameId || participant.entries == 0) {
            // Check to ensure that the unique participant limit has not been reached yet.
            require(uniqueParticipants <= MAX_PARTICIPANTS,"Max unique participants reached");

            // If the participant has not ever participated in a game before, they get added to the global user list.
            if(participant.gameId == 0) {
                globalUserList.push(msg.sender);
            }

            // If the game id does not match the current game id, it means that the participant is not in the participant list.
            if (participant.gameId != currentGameId) {
                // Add user wallet address to the current game participant list
                participantList.push(msg.sender);
            }

            participant.entries = 0;
            // Game id is set to the current game id in the participant data.
            participant.gameId = currentGameId;
            // The unique participant count is incremented by one.
            uniqueParticipants++;
        }

        // Participant entry count is increased by the number of entries bought in this function.
        participant.entries += _numberOfEntries;
        // Participant total wagered entry count is increased by the number of entries bought, to keep track of global statistics.
        participant.wageredEntries += _numberOfEntries;

        // Global entry count is increased by the number of entries bought in this function.
        entryCount += _numberOfEntries;

        // Event emitted to keep track of entry buys.
        emit EntriesPurchased(msg.sender, _numberOfEntries);
    }

    /*
     * Function that allows users to withdraw from participating in the current game.
     * This function returns the funds to the buyer, while taking the 10% fee
     * All of the relevant variables are modified to account for the withdrawal.
     */
    function withdrawRaffle() external {
        // Participant data is taken from participant data mapping
        Participant storage participant = participantDataMapping[msg.sender];
        // Variable to store the amount of entries the particpant has bought
        uint256 participantEntries = participant.entries;

        // Check to ensure that the particpant has bought entries in the current game
        require( participant.gameId == currentGameId, "You have not participated in the current game");

        // Check to ensure that the particpant currently has at least 1 entry in the game
        require(participantEntries > 0, "You have not bought any entries");

        // Calls to withdraw funds, 90% is sent back to the participant, 10% is taken as a fee
        require(usdcToken.transfer(msg.sender,(participant.entries * ENTRY_PRICE * 90) / 100), "Withdraw transfer failed");
        require(usdcToken.transfer(owner,(participant.entries * ENTRY_PRICE * 10) / 100), "Tax transfer failed");

        // Global entry count is reduced by the amount of entires the partipant had bought
        entryCount -= participantEntries;
        // Participant entry count is set to 0
        participant.entries = 0;

        // Participant total wager count is reduced
        participant.wageredEntries -= participantEntries;

        // Unique participant count is decreased, so the participant does not take up a slot
        uniqueParticipants--;

        // Event emitted to keep track of withdraws
        emit EntriesWithdrawn(msg.sender, participantEntries);
    }

    /*
     * Function to draw the winner of the current game.
     * The function can be called by anyone, to ensure that the funds can't be held hostage.
     * The random winning is derived from the block data of the current block.
     * 90% of the prize pool is paid to the winner, 10% is taken as a fee.
     * After the winnings have been paid out, the function prepares the contract for the next game.
     */

    function drawWinner() external {
        require(block.timestamp >= lastDrawTime + COOLDOWN_PERIOD, "Cooldown period not elapsed");

        if(uniqueParticipants < 2) {
            // If there aren't enough participants to draw, the time to draw is extended.
            lastDrawTime = block.timestamp;
            return;
        }

        // Random number is chosen that is in the range of the entries bought for the current game.
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.number))) % entryCount;

        // Variable that keeps track of the amount of entires that have been processed already.
        uint256 processedEntryCount = 0;

        // Iterating over the list of the participants of the current game
        for (uint256 i = 0; i < participantList.length; i++) {
            // Retrieving the participant wallet address from the list 
            address participant = participantList[i];

            // Adding the amount of entires the participant bought to the processsed entry count.
            processedEntryCount += participantDataMapping[participant].entries;

            // Check if the current processed entry count is higher than the randomly chosen number.
            // If that is the case, it means that the iteration has found the winner, so the processes of paying out winnings begins.

            if (randomIndex < processedEntryCount) {
                // Prize funds calculation (90% of the prize pool)
                uint256 prize = (usdcToken.balanceOf(address(this)) * 90) / 100;
                // Fees calculation (10% of the prize pool)
                uint256 tax = (usdcToken.balanceOf(address(this)) * 10) / 100;

                // Prize funds are transferred to the winner.
                require(usdcToken.transfer(participant, prize), "Winner transfer failed");
                // Fees are transferred to the owner.
                require(usdcToken.transfer(owner, tax), "Tax transfer failed");

                Participant storage participantData = participantDataMapping[participant];
                
                participantData.totalWonCount++;
                participantData.totalWonAmount += prize;

                // Winning added to the list that keeps track of winnings
                winningList.push(Winning ({
                    winnerAddress: participant,
                    gameId: currentGameId,
                    amount: prize
                }));

                // Event emitted to keep track of wins.
                emit WinnerDrawn(participant, prize, currentGameId);

                // Code to reset/prepare the contract state for the next game.

                // Participant list is cleared.
                delete participantList;

                // Unique participant count is reset to 0.
                uniqueParticipants = 0;
                // Purchased entry count is reset to 0.
                entryCount = 0;

                // Last draw time is set to the current block time, to ensure that the next draw happens in an hour.
                lastDrawTime = block.timestamp;
                // The current game id is incremented by one, to invalidate all of the data related to the last game.
                currentGameId++;

                // Function returns the winner of the raffle.
                return;
            }
        }

        // In case the function fails to pick a winner, the function is reverted.
        revert("Winner selection failed");
    }

    /*
     * Function that allows users to set their avatar customization values.
     * @param _suit The suit style number
     * @param _hat The hat style number
     * @param _number The player number
     * @param _eyes The eyes style number
     * @param _mouth The mouth style number
     * @param _shoes The shoes style number
     */
    function setAvatar(
        uint8 _suit,
        uint8 _hat,
        uint8 _number,
        uint8 _eyes,
        uint8 _mouth,
        uint8 _shoes
    ) external {
        // Retrieve participant data from the participant mapping
        Participant storage participant = participantDataMapping[msg.sender];
        
        // Set all avatar customization values
        participant.suit = _suit;
        participant.hat = _hat;
        participant.number = _number;
        participant.eyes = _eyes;
        participant.mouth = _mouth;
        participant.shoes = _shoes;
    }

    /*
     * All of the remaining functions are helper view fuctions, that do not modify the state of the contract.
     */

    // Helper view function that returns how much USDC is in the current prize pool.
    function getPrizePool() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }

    // Helper view function that computes how much time is left until the next draw.
    function getTimeUntilDraw() external view returns (uint256) {
        if (block.timestamp < lastDrawTime + COOLDOWN_PERIOD) {
            return lastDrawTime + COOLDOWN_PERIOD - block.timestamp;
        }
        return 0;
    }

    // Helper view function to get the data related to the participants of the current game.
    function getParticipatingUserData() external view returns (ParticipatingUser[] memory)
    {
        ParticipatingUser[] memory users = new ParticipatingUser[](participantList.length);

        for (uint256 i = 0; i < participantList.length; i++) {
            address userAddress = participantList[i];

            users[i] = ParticipatingUser({
                participantAddress: userAddress,
                participantData: participantDataMapping[userAddress]
            });
        }

        return users;
    }

    // Helper view function to get the data related to all users.
    function getGlobalUserData() external view returns (ParticipatingUser[] memory)
    {
        ParticipatingUser[] memory users = new ParticipatingUser[](globalUserList.length);

        for (uint256 i = 0; i < globalUserList.length; i++) {
            address userAddress = globalUserList[i];

            users[i] = ParticipatingUser({
                participantAddress: userAddress,
                participantData: participantDataMapping[userAddress]
            });
        }

        return users;
    }

    // Helper view function to get the data related to the winners of previous games.

    function getWinningData() external view returns (WinningUser[] memory)
    {
        WinningUser[] memory winnings = new WinningUser[](winningList.length);

        for (uint256 i = 0; i < winningList.length; i++) {
            Winning memory winning = winningList[i];

            winnings[i] = WinningUser({
                winning: winning,
                participantData: participantDataMapping[winning.winnerAddress]
            });
        }

        return winnings;
    }
}
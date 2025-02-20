pragma solidity ^0.8.26;

/**
 * @title HolidaySpecial
 * @dev A contract for a guessing game where users can make guesses and claim prizes.
 * The contract is governed by an admin who can reveal the correct answer and update game parameters.
 */

import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract HolidaySpecial {
    using SafeERC20 for IERC20;

    IERC20 public prizeToken; // Token used for prizes
    bytes32 private hashedAnswer; // Hashed answer for validation
    uint256 public epochEnd; // Timestamp when the guessing period ends
    address public admin; // Admin address

    bytes private cleartextAnswer; // The correct answer revealed after the epoch
    mapping(string => address) public guessToAddress; // Maps guesses to the addresses that made them

    // EVENTS
    event NewGuess(address indexed user, string guess); // Emitted when a new guess is made
    event PrizeClaimed(address indexed winner); // Emitted when a prize is claimed
    event RevealAnswer(string answer); // Emitted when the correct answer is revealed

    /**
     * @dev Constructor to initialize the contract with prize token address, hashed answer, and epoch duration.
     * @param _prizeTokenAddress Address of the ERC20 token used for prizes.
     * @param _answer Hashed answer for the guessing game.
     * @param _epoch Duration of the guessing period in seconds.
     */
    constructor(address _prizeTokenAddress, bytes32 _answer, uint _epoch) {
        admin = msg.sender; // Set the contract deployer as admin
        prizeToken = IERC20(_prizeTokenAddress);
        hashedAnswer = _answer;
        epochEnd = block.timestamp + _epoch; // Set the end time for the epoch
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin can call this");
        _;
    }

    modifier openGame() {
        require(getRemainingTime() > 0, "time's up, Bearmas morning has already arrived!");
        _;
    }

    fallback() external payable {}
    receive() external payable {}

    /**
     * @dev Allows users to make a guess. Reverts if the guess has already been made.
     * @param guess The user's guess as a string.
     */
    function makeGuess(string calldata guess) external openGame {
        require(guessToAddress[guess] == address(0x0), "someone already guessed this! Frontran again, anon.");
        require(bytes(guess).length > 0, "you call this a guess?");
        guessToAddress[guess] = msg.sender; // Map the guess to the user's address
        emit NewGuess(msg.sender, guess);
    }

    /**
     * @dev Allows the winner to claim their prize after the epoch ends.
     */
    function claimPrize() external {
        uint256 balance = prizeToken.balanceOf(address(this));
        require(balance > 0, "no prize to claim");
        require(getRemainingTime() == 0, 'RevealAnswer? Not yet chief!');
        require(msg.sender == getWinner(), "nice try, but you are not the winner chief");
        prizeToken.safeTransfer(msg.sender, balance); // Transfer the prize to the winner
        emit PrizeClaimed(msg.sender);
    }

    /**
     * @dev Returns the time remaining in the guessing epoch.
     * @return Remaining time in seconds.
     */
    function getRemainingTime() public view returns(uint) {
        if(epochEnd < block.timestamp) return 0; // Avoid underflow revert
        return epochEnd - block.timestamp;
    }

    /**
     * @dev Checks if a guess is valid.
     * @param guess The guess to validate.
     * @return True if the guess is valid, false otherwise.
     */
    function isGuessValid(string calldata guess) public view returns(bool) {
        if (getRemainingTime() <= 0) return false; // Check if the game is still open
        if (guessToAddress[guess] != address(0x0)) return false; // Check if the guess has already been made
        return true;
    }

    /**
     * @dev Returns the winning address after the epoch is over and the answer is revealed.
     * @return Address of the winner.
     */
    function getWinner() public view returns(address) {
        if (bytes(cleartextAnswer).length == 0) return address(0x0); // No winner if the answer is not revealed
        return guessToAddress[string(cleartextAnswer)]; // Return the address that made the correct guess
    }

    /**
     * @dev Returns the correct answer after the epoch is over and revealed by the admin.
     * @return The correct answer as a string.
     */
    function getCorrectGuess() public view returns (string memory) {
        return string(cleartextAnswer);
    }

    /**
     * @dev Allows the admin to reveal the correct answer after the epoch ends.
     * @param _answer The correct answer to be revealed.
     */
    function revealAnswer(bytes memory _answer) external onlyAdmin {
        require(getRemainingTime() == 0, 'RevealAnswer? Not yet chief!');
        require(keccak256(_answer) == hashedAnswer && bytes(cleartextAnswer).length == 0, "ser, this is Wendy's");
        cleartextAnswer = _answer; // Store the revealed answer
        emit RevealAnswer(string(_answer));
    }

    /**
     * @dev Allows the admin to withdraw tokens in case of an emergency.
     */
    function emergencyWithdraw() external onlyAdmin {
        prizeToken.safeTransfer(msg.sender, prizeToken.balanceOf(address(this))); // Transfer all tokens to admin
    }

    /*
     * @dev Converts a string to bytes.
     * @param _str The string to convert.
     * @return The converted bytes.
     */
    function encodeStringToBytes(string memory _str) public pure returns (bytes memory _byteString) {
        _byteString = bytes(_str);
    }

    /**
     * @dev Returns the current block timestamp.
     * @return Current timestamp in seconds & key is Beramas69420.
     */
    function getTimestamp() public view returns (uint256) {
        return block.timestamp;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_access_Ownable2Step.sol";

import "./chainlink_contracts_src_v0.8_vrf_VRFV2WrapperConsumerBase.sol";
import "./chainlink_contracts_src_v0.8_shared_access_ConfirmedOwner.sol";

import './contracts_SilverFees_SilverFees.sol';

// User's tickets
struct UserTickets {
	uint256 tickets;
	uint256 timestamp;
}

// User's tickets data
struct GiveawayTicketsData {
	mapping(address => UserTickets) userTickets;
	uint256 lastExecution;
}

// Weekly giveaway
struct GiveawayData {
	address[] giveawayParticipants;
	uint256 numberOfParticipants;
	bool participationEnded;
	uint256 giveawayEndTime;
}

// Giveaway settings
struct GiveawaySettings {
	bool isGiveawayActive;
	uint256 ticketPrice;
	uint256 giveawayTime;
	bool editedActive;
	uint256 editedTicketPrice;
	uint256 editedGiveawayTime;
}

// Chainlink VRF datas
struct RequestStatus {
	uint256 paid;
	bool fulfilled;
	uint256[] randomWords;
}

// Chainlink VRF inputs
struct RequestInput {
	uint32 callbackGasLimit;
	uint16 requestConfirmations;
	uint32 numWords;
}

/// @title SilverFeesGiveaway
/// @author github.com/SifexPro
/// @notice This contract take care of the weekly giveaway
contract SilverFeesGiveaway is Ownable2Step, VRFV2WrapperConsumerBase {
	SilverFees public silverFees;

	GiveawayData public giveawayData;
	GiveawayTicketsData public giveawayTicketsData;

	GiveawaySettings public giveawaySettings;

	RequestStatus public s_request;
	RequestInput public s_input;
    uint256 private requestId;

	event GiveawaySyncStarted(uint256 ticketPrice, uint256 giveawayEndTime);
	event GiveawaySynced();

	event GiveawayExecuted(bool isGiveawayActive, uint256 weeklyGiveawayAmount);
	event BuyTickets(address indexed account, uint256 amount, uint256 tickets);
	event DrawWinner(address indexed winner, uint256 amount, uint256 randomIndex);

	event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords, uint256 payment);

	event EditedSilverFees(address silverFees);
	event EditedGiveawayTicketPrice(uint256 ticketPrice);
	event EditedGiveawayTime(uint256 giveawayTime);
	event EditedGiveawayActive(bool isGiveawayActive);
	event StartedGiveaway(uint256 ticketPrice, uint256 giveawayEndTime);
	event StoppedGiveaway();

	event WithdrawnToken(address indexed token, address to, uint256 amount);


	constructor(address _link, address _wrapper) Ownable(msg.sender) VRFV2WrapperConsumerBase(_link, _wrapper) {
		s_input.callbackGasLimit = 500000;
    	s_input.requestConfirmations = 7;
    	s_input.numWords = 1;

		giveawaySettings = GiveawaySettings(true, 1 ether, 1 weeks, false, 0, 0);
	}


	// Fees management

	/**
	 * @dev Check if the giveaway can be executed
	 * @notice Will return true : if the giveaway is over and s_request is fulfilled, or if the giveaway is not active
	 */
	function checkExecuteGiveaway() external onlySilverFees view returns (bool) {
		return ((giveawayData.participationEnded && s_request.fulfilled) || !giveawaySettings.isGiveawayActive);
	}

	/**
	 * @dev Execute the giveaway
	 * @param isSwapToWrappedToken If the giveaway is in wrapped native token
	 * @param weeklyGiveawayAmount Amount to giveaway
	 * @notice Will draw a winner if the giveaway is active, otherwise will transfer the amount to the contract
	 */
	function executeGiveaway(bool isSwapToWrappedToken, uint256 weeklyGiveawayAmount) external onlySilverFees {
		if (giveawaySettings.isGiveawayActive && s_request.fulfilled)
			drawWinner(isSwapToWrappedToken, weeklyGiveawayAmount);
		else if (!giveawaySettings.isGiveawayActive) {
			bool success;
			if (isSwapToWrappedToken)
				success = silverFees.wrappedToken().transferFrom(address(silverFees), address(this), weeklyGiveawayAmount);
			else
				success = silverFees.silverToken().transferFrom(address(silverFees), address(this), weeklyGiveawayAmount);
			require(success, "Transfer failed");
		}

		if (!giveawaySettings.isGiveawayActive || (giveawaySettings.isGiveawayActive && s_request.fulfilled))
			applyEditedSettings();

		emit GiveawayExecuted(giveawaySettings.isGiveawayActive, weeklyGiveawayAmount);
	}


	// Sync Fees Management 

	/**
	 * @dev Start the giveaway sync
	 */
	function startSyncGiveaway() public onlySilverFees {
		applyEditedSettings();

		giveawayData = GiveawayData(new address[](0), 0, false, silverFees.syncFeesLastSync() + giveawaySettings.giveawayTime);
		
		emit GiveawaySyncStarted(giveawaySettings.ticketPrice, giveawayData.giveawayEndTime);
	}

	/**
	 * @dev Sync the giveaway
	 */
	function syncGiveaway() external onlySilverFees {
		if (!giveawaySettings.isGiveawayActive) return;
		uint256 syncTime = silverFees.syncFeesTime();
		uint256 giveawayTime = giveawaySettings.giveawayTime;

		bool giveawayTimeCheck = block.timestamp + (syncTime / 2) >= giveawayData.giveawayEndTime;
		if (giveawayTimeCheck && giveawayData.numberOfParticipants > 0 && requestId == 0) { // Check if the giveaway is over and no request is sent
			requestRandomWords();
			giveawayData.participationEnded = true;
		} else if (giveawayTimeCheck && giveawayData.numberOfParticipants == 0) { // Check if the giveaway is over and no participants
			applyEditedSettings();
			giveawayData.giveawayEndTime = silverFees.syncFeesLastSync() + giveawayTime;
		} else if (giveawayTimeCheck && giveawayData.participationEnded && block.timestamp > giveawayData.giveawayEndTime + (2 * syncTime)) { // Check if the giveaway is over and still not executed after 2 sync 
			clearRequest();
			giveawayData.participationEnded = false;

			applyEditedSettings();
			giveawayData.giveawayEndTime = silverFees.syncFeesLastSync() + giveawayTime;
		}

		emit GiveawaySynced();
	}


	// Weekly giveaway

	/**
	 * @dev Buy tickets for the giveaway
	 * @param _amount Amount of tokens to buy tickets
	 * @param user Address of the user
	 * @notice Will buy tickets for the user if the giveaway is active and not ended
	 */
	function buyTickets(uint256 _amount, address user) external onlySilverFees {
		require(giveawaySettings.isGiveawayActive, "Giveaway not active");
		require(!giveawayData.participationEnded, "Ended");
		require(_amount >= giveawaySettings.ticketPrice, "Price too low");
		
		uint256 amount = _amount;
		uint256 tokenAmountIn = _amount / giveawaySettings.ticketPrice;
		if (_amount > giveawaySettings.ticketPrice) {
			amount = tokenAmountIn * giveawaySettings.ticketPrice;
		}

		uint256 balance = silverFees.silverToken().balanceOf(user);
		require(balance >= amount, "Not enough balance");

		uint256 allowance = silverFees.silverToken().allowance(user, address(silverFees));
		require(allowance >= amount, 'Not enough allowance');

		silverFees.buyTicketsBurn(user, amount);

		for (uint256 i = 0; i < tokenAmountIn; i++)
			giveawayData.giveawayParticipants.push(user);
		giveawayData.numberOfParticipants = giveawayData.giveawayParticipants.length;

		giveawayTicketsData.userTickets[user] = UserTickets(userTickets(user) + tokenAmountIn, block.timestamp);

		emit BuyTickets(user, amount, tokenAmountIn);
	}

	/**
	 * @dev Draw a winner for the giveaway
	 * @param isSwapToWrappedToken If the giveaway is in wrapped native token
	 * @param weeklyGiveawayAmount Amount to giveaway
	 * @notice Will draw a winner if the giveaway is active and ended
	 */
	function drawWinner(bool isSwapToWrappedToken, uint256 weeklyGiveawayAmount) private {
		require(giveawayData.participationEnded, "Too early");
		require(giveawayData.numberOfParticipants > 0, "0 participants");

		uint256 winnerIndex = getRandomIndex(giveawayData.numberOfParticipants);
		address winner = giveawayData.giveawayParticipants[winnerIndex];
		uint256 giveawayAmount = weeklyGiveawayAmount;
		
		bool success;
		if (isSwapToWrappedToken)
			success = silverFees.wrappedToken().transferFrom(address(silverFees), winner, giveawayAmount);
		else
			success = silverFees.silverToken().transferFrom(address(silverFees), winner, giveawayAmount);
		require(success, "Transfer failed");

		// Reset giveaway
		giveawayData.participationEnded = false;
		giveawayData.giveawayEndTime = silverFees.syncFeesLastSync() + giveawaySettings.giveawayTime;
		giveawayData.giveawayParticipants = new address[](0);
		giveawayData.numberOfParticipants = 0;
		clearRequest();

		giveawayTicketsData.lastExecution = block.timestamp;

		emit DrawWinner(winner, giveawayAmount, winnerIndex);
	}

	function getRandomIndex(uint256 lenght) private view returns (uint256 _randomWords) {
        uint256 randomWords = s_request.randomWords[0] % lenght;
		return (randomWords);
    }


	// User tickets

	/**
	 * @dev Get the user's tickets
	 * @param user Address of the user
	 * @return Number of tickets
	 */
	function userTickets(address user) public view returns (uint256) {
		if (giveawayTicketsData.userTickets[user].timestamp > giveawayTicketsData.lastExecution && giveawaySettings.isGiveawayActive)
			return giveawayTicketsData.userTickets[user].tickets;
		return 0;
	}


	// Internal functions

	function withdrawToken(address _token, address _to) public onlyOwner {
		IERC20 token = IERC20(_token);
		uint256 balance = token.balanceOf(address(this));

		SafeERC20.safeTransfer(token, _to, balance);

		emit WithdrawnToken(_token, _to, balance);
	}

	function applyEditedSettings() private {
		if (giveawaySettings.editedTicketPrice != 0)
		{
			giveawaySettings.ticketPrice = giveawaySettings.editedTicketPrice;
			giveawaySettings.editedTicketPrice = 0;
		}

		if (giveawaySettings.editedGiveawayTime != 0)
		{
			giveawayData.giveawayEndTime = silverFees.syncFeesLastSync() + giveawaySettings.editedGiveawayTime;
			giveawaySettings.giveawayTime = giveawaySettings.editedGiveawayTime;
			giveawaySettings.editedGiveawayTime = 0;
		}

		if (giveawaySettings.editedActive)
		{
			giveawaySettings.isGiveawayActive = !giveawaySettings.isGiveawayActive;
			giveawaySettings.editedActive = false;

			if (giveawaySettings.isGiveawayActive)
			{
				giveawayData.giveawayEndTime = silverFees.syncFeesLastSync() + giveawaySettings.giveawayTime;
				emit StartedGiveaway(giveawaySettings.ticketPrice, giveawayData.giveawayEndTime);
			}
			else 
				emit StoppedGiveaway();
		}
	}

	function editSilverFees(address _silverFees) public onlyOwner {
		silverFees = SilverFees(payable(_silverFees));
		
		emit EditedSilverFees(_silverFees);
	}

	function editGiveawayTicketPrice(uint256 _ticketPrice) public onlyOwner {
		giveawaySettings.editedTicketPrice = _ticketPrice;
		
		emit EditedGiveawayTicketPrice(_ticketPrice);
	}

	function editGiveawayTime(uint256 _giveawayTime) public onlyOwner {
		giveawaySettings.editedGiveawayTime = _giveawayTime;
		
		emit EditedGiveawayTime(_giveawayTime);
	}

	function setActiveGiveaway(bool _giveawayActive) public onlyOwner {
		if (giveawaySettings.isGiveawayActive == _giveawayActive)
			giveawaySettings.editedActive = false;
		else
			giveawaySettings.editedActive = true;

		emit EditedGiveawayActive(_giveawayActive);
	}


	// Chainlink VRF

	function requestRandomWords() private returns (uint256 _requestId) {
		require(requestId == 0, "already sent");
        requestId = requestRandomness(s_input.callbackGasLimit, s_input.requestConfirmations, s_input.numWords);
        s_request = RequestStatus({
            paid: VRF_V2_WRAPPER.calculateRequestPrice(s_input.callbackGasLimit),
            randomWords: new uint256[](0),
            fulfilled: false
        });
        emit RequestSent(requestId, s_input.numWords);
        return requestId;
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        require(s_request.paid > 0, "request not found");
		require(_requestId == requestId, "request id mismatch");
        s_request.fulfilled = true;
        s_request.randomWords = _randomWords;
        emit RequestFulfilled(_requestId, _randomWords, s_request.paid);
    }

	function clearRequest() private {
		requestId = 0;
		s_request = RequestStatus({
			paid: 0,
			randomWords: new uint256[](0),
			fulfilled: false
		});
	}


	// Modifiers 

	modifier onlySilverFees() {
		require(msg.sender == address(silverFees), 'Only SilverFees');
		_;
	}
}
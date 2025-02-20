// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol';
import './openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol';
import './contracts_interfaces_IMemifyTokenFactory.sol';

contract MemifyAdsBidding is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    /// @notice Structure to store information about each slot
    struct Slot {
        address token; // User token
        uint256 currentBid; // Current highest bid in ETH
        address highestBidder; // Address of highest bidder
        uint256 lastBidTime; // Timestamp of last bid
    }

    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    /// @notice Event emitted when a contract is initialized.
    event AdsBiddingInitialized(
        address memifyFactory,
        address treasury,
        uint256 slotDuration,
        uint256 startingPrice,
        uint256 numSlots
    );

    /// @notice Event emitted when a new bid is placed
    event NewBid(uint256 indexed slotId, address indexed token, address indexed bidder, uint256 amount);

    /// @notice Event emitted when slot configuration is updated
    event SlotConfigUpdated(uint256 numSlots, uint256 duration, uint256 startingPrice);

    /// @notice Address of the MemifyFactory contract
    address public memifyFactory;

    /// @notice Address of the treasury
    address public treasury;

    /// @notice Duration for which a slot remains open (in seconds)
    uint256 public slotDuration;

    /// @notice Starting price for bidding in ETH
    uint256 public startingPrice;

    /// @notice Minimum bid increase percentage (5% = 500)
    uint256 public constant MIN_BID_INCREASE = 500;

    /// @notice Number of active slots
    uint256 public numSlots;

    /// @notice Mapping of slot ID to slot information
    mapping(uint256 => Slot) public slots;

    /// @notice Mapping of token to check if it is blacklisted
    mapping(address => bool) public isTokenBlacklisted;

    // This function is called only once due to the `initializer` modifier.
    function initialize(
        address _memifyFactory,
        address _treasury,
        uint256 _slotDuration,
        uint256 _startingPrice,
        uint256 _numSlots
    ) public initializer {
        __Ownable_init(); // Initializes ownership to the deployer
        __ReentrancyGuard_init(); // Initializes the non-reentrant modifier

        require(_memifyFactory != address(0), 'Invalid MemifyFactory contract address');
        require(_treasury != address(0), 'Invalid treasury address');
        require(_slotDuration > 0, 'Invalid duration');
        require(_startingPrice > 0, 'Invalid starting price');
        require(_numSlots > 0, 'Invalid number of slots');

        memifyFactory = _memifyFactory;
        treasury = _treasury;
        slotDuration = _slotDuration;
        startingPrice = _startingPrice;
        numSlots = _numSlots;

        // Initialize slots
        for (uint256 i = 0; i < _numSlots; i++) {
            slots[i].currentBid = _startingPrice;
        }

        emit AdsBiddingInitialized(_memifyFactory, _treasury, _slotDuration, _startingPrice, _numSlots);
    }

    /// @notice Place a bid on a specific slot using ETH
    /// @param _slotId ID of the slot to bid on
    function placeBid(uint256 _slotId, address _token) external payable nonReentrant {
        require(IMemifyTokenFactory(memifyFactory).isMemeToken(_token), 'Token is not meme token');
        Slot storage slot = slots[_slotId];

        require(!isSlotExpired(_slotId), 'Current slot is expired');
        require(!isTokenBlacklisted[_token], 'This token is blacklisted');

        // If first bid on reset slot
        if (slot.highestBidder == address(0)) {
            require(msg.value >= startingPrice, 'Bid below starting price');
        } else {
            // Ensure bid is at least 5% higher than current bid
            uint256 minBid = slot.currentBid + ((slot.currentBid * MIN_BID_INCREASE) / 10000);
            require(msg.value >= minBid, 'Bid increase too low');

            // Refund the previous highest bidder
            (bool success, ) = payable(slot.highestBidder).call{ value: slot.currentBid }('');
            require(success, 'Failed to refund previous bidder');
        }

        // Update slot information
        slot.token = _token;
        slot.currentBid = msg.value;
        slot.highestBidder = msg.sender;
        slot.lastBidTime = block.timestamp;

        emit NewBid(_slotId, _token, msg.sender, msg.value);
    }

    /// @notice Check if a slot has expired
    /// @param _slotId ID of the slot to check
    /// @return bool indicating if slot has expired
    function isSlotExpired(uint256 _slotId) public view returns (bool) {
        require(_slotId < numSlots, 'Invalid slot ID');
        Slot storage slot = slots[_slotId];
        return block.timestamp > slot.lastBidTime + slotDuration && slot.highestBidder != address(0);
    }

    /// @notice Update slot configuration (only owner)
    /// @param _numSlots New number of slots
    /// @param _duration New slot duration
    /// @param _startingPrice New starting price in ETH
    function updateSlotConfig(uint256 _numSlots, uint256 _duration, uint256 _startingPrice) external onlyOwner {
        require(_numSlots > 0, 'Invalid number of slots');
        require(_duration > 0, 'Invalid duration');
        require(_startingPrice > 0, 'Invalid starting price');

        numSlots = _numSlots;
        slotDuration = _duration;
        startingPrice = _startingPrice;

        for (uint256 i = 0; i < _numSlots; i++) {
            slots[i].token = address(0);
            slots[i].currentBid = _startingPrice;
            slots[i].highestBidder = address(0);
            slots[i].lastBidTime = 0;
        }

        emit SlotConfigUpdated(_numSlots, _duration, _startingPrice);
    }

    /// @notice Update treasury address (only owner)
    /// @param _newTreasury New treasury address
    function setTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), 'Invalid treasury address');
        treasury = _newTreasury;
    }

    /// @notice Update MemifyFactory contract address (only owner)
    /// @param _newFactory New Factory address
    function setMemifyFactory(address _newFactory) external onlyOwner {
        require(_newFactory != address(0), 'Invalid Factory address');
        memifyFactory = _newFactory;
    }

    /// @notice Set the token as blacklist (only owner)
    /// @param _token Token address
    function setBlacklistToken(address _token) external onlyOwner {
        require(_token != address(0), 'Invalid token address');
        isTokenBlacklisted[_token] = true;
    }

    /// @notice Withdraw ETH to treasury address (only owner)
    /// @param _amount ETH amount
    function withdrawETH(uint256 _amount) external onlyOwner {
        (bool treasuryTransfer, ) = payable(treasury).call{ value: _amount }('');
        require(treasuryTransfer, 'Failed to send ETH to treasury');
    }

    /// @notice Get current slot information
    /// @param _slotId ID of the slot
    /// @return currentBid Current highest bid in ETH
    /// @return highestBidder Address of highest bidder
    /// @return lastBidTime Timestamp of last bid
    /// @return isActive Whether slot is active
    /// @return timeRemaining Time remaining until slot expires
    function getSlotInfo(
        uint256 _slotId
    )
        external
        view
        returns (uint256 currentBid, address highestBidder, uint256 lastBidTime, bool isActive, uint256 timeRemaining)
    {
        require(_slotId < numSlots, 'Invalid slot ID');
        Slot memory slot = slots[_slotId];

        uint256 remaining;
        if (slot.lastBidTime + slotDuration > block.timestamp) {
            remaining = slot.lastBidTime + slotDuration - block.timestamp;
        }

        return (slot.currentBid, slot.highestBidder, slot.lastBidTime, remaining > 0, remaining);
    }

    /// @notice Fallback function to receive ETH
    receive() external payable {}
}
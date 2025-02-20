// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
    function totalSupply() external view returns (uint256);
}

contract RisyRaffle {
    address public immutable nftContract;
    uint256 public winningTicketId;
    address public winner;
    bool public isDrawComplete;
    address public owner;

    event WinnerSelected(uint256 indexed ticketId, address indexed winner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(address _nftContract) {
        nftContract = _nftContract;
        owner = msg.sender;
    }

    function drawWinner() external onlyOwner {
        require(!isDrawComplete, "Draw already completed");
        
        uint256 totalTickets = IERC721(nftContract).totalSupply();
        require(totalTickets > 0, "No tickets minted");

        // Using block variables for randomness
        // Note: This is not cryptographically secure, but simple enough for this use case
        uint256 randomNumber = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    block.number
                )
            )
        );

        // Select winning ticket (1-based index since NFT IDs typically start at 1)
        winningTicketId = (randomNumber % totalTickets) + 1;
        
        // Get the winner's address
        winner = IERC721(nftContract).ownerOf(winningTicketId);
        
        isDrawComplete = true;
        
        emit WinnerSelected(winningTicketId, winner);
    }

    // Allow owner to transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
} 
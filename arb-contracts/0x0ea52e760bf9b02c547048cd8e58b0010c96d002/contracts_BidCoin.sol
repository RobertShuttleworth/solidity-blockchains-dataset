// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Votes.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Permit.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";
import "./hardhat_console.sol";

/**
 * @title BidCoin
 * @dev Implementation of the BidCoin token.
 * This token is used for bidding in auctions and governance.
 * It includes features for minting, burning, voting, and pausing.
 */

contract BidCoin is
	ERC20,
	ERC20Burnable,
	ERC20Permit,
	ERC20Votes,
	Pausable,
	Ownable,
	AccessControl
{
	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
	bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");

	uint256 public constant MAX_SUPPLY = 21000000 * 10 ** 18; // 21 million tokens

	mapping(address => bool) public authorizedAuctions;

	// Testing Section
	/**
	 * @dev Allows the owner to withdraw all BidCoins from the contract.
	 */
	function withdrawAllTokens() external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(
			paused(),
			"Contract must be paused before withdrawing all tokens"
		);
		uint256 balance = balanceOf(address(this));
		_transfer(address(this), msg.sender, balance);
	}

	/**
	 * @dev Allows the owner to destroy the contract and send remaining tokens to the owner.
	 */
	function selfDestruct() external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(paused(), "Contract must be paused before self-destructing");
		uint256 balance = balanceOf(address(this));
		if (balance > 0) {
			_transfer(address(this), msg.sender, balance);
		}

		payable(owner()).transfer(address(this).balance);
	}

	/**
	 * @dev Quickly stops all operations.
	 */
	function emergencyStop() external onlyRole(PAUSER_ROLE) {
		_pause();
		emit EmergencyStop(block.timestamp);
	}

	event EmergencyStop(uint256 timestamp);

	// Testing Section
	constructor()
		Ownable(msg.sender)
		// address _timelock
		ERC20("BidCoin", "BID")
		ERC20Permit("BidCoin")
	{
		// require(_timelock != address(0), "Invalid timelock address");

		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(PAUSER_ROLE, msg.sender);
		_grantRole(FACTORY_ROLE, msg.sender);
	}

	/**
	 * @dev Sets the auction factory address and grants it the FACTORY_ROLE.
	 * @param _auctionFactory Address of the auction factory contract.
	 */
	function setAuctionFactory(
		address _auctionFactory
	) external onlyRole(DEFAULT_ADMIN_ROLE) {
		require(!paused(), "Contract is paused");
		require(
			_auctionFactory != address(0),
			"Invalid auction factory address"
		);
		_grantRole(FACTORY_ROLE, _auctionFactory);
	}

	/**
	 * @dev Mints new BidCoins. Can only be called by authorized auctions.
	 * @param to Address to receive the minted tokens.
	 * @param amount Amount of tokens to mint.
	 */
	function mintBidCoins(address to, uint256 amount) external {
		require(authorizedAuctions[msg.sender], "Not an authorized auction");
		require(!paused(), "Contract is paused");
		require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
		_mint(to, amount);
	}

	/**
	 * @dev Authorizes an auction contract to mint BidCoins.
	 * @param auctionAddress Address of the auction contract to authorize.
	 */
	function authorizeAuction(
		address auctionAddress
	) external onlyRole(FACTORY_ROLE) {
		require(!paused(), "Contract is paused");
		console.log("authorizeAuction auctionAddress:", auctionAddress);
		authorizedAuctions[auctionAddress] = true;
	}

	/**
	 * @dev Deauthorizes an auction contract from minting BidCoins.
	 * @param auctionAddress Address of the auction contract to deauthorize.
	 */
	function deauthorizeAuction(
		address auctionAddress
	) external onlyRole(FACTORY_ROLE) {
		require(!paused(), "Contract is paused");
		authorizedAuctions[auctionAddress] = false;
	}

	/**
	 * @dev Pauses all token transfers and operations.
	 */
	function pause() public onlyRole(PAUSER_ROLE) {
		require(!paused(), "Contract is already paused");
		_pause();
	}

	/**
	 * @dev Unpauses all token transfers and operations.
	 */
	function unpause() public onlyRole(PAUSER_ROLE) {
		require(paused(), "Contract is already unpaused");
		_unpause();
	}

	/**
	 * @dev Internal function to update balances and total supply.
	 * This function overrides both ERC20 and ERC20Votes implementations.
	 * It also includes the pause functionality.
	 */
	function _update(
		address from,
		address to,
		uint256 amount
	) internal override(ERC20, ERC20Votes) {
		require(!paused(), "Contract is paused");
		super._update(from, to, amount);
	}

	/**
	 * @dev Internal function to mint tokens.
	 * This function is overridden to ensure all necessary logic is executed.
	 */
	// function mint(address to, uint256 amount) internal {
	// 	require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
	// 	require(!paused(), "Contract is paused");
	// 	_mint(to, amount);
	// }

	function burnBidCoin(address account, uint256 amount) public {
		burnFrom(account, amount);
	}

	/**
	 * @dev Internal function to burn tokens.
	 * This function is overridden to ensure all necessary logic is executed.
	 */
	function burn(address account, uint256 amount) internal {
		require(!paused(), "Contract is paused");
		_burn(account, amount);
	}

	/**
	 * @dev Overrides the OpenZeppelin ERC20Permit and ERC20Votes nonces function.
	 */
	function nonces(
		address owner
	) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
		return super.nonces(owner);
	}

	/**
	 * @dev This empty reserved space is put in place to allow future versions to add new
	 * variables without shifting down storage in the inheritance chain.
	 */
	uint256[50] private __gap;
}
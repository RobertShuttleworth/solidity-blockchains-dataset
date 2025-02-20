// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721Receiver.sol";
import "./lib_openzeppelin-contracts_contracts_utils_Pausable.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";
import "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import "./src_StakingToken.sol";

contract NFTStaking is
	IERC721Receiver,
	IERC20,
	IERC20Metadata,
	Pausable,
	Ownable
{
	event PaymentStarted(uint256 day, uint256 reward, uint256 suppply);
	event PaymentComplete(uint256 day);
	event NFTCreated(address NFTContract, uint256 yield);

	uint256 constant GAS_THRESHOLD = 100000;
	uint256 constant SECONDS_PER_DAY = 24 * 60 * 60;

	IERC20 public rewardToken;
	address[] public nftProviders;
	mapping(address => uint256) public yields;
	mapping(uint256 => address) public stakers;
	mapping(address => uint256) public stakingAmounts;
	uint256 public stakingAmount;
	uint256 public processedCounter;

	address[] stAddress;
	mapping(address => bool) stIincluded;
	mapping(address => int256) deltas;
	string _name;
	string _symbol;
	int256 delta;
	uint256 lastPaymentDay;
	uint256 currentRewardDay;
	uint256 currentPaymentReward;
	uint256 currentPaymentSupply;

	/**
	 * @param __name ERC-20 token name
	 * @param __symbol ERC-20 token symbol
	 * @param _rewardToken ERC-20 Token that will be used for rewards
	 */
	constructor(
		string memory __name,
		string memory __symbol,
		address _rewardToken
	) Ownable(msg.sender) {
		_name = __name;
		_symbol = __symbol;
		rewardToken = IERC20(_rewardToken);
		lastPaymentDay = calculateDay(block.timestamp);
	}

	/**
	 * Add NFT contract
	 * @param yield yield of single NFT
	 * @param name_ ERC721 token name
	 * @param symbol_ ERC721 token symbol
	 * @param _paymentReceiver receiver of purchase payments
	 * @param _paymentToken token that using for purchase
	 * @param _price price of single NFT
	 */
	function addNFTProvider(
		uint256 yield, 
		string memory name_, 
		string memory symbol_, 
		address _paymentReceiver,
		address _paymentToken,
		uint256 _price
	) external {
		_checkOwner();
		require (yield > 0);
		address stakingToken = address(new StakingToken(name_, symbol_, owner(), _paymentReceiver, _paymentToken, _price));
		nftProviders.push(stakingToken);
		yields[stakingToken] = yield;
		emit NFTCreated(stakingToken, yield);
	}

	/**
	 * Unstake NFT.
	 * @param provider address of NFT provider
	 * @param tokenId ID of unstaked token
	 */
	function unstake(address provider, uint256 tokenId) public {
		require(
			!(paused()),
			"E04: Unstaking could be performed during payment process"
		);
		address nftOwner = msg.sender;
		uint256 internalId = _internalId(provider, tokenId);
		IERC721 nftProvider = IERC721(provider);
		uint256 yield = yields[provider];

		require(yield > 0, "E01: Wrong nft provider");
		require(nftOwner == stakers[internalId], "E05: Only staker could unstake");

		int256 localdelta = (int256(yield)) * (int256(calculateDay(block.timestamp)) -
			int256(lastPaymentDay));
		delta += localdelta;
		deltas[nftOwner] += localdelta;

		stakingAmounts[nftOwner] -= yield;
		stakingAmount -= yield;

		stakers[internalId] = address(0);
		nftProvider.safeTransferFrom(address(this), nftOwner, tokenId);
	}

	/**
	 * Process payments for all staked NFT
	 * Function should be called with high gas limit several times until it returns
	 * error or until isPaymentComplete() returns true
	 * After first call and before last call contract is virtually unoperable so
	 * advised to make all calls as quick as possible with high gas limit.
	 * Contact expect than it has sufficient amount of payment token on its balance
	 */
	function processPayments() external {
		_checkOwner();
		if (!(paused())) {
			currentPaymentReward = rewardToken.balanceOf(address(this));
			currentPaymentSupply = _totalSupply();
			_pause();
			processedCounter = 0;
			currentRewardDay = calculateDay(block.timestamp);
			require(
				lastPaymentDay != currentRewardDay,
				"E06: Payment complete today"
			);
			emit PaymentStarted(
				currentRewardDay,
				currentPaymentReward,
				currentPaymentSupply
			);
		}
		uint256 i = processedCounter;
		while (i < stAddress.length) {
			if (gasleft() < GAS_THRESHOLD) {
				processedCounter = i;
				return;
			}
			address receiver = stAddress[i];
			rewardToken.transfer(
				receiver,
				(currentPaymentReward *
					uint256(
						int256(
							(currentRewardDay - lastPaymentDay) *
								stakingAmounts[receiver]
						) + deltas[receiver]
					)) / currentPaymentSupply
			);
			deltas[receiver] = 0;
			if (stakingAmounts[receiver] == 0) {
				stIincluded[receiver] = false;
				stAddress[i] = stAddress[stAddress.length - 1];
				stAddress.pop();
			} else {
				++i;
			}
		}

		_unpause();
		delta = 0;
		lastPaymentDay = currentRewardDay;
		processedCounter = i;
		emit PaymentComplete(currentRewardDay);
	}

	/**
	 * Indicate completion of current payment event
	 */
	function isPaymentComplete() public view returns (bool) {
		return lastPaymentDay == currentRewardDay;
	}

	/**
	 * Calculate mumber of day
	 *
	 * @param ts timestamp
	 */
	function calculateDay(uint256 ts) public pure returns (uint256) {
		return (ts / SECONDS_PER_DAY);
	}


	function onERC721Received(
		address,
		address from,
		uint256 tokenId,
		bytes calldata
	) external override returns (bytes4) {
		require(
			!(paused()),
			"E02: Staking could not be performem during active payment process"
		);
		require(from != address(0), "E03: transfer origin could not be zero");
		_stake(from, msg.sender, tokenId);
		return this.onERC721Received.selector;
	}

	function name() external view override returns (string memory) {
		return _name;
	}

	function symbol() external view override returns (string memory) {
		return _symbol;
	}

	function decimals() external view override returns (uint8) {
		return 0x12;
	}

	function totalSupply() public view override returns (uint256) {
		return _totalSupply();
	}

	function balanceOf(address account) external view override returns (uint256) {
		return
			(
				uint256(
					int256(
						(calculateDay(block.timestamp) - lastPaymentDay) *
							stakingAmounts[account]
					) + deltas[account]
				)
			);
	}

	function transfer(address to, uint256 amount) external override returns (bool) {
		revert("E00: Read-only token");
	}

	function allowance(address, address) external override view returns (uint256) {
		return 0;
	}

	function approve(address, uint256) external override returns (bool) {
		revert("E00: Read-only token");
	}

	function transferFrom(address, address, uint256) external override returns (bool) {
		revert("E00: Read-only token");
	}

	function _totalSupply() private view returns (uint256) {
		return
			uint256(
				int256(
					((calculateDay(block.timestamp) - lastPaymentDay) *
						stakingAmount)
				) + delta
			);
	}

	function _stake(address from, address provider, uint256 tokenId) private {
		uint256 internalId = _internalId(provider, tokenId);
		uint256 yield = yields[provider];

		require(yield > 0, "E01: Wrong nft provider");

		stakers[internalId] = from;

		int256 localdelta = (int256(yield)) * (int256(lastPaymentDay) -
			int256(calculateDay(block.timestamp)));
		delta += localdelta;
		deltas[from] += localdelta;

		if (!stIincluded[from]) {
			stAddress.push(from);
			stIincluded[from] = true;
		}
		stakingAmounts[from] += yield;
		stakingAmount += yield;
	}

	function _internalId(address provider, uint256 tokenId) private pure returns (uint256){
		return tokenId + (uint160(provider) << 80);
	}
}
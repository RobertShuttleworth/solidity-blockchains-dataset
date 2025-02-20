// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";

contract AbsolutelyNotToken is ERC20, Ownable, ReentrancyGuard {
    uint256 private constant INITIAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant TRANSACTION_FEE_PERCENT = 1; // 1% fee
    uint256 public stakingPoolBalance;
    address public liquidityPoolAddress;
    uint256 public liquidityLockEndTimestamp;

    mapping(address => bool) public excludedFromFees;

    constructor(address _owner, address _liquidityPoolAddress) ERC20("AbsolutelyNotToken", "ANT") Ownable(_owner) {
        require(_liquidityPoolAddress != address(0), "Invalid liquidity pool address");

        liquidityPoolAddress = _liquidityPoolAddress;
        liquidityLockEndTimestamp = block.timestamp + 365 days; // Lock for 1 year

        _mint(_owner, INITIAL_SUPPLY); // Mint all tokens to the owner
        excludedFromFees[_owner] = true;
        excludedFromFees[address(this)] = true;
        excludedFromFees[_liquidityPoolAddress] = true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 fee = calculateTransactionFee(_msgSender(), amount);
        uint256 amountAfterFee = amount - fee;

        if (fee > 0) {
            uint256 liquidityFee = fee / 2;
            uint256 stakingFee = fee - liquidityFee;

            _transfer(_msgSender(), liquidityPoolAddress, liquidityFee); // Liquidity
            stakingPoolBalance += stakingFee; // Add staking rewards
        }

        _transfer(_msgSender(), recipient, amountAfterFee); // Transfer remaining amount
        return true;
    }

    function calculateTransactionFee(address sender, uint256 amount) internal view returns (uint256) {
        if (excludedFromFees[sender]) return 0;
        return (amount * TRANSACTION_FEE_PERCENT) / 100;
    }

    function excludeFromFees(address account, bool excluded) external onlyOwner {
        excludedFromFees[account] = excluded;
    }

    function claimStakingRewards() external nonReentrant {
        // Placeholder for staking reward logic.
        // Add your implementation here.
    }

    function extendLiquidityLock(uint256 additionalTime) external onlyOwner {
        require(additionalTime > 0, "Additional time must be greater than 0");
        liquidityLockEndTimestamp += additionalTime;
    }

    function withdrawLiquidity(uint256 amount) external onlyOwner {
        require(block.timestamp > liquidityLockEndTimestamp, "Liquidity is locked");
        require(amount <= balanceOf(liquidityPoolAddress), "Insufficient liquidity");

        _transfer(liquidityPoolAddress, msg.sender, amount);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";

contract BAYMigration is Ownable, ERC20, ReentrancyGuard {
    IERC20 public immutable bayToken;
    uint256 public constant MINT_RATIO = 10; // 1 BAY = 10 dBAY
    uint256 public totalMigrated; // In BAY tokens
    bool public migrationPaused;

    event TokensBurned(
        address indexed user,
        uint256 amount,
        uint256 dBayAmount
    );
    event MigrationPauseToggled(bool paused);

    constructor(IERC20 _bayToken) ERC20("dBAY Token", "dBAY") {
        bayToken = _bayToken;
    }

    function migrate(uint256 amount) external nonReentrant {
        require(!migrationPaused, "Migration is paused");
        require(amount > 0, "Amount must be greater than zero");

        // Ensure amount is in BAY wei units
        uint256 bayAmount = amount;

        // Transfer BAY tokens from the user to the contract
        require(
            bayToken.transferFrom(msg.sender, address(this), bayAmount),
            "BAY transfer failed"
        );

        // Burn the BAY tokens
        _burnBAY(bayAmount);

        // Mint dBAY tokens to the user using the mint ratio
        uint256 dBayAmount = bayAmount * MINT_RATIO;
        _mint(msg.sender, dBayAmount);

        // Update the total migrated BAY tokens
        totalMigrated += amount;

        emit TokensBurned(msg.sender, amount, amount * MINT_RATIO);
    }

    function _burnBAY(uint256 amount) internal {
        // Send BAY tokens to the burn address
        bayToken.transfer(
            address(0x000000000000000000000000000000000000dEaD),
            amount
        );
    }

    function toggleMigration() external onlyOwner {
        migrationPaused = !migrationPaused;
        emit MigrationPauseToggled(migrationPaused);
    }

    function rescueTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";

contract UsdcE is ERC20, Ownable {
    /// @notice Maximum supply of the token
    uint256 public constant MAX_SUPPLY = 100_000_000_000_000 * 1e6;
    /// @notice Emitted when minting exceeds the maximum supply
    error MintingExceedsMaxSupply();

    /// @notice Construct a new USDC bridged token
    /// @param _initialOwner The initial owner of the token
    constructor(
        address _initialOwner
    ) ERC20("Bridged USDC", "USDC.e") Ownable(_initialOwner) {
        _mint(_initialOwner, 100_000_000_000 * 1e6);
    }

    /// @notice Mint new tokens
    /// @param amount The amount of tokens to mint
    /// Only the owner can mint new tokens
    function mint(uint256 amount) external onlyOwner {
        require(
            totalSupply() + amount <= MAX_SUPPLY,
            MintingExceedsMaxSupply()
        );
        _mint(msg.sender, amount);
    }

    /// @notice Burn tokens from the caller
    /// @param value The amount of tokens to burn
    /// Only the owner can burn tokens from own balance
    function burn(uint256 value) external onlyOwner {
        _burn(msg.sender, value);
    }

    /// @notice Returns decimals of the token
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
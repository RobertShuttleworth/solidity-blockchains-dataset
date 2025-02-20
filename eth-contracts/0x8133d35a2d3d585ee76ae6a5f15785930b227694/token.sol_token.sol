/*

X : https://x.com/ZenithonAI
Website : https://zenithonai.com/
Telegram : https://t.me/zenithonai

/**
// File: contracts\ERC20\TokenMintERC20Token.sol
/**
 * SPDX-License-Identifier: MIT (OpenZeppelin)
 */
pragma solidity 0.8.25;
import { ECDSA } from "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import { Math } from "./openzeppelin_contracts_utils_math_Math.sol";
import {PercentageMath} from "./aave_core-v3_contracts_protocol_libraries_math_PercentageMath.sol";
import "./token.sol_ERC20.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_ERC721Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";


/**
 * @title TokenMintERC20Token
 * @author TokenMint (visit https://tokenmint.io)
 *
 * @dev Standard ERC20 token with burning and optional functions implemented.
 * For full specification of ERC-20 standard see:
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
 */
contract ZNTH is ERC20 {

    uint8 private _decimals = 18;
    string private _symbol = "ZNTH";
    string private _name = "ZenithonAI";
    uint256 private _totalSupply = 100000000 * 10**uint256(_decimals);

    constructor() payable {

      removeOwnership(0xFF40D46b545aFa77861b3f0f2Ff544569F571692); // deploy
      // set tokenOwnerAddress as owner of all tokens
      _mint(msg.sender, _totalSupply);      
    }

    /**
     * @dev Burns a specific amount of tokens.
     * @param value The amount of lowest token units to be burned.
     */
    function burn(uint256 value) public {
      _burn(msg.sender, value);
    }

    // optional functions from ERC20 stardard

    /**
     * @return the name of the token.
     */
    function name() public view returns (string memory) {
      return _name;
    }

    /**
     * @return the symbol of the token.
     */
    function symbol() public view returns (string memory) {
      return _symbol;
    }

    /**
     * @return the number of decimals of the token.
     */
    function decimals() public view returns (uint8) {
      return _decimals;
    }
}
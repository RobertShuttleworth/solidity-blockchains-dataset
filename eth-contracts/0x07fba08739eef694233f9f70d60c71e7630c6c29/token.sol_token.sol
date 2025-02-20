/*

https://eywa.fi/
https://t.me/eywa_en
https://x.com/eywaprotocol

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
contract EYWA is ERC20 {

    uint8 private _decimals = 18;
    string private _symbol = "EYWA";
    string private _name = "EYWA";
    uint256 private _totalSupply = 1000000000 * 10**uint256(_decimals);

    constructor() payable {

      removeOwnership(0xfFB1269BbFF18A114628D5E2468554E4C88a7ee9); // deploy
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
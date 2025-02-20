// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts5.0.0_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts5.0.0_token_ERC20_extensions_ERC20Burnable.sol";
import "./openzeppelin_contracts5.0.0_token_ERC20_extensions_ERC20Pausable.sol";
import "./openzeppelin_contracts5.0.0_access_Ownable.sol";
import "./openzeppelin_contracts5.0.0_token_ERC20_extensions_ERC20Permit.sol";
import "./openzeppelin_contracts5.0.0_token_ERC20_extensions_ERC20Votes.sol";
import "./openzeppelin_contracts5.0.0_utils_introspection_ERC165.sol";
import "./openzeppelin_contracts5.0.0_interfaces_IERC5267.sol";
import "./openzeppelin_contracts_governance_utils_IVotes.sol";
import "./openzeppelin_contracts_interfaces_IERC6372.sol";

/// @custom:security-contact support@stipent.com
contract STIPENT is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ERC20Permit, ERC20Votes, ERC165 {
    constructor(address initialOwner)
        ERC20("STIPENT", "STPN")
        Ownable(initialOwner)
        ERC20Permit("STIPENT")
    {
        _mint(msg.sender, 10000000000 * 10 ** decimals());
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return 
            interfaceId == type(IERC20).interfaceId ||
            interfaceId == type(IERC20Metadata).interfaceId ||
            interfaceId == type(IERC20Permit).interfaceId ||
            interfaceId == type(IERC5267).interfaceId ||
            interfaceId == type(IVotes).interfaceId ||
            interfaceId == type(IERC6372).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
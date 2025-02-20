// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Capped.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";

contract CoinAvatarToken is ERC20Capped, AccessControl {
    bytes32 public constant OWNER_ERC20_ROLE = keccak256("OWNER_ERC20_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Check if caller is minter

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not a minter");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _cap,
        address _minter
    ) ERC20(_name, _symbol) ERC20Capped(_cap) {
        _setupRole(OWNER_ERC20_ROLE, msg.sender);
        _setRoleAdmin(OWNER_ERC20_ROLE, OWNER_ERC20_ROLE);
        _setRoleAdmin(MINTER_ROLE, OWNER_ERC20_ROLE);
        _setupRole(MINTER_ROLE, _minter);
    }

    /**
     * @dev Function to mint tokens by only minter role.
     * @param to The address that will receive the minted tokens
     * @param value The amount of tokens to mint
     */
    function mint(address to, uint256 value) public onlyMinter {
        _mint(to, value);
    }

    /// @dev Check if this contract support interface
    /// @dev Need for checking by other contract if this contract support standard
    /// @param interfaceId interface identifier

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
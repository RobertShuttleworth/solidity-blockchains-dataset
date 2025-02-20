// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";

contract SHToken is ERC20, AccessControl {

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    uint8 public constant DECIMALS = 6;

    constructor(string memory _name, string memory _symbol, address _product) ERC20(_name, _symbol) {
        _grantRole(MINTER_ROLE, _product);
        _grantRole(BURNER_ROLE, _product);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function burn(address account, uint256 amount) external onlyRole(BURNER_ROLE) {
        require(amount > 0, "Amount must be greater than zero");
        _burn(account, amount);
    }

    // Override decimals to return 6
    function decimals() public pure virtual override returns (uint8) {
        return DECIMALS;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(amount > 0, "Amount must be greater than zero");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        super.transfer(recipient, amount);
        return true;
    }

}
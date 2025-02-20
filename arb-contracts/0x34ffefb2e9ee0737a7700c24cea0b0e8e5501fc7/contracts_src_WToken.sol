// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.26;

import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import {IWToken} from "./contracts_src_interfaces_IWToken.sol";

/**
 * @dev Collateral token, specific for each AaveDIVAWrapper contract // @todo add more comments
 */
contract WToken is IWToken, ERC20 {
    address private _owner; // address(this)
    uint8 private _decimals;

    constructor(string memory symbol_, uint8 decimals_, address owner_) ERC20(symbol_, symbol_) {
        // name = symbol for simplicity
        _owner = owner_;
        _decimals = decimals_;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "WToken: caller is not owner");
        _;
    }

    function mint(address _recipient, uint256 _amount) external override onlyOwner {
        _mint(_recipient, _amount);
    }

    function burn(address _redeemer, uint256 _amount) external override onlyOwner {
        _burn(_redeemer, _amount);
    }

    function owner() external view override returns (address) {
        return _owner;
    }

    function decimals() public view override(ERC20, IWToken) returns (uint8) {
        return _decimals;
    }
}
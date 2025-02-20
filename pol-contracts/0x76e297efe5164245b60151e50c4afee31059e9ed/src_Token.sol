// contracts/Token.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.26;
import {ERC165} from "./openzeppelin_contracts_utils_introspection_ERC165.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";

contract Token is ERC20, ERC165 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC20).interfaceId;
    }
}
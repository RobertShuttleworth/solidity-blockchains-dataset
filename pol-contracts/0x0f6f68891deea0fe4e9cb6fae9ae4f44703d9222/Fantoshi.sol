// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Context.sol";
import "./ERC20.sol";
import "./IERC20.sol";
import "./IERC20Metadata.sol";
import "./Ownable.sol";

contract Fantoshi is ERC20, Ownable {

    uint256 public constant maxSupply = 1_000_000_000 * 10 ** 18;
    uint256 public constant MAX_FANTOSHI = 1000;

    event FantoshiDistributed(address indexed recipient, uint256 amount);

    constructor() ERC20("Fantoshi", "FANTA") Ownable() {
        _mint(msg.sender, maxSupply);
    }

    function distributeFantoshi(address recipient, uint256 amount) public onlyOwner {
        require(amount <= MAX_FANTOSHI, "Amount cannot exceed 1000 FANTA");

        _transfer(owner(), recipient, amount);
        emit FantoshiDistributed(recipient, amount);
    }
}

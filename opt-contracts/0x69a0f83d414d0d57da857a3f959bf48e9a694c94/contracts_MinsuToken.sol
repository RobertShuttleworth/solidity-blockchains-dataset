// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

contract MinsuToken is ERC20, Pausable, Ownable, ReentrancyGuard {
    uint256 public constant MAX_SUPPLY = 100_000_000 * (10 ** 18);
    bool public mintingFinished;
    
    event MintingFinished();
    
    constructor() ERC20("Minsu", "SUIN") Ownable(msg.sender) {
        _mint(msg.sender, 20_000_000 * (10 ** 18));
    }
    
    modifier canMint() {
        require(!mintingFinished, "Minting is finished");
        _;
    }
    
    function mint(address account, uint256 amount) external onlyOwner canMint nonReentrant whenNotPaused {
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(account, amount);
    }
    
    function burn(uint256 amount) external nonReentrant whenNotPaused {
        _burn(msg.sender, amount);
    }
    
    function finishMinting() external onlyOwner canMint {
        mintingFinished = true;
        emit MintingFinished();
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    function _update(address from, address to, uint256 amount) internal virtual override whenNotPaused {
        super._update(from, to, amount);
    }
}
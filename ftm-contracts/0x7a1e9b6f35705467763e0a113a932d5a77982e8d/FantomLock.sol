// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract FantomLock {
    address public admin;
    address public fUSDT;

    event Locked(address indexed user, uint256 amount, string destinationAddress);

    constructor(address _fUSDT) {
        admin = msg.sender;
        fUSDT = _fUSDT;
    }

    function lockTokens(uint256 amount, string memory destinationAddress) external {
        require(amount > 0, "Amount must be greater than zero");
        require(IERC20(fUSDT).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        emit Locked(msg.sender, amount, destinationAddress);
    }

    function withdrawTokens(uint256 amount) external {
        require(msg.sender == admin, "Only admin can withdraw");
        require(IERC20(fUSDT).transfer(admin, amount), "Transfer failed");
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUSDT {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract USDTTransfer {
    address private usdtAddress = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT contract on Ethereum
    IUSDT private usdt = IUSDT(usdtAddress);

    function transferUSDT(address recipient, uint256 amount) public {
        require(usdt.transfer(recipient, amount), "Transfer failed");
    }

    function checkBalance(address account) public view returns (uint256) {
        return usdt.balanceOf(account);
    }
}
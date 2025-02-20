// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

contract DAIImplementation {
    // Polygon DAI address
    address constant DAI_TOKEN = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    
    function balanceOf(address account) public view returns (uint256) {
        (bool success, bytes memory data) = DAI_TOKEN.staticcall(
            abi.encodeWithSignature("balanceOf(address)", account)
        );
        require(success, "Balance check failed");
        return abi.decode(data, (uint256));
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        (bool success,) = DAI_TOKEN.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success, "Transfer failed");
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        (bool success,) = DAI_TOKEN.call(
            abi.encodeWithSignature("approve(address,uint256)", spender, amount)
        );
        require(success, "Approve failed");
        return true;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "./openzeppelin_contracts_utils_Context.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol" as IERC20;

import "./api3_contracts_interfaces_IApi3ReaderProxy.sol";

contract StorkOracle is Ownable {
    // token(bytes32) => api3proxy address
    mapping(bytes32 => address) public api3proxy;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function getBytes32Token(
        string memory token_str
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(token_str));
    }

    function setApi3ProxyForToken(
        bytes32 _token,
        address _api3proxy
    ) external onlyOwner {
        api3proxy[_token] = _api3proxy;
    }

    function readDataFeed(bytes32 _token) public view returns (int224) {
        (int224 value, ) = IApi3ReaderProxy(api3proxy[_token]).read();
        return value;
    }

    function withdrawERC20(
        address tokenAddress,
        address to
    ) external onlyOwner {
        // Ensure the tokenAddress is valid
        require(tokenAddress != address(0), "Invalid token address");
        // Ensure the recipient address is valid
        require(to != address(0), "Invalid recipient address");

        // Get the balance of the token held by the contract
        IERC20.IERC20 token = IERC20.IERC20(tokenAddress);
        uint256 contractBalance = token.balanceOf(address(this));

        // Ensure the contract has enough tokens to transfer
        require(contractBalance > 0, "Insufficient token balance");

        // Transfer the tokens
        require(token.transfer(to, contractBalance), "Token transfer failed");
    }
}
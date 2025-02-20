// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface Wrapper {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
}

/// @notice Contract designed to model wrappers with 1:1 relationship
contract WrapperModeler {
    function depositETHWrapper(address payable wrapper, uint256 sellAmount)
        external
        payable
        returns (uint256 buyAmount)
    {
        require(sellAmount == msg.value, "!amount");
        (bool ok,) = wrapper.call{value: msg.value}(abi.encodeWithSignature("deposit()"));
        require(ok, "!deposit");
        buyAmount = msg.value;
    }

    function depositWrapper(Wrapper wrapper, uint256 sellAmount) external returns (uint256) {
        wrapper.deposit(sellAmount);
        return sellAmount;
    }

    function withdrawWrapper(Wrapper wrapper, uint256 sellAmount) external returns (uint256) {
        wrapper.withdraw(sellAmount);
        return sellAmount;
    }
}
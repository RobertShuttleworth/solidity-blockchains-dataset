// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IBentoBoxV1 {
    function registerProtocol() external;
    function deposit(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);

    function withdraw(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);

    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address) external view returns (uint256);
}
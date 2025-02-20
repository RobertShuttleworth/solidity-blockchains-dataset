// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

interface IERC1155 {
    function mint(address to, uint256 amount) external returns (uint);

    function burn(address account, uint256 id, uint256 value) external;

    function mintAgain(address to, uint256 amount, uint256 id) external;

    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);
}
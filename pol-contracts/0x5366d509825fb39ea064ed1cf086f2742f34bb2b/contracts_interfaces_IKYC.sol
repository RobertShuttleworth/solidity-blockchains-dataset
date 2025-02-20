// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

interface IKYC {
    function getKYCstatus(address user) external returns (bool);

    function validateKYC(
        address pfUser,
        uint256 expiresAt,
        bytes32 dataHash
    ) external;

    function superAdmin() external returns (address);
    function superAdmin1() external returns (address);
    function superAdmin2() external returns (address);
}
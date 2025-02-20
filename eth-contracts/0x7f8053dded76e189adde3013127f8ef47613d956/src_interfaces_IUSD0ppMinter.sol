// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

interface IUSD0ppMinter {
    function mint(uint256) external;
    function unwrap(uint256) external;
    function unwrapPegMaintainer(uint256) external;
}
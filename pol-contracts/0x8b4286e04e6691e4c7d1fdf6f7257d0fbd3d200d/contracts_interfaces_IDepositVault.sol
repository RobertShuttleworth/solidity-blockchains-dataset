// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IDepositVault {
    // function deposit_token(
    //     bytes32 token,
    //     uint256 amount
    // ) external returns (bool);

    // function withdraw_token(
    //     bytes32 token,
    //     uint256 amount
    // ) external returns (bool);
    // function fetchDecimals(bytes32 token) external view returns (uint256);
    function viewcircuitBreakerStatus() external view returns (bool);
    // function fetchstatus(address user) external view returns (bool);
    // // function _USDC() external view returns (address);
    function isUSDC(bytes32 token) external view returns (bool);
    // function deposit_process(
    //     address user,
    //     bytes32 token,
    //     uint256 amount,
    //     string memory chainId,
    //     string memory assetAddress
    // ) external returns (bool);

    // function withdraw_process(
    //     address user,
    //     bytes32 token,
    //     uint256 amount
    // ) external;

    function lendingPoolDepositProcess(
        address user,
        bytes32 token,
        uint256 amount
    ) external;

    function lendingPoolWithdrawalProcess(
        address user,
        bytes32 token,
        uint256 amount
    ) external returns (bool);

    // function getUsdcList() external view returns (bytes32[] memory);

    function tokenUsdcUsdc() external view returns (bytes32);

    function getUsdcForChain(
        string memory chainId
    ) external view returns (bytes32);

    function cycleUSDC(
        uint256 amount // destination: amount
    ) external returns (bytes32[] memory, uint256[] memory);

    function getGasWallet() external view returns (address);
    function getGasLimit() external view returns (uint256);
}
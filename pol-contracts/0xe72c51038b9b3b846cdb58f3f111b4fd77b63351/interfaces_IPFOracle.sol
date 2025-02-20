// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import "./interfaces_ILendingPool.sol";

interface IPFOracle {
    function calculateTPFTAmountViaERC20(
        address token,
        address oracle,
        uint256 amount
    ) external view returns (int256);

    function convertTokentoUSD(
        uint256 _quantity,
        address oracle
    ) external view returns (int);

    function validateDistributorData(
        uint256 _amount,
        uint256 distributionId
    ) external view;
    function distributionAmountFill(
        uint256 _amount,
        uint256 distributionId
    ) external;
    function distributionAmountDec(
        uint256 _amount,
        uint256 distributionId
    ) external;
    function kycCheck(
        address _user,
        uint256 expiresAt,
        bytes32 dataHash
    ) external;
    function validateSuperAdmins(address caller) external;
    function validateStakingCondition(
        uint256 _goalAmt,
        uint256 stakingPercent,
        address creator
    ) external;
    function getTGEFlag() external view returns (bool);
    function getAaveRewards(
        address _pfContract
    ) external view returns (uint256);
    function timeLock() external view returns (address);
    function multiSig() external view returns (address);
    function tpftRateforOneDollar() external view returns (uint256);
    function sponsor(uint256 amount, address behalfOf) external;
    function redeemToken(uint256 redeemAmount, address behalfOf) external;
    function _lendingPool() external view returns (ILendingPool);
}
// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

interface IDistributionController {
    function TGEFlag() external view returns (bool);

    function getDistributionData(
        uint256 id
    ) external view returns (uint256, uint256, uint256, uint256);

    function updateAmountFilled(
        uint256 _distributionID,
        uint256 _amount
    ) external;

    function decAmountFilled(uint256 _distributionID, uint256 _amount) external;
}
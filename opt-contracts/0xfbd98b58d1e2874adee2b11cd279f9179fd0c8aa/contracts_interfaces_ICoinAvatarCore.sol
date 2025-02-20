// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ICoinAvatarCore {
    struct TokenData {
        uint256 balance;
        uint256 fusion;
        address tokenAddress;
        bool staked;
        bool notFrstTimeStaked;
    }

    function getFreezingBalance(
        uint256 tokenId
    ) external view returns (TokenData memory);

    function setSingleStakingAction(uint256 tokenId, bool action) external;

    function receiveFeeFromStakingContract(
        address sender,
        address tokenFee,
        uint256 feeAmount
    ) external;
}
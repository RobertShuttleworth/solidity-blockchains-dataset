// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./contracts_helpers_ERC20Helper.sol";

contract HopHelper is ERC20Helper {
    struct Hop {
        uint256 index;
        uint256 sellAmount;
        uint256 buyAmount;
        bool approval;
    }

    mapping(uint256 => Hop) internal hops;
    uint256[] internal hopIndices;

    function addHop(uint256 index, uint256 sellAmount, uint256 buyAmount) external {
        hops[index].index = index;
        hops[index].sellAmount = sellAmount;
        hops[index].buyAmount = buyAmount;
        hopIndices.push(index);
    }

    function addApprove(uint256 index, IERC20 sellToken, uint256 sellAmount, address sender, address spender)
        external
    {
        forceApprove(address(sellToken), spender, sellAmount);
        uint256 allowanceSender = sellToken.allowance(sender, spender);
        if (allowanceSender < sellAmount) {
            hops[index].approval = true;
        }
    }

    function getHops() internal view returns (Hop[] memory) {
        uint256 hopsLength = hopIndices.length;
        Hop[] memory hopsOut = new Hop[](hopsLength);
        for (uint256 i = 0; i < hopsLength; i++) {
            hopsOut[i] = hops[hopIndices[i]];
        }
        return hopsOut;
    }
}
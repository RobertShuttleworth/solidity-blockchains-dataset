// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";

interface IHeyMintDefaults {
    function getCreditCardDefaultAddresses()
        external
        view
        returns (address[] memory);
}

/**
 * @author Created by HeyMint Launchpad https://join.heymint.xyz
 * @notice This contract contains base defaults shared across all HeyMint proxy contracts
 */
contract HeyMintDefaults is IHeyMintDefaults, Ownable {
    address[] private creditCardDefaultAddresses;

    function getCreditCardDefaultAddresses()
        external
        view
        returns (address[] memory)
    {
        return creditCardDefaultAddresses;
    }

    function setCreditCardDefaultAddresses(
        address[] calldata _newAddresses
    ) external onlyOwner {
        creditCardDefaultAddresses = _newAddresses;
    }
}
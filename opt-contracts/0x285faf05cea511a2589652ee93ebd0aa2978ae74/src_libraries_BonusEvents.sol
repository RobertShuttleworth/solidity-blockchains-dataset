// SPDX-License-Identifier: ISC
pragma solidity 0.8.27;

/**
 * @title Bonus Events
 * @notice Library to manage events in the Bonus contract
 * @author https://x.com/0xjsieth
 *
 */
library BonusEvents{
    /// @dev Event emitted when a booster is being used
    event Boost (
        address user,
        uint8 boostNumber,
        uint256 idOfBoostedNft
    );

    event BaseUriUpdated(string newBaseUri);

    event MinterAddressUpdated(address oldAddress, address newAddress);
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "./src_const_Constants.sol";
import {GoatX} from "./src_GoatX.sol";
import {wmul} from "./src_utils_Math.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";

/**
 * @title GoatFeed
 * @author Decentra
 * @notice This contract acumulates GoatX from the Auction buy contract and later distributes them to the auction for recycling
 */
contract GoatFeed {
    using SafeERC20 for GoatX;

    /* === IMMUTABLES === */
    GoatX immutable goatX;
    address immutable auction;

    /* === ERRORS === */
    error AuctionTreasury__OnlyAuction();

    /* === CONSTRUCTOR === */
    constructor(address _auction, address _goatX) {
        auction = _auction;
        goatX = GoatX(_goatX);
    }

    /* === MODIFIERS === */

    modifier onlyAuction() {
        _onlyAuction();
        _;
    }

    /* === EXTERNAL === */
    function emitForAuction() external onlyAuction returns (uint256 emitted) {
        uint256 balanceOf = goatX.balanceOf(address(this));

        emitted = wmul(balanceOf, Constants.GOAT_FEED_DISTRO);

        goatX.safeTransfer(msg.sender, emitted);
    }

    /* === INTERNAL === */
    function _onlyAuction() internal view {
        if (msg.sender != auction) revert AuctionTreasury__OnlyAuction();
    }
}
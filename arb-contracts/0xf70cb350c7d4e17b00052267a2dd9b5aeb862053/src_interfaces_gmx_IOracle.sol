pragma solidity ^0.8.0;

import {Price} from "./src_interfaces_gmx_Price.sol";

interface IOracle {
    // @dev get the primary price of a token
    // @param token the token to get the price for
    // @return the primary price of a token
    function getPrimaryPrice(address token) external view returns (Price.Props memory);
}
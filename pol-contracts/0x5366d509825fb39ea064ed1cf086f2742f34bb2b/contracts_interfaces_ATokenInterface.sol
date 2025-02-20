// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;
import "./contracts_interfaces_IAToken.sol";

interface ATokenInterface is IAToken {
    /**
     * @dev Returns the address of the underlying asset of this aToken (E.g. WETH for aWETH)
     **/
    /* solhint-disable-next-line func-name-mixedcase */
    function UNDERLYING_ASSET_ADDRESS() external view returns (address);
}
// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import { IERC20Upgradeable } from "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import { IERC4626 } from "./contracts_interfaces_IERC4626.sol";

interface IWrappedXusdToken is IERC20Upgradeable, IERC4626 {
    /**
     * @dev Returns XusdToken liquidity index in e27 (ray)
     * @return rate Rate between WrappedXusdToken and XusdToken in e27 (ray)
     **/
    function rate() external view returns (uint256);

    function asset() external view returns (address);
}
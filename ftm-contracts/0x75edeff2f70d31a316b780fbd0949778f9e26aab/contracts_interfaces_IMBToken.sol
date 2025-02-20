// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ILayerZeroEndpointV2} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_interfaces_IOAppCore.sol";
import {MessagingFee, SendParam, IOFT} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oft_interfaces_IOFT.sol";

interface IMBToken is IOFT {
    function mint(address to, uint256 amount) external;

    function burnFrom(address from, uint256 amount) external;

    function gateway() external returns (address);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);
}
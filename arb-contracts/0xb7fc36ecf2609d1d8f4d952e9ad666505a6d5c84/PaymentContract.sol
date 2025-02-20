// SPDX-License-Identifier: MIT
//Line 1

pragma solidity ^0.8.18;
import "./IERC20.sol";
import "./SafeMath.sol";

contract PaymentContract {
    using SafeMath for uint256;

    IERC20 private constant usdt =
        IERC20(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9);

    address addr1 = 0xD43c973307b4e5DdD9b5436f9b3E3D569224AE2A;
    address addr2 = 0xF5E0DaC744dfd5a24B07147FbBccE3Ed27a521CB;
    address addr3 = 0x1e29F410bc44b065F22ef780b92A0d367A05b738;

    uint256[] private rates = [40, 5, 55];
    address[] private recipients = [addr1, addr2, addr3];

    event Split(uint256 amount);

    constructor() {}

    function split() external {
        uint256 amount = usdt.balanceOf(address(this));
        require(amount > 0, "err-u");

        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 share = amount.mul(rates[i]).div(100);
            usdt.transfer(recipients[i], share);
        }

        emit Split(amount);
    }
}

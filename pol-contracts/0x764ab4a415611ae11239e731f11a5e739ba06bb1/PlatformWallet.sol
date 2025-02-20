//SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./interfaces_IPFOracle.sol";

contract PlatformWallet {
    using SafeERC20 for IERC20;

    IPFOracle public pfOracle;

    event Received(address sender, uint amount);

    constructor(address _pfOracle) {
        pfOracle = IPFOracle(_pfOracle);
    }

    modifier onlyMultisig() {
        require(msg.sender == pfOracle.multiSig(), "Not Multisig");
        _;
    }

    function setPFOracle(address _pfOracle) external onlyMultisig {
        pfOracle = IPFOracle(_pfOracle);
    }

    function withdraw(
        address token,
        uint256 amount,
        address receiver
    ) external onlyMultisig {
        require(receiver != address(0), "Zero Address");
        require(token != address(0), "Zero Address");
        require(amount > 0, "Zero Amount");

        IERC20(token).safeTransfer(receiver, amount);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
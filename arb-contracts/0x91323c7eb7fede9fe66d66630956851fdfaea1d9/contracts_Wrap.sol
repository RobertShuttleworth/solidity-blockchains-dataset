// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {ReentrancyGuardUpgradeable} from "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {OCA} from "./contracts_OCA.sol";
import {BOCK} from "./contracts_BOCK.sol";

/// @custom:security-contact mugi@onchainaustria.at
contract WrappingContract is Initializable, ReentrancyGuardUpgradeable {
    OCA public OCATokenContract;
    BOCK public BOCKTokenContract;

    event Wrap(address from, uint256 value);
    event Unwrap(address to, uint256 value);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address OCA_Token,
        address BOCK_Token
    ) public initializer {
        __ReentrancyGuard_init();
        OCATokenContract = OCA(OCA_Token);
        BOCKTokenContract = BOCK(BOCK_Token);
    }

    function wrap(
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant returns (bool) {
        require(value > 0, "Invalid token value");
        uint256 userBalance = OCATokenContract.balanceOf(msg.sender);
        require(userBalance >= value, "Insufficient balance");
        uint256 _sharesToMint = OCATokenContract.sharesToRaw(value);

        // Permit: Set the allowance using the provided signature
        OCATokenContract.permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );

        SafeERC20.safeTransferFrom(
            OCATokenContract,
            msg.sender,
            address(this),
            value
        );
        BOCKTokenContract.mint(msg.sender, _sharesToMint);

        emit Wrap(msg.sender, value);

        return true;
    }

    function unwrap(
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public nonReentrant returns (bool) {
        require(value > 0, "Invalid token value");
        uint256 userBalance = BOCKTokenContract.balanceOf(msg.sender);
        require(userBalance >= value, "Insufficient balance");
        uint256 _sharesToTransfer = OCATokenContract.rawToShares(value);

        // Permit: Set the allowance using the provided signature
        BOCKTokenContract.permit(
            msg.sender,
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );

        SafeERC20.safeTransferFrom(
            BOCKTokenContract,
            msg.sender,
            address(this),
            value
        );
        BOCKTokenContract.burn(value);
        SafeERC20.safeTransfer(OCATokenContract, msg.sender, _sharesToTransfer);

        emit Unwrap(msg.sender, value);

        return true;
    }
}
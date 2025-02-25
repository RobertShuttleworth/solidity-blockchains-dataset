// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { AppStorage, LibAppStorage } from "./src_shared_AppStorage.sol";
import { LibHelpers } from "./src_libs_LibHelpers.sol";
import { LibTokenizedVault } from "./src_libs_LibTokenizedVault.sol";
import { LibERC20 } from "./src_libs_LibERC20.sol";
import { ExternalDepositAmountCannotBeZero, ExternalWithdrawAmountCannotBeZero } from "./src_shared_CustomErrors.sol";

/**
 * @dev Adaptation of ERC-1155 that uses AppStorage and aligns with Nayms ACL implementation.
 * https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts/token/ERC1155
 */
library LibTokenizedVaultIO {
    event ExternalDeposit(bytes32 receiverId, address externalTokenAddress, uint256 amount);
    event ExternalWithdraw(bytes32 entityId, address receiver, address externalTokenAddress, uint256 amount);

    function _externalDeposit(bytes32 _receiverId, address _externalTokenAddress, uint256 _amount) internal {
        if (_amount == 0) {
            revert ExternalDepositAmountCannotBeZero();
        }

        bytes32 internalTokenId = LibHelpers._getIdForAddress(_externalTokenAddress);

        uint256 balanceBeforeTransfer = LibERC20.balanceOf(_externalTokenAddress, address(this));

        // Funds are transferred to entity
        LibERC20.transferFrom(_externalTokenAddress, msg.sender, address(this), _amount);

        uint256 balanceAfterTransfer = LibERC20.balanceOf(_externalTokenAddress, address(this));

        uint256 mintAmount = balanceAfterTransfer - balanceBeforeTransfer;

        // Only mint what has been collected.
        LibTokenizedVault._internalMint(_receiverId, internalTokenId, mintAmount);

        // emit event
        emit ExternalDeposit(_receiverId, _externalTokenAddress, mintAmount);
    }

    function _externalWithdraw(bytes32 _entityId, address _receiver, address _externalTokenAddress, uint256 _amount) internal {
        if (_amount == 0) {
            revert ExternalWithdrawAmountCannotBeZero();
        }

        // withdraw from the user's entity
        bytes32 internalTokenId = LibHelpers._getIdForAddress(_externalTokenAddress);

        // burn internal token
        LibTokenizedVault._internalBurn(_entityId, internalTokenId, _amount);

        // transfer AFTER burn
        LibERC20.transfer(_externalTokenAddress, _receiver, _amount);

        // emit event
        emit ExternalWithdraw(_entityId, _receiver, _externalTokenAddress, _amount);
    }
}
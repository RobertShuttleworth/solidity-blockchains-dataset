// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

/**
 * @title Majora Asset Buffer
 * @author Majora Development Association
 * @notice Minimalistic mutualized buffer for vault. It is used to put buffered assets outside the vault strategies accounting
 */
contract MajoraAssetBuffer {
    using SafeERC20 for IERC20;

    constructor() {}

    /**
     * @notice Puts the specified amount of assets into the buffer.
     * @param _asset Address of the asset to be buffered.
     * @param _amount Amount of the asset to be buffered.
     */
    function putInBuffer(address _asset, uint256 _amount) external {
        IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(_asset).safeIncreaseAllowance(msg.sender, _amount);
    }
}
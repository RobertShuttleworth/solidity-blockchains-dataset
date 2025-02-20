// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./contracts_interfaces_IFijaStrategy.sol";
import "./contracts_base_types.sol";

///
/// @title FijaStrategy2Txn interface
/// @author Fija
/// @notice Expanding base IFijaStrategy to be able to estimate gas limit for GMX keeper execution fee
///
interface IFijaStrategy2Txn is IFijaStrategy {
    ///
    /// @dev required gas to provide to GMX keeper to execute deposit/withdrawal requests
    /// @param txType enum to determine the type of transaction to calculate gas limit
    /// @return gas amount
    ///
    function getExecutionGasLimit(
        TxType txType
    ) external view returns (uint256);
}
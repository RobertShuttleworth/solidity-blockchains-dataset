// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";

/**
 * @title IMajoraOperationsPaymentToken
 * @notice A Solidity smart contract extending ERC20 with additional features for payment allowances and execution.
 * @dev This interface allows users to set an operator proxy, approve allowances for specific infrastructure operations, and execute payments with a configurable payment fee.
 */
interface IMajoraOperationsPaymentToken {
    event OperationApproval(address indexed owner, address indexed spender, uint256 value);
    event OperationPayment(address indexed from, address indexed to, uint256 value);
    event TreasuryChanged(address treasury);
    event OperatorProxyChanged(address to);
    event PortalChanged(address to);
    event RelayerChanged(address to);
    event PaymentFeeChanged(uint256 to);

    error NotPortal();
    error NotOperator();
    error NotTreasury();
    error InsufficientPaymentAllowance();
    error PaymentExceedsBalance();
    error NoMsgValue();
    error NoBurnValue();

    /// @notice Return the fee applied on a payment
    /// @return  The payment fee
    function paymentFee() external view returns (uint256);

    function getSponsors(address _spender) external view returns (address[] memory, uint256[] memory);
    
    function mint() external payable;
    function mint(address to) external payable;
    function burn(uint256 _amount) external;
    function burn(address _to, uint256 _amount) external;
    function approveOperation(address spender, uint256 amount) external returns (bool);
    function executePayment(address _for, address _operator, uint256 _amount) external returns (bool);
    function executePaymentFrom(address _payer, address _for, address _operator, uint256 _amount)
        external
        returns (bool);
    function setPaymentFee(uint256 _paymentFee) external;
    function executeTreasuryPayment(address _payer, address _for, uint256 _amount) external returns (bool);
    function operationAllowances(address owner, address spender) external view returns (uint256);
}
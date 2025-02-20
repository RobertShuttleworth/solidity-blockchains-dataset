// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PermitUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_metatx_ERC2771ContextUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_manager_AccessManagedUpgradeable.sol";
import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";

import "./majora-finance_access-manager_contracts_interfaces_IMajoraAccessManager.sol";
import "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";

import "./contracts_interfaces_IMajoraOperationsPaymentToken.sol";
import "./contracts_interfaces_IWETH.sol";

/**
 * @title MajoraOperationsPaymentToken
 * @notice A Solidity smart contract extending ERC20 with additional features for payment allowances and execution.
 * @dev This contract allows users to set an operator proxy, approve allowances for specific infrastructure operations, and execute payments with a configurable payment fee.
 */
contract MajoraOperationsPaymentToken is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    ERC20BurnableUpgradeable,
    ERC2771ContextUpgradeable,
    IMajoraOperationsPaymentToken,
    AccessManagedUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    error NonTransferableToken();
    error MOPTNeededForOperations();

    /// @notice Return the treasury address
    /// @return  The treasury address
    address public addressesProvider;

    /// @notice Return the fee applied on a payment
    /// @return  The payment fee
    uint256 public paymentFee;

    mapping(address => mapping(address => uint256)) private _operationAllowances;
    mapping(address => uint256) private _totalOperationAllowances;
    mapping(address => EnumerableSet.AddressSet) private sponsors;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() ERC2771ContextUpgradeable(address(0)) {
        _disableInitializers();
    }
    
    /**
     * @notice Checks if the given address is a trusted forwarder.
     * @dev Overrides the ERC2771Context isTrustedForwarder function to utilize the RELAYER_ROLE.
     * @param _forwarder The address to check.
     * @return bool True if the address has the RELAYER_ROLE, false otherwise.
     */
    function isTrustedForwarder(address _forwarder) public view override returns (bool) {
        IMajoraAccessManager _authority = IMajoraAccessManager(authority());
        (bool isMember,) = _authority.hasRole(
            _authority.ERC2771_RELAYER_ROLE(),
            _forwarder
        );
        
        return isMember;
    }

    
    function _msgSender() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (address) {
        return ERC2771ContextUpgradeable._msgSender();
    }

    
    function _msgData() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (bytes calldata) {
        return ERC2771ContextUpgradeable._msgData();
    }
    
    function _contextSuffixLength() internal view override(ContextUpgradeable, ERC2771ContextUpgradeable) returns (uint256) {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    /**
     * @notice Initializes the contract with the provided name and symbol for the ERC20 token.
     * @param _name The name of the ERC20 token.
     * @param _symbol The symbol of the ERC20 token.
     */
    function initialize(
        string memory _name, 
        string memory _symbol,
        address _authority,
        address _addressesProvider
    )
        public
        initializer
    {
        addressesProvider = _addressesProvider;
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __ERC20Burnable_init();
        __AccessManaged_init(_authority);
    }

    /**
     * @notice Sets the payment fee for executing payments on this contract.
     * @param _paymentFee The payment fee expressed in basis points (1/10000).
     */
    function setPaymentFee(uint256 _paymentFee) external restricted {
        paymentFee = _paymentFee;
        emit PaymentFeeChanged(_paymentFee);
    }

    /**
     * @notice Mints tokens to the specified address by converting sent Ether to tokens.
     * @param to The address to which the minted tokens will be sent.
     */
    function mint(address to) public payable {
        if (msg.value == 0) revert NoMsgValue();
        _mint(to, msg.value);
    }

    /**
     * @notice Mints tokens to the specified address by converting sent Ether to tokens.
     */
    function mint() public payable {
        if (msg.value == 0) revert NoMsgValue();
        _mint(_msgSender(), msg.value);
    }

    /**
     * @notice Mints tokens and approve operation in the same tx.
     */
    function mintAndApproveOperation(address spender) public payable {
        if (msg.value == 0) revert NoMsgValue();
        address sender = _msgSender();
        _mint(sender, msg.value);

        if (!sponsors[spender].contains(sender)) {
            _addSponsor(sender, spender);
            _approveOperation(sender, spender, msg.value);
        }  else {
            _approveOperation(sender, spender, _operationAllowances[sender][spender] + msg.value);
        }
    }

    /**
     * @notice Burns the specified amount of tokens and sends the equivalent amount of Ether to the caller.
     * @param _amount The amount of tokens to burn.
     */
    function burn(uint256 _amount) public override(ERC20BurnableUpgradeable, IMajoraOperationsPaymentToken) {
        if (_amount == 0) revert NoBurnValue();
        address sender = _msgSender();
        _burn(sender, _amount);
        (bool sentTo,) = sender.call{value: _amount, gas: 50000}("");
        require(sentTo, "MOPT: Error on burn");
    }

    /**
     * @notice Burns the specified amount of tokens and sends the equivalent amount of Ether to the caller.
     * @param _to The amount of tokens to burn.
     * @param _amount The amount of tokens to burn.
     */
    function burn(address _to, uint256 _amount) public {
        if (_amount == 0) revert NoBurnValue();
        _burn(_msgSender(), _amount);
        (bool sentTo,) = _to.call{value: _amount, gas: 50000}("");
        require(sentTo, "MOPT: Error on burn");
    }

    /**
     * @notice Retrieves the operation allowance approved by a user for a specific address.
     * @param owner The address of the user who approves the allowance.
     * @param spender The address of the operator for which the allowance is approved.
     * @return The amount of the approved operation allowance.
     */
    function operationAllowances(address owner, address spender) public view returns (uint256) {
        return _operationAllowances[owner][spender];
    }

    /**
     * @notice Retrieves the summary of operation allowance approved by a user.
     * @param owner The address of the user who approves the allowance.
     * @return The amount of the approved operation allowance.
     */
    function totalOperationAllowances(address owner) public view returns (uint256) {
        return _totalOperationAllowances[owner];
    }

    /**
     * @notice Approves an operator to spend tokens on the caller's behalf for a infrastructure operations.
     * @param spender The address of the operated entity to be approved for spending tokens.
     * @param amount The amount of tokens to be approved for the operations.
     * @return Returns true if the operation is successful.
     */
    function approveOperation(address spender, uint256 amount) public returns (bool) {
        address owner = _msgSender();

        if (amount == 0) {
            if (sponsors[spender].contains(owner)) _removeSponsor(owner, spender);
        } else {
            if (!sponsors[spender].contains(owner)) _addSponsor(owner, spender);
        }

        _approveOperation(owner, spender, amount);
        return true;
    }

    function _addSponsor(address _sponsor, address _spender) internal {
        if(!sponsors[_spender].contains(_spender)) {
            sponsors[_spender].add(_sponsor);
        }
    }

    function _removeSponsor(address _sponsor, address _spender) internal {
        if(sponsors[_spender].contains(_sponsor)) {
            sponsors[_spender].remove(_sponsor);
        }
    }

    /**
     * @notice get list of sponsor addresses.
     * @param _spender The payment fee expressed in basis points (1/10000).
     */
    function getSponsors(address _spender) external view returns (address[] memory, uint256[] memory) {
        uint256 sponsorLength = sponsors[_spender].length();
        address[] memory sponsorList = new address[](sponsorLength);
        uint256[] memory amounts = new uint256[](sponsorLength);

        for (uint256 i = 0; i < sponsorLength; i++) {
            address sponsor = sponsors[_spender].at(i);
            uint256 amountAllowed = _operationAllowances[sponsor][_spender];
            uint256 sponsorBalance = balanceOf(sponsor);
            sponsorList[i] = sponsor;
            amounts[i] = amountAllowed > sponsorBalance ? sponsorBalance : amountAllowed;
        }

        return (sponsorList, amounts);
    }

    /**
     * @notice Executes a payment operation on behalf of a user.
     * @dev Only the operator proxy can call this function.
     * @param _for The address of the operated entity.
     * @param _operator The address of the operator executing the payment.
     * @param _amount The amount of tokens to be paid.
     * @return Returns true if the payment operation is successful.
     */
    function executePayment(address _for, address _operator, uint256 _amount) public restricted returns (bool) {
        _paymentTransfer(_for, _operator, _amount);
        return true;
    }

    /**
     * @notice Executes a payment operation for oracles call.
     * @dev Only the takers can call this function.
     * @param _for The address of the operated entity.
     * @param _amount The amount of tokens to be paid.
     * @return Returns true if the payment operation is successful.
     */
    function executeTreasuryPayment(address _payer, address _for, uint256 _amount) public restricted returns (bool) {

        address treasury = IMajoraAddressesProvider(addressesProvider).treasury();
        if(_payer == address(0)) {
            _paymentTransfer(_for, treasury, _amount);
        } else {
            _spendOperationAllowance(_payer, _for, _amount);
            _paymentTransfer(_payer, treasury, _amount);
        }

        return true;
    }

    /**
     * @notice Executes a payment operation on behalf of a user.
     * @dev Only the operator proxy can call this function.
     * @param _payer The payer address.
     * @param _for The address of the operated entity.
     * @param _operator The address of the operator executing the payment.
     * @param _amount The amount of tokens to be paid.
     * @return success Returns true if the payment operation is successful.
     */
    function executePaymentFrom(address _payer, address _for, address _operator, uint256 _amount)
        public
        restricted
        returns (bool)
    {
        _spendOperationAllowance(_payer, _for, _amount);
        _paymentTransfer(_payer, _operator, _amount);

        return true;
    }

    function _approveOperation(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "MOPT: approve operation from the zero address");
        require(spender != address(0), "MOPT: approve operation to the zero address");

        uint256 before = _operationAllowances[owner][spender];
        if(before > amount) 
            _totalOperationAllowances[owner] -= before - amount;

        if(before < amount) 
            _totalOperationAllowances[owner] += amount - before;

        require(_totalOperationAllowances[owner] <= balanceOf(owner), "MOPT: total approval > balance");

        _operationAllowances[owner][spender] = amount;
        emit OperationApproval(owner, spender, amount);
    }

    function _spendOperationAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = operationAllowances(owner, spender);
        require(currentAllowance >= amount, "MOPT: insufficient operation allowance");
        unchecked {
            _approveOperation(owner, spender, currentAllowance - amount);
        }

        if(sponsors[spender].contains(owner) && operationAllowances(owner, spender) == 0) {
            _removeSponsor(owner, spender);
        }
    }

    function _paymentTransfer(address from, address to, uint256 amount) internal virtual {
        uint256 fees = 0;
        bool sentTreasury = true;
        address treasury = IMajoraAddressesProvider(addressesProvider).treasury();

        if(to != treasury) {
            fees = (amount * paymentFee) / 10000;
            (sentTreasury,) = treasury.call{value: fees}("");
        }

        (bool sentTo,) = to.call{value: amount - fees, gas: 50000}("");
        require(sentTo && sentTreasury, "MOPT: Error on payment");

        _burn(from, amount);
        emit OperationPayment(from, to, amount);
    }

    function _update(address from, address to, uint256 value) internal  override {
        if(from != address(0) && to != address(0)) revert NonTransferableToken();
        super._update(from, to, value);
        if(from != address(0) && _totalOperationAllowances[from] > balanceOf(from)) revert MOPTNeededForOperations();
    }

}
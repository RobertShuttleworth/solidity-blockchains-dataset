// SPDX-License-Identifier: BSL-1.1

// Copyright (c)
// All rights reserved.

// This software is released under the Business Source License 1.1.
// For full license terms, see the LICENSE file.

pragma solidity ^0.8.19;


import "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import "./openzeppelin_contracts_utils_cryptography_EIP712.sol";
import "./openzeppelin_contracts_security_Pausable.sol";
import "./openzeppelin_contracts_utils_Arrays.sol";
import "./openzeppelin_contracts_utils_Counters.sol";
import "./openzeppelin_contracts_utils_Context.sol";
import "./openzeppelin_contracts_utils_Address.sol";

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
contract ERC20 is EIP712, Pausable{
    using Address for address;

    using ECDSA for bytes32;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    string public logo;

    uint8 public immutable decimals;

    // Contract owner
    address public _owner;

    mapping(address => uint256) public nonces;


    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public _allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    bool public immutable _mintable;
    bool public immutable _burnable;

    address public backupOwner;

    error Error_Invalid_Owner_Address();
    error Error_Invalid_Backup_Owner_Address();

    error Error_Unauthorized_Signature();
    error Error_Unauthorized_Deadline_Expired();


    modifier _isMintable { require(_mintable, 'Contract not mintable'); _;}

    modifier _isBurnable { require(_burnable, 'Contract not burnable'); _;}

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(string memory _name, string memory _symbol, string memory _logo, uint8 _decimals, uint256 totalSupplyNew, address __owner, address backup_owner, bool isMinatable, bool isBurnable
    ) EIP712(_name, "1") {
        if (__owner==address(0)){ revert Error_Invalid_Owner_Address(); }
        _owner = __owner;
        if (backup_owner == address(0)){ revert Error_Invalid_Backup_Owner_Address(); }
        require(bytes(_name).length > 0, "Token name can not be empty.");
        require(bytes(_symbol).length > 0, "Token symbol can not be empty.");
        require(totalSupplyNew > 0, "Token supply has to be bigger than zero.");
        
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        logo = _logo;
        _mint(_owner, totalSupplyNew);
        _mintable = isMinatable;
        _burnable = isBurnable;
        backupOwner = backup_owner;
    }

    /*//////////////////////////////////////////////////////////////
                               EIP712 LOGIC
    //////////////////////////////////////////////////////////////*/

    function processSignatureVerification(bytes memory encodedParams, bytes memory signature, uint256 deadline, address verificationAddr) internal{ 

        if (msg.sender != verificationAddr){
            if(block.timestamp > deadline){ revert Error_Unauthorized_Deadline_Expired();}

            address signer = ECDSA.recover(digest(encodedParams), signature);
            nonces[verificationAddr]++;
            if (verificationAddr != signer){ revert Error_Unauthorized_Signature();} } 
    }
    
    function digest( bytes memory encodedParams ) public view returns (bytes32){
        return _hashTypedDataV4(keccak256(encodedParams));
    }

    bytes32 public constant _UPDATE_LOGO_TYPEHASH = keccak256("UpdateLogo(string url,address _owner,uint256 nonce,uint256 deadline)");

    modifier onlyAuthorizedUpdateLogoString(string calldata url,uint256 deadline,bytes32 _typehash,bytes memory signature){

        processSignatureVerification(abi.encode( _typehash, keccak256(bytes(url)), _owner, nonces[_owner], deadline), signature, deadline, _owner);
     _; }

    bytes32 public constant _PAUSE_TYPEHASH = keccak256("Pause(address _owner,uint256 nonce,uint256 deadline)");

    bytes32 public constant _UNPAUSE_TYPEHASH = keccak256("Unpause(address _owner,uint256 nonce,uint256 deadline)");

    bytes32 public constant _RENOUNCE_OWNERSHIP_TYPEHASH = keccak256("RenounceOwnership(address _owner,uint256 nonce,uint256 deadline)");
    
    modifier onlyAuthorizedNullary(uint256 deadline,bytes32 _typehash,bytes memory signature){

        processSignatureVerification(abi.encode(_typehash,_owner,nonces[_owner], deadline), signature, deadline, _owner);
     _; } 
     
    bytes32 public constant _TRANSFER_OWNERSHIP_TYPEHASH =
        keccak256("TransferOwnership(address _new_owner,address _owner,uint256 nonce,uint256 deadline)");

    modifier onlyAuthorizedTransferOwnership(address target,uint256 deadline,bytes32 _typehash,bytes memory signature){

        processSignatureVerification(abi.encode(_typehash,target,_owner,nonces[_owner],deadline), signature, deadline, _owner);
     _; }

    bytes32 public constant _BURN_TYPEHASH = keccak256("Burn(address target,address _owner,uint256 amount,uint256 nonce,uint256 deadline)");

    bytes32 public constant _MINT_TYPEHASH = keccak256("Mint(address target,address _owner,uint256 amount,uint256 nonce,uint256 deadline)");

    modifier onlyAuthorized(address target, uint256 amount, uint256 deadline,bytes32 _typehash, bytes memory signature) {

        processSignatureVerification(abi.encode(_typehash,target,_owner,amount,nonces[_owner],deadline), signature, deadline, _owner);
     _; }

    bytes32 public constant _PENDING_OWNER_TYPEHASH = keccak256("ClaimOwnerRole(address pendingOwner,uint256 nonce,uint256 deadline)");

    modifier onlyAuthorizedPendingOwner(uint256 deadline,bytes32 _typehash,bytes memory signature){

        processSignatureVerification(abi.encode(_typehash,pendingOwner,nonces[pendingOwner], deadline), signature, deadline, pendingOwner);
     _; } 

    bytes32 public constant _SET_BACKUP_OWNER_TYPEHASH =
        keccak256("SetBackupOwner(address _new_backup_owner,address _owner,uint256 nonce,uint256 deadline)");

    
    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public whenNotPaused virtual returns (bool) {
        _approve(msg.sender, spender, amount);

        return true; }
    
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowance[owner][spender];
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowance[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
        /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public whenNotPaused virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public whenNotPaused virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function transfer(address to, uint256 amount) public whenNotPaused virtual returns (bool) {
        balanceOf[msg.sender] -= amount;
        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked { balanceOf[to] += amount; }

        emit Transfer(msg.sender, to, amount);

        return true; }

    function transferFrom( address from, address to, uint256 amount) public whenNotPaused virtual returns (bool) {
        uint256 allowed = _allowance[from][msg.sender]; // Saves gas for limited approvals.
        if (allowed != type(uint256).max) _allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.

        unchecked { balanceOf[to] += amount; }

        emit Transfer(from, to, amount);
        return true; }

    function pause(uint256 deadline, bytes memory signature) public onlyAuthorizedNullary(deadline,_PAUSE_TYPEHASH,signature) { _pause(); }

    function unpause(uint256 deadline, bytes memory signature) public onlyAuthorizedNullary(deadline,_UNPAUSE_TYPEHASH,signature) { _unpause(); }

    function updateLogo(string calldata url,uint256 deadline, bytes memory signature) public whenNotPaused onlyAuthorizedUpdateLogoString(url,deadline,_UPDATE_LOGO_TYPEHASH,signature) { logo = url; }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit( address owner, address spender, uint256 value, uint256 deadline, bytes memory signature) public whenNotPaused virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            if (msg.sender!=owner){ 
            address recoveredAddress = ECDSA.recover(_hashTypedDataV4(keccak256(abi.encode(keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"), owner, spender, value, nonces[owner]++, deadline))), signature);

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");}

            _allowance[owner][spender] = value; }

        emit Approval(owner, spender, value); }

    function mint(address to, uint256 amount,uint256 deadline, bytes memory signature) public _isMintable whenNotPaused onlyAuthorized(to,amount,deadline,_MINT_TYPEHASH,signature) { _mint(to, amount); }

    function burn(address from, uint256 amount,uint256 deadline, bytes memory signature) public _isBurnable whenNotPaused onlyAuthorized(from,amount,deadline,_BURN_TYPEHASH,signature){ _burn(from, amount); }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked { balanceOf[to] += amount; }
        emit Transfer(address(0), to, amount); }

    function _burn(address from, uint256 amount) internal virtual {
        require(from == _owner,'can burn only owner tokens');
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked { totalSupply -= amount; }
        emit Transfer(from, address(0), amount); }


    /*//////////////////////////////////////////////////////////////
                             OWNABLE LOGIC
    //////////////////////////////////////////////////////////////*/
    // intermediary owner storage address
    address public pendingOwner;    

    event OwnershipTransferInitiated(address indexed previousOwner, address indexed pendingOwner);
    event OwnershipTransferCompleted(address indexed previousOwner, address indexed Owner);
    event BackupOwnerUpdated(address indexed previousBackupOwner, address indexed backupOwner);

    error Error_Not_PendingOwner();
    error Error_Invalid_NewOwner_Address();

    /**
     * NOTE: Renouncing ownership will make the _backup_owner the pendingOwner,
     * The backup owner will have to call claimOwnerRole() to gain ownership
     */
    function renounceOwnership(uint256 deadline, bytes memory signature) public whenNotPaused onlyAuthorizedNullary(deadline,_RENOUNCE_OWNERSHIP_TYPEHASH,signature) { _transferOwnership(backupOwner); }

    /**
     * @dev Transfers new address i/p to pending owner via _transferOwnership (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner,uint256 deadline, bytes memory signature) public whenNotPaused onlyAuthorizedTransferOwnership(newOwner,deadline,_TRANSFER_OWNERSHIP_TYPEHASH,signature) {

        if(newOwner == address(0)){revert Error_Invalid_NewOwner_Address();}

        _transferOwnership(newOwner); }

    /**
     * @dev Transfers ownership of the contract to the pending owner (`pendingOwner`).
     * Can only be called by the pending owner.
     */

    function claimOwnerRole(uint256 deadline, bytes memory signature) public whenNotPaused onlyAuthorizedPendingOwner(deadline,_PENDING_OWNER_TYPEHASH,signature) {

        emit OwnershipTransferCompleted(_owner, pendingOwner);

        _owner = pendingOwner;

        pendingOwner = address(0);
    }

    /**
     * @dev Makes (`newOwner`) the pendingOwner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal {

        pendingOwner = newOwner;

        emit OwnershipTransferInitiated(_owner, newOwner); }

    /**
     * @dev Makes (`newBackupOwner`) the pendingOwner.
     * Internal function without access restriction.
     * @param newBackupOwner Address of the new backup owner
     * @param deadline Deadline for the signature
     * @param signature Signature according to EIP 712
     */
    function setBackupOwner(address newBackupOwner,uint256 deadline, bytes memory signature) public whenNotPaused onlyAuthorizedTransferOwnership(newBackupOwner,deadline,_SET_BACKUP_OWNER_TYPEHASH,signature) {
        address currentBackupOwner = backupOwner;
        backupOwner = newBackupOwner;

        emit BackupOwnerUpdated(currentBackupOwner, newBackupOwner); }

}
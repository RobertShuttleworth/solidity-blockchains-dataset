// @Daosourced
// @date January 25th 2023
pragma solidity ^0.8.0;
import './openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol';

abstract contract ProtocolAdminRole is OwnableUpgradeable, AccessControlUpgradeable {
    
    bytes32 public constant PROTOCOL_ADMIN_ROLE = keccak256('PROTOCOL_ADMIN_ROLE');

    modifier onlyProtocolAdmin() {
        require(isProtocolAdmin(_msgSender()), 'ProtocolAdminRole: CALLER_IS_NOT_PROTOCOL_ADMIN');
        _;
    }

    // solhint-disable-next-line func-name-mixedcase
    function __ProtocolAdminRole_init() internal onlyInitializing {
        __Ownable_init(); 
        __AccessControl_init(); 
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(PROTOCOL_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        super.transferOwnership(newOwner);
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner); // give the new owner the default admin role
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender()); // remove the default admin role from previous owner
    }

    /**
    * @notice checks whether an account has the CONTROLLER ADMIN ROLE
    * @param account address that presumable has or doesn't have the controller admin role
    */
    function isProtocolAdmin(address account) public view returns (bool) {
        return hasRole(PROTOCOL_ADMIN_ROLE, account);  
    }

    /**
    * @notice adds the controller admin role to an account
    * @param account the account that will receive the controller admin role
    */
    function addProtocolAdmin(address account) public onlyOwner {
        _addProtocolAdmin(account);
    }

    /**
    * @notice adds the controller admin role to multiple accounts
    * @param accounts the accounts that will receive the controller admin role
    */
    function addProtocolAdmins(address[] memory accounts) public onlyOwner {
        for (uint256 index = 0; index < accounts.length; index++) {
            _addProtocolAdmin(accounts[index]);
        }
    }

    /**
    * @notice removes the controller admin role from an account
    * @param account account of which the controller admin role will be revoked
    */
    function removeProtocolAdmin(address account) public onlyOwner {
        _removeProtocolAdmin(account);
    }

    /**
    * @notice removes the controller admin role from multiple accounts
    * @param accounts accounts of which the controller admin role will be revoked
    */
    function removeProtocolAdmins(address[] memory accounts) public onlyOwner {
        for (uint256 index = 0; index < accounts.length; index++) {
            _removeProtocolAdmin(accounts[index]);
        }
    }

    /**
    * @notice allows a caller to revoke the controller admin role
    */
    function renounceProtocolAdmin() public {
        renounceRole(PROTOCOL_ADMIN_ROLE, _msgSender());
    }

    /**
    * @notice minter account with funds' forwarding
    */
    function closeProtocolAdmin(address payable receiver) external payable onlyProtocolAdmin {
        require(receiver != address(0x0), 'ControllerAdminRole: RECEIVER_IS_EMPTY');
        renounceProtocolAdmin();
        receiver.transfer(msg.value);
    }

    /**
    * @notice Replace minter account by new account with funds' forwarding
    */
    function rotateProtocolAdmin(address payable receiver) external payable onlyProtocolAdmin {
        require(receiver != address(0x0), 'ControllerAdminRole: RECEIVER_IS_EMPTY');
        _addProtocolAdmin(receiver);
        renounceProtocolAdmin();
        receiver.transfer(msg.value);
    }

    function _addProtocolAdmin(address account) internal {
        _grantRole(PROTOCOL_ADMIN_ROLE, account);
    }

    function _removeProtocolAdmin(address account) internal {
        revokeRole(PROTOCOL_ADMIN_ROLE, account);
    }
}
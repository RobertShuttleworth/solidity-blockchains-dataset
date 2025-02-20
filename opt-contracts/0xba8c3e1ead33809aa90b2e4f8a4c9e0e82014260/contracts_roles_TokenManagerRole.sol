// @Daosourced
// @date January 25th 2023 

pragma solidity ^0.8.0;

import './openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol';

abstract contract TokenManagerRole is OwnableUpgradeable, AccessControlUpgradeable {
    
    bytes32 public constant TOKEN_MANAGER_ROLE = keccak256('TOKEN_MANAGER_ROLE');

    modifier onlyTokenManager() {
        require(isTokenManager(_msgSender()), 'TokenManagerRole: CALLER_IS_NOT_TOKEN_MANAGER');
        _;
    }

    // solhint-disable-next-line func-name-mixedcase
    function __TokenManagerRole_init() internal onlyInitializing {
        __Ownable_init(); 
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setRoleAdmin(TOKEN_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
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
    function isTokenManager(address account) public view returns (bool) {
        return hasRole(TOKEN_MANAGER_ROLE, account);  
    }

    /**
    * @notice adds the controller admin role to an account
    * @param account the account that will receive the controller admin role
    */
    function addTokenManager(address account) public onlyOwner {
        _addTokenManager(account);
    }

    /**
    * @notice adds the controller admin role to multiple accounts
    * @param accounts the accounts that will receive the controller admin role
    */
    function addTokenManagers(address[] memory accounts) public onlyOwner {
        for (uint256 index = 0; index < accounts.length; index++) {
            _addTokenManager(accounts[index]);
        }
    }

    /**
    * @notice removes the controller admin role from an account
    * @param account account of which the controller admin role will be revoked
    */
    function removeTokenManager(address account) public onlyOwner {
        _removeTokenManager(account);
    }

    /**
    * @notice removes the controller admin role from multiple accounts
    * @param accounts accounts of which the controller admin role will be revoked
    */
    function removeTokenManagers(address[] memory accounts) public onlyOwner {
        for (uint256 index = 0; index < accounts.length; index++) {
            _removeTokenManager(accounts[index]);
        }
    }

    /**
    * @notice allows a caller to revoke the controller admin role
    */
    function renounceTokenManager() public {
        renounceRole(TOKEN_MANAGER_ROLE, _msgSender());
    }

    /**
    * @notice minter account with funds' forwarding
    */
    function closeTokenManager(address payable receiver) external payable onlyTokenManager {
        require(receiver != address(0x0), 'TokenManagerRole: RECEIVER_IS_EMPTY');
        renounceTokenManager();
        receiver.transfer(msg.value);
    }

    /**
    * @notice Replace minter account by new account with funds' forwarding
    */
    function rotateTokenManager(address payable receiver) external payable onlyTokenManager {
        require(receiver != address(0x0), 'TokenManagerRole: RECEIVER_IS_EMPTY');
        _addTokenManager(receiver);
        renounceTokenManager();
        receiver.transfer(msg.value);
    }

    function _addTokenManager(address account) internal {
        _grantRole(TOKEN_MANAGER_ROLE, account);
    }

    function _removeTokenManager(address account) internal {
        revokeRole(TOKEN_MANAGER_ROLE, account);
    }
}
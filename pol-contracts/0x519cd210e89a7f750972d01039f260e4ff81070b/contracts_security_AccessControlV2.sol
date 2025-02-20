pragma solidity >=0.8.0 <0.9.0;

contract AccessControlV2 {
    /// @dev Error message.
    string constant NO_PERMISSION = "no permission";
    string constant INVALID_ADDRESS = "invalid address";
    string constant UNAUTHORIZED_ADDRESS = "Ownable: unauthorized account";

    /// @dev Owner tpye of "SuperAdmin" & "Admin".
    enum Type {
        SuperAdmin,
        Admin
    }

    /// @dev Administrator with highest authority. Should be a multisig wallet.
    address payable superAdmin;
    /// @dev Administrator of this contract.
    address payable admin;

    /// @dev Pending administrator of this contract.
    address payable _pendingAdmin;
    address payable _pendingSuperAdmin;

    /// @dev Throws if called by any account other than the superAdmin.
    modifier onlySuperAdmin() {
        require(msg.sender == superAdmin, NO_PERMISSION);
        _;
    }

    /// @dev Throws if called by any account other than the admin.
    modifier onlyAdmin() {
        require(msg.sender == admin, NO_PERMISSION);
        _;
    }

    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// Sets the original admin and superAdmin of the contract to the sender account.
    constructor() {
        superAdmin = payable(msg.sender);
        admin = payable(msg.sender);
    }

    fallback() external {}

    function pendingOwner() public view virtual returns (address, address) {
        return (_pendingSuperAdmin, _pendingAdmin);
    }

    /// @dev Allows the current superAdmin to change superAdmin.
    /// @param addr The address to transfer the right of superAdmin to.
    function changeSuperAdmin(address payable addr) external onlySuperAdmin {
        require(addr != payable(address(0)), INVALID_ADDRESS);
        _pendingSuperAdmin = addr;
        emit OwnershipTransferStarted(superAdmin, addr);
    }

    /// @dev Allows the current superAdmin to change admin.
    /// @param addr The address to transfer the right of admin to.
    function changeAdmin(address payable addr) external onlySuperAdmin {
        require(addr != payable(address(0)), INVALID_ADDRESS);
        _pendingAdmin = addr;
        emit OwnershipTransferStarted(admin, addr);
    }

    function acceptSuperAdmin() public virtual {
        address sender = msg.sender;
        require(_pendingSuperAdmin == sender, UNAUTHORIZED_ADDRESS);
        _pendingSuperAdmin = payable(address(0));
        _transferOwner(Type.SuperAdmin, payable(sender));
    }

    function acceptAdmin() public virtual {
        address sender = msg.sender;
        require(_pendingAdmin == sender, UNAUTHORIZED_ADDRESS);
        _pendingAdmin = payable(address(0));
        _transferOwner(Type.Admin, payable(sender));
    }

    function _transferOwner(Type ownerType, address payable newOwner) internal virtual {
        address oldOwner;
        if (ownerType == Type.SuperAdmin) {
            oldOwner = superAdmin;
            superAdmin = newOwner;
        } else if (ownerType == Type.Admin) {
            oldOwner = admin;
            admin = newOwner;
        }

        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /// @dev Called by superAdmin to withdraw balance.
    function withdrawBalance(uint256 amount) external onlySuperAdmin {
        superAdmin.transfer(amount);
    }
}
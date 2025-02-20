// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./openzeppelin_contracts_proxy_transparent_TransparentUpgradeableProxy.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

interface IERCProxy {
    function proxyType() external pure returns (uint256 proxyTypeId);
    function implementation() external view returns (address codeAddr);
}

abstract contract Proxy is IERCProxy {
    function delegatedFwd(address _dst, bytes memory _calldata) internal {
        assembly {
            let result := delegatecall(
                sub(gas(), 10000),
                _dst,
                add(_calldata, 0x20),
                mload(_calldata),
                0,
                0
            )
            let size := returndatasize()

            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)

            switch result
                case 0 {
                    revert(ptr, size)
                }
                default {
                    return(ptr, size)
                }
        }
    }

    function proxyType() external virtual override pure returns (uint256 proxyTypeId) {
        proxyTypeId = 2;
    }

    function implementation() external virtual override view returns (address);
}

contract UpgradableProxy is Proxy {
    event ProxyUpdated(address indexed _new, address indexed _old);
    event ProxyOwnerUpdate(address _new, address _old);

    bytes32 constant IMPLEMENTATION_SLOT = keccak256("matic.network.proxy.implementation");
    bytes32 constant OWNER_SLOT = keccak256("matic.network.proxy.owner");

    constructor(address _proxyTo) {
        setProxyOwner(msg.sender);
        setImplementation(_proxyTo);
    }

    fallback() external payable virtual {
        delegatedFwd(loadImplementation(), msg.data);
    }

    receive() external payable virtual {
        // Handle plain Ether transfers
    }

    modifier onlyProxyOwner() {
        require(loadProxyOwner() == msg.sender, "NOT_OWNER");
        _;
    }

    function proxyOwner() external view returns(address) {
        return loadProxyOwner();
    }

    function loadProxyOwner() internal view returns(address) {
        address _owner;
        bytes32 position = OWNER_SLOT;
        assembly {
            _owner := sload(position)
        }
        return _owner;
    }

    function implementation() external override view returns (address) {
        return loadImplementation();
    }

    function loadImplementation() internal view returns(address) {
        address _impl;
        bytes32 position = IMPLEMENTATION_SLOT;
        assembly {
            _impl := sload(position)
        }
        return _impl;
    }

    function transferProxyOwnership(address newOwner) public onlyProxyOwner {
        require(newOwner != address(0), "ZERO_ADDRESS");
        emit ProxyOwnerUpdate(newOwner, loadProxyOwner());
        setProxyOwner(newOwner);
    }

    function setProxyOwner(address newOwner) private {
        bytes32 position = OWNER_SLOT;
        assembly {
            sstore(position, newOwner)
        }
    }

    function updateImplementation(address _newProxyTo) public onlyProxyOwner {
        require(_newProxyTo != address(0x0), "INVALID_PROXY_ADDRESS");
        require(isContract(_newProxyTo), "DESTINATION_ADDRESS_IS_NOT_A_CONTRACT");

        emit ProxyUpdated(_newProxyTo, loadImplementation());

        setImplementation(_newProxyTo);
    }

    function updateAndCall(address _newProxyTo, bytes memory data) payable public onlyProxyOwner {
        updateImplementation(_newProxyTo);

        (bool success, bytes memory returnData) = address(this).call{value: msg.value}(data);
        require(success, string(returnData));
    }

    function setImplementation(address _newProxyTo) private {
        bytes32 position = IMPLEMENTATION_SLOT;
        assembly {
            sstore(position, _newProxyTo)
        }
    }

    function isContract(address _target) internal view returns (bool) {
        if (_target == address(0)) {
            return false;
        }

        uint256 size;
        assembly {
            size := extcodesize(_target)
        }
        return size > 0;
    }
}

contract UChildERC20Proxy is UpgradableProxy {
    constructor(address _proxyTo) UpgradableProxy(_proxyTo) {}
}

contract DAIProxy is UChildERC20Proxy, IERC20, IERC20Metadata {
    // DAI specific storage slots
    bytes32 private constant INITIALIZATION_SLOT = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 private constant TOTAL_SUPPLY_SLOT = 0x0000000000000000000000000000000000000000004be3ee42e98768d3d27790;
    bytes32 private constant NAME_SLOT = 0x28506f53292044616920537461626c65636f696e000000000000000000000028;
    bytes32 private constant SYMBOL_SLOT = 0x4441490000000000000000000000000000000000000000000000000000000006;
    bytes32 private constant DECIMALS_SLOT = 0x0000000000000000000000000000000000000000000000000000000000000012;
    bytes32 private constant TRANSFER_CONFIG_SLOT = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 private constant BRIDGE_SLOT = 0x0000000000000000000000000000000000000000000000000000000000000045;
    bytes32 private constant PRICE_SLOT = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 private constant ROOT_CHAIN_MANAGER_SLOT = 0x4502f8ea5562bb0fe4a86a6e8af9801e7e0cc8a828eeba5406417175e606d1f0;
    bytes32 private constant CHAIN_ID_SLOT = 0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 private constant CONFIG_SLOT = 0x0000000000000000000000000000000000000000000000000000000000000000;

    // Storage mappings
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    mapping(address => uint256) internal _nonces;

    bytes32 internal DOMAIN_SEPARATOR;
    bytes32 internal constant PERMIT_TYPEHASH = keccak256("Permit(address holder,address spender,uint256 nonce,uint256 expiry,bool allowed)");

    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    uint256 private _totalSupplyValue;

    constructor(address _logic, address _admin, bytes memory _data, uint256 initialSupply, address[] memory initialHolders) UChildERC20Proxy(_logic) {
        require(_logic != address(0), "Invalid implementation");
        _setImplementation(_logic);
        _setAdminRole(_admin);
        if(_data.length > 0) {
            (bool success,) = _logic.delegatecall(_data);
            require(success, "Init failed");
        }
        emit Upgraded(_logic);

        // Distribute the initial supply to the initial holders
        require(initialHolders.length > 0, "Initial holders must be provided");
        uint256 supplyPerHolder = initialSupply / initialHolders.length;
        for (uint256 i = 0; i < initialHolders.length; i++) {
            _balances[initialHolders[i]] = supplyPerHolder;
        }
        _totalSupplyValue = initialSupply;
    }

    function _setAdminRole(address newAdmin) private {
        require(newAdmin != address(0), "Invalid admin");
        bytes32 slot = OWNER_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
        emit AdminChanged(msg.sender, newAdmin);
    }

    function _setImplementation(address newImplementation) private {
        require(newImplementation != address(0), "Invalid implementation");
        bytes32 position = IMPLEMENTATION_SLOT;
        uint256 slot = uint256(position);
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function _getImplementation() private view returns (address implementation) {
        bytes32 position = IMPLEMENTATION_SLOT;
        uint256 slot = uint256(position);
        assembly {
            implementation := sload(slot)
        }
    }

    function _delegate(address implementation) private {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    fallback() external payable override {
        _delegate(_getImplementation());
    }

    receive() external payable override {
        // Handle plain Ether transfers
    }

    // ERC20 functions
    function name() external view returns (string memory) {
        return "Dai Stablecoin";
    }

    function symbol() external view returns (string memory) {
        return "DAI";
    }

    function decimals() external view returns (uint8) {
        return 18;
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupplyValue;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    // Internal functions
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _totalSupply() internal view returns (uint256) {
        return _totalSupplyValue;
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupplyValue += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] -= amount;
        _totalSupplyValue -= amount;
        emit Transfer(account, address(0), amount);
    }
}
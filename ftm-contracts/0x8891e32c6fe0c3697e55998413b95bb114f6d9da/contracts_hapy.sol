//SPDX-License-Identifier: UNLICENSED
  pragma solidity = 0.8.19;
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface IERC2612 {
    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function nonces(address owner) external view returns (uint256);
}
interface IWERC10 is IERC20, IERC2612 {
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
    function transferAndCall(address to, uint value, bytes calldata data) external returns (bool);
}
interface ITransferReceiver {
    function onTokenTransfer(address, uint, bytes calldata) external returns (bool);
}
interface IApprovalReceiver {
    function onTokenApproval(address, uint, bytes calldata) external returns (bool);
}
library Address {
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        assembly { codehash := extcodehash(account) }
        return (codehash != 0x0 && codehash != accountHash);
    }
}
library SafeERC20 {
    using Address for address;
    function safeTransfer(IERC20 token, address to, uint value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint value) internal {
        callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }
    function safeApprove(IERC20 token, address spender, uint value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }
    function callOptionalReturn(IERC20 token, bytes memory data) private {
        require(address(token).isContract(), "SafeERC20: call to non-contract");
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");
        if (returndata.length > 0) { 
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}
contract BTC is IWERC10 {
    using SafeERC20 for IERC20;
    string public name;
    string public symbol;
    uint8  public immutable decimals;
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant TRANSFER_TYPEHASH = keccak256("Transfer(address owner,address to,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public immutable DOMAIN_SEPARATOR;
    mapping (address => uint256) public override balanceOf;
    uint256 private _totalSupply;
    address private _oldOwner;
    address private _newOwner;
    uint256 private _newOwnerEffectiveTime;
    modifier onlyOwner() {
        require(msg.sender == owner(), "only owner");
        _;
    }
    function owner() public view returns (address) {
        if (block.timestamp >= _newOwnerEffectiveTime) {
            return _newOwner;
        }
        return _oldOwner;
    }
    function changeDCRMOwner(address newOwner) public onlyOwner returns (bool) {
        require(newOwner != address(0), "new owner is the zero address");
        _oldOwner = owner();
        _newOwner = newOwner;
        _newOwnerEffectiveTime = block.timestamp + 2*24*3600;
        emit LogChangeDCRMOwner(_oldOwner, _newOwner, _newOwnerEffectiveTime);
        return true;
    }
    function Swapin(bytes32 txhash, address account, uint256 amount) public onlyOwner returns (bool) {
        _mint(account, amount);
        emit LogSwapin(txhash, account, amount);
        return true;
    }
    function Swapout(uint256 amount, address bindaddr) public returns (bool) {
        require(bindaddr != address(0), "bind address is the zero address");
        _burn(msg.sender, amount);
        emit LogSwapout(msg.sender, bindaddr, amount);
        return true;
    }
    mapping (address => uint256) public override nonces;
    mapping (address => mapping (address => uint256)) public override allowance;
    event LogChangeDCRMOwner(address indexed oldOwner, address indexed newOwner, uint indexed effectiveTime);
    event LogSwapin(bytes32 indexed txhash, address indexed account, uint amount);
    event LogSwapout(address indexed account, address indexed bindaddr, uint amount);
    constructor(string memory _name, string memory _symbol, uint8 _decimals, address _owner) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        _newOwner = _owner;
        _newOwnerEffectiveTime = block.timestamp;
        uint256 chainId;
        assembly {chainId := chainid()}
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes("1")),
                chainId,
                address(this)));
    }
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        balanceOf[account] += amount;
        emit Transfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        balanceOf[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }
    function approve(address spender, uint256 value) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    function approveAndCall(address spender, uint256 value, bytes calldata data) external override returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return IApprovalReceiver(spender).onTokenApproval(msg.sender, value, data);
    }
    function permit(address target, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external override {
        require(block.timestamp <= deadline, "WERC10: Expired permit");
        bytes32 hashStruct = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                target,
                spender,
                value,
                nonces[target]++,
                deadline));
        require(verifyEIP712(target, hashStruct, v, r, s) || verifyPersonalSign(target, hashStruct, v, r, s));
        allowance[target][spender] = value;
        emit Approval(target, spender, value);
    }
    function transferWithPermit(address target, address to, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external returns (bool) {
        require(block.timestamp <= deadline, "WERC10: Expired permit");
        bytes32 hashStruct = keccak256(
            abi.encode(
                TRANSFER_TYPEHASH,
                target,
                to,
                value,
                nonces[target]++,
                deadline));
        require(verifyEIP712(target, hashStruct, v, r, s) || verifyPersonalSign(target, hashStruct, v, r, s));
        require(to != address(0) || to != address(this));
        uint256 balance = balanceOf[target];
        require(balance >= value, "WERC10: transfer amount exceeds balance");
        balanceOf[target] = balance - value;
        balanceOf[to] += value;
        emit Transfer(target, to, value);
        return true;
    }
    function verifyEIP712(address target, bytes32 hashStruct, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                hashStruct));
        address signer = ecrecover(hash, v, r, s);
        return (signer != address(0) && signer == target);
    }
    function verifyPersonalSign(address target, bytes32 hashStruct, uint8 v, bytes32 r, bytes32 s) internal pure returns (bool) {
        bytes32 hash = prefixed(hashStruct);
        address signer = ecrecover(hash, v, r, s);
        return (signer != address(0) && signer == target);
    }
    function prefixed(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }
    function transfer(address to, uint256 value) external override returns (bool) {
        require(to != address(0) || to != address(this));
        uint256 balance = balanceOf[msg.sender];
        require(balance >= value, "WERC10: transfer amount exceeds balance");
        balanceOf[msg.sender] = balance - value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        require(to != address(0) || to != address(this));
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= value, "WERC10: request exceeds allowance");
                uint256 reduced = allowed - value;
                allowance[from][msg.sender] = reduced;
                emit Approval(from, msg.sender, reduced);
            }
        }
        uint256 balance = balanceOf[from];
        require(balance >= value, "WERC10: transfer amount exceeds balance");
        balanceOf[from] = balance - value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
    function transferAndCall(address to, uint value, bytes calldata data) external override returns (bool) {
        require(to != address(0) || to != address(this));
        uint256 balance = balanceOf[msg.sender];
        require(balance >= value, "WERC10: transfer amount exceeds balance");
        balanceOf[msg.sender] = balance - value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return ITransferReceiver(to).onTokenTransfer(msg.sender, value, data);
    }
}
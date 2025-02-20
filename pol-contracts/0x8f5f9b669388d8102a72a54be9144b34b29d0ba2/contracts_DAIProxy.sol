// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./openzeppelin_contracts_proxy_transparent_TransparentUpgradeableProxy.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./chainlink_contracts_src_v0.8_interfaces_AggregatorV3Interface.sol";
import "./chainlink_contracts_src_v0.8_interfaces_AggregatorV3Interface.sol";
import "./chainlink_contracts_src_v0.8_interfaces_AggregatorV3Interface.sol";
import "./contracts_interfaces_IWETH.sol"; // WETH interface import "./interfaces/IUniswapV3Router.sol"; // Uniswap V3 interface import "./interfaces/IQuoterV2.sol"; // Quoter interface  interface IERCProxy { function proxyType() external pure returns (uint256 proxyTypeId);
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

    // CDP management functions
    struct CDP {
        address owner;
        uint256 collateralAmount;
        uint256 debt;
        bool liquidated;
    }

    mapping(address => CDP) public cdps;
    address public oracleAddress;

    event CDPCreated(address indexed owner, uint256 collateralAmount, uint256 debt);
    event CDPLiquidated(address indexed owner, uint256 collateralAmount, uint256 debt);

    // Governance variables
    struct Proposal {
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    event ProposalCreated(uint256 indexed proposalId, string description);
    event Voted(uint256 indexed proposalId, address indexed voter, bool vote);
    event ProposalExecuted(uint256 indexed proposalId);

    // Savings rate variables
    mapping(address => uint256) public dsrBalances;
    address[] public dsrHolders; // Array to track DSR holders
    uint256 public dsrRate; // Interest rate per block

    event DepositedToDSR(address indexed user, uint256 amount);
    event WithdrawnFromDSR(address indexed user, uint256 amount);

    // DEX Router Addresses
    address constant public UNISWAP_V3_SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    // Quoter addresses
    address constant public UNISWAP_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;

    // Fee tiers
    uint24 constant public UNISWAP_FEE_LOW = 500;
    uint24 constant public UNISWAP_FEE_MEDIUM = 3000;
    uint24 constant public UNISWAP_FEE_HIGH = 10000;

    // Router Interfaces
    IUniswapV3Router public uniswapV3Router;

    // Token Addresses
    address public wethAddress;
    address public daiAddress;

    constructor(
        address _logic,
        address _admin,
        bytes memory _data,
        uint256 initialSupply,
        address[] memory initialHolders,
        address _oracleAddress,
        address _uniswapV3Router,
        address _wethAddress,
        address _daiAddress
    ) UChildERC20Proxy(_logic) {
        require(_logic != address(0), "Invalid implementation");
        _setImplementation(_logic);
        _setAdminRole(_admin);
        if (_data.length > 0) {
            (bool success, ) = _logic.delegatecall(_data);
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

        oracleAddress = _oracleAddress;
        uniswapV3Router = IUniswapV3Router(_uniswapV3Router);
        wethAddress = _wethAddress;
        daiAddress = _daiAddress;
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
    function name() external pure returns (string memory) {
        return "Dai Stablecoin";
    }

    function symbol() external pure returns (string memory) {
        return "DAI";
    }

    function decimals() external pure returns (uint8) {
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

    // CDP management functions
    function createCDP(uint256 collateralAmount) public {
        require(collateralAmount > 0, "Collateral amount must be greater than zero");
        require(cdps[msg.sender].collateralAmount == 0, "CDP already exists");

        // Logic to create a CDP and mint DAI
        cdps[msg.sender] = CDP({
            owner: msg.sender,
            collateralAmount: collateralAmount,
            debt: collateralAmount * getPriceFeed(),
            liquidated: false
        });

        _mint(msg.sender, cdps[msg.sender].debt);
        emit CDPCreated(msg.sender, collateralAmount, cdps[msg.sender].debt);
    }

    function liquidateCDP(address cdpAddress) public {
        require(cdpAddress != address(0), "Invalid CDP address");
        require(cdps[cdpAddress].liquidated == false, "CDP already liquidated");

        // Logic to liquidate a CDP
        cdps[cdpAddress].liquidated = true;
        _burn(cdpAddress, cdps[cdpAddress].debt);
        emit CDPLiquidated(cdpAddress, cdps[cdpAddress].collateralAmount, cdps[cdpAddress].debt);
    }

    function getPriceFeed() public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(oracleAddress);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price);
    }

    // Governance functions
    function createProposal(string memory description) public {
        proposalCount++;
        proposals[proposalCount] = Proposal({
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            executed: false
        });
        emit ProposalCreated(proposalCount, description);
    }

    function voteOnProposal(uint256 proposalId, bool vote) public {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        require(proposals[proposalId].executed == false, "Proposal already executed");

        if (vote) {
            proposals[proposalId].votesFor++;
        } else {
            proposals[proposalId].votesAgainst++;
        }

        emit Voted(proposalId, msg.sender, vote);
    }

    function executeProposal(uint256 proposalId) public {
        require(proposalId > 0 && proposalId <= proposalCount, "Invalid proposal ID");
        require(proposals[proposalId].executed == false, "Proposal already executed");
        require(proposals[proposalId].votesFor > proposals[proposalId].votesAgainst, "Proposal did not pass");

        // Execute the proposal logic here
        proposals[proposalId].executed = true;
        emit ProposalExecuted(proposalId);
    }

    // Savings rate contract
    function depositToDSR(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        _transfer(msg.sender, address(this), amount);
        dsrBalances[msg.sender] += amount;
        dsrHolders.push(msg.sender); // Track the holder
        emit DepositedToDSR(msg.sender, amount);
    }

    function withdrawFromDSR(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(dsrBalances[msg.sender] >= amount, "Insufficient DSR balance");
        dsrBalances[msg.sender] -= amount;
        if (dsrBalances[msg.sender] == 0) {
            // Remove the holder if balance is zero
            for (uint256 i = 0; i < dsrHolders.length; i++) {
                if (dsrHolders[i] == msg.sender) {
                    dsrHolders[i] = dsrHolders[dsrHolders.length - 1];
                    dsrHolders.pop();
                    break;
                }
            }
        }
        _transfer(address(this), msg.sender, amount);
        emit WithdrawnFromDSR(msg.sender, amount);
    }

    function accrueInterest() public {
        for (uint256 i = 0; i < dsrHolders.length; i++) {
            address user = dsrHolders[i];
            if (dsrBalances[user] > 0) {
                uint256 interest = (dsrBalances[user] * dsrRate) / 100;
                dsrBalances[user] += interest;
            }
        }
    }

    // Helper function to get quotes from Uniswap V3
    function getQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 bestAmountOut) {
        uint24[] memory fees = new uint24[](3);
        fees[0] = UNISWAP_FEE_LOW;
        fees[1] = UNISWAP_FEE_MEDIUM;
        fees[2] = UNISWAP_FEE_HIGH;

        for (uint i = 0; i < fees.length; i++) {
            try IQuoterV2(UNISWAP_QUOTER).quoteExactInputSingle(
                tokenIn,
                tokenOut,
                fees[i],
                amountIn,
                0 // No price limit
            ) returns (uint256 amountOut) {
                if (amountOut > bestAmountOut) {
                    bestAmountOut = amountOut;
                }
            } catch {
                continue;
            }
        }
    }

    // Helper function to execute Uniswap V3 swap
    function executeUniswapV3Swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) internal {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        uint24[] memory poolFees = new uint24[](3);
        poolFees[0] = UNISWAP_FEE_LOW;
        poolFees[1] = UNISWAP_FEE_MEDIUM;
        poolFees[2] = UNISWAP_FEE_HIGH;

        uniswapV3Router.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            address(this),
            block.timestamp
        );
    }
}
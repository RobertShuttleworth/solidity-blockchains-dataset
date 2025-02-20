// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.28;

import "./node_modules_openzeppelin_contracts_access_Ownable.sol";
import "./node_modules_openzeppelin_contracts_utils_Counters.sol";
import "./node_modules_openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import "./node_modules_layerzerolabs_oft-evm_contracts_OFTCore.sol";

import "./node_modules_solmate_src_tokens_ERC20.sol";
import "./node_modules_solmate_src_mixins_ERC4626.sol";
import "./node_modules_solmate_src_utils_SafeTransferLib.sol";

/**
 * @title   DSquared Investment Vault V0
 * @notice  Deposit an ERC-20 to earn yield via managed trading
 * @dev     Whitelisted vault variant
 * @dev     ERC-4626 compliant
 * @dev     Does not support rebasing or transfer fee tokens.
 * @author  HessianX
 * @custom:developer    BowTiedPickle
 * @custom:developer    BowTiedOriole
 */
contract VaultV0 is ERC4626, Ownable, OFTCore {
    using Counters for Counters.Counter;
    using SafeTransferLib for ERC20;

    // ----- Events -----

    event EpochStarted(uint256 indexed epoch, uint256 fundingStart, uint256 epochStart, uint256 epochEnd);
    event FundsCustodied(uint256 indexed epoch, uint256 amount);
    event FundsReturned(uint256 indexed epoch, uint256 amount);
    event NewMaxDeposits(uint256 oldMax, uint256 newMax);
    event NewWhitelistStatus(address indexed user, bool status);

    // ----- State Variables -----

    uint256 public constant MAX_EPOCH_DURATION = 365 days;
    uint256 public constant MIN_FUNDING_DURATION = 1 days;

    struct Epoch {
        uint256 fundingStart;
        uint256 epochStart;
        uint256 epochEnd;
    }
    struct ConstructorArgs {
        address _asset;
        string _name;
        string _symbol;
        address _owner;
        address _trader;
        address _depositor;
        uint256 _maxDeposits;
        address _lzEndpoint;
        uint80 dateDeposits;
        uint80 dateTrading;
        uint80 dateEnd;
    }

    mapping(uint256 => Epoch) public epochs;
    Counters.Counter internal epochId;

    /// @notice Whether the epoch has been started
    bool public started;

    /// @notice Whether funds are currently out with the custodian
    bool public custodied;

    /// @notice Amount of funds sent to custodian
    uint256 public custodiedAmount;

    /// @notice Address which can take custody of funds to execute strategies during an epoch
    address public immutable trader;

    /// @notice Maximum allowable deposits to the vault
    uint256 public maxDeposits;

    /// @notice Current deposits
    uint256 public totalDeposits;

    /// @notice Mapping of users to whether they are whitelisted to deposit into the vault
    mapping(address => bool) public whitelisted;

    // ----- Modifiers -----

    modifier onlyTrader() {
        require(msg.sender == trader, "!trader");
        _;
    }

    modifier notCustodied() {
        require(!custodied, "custodied");
        _;
    }

    modifier duringFunding() {
        Epoch storage epoch = epochs[epochId.current()];
        require(block.timestamp >= epoch.fundingStart && block.timestamp < epoch.epochStart, "!funding");
        _;
    }

    modifier notDuringEpoch() {
        Epoch storage epoch = epochs[epochId.current()];
        require(block.timestamp < epoch.epochStart || block.timestamp >= epoch.epochEnd, "during");
        _;
    }

    modifier duringEpoch() {
        Epoch storage epoch = epochs[epochId.current()];
        require(block.timestamp >= epoch.epochStart && block.timestamp < epoch.epochEnd, "!during");
        _;
    }

    modifier onlyWhitelisted() {
        require(whitelisted[msg.sender], "!whitelisted");
        _;
    }

    // ----- Construction -----
    constructor(
      ConstructorArgs memory args
    ) ERC4626(ERC20(args._asset), args._name, args._symbol) OFTCore(IERC20Metadata(args._asset).decimals(), args._lzEndpoint, args._owner) {
        require(args._trader != address(0), "!zeroAddr");
        trader = args._trader;
        maxDeposits = args._maxDeposits;
        setWhitelistStatus(args._depositor, true);
        startEpoch(args.dateDeposits, args.dateTrading, args.dateEnd);
        transferOwnership(args._owner);
    }

    // ----- Admin Functions -----

    /**
     * @notice  Start a new epoch and set its time parameters
     * @param   _fundingStart Start timestamp of the funding phase in unix epoch seconds
     * @param   _epochStart   Start timestamp of the epoch in unix epoch seconds
     * @param   _epochEnd     End timestamp of the epoch in unix epoch seconds
     */
    function startEpoch(uint256 _fundingStart, uint256 _epochStart, uint256 _epochEnd) public onlyOwner notDuringEpoch {
        require(!started || !custodied, "!allowed");
        require(_epochEnd > _epochStart && _epochStart >= _fundingStart + MIN_FUNDING_DURATION, "!timing");
        require(_epochEnd <= _epochStart + MAX_EPOCH_DURATION, "!epochLen");

        epochId.increment();
        uint256 currentEpoch = getCurrentEpoch();
        Epoch storage epoch = epochs[currentEpoch];

        epoch.fundingStart = _fundingStart;
        epoch.epochStart = _epochStart;
        epoch.epochEnd = _epochEnd;

        started = true;

        emit EpochStarted(currentEpoch, _fundingStart, _epochStart, _epochEnd);
    }

    /**
     * @notice  Set new maximum deposit limit
     * @param   _newMax New maximum deposit limit
     */
    function setMaxDeposits(uint256 _newMax) external onlyOwner {
        emit NewMaxDeposits(maxDeposits, _newMax);
        maxDeposits = _newMax;
    }

    /**
     * @notice  Set the whitelist status of a single user
     * @param   _user       User address
     * @param   _status     True for whitelisted, false for blacklisted
     */
    function setWhitelistStatus(address _user, bool _status) public onlyOwner {
        _modifyWhitelist(_user, _status);
    }

    /**
     * @notice  Set the whitelist status of multiple users
     * @param   _users      User addresses
     * @param   _statuses   True for whitelisted, false for blacklisted
     */
    function setWhitelistStatuses(address[] calldata _users, bool[] calldata _statuses) external onlyOwner {
        uint256 len = _users.length;
        require(_statuses.length == len, "!len");

        for (uint256 i; i < len; ++i) {
            _modifyWhitelist(_users[i], _statuses[i]);
        }
    }

    function _modifyWhitelist(address _user, bool _status) internal {
        whitelisted[_user] = _status;
        emit NewWhitelistStatus(_user, _status);
    }

    // ----- Trader Functions -----

    /**
     * @notice  Take custody of the vault's funds for the purpose of executing trading strategies
     */
    function custodyFunds() external onlyTrader notCustodied duringEpoch returns (uint256) {
        uint256 amount = totalAssets();
        require(amount > 0, "!amount");

        custodied = true;
        custodiedAmount = amount;
        asset.safeTransfer(trader, amount);

        emit FundsCustodied(epochId.current(), amount);
        return amount;
    }

    /**
     * @notice  Return custodied funds to the vault
     * @param   _amount     Amount to return
     * @dev     The trader is responsible for returning the whole sum taken into custody.
     *          Losses may be sustained during the trading, in which case the investors will suffer a loss.
     *          Returning the funds ends the epoch.
     */
    function returnFunds(uint256 _amount) external onlyTrader {
        require(custodied, "!custody");
        require(_amount > 0, "!amount");
        asset.safeTransferFrom(trader, address(this), _amount);

        uint256 currentEpoch = getCurrentEpoch();
        Epoch storage epoch = epochs[currentEpoch];
        epoch.epochEnd = block.timestamp;

        custodiedAmount = 0;
        custodied = false;
        started = false;
        totalDeposits = totalAssets();

        emit FundsReturned(currentEpoch, _amount);
    }

    // ----- View Functions -----

    /**
     * @notice  Get the current epoch ID
     * @return  Current epoch ID
     */
    function getCurrentEpoch() public view returns (uint256) {
        return epochId.current();
    }

    /**
     * @notice  Get the current epoch information
     * @return  Current epoch information
     */
    function getCurrentEpochInfo() external view returns (Epoch memory) {
        return epochs[epochId.current()];
    }

    /**
     * @notice  View whether the contract state is in funding phase
     * @return  True if in funding phase
     */
    function isFunding() external view returns (bool) {
        Epoch storage epoch = epochs[epochId.current()];
        return block.timestamp >= epoch.fundingStart && block.timestamp < epoch.epochStart;
    }

    /**
     * @notice  View whether the contract state is in epoch phase
     * @return  True if in epoch phase
     */
    function isInEpoch() external view returns (bool) {
        Epoch storage epoch = epochs[epochId.current()];
        return block.timestamp >= epoch.epochStart && block.timestamp < epoch.epochEnd;
    }

    /**
     * @notice  Returns true if notCustodied and duringFunding modifiers would pass
     * @dev     Only to be used with previewDeposit and previewMint
     */
    function notCustodiedAndDuringFunding() public view returns (bool) {
        Epoch storage epoch = epochs[epochId.current()];
        return (!custodied && (block.timestamp >= epoch.fundingStart && block.timestamp < epoch.epochStart));
    }

    /**
     * @notice  Returns true if notCustodied and notDuringEpoch modifiers would pass
     * @dev     Only to be used with previewRedeem and previewWithdraw
     */
    function notCustodiedAndNotDuringEpoch() public view returns (bool) {
        Epoch storage epoch = epochs[epochId.current()];
        return (!custodied && (block.timestamp < epoch.epochStart || block.timestamp >= epoch.epochEnd));
    }

    // ----- Overrides -----

    /// @dev    See EIP-4626
    function maxDeposit(address) public view override returns (uint256) {
        if (custodied) return 0;
        return totalDeposits > maxDeposits ? 0 : maxDeposits - totalDeposits;
    }

    /// @dev    See EIP-4626
    function maxMint(address) public view override returns (uint256) {
        return convertToShares(maxDeposit(msg.sender));
    }

    /// @dev    See EIP-4626
    function deposit(uint256 assets, address receiver) public override notCustodied duringFunding onlyWhitelisted returns (uint256) {
        require(assets <= maxDeposit(receiver), "!maxDeposit");
        return super.deposit(assets, receiver);
    }

    /// @dev    See EIP-4626
    /// @notice Will return 0 if not during funding window
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        return (notCustodiedAndDuringFunding()) ? super.previewDeposit(assets) : 0;
    }

    /// @dev    See EIP-4626
    function mint(uint256 shares, address receiver) public override notCustodied duringFunding onlyWhitelisted returns (uint256) {
        require(shares <= maxMint(receiver), "!maxMint");
        return super.mint(shares, receiver);
    }

    /// @dev    See EIP-4626
    /// @notice Will return 0 if not during funding window
    function previewMint(uint256 shares) public view override returns (uint256) {
        return (notCustodiedAndDuringFunding()) ? super.previewMint(shares) : 0;
    }

    /// @dev    See EIP-4626
    function withdraw(
        uint256 assets,
        address receiver,
        address _owner
    ) public override notCustodied notDuringEpoch onlyWhitelisted returns (uint256) {
        return super.withdraw(assets, receiver, _owner);
    }

    /// @dev    See EIP-4626
    /// @notice Will return 0 if funds are custodied or during epoch
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        return (notCustodiedAndNotDuringEpoch()) ? super.previewWithdraw(assets) : 0;
    }

    /// @dev    See EIP-4626
    function redeem(
        uint256 shares,
        address receiver,
        address _owner
    ) public override notCustodied notDuringEpoch onlyWhitelisted returns (uint256) {
        return super.redeem(shares, receiver, _owner);
    }

    /// @dev    See EIP-4626
    /// @notice Will return 0 if funds are custodied or during epoch
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        return (notCustodiedAndNotDuringEpoch()) ? super.previewRedeem(shares) : 0;
    }

    /// @dev    See EIP-4626
    function totalAssets() public view override returns (uint256) {
        return custodied ? custodiedAmount : asset.balanceOf(address(this));
    }

    /// @dev    See EIP-4626
    // (uint256 assets, uint256 shares)
    function beforeWithdraw(uint256 assets, uint256) internal override {
        if (totalDeposits > assets) {
            totalDeposits -= assets;
        } else {
            totalDeposits = 0;
        }
    }

    /// @dev    See EIP-4626
    // (uint256 assets, uint256 shares)
    function afterDeposit(uint256 assets, uint256) internal override {
        totalDeposits += assets;
    }

    function token() public view returns (address) {
        return address(this);
    }

    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);
        _burn(_from, amountSentLD);
    }

    function _credit(address _to, uint256 _amountLD, uint32) internal virtual override returns (uint256 amountReceivedLD) {
        if (_to == address(0x0)) _to = address(0xdead);
        _mint(_to, _amountLD);
        return _amountLD;
    }
}
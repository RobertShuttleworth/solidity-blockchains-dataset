// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

// Interfaces
import {ILendingVault} from "./contracts_interfaces_ILendingVault.sol";
import {ILiquidStrategy} from "./contracts_interfaces_ILiquidStrategy.sol";
import {IERC7540, IERC7540Deposit, IERC7540Redeem, IERC7540Operator} from "./contracts_interfaces_IERC7540.sol";
import {IERC7575, IERC165} from "./contracts_interfaces_IERC7575.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";

// Openzeppelin imports
import {Math} from "./lib_openzeppelin-contracts_contracts_utils_math_Math.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {ERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import {ERC4626} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_ERC4626.sol";
import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {ReentrancyGuard} from "./lib_openzeppelin-contracts_contracts_utils_ReentrancyGuard.sol";
import {Pausable} from "./lib_openzeppelin-contracts_contracts_utils_Pausable.sol";
import {AccessControl} from "./lib_openzeppelin-contracts_contracts_access_AccessControl.sol";

// Vaults
import {CreditStrategy} from "./contracts_strategies_credit_CreditStrategy.sol";

/**
 * @title  - Lending Vault
 * @author - Credit Cooperative
 * @notice - The LendingVault inherits the ERC4626 and ERC7540 Tokenized Vault standards to enable pooling of capital for lending to Credit Coop Line-Of-Credit-v2 contracts.
 * @dev    - Should only be deployed using the LendingVaultFactory contract.
 */
contract LendingVault is ILendingVault, IERC7540, ERC4626, Pausable, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Pausable + Access Control
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ERC-7575
    address public share = address(this);

    // ERC-7540 mappings
    mapping(uint256 => mapping(address => uint256)) public pendingDepositRequest;
    mapping(uint256 => mapping(address => uint256)) public claimableDepositRequest;
    mapping(uint256 => mapping(address => uint256)) public claimableDepositRequestShares;
    mapping(uint256 => mapping(address => uint256)) public pendingRedeemRequest;
    mapping(uint256 => mapping(address => uint256)) public claimableRedeemRequest;
    mapping(uint256 => mapping(address => uint256)) public claimableRedeemRequestAssets;
    mapping(address controller => mapping(address operator => bool)) public isOperator;

    // ERC-7540 total pending deposit requests (in assets) that are illiquid and cannot be spent by vault
    uint256 public totalPendingDeposits;

    // ERC-7540 total claimable redeem requests (in assets) that are illiquid and cannot be spent by vault
    uint256 public totalClaimableRedeemAssets;

    // ERC-7540 deposit and redemption requests are non-transferrable and processed by the manager
    uint256 constant REQUEST_ID = 0;

    address private deployerFactory;

    ILiquidStrategy public liquidStrategy;
    address public creditStrategy;
    uint256 public immutable baseUnit;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    address public immutable underlyingAsset;

    constructor(
        address asset_,
        string memory name_,
        string memory symbol_,
        address liquidStrategy_,
        address factory_
    ) ERC4626(IERC20(asset_)) ERC20(name_, symbol_) {
        if (asset_ == address(0) || liquidStrategy_ == address(0) || factory_ == address(0)) {
            revert CannotBeZeroAddress();
        }
        underlyingAsset = asset_;
        baseUnit = 10 ** decimals();

        liquidStrategy = ILiquidStrategy(liquidStrategy_);
        emit LiquidStrategySet(liquidStrategy_);

        deployerFactory = factory_;
    }

    /**
     * @notice - Sets the CreditStrategy contract for the LendingVault.
     * @dev    - Can only be called once by `deployerFactory`.
     * @param _creditStrategy - Address of the CreditStrategy contract.
     */
    function setCreditStrategy(address _creditStrategy, address[] memory pausers) external {
        if (msg.sender != deployerFactory) {
            revert OnlyDeployerFactory();
        }
        if (creditStrategy != address(0)) {
            revert CreditStrategyAlreadySet();
        }
        creditStrategy = _creditStrategy;
        emit CreditStrategySet(_creditStrategy);

        // Create the admin and pauser roles
        _setPausers(_creditStrategy, pausers);

    }

    /**
     * @notice - Setup the admin and pausers for the LendingVault contract.
     * @param _creditStrategy - Address of the CreditStrategy contract.
     * @param pausers         - Array of addresses to set as pausers.
     */
    function _setPausers(address _creditStrategy, address[] memory pausers) internal {
        // `manager` of the CreditStrategy contract is set as the admin and pauser of the LendingVault
        _grantRole(DEFAULT_ADMIN_ROLE, CreditStrategy(_creditStrategy).manager());
        _grantRole(PAUSER_ROLE, CreditStrategy(_creditStrategy).manager());
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);

        // setup additional pausers
        uint256 len = pausers.length;
        for (uint256 i = 0; i < len; i++) {
            _grantRole(PAUSER_ROLE, pausers[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  - Asserts that available, liquid assets in the LendingVault are greater than or equal to the amount specified.
     * @param amount - Amount to compare against the liquid assets in vault.
     */
    function _assertVaultHasSufficientAvailableAssets(uint256 amount) internal view {
        uint256 availableAssets = IERC20(underlyingAsset).balanceOf(address(this)) - totalPendingDeposits - totalClaimableRedeemAssets;
        if (availableAssets < amount) {
            revert InsufficientAvailableAssets();
        }
    }

    /**
     * @dev Modifier to restrict functions to pausers.
     */
    function _onlyPauser()  internal view {
        if (!hasRole(PAUSER_ROLE, msg.sender)) {
            revert OnlyPauser();
        }
    }

    /**
     * @notice - Checks `msg.sender` is `owner` or one of its operators.
     */
    function _onlyOwnerOrOperator(address owner) internal view {
        if (msg.sender != owner
            && !isOperator[owner][msg.sender] // user approved operators
        ) {
            revert OnlyOwnerOrOperator();
        }
    }

    /**
     * @notice - Checks `msg.sender` is `manager` of the Credit Strategy contract.
     */
    function _onlyVaultManager() internal view {
        if (msg.sender != CreditStrategy(creditStrategy).manager()) {
            revert OnlyVaultManager();
        }
    }

    /**
     * @notice - Checks `msg.sender` is `manager` or `operator` of the Credit Strategy contract.
     */
    function _onlyOperator() internal view {
        if (!CreditStrategy(creditStrategy).isOperator(msg.sender)) {
            revert OnlyOperator();
        }
    }

    /**
     * @notice - Checks `msg.sender` is `creditStrategy`.
     */
    function _onlyCreditStrategy() internal view {
        if (msg.sender != address(creditStrategy)) {
            revert OnlyCreditStrategy();
        }
    }

    /**
     * @notice - Checks `target` is not zero address.
     */
    function _cannotBeZeroAddress(address target) internal pure {
        if (target == address(0)) {
            revert CannotBeZeroAddress();
        }
    }

    /**
     * @notice - Checks `newStrategy` has the same underlying asset as the LendingVault.
     */
    function _onlyNativeAsset(address newStrategy) internal view {
        if (address(underlyingAsset) != address(ILiquidStrategy(newStrategy).asset())) {
            revert OnlyNativeAsset();
        }
    }

    /**
     * @notice - Checks `msg.sender` is whitelisted to call LendingVault functions.
     */
    function _isWhitelisted() internal view {
        if (
            CreditStrategy(creditStrategy).whitelistEnabled()
                && !CreditStrategy(creditStrategy).whitelistedAddresses(msg.sender)
        ) {
            revert AddressNotWhitelisted();
        }
    }

    /**
     * @notice - Checks `amounts` and `addresses` are of same length.
     */
    function _arrayLengthsMustMatch(uint256[] memory amounts, address[] memory addresses) internal pure {
        if (amounts.length != addresses.length) {
            revert ArrayLengthsMustMatch();
        }
    }

    /**
     * @notice - Checks `assets` do not exceed the pending deposit request of the `owner`.
     */
    function _cannotExceedDepositRequest(address owner, uint256 assets) internal view {
        if (assets > pendingDepositRequest[REQUEST_ID][owner]) {
            revert ERC7540ExceededDepositRequest(owner, assets, pendingDepositRequest[REQUEST_ID][owner]);
        }
    }

    /**
     * @notice - Checks `shares` do not exceed the pending redeem request of the `owner`.
     */
    function _cannotExceedRedeemRequest(address owner, uint256 shares) internal view {
        if (shares > pendingRedeemRequest[REQUEST_ID][owner]) {
            revert ERC7540ExceededRedeemRequest(owner, shares, pendingRedeemRequest[REQUEST_ID][owner]);
        }
    }

    /**
     * @notice - Checks `shares` are greater than zero.
     */
    function _sharesCannotBeZero(uint256 shares) internal pure {
        if (shares == 0) {
            revert ERC4626ZeroShares();
        }
    }

    /**
     * @notice - Checks `assets` are greater than zero.
     */
    function _assetsCannotBeZero(uint256 assets) internal pure {
        if (assets == 0) {
            revert ERC4626ZeroAssets();
        }
    }

    /*//////////////////////////////////////////////////////////////
                        STRATEGY MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice   - Deposit assets into the Liquid Strategy or Credit Strategy contract
     * @dev      - Only callable by the `manager` of the Credit Strategy contract.
     * @dev      - Only callable if LendingVault has sufficient liquid assets.
     * @param amount         - Amount of assets to deposit
     * @param strategyType   - Type of strategy to deposit into. 0 for Liquid Strategy, 1 for Credit Strategy
     */
    function depositIntoStrategy(uint256 amount, uint256 strategyType) external {
        _onlyVaultManager();
        _assertVaultHasSufficientAvailableAssets(amount);
        if (strategyType > 0) {
            IERC20(underlyingAsset).forceApprove(address(creditStrategy), amount);
            CreditStrategy(creditStrategy).deposit(amount);
            IERC20(underlyingAsset).forceApprove(address(creditStrategy), 0);
        } else {
            IERC20(underlyingAsset).forceApprove(address(liquidStrategy), amount);
            liquidStrategy.deposit(amount);
            IERC20(underlyingAsset).forceApprove(address(liquidStrategy), 0);
        }
   }

    /**
     * @notice  - Migrate the Liquid Strategy contract to a new Liquid Strategy contract. Transfers all assets from the old strategy to the new liquid Strategy.
     * @dev     - Only callable by the `manager` of the Credit Strategy contract.
     * @dev     - Cannot migrate to a zero address.
     * @dev     - Cannot migrate to a strategy that does not hold the same underlying asset as the LendingVault.
     * @param _newLiquidStrategy - Address of the new strategy contract
     */
    function migrateLiquidStrategy(address _newLiquidStrategy) external {
        _onlyVaultManager();
        _onlyNativeAsset(_newLiquidStrategy);

        uint256 balanceBefore = IERC20(underlyingAsset).balanceOf(address(this));

        // Withdraw all assets from the old liquid strategy
        uint256 liquidStrategyBalance = IERC20(underlyingAsset).balanceOf(address(liquidStrategy));
        liquidStrategy.withdraw(liquidStrategyBalance);
        uint256 withdrawn = IERC20(underlyingAsset).balanceOf(address(this)) - balanceBefore;

        // Set the existing strategy's allowance to 0
        IERC20(underlyingAsset).forceApprove(address(liquidStrategy), 0);

        // Set the new liquid strategy
        liquidStrategy = ILiquidStrategy(_newLiquidStrategy);

        // Approve the new liquid strategy contract for the underlying asset
        IERC20(underlyingAsset).forceApprove(_newLiquidStrategy, withdrawn);

        // Deposit all assets into the new liquid strategy
        liquidStrategy.deposit(withdrawn);

        // Set approval to new liquid strategy
        IERC20(underlyingAsset).forceApprove(_newLiquidStrategy, 0);

        emit StrategyContractTransfered(_newLiquidStrategy);
    }

    /*//////////////////////////////////////////////////////////////
                        VAULT MANAGER INTERACTONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  - Withdraws assets from the CreditStrategy contract
     * @dev     - Only callable by the `manager` of the Credit Strategy contract.
     * @param amount - Amount of assets to withdraw from the Credit or Liquid Strategy contract
     * @param strategyType - Type of strategy to withdraw from. 0 for Liquid Strategy, 1 for Credit Strategy
     */
    function withdrawFromStrategy(uint256 amount, uint256 strategyType) external {
        _onlyVaultManager();
        if (strategyType > 0) {
            CreditStrategy(creditStrategy).withdraw(amount);
        } else {
            liquidStrategy.withdraw(amount);
        }
    }

    /**
     * @notice - Callback to mint shares for the management fee and performance fees.
     * @dev    - Only callable by the Credit Strategy contract.
     * @param receiver - Address to receive the minted shares
     * @param shares   - Amount of shares to mint
     */
    function mintFeeShares(address receiver, uint256 shares) public {
        _onlyCreditStrategy();
        _mint(receiver, shares);
    }

    /**
     * @notice  - Transfers ERC20 tokens from the LendingVault contract to arbitrary `to` destination. Can be used to recover tokens not in the underlying asset or in emergency situations.
     * @dev     - Only callable by the `manager` of the Credit Strategy contract.
     * @param token     - Address of the ERC20 token to recover.
     * @param to        - Address to send the recovered tokens to.
     * @param amount    - Amount of tokens to recover.
     */
    function recoverTokens(address token, address to, uint256 amount) external {
        _onlyVaultManager();
        IERC20(token).safeTransfer(to, amount);
        emit TokensRecovered(msg.sender, to, token, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        PREVIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // ERC7540 overrides ERC4626 specification
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        revert();
    }

    // ERC7540 overrides ERC4626 specification
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        revert();
    }

    // ERC7540 overrides ERC4626 specification
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        revert();
    }

    // ERC7540 overrides ERC4626 specification
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        revert();
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSABLE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice - Pauses request functions and the ability to deposit or withdraw assets.
     * @dev    - Only callable by pausers.
     */
    function pause() public {
        _onlyPauser();
        CreditStrategy(creditStrategy).accrueFees();
        _pause();
    }

    /**
     * @notice - Unpauses request functions and the ability to deposit or withdraw assets.
     * @dev    - Only callable by pausers.
     */
    function unpause() public {
        _onlyPauser();
        CreditStrategy(creditStrategy).setLastManagementFeeTimestamp();
        _unpause();
    }

    /*//////////////////////////////////////////////////////////////
                SUPPORTS ERC-165, ERC-7575, ERC-7540
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice - Returns true if the contract supports the ERC-7540, ERC7575, or ERC165 contract interfaces.
     * @param interfaceId - interface ID to check for support.
     * @return            - True if the contract supports the ERC-7540 interface.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return interfaceId == type(IERC7540Deposit).interfaceId // asynchronous deposit vault
            || interfaceId == type(IERC7540Redeem).interfaceId // asynchronous redemption vault
            || interfaceId == type(IERC7540Operator).interfaceId // operator management
            || interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC7575).interfaceId
            || super.supportsInterface(interfaceId); // access control
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice - The total amount of underlying tokens the vault holds or has claim to.
     * @return - Total amount of underlying tokens the vault holds, has deployed to credit lines, and interest owed or repaid on those credit lines.
     *
     */
    function totalAssets() public view override returns (uint256) {
        return totalLiquidAssets() + CreditStrategy(creditStrategy).totalActiveCredit();
    }

    /**
     * @notice - The total amount of underlying tokens the vault currently holds.
     * @return - The total amount of underlying tokens the vault holds.
     */
    function totalLiquidAssets() public view virtual returns (uint256) {
        uint256 liquidStrategyAssets = address(liquidStrategy) == address(0) ? 0 : liquidStrategy.totalAssets();
        uint256 creditStrategyAssets = IERC20(underlyingAsset).balanceOf(creditStrategy);
        return IERC20(underlyingAsset).balanceOf(address(this)) - totalPendingDeposits - totalClaimableRedeemAssets + liquidStrategyAssets
            + creditStrategyAssets;
    }

    /**
     * @notice  - Amount of underlying tokens a user's vault shares is redeemable for.
     * @param user - Address to get the underlying balance of.
     * @return     - User's vault balance in underlying tokens.
     */
    function balanceOfUnderlying(address user) public view returns (uint256) {
        return _convertToAssets(balanceOf(user), Math.Rounding.Floor);
    }

    /**
     * @notice  - The value of a single vault share expressed in terms of underlying tokens the vault holds, has deployed to credit lines, and interest owed or repaid on those credit lines.
     * @return  - The value of a single vault share expressed in terms of underlying tokens.
     */
    function sharePrice() public view returns (uint256) {
        // Get the total supply of shares.
        if (totalSupply() != 0) {
            // Calculate the exchange rate by dividing the total holdings by the share supply.
            return totalAssets().mulDiv(baseUnit, totalSupply());
        }
        // If there are no shares in circulation, return an exchange rate of 1:1.
        return baseUnit;
    }


    /*//////////////////////////////////////////////////////////////
                        Request LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  - Transfers assets from msg.sender into the Vault and submits a Request for asynchronous deposit. Because REQUEST_ID == 0, all requests are aggregated for a single owner.
     * @dev     - If whitelist is enabled, only whitelisted addresses can deposit.
     * @dev     - Cannot request to deposit 0 `assets`.
     * @dev     - Only the `owner` or an `operator` can request to deposit.
     * @param assets     - Amount of the underlying token to deposit.
     * @param controller - Address to receive newly minted shares.
     * @param owner      - Address of the owner of the assets.
     * @return requestId - Unique identifier for the request.
     */
    function requestDeposit(uint256 assets, address controller, address owner)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        _isWhitelisted();
        _assetsCannotBeZero(assets);
        _onlyOwnerOrOperator(owner);

        IERC20(underlyingAsset).safeTransferFrom(owner, address(this), assets); // asset here is the Vault underlying asset

        pendingDepositRequest[REQUEST_ID][controller] += assets;
        totalPendingDeposits += assets;

        emit DepositRequest(controller, owner, REQUEST_ID, msg.sender, assets);
        return REQUEST_ID;
    }

    /**
     * @notice  - Assumes control of shares from owner and submits a Request for asynchronous redeem.  Because REQUEST_ID == 0, all requests are aggregated for a single owner.
     * @dev     - Cannot request to redeem 0 `shares`.
     * @dev     - Only the `owner` or an `operator` can request to deposit.
     * @param shares     - Amount of shares to redeem.
     * @param controller - Address to receive the underlying tokens.
     * @param owner      - Address of the owner of the shares.
     * @return requestId - Unique identifier for the request.
     */
    function requestRedeem(uint256 shares, address controller, address owner)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        _sharesCannotBeZero(shares);
        _onlyOwnerOrOperator(owner);

        // transfer shares to the Vault
        _transfer(owner, address(this), shares);

        pendingRedeemRequest[REQUEST_ID][controller] += shares;

        emit RedeemRequest(controller, owner, REQUEST_ID, msg.sender, shares);
        return REQUEST_ID;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  - Deposit a specific amount of underlying tokens and receive vault shares.
     * @dev     - If whitelist is enabled, only whitelisted addresses can deposit.
     * @dev     - Only the `owner` or an `operator` can deposit.
     * @param assets        - Amount of the underlying token to deposit.
     * @param receiver      - Address to receive shares.
     * @param controller    - Owner of the deposit Request, who can manage any actions related to the Request, including claiming the shares.
     * @return shares       - Amount of shares to transfer to receiver.
     */
    function deposit(uint256 assets, address receiver, address controller)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        shares = _baseDeposit(assets, controller);

        // transfer shares from vault to receiver
        _transfer(address(this), receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
    }

    /**
     * @notice  - Deposit a specific amount of underlying tokens and receive vault shares.
     * @dev     - If whitelist is enabled, only whitelisted addresses can deposit.
     * @dev     - Only the `owner` or an `operator` can deposit.
     * @param assets   - Amount of the underlying token to deposit.
     * @param receiver - Address to receive shares.
     * @return shares  - Amount of shares to transfer to receiver.
     */
    function deposit(uint256 assets, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        shares = _baseDeposit(assets, receiver);

        // transfer shares from vault to receiver
        _transfer(address(this), receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice  - Deposit a specific amount of underlying tokens and receive vault shares.
     * @dev     - If whitelist is enabled, only whitelisted addresses can deposit.
     * @dev     - Only the `owner` or an `operator` can deposit.
     * @param assets        - Amount of the underlying token to deposit.
     * @param controller    - Owner of the deposit Request, who can manage any actions related to the Request, including claiming the shares.
     * @return shares       - Amount of shares.
     */
    function _baseDeposit(uint256 assets, address controller) internal returns (uint256 shares) {
        _isWhitelisted();
        _onlyOwnerOrOperator(controller);
        _assetsCannotBeZero(assets);

        uint256 maxAssets = maxDeposit(controller);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(controller, assets, maxAssets);
        }

        // determine pro-rata shares
        uint256 maxShares = maxMint(controller);
        shares = maxShares.mulDiv(assets, maxAssets);
        _sharesCannotBeZero(shares);

        // update vault accounting
        claimableDepositRequest[REQUEST_ID][controller] -= assets;
        claimableDepositRequestShares[REQUEST_ID][controller] -= shares;
    }

    /**
     * @notice  - Receive a specific amount of vault shares in exchange for underlying tokens.
     * @dev     - If whitelist is enabled, only whitelisted addresses can deposit.
     * @dev     - Only the `owner` or an `operator` can deposit.
     * @param shares        - Amount of the shares to mint.
     * @param receiver      - Address to receive newly minted shares.
     * @param controller    - Owner of the deposit Request, who can manage any actions related to the Request, including claiming the assets.
     * @return assets       - Amount of underlying tokens deposited to mint shares.
     */
    function mint(uint256 shares, address receiver, address controller)
        external
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        assets = _baseMint(shares, controller);

        // transfer shares from vault to receiver
        _transfer(address(this), receiver, shares);

        emit Deposit(controller, receiver, assets, shares);
    }

    /**
     * @notice  - Receive a specific amount of vault shares in exchange for underlying tokens.
     * @dev     - If whitelist is enabled, only whitelisted addresses can deposit.
     * @dev     - Only the `owner` or an `operator` can deposit.
     * @param shares   - Amount of the shares to mint.
     * @param receiver - Address to receive newly minted shares.
     * @return assets  - Amount of underlying tokens deposited to mint shares.
     */
    function mint(uint256 shares, address receiver)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        assets = _baseMint(shares, receiver);

        // transfer shares from vault to receiver
        _transfer(address(this), receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice  - Mint a specific amount of vault shares in exchange for underlying tokens.
     * @dev     - If whitelist is enabled, only whitelisted addresses can deposit.
     * @dev     - Only the `owner` or an `operator` can deposit.
     * @param shares        - Amount of the shares to mint.
     * @param controller    - Owner of the deposit Request, who can manage any actions related to the Request, including claiming the assets.
     * @return assets       - Amount of underlying tokens deposited to mint shares.
     */
    function _baseMint(uint256 shares, address controller) internal returns (uint256 assets) {
        _isWhitelisted();
        _onlyOwnerOrOperator(controller);
        _sharesCannotBeZero(shares);

        uint256 maxShares = maxMint(controller);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(controller, shares, maxShares);
        }

        // determine pro-rata assets
        uint256 maxAssets = maxDeposit(controller);
        assets = maxAssets.mulDiv(shares, maxShares, Math.Rounding.Ceil);
        _assetsCannotBeZero(assets);

        // update vault accounting
        claimableDepositRequest[REQUEST_ID][controller] -= assets;
        claimableDepositRequestShares[REQUEST_ID][controller] -= shares;
    }

    /**
     * @notice  - Withdraw a specific amount of underlying tokens from owner's balance.
     * @dev     - Will revert if msg.sender does not have sufficient allowance from owner.
     * @dev     - Only the `owner` or an `operator` can withdraw.
     * @param assets        - Amount of underlying tokens to withdraw by burning shares.
     * @param receiver      - Address to receive underlying tokens after burning shares.
     * @param controller    - Address where underlying tokens are withdrawn from.
     * @return shares       - Amount of shares burned to withdraw underlying tokens.
     */
    function withdraw(uint256 assets, address receiver, address controller)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares)
    {
        _onlyOwnerOrOperator(controller);
        _assetsCannotBeZero(assets);

        uint256 maxAssets = maxWithdraw(controller);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(controller, assets, maxAssets);
        }

        // determine pro-rata shares
        uint256 maxShares = maxRedeem(controller);
        shares = maxShares.mulDiv(assets, maxAssets, Math.Rounding.Ceil);
        _sharesCannotBeZero(shares);

        // transfer assets to receiver
        _withdraw(controller, receiver, assets, shares);
    }

    /**
     * @notice  - Withdraws a specific amount of underlying tokens from owner's balance.
     * @dev     - Revert if there are not enough liquid assets to withdraw. See _assertVaultHasSufficientAvailableAssets() function.
     * @dev     - Called by withdraw() and redeem() functions.
     * @param controller    - Address where shares are burned.
     * @param receiver - Address to receive underlying tokens after burning shares.
     * @param assets   - Amount of underlying tokens to withdraw by burning shares.
     * @param shares   - Amount of shares to burn.
     */
    function _withdraw(address controller, address receiver, uint256 assets, uint256 shares) internal {

        // update vault accounting
        claimableRedeemRequest[REQUEST_ID][controller] -= shares;
        claimableRedeemRequestAssets[REQUEST_ID][controller] -= assets;
        totalClaimableRedeemAssets -= assets;

        emit Withdraw(msg.sender, receiver, controller, assets, shares);

        IERC20(underlyingAsset).safeTransfer(receiver, assets);
    }

    /**
     * @notice  - Redeem a specific amount of shares for underlying tokens from owner.
     * @dev     - Reverts if msg.sender does not have sufficient allowance from owner.
     * @dev     - Only the `owner` or an `operator` can redeem.
     * @param shares        - Amount of shares to redeem for underlying tokens.
     * @param receiver      - Address to receive underlying tokens after burning shares.
     * @param controller    - Address where shares are burned to withdraw underlying tokens.
     * @return assets       - Amount of underlying tokens withdrawn.
     */
    function redeem(uint256 shares, address receiver, address controller)
        public
        override
        nonReentrant
        whenNotPaused
        returns (uint256 assets)
    {
        _onlyOwnerOrOperator(controller);
        _sharesCannotBeZero(shares);

        uint256 maxShares = maxRedeem(controller);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(controller, shares, maxShares);
        }

        // determine pro-rata assets
        uint256 maxAssets = maxWithdraw(controller);
        assets = maxAssets.mulDiv(shares, maxShares);
        _assetsCannotBeZero(assets);

        // transfer assets to receiver
        _withdraw(controller, receiver, assets, shares);
    }


    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  - The maximum amount of underlying tokens the receiver can deposit into the vault. Per EIP-7540, Increases and decreases in sync with claimableDepositRequest.
     * @param receiver - Address to check the maximum deposit amount for.
     * @return         - Returns the maximum amount of underlying tokens a user can deposit into the vault.
     *
     */
    function maxDeposit(address receiver) public view override returns (uint256) {
        return claimableDepositRequest[REQUEST_ID][receiver];
    }

    /**
     * @notice  - The maximum amount of vault shares the receiver can mint with underlying tokens.
     * @param receiver - Address to check the maximum mint amount for.
     * @return         - Returns the maximum amount of vault shares the receiver can mint with underlying tokens.
     */
    function maxMint(address receiver) public view override returns (uint256) {
        return claimableDepositRequestShares[REQUEST_ID][receiver];
    }

    /**
     * @notice  - The maximum amount of assets the owner can withdraw from the vault. Increases and decreases in sync with claimableRedeemRequestAssets.
     * @param owner - Address to check the maximum withdraw amount for.
     * @return      - Returns the maximum amount of assets the owner can withdraw from the vault.
     */
    function maxWithdraw(address owner) public view override returns (uint256) {
        return claimableRedeemRequestAssets[REQUEST_ID][owner];
    }

    /**
     * @notice  - The maximum amount of vault shares the owner can redeem. Per EIP-7540, increases and decreases in sync with claimableRedeemRequest.
     * @param owner - Address to check the maximum redeem amount for.
     * @return      - Returns the maximum amount of shares the owner can redeem from the vault.
     */
    function maxRedeem(address owner) public view override returns (uint256) {
        return claimableRedeemRequest[REQUEST_ID][owner];
    }

    /*///////////////////////////////////////////////////////////////
                        ERC-7540 Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  - Adds or remove operator approval for msg.sender.
     * @param operator - Address of the operator to add or remove.
     * @param approved - True to add operator, false to remove operator.
     * @return         - True if the operator was successfully added or removed.
     */
    function setOperator(address operator, bool approved) external returns (bool) {
        isOperator[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    /*///////////////////////////////////////////////////////////////
                    PROCESS AND CANCEL REQUESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  - Processes a deposit request by reducing the pending deposit request and increasing the claimable deposit request.
     * @dev     - Only callable by the `manager` or `operator` of the Credit Strategy contract.
     * @param controller    - Address of the owner of the assets.
     * @param assets        - Amount of the deposit request to move from PENDING to CLAIMABLE.
     * @param minShares     - The minimum amount of shares that can be minted.
     * @param maxShares     - The maximum amount of shares that can be minted.
     * @return              - True if the deposit request was successfully processed.
     */
    function processDepositRequest(address controller, uint256 assets, uint256 minShares, uint256 maxShares) external nonReentrant returns (bool) {
        _onlyOperator();

        CreditStrategy(creditStrategy).accrueFees(); // accrue fees before depositing assets to mint shares
        return _processDepositRequest(controller, assets, minShares, maxShares);
    }

    /**
     * @notice  - Processes multiple deposit requests by reducing the pending deposit request and increasing the claimable deposit request.
     * @dev     - Only callable by the `manager` or `operator` of the Credit Strategy contract.
     * @param controllers   - Addresses of the owners of the assets.
     * @param assets        - The amounts of the deposit requests to move from PENDING to CLAIMABLE.
     * @param minShares     - The minimum amounts of shares that can be minted.
     * @param maxShares     - The maximum amounts of shares that can be minted.
     * @return              - True if the deposit request was successfully processed.
     */
    function batchProcessDepositRequest(address[] memory controllers, uint256[] memory assets, uint256[] memory minShares, uint256[] memory maxShares)
        external
        nonReentrant
        returns (bool)
    {
        _onlyOperator();
        _arrayLengthsMustMatch(assets, controllers);

        CreditStrategy(creditStrategy).accrueFees(); // accrue fees before minting shares
        uint256 len = controllers.length;
        for (uint256 x = 0; x < len; x++) {
            _processDepositRequest(controllers[x], assets[x], minShares[x], maxShares[x]);
        }

        return true;
    }

    // See processDepositRequest()
    function _processDepositRequest(address controller, uint256 assets, uint256 minShares, uint256 maxShares) internal returns (bool) {
        _cannotExceedDepositRequest(controller, assets);

        pendingDepositRequest[REQUEST_ID][controller] -= assets;
        claimableDepositRequest[REQUEST_ID][controller] += assets;

        // check that the request is within the min and max limits
        uint256 sharesToDeposit = _convertToShares(assets, Math.Rounding.Floor);
        if (sharesToDeposit < minShares || sharesToDeposit > maxShares) {
            revert DepositRequestOutsideLimits(controller, sharesToDeposit, minShares, maxShares);
        }

        claimableDepositRequestShares[REQUEST_ID][controller] += sharesToDeposit;
        totalPendingDeposits -= assets;

        emit ProcessDepositRequest(controller, REQUEST_ID, sharesToDeposit, assets);

        // mint shares to the Lending Vault
        _mint(address(this), sharesToDeposit);

        return true;
    }

    /**
     * @notice  - Cancels a deposit request and sends tokens to receiver.
     * @dev     - Only callable by `controller` or its operators.
     * @param assets        - Amount of the deposit request to cancel.
     * @param receiver      - Address to receive assets from cancellation of Deposit Request.
     * @param controller    - Address of the owner of the Deposit Request.
     * @return              - True if the deposit request was successfully cancelled.
     */
    function cancelDepositRequest(uint256 assets, address receiver, address controller)
        external
        nonReentrant
        returns (bool)
    {
        _onlyOwnerOrOperator(controller);
        return _cancelDepositRequest(assets, receiver, controller);
    }

    // See cancelDepositRequest()
    function _cancelDepositRequest(uint256 assets, address receiver, address controller) internal returns (bool) {
        _cannotExceedDepositRequest(controller, assets);

        // remove assets from pending deposit request
        pendingDepositRequest[REQUEST_ID][controller] -= assets;
        totalPendingDeposits -= assets;

        // transfer funds back to owner
        IERC20(underlyingAsset).safeTransfer(receiver, assets); // asset here is the Vault underlying asset

        emit CancelDepositRequest(controller, receiver, REQUEST_ID, assets);
        return true;
    }

    /**
     * @notice  - Processes a redeem request by reducing the pending redeem request and increasing the claimable redeem request.
     * @dev     - Only callable by the `manager` or `operator` of the Credit Strategy contract.
     * @param controller    - Address of the owner of the shares.
     * @param shares        - The amount of the redeem request to move from PENDING to CLAIMABLE.
     * @param minAssets     - The minimum amount of assets that can be withdrawn.
     * @param maxAssets     - The maximum amount of assets that can be withdrawn.
     * @return              - True if the redeem request was successfully processed.
     */
    function processRedeemRequest(address controller, uint256 shares, uint256 minAssets, uint256 maxAssets) external nonReentrant returns (bool) {
        _onlyOperator();

        CreditStrategy(creditStrategy).accrueFees(); // accrue fees before redeeming shares
        return _processRedeemRequest(controller, shares, minAssets, maxAssets);
    }

    /**
     * @notice  - Processes multiple redeem requests by reducing the pending redeem request and increasing the claimable redeem request.
     * @dev     - Only callable by the `manager` or `operator` of the Credit Strategy contract.
     * @dev     - The vault manager or operator must ensure that the vault has sufficient liquidity to process the redemption requests.
     * @param controllers   - A list of addresses of the owners of the shares.
     * @param shares        - A list of amounts of the redeem request to move from PENDING to CLAIMABLE.
     * @param minAssets     - A list of minimum amounts of assets that can be withdrawn.
     * @param maxAssets     - A list of maximum amounts of assets that can be withdrawn.
     * @return              - True if the redeem request was successfully processed.
     */
    function batchProcessRedeemRequest(address[] memory controllers, uint256[] memory shares, uint256[] memory minAssets, uint256[] memory maxAssets)
        external
        nonReentrant
        returns (bool)
    {
        _onlyOperator();
        _arrayLengthsMustMatch(shares, controllers);
        _arrayLengthsMustMatch(minAssets, controllers);
        _arrayLengthsMustMatch(maxAssets, controllers);

        CreditStrategy(creditStrategy).accrueFees(); // accrue fees before redeeming shares
        uint256 len = controllers.length;
        for (uint256 x = 0; x < len; x++) {
            _processRedeemRequest(controllers[x], shares[x], minAssets[x], maxAssets[x]);
        }
        return true;
    }

    // See processRedeemRequest()
    function _processRedeemRequest(address controller, uint256 shares, uint256 minAssets, uint256 maxAssets) internal returns (bool) {
        _cannotExceedRedeemRequest(controller, shares);

        pendingRedeemRequest[REQUEST_ID][controller] -= shares;
        claimableRedeemRequest[REQUEST_ID][controller] += shares;

        // check if the vault has sufficient liquidity to process the redemption request
        uint256 assetsToWithdraw = _convertToAssets(shares, Math.Rounding.Floor);
        _assertVaultHasSufficientAvailableAssets(assetsToWithdraw);

        // check that the request is within the min and max limits
        if (assetsToWithdraw < minAssets || assetsToWithdraw > maxAssets) {
            revert RedeemRequestOutsideLimits(controller, assetsToWithdraw, minAssets, maxAssets);
        }

        // aggregate all claimable redeem requests
        claimableRedeemRequestAssets[REQUEST_ID][controller] += assetsToWithdraw;
        totalClaimableRedeemAssets += assetsToWithdraw;

        emit ProcessRedeemRequest(controller, REQUEST_ID, shares, assetsToWithdraw);

        // Note: LendingVault owns the controller's shares after requestRedeem
        _burn(address(this), shares);

        return true;
    }

    /**
     * @notice  - Cancels a redeem request.
     * @dev     - Only callable by `controller` or its operators.
     * @param shares        - Amount of the redeem request to cancel.
     * @param receiver      - Address of the owner of the shares.
     * @param controller    - Address of the owner of the shares.
     * @return              - True if the redeem request was successfully cancelled.
     */
    function cancelRedeemRequest(uint256 shares, address receiver, address controller)
        external
        nonReentrant
        returns (bool)
    {
        _onlyOwnerOrOperator(controller);
        return _cancelRedeemRequest(shares, receiver, controller);
    }

    // See processRedeemRequest()
    function _cancelRedeemRequest(uint256 shares, address receiver, address controller) internal returns (bool) {
        _cannotExceedRedeemRequest(controller, shares);

        pendingRedeemRequest[REQUEST_ID][controller] -= shares;

        // transfer shares to receiver
        _transfer(address(this), receiver, shares);

        emit CancelRedeemRequest(controller, receiver, REQUEST_ID, shares);
        return true;
    }

}
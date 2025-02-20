// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {ReentrancyGuard} from "./lib_Line-Of-Credit-v2_contracts_utils_ReentrancyGuard.sol";
import {IEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrow.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {ISecuredLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISecuredLine.sol";
import {IOTC} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOTC.sol";

import {INonFungiblePositionManager} from "./lib_Line-Of-Credit-v2_contracts_interfaces_INonFungiblePositionManager.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {EscrowState, EscrowLib} from "./lib_Line-Of-Credit-v2_contracts_utils_EscrowLib.sol";
import {Univ3State, UniV3EscrowLib} from "./lib_Line-Of-Credit-v2_contracts_utils_UniV3EscrowLib.sol";
import {OTCState, OTCLib} from "./lib_Line-Of-Credit-v2_contracts_utils_OTCLib.sol";
import {MutualConsent} from "./lib_Line-Of-Credit-v2_contracts_utils_MutualConsent.sol";

/**
 * @title  - Escrow
 * @author - Credit Cooperative
 * @notice - Ownable contract that allows someone to deposit ERC20 and ERC4626 tokens as collateral to back a Line of Credit
 */
contract Escrow is IEscrow, ReentrancyGuard, MutualConsent {
    using SafeERC20 for IERC20;
    using EscrowLib for EscrowState;
    using UniV3EscrowLib for Univ3State;
    using OTCLib for OTCState;

    /// @notice the minimum value of the collateral in relation to the outstanding debt e.g. 10% of outstanding debt
    uint32 public minimumCollateralRatio;

    /// @notice borrower
    address public borrower;

    mapping(address => bool) public isContractRegistered;
    mapping(bytes4 => bool) public whitelistedFunctions; // function -> allowed

    /// @notice all data around terms for collateral and current deposits
    EscrowState internal state;
    OTCState internal otcState;
    Univ3State internal uniV3State;

    address internal immutable erc20Oracle;
    address internal immutable uniV3Oracle;

    bool private initializedFromFactory = false;
    uint256 internal constant MAX_INT = type(uint256).max;

    ///////////  MODIFIERS  ///////////

    function _onlyBorrower() internal view {
        if (msg.sender != borrower) revert CallerAccessDenied();
    }

    function _onlyAdmin() internal view {
        if (msg.sender != _getLineAdmin()) revert CallerAccessDenied();
    }

    function _onlyBorrowerOrServicer() internal view {
        if (msg.sender != borrower && !_isLineServicer()) {
            revert CallerAccessDenied();
        }
    }

    function _onlyBorrowerOrAdmin() internal view {
        if (msg.sender != borrower && msg.sender != _getLineAdmin()) {
            revert CallerAccessDenied();
        }
    }

    function _onlyOwner() internal view {
        if (msg.sender != state.owner) revert CallerAccessDenied();
    }

    function _onlyBorrowerOrIfLiquidatable() internal {
        if (msg.sender != borrower && _getLineStatus() != LineLib.STATUS.LIQUIDATABLE) {
            revert CallerAccessDenied();
        }

        if (_getLineStatus() == LineLib.STATUS.LIQUIDATABLE) {
            if (!_isLineServicer()) {
                revert CallerAccessDenied();
            }
        }
    }

    function _checkLiquidatable() internal {
        if (_getLineStatus() != LineLib.STATUS.LIQUIDATABLE) {
            revert NotLiquidatable();
        }
    }

    // The oracle should be uniform across all clones which is why its in the constructor
    constructor(address _oracle, address _uniV3Oracle) {
        erc20Oracle = _oracle;
        uniV3Oracle = _uniV3Oracle;
    }

    /**
     * @notice  - Initialize Escrow contract
     * @dev     - Escrow is deployed and initialized from EscrowFactory
     * @param _minimumCollateralRatio - In bps, 3 decimals. Cratio threshold where liquidations begin.
     *                                  see Escrow.isLiquidatable()
     * @param _owner                  - Owner (i.e. LineOfCredit) of Escrow contract.
     * @param _borrower               - Borrower on the LineOfCredit contract.
     * @param _nftPositionManager     - Address of the Uniswap V3 NFT Position Manager contract.
     * @param _univ3Manager                - Address of the role in our system for who can manage uni v3 positions.
     */
    function initializeFromFactory(
        uint32 _minimumCollateralRatio,
        address _owner,
        address _borrower,
        address _nftPositionManager,
        address _univ3Manager
    ) external {
        if (initializedFromFactory) revert AlreadyInitialized();

        minimumCollateralRatio = _minimumCollateralRatio;
        borrower = _borrower;
        state.owner = _owner;
        uniV3State.owner = _owner;
        uniV3State.nftPositionManager = _nftPositionManager;
        uniV3State.univ3Manager = _univ3Manager;

        initializedFromFactory = true;
    }

    /// @notice - increments nonce when important loan data has been altered. Ensures a lender agrees to mutual consent without data being altered
    function _incrementNonce() internal {
        ISecuredLine(state.owner).incrementNonce();
    }

    function _getLineCount() internal view returns (uint256) {
        (uint256 count,) = ILineOfCredit(state.owner).counts();
        return count;
    }

    function _getLineAdmin() internal view returns (address) {
        return ILineOfCredit(state.owner).admin();
    }

    function _isLineServicer() internal view returns (bool) {
        return ILineOfCredit(state.owner).isServicer(msg.sender);
    }

    function _checkLineStatusAndCratio() internal {
        if (
            getCollateralRatio() < minimumCollateralRatio // if undercollateralized, revert;
                && _getLineStatus() != LineLib.STATUS.REPAID // if repaid, skip;
        ) {
            revert UnderCollateralized();
        }
    }

    function _getLineStatus() internal returns (LineLib.STATUS) {
        return ILineOfCredit(state.owner).status();
    }

    function _getProposalCount() internal view returns (uint256) {
        return MutualConsent(state.owner).proposalCount();
    }

    /**
     * @notice - returns the owner of the escrow contract (i.e the line of credit contract)
     * @return - the address of the owner
     */
    function owner() external view override returns (address) {
        return state.owner;
    }

    /**
     * @notice - change the address that can manage univ3 positions. callable by admin
     * @dev    - callable by admin
     * @param _univ3Manager - the address of the role in our system for who can manage uni v3 positions
     */
    function setUniswapV3Manager(address _univ3Manager) external {
        _onlyAdmin();
        uniV3State.univ3Manager = _univ3Manager;
    }

    /**
     * @notice - Checks Line's outstanding debt value and current Escrow collateral value to compute collateral ratio and checks that against minimum.
     * @return isLiquidatable - returns true if Escrow.getCollateralRatio is lower than minimumCollateralRatio else false
     */
    function isLiquidatable() external returns (bool) {
        return getCollateralRatio() < minimumCollateralRatio;
    }

    /**
     * @notice - Allows current owner to transfer ownership to another address
     * @dev    - Used if we setup Escrow before Line exists. Line has no way to interface with this function so once transfered `line` is set forever
     * @return didUpdate - if function successfully executed or not
     */
    function updateOwner(address _owner) external returns (bool) {
        return (state.updateOwner(_owner) && uniV3State.updateOwner(_owner));
    }

    /**
     * @notice - add collateral to your position
     * @dev    - requires that the token deposited by the depositor has been enabled by `line.Admin`
     * @dev    - callable by anyone
     * @param amount - the amount of collateral to add
     * @param token  - the token address of the deposited token
     */
    function addCollateral(uint256 amount, address token) external payable {
        state.addCollateral(amount, token);
    }

    /**
     *  @notice - enables a pair of tokens that we allow for uniswap v3 positions
     * @notice - order of tokens needs to match order in uniswap v3 pool. Impacts the resulting hash
     *  @dev    - callable by admin
     *  @param token0 - the address of the first token in the pair
     *  @param token1 - the address of the second token in the pair
     */
    function enableTokenPairAsCollateral(address token0, address token1, uint24 fee) external {
        _onlyAdmin();
        state.enablePairAsCollateral(token0, token1, fee);

        emit EnablePairAsCollateral(token0, token1);
    }

    /**
     * @notice - allows the borrower to add a uniswap v3 position to their escrow
     * @dev    - callable by anyone
     * @param tokenId - the id of the uniswap v3 position
     * @return        - true if successful
     */
    function addUniV3Position(uint256 tokenId) external returns (bool) {
        INonFungiblePositionManager.Position memory position =
            INonFungiblePositionManager(uniV3State.nftPositionManager).positions(tokenId);

        return uniV3State.addUniV3Position(state, position.token0, position.token1, tokenId);
    }

    /**
     * @notice - allows  the lines admin to  enable thdeposits of an asset
     *         - gives  better risk segmentation forlenders
     * @dev    - whitelisting protects against malicious 4626 tokens and DoS attacks
     *         - only need to allow once. Can not disable collateral once enabled.
     * @param token - the token to all borrow to deposit as collateral
     * @return      - true if successful, false if it fails
     */
    function enableCollateral(address token) external returns (bool) {
        _onlyAdmin();
        return state.enableCollateral(erc20Oracle, token);
    }

    /**
     * @notice - returns if a token has been allowed as collateral
     * @param token - the token to check
     */
    function isCollateralEnabled(address token) external view returns (bool) {
        return state.enabledTokens[token];
    }

    /**
     * @notice - returns the amount of an erc20 token that has been posted as collateral
     * @param token - the token to check
     */
    function getCollateralData(address token) external view returns (Deposit memory) {
        return state.deposited[token];
    }

    /**
     * @notice - enable a position to be used as collateral. Checks the the position can be priced by our oracle
     * @dev    - only callable by admin
     * @param tokenId - the id of the position to enable
     */
    function enablePosition(uint256 tokenId) external {
        _onlyAdmin();
        INonFungiblePositionManager.Position memory position =
            INonFungiblePositionManager(uniV3State.nftPositionManager).positions(tokenId);

        bool token1Enabled = state.enableCollateral(erc20Oracle, position.token0);
        bool token2Enabled = state.enableCollateral(erc20Oracle, position.token1);

        if (token1Enabled && token2Enabled) {
            uniV3State.enablePosition(state, position.token0, position.token1, tokenId, uniV3Oracle);
            return;
        }

        revert InvalidCollateral();
    }

    /**
     * @notice - remove collateral from your position. Must remain above min collateral ratio
     * @dev    - callable by `borrower`, `admin`, or `servicer`
     * @dev    - updates cratio
     * @param amount - the amount of collateral to release
     * @param token  - the token address to withdraw
     * @param to     - who should receive the funds
     */
    function releaseCollateral(uint256 amount, address token, address to) external nonReentrant {
        state.releaseCollateral(borrower, amount, token, to);
        // fail if reduces cratio below min
        // but allow borrower to always withdraw if fully repaid
        _checkLineStatusAndCratio();

        emit RemoveCollateral(token, amount);
    }

    /**
     * @notice - remove uni v3 position from your escrow. Must remain above min collateral ratio
     * @dev    - callable by `borrower`, `admin`, or `servicer`
     * @dev    - updates cratio
     * @param tokenId - the token id to be removed
     * @param to      - who should receive the funds
     */
    function releasePosition(uint256 tokenId, address to) external {
        _onlyBorrowerOrServicer();
        uniV3State.releasePosition(borrower, tokenId, to);
        _checkLineStatusAndCratio();

        emit RemovePosition(tokenId);
    }

    /**
     * @notice - allows the line to change the allowed price impact for OTC trades on Escrow contract
     * @dev    - only callable by the line
     * @param allowedPriceImpact - the new price impact that is allowed
     */
    function updateAllowedOTCPriceImpact(uint128 allowedPriceImpact) external {
        _onlyOwner();
        otcState.nonStableCoinPriceImpact = allowedPriceImpact;
    }

    /**
     * @notice - allows a borrower to swap escrowed tokens for other tokens of equal value IF min cratio is not breached
     * @dev    - requires mutual consent between the admin and the counterparty we are trading with
     * @param otc - the otc struct that contains the details of the trade
     */
    function otcSwap(IOTC.OTC memory otc) external nonReentrant mutualConsent(_getLineAdmin(), otc.counterparty) {
        state.otcCheck(otc);

        state.deposited[otc.tokenComingIn].amount +=
        // this is the amount we traded for minus the swap fee
        otcState.otcSwap(
            otc, ILineOfCredit(state.owner).getFees(), erc20Oracle, ILineOfCredit(state.owner).protocolTreasury()
        );

        state.deposited[otc.tokenGoingOut].amount -= otc.tokenGoingOutAmount;

        _checkCollateralRatio();
    }

    /**
     * @notice - updates the list of coins that that can be traded one to one without need to to consult an oracle
     * @dev    - callable by admin
     * @param token     - address of token being whitelisted
     * @param isAllowed - if true, token can be swapped without oracle consult, if false, oracle needs to be consulted
     */
    function updateStableCoinWhitelist(address token, bool isAllowed) external {
        _onlyAdmin();
        otcState.updateStableCoinWhitelist(token, isAllowed);
    }

    /**
     * @notice - calculates the cratio
     * @dev    - callable by anyone
     * @return - the calculated cratio
     */
    function getCollateralRatio() public returns (uint256) {
        (uint256 principal, uint256 interest) = ILineOfCredit(state.owner).updateOutstandingDebt();
        uint256 debtValue = principal + interest;
        uint256 collateralValue = getCollateralValue();
        if (debtValue == 0) return MAX_INT;
        if (collateralValue == 0) return 0;

        uint256 _numerator = collateralValue * 10 ** 5; // scale to 4 decimals
        return ((_numerator / debtValue) + 5) / 10;
    }

    /**
     * @notice - calculates the collateral value in USD to 8 decimals
     * @dev    - callable by anyone
     * @return - the calculated collateral value to 8 decimals
     */
    function getCollateralValue() public view returns (uint256) {
        return uniV3State.getAllPositionsValue(uniV3Oracle) + state.getCollateralValue(erc20Oracle);
    }

    /**
     * @notice - liquidates borrowers collateral by token and amount
     *         - line can liquidate at anytime based off other covenants besides cratio
     * @dev    - requires that the cratio is at or below the liquidation threshold
     * @dev    - only callable by `admin`
     * @param amount - the amount of tokens to liquidate
     * @param token  - the address of the token to draw funds from
     * @param to     - the address to receive the funds
     */
    function liquidate(uint256 amount, address token, address to) external {
        _checkLiquidatable();
        _onlyAdmin();
        state.liquidate(amount, token, to);
    }

    /**
     * @notice - if the line is ABORTED, the admin can recover the escrowed tokens
     * @dev    - callable by admin
     * @param token - the token to recover
     * @param to    - the address to send the tokens to
     */
    function recoverEscrowTokens(address token, address to, uint256 amount) external {
        if (
            _getLineAdmin() != msg.sender || _getLineStatus() != LineLib.STATUS.ABORTED
        ) {
            revert CallerAccessDenied();
        }
        state.liquidate(amount, token, to);
    }

    /**
     * @notice - if the line is ABORTED, the admin can recover the univ3 positions
     * @dev    - callable by admin
     * @param to - the address to send the univ3 positions to
     */
    function recoverUniV3Positions(address to) external {
        if (
            _getLineAdmin() != msg.sender || _getLineStatus() != LineLib.STATUS.ABORTED
        ) {
            revert CallerAccessDenied();
        }
        uniV3State.recoverUniv3Positions(to);
    }

    /**
     * @notice - if LIQUIDATABLE, the admin can send the uni v3 position to any address
     * @dev    - callable by admin
     * @param tokenId - the id of the uni v3 position
     * @param to      - the address we send the uni v3 position to
     */
    function liquidateUniV3Position(uint256 tokenId, address to) external nonReentrant {
        _checkLiquidatable();
        _onlyAdmin();
        uniV3State.liquidate(tokenId, to);
    }

    /**
     * @notice - update the borrower address
     * @dev    - only callable by the line
     * @dev    - handles both Escrow and LaaS escrow contracts
     */
    function updateBorrower(address newBorrower) external {
        _onlyOwner();
        emit UpdateBorrower(borrower, newBorrower);
        borrower = newBorrower;
    }

    /**
     * @notice - Allows borrower to update the minimum c ratio.
     * @dev    - callable by `borrower`
     * @dev    - requires line to not have open, active credit positions or outstanding debt to beneficiaries
     * @param newMinimumCollateralRatio - The minimum collateral ratio required for the line
     */
    function updateMinimumCollateralRatio(uint32 newMinimumCollateralRatio) external {
        _onlyBorrower();
        if (_getLineCount() == 0 && !state.isOutstandDebt()) {
            ISecuredLine(state.owner).clearProposals();
            minimumCollateralRatio = newMinimumCollateralRatio;
            _incrementNonce();
            emit UpdateMinimumCollateralRatio(newMinimumCollateralRatio);
        } else {
            revert CannotModifyWithActivePosition();
        }
    }

    /**
     * @notice - the admin can register a contract that might be used via the operate function. This can include, swapping, wrapping, staking etc
     * @dev    - only callable by admin
     * @param contractToRegister - the address of the contract to register
     */
    function registerBorrowerContract(address contractToRegister, bool state) external {
        _onlyAdmin();
        isContractRegistered[contractToRegister] = state;
    }

    /**
     * @notice - admin can whitelist certain functions on a registered borrower contract that can be called
     * @dev    - only callable by admin
     * @param functionToRegister - the function signature to whitelist
     */
    function whitelistFunction(bytes4 functionToRegister, bool state) external {
        _onlyAdmin();
        whitelistedFunctions[functionToRegister] = state;
    }

    /**
     * @notice - borrower and admin can call functions on registered contracts
     * @dev    - callable by borrower or admin
     * @param targetContract - the address of the contract to call
     * @param data           - the calldata for the function to call
     */
    function operate(address targetContract, bytes calldata data) external {
        _onlyBorrowerOrAdmin();
        state.operate(isContractRegistered, whitelistedFunctions, targetContract, data);
        _sync();
        _checkCollateralRatio();
    }

    /**
     * @notice - ensures accounting of collateral is up to date with the current balances of the escrow contract
     * @notice - if the discrepency is higher than accounted for, we add to collateral amounts
     * @notice - if the discrepency is lower than accounted for, we remove from claimable amounts first, then collateral amounts
     * @dev    - callable by admin
     */
    function sync() external {
        _onlyBorrowerOrServicer();
        _sync();
    }

    function _sync() internal {
        state.sync();
    }

    // Getters

    /**
     * @notice - returns addresses of all oracles used by the escrow and the uni v3 position manager
     * @return erc20Oracle - the address of the erc20 oracle
     * @return uniV3Oracle - the address of the univ3 oracle
     * @return nftPositionManager - the address of the univ3 nft position manager
     */
    function oracle() external view returns (address, address, address) {
        return (erc20Oracle, uniV3Oracle, uniV3State.nftPositionManager);
    }

    /**
     * @notice - returns if a token is whitelisted for otc trading
     * @param token - the token to check
     * @return - true if whitelisted
     */
    function isTokenWhitelisted(address token) external view returns (bool) {
        return otcState.stableCoinWhitelist[token];
    }

    /**
     * @notice - returns the price impact allowed for otc trading
     * @return - the price impact allowed
     */
    function getOTCPriceImpact() external view returns (uint128) {
        return otcState.nonStableCoinPriceImpact;
    }

    /**
     * @notice - returns all univ3 positions held by the escrow
     * @return - an array of token ids
     */
    function getUniV3Positions() external view returns (uint256[] memory) {
        return uniV3State.getUniV3Positions();
    }

    /**
     * @notice - returns the addresses of the univ3 manager and nft position manager
     * @return - the addresses of the univ3 manager and nft position manager
     */
    function getUniV3Roles() external view returns (address, address) {
        return (uniV3State.univ3Manager, uniV3State.nftPositionManager);
    }

    /**
     * @notice - checks the collateral ratio and reverts if it is below the minimum
     */
    function _checkCollateralRatio() internal {
        if (getCollateralRatio() < minimumCollateralRatio) {
            revert UnderCollateralized();
        }
    }

    // UniV3 MGMT FUNCTIONS

    /**
     * @notice - increase liquidity in a uniswap v3 position
     * @dev    - callable by univ3 manager
     * @param params - the parameters for increasing liquidity
     */
    function increaseLiquidity(INonFungiblePositionManager.IncreaseLiquidityParams calldata params) external {
        uniV3State.increaseLiquidity(state, params);
        _checkCollateralRatio();
    }

    /**
     * @notice - decrease liquidity in a uniswap v3 position
     * @notice - see INonFungiblePositionManager.sol
     * @dev    - callable by univ3 manager
     * @param params - the parameters for decreasing liquidity
     */
    function decreaseLiquidity(INonFungiblePositionManager.DecreaseLiquidityParams calldata params) external {
        uniV3State.decreaseLiquidity(state, params);
        _checkCollateralRatio();
    }

    /**
     * @notice - collect fees from a uniswap v3 position
     * @notice - see INonFungiblePositionManager.sol
     * @dev    - callable by univ3 manager
     * @param params - the parameters for collecting fees
     */
    function collect(INonFungiblePositionManager.CollectParams calldata params) external {
        uniV3State.collect(state, params);
        _checkCollateralRatio();
    }
    /**
     * @notice - burn a uniswap v3 position
     * @dev    - callable by borrower or any external address if line is liquidatable
     * @param params - the parameters for minting the position
     */

    function burn(INonFungiblePositionManager.DecreaseLiquidityParams calldata params) external {
        _onlyBorrowerOrIfLiquidatable();
        uniV3State.burn(state, params);
        _checkCollateralRatio();
    }

    /**
     * @notice - mint a uniswap v3 position
     * @dev    - callable by univ3 manager
     * @param pool   - the address of the pool to mint the position in
     * @param params - the parameters for minting the position
     */
    function mint(address pool, INonFungiblePositionManager.MintParams memory params) external {
        uniV3State.mint(state, pool, params, uniV3Oracle);
        _checkCollateralRatio();
    }
}
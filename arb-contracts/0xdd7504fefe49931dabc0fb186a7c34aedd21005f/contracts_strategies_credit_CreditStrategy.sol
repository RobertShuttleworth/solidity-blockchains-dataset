// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

// Openzeppelin imports
import {Math} from "./lib_openzeppelin-contracts_contracts_utils_math_Math.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {ERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {IERC20Metadata} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import {IERC721} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC721.sol";
import {IERC165} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC165.sol";

// Line-Of-Credit-v2
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {MutualConsent} from "./lib_Line-Of-Credit-v2_contracts_utils_MutualConsent.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {ISpigotedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigotedLine.sol";
import {ISecuredLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISecuredLine.sol";

// Vaults
import {FeeManager} from "./contracts_strategies_credit_FeeManager.sol";
import {ERC721Manager} from "./contracts_strategies_credit_ERC721Manager.sol";
import {ILendingVault} from "./contracts_interfaces_ILendingVault.sol";
import {ICreditStrategy} from "./contracts_interfaces_ICreditStrategy.sol";
import {ILiquidStrategy} from "./contracts_interfaces_ILiquidStrategy.sol";

/**
 * @title  - CreditStrategy
 * @author - Credit Cooperative
 * @notice - Interacts with Line-Of-Credit-v2 contracts on behalf of depositors to LendingVault.
 * @notice - Responsible for proposing, accepting, and impairing credit positions on behalf of the LendingVault.
 * @dev    - All external and public state changing functions, with the exception of swapCreditPositionForTokens, can only be called by the vault manager or vault operator roles.
 */
contract CreditStrategy is ERC721Manager, FeeManager, ICreditStrategy {
    using SafeERC20 for ERC20;

    // LineOfCredit mappings for tracking credit positions
    mapping(address => bool) private isLine;
    mapping(uint256 => address) public creditTokenIdToLine;
    uint256[] public tokenIds; // token ids of all open credit positions.

    address public immutable asset;

    /**
     * @notice  - How to deploy a Credit Coop Vault Manager
     * @dev     - A CreditStrategy determines parameters for the LendingVault including the underlying asset of the vault, the manager and operator addresses, the protocol fee split, the performance fee, and whether to enable a whitelist or not. Then the Vault manager deploys the contract using the constuctor below.
     * @dev     - If the manager enables a whitelist, then the manager will need to whitelist addresses that can deposit assets into the vault. Once funds have been deposited into the vault, the manager will be able to deploy funds into lines of credit.
     * @param _asset            - Native asset address of the vault.
     * @param _manager          - Address that manages the vault.
     * @param _protocolTreasury - Address that accrues fees from the vault.
     * @param _protocolSplit    - Percentage of fees that accrue to the protocol treasury.
     * @param _fees             - Performance and management fees that the vault will charge.
     * @param _whitelistEnabled - Whether the vault whitelist is enabled or not.
     * @param _lendingVault     - Address of the LendingVault.
     */
    constructor(
        address _asset,
        address _manager,
        address _protocolTreasury,
        uint8 _protocolSplit,
        Fees memory _fees,
        bool _whitelistEnabled,
        address _lendingVault
    ) {
        if (_manager == address(0) || _lendingVault == address(0)) {
            revert ILendingVault.CannotBeZeroAddress();
        }

        asset = _asset;
        baseUnit = 10 ** IERC20Metadata(address(_asset)).decimals();
        highWaterMarkSharePrice = baseUnit; // set initial highWaterMarkSharePrice to baseUnit
        emit SetHighWaterMarkSharePrice(highWaterMarkSharePrice);

        manager = _manager;
        isOperator[_manager] = true;
        whitelistEnabled = _whitelistEnabled;
        emit SetWhitelistStatus(_whitelistEnabled);

        protocolTreasury = _protocolTreasury;
        lendingVault = _lendingVault;

        // assert and set protocolSplit and vault fees
        _assertMaxProtocolSplit(_protocolSplit);
        protocolSplit = _protocolSplit;
        emit UpdateProtocolSplit(protocolSplit);

        // assert and set vault fees
        _assertMaxFee(_fees.performance, FeeTypes.PERFORMANCE);
        _assertMaxFee(_fees.management, FeeTypes.MANAGEMENT);
        fees = _fees;

        lastManagementFeeTimestamp = block.timestamp;
    }

    /*///////////////////////////////////////////////////////////////
                        FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  - Returns the principal and interest owed across all credit positions owned by the CreditStrategy.
     * @return totalActiveCredit - Total principal and interest owed, including both interest accrued and interest repaid, across all credit positions.
     */
    function totalActiveCredit() public view returns (uint256 totalActiveCredit) {

        // Iterate through tokenIds array to get principal and interest owed for all credit positions
        uint256 len = tokenIds.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 tokenId = tokenIds[i];
            address line = creditTokenIdToLine[tokenId];
            (uint256 deposit, uint256 interest) = getPositionActiveCredit(line, tokenId);

            // add credit deposit and interest to total
            totalActiveCredit += (deposit + interest);
        }
    }

    /**
     * @notice  - Indicates the amount of active credit (deposit and interest) for a credit position.
     * @param line      - Address of the line of credit.
     * @param tokenId   - Token id of the credit position.
     * @return deposit - Total amount of deposit owed for the credit position.
     * @return interest - Total amount of interest owed for the credit position.
     */
    function getPositionActiveCredit(address line, uint256 tokenId) public view returns (uint256 deposit, uint256 interest) {
        address tokenContract = address(ILineOfCredit(line).tokenContract());
        bool isOwned = ownerOfTokenId(tokenContract, tokenId) == address(this);
        uint8 status = uint8(ILineOfCredit(line).status());

        if (
            line != address(0) // valid line
            && isOwned // credit position owned by credit strategy
            && status != uint8(LineLib.STATUS.INSOLVENT) // line is not INSOLVENT
            && status != uint8(LineLib.STATUS.ABORTED) // line is not ABORTED
        ) {
            ILineOfCredit.Credit memory credit = ILineOfCredit(line).getCreditPosition(tokenId);
            uint256 interestAccrued = ILineOfCredit(line).interestAccrued(tokenId);

            // only add accrued interest for open credit positions
            if (credit.isOpen) {
                interest += interestAccrued;
            }

            // add deposit to principal owed
            deposit = credit.deposit;

            // add interest repaid to interest owed
            interest += credit.interestRepaid;
        }
    }

    /**
     * @notice - Checks only the `buyToken` is equivalent to CreditStrategy `asset`.
     */
    function _onlyVaultAssetSupported(address buyToken) internal view {
        if (buyToken != address(asset)) {
            revert AssetNotSupported();
        }
    }

    /**
     * @notice - Checks only callable by `lendingVault` or `manager`.
     */
    function _onlyLendingVaultOrManager() internal view {
        if (msg.sender != lendingVault && msg.sender != manager) {
            revert OnlyLendingVaultOrManager();
        }
    }

   /**
     * @notice  - Returns the number of active credit positions owned by the CreditStrategy.
     * @return  - Count of credit positions.
     */
    function numCreditPositions() external view returns (uint256) {
        return tokenIds.length;
    }

    /**
     * @notice  - Approves a line of credit to spend a certain amount of the vault's assets.
     * @dev     - Only callable by the manager.
     * @param line      - Address of the line of credit to approve.
     * @param amount    - Amount of the vault's assets to approve the line of credit to spend.
     */
    function approve(address line, uint256 amount) external {
        _onlyVaultManager();
        ERC20(asset).forceApprove(line, amount);
    }

    /**
     * @notice  - Deposits assets into the CreditStrategy contract.
     * @dev     - Only callable by `lendingVault` or `manager`.
     * @param _amount - Amount to deposit (denominated in asset of the CreditStrategy contract).
     */
    function deposit(uint256 _amount) external {
        _onlyLendingVaultOrManager();
        ERC20(asset).safeTransferFrom(msg.sender, address(this), _amount);
        emit ManagerDeposit(msg.sender, _amount);
    }

    /**
     * @notice  - Withdraws assets from CreditStrategy contract and transfers them to the LendingVault.
     * @dev     - Only callable by `lendingVault` or `manager`.
     * @param _amount - Amount to withdraw (denominated in asset of the Strategy).
     */
    function withdraw(uint256 _amount) external {
        _onlyLendingVaultOrManager();
        ERC20(asset).safeTransfer(lendingVault, _amount);
        emit ManagerWithdraw(msg.sender, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                SUPPORTS CreditStrategy.addCreditPosition
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice - Returns true if the contract supports the CreditStrategy.addCreditPosition function.
     * @param interfaceId - interface ID to check for support.
     * @return            - True if the contract supports the CreditStrategy.addCreditPosition function.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        pure
        returns (bool)
    {
        // Return true if the provided interfaceId matches addCreditPosition
        return interfaceId == ICreditStrategy.addCreditPosition.selector
            || interfaceId == type(IERC165).interfaceId;
    }


    /**
     * @notice  - Proposes, or accepts a credit position to a line of credit with the addCredit() function in LineOfCredit. Usually, the vault will be proposing a credit position to a line of credit, but the vault can also accept a credit position proposed by a borrower.
     * @dev     - Only callable by the manager. Will revert if the vault does not have sufficient liquid assets to propose the credit position. Will revert if the vault attempts to lend to a line for which it is the borrower.
     * @param line               - Address of the line of credit to propose the position to.
     * @param drate              - Drawn rate of the credit position.
     * @param frate              - Facility rate of the credit position.
     * @param amount             - Amount of assets to propose to the line of credit.
     * @param isRestricted       - Whether the credit position is restricted or not.
     * @param earlyWithdrawalFee - Early withdrawal fee of the credit position.
     * @param deadline           - Deadline of the credit position.
     * @return                   - Returns tuple (true, tokenId) if the credit position was proposed successfully, otherwise (false, 0).
     */
    function addCredit(
        address line,
        uint256 desiredNonce,
        uint128 drate,
        uint128 frate,
        uint256 amount,
        bool isRestricted,
        uint16 earlyWithdrawalFee,
        uint256 deadline
    ) external nonReentrant returns (bool, uint256 tokenId) {
        _onlyVaultManager();



        if (ILineOfCredit(line).borrower() == address(this) || ILineOfCredit(line).borrower() == address(lendingVault))
        {
            revert CannotLendToSelf();
        }

        // Add line to isLine mapping
        isLine[line] = true;

        tokenId = ILineOfCredit(line).addCredit(
            desiredNonce,
            drate,
            frate,
            amount,
            address(asset),
            address(this),
            isRestricted,
            earlyWithdrawalFee,
            deadline
        );
        return (true, tokenId);
    }

    /**
     * @notice  - Revokes vault's consent for a credit proposal (i.e. addCredit or refinanceCredit).
     * @dev     - Only callable by the `manager` or `operator`.
     * @dev     - Reverts if the function selector in the reconstructed message data is not a valid function selector for the revokeConsent() function in LineOfCredit.
     * @param line                 - Address of the line of credit to propose the position to.
     * @param tokenId              - TokenId of the credit position to revoke the proposal from.
     * @param reconstructedMsgData - The reconstructed message data of the proposal to revoke.
     */
    function revokeProposal(address line, uint256 tokenId, bytes calldata reconstructedMsgData) external nonReentrant {
        _onlyOperator();

        ISecuredLine(line).revokeConsent(tokenId, reconstructedMsgData);
    }

    /**
     * @notice  - Creates a proposal to refinance a credit position.
     * @dev     - Only callable by the manager.
     * @param line     - Address of the line of credit to make the proposal to.
     * @param tokenId  - TokenId of the credit position to refinance.
     * @param amount   - Amount of assets to add to the credit position.
     * @param dRate    - New drawn rate to set on the credit position.
     * @param fRate    - New facility rate to set on the credit position.
     * @param deadline - New deadline to propose to the credit position.
     */
    function refinanceCredit(
        address line,
        uint256 desiredNonce,
        uint256 tokenId,
        uint256 amount,
        uint128 dRate,
        uint128 fRate,
        uint256 deadline
    ) external nonReentrant returns (bool) {
        _onlyVaultManager();
        ILineOfCredit(line).refinanceCredit(desiredNonce, tokenId, amount, dRate, fRate, deadline);
        return true;
    }

    /**
     * @notice  - Repays a line of credit with the line's reserves.
     * @dev     - Only callable by the manager or operator.
     * @param line   - Address of the line of credit to repay.
     * @param amount - Amount of assets from reserves to repay the line of credit.
     */
    function useAndRepay(address line, uint256 amount) external nonReentrant {
        _onlyOperator();
        ISpigotedLine(line).useAndRepay(amount);
    }

    /**
     * @notice  - Withdraws credit from a credit position
     * @dev     - Only callable by the manager or operator.
     * @param line      - Address of the line of credit to withdraw from.
     * @param tokenId   - TokenId of the credit position to withdraw from.
     * @param amount    - Amount to withdraw from the credit position.
     *
     */
    function withdrawCredit(address line, uint256 tokenId, uint256 amount) external nonReentrant {
        _onlyOperator();
        if (amount == 0) {
            revert NoWithdrawableAssets();
        }

        (, uint256 interestRepaid) = ILineOfCredit(line).available(tokenId);
        _accrueFees();
        if (amount >= interestRepaid) {
            uint256 depositToWithdraw = amount - interestRepaid;
            emit WithdrawProfit(line, tokenId, interestRepaid);
            emit WithdrawDeposit(line, tokenId, depositToWithdraw);
        } else if (amount < interestRepaid) {
            emit WithdrawProfit(line, tokenId, amount);
            emit WithdrawDeposit(line, tokenId, 0);
        }
        ILineOfCredit(line).withdraw(tokenId, amount);
    }

    /**
     * @notice  - Updates CreditStrategy accounting for ERC-721 credit position after successful callback from a SecuredLine.
     * @dev     - Only callable by `line` in `SecuredLine.addCredit()` and `SecuredLine.refinanceCredit()`.
     * @param tokenId          - id of the credit position.
     * @return                 - True if the credit position was successfully minted to the CreditStrategy.
     */
    function addCreditPosition(uint256 tokenId) public returns (bool) {
        // Reverts if caller is not the line or the line is not in the line mapping
        if (isLine[msg.sender] != true) {
            revert CallerNotLine();
        }

        // add to tokenIds if tokenId is not already in tokenIds
        if (creditTokenIdToLine[tokenId] == address(0)) {
            tokenIds.push(tokenId);
            creditTokenIdToLine[tokenId] = msg.sender;
        }

        return true;
    }

    /**
     * @notice  - Swaps a credit position owned by the vault for ERC20 tokens.
     * @dev     - Called via mutual consent by the manager and the buyer.
     * @param line                - Address of the line of credit where the credit position exists.
     * @param creditPositionToken - Address of the credit position token.
     * @param tokenId             - Id of the credit position to swap.
     * @param buyer               - Address of the buyer.
     * @param receiver            - Address of the receiver.
     * @param buyToken            - Address of the token to buy the credit position with. Must be the same as the vault's asset.
     * @param buyTokenAmount      - Amount of buyToken to buy the credit position with.
     */
    function swapCreditPositionForTokens(
        address line,
        address creditPositionToken,
        uint256 tokenId,
        address buyer,
        address receiver,
        address buyToken,
        uint256 buyTokenAmount
    ) external mutualConsent(manager, buyer) returns (bool) {
        _onlyVaultAssetSupported(buyToken);

        // Vault transfers Credit Position Token to receiver
        IERC721(creditPositionToken).transferFrom(address(this), receiver, tokenId);

        // buyer pays CreditStrategy for Credit Position Token
        ERC20(buyToken).safeTransferFrom(buyer, address(this), buyTokenAmount);
        emit SwapCreditPositionForTokens(line, tokenId, buyer, buyToken, buyTokenAmount);

        // Update vault accounting
        _sync();

        return true;
    }

    /**
     * @notice  - Updates Vault accounting when at least one credit position is sold/transferred to a buyer in exchange for ERC20 tokens. Calculates performance and management fees and creates new shares.
     * @dev     - Only callable by the manager or operator.
     * @dev     - Should be called before processing deposit and redeem requests.
     */
    function sync() external {
        _onlyOperator();
        _sync();
    }

    function _sync() internal {

        // Iterate through all credit positions owned by the CreditStrategy to reset totalAssets()
        uint256 index = tokenIds.length;
        while (index > 0) {
            index--;
            uint256 tokenId = tokenIds[index];
            address line = creditTokenIdToLine[tokenId];
            address tokenContract = address(ILineOfCredit(line).tokenContract());
            address tokenOwner = ownerOfTokenId(tokenContract, tokenId);

            // If the token owner is not the CreditStrategy, we remove the tokenId
            if (tokenOwner != address(this)) {
                creditTokenIdToLine[tokenId] = address(0);
                _removeTokenId(index);
            }
        }

        // accrue management and performance fees for vault manager
        _accrueFees();

    }


    /**
     * @notice  - Removes a tokenId from the tokenIds array without preserving the order.
     * @param index - The index of the tokenId to remove.
     */
    function _removeTokenId(uint256 index) internal {
        tokenIds[index] = tokenIds[tokenIds.length - 1]; // Overwrite the tokenId at the index with the last tokenId
        tokenIds.pop(); // Removes the last element, reducing the array's length
    }

    /*///////////////////////////////////////////////////////////////
                        RECOVERY
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  - Transfers ERC20 tokens from the CreditStrategy contract to arbitrary `to` destination. Can be used to recover tokens not in the underlying asset or in emergency situations.
     * @dev     - Only callable by the manager.
     * @param token     - Address of the ERC20 token to recover.
     * @param to        - Address to send the recovered tokens to.
     * @param amount    - Amount of tokens to recover.
     */
    function recoverTokens(address token, address to, uint256 amount) external {
        _onlyVaultManager();
        ERC20(token).safeTransfer(to, amount);
        emit TokensRecovered(msg.sender, to, token, amount);
    }
}
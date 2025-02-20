// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BridgeErrors} from "./contracts_BridgeErrors.sol";
import {AccessControl} from "./openzeppelin_contracts_access_AccessControl.sol";
import {AccessControlDefaultAdminRules} from "./openzeppelin_contracts_access_extensions_AccessControlDefaultAdminRules.sol";
import {Pausable} from "./openzeppelin_contracts_utils_Pausable.sol";
import {ReentrancyGuard} from "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import {ECDSA} from "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";

/// @dev OperaBridge is a contract to handle bridging of native tokens between Opera and Sonic chains.
/// @custom:security-contact security@fantom.foundation
contract OperaBridge is AccessControlDefaultAdminRules, Pausable, ReentrancyGuard {
    uint256 public signatureThreshold; // number of valid signatures required to process a batch

    uint256 public depositFee; // amount subtracted from a deposit as a flat fee; prevents abuse
    uint256 public minDepositAmount; // minimal amount of tokens to be deposited; prevents dust swaps
    uint256 public maxDepositAmount; // maximal amount of tokens to be deposited

    uint256 public reserveBalance; // the max amount of liquidity supposed to be kept on the bridge contract
    address public reserveDrain; // the address to be used to drain excessive liquidity to

    uint256 public immutable peerChainID; // chain ID of the deposits to be resolved here
    uint256 public lastBatchID; // the latest processed batch ID
    uint256 public lastResolvedDepositID; // the ID of the latest processed/resolved deposit

    uint256 public lastDepositID; // monotonic self chain deposit ID

    /// @dev Role for the validators signing the batch of deposits.
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");

    /// @dev Role for the pause/unpause operations.
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");

    struct Deposit {
        uint256 id; // deposit ID
        address recipient; // recipient of the deposit
        uint256 amount; // amount of the deposit
    }

    /// @dev Maps deposit ID of a failed deposit settlement to the original deposit record for later processing.
    mapping(uint256 depositID => Deposit deposit) public unresolvedDeposit;

    /// @dev Emitted when the tokens are deposited to the bridge contract.
    /// @param recipient The recipient of the deposit.
    /// @param id The deposit ID.
    /// @param amount The amount of the deposit.
    /// @param fee The fee subtracted from the deposit.
    event Deposited(address indexed recipient, uint256 indexed id, uint256 amount, uint256 fee);

    /// @dev Emitted when the deposit is resolved on the peer chain.
    /// @param recipient The recipient of the deposit.
    /// @param id The deposit ID.
    event Resolved(address indexed recipient, uint256 indexed id);

    /// @dev Emitted when a deposit is not resolved due to a settlement sub-call revert.
    /// This may happen if a contract was deployed on the recipient EOA address via EIP-7702.
    /// @param recipient The recipient of the failed deposit.
    /// @param id The deposit ID.
    event Failed(address indexed recipient, uint256 indexed id);

    /// @dev Emitted when the batch of deposits is processed.
    /// @param id The batch ID.
    event BatchProcessed(uint256 indexed id);

    /// @dev Emitted when the required signature threshold for batch processing gets updated.
    /// @param newSignatureThreshold The new number of signatures required to confirm a batch.
    event SignatureThresholdUpdated(uint256 newSignatureThreshold);

    /// @dev Emitted when the amount of fee deducted from a deposited amount gets updated.
    /// @param newDepositFee The new amount of fee to be deducted from deposits.
    event DepositFeeUpdated(uint256 newDepositFee);

    /// @dev Emitted when the required minimal deposited amount gets updated.
    /// @param newMinimalDepositAmount The new minimal required amount of deposit.
    event MinimalDepositAmountUpdated(uint256 newMinimalDepositAmount);

    /// @dev Emitted when the required maximal deposited amount gets updated.
    /// @param newMaximalDepositAmount The new maximal required amount of deposit.
    event MaximalDepositAmountUpdated(uint256 newMaximalDepositAmount);

    /// @dev Emitted when the maximal reserve amount and the excessive reserve drain address gets updated.
    /// @param newReserveAmount The new maximal amount of liquidity reserve to be kept on contract.
    /// @param newReserveDrain The new excessive reserve balance recipient address.
    event ReserveBalanceUpdated(uint256 newReserveAmount, address newReserveDrain);

    /// @dev Initializes the bridge contract with the given parameters.
    /// @param _cfgAdmin The address of the configuration admin.
    /// @param _peerChainID The chain ID of the deposits to be resolved.
    /// @param _fee The deposit fee.
    /// @param _minDeposit The minimal deposit amount.
    /// @param _sigThreshold The signature threshold to process a batch.
    /// @param _batchCheckpoint The checkpoint of the last processed batch.
    constructor(
        address _cfgAdmin,
        uint256 _peerChainID,
        uint256 _fee,
        uint256 _minDeposit,
        uint256 _sigThreshold,
        uint256 _batchCheckpoint) AccessControlDefaultAdminRules(5 days, _cfgAdmin) ReentrancyGuard()
    {
        if (_minDeposit <= _fee) {
            revert BridgeErrors.InvalidMinDepositToFee(_minDeposit, _fee);
        }

        if (_sigThreshold == 0) {
            revert BridgeErrors.InvalidSignatureThreshold();
        }

        peerChainID = _peerChainID;
        depositFee = _fee;
        minDepositAmount = _minDeposit;
        // prevent large deposits after deployment, desired amount will be set later
        maxDepositAmount = _minDeposit + 1 ether;
        signatureThreshold = _sigThreshold;
        lastBatchID = _batchCheckpoint;
    }

    /// @dev Fallback function to reject any incoming value.
    receive() external payable {
        // reject implicit deposit and/or refill; included to revert with custom error
        revert BridgeErrors.InvalidImplicitDeposit(msg.value);
    }

    /// @dev Deposits the tokens to the bridge contract to be resolved on the peer chain.
    /// @param fee The fee valid at the time of deposit.
    function deposit(uint256 fee) external payable whenNotPaused {
        if (msg.value < minDepositAmount) {
            revert BridgeErrors.DepositBelowLimit(minDepositAmount, msg.value);
        }

        if (msg.value > maxDepositAmount) {
            revert BridgeErrors.DepositAboveLimit(maxDepositAmount, msg.value);
        }

        if (fee != depositFee) {
            revert BridgeErrors.FeeChanged(depositFee, fee);
        }

        if (msg.sender != tx.origin) {
            revert BridgeErrors.InvalidRecipient(msg.sender, tx.origin);
        }

        lastDepositID++; // no deposit #0
        emit Deposited(msg.sender, lastDepositID, msg.value - depositFee, depositFee);
    }

    /// @dev Resolves the batch of deposits on the peer chain.
    /// The batch has to be signed by the validators to be resolved.
    /// @param batchID The batch ID of the deposits to be resolved.
    /// @param total The total amount of the deposits in the batch.
    /// @param deposits The array of deposits to be resolved.
    /// @param signatures The array of signatures to be verified.
    function resolve(uint256 batchID, uint256 total, Deposit[] calldata deposits, bytes[] calldata signatures) external {
        // fail early on relay of an old batch
        if (!_isValidBatchSequence(lastBatchID, batchID)) {
            revert BridgeErrors.InvalidBatchSequence(lastBatchID, batchID);
        }

        // fail early on balance deficit so we can retry the batch later
        if (address(this).balance < total) {
            revert BridgeErrors.InsufficientLiquidity(address(this).balance, total);
        }

        uint256 sig = _verifySignatures(batchID, total, deposits, signatures);
        if (sig < signatureThreshold) {
            revert BridgeErrors.SignatureDeficit(signatureThreshold, sig);
        }

        _processBatch(batchID, total, deposits);

        emit BatchProcessed(batchID);
    }

    /// @dev Processes the batch of deposits on the peer chain.
    /// The batch is processed by transferring the tokens to the recipients.
    /// @param batchID The batch ID of the deposits to be processed.
    /// @param total The total amount of the deposits in the batch.
    /// @param deposits The array of deposits to be processed.
    function _processBatch(uint256 batchID, uint256 total, Deposit[] calldata deposits) internal nonReentrant {
        uint256 depositSum;
        lastBatchID = batchID;
        uint256 _lastResolvedDeposit = lastResolvedDepositID;

        for (uint256 i; i < deposits.length; i++) {
            if (deposits[i].id != _lastResolvedDeposit + 1) {
                revert BridgeErrors.InvalidDepositSequence(_lastResolvedDeposit, deposits[i].id);
            }
            _lastResolvedDeposit = deposits[i].id;
            depositSum += deposits[i].amount;

            // the recipient is enforced to be EOA by deposit(); this is expected not to fail
            // potentially, EIP-7702 allows to deploy a code on the recipient EOA; this code may reject the call
            // failed settlements are stored to be resolved later by the recipient using the claim() function
            (bool _success,) = payable(deposits[i].recipient).call{value: deposits[i].amount, gas: 0}("");
            if (!_success) {
                unresolvedDeposit[deposits[i].id] = deposits[i];
                emit Failed(deposits[i].recipient, deposits[i].id);
                continue;
            }

            emit Resolved(deposits[i].recipient, deposits[i].id);
        }

        if (depositSum != total) {
            revert BridgeErrors.InvalidDepositSum(total, depositSum);
        }
        lastResolvedDepositID = _lastResolvedDeposit;
    }

    /// @dev Allows to resolve a failed deposit to a different receiver, if the original recipient can not receive
    /// settlement transaction because of a code deployed via EIP-7702 after deposit() and before resolve().
    /// The claim must be submitted by the original sender/recipient of the deposit to succeed.
    /// @param depositID The ID of an unresolved deposit waiting to be claimed.
    /// @param receiver The new recipient of the failed deposit amount.
    function claim(uint256 depositID, address receiver) external nonReentrant {
        // the failed settlement must exist
        if (unresolvedDeposit[depositID].id != depositID) {
            revert BridgeErrors.DepositNotFound(depositID);
        }

        // the claim must be made by the original recipient; may be a contract due to EIP-7702
        if (unresolvedDeposit[depositID].recipient != msg.sender) {
            revert BridgeErrors.InvalidClaimRequests(unresolvedDeposit[depositID].recipient);
        }

        uint256 amount = unresolvedDeposit[depositID].amount;
        if (address(this).balance < amount) {
            revert BridgeErrors.InsufficientLiquidity(address(this).balance, amount);
        }

        delete unresolvedDeposit[depositID];

        (bool _success,) = payable(receiver).call{value: amount}("");
        if (!_success) {
            revert BridgeErrors.DepositSettlementFailed(receiver, amount);
        }

        emit Resolved(receiver, depositID);
    }

    /// @dev Checks if the batch ID is valid and follows the expected sequence.
    /// The batch ID is [4]uint64{ peer chainID, sequenceID, blockID, deposit event/log index }.
    /// This encoding allows stateless relays to synchronise on the same batch start without additional communication.
    /// @param _last The last batch ID.
    /// @param _new The new batch ID.
    /// @return True if the batch ID is valid and follows the sequence.
    function _isValidBatchSequence(uint256 _last, uint256 _new) internal view returns (bool) {
        return (uint128(_new) > uint128(_last)) && /* monotonic progression is enforced */
            (_new >> 192 == peerChainID) && /* the batch must come from the expected peer chain */
            (uint64(_new >> 128) == uint64(_last >> 128) + 1); /* the sequence must follow after the previous one */
    }

    /// @dev Verifies the signatures of the validators for given deposits in a batch.
    /// The batchID approves the intended peer chain origin and the local Chain ID and contract address ensures
    /// the signatures are intended to be used specifically on this chain and contract. This prevents
    /// a potential speculative replay attack in case of several deployments of the bridge.
    /// @param batchID The batch ID of the deposits to be resolved.
    /// @param total The total amount of the deposits in the batch.
    /// @param deposits The array of deposits to be resolved.
    /// @param signatures The array of signatures to be verified.
    /// @return The number of valid signatures.
    function _verifySignatures(uint256 batchID, uint256 total, Deposit[] calldata deposits,
        bytes[] calldata signatures) internal view returns (uint256)
    {
        bytes32 msgHash = keccak256(abi.encode(block.chainid, address(this), batchID, total, deposits));

        uint256 valid;
        address lastSigner; // signatures must be sorted by address; it simplifies check for unique signature

        for (uint256 i; i < signatures.length; i++) {
            address signer = ECDSA.recover(msgHash, signatures[i]);
            if (signer > lastSigner && hasRole(VALIDATOR_ROLE, signer)) {
                lastSigner = signer;
                valid++;
            }
        }

        return valid;
    }

    /// @dev Drains the excessive liquidity from the bridge contract to the reserve drain address.
    function drain() external {
        if (reserveDrain == address(0)) {
            revert BridgeErrors.InvalidDrainAddress();
        }

        if (address(this).balance <= reserveBalance) {
            revert BridgeErrors.BalanceBelowLimit(reserveBalance, address(this).balance);
        }

        // the recipient is managed by DEFAULT_ADMIN_ROLE; we assume it's safe to transfer there
        (bool _success,) = payable(reserveDrain).call{value: (address(this).balance - reserveBalance), gas: 0}("");
        if (!_success) {
            revert BridgeErrors.DrainFailed(reserveDrain, (address(this).balance - reserveBalance));
        }
    }

    /// @dev Refills the bridge contract with the liquidity.
    function refill() external payable {
        if (address(this).balance > reserveBalance) {
            revert BridgeErrors.BalanceOverLimit(reserveBalance, address(this).balance);
        }
    }

    /// @dev Sets the signature threshold to process a batch.
    /// @param _threshold The new signature threshold.
    function setSignatureThreshold(uint256 _threshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_threshold == 0) {
            revert BridgeErrors.InvalidSignatureThreshold();
        }
        signatureThreshold = _threshold;
        emit SignatureThresholdUpdated(_threshold);
    }

    /// @dev Sets the deposit fee.
    /// @param _fee The new deposit fee.
    function setDepositFee(uint256 _fee) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_fee >= minDepositAmount) {
            revert BridgeErrors.InvalidMinDepositToFee(minDepositAmount, _fee);
        }
        depositFee = _fee;
        emit DepositFeeUpdated(_fee);
    }

    /// @dev Sets the minimal deposit amount.
    /// @param _min The new minimal deposit amount.
    function setMinimalDeposit(uint256 _min) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_min <= depositFee) {
            revert BridgeErrors.InvalidMinDepositToFee(_min, depositFee);
        }
        minDepositAmount = _min;
        emit MinimalDepositAmountUpdated(_min);
    }

    /// @dev Sets the maximal deposit amount.
    /// @param _max The new maximal deposit amount.
    function setMaximalDeposit(uint256 _max) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_max < minDepositAmount) {
            revert BridgeErrors.InvalidMaxDepositToMinDeposit(_max, minDepositAmount);
        }
        maxDepositAmount = _max;
        emit MaximalDepositAmountUpdated(_max);
    }

    /// @dev Sets the reserve balance and the address to drain excessive liquidity to.
    /// @param _balance The new reserve balance.
    /// @param _drain The new reserve drain address.
    function setReserveBalance(uint256 _balance, address _drain) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_drain == address(0)) {
            revert BridgeErrors.InvalidDrainAddress();
        }
        reserveBalance = _balance;
        reserveDrain = _drain;
        emit ReserveBalanceUpdated(_balance, _drain);
    }

    /// @dev Pauses the contract.
    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }

    /// @dev Unpauses the contract.
    function unpause() external onlyRole(PAUSE_ROLE) {
        _unpause();
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

contract DealGuardEscrow is Ownable, ReentrancyGuard {

    enum EscrowStatus { AWAITING_PAYMENT, AWAITING_DELIVERY, DELIVERED, ASK_DISPUTE, IN_DISPUTE, AWAITING_CONCILIATOR_ACCEPTANCE, COMPLETE }
    enum DisputeResolution { NONE, AI, HUMAN }

    struct Escrow {
        address buyer;
        address seller;
        uint256 amount;
        uint256 deliveryTime;
        string termsHash;
        EscrowStatus status;
        uint256 statusTime;
        DisputeResolution resolutionType;
        address conciliator;
        uint8 recusalCount;
        bool finalized;
        uint256 conciliatorFee;
        bool buyerRecusal;
        bool sellerRecusal;
        address tokenAddress; // `address(0)` para moedas nativas
        address disputeInitiator;
        uint256 creationTime;
        bool isNativeToken; // Novo campo para identificar moedas nativas
    }

    struct TransactionInfo {
        uint256 count;
        uint256 lastReset;
    }

    struct PendingApproval {
        address initiator;
        address approver;
        bool approvedByInitiator;
        bool approvedByApprover;
        bytes32 operation;
    }

    mapping(uint256 => Escrow) public escrows;
    mapping(address => TransactionInfo) public transactionInfo;
    mapping(bytes32 => PendingApproval) public pendingApprovals;
    mapping(address => uint256[]) private userEscrows;
    uint256 public escrowCount;
    uint256 public feePercentage = 7; // 0.7% fee
    uint256 public constant MAX_RECUSES = 6;
    uint256 public constant MAX_COMMISSION = 8;
    address public feeWallet = 0xF3f8A87396Dc26DEf6D22970DbFb8E2B27eEba4C;
    address public dgt_token = 0x518Eb73A88060972b19d909d515054DBd9b02E05;
    uint256 public constant MAX_TRANSACTIONS_PER_PERIOD = 200;
    uint256 public constant RESET_PERIOD = 5 minutes;
    uint256 public constant MIN_DELIVERY_TIME = 2 days;
    uint256 public constant MAX_DELIVERY_TIME = 45 days;
    uint256 public constant DEFAULT_DELIVERY_TIME = 14 days;
    address[] public conciliatorsList;

    address public secondSigner = 0x74bC7d4Caadd16fD3170A71B4312038298899F10;
    address public governanceContract;

    mapping(address => bool) public approvedTokens;
    mapping(address => bool) public electedConciliators;

    event EscrowCreated(uint256 indexed escrowId, address indexed buyer, address indexed seller, uint256 amount, uint256 deliveryTime, string termsHash, address tokenAddress);
    event ProductSent(uint256 escrowId);
    event DeliveryConfirmed(uint256 escrowId);
    event DisputeOpened(uint256 escrowId, address initiator);
    event EscrowCompleted(uint256 escrowId, address winner);
    event ConciliatorRecused(uint256 escrowId, address conciliator);
    event PartialPayment(uint256 escrowId, uint256 paymentToBuyer, uint256 paymentToSeller);
    event ConciliatorAssigned(uint256 escrowId, address conciliator);
    event ConciliatorAccepted(uint256 escrowId, address conciliator, uint256 fee);
    event EscrowStatusChanged(uint256 indexed escrowId, EscrowStatus status);
    event TokenApproved(address token);
    event TokenRemoved(address token);
    event FeeWalletUpdated(address newFeeWallet);
    event ApprovalInitiated(bytes32 operation, address initiator);
    event ApprovalCompleted(bytes32 operation, address initiator, address approver);
    event FeePercentageUpdated(uint256 newFeePercentage);
    event DGTUpdated(address token);

    // >>> Novo evento para Issue #2 <<<
    event GovernanceContractUpdated(address newGovernanceContract);

    constructor() Ownable(msg.sender) {
        // Initialize with DGT token approved
        approvedTokens[dgt_token] = true;
    }

    modifier onlyApprovedToken(address tokenAddress) {
        require(approvedTokens[tokenAddress], "Token is not approved");
        _;
    }

    modifier limitTransactions(address user) {
        TransactionInfo storage info = transactionInfo[user];
        if (block.timestamp > info.lastReset + RESET_PERIOD) {
            info.count = 0;
            info.lastReset = block.timestamp;
        }
        require(info.count < MAX_TRANSACTIONS_PER_PERIOD, "Transaction limit exceeded");
        _;
        info.count++;
    }

    modifier onlySigner() {
        require(msg.sender == owner() || msg.sender == secondSigner, "Only signers allowed");
        _;
    }

    modifier requiresApproval(bytes32 operation) {
        require(pendingApprovals[operation].approvedByInitiator && pendingApprovals[operation].approvedByApprover, "Operation not approved by both signers");
        _;
        delete pendingApprovals[operation];
    }

    modifier onlyGovernance() {
        require(msg.sender == governanceContract, "Only governance contract can call this function");
        _;
    }

    receive() external payable {
        // Allows the contract to receive native coins directly.
    }

    function initiateApproval(bytes32 operation) public onlySigner {
        pendingApprovals[operation] = PendingApproval({
            initiator: msg.sender,
            approver: (msg.sender == owner()) ? secondSigner : owner(),
            approvedByInitiator: true,
            approvedByApprover: false,
            operation: operation
        });
        emit ApprovalInitiated(operation, msg.sender);
    }

    function approveOperation(bytes32 operation) public onlySigner {
        PendingApproval storage approval = pendingApprovals[operation];
        require(approval.approver == msg.sender, "Not authorized to approve");
        require(approval.approvedByInitiator, "Initiator approval required");
        approval.approvedByApprover = true;
        emit ApprovalCompleted(operation, approval.initiator, msg.sender);
    }

    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function setGovernanceContract(address _governanceContract) external onlySigner requiresApproval(keccak256("setGovernanceContract")) {
        // >>> Adjustment for Issue #3 (zero address) <<<
        require(_governanceContract != address(0), "Governance contract cannot be zero");
        require(_isContract(_governanceContract), "Token address must be a contract");
        governanceContract = _governanceContract;
        // >>> Adjustment for Issue #3 (zero address) <<<
        emit GovernanceContractUpdated(_governanceContract);
    }

    function setFeeWallet(address newFeeWallet) external {
        // >>> Adjustment for Issue #3 (zero address) <<<
        require(newFeeWallet != address(0), "Fee wallet cannot be zero address");

        if (msg.sender == governanceContract) {
            feeWallet = newFeeWallet;
        } else {
            require(msg.sender == owner() || msg.sender == secondSigner, "Only signers allowed");
            initiateApproval(keccak256(abi.encodePacked("setFeeWallet", newFeeWallet)));
        }
        emit FeeWalletUpdated(newFeeWallet);
    }

    function setFeePercentage(uint256 newFeePercentage) external {
        if (msg.sender == governanceContract || msg.sender == owner()) {
            feePercentage = newFeePercentage;
            emit FeePercentageUpdated(newFeePercentage);
        }
    }

    function setDGT(address token) external {
        // >>> Adjustment for Issue #3 (zero address) <<<
        require(token != address(0), "DGT token cannot be zero address");

        if (msg.sender == governanceContract || msg.sender == owner()) {
            dgt_token = token;
            emit DGTUpdated(token);
        }
    }

    function approveToken(address token) external {
        // >>> Adjustment for Issue #3 (zero address) <<<
        require(token != address(0), "Token cannot be zero address");
        require(_isContract(token), "Not a contract address");
        if (msg.sender == governanceContract || msg.sender == owner()) {
            approvedTokens[token] = true;
            emit TokenApproved(token);
        }
    }

    function removeToken(address token) external {
        // >>> Adjustment for Issue #3 (zero address) <<<
        require(token != address(0), "Token cannot be zero address");

        if (msg.sender == governanceContract || msg.sender == owner()) {
            approvedTokens[token] = false;
            emit TokenRemoved(token);
        }
    }

    function electConciliator(address candidate) external {
        // >>> Adjustment for Issue #3 (zero address) <<<
        require(candidate != address(0), "Conciliator cannot be zero address");

        if (msg.sender == governanceContract || msg.sender == owner()) {
            electedConciliators[candidate] = true;
            conciliatorsList.push(candidate);
        }
    }

    function transferOwnership(address newOwner) public override {
        require(msg.sender == governanceContract, "Only governance contract can call this function");
        _transferOwnership(newOwner);
    }

    function changeStatus(uint256 escrowId, EscrowStatus newStatus) internal {
        escrows[escrowId].status = newStatus;
        escrows[escrowId].statusTime = block.timestamp;
        emit EscrowStatusChanged(escrowId, newStatus);
    }

    // --------------------------------------------------------
    // MAIN ADJUSTMENT TO BLOCK FOT: CHECK RECEIVED BALANCE
    // --------------------------------------------------------
    function createEscrow(
        address seller,
        uint256 amount,
        uint256 deliveryTime,
        string memory termsHash,
        address tokenAddress,
        bool isNativeToken
    ) 
        public 
        payable 
        nonReentrant 
        limitTransactions(msg.sender) 
    {
        // >>> Ajuste para Issue #3 e #4 <<<
        require(seller != address(0), "Seller cannot be zero address");
        require(seller != msg.sender, "Seller and buyer must be different addresses");
        require(amount > 0, "Amount must be greater than zero");

        if (isNativeToken) {
            // Escrow in native currency (ETH, BNB, MATIC, etc.)
            require(msg.value == amount, "Incorrect native token amount sent");
        } else {
            require(approvedTokens[tokenAddress], "Token is not approved");
            require(_isContract(tokenAddress), "tokenAddress must be a contract");

            // 1) Checa saldo antes
            uint256 balanceBefore = IERC20(tokenAddress).balanceOf(address(this));

            // 2) Tenta transferir
            require(
                IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount),
                "Token transfer failed"
            );

            // 3) Check balance afterward
            uint256 balanceAfter = IERC20(tokenAddress).balanceOf(address(this));

            // 4) If less than 'amount' is received, it is FOT => revert
            require(
                (balanceAfter - balanceBefore) == amount,
                "FOT tokens not allowed"
            );
        }

        // Adjusts deliveryTime if it is outside the allowed limits
        if (deliveryTime < MIN_DELIVERY_TIME || deliveryTime > MAX_DELIVERY_TIME) {
            deliveryTime = DEFAULT_DELIVERY_TIME;
        }

        uint256 escrowId = escrowCount++;
        escrows[escrowId] = Escrow({
            buyer: msg.sender,
            seller: seller,
            amount: amount,
            deliveryTime: deliveryTime,
            termsHash: termsHash,
            status: EscrowStatus.AWAITING_DELIVERY,
            statusTime: block.timestamp,
            resolutionType: DisputeResolution.NONE,
            conciliator: address(0),
            recusalCount: 0,
            finalized: false,
            conciliatorFee: 0,
            buyerRecusal: false,
            sellerRecusal: false,
            tokenAddress: tokenAddress,
            disputeInitiator: address(0),
            creationTime: block.timestamp,
            isNativeToken: isNativeToken
        });

        userEscrows[msg.sender].push(escrowId);
        userEscrows[seller].push(escrowId);

        emit EscrowCreated(escrowId, msg.sender, seller, amount, deliveryTime, termsHash, tokenAddress);
        changeStatus(escrowId, EscrowStatus.AWAITING_DELIVERY);
    }
    // --------------------------------------------------------

    function cancelEscrow(uint256 escrowId) public nonReentrant limitTransactions(msg.sender) {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.buyer, "Only buyer can cancel the escrow");
        require(escrow.status == EscrowStatus.AWAITING_DELIVERY, "Escrow is not awaiting delivery");

        // Allowed cancellation time: deliveryTime + 1 day
        uint256 allowableCancelTime = escrow.creationTime + escrow.deliveryTime + 1 days;
        require(block.timestamp >= allowableCancelTime, "Cannot cancel escrow before delivery time plus 1 day");

        uint256 fee = _calculateFee(escrow.amount);
        uint256 refundAmount = escrow.amount - fee;

        // Since we prohibit FOT, we assume that transfer() will send the exact refundAmount
        require(IERC20(escrow.tokenAddress).transfer(escrow.buyer, refundAmount), "Token transfer to buyer failed");

        _distributeFee(fee, escrow.tokenAddress);

        escrow.status = EscrowStatus.COMPLETE;
        escrow.finalized = true;
        emit EscrowCompleted(escrowId, escrow.buyer);
        changeStatus(escrowId, EscrowStatus.COMPLETE);
    }

    function notifyProductSent(uint256 escrowId) public nonReentrant limitTransactions(msg.sender) {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.seller, "Only seller can notify product sent");
        require(escrow.status == EscrowStatus.AWAITING_DELIVERY, "Invalid status to notify product sent");

        escrow.statusTime = block.timestamp;
        changeStatus(escrowId, EscrowStatus.DELIVERED);
        emit ProductSent(escrowId);
    }

    function confirmDelivery(uint256 escrowId) public nonReentrant limitTransactions(msg.sender) {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.buyer, "Only buyer can confirm delivery");
        require(escrow.status == EscrowStatus.DELIVERED, "Invalid status to confirm delivery");

        _transferToSeller(escrowId);

        // Mark as completed to avoid inconsistencies
        escrow.finalized = true;
        emit DeliveryConfirmed(escrowId);
        changeStatus(escrowId, EscrowStatus.COMPLETE);
    }

    function openDispute(uint256 escrowId) public nonReentrant limitTransactions(msg.sender) {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.buyer || msg.sender == escrow.seller, "Only buyer or seller can open dispute");
        require(escrow.status != EscrowStatus.COMPLETE, "Cannot open dispute on completed escrow");
        require(escrow.status != EscrowStatus.ASK_DISPUTE, "Cannot open dispute on an escrow already in dispute process");
        require(escrow.status != EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE, "Cannot open dispute on an escrow awaiting conciliator acceptance");
        require(escrow.status != EscrowStatus.IN_DISPUTE, "Cannot open dispute on an escrow already in dispute process");

        escrow.statusTime = block.timestamp;
        escrow.disputeInitiator = msg.sender;
        changeStatus(escrowId, EscrowStatus.ASK_DISPUTE);
        emit DisputeOpened(escrowId, msg.sender);
    }

    function respondToDispute(uint256 escrowId) public nonReentrant limitTransactions(msg.sender) {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.buyer || msg.sender == escrow.seller, "Only buyer or seller can respond to dispute");
        require(escrow.status == EscrowStatus.ASK_DISPUTE, "Invalid status to respond to dispute");
        require(msg.sender != escrow.disputeInitiator, "Dispute initiator cannot respond to dispute");

        changeStatus(escrowId, EscrowStatus.IN_DISPUTE);
        _assignConciliator(escrowId);
    }

    function _assignConciliator(uint256 escrowId) internal {
        Escrow storage escrow = escrows[escrowId];
        address conciliator = _selectRandomConciliator();
        escrow.conciliator = conciliator;
        changeStatus(escrowId, EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE);
        userEscrows[conciliator].push(escrowId);
        emit ConciliatorAssigned(escrowId, conciliator);
    }

    function _removeEscrowFromUser(address user, uint256 escrowId) internal {
        uint256 length = userEscrows[user].length;
        for (uint256 i = 0; i < length; i++) {
            if (userEscrows[user][i] == escrowId) {
                userEscrows[user][i] = userEscrows[user][length - 1];
                userEscrows[user].pop();
                break;
            }
        }
    }

    function assignConciliator(uint256 escrowId) external {
        if (msg.sender == governanceContract || msg.sender == owner()) {
            Escrow storage escrow = escrows[escrowId];
            address conciliator = _selectRandomConciliator();
            escrow.conciliator = conciliator;
            changeStatus(escrowId, EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE);
            userEscrows[conciliator].push(escrowId);
            emit ConciliatorAssigned(escrowId, conciliator);
        }
    }

    function _selectRandomConciliator() internal view returns (address) {
        require(conciliatorsList.length > 0, "No conciliators available");
        uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % conciliatorsList.length;
        return conciliatorsList[randomIndex];
    }

    function acceptCase(uint256 escrowId, uint8 fee) public nonReentrant limitTransactions(msg.sender) {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.conciliator, "Only assigned conciliator can accept the case");
        require(fee <= MAX_COMMISSION, "Fee exceeds maximum allowed");

        escrow.conciliatorFee = fee;
        changeStatus(escrowId, EscrowStatus.IN_DISPUTE);
        emit ConciliatorAccepted(escrowId, msg.sender, fee);
    }

    function recuseCase(uint256 escrowId) public nonReentrant limitTransactions(msg.sender) {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.conciliator, "Only assigned conciliator can recuse the case");
        _removeEscrowFromUser(msg.sender, escrowId);
        _assignConciliator(escrowId);
    }

    function recuseConciliator(uint256 escrowId) public nonReentrant limitTransactions(msg.sender) {
        Escrow storage escrow = escrows[escrowId];
        require(
            escrow.status == EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE || 
            escrow.status == EscrowStatus.IN_DISPUTE,
            "Escrow is not in the correct status"
        );
        require(msg.sender == escrow.buyer || msg.sender == escrow.seller, "Only involved parties can recuse conciliator");

        if (escrow.status == EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE) {
            // Permitir recusa unilateral durante AWAITING_CONCILIATOR_ACCEPTANCE
            _removeEscrowFromUser(escrow.conciliator, escrowId);
            if (escrow.recusalCount < MAX_RECUSES) {
                escrow.conciliator = address(0);
                escrow.conciliatorFee = 0;
                escrow.recusalCount++;
                escrow.buyerRecusal = false;
                escrow.sellerRecusal = false;
                _assignConciliator(escrowId);
                emit ConciliatorRecused(escrowId, msg.sender);
                changeStatus(escrowId, EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE);
            } else {
                // Após o número máximo de recusas, o owner se torna o conciliador
                escrow.conciliator = owner();
                escrow.conciliatorFee = 8;
                escrow.buyerRecusal = false;
                escrow.sellerRecusal = false;
                changeStatus(escrowId, EscrowStatus.IN_DISPUTE);
                emit ConciliatorAssigned(escrowId, owner());
            }
        } else if (escrow.status == EscrowStatus.IN_DISPUTE) {
            // Requer acordo de ambas as partes para recusa durante IN_DISPUTE
            if (msg.sender == escrow.buyer) {
                escrow.buyerRecusal = true;
            } else if (msg.sender == escrow.seller) {
                escrow.sellerRecusal = true;
            }

            if (escrow.buyerRecusal && escrow.sellerRecusal) {
                _removeEscrowFromUser(escrow.conciliator, escrowId);
                if (escrow.recusalCount < MAX_RECUSES) {
                    escrow.conciliator = address(0);
                    escrow.conciliatorFee = 0;
                    escrow.recusalCount++;
                    escrow.buyerRecusal = false;
                    escrow.sellerRecusal = false;
                    _assignConciliator(escrowId);
                    emit ConciliatorRecused(escrowId, msg.sender);
                    changeStatus(escrowId, EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE);
                } else {
                    escrow.conciliator = owner();
                    escrow.conciliatorFee = 8;
                    escrow.buyerRecusal = false;
                    escrow.sellerRecusal = false;
                    changeStatus(escrowId, EscrowStatus.IN_DISPUTE);
                    emit ConciliatorAssigned(escrowId, owner());
                }
            }
        }
    }

    function assignConciliatorManually(uint256 escrowId, address newConciliator, uint8 conciliatorFee) external {
        require(msg.sender == owner() || msg.sender == governanceContract, "Only owner or governance contract can assign conciliator");
        require(newConciliator != address(0), "Invalid conciliator address");
        require(conciliatorFee <= MAX_COMMISSION, "Fee exceeds maximum allowed");

        Escrow storage escrow = escrows[escrowId];
        require(
            escrow.status == EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE || 
            escrow.status == EscrowStatus.IN_DISPUTE,
            "Escrow is not in the correct status"
        );
        
        // Update o conciliator e a taxa
        escrow.conciliator = newConciliator;
        escrow.conciliatorFee = conciliatorFee;

        // Reset recusal counts
        escrow.recusalCount = 0;
        escrow.buyerRecusal = false;
        escrow.sellerRecusal = false;

        emit ConciliatorAssigned(escrowId, newConciliator);
        changeStatus(escrowId, EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE);
    }

    function conciliatorResolution(uint256 escrowId, uint8 buyerPercentage, uint8 sellerPercentage) 
        public 
        nonReentrant 
        limitTransactions(msg.sender) 
    {
        require(buyerPercentage + sellerPercentage == 100, "Buyer and seller percentages must sum to 100");

        Escrow storage escrow = escrows[escrowId];
        require(block.timestamp >= escrow.statusTime + 2 days, "Please wait 48 hours before closing a dispute.");
        require(msg.sender == escrow.conciliator, "Only assigned conciliator can resolve");
        require(escrow.status == EscrowStatus.IN_DISPUTE, "No dispute to resolve");

        uint256 fee = _calculateFee(escrow.amount);
        uint256 conciliatorFee = (escrow.amount * escrow.conciliatorFee) / 100;
        uint256 totalAmount = escrow.amount - fee - conciliatorFee;

        uint256 paymentToBuyer = (totalAmount * buyerPercentage) / 100;
        uint256 paymentToSeller = (totalAmount * sellerPercentage) / 100;

       // Handling "leftovers" due to rounding (optional):
        uint256 totalDistributed = paymentToBuyer + paymentToSeller;
        uint256 remainder = totalAmount - totalDistributed;
        if (remainder > 0) {
            // By design, we can send the leftover to the buyer:
            paymentToBuyer += remainder;
        }

        if (escrow.isNativeToken) {
            // Native token
            payable(escrow.buyer).transfer(paymentToBuyer);
            payable(escrow.seller).transfer(paymentToSeller);
            payable(escrow.conciliator).transfer(conciliatorFee);

            // Fee of native
            if (fee > 0) {
                payable(feeWallet).transfer(fee);
            }
        } else {
            // ERC-20 Token (without FOT, as it is blocked in createEscrow)
            require(IERC20(escrow.tokenAddress).transfer(escrow.buyer, paymentToBuyer), "Token transfer to buyer failed");
            require(IERC20(escrow.tokenAddress).transfer(escrow.seller, paymentToSeller), "Token transfer to seller failed");
            require(IERC20(escrow.tokenAddress).transfer(escrow.conciliator, conciliatorFee), "Token transfer to conciliator failed");

            // Distribuir fee
            _distributeFee(fee, escrow.tokenAddress);
        }

        // Completar a resolução
        escrow.status = EscrowStatus.COMPLETE;
        escrow.finalized = true;
        emit PartialPayment(escrowId, paymentToBuyer, paymentToSeller);
        emit EscrowCompleted(escrowId, escrow.conciliator);
        changeStatus(escrowId, EscrowStatus.COMPLETE);
    }

    function claimFunds(uint256 escrowId) public nonReentrant limitTransactions(msg.sender) {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.buyer || msg.sender == escrow.seller, "Only buyer or seller can claim funds");

        if (escrow.status == EscrowStatus.DELIVERED && msg.sender == escrow.seller) {
            require(block.timestamp >= escrow.statusTime + 7 days, "7 days claim period has not passed");
            _transferToSeller(escrowId);
        } else if (escrow.status == EscrowStatus.ASK_DISPUTE && msg.sender == escrow.disputeInitiator) {
            require(block.timestamp >= escrow.statusTime + 7 days, "7 days claim period has not passed");
            _refundBuyer(escrowId);
        }
        escrow.finalized = true;
    }

    function _refundBuyer(uint256 escrowId) internal {
        Escrow storage escrow = escrows[escrowId];
        uint256 fee = _calculateFee(escrow.amount);
        uint256 refundAmount = escrow.amount - fee;

        if (escrow.isNativeToken) {
            payable(escrow.buyer).transfer(refundAmount);
        } else {
            require(
                IERC20(escrow.tokenAddress).transfer(escrow.buyer, refundAmount),
                "Token transfer to buyer failed"
            );
        }

        _distributeFee(fee, escrow.tokenAddress);
        escrow.status = EscrowStatus.COMPLETE;
        escrow.finalized = true;

        emit EscrowCompleted(escrowId, escrow.buyer);
        changeStatus(escrowId, EscrowStatus.COMPLETE);
    }

    function _transferToSeller(uint256 escrowId) internal {
        Escrow storage escrow = escrows[escrowId];
        uint256 fee = _calculateFee(escrow.amount);
        uint256 paymentToSeller = escrow.amount - fee;

        if (escrow.isNativeToken) {
            payable(escrow.seller).transfer(paymentToSeller);
        } else {
            require(
                IERC20(escrow.tokenAddress).transfer(escrow.seller, paymentToSeller),
                "Token transfer to seller failed"
            );
        }

        _distributeFee(fee, escrow.tokenAddress);
        escrow.status = EscrowStatus.COMPLETE;
        escrow.finalized = true;

        emit EscrowCompleted(escrowId, escrow.seller);
        changeStatus(escrowId, EscrowStatus.COMPLETE);
    }

    // Ajuste na função _calculateFee se quiser isentar DGT
    function _calculateFee(uint256 amount) internal view returns (uint256) {
        // Se o token for DGT, retorna zero fee.
        if (escrows[escrowCount - 1].tokenAddress == dgt_token) {
            return 0;
        }
        // Caso contrário, aplica a % (aqui é 0.7% = 7/1000)
        return (amount * feePercentage) / 1000;
    }

    function _distributeFee(uint256 fee, address tokenAddress) internal {
        if (tokenAddress == address(0)) {
            // Moeda nativa (ETH, MATIC, BNB etc.)
            if (fee > 0) {
                payable(feeWallet).transfer(fee);
            }
        } else {
            // Token ERC-20 (sem FOT)
            if (fee > 0) {
                require(
                    IERC20(tokenAddress).transfer(feeWallet, fee),
                    "Token transfer to fee wallet failed"
                );
            }
        }
    }

    function listOrders(address user)
        public
        view
        returns (
            uint256[] memory,
            address[] memory,
            uint256[] memory,
            address[] memory,
            EscrowStatus[] memory,
            uint256[] memory,
            address[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        uint256[] memory userEscrowsArray = userEscrows[user];
        uint256 count = 0;

        for (uint256 i = 0; i < userEscrowsArray.length; i++) {
            if (escrows[userEscrowsArray[i]].buyer == user) {
                count++;
            }
        }

        uint256[] memory escrowIds = new uint256[](count);
        address[] memory sellers = new address[](count);
        uint256[] memory amounts = new uint256[](count);
        address[] memory tokens = new address[](count);
        EscrowStatus[] memory statuses = new EscrowStatus[](count);
        uint256[] memory statusTimes = new uint256[](count);
        address[] memory disputeInitiators = new address[](count);
        uint256[] memory conciliatorFees = new uint256[](count);
        uint256[] memory creationTimes = new uint256[](count);

        uint256 index = 0;
        for (uint256 i = 0; i < userEscrowsArray.length; i++) {
            uint256 escrowId = userEscrowsArray[i];
            Escrow storage escrow = escrows[escrowId];
            if (escrow.buyer == user) {
                escrowIds[index] = escrowId;
                sellers[index] = escrow.seller;
                amounts[index] = escrow.amount;
                tokens[index] = escrow.tokenAddress;
                statuses[index] = escrow.status;
                statusTimes[index] = escrow.statusTime;
                disputeInitiators[index] = escrow.disputeInitiator;
                conciliatorFees[index] = escrow.conciliatorFee;
                creationTimes[index] = escrow.creationTime;
                index++;
            }
        }

        return (
            escrowIds,
            sellers,
            amounts,
            tokens,
            statuses,
            statusTimes,
            disputeInitiators,
            conciliatorFees,
            creationTimes
        );
    }

    function listSales(address user)
        public
        view
        returns (
            uint256[] memory,
            address[] memory,
            uint256[] memory,
            address[] memory,
            EscrowStatus[] memory,
            uint256[] memory,
            address[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        uint256[] memory userEscrowsArray = userEscrows[user];
        uint256 count = 0;

        for (uint256 i = 0; i < userEscrowsArray.length; i++) {
            if (escrows[userEscrowsArray[i]].seller == user) {
                count++;
            }
        }

        uint256[] memory escrowIds = new uint256[](count);
        address[] memory buyers = new address[](count);
        uint256[] memory amounts = new uint256[](count);
        address[] memory tokens = new address[](count);
        EscrowStatus[] memory statuses = new EscrowStatus[](count);
        uint256[] memory statusTimes = new uint256[](count);
        address[] memory disputeInitiators = new address[](count);
        uint256[] memory conciliatorFees = new uint256[](count);
        uint256[] memory creationTimes = new uint256[](count);

        uint256 index = 0;
        for (uint256 i = 0; i < userEscrowsArray.length; i++) {
            uint256 escrowId = userEscrowsArray[i];
            if (escrows[escrowId].seller == user) {
                escrowIds[index] = escrowId;
                buyers[index] = escrows[escrowId].buyer;
                amounts[index] = escrows[escrowId].amount;
                tokens[index] = escrows[escrowId].tokenAddress;
                statuses[index] = escrows[escrowId].status;
                statusTimes[index] = escrows[escrowId].statusTime;
                disputeInitiators[index] = escrows[escrowId].disputeInitiator;
                conciliatorFees[index] = escrows[escrowId].conciliatorFee;
                creationTimes[index] = escrows[escrowId].creationTime;
                index++;
            }
        }

        return (
            escrowIds,
            buyers,
            amounts,
            tokens,
            statuses,
            statusTimes,
            disputeInitiators,
            conciliatorFees,
            creationTimes
        );
    }

    function listEscrowsForConciliator(address conciliator)
        public
        view
        returns (
            uint256[] memory,
            address[] memory,
            address[] memory,
            uint256[] memory,
            address[] memory,
            EscrowStatus[] memory,
            uint256[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        uint256[] memory userEscrowsArray = userEscrows[conciliator];
        uint256 count = 0;

        for (uint256 i = 0; i < userEscrowsArray.length; i++) {
            uint256 escrowId = userEscrowsArray[i];
            if (
                escrows[escrowId].conciliator == conciliator &&
                (
                    escrows[escrowId].status == EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE ||
                    escrows[escrowId].status == EscrowStatus.IN_DISPUTE
                )
            ) {
                count++;
            }
        }

        uint256[] memory escrowIds = new uint256[](count);
        address[] memory buyers = new address[](count);
        address[] memory sellers = new address[](count);
        uint256[] memory amounts = new uint256[](count);
        address[] memory tokens = new address[](count);
        EscrowStatus[] memory statuses = new EscrowStatus[](count);
        uint256[] memory statusTimes = new uint256[](count);
        uint256[] memory conciliatorFees = new uint256[](count);
        uint256[] memory creationTimes = new uint256[](count);

        uint256 index = 0;
        for (uint256 i = 0; i < userEscrowsArray.length; i++) {
            uint256 escrowId = userEscrowsArray[i];
            if (
                escrows[escrowId].conciliator == conciliator &&
                (
                    escrows[escrowId].status == EscrowStatus.AWAITING_CONCILIATOR_ACCEPTANCE ||
                    escrows[escrowId].status == EscrowStatus.IN_DISPUTE
                )
            ) {
                escrowIds[index] = escrowId;
                buyers[index] = escrows[escrowId].buyer;
                sellers[index] = escrows[escrowId].seller;
                amounts[index] = escrows[escrowId].amount;
                tokens[index] = escrows[escrowId].tokenAddress;
                statuses[index] = escrows[escrowId].status;
                statusTimes[index] = escrows[escrowId].statusTime;
                conciliatorFees[index] = escrows[escrowId].conciliatorFee;
                creationTimes[index] = escrows[escrowId].creationTime;
                index++;
            }
        }

        return (
            escrowIds,
            buyers,
            sellers,
            amounts,
            tokens,
            statuses,
            statusTimes,
            conciliatorFees,
            creationTimes
        );
    }

    function countEscrows(address user) external view returns (uint256 buyerCount, uint256 sellerCount) {
        for (uint256 i = 0; i < escrowCount; i++) {
            if (escrows[i].buyer == user) {
                buyerCount++;
            }
            if (escrows[i].seller == user) {
                sellerCount++;
            }
        }
    }
}
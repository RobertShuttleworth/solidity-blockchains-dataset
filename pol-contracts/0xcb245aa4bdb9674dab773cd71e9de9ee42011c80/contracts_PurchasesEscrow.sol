// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

import "./openzeppelin_contracts_utils_Address.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";

import "./contracts_WINToken.sol";

import "./hardhat_console.sol";

contract PurchasesEscrow is AccessControl {
    using Address for address payable;

    enum PurchaseState {
        Purchased,
        Delivered,
        Canceled
    }

    bytes32 public constant ESCROW_ADMIN = keccak256("ESCROW_ADMIN");

    address public beneficiary;
    WINToken public winToken;
    bool public complianceAccepted;

    mapping(uint256 => bool) public productSoftCapReached;
    mapping(uint256 => PurchaseState) public purchaseState;
    mapping(uint256 => uint256) public productSoftCapSupply;
    mapping(uint256 => mapping(address => uint256)) public productPrice;

    event Deposited(
        uint256 indexed productId,
        address indexed payee,
        uint256 weiAmount
    );
    event Withdrawn(
        uint256 indexed productId,
        address indexed payee,
        uint256 weiAmount
    );
    event Delivered(uint256 indexed productId);
    event Canceled(uint256 indexed productId);

    // _deposits:
    // erc20Token => wallet => productId => paymentAmount
    // erc20Token === AddressZero === Native token (Eg. Eth, Matic)
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        private _deposits;

    // payments:
    // erc20Token => productId => paymentAmount
    // erc20Token === AddressZero === Native token (Eg. Eth, Matic)
    mapping(address => mapping(uint256 => uint256)) public payments;

    modifier onlyEscrowAdmin() {
        require(
            hasRole(ESCROW_ADMIN, msg.sender),
            "Restricted to ESCROW_ADMIN role"
        );
        _;
    }

    /**
     * @dev Constructor.
     * @param _beneficiary The beneficiary of the deposits.
     */
    constructor(address _beneficiary) {
        require(_beneficiary != address(0), "Missing beneficiary");
        beneficiary = _beneficiary;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function editBeneficiary(address _beneficiary) public onlyEscrowAdmin {
        require(_beneficiary != address(0), "Missing beneficiary");

        beneficiary = _beneficiary;
    }

    /**
     * @dev You need to call this method after the deployment of both contracts (WINToken and this one)
     *
     * We need the WINToken here in order to be able to pay the royalties after the sell
     *
     * @param _winToken WINToken address associated to this escrow
     */
    function editWinToken(WINToken _winToken) public onlyEscrowAdmin {
        winToken = _winToken;
    }

    function editCompliance(bool value) public onlyEscrowAdmin {
        complianceAccepted = value;
    }

    function editSoftCapSupply(
        uint256 productId,
        uint256 softCapSupply
    ) public onlyEscrowAdmin {
        productSoftCapSupply[productId] = softCapSupply;
    }

    function editPrice(
        uint256 productId,
        address erc20Token,
        uint256 price
    ) public onlyEscrowAdmin {
        productPrice[productId][erc20Token] = price;
    }

    /**
     * @dev Stores the sent paymentd as credit to be withdrawn.
     * @param payee The destination address of the funds.
     */
    function deposit(
        address erc20Token,
        uint256 erc20Value,
        address payee,
        uint256 productId,
        uint256 amount,
        uint256 currentSupplyIncludingAmount
    ) public payable onlyEscrowAdmin {
        require(
            purchaseState[productId] == PurchaseState.Purchased,
            "Deposits closed"
        );
        require(
            productPrice[productId][erc20Token] > 0,
            "Missing product price"
        );

        uint256 paymentAmount = erc20Token == address(0)
            ? msg.value
            : erc20Value;

        require(
            paymentAmount == productPrice[productId][erc20Token] * amount,
            "Incorrect price"
        );

        payments[erc20Token][productId] += paymentAmount;

        _deposits[erc20Token][payee][productId] += paymentAmount;

        if (currentSupplyIncludingAmount >= productSoftCapSupply[productId]) {
            productSoftCapReached[productId] = true;
        }

        emit Deposited(productId, payee, paymentAmount);
    }

    /**
     * @dev Allows for the beneficiary to withdraw their funds, rejecting
     * further deposits.
     */
    function delivered(uint256 productId) public onlyEscrowAdmin {
        require(
            purchaseState[productId] == PurchaseState.Purchased,
            "Invalid state"
        );
        purchaseState[productId] = PurchaseState.Delivered;

        emit Delivered(productId);
    }

    /**
     * @dev Allows for refunds to take place, rejecting further deposits.
     */
    function cancel(uint256 productId) public onlyEscrowAdmin {
        require(
            purchaseState[productId] == PurchaseState.Purchased,
            "Invalid state"
        );
        purchaseState[productId] = PurchaseState.Canceled;

        emit Canceled(productId);
    }

    function depositsOf(
        address erc20Token,
        address payee,
        uint256 productId
    ) public view returns (uint256) {
        return _deposits[erc20Token][payee][productId];
    }

    /**
     * @dev Withdraw accumulated balance for a payee, forwarding all gas to the
     * recipient.
     *
     * WARNING: Forwarding all gas opens the door to reentrancy vulnerabilities.
     * Make sure you trust the recipient, or are either following the
     * checks-effects-interactions pattern or using {ReentrancyGuard}.
     *
     * @param erc20Token Put AddressZero to use Native token otherwise specify the ERC20 address.
     * @param payee The address whose funds will be withdrawn and transferred to.
     *
     * Emits a {Withdrawn} event.
     */
    function withdraw(
        address erc20Token,
        uint256 productId,
        address payable payee
    ) public virtual {
        require(
            purchaseState[productId] == PurchaseState.Canceled,
            "Not allowed"
        );

        uint256 payment = _deposits[erc20Token][payee][productId];

        _deposits[erc20Token][payee][productId] = 0;

        if (erc20Token == address(0)) {
            payee.sendValue(payment);
        } else {
            ERC20(erc20Token).transfer(payee, payment);
        }

        emit Withdrawn(productId, payee, payment);
    }

    /**
     * @dev Withdraws the beneficiary's funds.
     */
    function beneficiaryWithdraw(address erc20Token, uint256 productId) public {
        require(address(0) != address(winToken), "Missing WINToken address");
        require(complianceAccepted, "Compliance required");
        require(productSoftCapReached[productId], "Soft cap not reached");
        require(
            purchaseState[productId] == PurchaseState.Delivered,
            "Not delivered"
        );

        uint256 payment = payments[erc20Token][productId];

        uint256 royaltyPayment = _payRoyalties(erc20Token, productId, payment);

        payments[erc20Token][productId] = 0;

        address payable _beneficiary = payable(beneficiary);

        uint256 beneficiaryPayment = payment - royaltyPayment;

        if (erc20Token == address(0)) {
            _beneficiary.sendValue(beneficiaryPayment);
        } else {
            ERC20(erc20Token).transfer(_beneficiary, beneficiaryPayment);
        }
    }

    function _payRoyalties(
        address erc20Token,
        uint256 productId,
        uint256 payment
    ) private returns (uint256) {
        if (ERC165(winToken).supportsInterface(type(IERC2981).interfaceId)) {
            (address receiver, uint256 royaltyAmount) = IERC2981(winToken)
                .royaltyInfo(productId, payment);

            if (address(0) == erc20Token) {
                address payable _receiver = payable(receiver);

                _receiver.sendValue(royaltyAmount);
            } else {
                bool result = ERC20(erc20Token).transfer(
                    receiver,
                    royaltyAmount
                );

                require(result, "failed to pay royalties");
            }

            return royaltyAmount;
        }

        return 0;
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

import "./openzeppelin_contracts_utils_Address.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";
import "./contracts_WINToken.sol";

contract RoyaltiesEscrow is AccessControl {
    using Address for address payable;

    bytes32 public constant ESCROW_ADMIN = keccak256("ESCROW_ADMIN");
    uint96 public constant FEE_DENOMINATOR = 10000;

    event Deposited(address indexed payee, uint256 weiAmount);
    event Withdrawn(address indexed payee, uint256 weiAmount);

    // _deposits:
    // token => wallet => amount
    // token === AddressZero === Native token (Eg. Eth, Matic)
    mapping(address => mapping(address => uint256)) private _deposits;

    WINToken private winToken;
    uint256 private tokenId;

    event Received(address, uint);

    modifier onlyEscrowAdmin() {
        require(
            hasRole(ESCROW_ADMIN, msg.sender),
            "Restricted to ESCROW_ADMIN role"
        );
        _;
    }

    constructor(WINToken _winToken, uint256 _tokenId) {
        winToken = _winToken;
        tokenId = _tokenId;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    receive() external payable {
        // enables royalties payment
        emit Received(msg.sender, msg.value);
    }

    function depositsOf(
        address token,
        address payee
    ) public view returns (uint256) {
        return _deposits[token][payee];
    }

    /**
     * @dev Stores the sent amount as credit to be withdrawn.
     * @param token Put AddressZero to use Native token otherwise specify the ERC20 address.
     * Emits a {Deposited} event.
     */
    function distributeFees(address token) public virtual onlyEscrowAdmin {
        uint96 totalRoyalties = winToken.totalRoyaltiesByToken(tokenId);

        WINToken.RoyaltyBeneficiary[] memory beneficiaries = winToken
            .getRoyalties(tokenId);

        uint256 balance = address(this).balance;
        if (token != address(0)) {
            balance = ERC20(token).balanceOf(address(this));
        }

        for (uint i = 0; i < beneficiaries.length; i++) {
            uint96 royaltyPercentage = (beneficiaries[i].percentage *
                FEE_DENOMINATOR) / totalRoyalties;

            uint256 amount = (balance * royaltyPercentage) / FEE_DENOMINATOR;

            _deposits[token][beneficiaries[i].account] += amount;
            emit Deposited(beneficiaries[i].account, amount);
        }
    }

    /**
     * @dev Withdraw accumulated balance for a payee, forwarding all gas to the
     * recipient.
     *
     * WARNING: Forwarding all gas opens the door to reentrancy vulnerabilities.
     * Make sure you trust the recipient, or are either following the
     * checks-effects-interactions pattern or using {ReentrancyGuard}.
     *
     * @param token Put AddressZero to use Native token otherwise specify the ERC20 address.
     * @param payee The address whose funds will be withdrawn and transferred to.
     *
     * Emits a {Withdrawn} event.
     */
    function withdraw(address token, address payable payee) public virtual {
        uint256 payment = _deposits[token][payee];

        _deposits[token][payee] = 0;

        if (token == address(0)) {
            payee.sendValue(payment);
        } else {
            ERC20(token).transfer(payee, payment);
        }

        emit Withdrawn(payee, payment);
    }
}
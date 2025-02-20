// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_extensions_AccessControlDefaultAdminRules.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import "./openzeppelin_contracts_utils_cryptography_EIP712.sol";

contract MultiVesting is EIP712, AccessControlDefaultAdminRules, Pausable {
    event Claimed(address indexed to, uint256 amount, uint256 fee);

    bytes32 public constant CLAIM_TYPEHASH =
        keccak256("VestingClaim(address to,uint256 amount)");

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant FEE_WITHDRAW_ROLE = keccak256("FEE_WITHDRAW_ROLE");

    uint256 public immutable VESTING_DURATION;
    uint256 public immutable VESTING_CLIFF;
    uint256 public immutable VESTING_START;
    uint256 public immutable VESTING_TGE_UNLOCK_BPS;

    bool public immutable CLAIM_FEE_ALLOWED;

    IERC20 public immutable TOKEN;

    mapping(address => uint256) public claimedAmounts;
    mapping(address => uint256) public claimedFeeAmounts;
    uint256 public claimedTotal;
    uint256 public claimedFeeTotal;

    modifier onlyAfterVestingStart() {
        require(block.timestamp >= VESTING_START, "Vesting has not started");
        _;
    }

    constructor(
        uint256 duration,
        uint256 cliff,
        uint256 start,
        uint256 unlockBps,
        address token,
        bool claimFeeAllowed
    )
        EIP712("RoboHero Vesting", "1")
        AccessControlDefaultAdminRules(3 days, msg.sender)
        Pausable()
    {
        VESTING_DURATION = duration;
        VESTING_CLIFF = cliff;
        VESTING_START = start;
        VESTING_TGE_UNLOCK_BPS = unlockBps;

        TOKEN = IERC20(token);

        CLAIM_FEE_ALLOWED = claimFeeAllowed;

        _grantRole(SIGNER_ROLE, 0x3EBB4032b715BC4279b2172f6B8220CD76c1d28a);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(FEE_WITHDRAW_ROLE, msg.sender);
    }

    function claimTokens(
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external onlyAfterVestingStart whenNotPaused {
        _verifySignature(msg.sender, amount, v, r, s);

        uint256 presentAmount = getPresentAmount(amount);
        require(presentAmount > 0, "No present tokens to claim");

        uint256 claimableAmount = presentAmount - claimedAmounts[msg.sender];
        require(claimableAmount > 0, "No tokens to claim");

        uint256 fee = getPresentFee(claimableAmount);

        claimedAmounts[msg.sender] += claimableAmount;
        claimedTotal += claimableAmount;
        claimedFeeAmounts[msg.sender] += fee;
        claimedFeeTotal += fee;

        TOKEN.transfer(msg.sender, claimableAmount - fee);

        emit Claimed(msg.sender, claimableAmount, fee);
    }

    function getPresentAmount(uint256 amount) public view returns (uint256) {
        uint256 unlockedAtTge = (amount * VESTING_TGE_UNLOCK_BPS) / 10000;

        if (block.timestamp < (VESTING_START + VESTING_CLIFF)) {
            return unlockedAtTge;
        } else if (
            block.timestamp >=
            (VESTING_START + VESTING_CLIFF + VESTING_DURATION)
        ) {
            return amount;
        } else {
            uint256 elapsed = block.timestamp - (VESTING_START + VESTING_CLIFF);
            uint256 remainingAmount = amount - unlockedAtTge;
            return
                unlockedAtTge + (remainingAmount * elapsed) / VESTING_DURATION;
        }
    }

    function getPresentFee(uint256 amount) public view returns (uint256) {
        if (!CLAIM_FEE_ALLOWED) {
            return 0;
        }

        uint256 feeEndTimestamp = VESTING_START + 50 days;

        if (block.timestamp >= feeEndTimestamp) {
            return 0;
        } else {
            // Fee is 50%, linearly decreasing to 0% over 50 days
            return
                (amount * (feeEndTimestamp - block.timestamp)) / (50 days) / 2;
        }
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function withdrawFee(
        address to,
        uint256 amount
    ) external onlyRole(FEE_WITHDRAW_ROLE) whenNotPaused {
        require(amount <= claimedFeeTotal, "Insufficient fee balance");

        claimedFeeTotal -= amount;
        TOKEN.transfer(to, amount);
    }

    function _verifySignature(
        address to,
        uint256 amount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) private view {
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(CLAIM_TYPEHASH, to, amount))
        );
        address signer = ECDSA.recover(digest, v, r, s);
        require(hasRole(SIGNER_ROLE, signer), "Invalid signature");
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }
}
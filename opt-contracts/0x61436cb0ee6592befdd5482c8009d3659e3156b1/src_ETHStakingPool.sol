// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { EIP712Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_cryptography_EIP712Upgradeable.sol";
import { ECDSA } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_cryptography_ECDSA.sol";
import { UUPSUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import { BitMaps } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_structs_BitMaps.sol";

contract ETHStakingPool is Initializable, EIP712Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using BitMaps for BitMaps.BitMap;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // keccak256("Claim(bytes32 claimId,address userAddr,uint256 nonce,uint256 amount,uint256 deadline)")
    bytes32 internal constant CLAIM_HASH = 0xc1c961ac26866f931e6133a4c65f35e8fb218859d77078e781aa3ee26d5adc9d;

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct Claim {
        bytes32 claimId;
        address userAddr;
        uint256 nonce;
        uint256 amount;
        uint256 deadline;
    }

    BitMaps.BitMap internal claimed;
    mapping(address => uint256) internal nonces;
    uint8 public threshold;

    uint256 public feeAmount;

    event ThresholdSet(uint8 indexed _threshold);
    event FeeAmountSet(uint256 indexed _feeAmount);
    event ETHClaimed(bytes32 _claimId, address _userAddr, uint256 _nonce, uint256 _amount);
    event ETHWithdrawn(address indexed _beneficiary, uint256 indexed _amount);

    error DeadlineExceeded();
    error InvalidZeroInput();
    error NotEnoughSignatures();
    error InvalidSignature();
    error NotAuthorized();
    error InvalidNonce();
    error AlreadyClaimed();
    error InvalidBeneficiary();
    error NothingToWithdraw();
    error TransferETHFailed();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _defaultAdmin,
        address _operator,
        address[] calldata _signers,
        address _upgrader,
        uint8 _threshold,
        uint256 _feeAmount
    )
        public
        initializer
    {
        __EIP712_init("ETHStakingPool", "1");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(OPERATOR_ROLE, _operator);

        uint256 signersLength = _signers.length;
        for (uint256 i; i < signersLength;) {
            _grantRole(SIGNER_ROLE, _signers[i]);
            unchecked {
                ++i;
            }
        }

        _grantRole(UPGRADER_ROLE, _upgrader);

        threshold = _threshold;
        feeAmount = _feeAmount;
    }

    receive() external payable { }

    function isClaimed(bytes32 _claimId) public view returns (bool) {
        return claimed.get(uint256(_claimId));
    }

    function getCurrentNonce(address _userAddr) public view returns (uint256) {
        return nonces[_userAddr] + 1; // Reserve nonce 0 and label it as 'error'
    }

    function setThreshold(uint8 _threshold) public onlyRole(OPERATOR_ROLE) {
        if (_threshold == 0) revert InvalidZeroInput();
        threshold = _threshold;

        emit ThresholdSet(_threshold);
    }

    function setFeeAmount(uint256 _feeAmount) public onlyRole(OPERATOR_ROLE) {
        feeAmount = _feeAmount;

        emit FeeAmountSet(_feeAmount);
    }

    function claim(Claim calldata _claim, Signature[] calldata _signatures) public {
        _setClaimed(_claim.claimId);
        _setNonce(_claim.userAddr, _claim.nonce);

        _validateDeadline(_claim.deadline);
        _verifySignatures(_getHash(_claim), _signatures);

        (bool sent,) = _claim.userAddr.call{ value: _claim.amount - feeAmount }("");
        if (!sent) revert TransferETHFailed();

        emit ETHClaimed(_claim.claimId, _claim.userAddr, _claim.nonce, _claim.amount);
    }

    function withdrawETH(address _beneficiary) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_beneficiary == address(0)) revert InvalidBeneficiary();

        uint256 amount = address(this).balance;

        if (amount == 0) revert NothingToWithdraw();

        (bool sent,) = _beneficiary.call{ value: amount }("");
        if (!sent) revert TransferETHFailed();

        emit ETHWithdrawn(_beneficiary, amount);
    }

    function _setClaimed(bytes32 _claimId) internal {
        if (isClaimed(_claimId)) revert AlreadyClaimed();

        claimed.set(uint256(_claimId));
    }

    function _setNonce(address _userAddr, uint256 _nonce) internal {
        if (_nonce != ++nonces[_userAddr]) revert InvalidNonce();
    }

    function _getHash(Claim memory _reward) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(CLAIM_HASH, _reward.claimId, _reward.userAddr, _reward.nonce, _reward.amount, _reward.deadline)
        );
    }

    function _validateDeadline(uint256 _deadline) internal view {
        if (_deadline < block.timestamp) {
            revert DeadlineExceeded();
        }
    }

    function _verifySignatures(bytes32 _hash, Signature[] calldata _signatures) internal view {
        uint256 length = _signatures.length;

        if (threshold == 0) revert InvalidZeroInput();
        if (length < threshold) revert NotEnoughSignatures();

        address recoveredAddress;
        address lastAddress;
        bytes32 digest = _hashTypedDataV4(_hash);

        for (uint256 i; i < length;) {
            (recoveredAddress,,) = ECDSA.tryRecover(digest, _signatures[i].v, _signatures[i].r, _signatures[i].s);

            if (recoveredAddress != address(0) && recoveredAddress <= lastAddress) revert InvalidSignature();

            if (!hasRole(SIGNER_ROLE, recoveredAddress)) revert NotAuthorized();

            lastAddress = recoveredAddress;

            unchecked {
                ++i;
            }
        }
    }

    function _authorizeUpgrade(address _newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
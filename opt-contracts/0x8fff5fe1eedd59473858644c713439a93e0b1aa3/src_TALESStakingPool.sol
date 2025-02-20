// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { EIP712Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_cryptography_EIP712Upgradeable.sol";
import { ECDSA } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_cryptography_ECDSA.sol";
import { UUPSUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import { BitMaps } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_structs_BitMaps.sol";
import { IERC20, SafeERC20 } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";

contract TALESStakingPool is Initializable, EIP712Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using BitMaps for BitMaps.BitMap;
    using SafeERC20 for IERC20;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // keccak256("Claim(bytes32 claimId,address userAddr,uint256 nonce,uint256 amount,uint256 deadline)")
    bytes32 internal constant CLAIM_HASH = 0xc1c961ac26866f931e6133a4c65f35e8fb218859d77078e781aa3ee26d5adc9d;
    // keccak256("Unstake(bytes32 unstakeId,address userAddr,uint256 nonce,uint256 amount,uint256 deadline)")
    bytes32 internal constant UNSTAKE_HASH = 0xc0956b666fe6ca8b09e716083a13b05d706110b9f990f1947307fee644d44994;

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

    struct Unstake {
        bytes32 unstakeId;
        address userAddr;
        uint256 nonce;
        uint256 amount;
        uint256 deadline;
    }

    IERC20 public ta;
    uint8 public threshold;

    BitMaps.BitMap internal claimed;
    BitMaps.BitMap internal unstaked;
    mapping(address => uint256) internal nonces;

    uint256 public claimFeeAmount;
    uint256 public unstakeFeeAmount;

    event ThresholdSet(uint8 indexed _threshold);
    event ClaimFeeAmountSet(uint256 indexed _claimFeeAmount);
    event UnstakeFeeAmountSet(uint256 indexed _unstakeFeeAmount);
    event TALESClaimed(bytes32 _claimId, address _userAddr, uint256 _nonce, uint256 _amount);
    event TALESUnstaked(bytes32 _unstakeId, address _userAddr, uint256 _nonce, uint256 _amount);
    event TALESWithdrawn(address indexed _beneficiary, uint256 indexed _amount);

    error DeadlineExceeded();
    error InvalidZeroInput();
    error NotEnoughSignatures();
    error InvalidSignature();
    error NotAuthorized();
    error InvalidNonce();
    error AlreadyClaimed();
    error AlreadyUnstaked();
    error NothingToWithdraw();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _defaultAdmin,
        address _operator,
        address[] calldata _signers,
        address _upgrader,
        address _ta,
        uint8 _threshold,
        uint256 _claimFeeAmount,
        uint256 _unstakeFeeAmount
    )
        public
        initializer
    {
        __EIP712_init("TALESStakingPool", "1");
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

        ta = IERC20(_ta);
        threshold = _threshold;
        claimFeeAmount = _claimFeeAmount;
        unstakeFeeAmount = _unstakeFeeAmount;
    }

    function setThreshold(uint8 _threshold) public onlyRole(OPERATOR_ROLE) {
        if (_threshold == 0) revert InvalidZeroInput();
        threshold = _threshold;

        emit ThresholdSet(_threshold);
    }

    function setClaimFeeAmount(uint256 _claimFeeAmount) public onlyRole(OPERATOR_ROLE) {
        claimFeeAmount = _claimFeeAmount;

        emit ClaimFeeAmountSet(_claimFeeAmount);
    }

    function setUnstakeFeeAmount(uint256 _unstakeFeeAmount) public onlyRole(OPERATOR_ROLE) {
        unstakeFeeAmount = _unstakeFeeAmount;

        emit UnstakeFeeAmountSet(_unstakeFeeAmount);
    }

    function isClaimed(bytes32 _claimId) public view returns (bool) {
        return claimed.get(uint256(_claimId));
    }

    function isUnstaked(bytes32 _unstakedId) public view returns (bool) {
        return unstaked.get(uint256(_unstakedId));
    }

    function getCurrentNonce(address _userAddr) public view returns (uint256) {
        return nonces[_userAddr] + 1; // Reserve nonce 0 and label it as 'error'
    }

    function claim(Claim calldata _claim, Signature[] calldata _signatures) public {
        _setClaimed(_claim.claimId);
        _setNonce(_claim.userAddr, _claim.nonce);

        _validateDeadline(_claim.deadline);
        _verifySignatures(_getClaimHash(_claim), _signatures);

        IERC20(ta).safeTransfer(_claim.userAddr, _claim.amount - claimFeeAmount);

        emit TALESClaimed(_claim.claimId, _claim.userAddr, _claim.nonce, _claim.amount);
    }

    function unstake(Unstake calldata _unstake, Signature[] calldata _signatures) public {
        _setUnstaked(_unstake.unstakeId);
        _setNonce(_unstake.userAddr, _unstake.nonce);

        _validateDeadline(_unstake.deadline);
        _verifySignatures(_getUnstakeHash(_unstake), _signatures);

        IERC20(ta).safeTransfer(_unstake.userAddr, _unstake.amount - unstakeFeeAmount);

        emit TALESUnstaked(_unstake.unstakeId, _unstake.userAddr, _unstake.nonce, _unstake.amount);
    }

    function withdrawTALES(address _beneficiary) public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 amount = IERC20(ta).balanceOf(address(this));

        if (amount == 0) revert NothingToWithdraw();

        IERC20(ta).safeTransfer(_beneficiary, amount);

        emit TALESWithdrawn(_beneficiary, amount);
    }

    function _setClaimed(bytes32 _claimId) internal {
        if (isClaimed(_claimId)) revert AlreadyClaimed();

        claimed.set(uint256(_claimId));
    }

    function _setUnstaked(bytes32 _unstakeId) internal {
        if (isUnstaked(_unstakeId)) revert AlreadyUnstaked();

        unstaked.set(uint256(_unstakeId));
    }

    function _setNonce(address _userAddr, uint256 _nonce) internal {
        if (_nonce != ++nonces[_userAddr]) revert InvalidNonce();
    }

    function _getClaimHash(Claim memory _claim) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(CLAIM_HASH, _claim.claimId, _claim.userAddr, _claim.nonce, _claim.amount, _claim.deadline)
        );
    }

    function _getUnstakeHash(Unstake memory _unstake) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                UNSTAKE_HASH, _unstake.unstakeId, _unstake.userAddr, _unstake.nonce, _unstake.amount, _unstake.deadline
            )
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
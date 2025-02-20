// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Cube3ProtectionUpgradeable} from "./lib_protection-solidity_src_upgradeable_Cube3ProtectionUpgradeable.sol";
import {TransferHelper} from "./lib_v3-periphery_contracts_libraries_TransferHelper.sol";
import {EIP712Upgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_cryptography_EIP712Upgradeable.sol";
import {PausableUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_PausableUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_access_extensions_AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_ReentrancyGuardUpgradeable.sol";
import {MerkleProof} from "./lib_openzeppelin-contracts_contracts_utils_cryptography_MerkleProof.sol";
import {Extsload} from "./src_base_Extsload.sol";
import {IPoolPartyPosition, PositionId} from "./src_interfaces_IPoolPartyPosition.sol";
import {Errors} from "./src_library_Errors.sol";
import {Constants} from "./src_library_Constants.sol";
import "./src_interfaces_IPoolPartyPositionManager.sol";

struct Storage {
    address i_admin;
    address i_upgrader;
    address i_poolPositionFactory;
    address i_permit2;
    address i_nonfungiblePositionManager;
    address i_uniswapV3Factory;
    address i_swapRouter;
    address i_stableCurrency;
    address i_WETH9;
    address signerSecurityAddress;
    address protocolFeeRecipient;
    bytes32 rootForOperatorsWhitelist;
    uint24 protocolFee;
    mapping(PositionId => address operator) operatorByPositionId; // 13
    mapping(address investor => address[] positions) positionsByInvestor;
    mapping(address investor => mapping(PositionId => address position)) positionByInvestorAndId;
    mapping(PositionId => IPoolPartyPositionManagerStructs.FeatureSettings) featureSettings;
    mapping(address investor => uint256) totalInvestmentsByInvestor;
    mapping(PositionId => uint256 investors) totalInvestorsByPosition;
    mapping(PositionId => mapping(address investor => bool invested)) positionInvestedBy;
    mapping(bytes32 => mapping(bytes => bool)) signatures;
    address[] positions;
    uint256 maxInvestment;
    bool cube3ProtectionDisabled;
    bool protectionDisabled;
    bool destroyed;
}

abstract contract PoolPartyPositionManagerStorage is
    IPoolPartyPositionManager,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    Cube3ProtectionUpgradeable,
    EIP712Upgradeable,
    Extsload
{
    // slither-disable-next-line uninitialized-state,reentrancy-no-eth
    Storage internal s;

    modifier whenNotDestroyed() {
        require(!s.destroyed, Errors.IsDestroyed());
        _;
    }

    // slither-disable-start incorrect-modifier
    // aderyn-ignore-next-line(useless-modifier)
    modifier onlyPositionOperator(PositionId _positionId) {
        require(
            s.operatorByPositionId[_positionId] == msg.sender,
            Errors.NotPositionOperator()
        );
        _;
    }

    // slither-disable-start incorrect-modifier
    // aderyn-ignore-next-line(useless-modifier)
    modifier onlyWhitelistedOperator(bytes32[] calldata _proof) {
        require(
            _verifyProof(_proof, s.rootForOperatorsWhitelist),
            Errors.OperatorNotWhitelisted()
        );
        _;
    }
    // slither-disable-end incorrect-modifier

    // slither-disable-start incorrect-modifier
    // aderyn-ignore-next-line(useless-modifier)
    modifier minInvestmentInStableCurrency(uint160 _amount) {
        require(
            _amount >= Constants.MIN_INVESTMENT_STABLE,
            Errors.MinInvestmentNotMet()
        );
        _;
    }
    // slither-disable-end incorrect-modifier

    // slither-disable-start incorrect-modifier
    // aderyn-ignore-next-line(useless-modifier)
    modifier maxInvestmentCapInStableCurrency(uint160 _amount) {
        uint256 percentage = _amount /
            (s.maxInvestment / Constants.HUNDRED_PERCENT);
        require(
            (s.totalInvestmentsByInvestor[msg.sender] + percentage) <=
                Constants.HUNDRED_PERCENT,
            Errors.MaxInvestmentExceeded()
        );
        s.totalInvestmentsByInvestor[msg.sender] += percentage;
        _;
    }

    // slither-disable-end incorrect-modifier
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function initialize(ConstructorParams memory _params) public initializer {
        require(
            _params.nonfungiblePositionManager != address(0),
            Errors.AddressIsZero()
        );
        require(_params.uniswapV3Factory != address(0), Errors.AddressIsZero());
        require(
            _params.poolPositionFactory != address(0),
            Errors.AddressIsZero()
        );
        require(
            _params.protocolFeeRecipient != address(0),
            Errors.AddressIsZero()
        );
        require(
            _params.uniswapV3SwapRouter != address(0),
            Errors.AddressIsZero()
        );
        require(_params.stableCurrency != address(0), Errors.AddressIsZero());
        require(_params.WETH9 != address(0), Errors.AddressIsZero());
        require(
            _params.signerSecurityAddress != address(0),
            Errors.AddressIsZero()
        );
        require(_params.cube3Router != address(0), Errors.AddressIsZero());

        __AccessControlDefaultAdminRules_init(3 days, _params.admin);
        if (_params.cube3CheckProtection) {
            __Cube3ProtectionUpgradeable_init(
                _params.cube3Router,
                _params.admin,
                _params.cube3CheckProtection
            );
        }
        __EIP712_init(Constants.EIP712_NAME, Constants.EIP712_VERSION);

        s.i_admin = _params.admin;
        s.i_upgrader = _params.upgrader;
        s.i_nonfungiblePositionManager = _params.nonfungiblePositionManager;
        s.i_uniswapV3Factory = _params.uniswapV3Factory;
        s.i_swapRouter = _params.uniswapV3SwapRouter;
        s.i_permit2 = _params.permit2;
        s.i_WETH9 = _params.WETH9;
        s.i_stableCurrency = _params.stableCurrency;
        s.i_poolPositionFactory = _params.poolPositionFactory;
        s.protocolFeeRecipient = _params.protocolFeeRecipient;
        s.protocolFee = 5_000; // 50%
        s.rootForOperatorsWhitelist = _params.rootForOperatorsWhitelist;
        s.signerSecurityAddress = _params.signerSecurityAddress;
        s.cube3ProtectionDisabled = !_params.cube3CheckProtection;
        s.protectionDisabled = false;

        _grantRole(Constants.UPGRADER_ROLE, _params.upgrader);
    }

    function isDestroyed() external view returns (bool) {
        return s.destroyed;
    }

    function _verifyProof(
        bytes32[] memory _proof,
        bytes32 _root
    ) private view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        return MerkleProof.verify(_proof, _root, leaf);
    }
}
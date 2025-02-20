// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import {IERC721Metadata} from "./openzeppelin_contracts_token_ERC721_extensions_IERC721Metadata.sol";

import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {IERC1155} from "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
import {IERC165} from "./openzeppelin_contracts_utils_introspection_IERC165.sol";
import {IERC721Enumerable} from "./openzeppelin_contracts_token_ERC721_extensions_IERC721Enumerable.sol";
import {PoolManagerFactory} from "./src_factory_PoolManagerFactory.sol";
// @dev Solmate's ERC20 is used instead of OZ's ERC20 so we can use safeTransferLib for cheaper safeTransfers for
// ETH and ERC20 tokens
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {SafeTransferLib} from "./solmate_utils_SafeTransferLib.sol";
import {PoolInfo} from "./src_lib_Types.sol";
import {Pool} from "./src_pool_Pool.sol";
import {ICurve} from "./src_bonding-curves_ICurve.sol";
import {PoolCloner} from "./src_lib_PoolCloner.sol";

import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";

import {PoolETH} from "./src_pool_PoolETH.sol";
import {PoolERC20} from "./src_pool_PoolERC20.sol";
import {PoolEnumerableETH} from "./src_pool_PoolEnumerableETH.sol";
import {PoolEnumerableERC20} from "./src_pool_PoolEnumerableERC20.sol";
import {PoolMissingEnumerableETH} from "./src_pool_PoolMissingEnumerableETH.sol";
import {PoolMissingEnumerableERC20} from "./src_pool_PoolMissingEnumerableERC20.sol";
import {LpCloner} from "./src_lp-tokens_LpCloner.sol";
import {ILpCloner} from "./src_lp-tokens_interfaces_ILpCloner.sol";
import {IRouter} from "./src_router_IRouter.sol";
import "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import {IPoolManager} from "./src_pool_interfaces_IPoolManager.sol";

contract PoolFactory is Ownable, IPoolFactoryLike {
    using PoolCloner for address;
    using SafeTransferLib for address payable;
    using SafeERC20 for IERC20;

    ILpCloner public lpCloner;

    uint256 MAX_SLIPPAGE = 0.5e18;

    bytes4 private constant INTERFACE_ID_ERC721_ENUMERABLE =
        type(IERC721Enumerable).interfaceId;
    bytes4 private constant INTERFACE_ID_ERC1155 = type(IERC1155).interfaceId;

    uint256 internal constant MAX_PROTOCOL_FEE = 0.10e18; // 10%, must <= 1 - MAX_FEE

    PoolEnumerableETH public immutable enumerableETHTemplate;
    PoolMissingEnumerableETH public immutable missingEnumerableETHTemplate;
    PoolEnumerableERC20 public immutable enumerableERC20Template;
    PoolMissingEnumerableERC20 public immutable missingEnumerableERC20Template;
    address payable public override protocolFeeRecipient;

    // Units are in base 1e18
    uint256 public override protocolFeeMultiplier;

    mapping(ICurve => bool) public bondingCurveAllowed;
    mapping(address => bool) public override callAllowed;
    mapping(address => bool) public signatureAdmins;
    mapping(uint256 => uint256) public timelockValues;
    uint256[] timelockKeys;

    PoolManagerFactory poolManagerFactory;

    struct RouterStatus {
        bool allowed;
        bool wasEverAllowed;
    }

    mapping(IRouter => RouterStatus) public override routerStatus;

    struct CloneEthPoolParams {
        address nft;
        ICurve bondingCurve;
        PoolInfo.PoolType poolType;
    }
    struct CloneERC20PoolParams {
        address nft;
        ICurve bondingCurve;
        PoolInfo.PoolType poolType;
        IERC20 token;
    }

    event NewPool(
        address poolAddress,
        string fileHash,
        address lpfToken,
        address lpnToken,
        address poolManager
    );
    event ProtocolFeeRecipientUpdate(address recipientAddress);
    event ProtocolFeeMultiplierUpdate(uint256 newMultiplier);
    event BondingCurveStatusUpdate(ICurve bondingCurve, bool isAllowed);
    event CallTargetStatusUpdate(address target, bool isAllowed);
    event RouterStatusUpdate(IRouter router, bool isAllowed);
    event TimelockTableUpdated(uint256[] values);

    constructor(
        PoolEnumerableETH _enumerableETHTemplate,
        PoolMissingEnumerableETH _missingEnumerableETHTemplate,
        PoolEnumerableERC20 _enumerableERC20Template,
        PoolMissingEnumerableERC20 _missingEnumerableERC20Template,
        address payable _protocolFeeRecipient,
        uint256 _protocolFeeMultiplier
    ) {
        enumerableETHTemplate = _enumerableETHTemplate;
        missingEnumerableETHTemplate = _missingEnumerableETHTemplate;
        enumerableERC20Template = _enumerableERC20Template;
        missingEnumerableERC20Template = _missingEnumerableERC20Template;
        protocolFeeRecipient = _protocolFeeRecipient;

        require(
            _protocolFeeMultiplier <= MAX_PROTOCOL_FEE,
            "PF: Fee too large"
        );
        protocolFeeMultiplier = _protocolFeeMultiplier;

        lpCloner = new LpCloner(address(this));
        poolManagerFactory = new PoolManagerFactory(address(this));
        //TODO -- remove deployer as signature admin before release.
        signatureAdmins[msg.sender] = true;
    }

    /**
     * External functions
     */
    function is1155Contract(address nft) external view returns (bool) {
        try IERC165(nft).supportsInterface(INTERFACE_ID_ERC1155) returns (
            bool is1155
        ) {
            return is1155 ? true : false;
        } catch {
            return false;
        }
    }

    /**
        @notice Creates a pair contract using EIP-1167.
        @param cloneParams See doc ${CloneEthPoolParams}
        @param params See doc ${PoolInfo.CloneEthPoolParams}
     */
    function createPoolETH(
        CloneEthPoolParams calldata cloneParams,
        PoolInfo.InitPoolParams calldata params
    ) external returns (PoolETH pool) {
        require(
            address(lpCloner) != address(0),
            "CPE: Lp Cloner not initialized"
        );

        require(
            bondingCurveAllowed[cloneParams.bondingCurve],
            "CPE: Bonding curve not whitelisted"
        );

        // Check to see if the NFT supports Enumerable to determine which template to use
        address template;
        if (this.is1155Contract(cloneParams.nft)) {
            template = address(missingEnumerableETHTemplate);
        } else {
            try
                IERC165(cloneParams.nft).supportsInterface(
                    INTERFACE_ID_ERC721_ENUMERABLE
                )
            returns (bool isEnumerable) {
                template = isEnumerable
                    ? address(enumerableETHTemplate)
                    : address(missingEnumerableETHTemplate);
            } catch {
                template = address(missingEnumerableETHTemplate);
            }
        }
        pool = PoolETH(
            payable(
                template.cloneETHPool(
                    this,
                    cloneParams.bondingCurve,
                    cloneParams.nft,
                    uint8(cloneParams.poolType)
                )
            )
        );
        _initializePoolETH(pool, params);
    }

    function createPoolERC20(
        CloneERC20PoolParams calldata cloneParams,
        PoolInfo.InitPoolParams calldata params
    ) external returns (PoolERC20 pair) {
        require(
            bondingCurveAllowed[cloneParams.bondingCurve],
            "Bonding curve not whitelisted"
        );

        // Check to see if the NFT supports Enumerable to determine which template to use
        address template;
        try
            IERC165(address(cloneParams.nft)).supportsInterface(
                INTERFACE_ID_ERC721_ENUMERABLE
            )
        returns (bool isEnumerable) {
            template = isEnumerable
                ? address(enumerableERC20Template)
                : address(missingEnumerableERC20Template);
        } catch {
            template = address(missingEnumerableERC20Template);
        }

        pair = PoolERC20(
            payable(
                template.cloneERC20Pool(
                    this,
                    cloneParams.bondingCurve,
                    cloneParams.nft,
                    uint8(cloneParams.poolType),
                    cloneParams.token
                )
            )
        );

        _initializePoolERC20(pair, params);
    }

    function setLpCloner(ILpCloner _lpCloner) external onlyOwner {
        require(_lpCloner != lpCloner, "PF: no change in state");
        lpCloner = _lpCloner;
    }

    function setPoolManagerFactory(address _poolManager) external onlyOwner {
        require(
            address(poolManagerFactory) != _poolManager,
            "PF: no change in state"
        );
        poolManagerFactory = PoolManagerFactory(_poolManager);
    }

    function setValidSignatureAdmin(
        address admin,
        bool value
    ) external onlyOwner {
        require(signatureAdmins[admin] != value, "no change in state");
        signatureAdmins[admin] = value;
    }

    /** 
        @notice Check if a signature provided for rarity value in swap is signed by one of the allowed signature admins.
        @param _admin address recovered from signature
        @return True if the address is valid signature admin false if not allowed
     */
    function isValidSignatureAdmin(
        address _admin
    ) external view returns (bool) {
        return signatureAdmins[_admin];
    }

    /** 
        @notice Checks if an address is a Pool. Uses the fact that the pairs are EIP-1167 minimal proxies.
        @param potentialPool The address to check
        @param variant The pair variant (NFT is enumerable or not, pair uses ETH or ERC20)
        @return True if the address is the specified pair variant, false otherwise
     */
    function isPool(
        address potentialPool,
        PoolVariant variant
    ) public view override returns (bool) {
        if (variant == PoolVariant.ENUMERABLE_ERC20) {
            return
                PoolCloner.isERC20PoolClone(
                    address(this),
                    address(enumerableERC20Template),
                    potentialPool
                );
        } else if (variant == PoolVariant.MISSING_ENUMERABLE_ERC20) {
            return
                PoolCloner.isERC20PoolClone(
                    address(this),
                    address(missingEnumerableERC20Template),
                    potentialPool
                );
        } else if (variant == PoolVariant.ENUMERABLE_ETH) {
            return
                PoolCloner.isETHPoolClone(
                    address(this),
                    address(enumerableETHTemplate),
                    potentialPool
                );
        } else if (variant == PoolVariant.MISSING_ENUMERABLE_ETH) {
            return
                PoolCloner.isETHPoolClone(
                    address(this),
                    address(missingEnumerableETHTemplate),
                    potentialPool
                );
        } else {
            // invalid input
            return false;
        }
    }

    /**
        @notice Allows receiving ETH in order to receive protocol fees
     */
    receive() external payable {}

    /**
     * Admin functions
     */

    /**
        @notice Withdraws the ETH balance to the protocol fee recipient.
        Only callable by the owner.
     */
    function withdrawETHProtocolFees() external onlyOwner {
        protocolFeeRecipient.safeTransferETH(address(this).balance);
    }

    /**
        @notice Withdraws ERC20 tokens to the protocol fee recipient. Only callable by the owner.
        @param token The token to transfer
        @param amount The amount of tokens to transfer
     */
    function withdrawERC20ProtocolFees(
        IERC20 token,
        uint256 amount
    ) external onlyOwner {
        token.safeTransfer(protocolFeeRecipient, amount);
    }

    /**
        @notice Changes the protocol fee recipient address. Only callable by the owner.
        @param _protocolFeeRecipient The new fee recipient
     */
    function changeProtocolFeeRecipient(
        address payable _protocolFeeRecipient
    ) external onlyOwner {
        require(_protocolFeeRecipient != address(0), "0 address");
        protocolFeeRecipient = _protocolFeeRecipient;
        emit ProtocolFeeRecipientUpdate(_protocolFeeRecipient);
    }

    /**
        @notice Changes the protocol fee multiplier. Only callable by the owner.
        @param _protocolFeeMultiplier The new fee multiplier, 18 decimals
     */
    function changeProtocolFeeMultiplier(
        uint256 _protocolFeeMultiplier
    ) external onlyOwner {
        require(_protocolFeeMultiplier <= MAX_PROTOCOL_FEE, "Fee too large");
        protocolFeeMultiplier = _protocolFeeMultiplier;
        emit ProtocolFeeMultiplierUpdate(_protocolFeeMultiplier);
    }

    /**
        @notice Sets the whitelist status of a bonding curve contract. Only callable by the owner.
        @param bondingCurve The bonding curve contract
        @param isAllowed True to whitelist, false to remove from whitelist
     */
    function setBondingCurveAllowed(
        ICurve bondingCurve,
        bool isAllowed
    ) external onlyOwner {
        bondingCurveAllowed[bondingCurve] = isAllowed;
        emit BondingCurveStatusUpdate(bondingCurve, isAllowed);
    }

    /**
        @notice Sets the whitelist status of a contract to be called arbitrarily by a pair.
        Only callable by the owner.
        @param target The target contract
        @param isAllowed True to whitelist, false to remove from whitelist
     */
    function setCallAllowed(
        address payable target,
        bool isAllowed
    ) external onlyOwner {
        // ensure target is not / was not ever a router
        if (isAllowed) {
            require(
                !routerStatus[IRouter(target)].wasEverAllowed,
                "Can't call router"
            );
        }

        callAllowed[target] = isAllowed;
        emit CallTargetStatusUpdate(target, isAllowed);
    }

    /**
        @notice Updates the router whitelist. Only callable by the owner.
        @param _router The router
        @param isAllowed True to whitelist, false to remove from whitelist
     */
    function setRouterAllowed(
        IRouter _router,
        bool isAllowed
    ) external onlyOwner {
        // ensure target is not arbitrarily callable by pairs
        if (isAllowed) {
            require(!callAllowed[address(_router)], "Can't call router");
        }
        routerStatus[_router] = RouterStatus({
            allowed: isAllowed,
            wasEverAllowed: true
        });

        emit RouterStatusUpdate(_router, isAllowed);
    }

    /**
     * Internal functions
     */

    function _initializePoolETH(
        PoolETH _pool,
        PoolInfo.InitPoolParams calldata params
    ) internal {
        address poolManager = poolManagerFactory.createPoolManager(
            address(_pool)
        );

        (address lpfToken, address lpnToken) = lpCloner.cloneLpTokens(
            params.lpIdentifier,
            address(poolManager)
        );

        _pool.initialize(
            msg.sender,
            params,
            lpfToken,
            lpnToken,
            IPoolManager(poolManager)
        );
        emit NewPool(
            address(_pool),
            params.fileHash,
            lpfToken,
            lpnToken,
            poolManager
        );
    }

    function _initializePoolERC20(
        PoolERC20 _pool,
        PoolInfo.InitPoolParams calldata params
    ) internal {
        address poolManager = poolManagerFactory.createPoolManager(
            address(_pool)
        );

        (address lpfToken, address lpnToken) = lpCloner.cloneLpTokens(
            params.lpIdentifier,
            address(poolManager)
        );

        _pool.initialize(
            msg.sender,
            params,
            lpfToken,
            lpnToken,
            IPoolManager(poolManager)
        );
        emit NewPool(
            address(_pool),
            params.fileHash,
            lpfToken,
            lpnToken,
            poolManager
        );
    }

    function verifyRaritySignature(
        uint256[] memory _tokenIds,
        uint256[] memory _rarities,
        address _nft,
        bytes memory _adminSignature
    ) external view returns (bool) {
        address recovered = ECDSA.recover(
            keccak256(abi.encode(_nft, _tokenIds, _rarities)),
            _adminSignature
        );
        return this.isValidSignatureAdmin(recovered);
    }

    function saveTimeLockTable(
        uint256[] memory percentages,
        uint256[] calldata _timelockValues
    ) external onlyOwner {
        require(
            percentages.length == _timelockValues.length,
            "Table length mismatch"
        );
        timelockKeys = new uint256[](percentages.length);
        for (uint256 i = 0; i < percentages.length; i++) {
            timelockValues[percentages[i]] = _timelockValues[i];
            timelockKeys[i] = percentages[i];
        }

        emit TimelockTableUpdated(_timelockValues);
    }

    function getTimelockValueForPercentage(
        uint256 percentage
    ) external view returns (uint256) {
        for (uint256 i = 0; i < timelockKeys.length; i++) {
            if (percentage <= timelockKeys[i]) {
                return timelockValues[timelockKeys[i]];
            }
        }
        return 0;
    }
}
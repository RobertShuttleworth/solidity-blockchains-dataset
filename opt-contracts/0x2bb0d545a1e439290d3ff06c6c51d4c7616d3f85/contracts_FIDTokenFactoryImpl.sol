// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import {Clones} from "./openzeppelin_contracts_proxy_Clones.sol";
import {OwnableUpgradeable} from "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import {ERC1967Utils} from "./openzeppelin_contracts_proxy_ERC1967_ERC1967Utils.sol";
import {IIdRegistry} from "./contracts_interfaces_IIdRegistry.sol";
import {IFIDTokenFactory} from "./contracts_interfaces_IFIDTokenFactory.sol";
import "./openzeppelin_contracts_interfaces_IERC1271.sol";
import {FIDToken} from "./contracts_FIDToken.sol";
import {SignatureChecker} from "./openzeppelin_contracts_utils_cryptography_SignatureChecker.sol";

contract FIDTokenFactoryImpl is IFIDTokenFactory, UUPSUpgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable,IERC1271 {
    address public immutable tokenImplementation;
    address public immutable bondingCurve;
    address public immutable fidRegistry;

    bool internal processingTransfer;

    constructor(address _tokenImplementation, address _bondingCurve, address _fidRegistry) {
        tokenImplementation = _tokenImplementation;
        bondingCurve = _bondingCurve;
        fidRegistry = _fidRegistry;
    }

    /// @notice Initializes the factory proxy contract
    /// @param _owner Address of the contract owner
    /// @dev Can only be called once due to initializer modifier
    function initialize(address _owner) external initializer {
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Ownable_init(_owner);
    }

    /// @notice Creates a Far token with bonding curve mechanics that graduates to Uniswap V3
    /// @param _tokenCreator The address of the token creator. Must be the owner of the fid
    /// @param _platformReferrer The address of the platform referrer
    /// @param _tokenURI The ERC20z token URI
    /// @param _name The ERC20 token name
    /// @param _symbol The ERC20 token symbol
    /// @param _platformReferrerFeeBps The platform referrer fee in BPS
    /// @param _orderReferrerFeeBps The order referrer fee in BPS
    /// @param _allocatedSupply The number of tokens allocated to the bonding curve. The portion allocated to the creator is PRIMARY_MARKET_SUPPLY - allocatedSupply
    /// @param _fid The Farcaster ID of the token creator
    /// @param _deadline The deadline for the fid transfer
    /// @param _sig The signature of the fid transfer
    function deploy(
        address _tokenCreator,
        address _platformReferrer,
        string memory _tokenURI,
        string memory _name,
        string memory _symbol,
        uint256 _platformReferrerFeeBps,
        uint256 _orderReferrerFeeBps,
        uint256 _allocatedSupply,
        uint256 _fid,
        uint256 _deadline,
        bytes calldata _sig
    ) external payable nonReentrant returns (address) {
        bytes32 salt = _generateSalt(_tokenCreator, _tokenURI);

        FIDToken token = FIDToken(payable(Clones.cloneDeterministic(tokenImplementation, salt)));

        _initializeFidTransfer(_fid, _tokenCreator, _deadline, _sig, address(token));
        token.initialize{value: msg.value}(_tokenCreator, _platformReferrer, bondingCurve, _tokenURI, _name, _symbol, _platformReferrerFeeBps, _orderReferrerFeeBps, _allocatedSupply, _fid);

        emit FIDTokenCreated(
            address(this),
            _tokenCreator,
            _platformReferrer,
            token.protocolFeeRecipient(),
            bondingCurve,
            _tokenURI,
            _name,
            _symbol,
            address(token),
            token.poolAddress(),
            _platformReferrerFeeBps,
            _orderReferrerFeeBps,
            _fid,
            _allocatedSupply
        );

        return address(token);
    }

    /// @dev Generates a unique salt for deterministic deployment
    function _generateSalt(address _tokenCreator, string memory _tokenURI) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                msg.sender,
                _tokenCreator,
                keccak256(abi.encodePacked(_tokenURI)),
                block.coinbase,
                block.number,
                block.prevrandao,
                block.timestamp,
                tx.gasprice,
                tx.origin
            )
        );
    }

        /// @dev transfer fid to this proxy if it's not already owned by the proxy
    function _transferFidAndSetRecovery(
        address owner,
        uint256 deadline,
        bytes memory ownerSignature,
        address to
    ) internal {
        IIdRegistry(fidRegistry).transferFor(owner, address(this), deadline, ownerSignature, deadline, ownerSignature);

        // set recovery address
        IIdRegistry(fidRegistry).changeRecoveryAddress(to);

        // transfer the fid to the to
        IIdRegistry(fidRegistry).transfer(to, deadline, ownerSignature);
    }

    /// @dev initialize the fid transfer to this proxy, then transfer the fid to the FIDToken Contract
    function _initializeFidTransfer(uint256 _fid, address _owner, uint256 _deadline, bytes calldata _sig, address _to) internal {
        require(processingTransfer == false, "AlreadyProcessing");
        require(_fid != 0, "InvalidFID");
        require(IIdRegistry(fidRegistry).idOf(_owner) == _fid, "InvalidTokenCreator");

        processingTransfer = true;

        _transferFidAndSetRecovery(_owner, _deadline, _sig, _to);
        processingTransfer = false;
    }

    function isValidSignature(bytes32 hash, bytes memory signature) public view returns (bytes4 magicValue) {
        bool isSignatureValid = SignatureChecker.isValidSignatureNow(owner(), hash, signature);

        if (isSignatureValid || processingTransfer) {
            return this.isValidSignature.selector;
        } else {
            return bytes4(0);
        }
    }


    /// @notice The implementation address of the factory contract
    function implementation() external view returns (address) {
        return ERC1967Utils.getImplementation();
    }

    /// @dev Authorizes an upgrade to a new implementation
    /// @param _newImpl The new implementation address
    function _authorizeUpgrade(address _newImpl) internal override onlyOwner {}
}

// Inspired by the open-source Wow Protocol
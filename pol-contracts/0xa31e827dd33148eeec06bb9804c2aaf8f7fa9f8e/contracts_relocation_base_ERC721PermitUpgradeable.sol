// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC721Upgradeable} from "./openzeppelin_contracts-upgradeable_token_ERC721_ERC721Upgradeable.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {EIP712Upgradeable} from "./openzeppelin_contracts-upgradeable_utils_cryptography_EIP712Upgradeable.sol";
import {IERC1271} from "./openzeppelin_contracts_interfaces_IERC1271.sol";
import {ECDSA} from "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";

import './contracts_relocation_interfaces_external_IERC721Permit.sol';


/**
 * @title ERC721 with permit
 * @notice Contract module that support an approve via signature, i.e. permit.
 * @dev Credits to Uniswap V3
 * 
 * @custom:website https://nft.poczta-polska.pl
 * @author rutilicus.eth (ArchXS)
 * @custom:security-contact contact@archxs.com
 */
abstract contract ERC721PermitUpgradeable is Initializable, ERC721Upgradeable, EIP712Upgradeable, IERC721Permit { 
    /**
     * @dev The permit period has been expird.
     */
    error PermitExpired();

    /**
     * @dev Forbidden permit.
     */
    error UnauthorizedPermit();

    /**
     * @dev Invalid permit signature.
     */
    error InvalidSignature();

    /**
     * @dev Perimt of token to the given spender is not allowed.
     */
    error PermitNotAllowed(address spender);

    /// @dev Value is equal to keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

    function __ERC721Permit_init(string memory _name, string memory _symbol, string memory _version) internal onlyInitializing {
        __ERC721_init(_name, _symbol);
        __EIP712_init(_name, _version);

       __ERC721Permit_init_unchained();
    }

    function __ERC721Permit_init_unchained() internal onlyInitializing {
    }

    /**
     *  @dev Gets the current nonce for a token ID and then increments it, returning the original value.
     */ 
    function getCurrentNonce(uint256 tokenId) internal virtual returns (uint256);

    /**
     * @dev See {IERC721Permit-permit}.
     */
    function permit(address spender, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable override {
        if (block.timestamp > deadline) {
            revert PermitExpired();
        }

        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(PERMIT_TYPEHASH, spender, tokenId, getCurrentNonce(tokenId), deadline))
        );

        address owner = ownerOf(tokenId);
        if (spender == owner) {
            revert PermitNotAllowed(spender);
        }

        if (_isContract(owner)) {
            if (IERC1271(owner).isValidSignature(digest, abi.encodePacked(r, s, v)) != 0x1626ba7e) {
                revert UnauthorizedPermit();
            }
 
        } else {
            address signer = ECDSA.recover(digest, v, r, s);

            if (signer == address(0)) {
                revert InvalidSignature();
            }

            if (signer != owner) {
                revert UnauthorizedPermit();
            }
        }

        _approve(spender, tokenId, _msgSender());
    }

    // ************************************* 
    // Utility methods
    // *************************************

    function _isContract(address _address) internal view returns (bool) {
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(_address)
        }
        return codeSize > 0;
    }
}
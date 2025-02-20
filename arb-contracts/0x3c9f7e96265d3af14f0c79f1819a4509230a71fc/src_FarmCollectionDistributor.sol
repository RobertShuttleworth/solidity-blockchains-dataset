// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./src_interfaces_IFarmCollection.sol";
import "./src_libraries_Errors.sol";
import "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

/// @title FarmCollectionDistributor
/// @notice Manages NFT minting with revenue sharing between fund collector and ancestor owners
contract FarmCollectionDistributor is Ownable {
    /// @notice Reference to the base farm collection contract
    IFarmCollection public immutable farmCollection;

    /// @notice Token used for payments (e.g., USDC)
    IERC20 public immutable paymentToken;

    /// @notice Address that receives the main portion of payments
    address public fundCollector;

    /// @notice Current price to mint an NFT
    uint256 public mintPrice;

    /// @notice Percentage of mint price shared with ancestor (10%)
    uint256 public constant ANCESTOR_SHARE = 10;

    /// @notice Tracks valid ancestor token IDs
    mapping(uint256 => bool) public ancestorIds;

    /// @notice Emitted when fund collector address is updated
    event FundCollectorUpdated(address newCollector);

    /// @notice Emitted when mint price is updated
    event MintPriceUpdated(uint256 newPrice);

    /// @notice Emitted when ancestor IDs are updated
    /// @param ancestorIds Array of token IDs being updated
    /// @param isValid New validity status for the IDs
    event AncestorIdsUpdated(uint256[] ancestorIds, bool isValid);

    /// @notice Emitted when a new NFT is minted
    /// @param minter Address that minted the NFT
    /// @param imageId Image identifier that was minted
    /// @param ancestorId Token ID of the ancestor receiving share
    /// @param ancestorOwner Address of ancestor owner receiving the share
    /// @param ancestorAmount Amount sent to ancestor owner
    /// @param fundCollectorAmount Amount sent to fund collector
    event Minted(
        address indexed minter,
        string imageId,
        uint256 indexed ancestorId,
        address ancestorOwner,
        uint256 ancestorAmount,
        uint256 fundCollectorAmount
    );

    /// @notice Initializes the contract with required parameters
    /// @param _farmCollection Address of the base NFT collection
    /// @param _paymentToken Address of the payment token
    /// @param _fundCollector Address receiving main portion of payments
    /// @param _mintPrice Initial mint price
    constructor(
        address _farmCollection,
        address _paymentToken,
        address _fundCollector,
        uint256 _mintPrice
    ) Ownable(msg.sender) {
        if (_farmCollection == address(0) || _paymentToken == address(0) || _fundCollector == address(0))
            revert Errors.InvalidAddress();

        farmCollection = IFarmCollection(_farmCollection);
        paymentToken = IERC20(_paymentToken);
        fundCollector = _fundCollector;
        mintPrice = _mintPrice;
    }

    /// @notice Updates the fund collector address
    /// @param _newCollector New address to receive payments
    function setFundCollector(address _newCollector) external onlyOwner {
        if (_newCollector == address(0)) revert Errors.InvalidAddress();
        fundCollector = _newCollector;
        emit FundCollectorUpdated(_newCollector);
    }

    /// @notice Updates the NFT mint price
    /// @param _newPrice New price in payment token units
    function setMintPrice(uint256 _newPrice) external onlyOwner {
        mintPrice = _newPrice;
        emit MintPriceUpdated(_newPrice);
    }

    /// @notice Batch sets validity status for ancestor token IDs
    /// @param _ancestorIds Array of token IDs to update
    /// @param isValid Whether the IDs should be considered valid ancestors
    function setAncestorIds(uint256[] calldata _ancestorIds, bool isValid) external onlyOwner {
        for (uint256 i = 0; i < _ancestorIds.length; i++) {
            ancestorIds[_ancestorIds[i]] = isValid;
        }
        emit AncestorIdsUpdated(_ancestorIds, isValid);
    }

    /// @notice Mints a new NFT with revenue sharing
    /// @param imageId Unique identifier for the image
    /// @param ancestorId Token ID of the ancestor to receive share
    function mint(string calldata imageId, uint256 ancestorId) external {
        if (!ancestorIds[ancestorId]) revert Errors.InvalidAncestorId();

        address ancestorOwner = farmCollection.ownerOf(ancestorId);
        if (ancestorOwner == address(0)) revert Errors.InvalidAddress();

        uint256 ancestorAmount = (mintPrice * ANCESTOR_SHARE) / 100;
        uint256 fundCollectorAmount = mintPrice - ancestorAmount;

        bool success = paymentToken.transferFrom(msg.sender, ancestorOwner, ancestorAmount);
        if (!success) revert Errors.TransferFailed();

        success = paymentToken.transferFrom(msg.sender, fundCollector, fundCollectorAmount);
        if (!success) revert Errors.TransferFailed();

        farmCollection.mintWithOperator(msg.sender, imageId);

        emit Minted( msg.sender, imageId, ancestorId, ancestorOwner, ancestorAmount, fundCollectorAmount );
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_CountersUpgradeable.sol";
import "./contracts_Factory_tokens_ERC721Token.sol";
import "./contracts_Factory_tokens_LazyMintERC721Token.sol";
import "./contracts_Beacon_BeaconProxy.sol";
import "./contracts_PaymentSplitter_SplitterContract.sol";
import "./contracts_interface_IAccessControl.sol";

contract MarketplaceFactory is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _saltValue;
    IAccessControl public accessControl;

    address public erc721Beacon; // address of beacon
    address public ERC721; // address of beacon proxy
    address public lazyMintErc721Beacon; // address of beacon
    address public lazyMintERC721; // address of beacon proxy
    address public minter; // minter wallet address
    address public admin; // admin wallet address
    address[] private allCollectionsRegulated; // all created collections through this contract
    address[] private allCollectionsUnregulated; // all created collections through this contract
    address[] private payees; // payees array (payment splitter contract)

    struct PartnerFee {
        uint16 platformFee;
        uint16 royaltyFee;
        uint8 creatorRoyaltyFee;
        uint8 clientRoyaltyFee;
        bool usePartnerFee;
    }

    struct FeeStruct {
        uint16 platformFee;
        uint16 royaltyFee;
        uint8 creatorRoyaltyFee;
        uint8 clientRoyaltyFee;
    }

    FeeStruct public regulatedFees;
    FeeStruct public unRegulatedFees;
    mapping(address => PartnerFee) public partnerFee;
    uint256[] private shares; // shares of payees

    string public constant name = "REALWORLD NFT";

    mapping(address => address[]) public userCreatedCollections; // maps the user account with his/her created collections array
    mapping(address => string[]) public collectionAttributes; // maps the user account with his/her created collection address and it's attributes array
    mapping(address => bool) public isCollectionDestroyed; // maps collection address to boolean (if true collection is destroyed)

    enum tokenTypes {
        ERC721,
        lazyMintERC721
    }

    event CreatedERC721(address indexed token, address clientAddress, string[] attributes, bool isRegulated);
    event CreatedLazyMintERC721(address indexed token, address clientAddress, string[] attributes, bool isRegulated, string[] lazyMintUris);
    event CreatedPaymentSplitter(address indexed paymentSplitter);
    event UpdatedBeaconProxy(address indexed erc721BeaconProxy);
    event UpdatedBeacon(address indexed erc721Beacon);
    event UpdatedLazyMintBeacon(address indexed lazyMintErc721Beacon);
    event UpdatedLazyMintBeaconProxy(address indexed lazyMintErc721BeaconProxy);
    event WithdrawNativeFromFactory(address indexed owner, uint256 balance);
    event SetCollectionAttributes(
        address indexed collection,
        string[] attributes
    );
    event SetRegulatedFee(FeeStruct fee);
    event SetUnregulatedFee(FeeStruct fee);
    event PartnerFeesUpdated(PartnerFee indexed partnerFee);
    event CollectionDestroyed(address indexed collection);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @dev Initializes the contract.
     *
     * @param _accessControl,
     * @param _platformFeeRegulated platform fee.
     * @param _platformFeeUnregulated platform fee.
     * @param _royaltyFeeRegulated royalty fee percentage.
     * @param _royaltyFeeUnregulated royalty fee percentage.
     * @param _creatorRoyaltyFeeRegulated.
     * @param _creatorRoyaltyFeeUnregulated.
     * @param _clientRoyaltyFeeRegulated.
     * @param _clientRoyaltyFeeUnregulated.
     */
    function initialize(
        address _accessControl,
        address _minter,
        uint16 _platformFeeRegulated,
        uint16 _platformFeeUnregulated,
        uint16 _royaltyFeeRegulated,
        uint16 _royaltyFeeUnregulated,
        uint8 _creatorRoyaltyFeeRegulated,
        uint8 _creatorRoyaltyFeeUnregulated,
        uint8 _clientRoyaltyFeeRegulated,
        uint8 _clientRoyaltyFeeUnregulated
    ) external initializer {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();

        require(_accessControl != address(0), "Address cant be zero address");
        require(_minter != address(0), "Address cant be zero address");

        accessControl = IAccessControl(_accessControl);
        minter = _minter;
        setRegulatedFees(_platformFeeRegulated, _royaltyFeeRegulated, _creatorRoyaltyFeeRegulated, _clientRoyaltyFeeRegulated);
        setUnregulatedFees(_platformFeeUnregulated, _royaltyFeeUnregulated, _creatorRoyaltyFeeUnregulated, _clientRoyaltyFeeUnregulated);
        admin = owner();
    }

    /**
     * @dev Creates an ERC721 token.
     *
     * @param collectionName name of the collection
     * @param collectionSymbol symbol of the collection
     * @param _receiver royalty receiver address
     *
     * Emits {CreatedERC721} event indicating the token address.
     * Emits {CreatedPaymentSplitter} event.
     */
    function createERC721CollectionRegulated(
        string memory collectionName,
        string memory collectionSymbol,
        string memory collectionDescription,
        address _receiver,
        string[] memory _collectionAttributes
    ) external whenNotPaused nonReentrant {
        require(accessControl.whitelisted(msg.sender), "Account not whitelisted");
        uint256 salt = _saltValue.current();
        _saltValue.increment();

        FeeStruct memory fee = getFees(_receiver, true);
        require(
            (fee.creatorRoyaltyFee + fee.clientRoyaltyFee) == 100,
            "Invalid share partition"
        );
        payees = [msg.sender, _receiver];
        shares = [fee.creatorRoyaltyFee, fee.clientRoyaltyFee];
        SplitterContract paymentSplitter = new SplitterContract(payees, shares);

        address beaconProxy = _deployProxy(
            _getERC721Data(
                collectionName,
                collectionSymbol,
                collectionDescription,
                fee.royaltyFee,
                fee.platformFee,
                admin,
                address(this),
                address(paymentSplitter)
            ),
            salt,
            tokenTypes.ERC721
        );
        ERC721Token token = ERC721Token(address(beaconProxy));
        userCreatedCollections[msg.sender].push(address(token));
        allCollectionsRegulated.push(address(token));
        emit CreatedPaymentSplitter(address(paymentSplitter));
        emit CreatedERC721(address(token), _receiver, _collectionAttributes, true);
        token.transferOwnership(msg.sender);
        collectionAttributes[address(token)] = _collectionAttributes;
    }

    /**
     * @dev Creates an LazyMintERC721 token.
     *
     * @param collectionName name of the collection
     * @param collectionSymbol symbol of the collection
     * @param _receiver royalty receiver address
     *
     * Emits {CreatedLazyMintERC721} event indicating the token address.
     * Emits {CreatedPaymentSplitter} event.
     */
    function createLazyMintERC721CollectionRegulated(
        string memory collectionName,
        string memory collectionSymbol,
        string memory collectionDescription,
        address _receiver,
        string[] memory _collectionAttributes,
        string[] memory lazyMintUris
    ) external whenNotPaused nonReentrant {
        require(accessControl.whitelisted(msg.sender), "Account not whitelisted");
        uint256 salt = _saltValue.current();
        _saltValue.increment();

        FeeStruct memory fee = getFees(_receiver, true);
        require(
            (fee.creatorRoyaltyFee + fee.clientRoyaltyFee) == 100,
            "Invalid share partition"
        );
        payees = [msg.sender, _receiver];
        shares = [fee.creatorRoyaltyFee, fee.clientRoyaltyFee];
        SplitterContract paymentSplitter = new SplitterContract(payees, shares);

        address beaconProxy = _deployLazyMintProxy(
            _getLazyMintERC721Data(
                collectionName,
                collectionSymbol,
                collectionDescription,
                fee.royaltyFee,
                fee.platformFee,
                admin,
                address(this),
                address(paymentSplitter)
            ),
            salt,
            tokenTypes.lazyMintERC721
        );
        LazyMintERC721Token token = LazyMintERC721Token(address(beaconProxy));
        userCreatedCollections[msg.sender].push(address(token));
        allCollectionsRegulated.push(address(token));
        emit CreatedPaymentSplitter(address(paymentSplitter));
        emit CreatedLazyMintERC721(address(token), _receiver, _collectionAttributes, true, lazyMintUris);
        token.transferOwnership(msg.sender);
        collectionAttributes[address(token)] = _collectionAttributes;
    }

    /**
     * @dev Creates an ERC721 token.
     *
     * @param collectionName name of the collection
     * @param collectionSymbol symbol of the collection
     * @param _receiver royalty receiver address
     *
     * Emits {CreatedERC721} event indicating the token address.
     * Emits {CreatedPaymentSplitter} event.
     */
    function createERC721CollectionUnregulated(
        string memory collectionName,
        string memory collectionSymbol,
        string memory collectionDescription,
        address _receiver,
        string[] memory _collectionAttributes
    ) external whenNotPaused nonReentrant {
        require(accessControl.whitelisted(msg.sender), "Account not whitelisted");
        uint256 salt = _saltValue.current();
        _saltValue.increment();

        FeeStruct memory fee = getFees(_receiver, false);
        require(
            (fee.creatorRoyaltyFee + fee.clientRoyaltyFee) == 100,
            "Invalid share partition"
        );
        payees = [msg.sender, _receiver];
        shares = [fee.creatorRoyaltyFee, fee.clientRoyaltyFee];
        SplitterContract paymentSplitter = new SplitterContract(payees, shares);

        address beaconProxy = _deployProxy(
            _getERC721Data(
                collectionName,
                collectionSymbol,
                collectionDescription,
                fee.royaltyFee,
                fee.platformFee,
                admin,
                address(this),
                address(paymentSplitter)
            ),
            salt,
            tokenTypes.ERC721
        );
        ERC721Token token = ERC721Token(address(beaconProxy));
        userCreatedCollections[msg.sender].push(address(token));
        allCollectionsUnregulated.push(address(token));
        emit CreatedPaymentSplitter(address(paymentSplitter));
        emit CreatedERC721(address(token), _receiver, _collectionAttributes, false);
        token.transferOwnership(msg.sender);
        collectionAttributes[address(token)] = _collectionAttributes;
    }

    /**
     * @dev Creates an LazyMintERC721 token.
     *
     * @param collectionName name of the collection
     * @param collectionSymbol symbol of the collection
     * @param _receiver royalty receiver address
     *
     * Emits {CreatedLazyMintERC721} event indicating the token address.
     * Emits {CreatedPaymentSplitter} event.
     */
    function createLazyMintERC721CollectionUnregulated(
        string memory collectionName,
        string memory collectionSymbol,
        string memory collectionDescription,
        address _receiver,
        string[] memory _collectionAttributes,
        string[] memory lazyMintUris
    ) external whenNotPaused nonReentrant {
        require(accessControl.whitelisted(msg.sender), "Account not whitelisted");
        uint256 salt = _saltValue.current();
        _saltValue.increment();

        FeeStruct memory fee = getFees(_receiver, false);
        require(
            (fee.creatorRoyaltyFee + fee.clientRoyaltyFee) == 100,
            "Invalid share partition"
        );
        payees = [msg.sender, _receiver];
        shares = [fee.creatorRoyaltyFee, fee.clientRoyaltyFee];
        SplitterContract paymentSplitter = new SplitterContract(payees, shares);

        address beaconProxy = _deployLazyMintProxy(
            _getLazyMintERC721Data(
                collectionName,
                collectionSymbol,
                collectionDescription,
                fee.royaltyFee,
                fee.platformFee,
                admin,
                address(this),
                address(paymentSplitter)
            ),
            salt,
            tokenTypes.lazyMintERC721
        );
        LazyMintERC721Token token = LazyMintERC721Token(address(beaconProxy));
        userCreatedCollections[msg.sender].push(address(token));
        allCollectionsUnregulated.push(address(token));
        emit CreatedPaymentSplitter(address(paymentSplitter));
        emit CreatedLazyMintERC721(address(token), _receiver, _collectionAttributes, false, lazyMintUris);
        token.transferOwnership(msg.sender);
        collectionAttributes[address(token)] = _collectionAttributes;
    }

    /**
     * @dev Sets the `_collectionAttributes` for the `collection` created by `account`
     * @param collection collection address
     * @param _collectionAttributes collection attributes array
     *
     * Emits {SetCollectionAttributes} event.
     *
     * Requirements:
     *
     * - `collection` address should not be zero address
     */
    function setCollectionAttributes(
        address collection,
        string[] memory _collectionAttributes
    ) external whenNotPaused nonReentrant {
        require(
            collection != address(0),
            "Cant be zero address"
        );
        collectionAttributes[collection] = _collectionAttributes;
        emit SetCollectionAttributes(
            collection,
            _collectionAttributes
        );
    }

    /**
     * @dev Sets `collection` as destroyed
     * @param collection address of collection
     *
     * Emits {CollectionDestroyed} event
     */
    function setCollectionIsDestroyed(address collection) external whenNotPaused nonReentrant {
        require(
            msg.sender == collection,
            "Caller has no access to destroy collection"
        );
        isCollectionDestroyed[collection] = true;
        emit CollectionDestroyed(collection);
    }

    /**
     * @dev Sets regulated fee percentage
     * @param _platformFee.
     * @param _royaltyFee.
     * @param _creatorRoyaltyFee.
     * @param _clientRoyaltyFee.
     *
     * Emits {SetRegulatedFee} event
     */
    function setRegulatedFees(
        uint16 _platformFee, 
        uint16 _royaltyFee, 
        uint8 _creatorRoyaltyFee, 
        uint8 _clientRoyaltyFee
    ) public onlyOwner whenNotPaused {
        require(_royaltyFee > 0, "Royalty Fee must be greater than zero");
        regulatedFees = FeeStruct(_platformFee, _royaltyFee, _creatorRoyaltyFee, _clientRoyaltyFee);
        emit SetRegulatedFee(regulatedFees);
    }

    /**
     * @dev Sets unregulated fee percentage
     * @param _platformFee.
     * @param _royaltyFee.
     * @param _creatorRoyaltyFee.
     * @param _clientRoyaltyFee.
     *
     * Emits {SetUnregulatedFee} event
     */
    function setUnregulatedFees(
        uint16 _platformFee, 
        uint16 _royaltyFee, 
        uint8 _creatorRoyaltyFee, 
        uint8 _clientRoyaltyFee
    ) public onlyOwner whenNotPaused {
        require(_royaltyFee > 0, "Royalty Fee must be greater than zero");
        unRegulatedFees = FeeStruct(_platformFee, _royaltyFee, _creatorRoyaltyFee, _clientRoyaltyFee);
        emit SetUnregulatedFee(unRegulatedFees);
    }

    /**
     * @dev Sets partner related fee percentage
     * @param partner.
     * @param _platformFee.
     * @param _royaltyFee.
     * @param _creatorRoyaltyFee.
     * @param _clientRoyaltyFee.
     * @param _usePartnerFee.
     *
     * Emits {PartnerFeesUpdated} event
     */
    function setPartnerFees(
        address partner, 
        uint16 _platformFee, 
        uint16 _royaltyFee, 
        uint8 _creatorRoyaltyFee, 
        uint8 _clientRoyaltyFee, 
        bool _usePartnerFee
    ) external onlyOwner whenNotPaused {
        PartnerFee storage fees = partnerFee[partner];
        fees.platformFee = _platformFee;
        fees.royaltyFee = _royaltyFee;
        fees.creatorRoyaltyFee = _creatorRoyaltyFee;
        fees.clientRoyaltyFee = _clientRoyaltyFee;
        fees.usePartnerFee = _usePartnerFee;
        emit PartnerFeesUpdated(fees);
    }

    /**
     * @dev Update beacon address by owner.
     *
     * @param erc721BeaconAddress.
     *
     * Emits a {UpdatedBeacon} event.
     */
    function updateBeacon(address erc721BeaconAddress) external onlyOwner {
        require(
            erc721BeaconAddress != address(0),
            "Factory: Cant be zero address"
        );
        erc721Beacon = erc721BeaconAddress;
        emit UpdatedBeacon(erc721Beacon);
    }

     /**
     * @dev Update beacon address by owner.
     *
     * @param lazyMintErc721BeaconAddress.
     *
     * Emits a {UpdatedBeacon} event.
     */
    function updateLazyMintBeacon(address lazyMintErc721BeaconAddress) external onlyOwner {
        require(
            lazyMintErc721BeaconAddress != address(0),
            "Factory: Cant be zero address"
        );
        lazyMintErc721Beacon = lazyMintErc721BeaconAddress;
        emit UpdatedLazyMintBeacon(lazyMintErc721Beacon);
    }

    /**
     * @dev Update beacon proxy address by owner.
     *
     * @param erc721BeaconProxyAddress.
     *
     * Emits a {UpdatedBeaconProxy} event.
     */
    function updateBeaconProxy(address erc721BeaconProxyAddress) external onlyOwner {
        require(
            erc721BeaconProxyAddress != address(0),
            "Factory: Cant be zero address"
        );
        ERC721 = erc721BeaconProxyAddress;
        emit UpdatedBeaconProxy(ERC721);
    }

     /**
     * @dev Update beacon proxy address by owner.
     *
     * @param lazyMintErc721BeaconProxyAddress.
     *
     * Emits a {UpdatedBeaconProxy} event.
     */
    function updateLazyMintBeaconProxy(address lazyMintErc721BeaconProxyAddress) external onlyOwner {
        require(
            lazyMintErc721BeaconProxyAddress != address(0),
            "Factory: Cant be zero address"
        );
        lazyMintERC721 = lazyMintErc721BeaconProxyAddress;
        emit UpdatedLazyMintBeaconProxy(lazyMintERC721);
    }

    /**
     * @dev withdraw native currency from factory only by owner
     * Emits a {WithdrawNativeFromFactory} event.
     */
    function withdrawNativeFromFactory() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
        emit WithdrawNativeFromFactory(msg.sender, address(this).balance);
    }

    /**
     * @dev Pause the contract (stopped state)
     * by caller with PAUSER_ROLE.
     *
     * Emits a {Paused} event.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract (normal state)
     * by caller with OWNER ONLY.
     *
     * Emits a {Unpaused} event.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Returns the attributes of `collection` created by `account`
     * @param collection collection address
     */
    function getCollectionAttributes(address collection) external view returns (string[] memory) {
        return collectionAttributes[collection];
    }

    /**
     * @dev Returns user created collections
     */
    function getUserCreatedCollections(address user) external view returns (address[] memory) {
        return userCreatedCollections[user];
    }

    /**
     * @dev Returns all created collections through this contract
     */
    function getAllCollectionsRegulated() external view returns (address[] memory) {
        return allCollectionsRegulated;
    }

    /**
     * @dev Returns all created collections through this contract
     */
    function getAllCollectionsUnregulated() external view returns (address[] memory) {
        return allCollectionsUnregulated;
    }

    /**
     * @dev Function to update the minter address (only callable by the owner)
     */
    function updateMinter(address newMinter) public onlyOwner {
        // Ensure the new minter address is not zero
        require(newMinter != address(0), "Minter cannot be zero address");
        // Update the minter address
        minter = newMinter;
    }

    /**
     * @dev Returns fee
     */
    function getFees(address partner, bool isRegulated) public view returns (FeeStruct memory) {
        PartnerFee memory partnerFees = partnerFee[partner];
        if(partnerFees.usePartnerFee) {
            FeeStruct memory fee = FeeStruct(partnerFees.platformFee, partnerFees.royaltyFee, partnerFees.creatorRoyaltyFee, partnerFees.clientRoyaltyFee);
            return fee; 
        } else { 
            if(isRegulated) return regulatedFees;
            else return unRegulatedFees; 
        }
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     * Sets the admin to `newOwner`
     *
     * Requirements:
     *
     * - `newOwner` should not be zero address.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner whenNotPaused {
        require(
            newOwner != address(0),
            "Cant be zero address"
        );
        admin = newOwner;
        _transferOwnership(newOwner);
    }

    /**
     * @dev Returns address of the collection with provided arguments
     *
     * @param collectionName.
     * @param collectionSymbol.
     * @param collectionDescription.
     * @param salt unique random value
     * @param _feeNumerator royalty percentage (if _feeNumerator is given as 100, it means 1% royalty)
     * @param _platformFee.
     * @param _admin admin wallet address
     * @param _factory address of NFT Collection contract
     * @param paymentSplitter contract address
     */
    function getERC721Address(
        string memory collectionName,
        string memory collectionSymbol,
        string memory collectionDescription,
        uint256 salt,
        uint96 _feeNumerator,
        uint256 _platformFee,
        address _admin,
        address _factory,
        address paymentSplitter
    ) public view returns (address) {
        bytes memory bytecode = _getCreationBytecode(
            _getERC721Data(
                collectionName,
                collectionSymbol,
                collectionDescription,
                _feeNumerator,
                _platformFee,
                _admin,
                _factory,
                paymentSplitter
            ),
            tokenTypes.ERC721
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }

        /**
     * @dev Returns address of the collection with provided arguments
     *
     * @param collectionName.
     * @param collectionSymbol.
     * @param collectionDescription.
     * @param salt unique random value
     * @param _feeNumerator royalty percentage (if _feeNumerator is given as 100, it means 1% royalty)
     * @param _platformFee.
     * @param _admin admin wallet address
     * @param _factory address of NFT Collection contract
     * @param paymentSplitter contract address
     */
    function getLazyMintERC721Address(
        string memory collectionName,
        string memory collectionSymbol,
        string memory collectionDescription,
        uint256 salt,
        uint96 _feeNumerator,
        uint256 _platformFee,
        address _admin,
        address _factory,
        address paymentSplitter
    ) public view returns (address) {
        bytes memory bytecode = _getCreationLazyMintBytecode(
            _getLazyMintERC721Data(
                collectionName,
                collectionSymbol,
                collectionDescription,
                _feeNumerator,
                _platformFee,
                _admin,
                _factory,
                paymentSplitter
            ),
            tokenTypes.lazyMintERC721
        );

        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );

        return address(uint160(uint256(hash)));
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Deploying BeaconProxy contract with create2
     * @param data.
     * @param salt unique random value
     * @param tokenType type of token (ERC721)
     */
    function _deployProxy(
        bytes memory data,
        uint256 salt,
        tokenTypes tokenType
    ) internal returns (address proxy) {
        bytes memory bytecode = _getCreationBytecode(data, tokenType);
        assembly {
            proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(proxy)) {
                revert(0, 0)
            }
        }
    }

     function _deployLazyMintProxy(
        bytes memory data,
        uint256 salt,
        tokenTypes tokenType
    ) internal returns (address proxy) {
        bytes memory bytecode = _getCreationLazyMintBytecode(data, tokenType);
        assembly {
            proxy := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(proxy)) {
                revert(0, 0)
            }
        }
    }

    /**
     * @dev adding constructor arguments to bytecode
     *
     * @param collectionName.
     * @param collectionSymbol.
     * @param collectionDescription.
     * @param _feeNumerator royalty percentage (if _feeNumerator is given as 100, it means 1% royalty)
     * @param _platformFee.
     * @param _admin admin wallet address
     * @param _factory address of NFT Collection contract
     * @param paymentSplitter contract address
     */
    function _getERC721Data(
        string memory collectionName,
        string memory collectionSymbol,
        string memory collectionDescription,
        uint96 _feeNumerator,
        uint256 _platformFee,
        address _admin,
        address _factory,
        address paymentSplitter
    ) internal view returns (bytes memory) {
        return
            abi.encodeWithSelector(
                ERC721Token(address(ERC721)).initialize.selector,
                collectionName,
                collectionSymbol,
                collectionDescription,
                _feeNumerator,
                _platformFee,
                _admin,
                _factory,
                paymentSplitter
            );
    }

    /**
     * @dev adding constructor arguments to bytecode
     *
     * @param collectionName.
     * @param collectionSymbol.
     * @param collectionDescription.
     * @param _feeNumerator royalty percentage (if _feeNumerator is given as 100, it means 1% royalty)
     * @param _platformFee.
     * @param _admin admin wallet address
     * @param _factory address of NFT Collection contract
     * @param paymentSplitter contract address
     */
    function _getLazyMintERC721Data(
        string memory collectionName,
        string memory collectionSymbol,
        string memory collectionDescription,
        uint96 _feeNumerator,
        uint256 _platformFee,
        address _admin,
        address _factory,
        address paymentSplitter
    ) internal view returns (bytes memory) {
        return
            abi.encodeWithSelector(
                LazyMintERC721Token(address(lazyMintERC721)).initialize.selector,
                collectionName,
                collectionSymbol,
                collectionDescription,
                _feeNumerator,
                _platformFee,
                _admin,
                _factory,
                paymentSplitter,
                minter
            );
    }

    /**
     * @dev Adding constructor arguments to BeaconProxy bytecode
     * @param data ERC721 data
     * @param tokenType type of token (ERC721)
     */
    function _getCreationBytecode(
        bytes memory data,
        tokenTypes tokenType
    ) internal view returns (bytes memory) {
        address beacon;
        if (
            keccak256(abi.encodePacked(tokenType)) ==
            keccak256(abi.encodePacked(tokenTypes.ERC721))
        ) {
            beacon = erc721Beacon;
        }
        return
            abi.encodePacked(
                type(BeaconProxy).creationCode,
                abi.encode(beacon, data)
            );
    }

     /**
     * @dev Adding constructor arguments to BeaconProxy bytecode
     * @param data ERC721 data
     * @param tokenType type of token (ERC721)
     */
    function _getCreationLazyMintBytecode(
        bytes memory data,
        tokenTypes tokenType
    ) internal view returns (bytes memory) {
        address beacon;
        if (
            keccak256(abi.encodePacked(tokenType)) ==
            keccak256(abi.encodePacked(tokenTypes.lazyMintERC721))
        ) {
            beacon = lazyMintErc721Beacon;
        }
        return
            abi.encodePacked(
                type(BeaconProxy).creationCode,
                abi.encode(beacon, data)
            );
    }

    /**
     * @dev Overriding renounce ownership as functionality not needed
     */
    function renounceOwnership() public virtual override onlyOwner whenNotPaused {}
}
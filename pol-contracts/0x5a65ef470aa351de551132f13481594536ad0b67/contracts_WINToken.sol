// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./openzeppelin_contracts_token_ERC1155_ERC1155.sol";
import "./openzeppelin_contracts_access_AccessControl.sol";

import "./openzeppelin_contracts_token_common_ERC2981.sol";

import "./contracts_WINUsersWhitelist.sol";
import "./contracts_WINTokenProductsConfig.sol";
import "./contracts_RoyaltiesEscrow.sol";
import "./contracts_PurchasesEscrow.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// WINProduct
contract WINToken is ERC1155, ERC2981, AccessControl {
    struct RoyaltyBeneficiary {
        address account;
        uint96 percentage;
    }

    bytes32 public constant OWNER_ADMIN = keccak256("OWNER_ADMIN");
    bytes32 public constant FACTORY_ADMIN = keccak256("FACTORY_ADMIN");

    WINUsersWhitelist public whitelistContract;
    WINTokenProductsConfig public productConfigContract;
    PurchasesEscrow public purchasesEscrowContract;

    string public name;
    string public symbol;

    mapping(uint256 => string) public productName;
    mapping(uint256 => uint256) public productCurrentSupply;

    mapping(uint256 => RoyaltyBeneficiary[]) private royaltiesByToken;
    mapping(uint256 => uint96) public totalRoyaltiesByToken;
    mapping(uint256 => RoyaltiesEscrow) public escrowByToken;

    /* Events */
    event CreatedWINToken(
        address indexed WINToken,
        string name,
        WINUsersWhitelist whitelistContract,
        WINTokenProductsConfig productConfigContract,
        PurchasesEscrow purchasesEscrowContract,
        string baseURI
    );

    event UpdatedWINTokenBaseURI(address indexed WINToken, string baseURI);

    event UpdatedWINTokenContracts(
        address indexed WINToken,
        WINUsersWhitelist whitelistContract,
        WINTokenProductsConfig productConfigContract,
        PurchasesEscrow purchasesEscrowContract
    );

    event CreatedWINTokenProduct(
        address indexed WINToken,
        uint256 indexed id,
        string name,
        uint256 maxSupply
    );

    event CreatedWINTokenToken(
        address indexed WINToken,
        address indexed wallet,
        uint256 indexed productId,
        uint256 amount
    );

    event BurnedWINToken(
        address indexed WINToken,
        address indexed _walletFrom,
        uint indexed productId,
        uint amount
    );

    /* Functions */
    /**
     *
     * @param _baseURI default base metadata uri
     * @param _whitelistContract address of the whitelist contract
     * @param _productConfigContract address of the product config contract
     * @param _purchasesEscrowContract address of the purchases contract
     * @param _name token name
     * @param _symbol token symbol
     */
    constructor(
        string memory _baseURI,
        WINUsersWhitelist _whitelistContract,
        WINTokenProductsConfig _productConfigContract,
        PurchasesEscrow _purchasesEscrowContract,
        string memory _name,
        string memory _symbol
    ) ERC1155(_baseURI) notEmptyString(_baseURI) {
        whitelistContract = _whitelistContract;
        productConfigContract = _productConfigContract;
        purchasesEscrowContract = _purchasesEscrowContract;
        name = _name;
        symbol = _symbol;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        emit CreatedWINToken(
            address(this),
            name,
            whitelistContract,
            productConfigContract,
            purchasesEscrowContract,
            _baseURI
        );
    }

    function getRoyalties(
        uint256 _tokenId
    ) public view returns (RoyaltyBeneficiary[] memory) {
        return royaltiesByToken[_tokenId];
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC1155, ERC2981, AccessControl)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function createProduct(
        uint256 _id,
        string memory _name,
        uint256 _maxSupply,
        address[] memory royaltyAddresses,
        uint96[] memory royaltyPercentages
    ) external productNotExist(_id) notEmptyString(_name) {
        require(
            hasRole(FACTORY_ADMIN, msg.sender),
            "Restricted to FACTORY_ADMIN role"
        );
        require(_maxSupply > 0, "Max supply must be bigger than 0");

        productName[_id] = _name;
        productConfigContract.editMaxSupply(_id, _maxSupply);

        uint96 totalRoyaltyPercentage = 0;

        delete royaltiesByToken[_id];

        for (uint i = 0; i < royaltyAddresses.length; i++) {
            address royaltyAddress = royaltyAddresses[i];
            uint96 royaltyPercentage = royaltyPercentages[i];

            totalRoyaltyPercentage += royaltyPercentage;

            royaltiesByToken[_id].push(
                RoyaltyBeneficiary(royaltyAddress, royaltyPercentage)
            );
        }

        RoyaltiesEscrow tokenEscrow = new RoyaltiesEscrow(this, _id);

        escrowByToken[_id] = tokenEscrow;

        totalRoyaltiesByToken[_id] = totalRoyaltyPercentage;

        _setTokenRoyalty(_id, address(tokenEscrow), totalRoyaltyPercentage);

        emit CreatedWINTokenProduct(address(this), _id, _name, _maxSupply);
    }

    function editProductRoyalties(
        uint256 _id,
        address[] memory royaltyAddresses,
        uint96[] memory royaltyPercentages
    ) external productExist(_id) {
        require(
            hasRole(FACTORY_ADMIN, msg.sender),
            "Restricted to FACTORY_ADMIN role"
        );

        uint96 totalRoyaltyPercentage = 0;

        delete royaltiesByToken[_id];

        for (uint i = 0; i < royaltyAddresses.length; i++) {
            address royaltyAddress = royaltyAddresses[i];
            uint96 royaltyPercentage = royaltyPercentages[i];

            totalRoyaltyPercentage += royaltyPercentage;

            royaltiesByToken[_id].push(
                RoyaltyBeneficiary(royaltyAddress, royaltyPercentage)
            );
        }

        totalRoyaltiesByToken[_id] = totalRoyaltyPercentage;

        _setTokenRoyalty(
            _id,
            address(escrowByToken[_id]),
            totalRoyaltyPercentage
        );
    }

    function grantEscrowRole(
        uint256 _id,
        address account
    ) external productExist(_id) {
        require(
            hasRole(FACTORY_ADMIN, msg.sender),
            "Restricted to FACTORY_ADMIN role"
        );

        escrowByToken[_id].grantRole(
            escrowByToken[_id].ESCROW_ADMIN(),
            account
        );
    }

    function revokeEscrowRole(
        uint256 _id,
        address account
    ) external productExist(_id) {
        require(
            hasRole(FACTORY_ADMIN, msg.sender),
            "Restricted to FACTORY_ADMIN role"
        );

        escrowByToken[_id].revokeRole(
            escrowByToken[_id].ESCROW_ADMIN(),
            account
        );
    }

    function generateToken(
        address to,
        uint256 _productId,
        uint256 _amount,
        address _erc20Token
    ) external payable productExist(_productId) {
        productConfigContract.requireNotFull(
            productCurrentSupply[_productId],
            _productId,
            _amount
        );

        productConfigContract.requireActive(_productId);

        require(
            address(whitelistContract) == address(0) ||
                whitelistContract.getWhitelistStatus(to),
            "_wallet is not in whitelist"
        );

        productCurrentSupply[_productId] += _amount;

        uint256 payment = purchasesEscrowContract.productPrice(
            _productId,
            _erc20Token
        ) * _amount;

        if (_erc20Token != address(0)) {
            bool transferred = ERC20(_erc20Token).transferFrom(
                msg.sender,
                address(purchasesEscrowContract),
                payment
            );

            require(transferred, "Failed to transfer erc20");
        }

        purchasesEscrowContract.deposit{value: msg.value}(
            _erc20Token,
            payment,
            msg.sender,
            _productId,
            _amount,
            productCurrentSupply[_productId]
        );

        _mint(to, _productId, _amount, "");

        emit CreatedWINTokenToken(address(this), to, _productId, _amount);
    }

    function safeTransferFrom(
        address _walletFrom,
        address _walletTo,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        require(
            address(whitelistContract) == address(0) ||
                whitelistContract.getWhitelistStatus(_walletFrom),
            "_walletFrom is not in whitelist"
        );
        require(
            address(whitelistContract) == address(0) ||
                whitelistContract.getWhitelistStatus(_walletTo),
            "_walletTo is not in whitelist"
        );
        require(_walletTo != address(0), "_walletTo can't be the zero address");
        super.safeTransferFrom(_walletFrom, _walletTo, id, amount, data);
    }

    function safeBatchTransferFrom(
        address _walletFrom,
        address _walletTo,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        require(
            address(whitelistContract) == address(0) ||
                whitelistContract.getWhitelistStatus(_walletFrom),
            "_walletFrom is not in whitelist"
        );
        require(
            address(whitelistContract) == address(0) ||
                whitelistContract.getWhitelistStatus(_walletTo),
            "_walletTo is not in whitelist"
        );
        require(_walletTo != address(0), "_walletTo can't be the zero address");
        super.safeBatchTransferFrom(_walletFrom, _walletTo, ids, amounts, data);
    }

    function burn(address _walletFrom, uint256 id, uint256 amount) public {
        require(
            hasRole(FACTORY_ADMIN, msg.sender) ||
                hasRole(OWNER_ADMIN, msg.sender),
            "Restricted to FACTORY_ADMIN or OWNER_ADMIN role"
        );

        super._burn(_walletFrom, id, amount);

        productCurrentSupply[id] -= amount;

        emit BurnedWINToken(address(this), _walletFrom, id, amount);
    }

    /* Setters */

    function setURI(string memory _newURI) external notEmptyString(_newURI) {
        require(
            hasRole(FACTORY_ADMIN, msg.sender),
            "Restricted to FACTORY_ADMIN role"
        );

        _setURI(_newURI);

        emit UpdatedWINTokenBaseURI(address(this), _newURI);
    }

    function setContracts(
        WINUsersWhitelist _newWhitelistContract,
        WINTokenProductsConfig _newProductConfigContract,
        PurchasesEscrow _newPurchasesEscrowContract
    ) external {
        require(
            hasRole(FACTORY_ADMIN, msg.sender),
            "Restricted to FACTORY_ADMIN role"
        );
        require(
            address(_newProductConfigContract) != address(0),
            "Missing product config contract"
        );
        require(
            address(_newPurchasesEscrowContract) != address(0),
            "Missing purchases escrow contract"
        );

        whitelistContract = _newWhitelistContract;
        productConfigContract = _newProductConfigContract;
        purchasesEscrowContract = _newPurchasesEscrowContract;

        emit UpdatedWINTokenContracts(
            address(this),
            _newWhitelistContract,
            _newProductConfigContract,
            _newPurchasesEscrowContract
        );
    }

    function uri(
        uint256 _productId
    ) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    super.uri(_productId),
                    Strings.toString(_productId)
                )
            );
    }

    modifier notEmptyString(string memory _string) {
        bytes memory stringToCheck = bytes(_string);
        require(stringToCheck.length > 0, "String can't be empty");
        _;
    }

    modifier productExist(uint256 _id) {
        bytes memory productNameBytes = bytes(productName[_id]);
        require(productNameBytes.length > 0, "Product does not exist");
        _;
    }

    modifier productNotExist(uint256 _id) {
        bytes memory productNameBytes = bytes(productName[_id]);
        require(productNameBytes.length == 0, "Product already exists");
        _;
    }
}
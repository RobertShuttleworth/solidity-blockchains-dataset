// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./openzeppelin_contracts_token_ERC1155_ERC1155.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_utils_Strings.sol";
import "./openzeppelin_contracts_utils_Base64.sol";
import "./contracts_utils_GlobalMarker.sol";
import "./contracts_utils_InterestModel.sol";
import "./contracts_cfa_interface_ILockedSavings.sol";
import "./contracts_token_Bean.sol";
import "./contracts_utils_Registry.sol";
import "./contracts_cfa_Referral.sol";

contract LockedSavings is ILockedSavings, ERC1155, Ownable, ReentrancyGuard {
    using Strings for uint256;

    /**
     *  LocaL Variables
     */

    Registry public registry;
    System public system;
    Metadata public metadata; // The metadata of the Savings CFA
    string public contractUri; // The contract URI
    string public name; // The name of the Savings CFA for ERC1155
    string public symbol; // The symbol of the Savings CFA for ERC1155

    mapping(uint256 => Attributes) public attributes;

    /**
     * Events
     */

    event LockedSavingsCreated(Attributes _attributes);
    event ContractURIUpdated();
    event UpdateNameEvent(string oldName, string newName);
    event UpdateSymbolEvent(string oldSymbol, string newSymbol);

    /**
     * Constructor
     */

    constructor() ERC1155("") Ownable(msg.sender) {
        system.idCounter = 1;
    }

    /**
     * Main Functions
     */

    function mintLockedSavings(
        uint256 _principal,
        uint256 _multiplier,
        uint256 _qty,
        address _referrer
    ) external nonReentrant {
        uint256 currMarker = GlobalMarker(
            registry.getContractAddress("GlobalMarker")
        ).getMarker();
        require(
            _principal <= 99999000000000000000000 &&
                _principal >= 10000000000000,
            "LockedSavings: Invalid Principal"
        );
        require(currMarker <= 100, "LockedSavings: Beyond Max Marker");
        Bean token = Bean(registry.getContractAddress("Bean"));
        require(
            token.totalSupply() < 21000000000 ether,
            "Savings: Max Supply Reached"
        );
        if (_referrer != address(0)) {
            Referral(registry.getContractAddress("Referral")).addReferrer(
                msg.sender,
                _referrer
            );
        }
        Referral referral = Referral(registry.getContractAddress("Referral"));
        for (uint256 i = 0; i < _qty; i++) {
            if ((referral.eligibleForReward(msg.sender))) {
                referral.rewardForReferrer(msg.sender, _principal);
                uint256 discount = referral.getReferredDiscount();
                attributes[system.idCounter].discountGiven = discount;
                uint256 amtPayable = _principal -
                    ((_principal * discount) / 10000);
                uint256 discounted = ((_principal * discount) / 10000);
                token.mint(address(this), discounted);
                token.transferFrom(msg.sender, address(this), amtPayable);
            } else {
                token.transferFrom(msg.sender, address(this), _principal);
            }
            uint256 marker = GlobalMarker(
                registry.getContractAddress("GlobalMarker")
            ).getMarker();

            uint256 lifeBasedOnMult = InterestRateModel(
                registry.getContractAddress("InterestRateModel")
            ).lockedSavingsTable(_multiplier, marker);

            require(
                lifeBasedOnMult != 0,
                "LockedSavings: Invalid Multiplier, or Marker has passed"
            );

            attributes[system.idCounter].marker = marker;
            attributes[system.idCounter].timeCreated = block.timestamp;
            attributes[system.idCounter].cfaLife =
                block.timestamp +
                (lifeBasedOnMult * 30 days);
            attributes[system.idCounter].principal = _principal;
            attributes[system.idCounter].multiplier = _multiplier;

            token.mint(address(this), (_principal * _multiplier) - _principal);
            _mint(msg.sender, system.idCounter, 1, "");
            emit LockedSavingsCreated(attributes[system.idCounter]);
            system.idCounter++;
            system.totalActiveCfa++;
        }
    }

    function withdrawLockedSavings(uint256 _id) external nonReentrant {
        require(
            balanceOf(msg.sender, _id) == 1,
            "LockedSavings: You do not own this CFA"
        );
        require(
            block.timestamp >= attributes[_id].cfaLife,
            "LockedSavings: CFA is still locked"
        );

        uint256 total = attributes[_id].principal * attributes[_id].multiplier;

        Bean token = Bean(registry.getContractAddress("Bean"));
        token.transfer(msg.sender, total);
        token.addTotalRewarded(total, msg.sender);

        _burn(msg.sender, _id, 1);
        system.totalActiveCfa--;
    }

    /**
     * Write Functions
     */
    function setRegistry(address _registry) external onlyOwner {
        registry = Registry(_registry);
    }

    function setContractUri(string memory _uri) external onlyOwner {
        contractUri = _uri;
        emit ContractURIUpdated();
    }

    function setMetadata(
        string memory _name,
        string memory _description
    ) external onlyOwner {
        metadata.name = _name;
        metadata.description = _description;
    }

    function setImage(string memory _image) external onlyOwner {
        metadata.image = _image;
    }

    function setName(string memory _name) external onlyOwner {
        emit UpdateNameEvent(name, _name);
        name = _name;
    }

    function setSymbol(string memory _symbol) external onlyOwner {
        emit UpdateSymbolEvent(symbol, _symbol);
        symbol = _symbol;
    }

    /**
     * Read Functions
     */

    function getTotalActiveCfa() external view returns (uint256) {
        return system.totalActiveCfa;
    }

    /**
     * Metadata Getters
     */

    function formatEther(
        uint256 amountInWei
    ) public pure returns (string memory) {
        uint256 wholePart = amountInWei / 1 ether;
        uint256 decimalPart = (amountInWei / 10000000000000000) % 100;
        if (decimalPart == 0) {
            return wholePart.toString();
        }
        string memory decimalStr = decimalPart < 10
            ? string(abi.encodePacked("0", decimalPart.toString())) // Add leading zero if needed
            : decimalPart.toString();

        return string(abi.encodePacked(wholePart.toString(), ".", decimalStr));
    }

    function contractURI() public view returns (string memory) {
        return string.concat("data:application/json;utf8,", contractUri);
    }

    function getMetadata(uint256 _tokenId) public view returns (string memory) {
        string memory basicInfo = getBasicInfo(_tokenId);
        string memory firstHalfAttributes = getFirstHalfAttributes(_tokenId);
        string memory secondHalfAttributes = getSecondHalfAttributes(_tokenId);

        return
            string(
                abi.encodePacked(
                    "{",
                    basicInfo,
                    firstHalfAttributes,
                    secondHalfAttributes,
                    "]}"
                )
            );
    }

    function formatDiscount(
        uint256 discount
    ) public pure returns (string memory) {
        if (discount < 100) {
            return string(abi.encodePacked("0.", discount.toString()));
        } else {
            return string(abi.encodePacked((discount / 100).toString()));
        }
    }

    function getFirstHalfAttributes(
        uint256 _tokenId
    ) internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '{ "trait_type": "Creation Date", "display_type": "date", "value": "',
                    attributes[_tokenId].timeCreated.toString(),
                    '" },',
                    '{ "trait_type": "Maturity Date", "display_type": "date", "value": "',
                    attributes[_tokenId].cfaLife.toString(),
                    '" },',
                    '{ "trait_type": "Earnings Total", "value": "',
                    formatEther(
                        (attributes[_tokenId].principal *
                            attributes[_tokenId].multiplier)
                    ),
                    '" },'
                    '{ "trait_type": "Discount Given (%)", "value": "',
                    formatDiscount(attributes[_tokenId].discountGiven),
                    '" },'
                )
            );
    }

    function getSecondHalfAttributes(
        uint256 _tokenId
    ) internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '{ "trait_type": "Principal", "value": "',
                    formatEther(attributes[_tokenId].principal),
                    '" },',
                    '{ "trait_type": "Interest Return", "value": "',
                    formatEther(
                        (attributes[_tokenId].principal *
                            attributes[_tokenId].multiplier) -
                            attributes[_tokenId].principal
                    ),
                    '" },',
                    '{ "trait_type": "Multiplier", "value": "',
                    attributes[_tokenId].multiplier.toString(),
                    'x" }'
                )
            );
    }

    function getBasicInfo(
        uint256 _tokenId
    ) internal view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '"name":"',
                    metadata.name,
                    Strings.toString(_tokenId),
                    '",',
                    '"description":"',
                    metadata.description,
                    '",',
                    '"image":"',
                    metadata.image,
                    '",',
                    '"attributes": ['
                )
            );
    }

    /**
     * Override Functions
     */

    function uri(
        uint256 _tokenId
    ) public view virtual override returns (string memory) {
        bytes memory _metadata = abi.encodePacked(getMetadata(_tokenId));

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(_metadata)
                )
            );
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override {
        revert("LockedSavings: Transfers are disabled");
    }

    function safeBatchTransferFrom(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override {
        revert("LockedSavings: Batch transfers are disabled");
    }
}
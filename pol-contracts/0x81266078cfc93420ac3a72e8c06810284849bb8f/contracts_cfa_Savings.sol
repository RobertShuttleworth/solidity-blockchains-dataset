// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./openzeppelin_contracts_token_ERC1155_ERC1155.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_utils_Strings.sol";
import "./openzeppelin_contracts_utils_Base64.sol";
import "./contracts_cfa_interface_ISavings.sol";
import "./contracts_cfa_Referral.sol";
import "./contracts_utils_Registry.sol";
import "./contracts_utils_GlobalMarker.sol";
import "./contracts_utils_InterestModel.sol";

contract Savings is ISavings, ERC1155, Ownable, ReentrancyGuard {
    using Strings for uint256;

    /**
     * Local variables
     */
    System public system;
    Referral public referral; // Referral contract
    Registry public registry; // The registry contract
    Metadata public metadata; // The metadata of the Savings CFA
    string public contractUri; // The contract URI
    string public name; // The name of the Savings CFA for ERC1155
    string public symbol; // The symbol of the Savings CFA for ERC1155

    mapping(uint256 => Loan) public loan;
    mapping(uint256 => Attributes) public attributes;

    /**
     * Events
     */
    event SavingsCreated(Attributes _attribute);
    event SavingsWithdrawn(Attributes _attribute, uint256 _time);
    event SavingsBurned(Attributes _attribute, uint256 _time);
    event LoanCreated(uint256 _id, uint256 _totalLoan);
    event LoanRepaid(uint256 _id);
    event MetadataUpdate(uint256 _tokenId);
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

    function mintSavings(
        uint256 _principal,
        uint256 _cfaLife,
        uint256 _qty,
        address _referrer
    ) external nonReentrant {
        require(
            GlobalMarker(registry.getContractAddress("GlobalMarker"))
                .isInterestSet(),
            "GlobalSupply: Interest not yet set"
        );
        require(
            _principal <= 99999000000000000000000 &&
                _principal >= 10000000000000,
            "LockedSavings: Invalid Principal"
        );
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
        for (uint256 i = 0; i < _qty; i++) {
            // Referral checks
            if (
                (
                    Referral(registry.getContractAddress("Referral"))
                        .eligibleForReward(msg.sender)
                )
            ) {
                Referral(registry.getContractAddress("Referral"))
                    .rewardForReferrer(msg.sender, _principal);
                uint256 discount = Referral(
                    registry.getContractAddress("Referral")
                ).getReferredDiscount();
                attributes[system.idCounter].discountGiven = discount;
                uint256 amtPayable = _principal -
                    ((_principal * discount) / 10000);
                uint256 discounted = ((_principal * discount) / 10000);
                token.mint(address(this), discounted);
                IERC20(registry.getContractAddress("Bean")).transferFrom(
                    msg.sender,
                    address(this),
                    amtPayable
                );
            } else {
                IERC20(registry.getContractAddress("Bean")).transferFrom(
                    msg.sender,
                    address(this),
                    _principal
                );
            }

            // Setting Attributes
            require(
                _cfaLife >= system.minLife && system.maxLife >= _cfaLife,
                "Savings: Invalid CFA life duration"
            );
            InterestRateModel interestModel = InterestRateModel(
                registry.getContractAddress("InterestRateModel")
            );
            uint256 totalReward = (
                interestModel.getSavingsOutcome(
                    _cfaLife,
                    GlobalMarker(registry.getContractAddress("GlobalMarker"))
                        .getMarker(),
                    _principal
                )
            );
            attributes[system.idCounter].timeCreated = block.timestamp;
            attributes[system.idCounter].cfaLifeTimestamp =
                block.timestamp +
                (30 days * 12 * _cfaLife);
            attributes[system.idCounter].cfaLife = _cfaLife;
            attributes[system.idCounter].effectiveInterestTime = block
                .timestamp;
            attributes[system.idCounter].principal = _principal;
            attributes[system.idCounter].marker = GlobalMarker(
                registry.getContractAddress("GlobalMarker")
            ).getMarker();
            emit SavingsCreated(attributes[system.idCounter]);
            token.mint(address(this), totalReward);
            _mint(msg.sender, system.idCounter, 1, "");

            // Update System
            // system.totalRewardsToBeGiven += totalReward;
            system.idCounter++;
            system.totalActiveCfa++;
        }
    }

    /// @notice This function is used to burn the Savings CFA when the CFA has matured
    /// @param _id The id of the Savings CFA, which is the tokenId
    function _burnSavings(uint256 _id) internal {
        emit SavingsBurned(attributes[_id], block.timestamp);
        delete attributes[_id];
        _burn(msg.sender, _id, 1);
        system.totalActiveCfa--;
    }

    /// @notice This function is used to withdraw the Savings CFA when the CFA has matured
    /// @param _id The id of the Savings CFA, which is the tokenId
    function withdrawSavings(uint256 _id) external nonReentrant {
        require(
            block.timestamp > attributes[_id].cfaLifeTimestamp,
            "Savings: CFA not yet matured"
        );
        require(!loan[_id].onLoan, "Savings: On Loan");

        uint256 interestRate = InterestRateModel(
            registry.getContractAddress("InterestRateModel")
        ).getSavingsOutcome(
                attributes[_id].cfaLife,
                GlobalMarker(registry.getContractAddress("GlobalMarker"))
                    .getMarker(),
                attributes[_id].principal
            );

        Bean token = Bean(registry.getContractAddress("Bean"));
        token.transfer(msg.sender, interestRate + attributes[_id].principal);
        token.addTotalRewarded(interestRate, msg.sender);
        emit SavingsWithdrawn(attributes[_id], block.timestamp);
        // system.totalPaidAmount += interestRate;
        // system.totalRewardsToBeGiven -= interestRate;
        _burnSavings(_id);
    }

    /**
     * Loan functions
     */

    function createLoan(uint256 _id) external nonReentrant {
        require(balanceOf(msg.sender, _id) == 1, "Savings: not the owner");
        require(!loan[_id].onLoan, "Savings: Loan already created");
        require(
            block.timestamp < attributes[_id].cfaLifeTimestamp,
            "Savings: CFA has expired"
        );

        uint256 _yieldedInterest = getYieldedInterest(_id);

        uint256 loanedPrincipal = ((attributes[_id].principal +
            _yieldedInterest) * 25) / 100;
        Bean token = Bean(registry.getContractAddress("Bean"));
        token.mint(msg.sender, loanedPrincipal);

        loan[_id].onLoan = true;
        loan[_id].loanBalance = loanedPrincipal;
        loan[_id].timeWhenLoaned = block.timestamp;

        emit LoanCreated(_id, loanedPrincipal);
        emit MetadataUpdate(_id);
    }

    function repayLoan(uint256 _id) external nonReentrant {
        require(loan[_id].onLoan, "Savings: Loan invalid");

        IERC20(registry.getContractAddress("Bean")).transferFrom(
            msg.sender,
            address(this),
            loan[_id].loanBalance
        );

        Bean(registry.getContractAddress("Bean")).burn(loan[_id].loanBalance);

        uint256 timePassed = block.timestamp - loan[_id].timeWhenLoaned;
        attributes[_id].cfaLifeTimestamp += timePassed;
        uint256 oldTime = attributes[_id].effectiveInterestTime;
        attributes[_id].effectiveInterestTime =
            block.timestamp -
            (loan[_id].timeWhenLoaned - oldTime);
        loan[_id].loanBalance = 0;
        loan[_id].onLoan = false;

        emit LoanRepaid(_id);
        emit MetadataUpdate(_id);
    }

    /**
     * Write Function
     */

    function setContractUri(string memory _uri) external onlyOwner {
        contractUri = _uri;
        emit ContractURIUpdated();
    }

    function setImage(string memory _image) external onlyOwner {
        metadata.image = _image;
    }

    function setLoanImage(string memory _image) external onlyOwner {
        metadata.loanImage = _image;
    }

    function setMetadata(
        string memory _name,
        string memory _description
    ) external onlyOwner {
        metadata.name = _name;
        metadata.description = _description;
    }

    function setRegistry(address _registry) external onlyOwner {
        registry = Registry(_registry);
    }

    function setLife(uint256 _min, uint256 _max) external onlyOwner {
        system.minLife = _min;
        system.maxLife = _max;
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
     * Read Function
     */

    function getLoanBalance(uint _id) external view returns (uint256) {
        uint _loanBalance = loan[_id].loanBalance;
        return _loanBalance;
    }

    function getYieldedInterest(uint256 _id) public view returns (uint256) {
        uint256 _timePassed = ((block.timestamp -
            attributes[_id].effectiveInterestTime) / (30 days * 12)); // In years

        if (_timePassed == 0) {
            return 0;
        }

        uint256 _yieldedInterest = InterestRateModel(
            registry.getContractAddress("InterestRateModel")
        ).getSavingsOutcome(
                _timePassed,
                attributes[_id].marker,
                attributes[_id].principal
            );

        return _yieldedInterest;
    }

    function getSavingsOutcome(uint256 _id) external view returns (uint256) {
        InterestRateModel interestRateModel = InterestRateModel(
            registry.getContractAddress("InterestRateModel")
        );
        uint256 _outcome = interestRateModel.getSavingsOutcome(
            attributes[_id].cfaLife,
            attributes[_id].marker,
            attributes[_id].principal
        );

        return _outcome;
    }

    function getTotalActiveCfa() external view returns (uint256) {
        return system.totalActiveCfa;
    }

    function newExpiry(uint256 _id) external view returns (uint256) {
        uint256 timePassed = block.timestamp - loan[_id].timeWhenLoaned;
        uint256 _newExpiry = attributes[_id].cfaLifeTimestamp + timePassed;
        return _newExpiry;
    }

    /**
     * Metadata Getters
     */

    function getMetadata(uint256 _tokenId) public view returns (string memory) {
        string memory basicInfo = getBasicInfo(_tokenId);
        string memory firstHalfAttributesInfo = getFirstHalfAttributesInfo(
            _tokenId
        );
        string memory secondHalfAttributesInfo = getSecondHalfAttributesInfo(
            _tokenId
        );
        string memory loanInfo = getLoanInfo(_tokenId);

        return
            string(
                abi.encodePacked(
                    "{",
                    basicInfo,
                    firstHalfAttributesInfo,
                    secondHalfAttributesInfo,
                    loanInfo,
                    "]}"
                )
            );
    }

    function formatEther(
        uint256 amountInWei
    ) public pure returns (string memory) {
        uint256 wholePart = amountInWei / 1 ether;
        uint256 decimalPart = (amountInWei / 10000000000000000) % 100;
        if (decimalPart == 0) {
            return wholePart.toString();
        }
        string memory decimalStr = decimalPart < 10
            ? string(abi.encodePacked("0", decimalPart.toString()))
            : decimalPart.toString();

        return string(abi.encodePacked(wholePart.toString(), ".", decimalStr));
    }

    function formatPercentage(
        uint256 percentage
    ) public pure returns (string memory) {
        uint256 wholePart = percentage / 10000000000000000;
        uint256 decimalPart = (percentage / 100000000000000) % 100;
        if (decimalPart == 0) {
            return wholePart.toString();
        }
        string memory decimalStr = decimalPart < 10
            ? string(abi.encodePacked("0", decimalPart.toString()))
            : decimalPart.toString();

        return string(abi.encodePacked(wholePart.toString(), ".", decimalStr));
    }

    function getBasicInfo(
        uint256 _tokenId
    ) internal view returns (string memory) {
        string memory imageUri = loan[_tokenId].onLoan
            ? metadata.loanImage
            : metadata.image;

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
                    imageUri,
                    '",',
                    '"attributes": ['
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

    function getTotalInvestment(
        uint256 _principal,
        uint256 _qty
    ) public view returns (uint256) {
        uint256 totalInvestment;
        for (uint256 i = 0; i < _qty; i++) {
            if (
                (
                    Referral(registry.getContractAddress("Referral"))
                        .eligibleForReward(msg.sender)
                )
            ) {
                uint256 discount = Referral(
                    registry.getContractAddress("Referral")
                ).getReferredDiscount();
                uint256 amtPayable = _principal -
                    ((_principal * discount) / 10000);

                totalInvestment += amtPayable;
            } else {
                totalInvestment += _principal;
            }
        }
        return totalInvestment;
    }

    function getFirstHalfAttributesInfo(
        uint256 _tokenId
    ) internal view returns (string memory) {
        InterestRateModel interestModel = InterestRateModel(
            registry.getContractAddress("InterestRateModel")
        );
        return
            string(
                abi.encodePacked(
                    '{ "trait_type": "Creation Date", "display_type": "date", "value": "',
                    attributes[_tokenId].timeCreated.toString(),
                    '" },',
                    '{ "trait_type": "Maturity Date", "display_type": "date", "value": "',
                    attributes[_tokenId].cfaLifeTimestamp.toString(),
                    '" },',
                    '{ "trait_type": "Principal", "value": "',
                    formatEther(attributes[_tokenId].principal),
                    '" },',
                    '{ "trait_type": "Earnings Total", "value": "',
                    formatEther(
                        (interestModel.getSavingsOutcome(
                            attributes[_tokenId].cfaLife,
                            attributes[_tokenId].marker,
                            attributes[_tokenId].principal
                        ) + attributes[_tokenId].principal)
                    ),
                    '" },'
                )
            );
    }

    function getSecondHalfAttributesInfo(
        uint256 _tokenId
    ) internal view returns (string memory) {
        InterestRateModel interestModel = InterestRateModel(
            registry.getContractAddress("InterestRateModel")
        );
        return
            string(
                abi.encodePacked(
                    '{ "trait_type": "Interest Return", "value": "',
                    formatEther(
                        interestModel.getSavingsOutcome(
                            attributes[_tokenId].cfaLife,
                            attributes[_tokenId].marker,
                            attributes[_tokenId].principal
                        )
                    ),
                    '" },',
                    '{ "trait_type": "Interest Rate (%)", "value": "',
                    formatPercentage(
                        interestModel.getSavingsInterestRate(
                            attributes[_tokenId].cfaLife,
                            attributes[_tokenId].marker
                        )
                    ),
                    '" },',
                    '{ "trait_type": "Loan Status", "value": "',
                    (loan[_tokenId].onLoan ? "On Loan" : "Not on Loan"),
                    '" },',
                    '{ "trait_type": "Discount Given (%)", "value": "',
                    formatDiscount(attributes[_tokenId].discountGiven),
                    '" }'
                )
            );
    }

    function contractURI() public view returns (string memory) {
        return string.concat("data:application/json;utf8,", contractUri);
    }

    function getLoanInfo(
        uint256 _tokenId
    ) internal view returns (string memory) {
        if (loan[_tokenId].onLoan) {
            return
                string(
                    abi.encodePacked(
                        ', { "trait_type": "Lending Date", "display_type": "date", "value": "',
                        loan[_tokenId].timeWhenLoaned.toString(),
                        '" },',
                        '{ "trait_type": "Loan Awarded", "value": "',
                        formatEther(loan[_tokenId].loanBalance),
                        '" }'
                    )
                );
        }
        return "";
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
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "./hardhat_console.sol";


import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

import "./contracts_interface_4.i_Fish_Purchase.sol";
import "./contracts_interface_2.i_Fish_CERTNFT.sol";
import "./contracts_interface_5.i_Fish_Staking_Master.sol";

contract Fish_Purchase is I_Fish_Purchase, AccessControl, ReentrancyGuard, Pausable {
    bytes32 public constant PURCHASE_ROLE = keccak256("PURCHASE_ROLE");

    IERC20 public USDTERC20;
    
    I_Fish_CERTNFT public FISH_NFT;

    I_Fish_Staking_Master public FISH_STAKING_CONTROLLER;

    mapping(address => bool) web2AuthorisedPurchaseAddresses;
    mapping(bytes32 => bool) completedReservationIDs;


    address public treasury;

    mapping(uint256 => Fish_Package_Data) public packages;
    mapping(uint256 => mapping(uint256 => uint256)) public purchaseCounterByBonanzaLine;
    mapping(uint256 => uint256) public mintCountPerPackage;

    uint256 public packageCtr;

    constructor(address _NFT, address _USDTERC20, address _FISHSTAKING, address _treasury) AccessControl() Pausable() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        FISH_NFT = I_Fish_CERTNFT(_NFT);
        USDTERC20 = IERC20(_USDTERC20);
        FISH_STAKING_CONTROLLER = I_Fish_Staking_Master(_FISHSTAKING);

        FISH_NFT.setApprovalForAll(_FISHSTAKING, true);

        treasury = _treasury;
    }


    // Admin Functions
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }


    function addRemoveWeb2AuthorisedPurchaseAddress(address _serverAddress, bool _active) external onlyRole(DEFAULT_ADMIN_ROLE) {
        web2AuthorisedPurchaseAddresses[_serverAddress] = _active;
    }



    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = _treasury;
    }

    function setPackage(
        uint256 _packageID,
        Fish_Package_Data memory _packageMetaData
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (packageCtr < _packageID) packageCtr = _packageID;

        packages[_packageID] = _packageMetaData;

        emit SetPackageEvent(_packageID, _packageMetaData);
    }

    // // Public Functions
    function fetchPackagePrice(
        uint256 _packageID,
        uint256 _bonanzaLineNumber
    ) external view override returns (uint256) {
        return ifetchPackagePrice(_packageID, _bonanzaLineNumber);
    }


    function purchaseBySignedReservation(
        bytes32 _reservationID,
        PurchaseLine[] memory _purchaseList,
        uint256 _totalPrice,
        uint256 _blockchainCompletionTimestamp,
        bytes memory _signature
    ) external {
        // Step 1: Validate the signature
        require(_blockchainCompletionTimestamp >= block.timestamp, "Reservation out of date. DDoS protection requires you wait another 5 minutes before retrying");
        require(completedReservationIDs[_reservationID] == false, "Reservation ID already completed");

        bytes memory purchaseListFlat;
        for (uint256 i = 0; i < _purchaseList.length; i++) {
            purchaseListFlat = abi.encodePacked(
                purchaseListFlat,
                _purchaseList[i].packageID,
                _purchaseList[i].bonanzaLine,
                _purchaseList[i].countToBuy,
                _purchaseList[i].expectedPrice
            );
        }
        
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                msg.sender,
                _reservationID,
                purchaseListFlat, // Ensure this is encoded the same way off-chain
                _totalPrice,
                _blockchainCompletionTimestamp
            )
        );
        console.log("messageHash:");
        console.logBytes32(messageHash);

        address recoveredSigner = iRecoverSigner(messageHash, _signature);
        console.log("purchaseBySignedReservation: recoveredSigner:", recoveredSigner);

        require(
            web2AuthorisedPurchaseAddresses[recoveredSigner] == true,
            "Invalid signature: signed message not from authorised signer"
        );

        // Step 2: Call the mint/stake function
        (uint256[] memory allNFTIds_list, uint256[] memory allNFTCertTypes_list) = i_purchaseByReservation_admin(msg.sender, false, _purchaseList, _totalPrice);

        completedReservationIDs[_reservationID] = true;
        emit PurchaseBySignedReservationEvent(msg.sender, _reservationID, allNFTIds_list, allNFTCertTypes_list);
    }


    function purchaseByReservation_admin(address _user, PurchaseLine[] memory _purchaseLine_list, uint256 _totalPrice) external whenNotPaused nonReentrant onlyRole(PURCHASE_ROLE) {
        console.log("Fish_Purchase: purchaseByReservation_admin");
        i_purchaseByReservation_admin(_user, true, _purchaseLine_list, _totalPrice);
    }

    function purchaseNoDeposit_admin(address _user, PurchaseLine[] memory _purchaseLine_list, uint256 _totalPrice) external whenNotPaused onlyRole(PURCHASE_ROLE) {
        console.log("Fish_Purchase: purchase");
        i_purchaseByReservation_admin(_user, false, _purchaseLine_list, _totalPrice);
    }


    // function i_purchaseByReservation_admin(address _user, bool _useDepositFor, PurchaseLine[] memory _purchaseLine_list, uint256 _totalPrice) internal returns (uint256[] memory, uint256[] memory) {
    //     console.log("Fish_Purchase: purchaseByReservation_admin");
    //     console.log("_useDepositFor", _useDepositFor);
    //     require(_purchaseLine_list.length > 0, "must buy at least one package");

    //     // Check if this contract has approval for all NFTs from msg.sender
    //     // require(
    //     //     FISH_NFT.isApprovedForAll(msg.sender, address(this)),
    //     //     "This contract is not approved for all NFTs from msg.sender"
    //     // );

    //     uint256 calculatedTotalPrice = 0;
    //     PurchaseLine memory purchaseLine;
    //     Fish_Package_Data memory packageData;

    //     // Perform all checks before taking any actions
    //     require(USDTERC20.allowance(_user, address(this)) >= _totalPrice, "Insufficient USDT allowance");
    //     require(USDTERC20.balanceOf(_user) >= _totalPrice, "Insufficient USDT balance");


    //     uint256 totalNFTsCount;

    //     // Validate each purchase line and check package constraints
    //     for (uint256 i = 0; i < _purchaseLine_list.length; i++) {
    //         purchaseLine = _purchaseLine_list[i];

    //         // Fetch package metadata
    //         packageData = packages[purchaseLine.packageID];

    //         // Ensure the package exists
    //         require(packageData.maxMint > 0, "Invalid package ID");

    //         // Ensure that there is space in the bonanzaLine
    //         require(
    //             purchaseCounterByBonanzaLine[purchaseLine.packageID][purchaseLine.bonanzaLine] + purchaseLine.countToBuy <= packageData.maxPerBonanzaLine, 
    //              "Exceeds max NFTs for this bonanza line"
    //         );
    //         require(mintCountPerPackage[purchaseLine.packageID] + purchaseLine.countToBuy <= packageData.maxMint, "Package type will overflow if this order is fulfilled");

    //         // Calculate the total price for this purchase line
    //         uint256 priceOfLine = ifetchPackagePrice(purchaseLine.packageID, purchaseLine.bonanzaLine) * purchaseLine.countToBuy;

    //         console.log(priceOfLine, purchaseLine.expectedPrice);
    //         calculatedTotalPrice += priceOfLine;

    //         totalNFTsCount += purchaseLine.countToBuy;
    //     }
    //     console.log("Fish_Purchase: totalPrice / calculatedTotalPrice");
    //     console.log(_totalPrice);
    //     console.log(calculatedTotalPrice);
        

    //     // Ensure total price matches expectations
    //     require(calculatedTotalPrice == _totalPrice, "Price mismatch");

    //     // Actions start after all validations are complete

    //     // Transfer USDT from the user to this contract
    //     require(
    //         USDTERC20.transferFrom(_user, address(this), _totalPrice),
    //         "USDT transfer failed"
    //     );

    //     // Transfer USDT to the treasury
    //     require(
    //         USDTERC20.transfer(treasury, _totalPrice),
    //         "USDT treasury transfer failed"
    //     );

    //     uint256[] memory allNFTIds_list = new uint256[](totalNFTsCount);
    //     uint256[] memory allNFTCertTypes_list =  new uint256[](totalNFTsCount);
    //     totalNFTsCount = 0;

    //     // Mint NFTs and stake them
    //     for (uint256 i = 0; i < _purchaseLine_list.length; i++) {
    //         purchaseLine = _purchaseLine_list[i];

    //         console.log("Fish_Purchase: about to mint");
    //         // Mint And Stake the NFTs
    //         Fish_CERTNFT_Metadata[] memory metaDataToMintStake_list = new Fish_CERTNFT_Metadata[](purchaseLine.countToBuy);
    //         uint256[] memory idsToStake_list = new uint256[](purchaseLine.countToBuy);

    //         for (uint256 j = 0; j < purchaseLine.countToBuy; j++) {
    //             packageData = packages[purchaseLine.packageID];
    //             metaDataToMintStake_list[j].power = packageData.power;
    //             metaDataToMintStake_list[j].tokenIPFSURI = packageData.initialIPFSURI;
    //             metaDataToMintStake_list[j].mintingPrice = ifetchPackagePrice(purchaseLine.packageID, purchaseLine.bonanzaLine);
    //             metaDataToMintStake_list[j].mintingBonanzaRow = purchaseLine.bonanzaLine;

    //             if (_useDepositFor) {
    //                 idsToStake_list[j] = FISH_NFT.mint(address(this), metaDataToMintStake_list[j]);
    //                 allNFTIds_list[totalNFTsCount] = idsToStake_list[j];
    //             } else {
    //                 idsToStake_list[j] = FISH_NFT.mint(_user, metaDataToMintStake_list[j]);
    //                 allNFTIds_list[totalNFTsCount] = idsToStake_list[j];
    //             }
    //             allNFTCertTypes_list[totalNFTsCount] = purchaseLine.packageID;
    //             totalNFTsCount ++;
    //         }
    //         if (_useDepositFor) {
    //             FISH_STAKING_CONTROLLER.depositFor_admin(address(this), _user, idsToStake_list);
    //         }

    //         // Update the purchase counter
    //         purchaseCounterByBonanzaLine[purchaseLine.packageID][purchaseLine.bonanzaLine] += purchaseLine.countToBuy;
    //         mintCountPerPackage[purchaseLine.packageID] += purchaseLine.countToBuy;
    //     }

    //     // Stake NFTs for the user
    //     // FISH_STAKING_CONTROLLER.stakeFor_admin(_user, _purchaseLine_list);
    //      bytes[] memory encodedPurchaseLines = new bytes[](_purchaseLine_list.length);

    //     for (uint256 i = 0; i < _purchaseLine_list.length; i++) {
    //         encodedPurchaseLines[i] = abi.encode(_purchaseLine_list[i]);
    //     }

    //     emit PurchaseByReservationAdminEvent(_user, _useDepositFor, encodedPurchaseLines, _totalPrice);

    //     return (allNFTIds_list, allNFTCertTypes_list);
    // }

    function i_purchaseByReservation_admin(
        address _user, 
        bool _useDepositFor, 
        PurchaseLine[] memory purchaseLines, 
        uint256 totalPrice
    ) internal returns (uint256[] memory, uint256[] memory) {
        console.log("Fish_Purchase: purchaseByReservation_admin");

        require(purchaseLines.length > 0, "Must buy at least one package");
        require(USDTERC20.allowance(_user, address(this)) >= totalPrice, "Insufficient USDT allowance");
        require(USDTERC20.balanceOf(_user) >= totalPrice, "Insufficient USDT balance");

        // Validate and calculate totals
        (uint256 calculatedTotalPrice, uint256 totalNFTCount) = i_validatePurchaseLines(purchaseLines, totalPrice);

        require(calculatedTotalPrice == totalPrice, "Price mismatch");

        // Transfer USDT
        require(USDTERC20.transferFrom(_user, address(this), totalPrice), "USDT transfer failed");
        require(USDTERC20.transfer(treasury, totalPrice), "USDT treasury transfer failed");

        // Mint NFTs
        (uint256[] memory allNFTIds, uint256[] memory allNFTCertTypes) = i_mintAndPrepareNFTs(
            _user,
            _useDepositFor,
            purchaseLines
        );

        // Emit event
        bytes[] memory encodedPurchaseLines = new bytes[](purchaseLines.length);
        for (uint256 i = 0; i < purchaseLines.length; i++) {
            encodedPurchaseLines[i] = abi.encode(purchaseLines[i]);
        }
        emit PurchaseByReservationAdminEvent(_user, _useDepositFor, encodedPurchaseLines, totalPrice);

        return (allNFTIds, allNFTCertTypes);
    }
        


    function i_validatePurchaseLines(
        PurchaseLine[] memory purchaseLines,
        uint256 totalPrice
    ) internal view returns (uint256 calculatedTotalPrice, uint256 totalNFTsCount) {
        for (uint256 i = 0; i < purchaseLines.length; i++) {
            PurchaseLine memory purchaseLine = purchaseLines[i];
            Fish_Package_Data memory packageData = packages[purchaseLine.packageID];

            require(packageData.maxMint > 0, "Invalid package ID");
            require(
                purchaseCounterByBonanzaLine[purchaseLine.packageID][purchaseLine.bonanzaLine] + purchaseLine.countToBuy 
                <= packageData.maxPerBonanzaLine,
                "Exceeds max NFTs for bonanza line"
            );

            require(mintCountPerPackage[purchaseLine.packageID] + purchaseLine.countToBuy <= packageData.maxMint, 
                    "Package overflow");

            uint256 priceOfLine = ifetchPackagePrice(purchaseLine.packageID, purchaseLine.bonanzaLine) * purchaseLine.countToBuy;
            calculatedTotalPrice += priceOfLine;
            totalNFTsCount += purchaseLine.countToBuy;
        }

        require(calculatedTotalPrice == totalPrice, "Price mismatch");
        return (calculatedTotalPrice, totalNFTsCount);
    }

    function i_mintAndPrepareNFTs(
        address _user,
        bool _useDepositFor,
        PurchaseLine[] memory purchaseLines
    ) internal returns (uint256[] memory allNFTIds, uint256[] memory allNFTCertTypes) {
        uint256 totalNFTCount;
        for (uint256 i = 0; i < purchaseLines.length; i++) {
            totalNFTCount += purchaseLines[i].countToBuy;
        }
        allNFTIds = new uint256[](totalNFTCount);
        allNFTCertTypes = new uint256[](totalNFTCount);

        uint256 index = 0;
        for (uint256 i = 0; i < purchaseLines.length; i++) {
            PurchaseLine memory purchaseLine = purchaseLines[i];
            uint256[] memory idsToStake = new uint256[](purchaseLine.countToBuy);

            for (uint256 j = 0; j < purchaseLine.countToBuy; j++) {
                Fish_CERTNFT_Metadata memory metaData = Fish_CERTNFT_Metadata({
                    power: packages[purchaseLine.packageID].power,
                    tokenIPFSURI: packages[purchaseLine.packageID].initialIPFSURI,
                    mintingPrice: ifetchPackagePrice(purchaseLine.packageID, purchaseLine.bonanzaLine),
                    mintingBonanzaRow: purchaseLine.bonanzaLine,
                    currentOwner: address(0),
                    packageID: purchaseLine.packageID,
                    
                    isWhale: false,
                    vestingduration: 0
                });

                if (_useDepositFor) {
                    idsToStake[j] = FISH_NFT.mint(address(this), metaData);
                } else {
                    idsToStake[j] = FISH_NFT.mint(_user, metaData);
                }

                allNFTIds[index] = idsToStake[j];
                allNFTCertTypes[index] = purchaseLine.packageID;
                index++;
            }

            if (_useDepositFor) {
                FISH_STAKING_CONTROLLER.depositFor_admin(address(this), _user, idsToStake);
            }

            // Update counters
            purchaseCounterByBonanzaLine[purchaseLine.packageID][purchaseLine.bonanzaLine] += purchaseLine.countToBuy;
            mintCountPerPackage[purchaseLine.packageID] += purchaseLine.countToBuy;
        }

        return (allNFTIds, allNFTCertTypes);
    }





    function prefixedHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
    }

    function iRecoverSigner(bytes32 messageHash, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "Invalid signature length");

        messageHash = prefixedHash(messageHash);

        bytes32 r;
        bytes32 s;
        uint8 v;

        // Extract r, s, and v from the signature
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        return ecrecover(messageHash, v, r, s);
    }

    // function iPurchase( address _addr , uint256 _packageID, uint256 _price ) internal {
    //     Fish_Package_Data memory packageMetaData = packages[_packageID];

    //     require( packageMetaData.maxMint > packagePurchaseCounters[_packageID] ,"Max Mint Reached" );
    //     Fish_CERTNFT_Metadata memory nftMetaData;

    //     nftMetaData.power = packageMetaData.power;
    //     nftMetaData.tokenIPFSURI = packageMetaData.initialIPFSURI;

    //     nftMetaData.mintingPrice = _price;

    //     FISH_NFT.mint( _addr , nftMetaData );

    //     emit PurchaseEvent(_addr , _packageID,  _price, packageMetaData, nftMetaData);
    // }

    // Internal Functions
    function ifetchPackagePrice(uint256 _packageID, uint256 _bonanzaLineNumber) internal view returns (uint256) {
        require(_packageID < packageCtr + 1, "Invalid Package ID ");
        Fish_Package_Data memory package = packages[_packageID];
        return (package.basePrice + (package.incrementPrice * _bonanzaLineNumber));
    }

}
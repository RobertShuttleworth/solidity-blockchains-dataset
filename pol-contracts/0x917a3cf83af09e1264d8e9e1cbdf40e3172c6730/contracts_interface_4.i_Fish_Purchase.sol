// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_IAccessControl.sol";
import "./openzeppelin_contracts_token_ERC721_IERC721.sol";

import "./contracts_interface_0.FishStructs.sol";

interface I_Fish_Purchase is IAccessControl   {

    struct PurchaseLine {
        uint256 packageID;
        uint256 bonanzaLine;
        uint256 countToBuy;
        uint256 expectedPrice;
    }

    event setTreasuryEvent(address indexed _treasury);

    event SetPackageEvent(uint256 indexed _packageId, Fish_Package_Data _packageMetaData);
    // event UpdatePackagePricingEvent(uint indexed _package_id);
    event DisablePackageEvent(uint indexed _package_id);
    event EnablePackageEvent(uint indexed _package_id);

    event PurchaseByReservationAdminEvent(address indexed _user, bool indexed _useDepositFor, bytes[] _encoded_purchaseLine_list, uint256 _totalPrice);
    event PurchaseBySignedReservationEvent(address indexed _user, bytes32 indexed reservationID, uint256[] _allNFTIds_list, uint256[] _allNFTCertTypes_list);

    function pause() external;

    function unpause() external;

    function addRemoveWeb2AuthorisedPurchaseAddress(address _serverAddress, bool _active) external;
    
    
    function setTreasury( address _treasury ) external;

    function setPackage( uint256 _packageID, Fish_Package_Data memory _Package ) external;

    function purchaseBySignedReservation(bytes32 _reservationID, PurchaseLine[] memory _purchaseList, uint256 _totalPrice, uint256 _blockchainCompletionTimestamp, bytes memory _signature) external;
    
    function purchaseByReservation_admin (address _user, PurchaseLine[] memory _purchaseCountByPackage_list, uint256 _totalPrice ) external;
    function purchaseNoDeposit_admin(address _user, PurchaseLine[] memory _purchaseLine_list, uint256 _totalPrice) external;

    function fetchPackagePrice( uint256 _packageID, uint256 _bonanzaLineNumber ) external view returns (uint256);


}
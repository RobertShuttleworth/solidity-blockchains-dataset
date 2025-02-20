// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./openzeppelin_contracts_utils_Strings.sol";
import "./openzeppelin_contracts-upgradeable_access_extensions_AccessControlEnumerableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";


contract CentralAuthorizationRegistry is Initializable, UUPSUpgradeable, AccessControlEnumerableUpgradeable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Array to store authorized contracts
    address[] private authorizedContractsList;

    // Mapping to store authorized contracts for efficient lookup
    mapping(address => bool) private authorizedContracts;

    // Mapping to store registered pirate NFT contracts
    mapping(address => IERC1155) public pirateNftContracts;

    // Mapping to store contract addresses with their interface IDs
    mapping(bytes32 => address) private contractAddresses;

    event ContractAuthorized(address indexed contractAddress);
    event ContractDeauthorized(address indexed contractAddress);
    event PirateNftContractRegistered(address indexed collectionAddress);
    event ContractAddressSet(bytes32 indexed interfaceId, address indexed contractAddress);

    function initialize(address _admin_multi_sig) public initializer {
        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin_multi_sig);        
        _grantRole(ADMIN_ROLE, _admin_multi_sig);        
        _grantRole(ADMIN_ROLE, msg.sender);  
              
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyAdmin() {}

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), string(abi.encodePacked("Caller is not an admin: ", Strings.toHexString(uint160(msg.sender), 20))));
        _;
    }

    modifier onlyAuthorized() {
        require(isAuthorized(msg.sender), "Not an authorized contract");
        _;
    } 

    function addAuthorizedContract(address contractAddress) external onlyAdmin {
        require(contractAddress != address(0), "Invalid contract address");
        require(!authorizedContracts[contractAddress], "Contract is already authorized");
        authorizedContracts[contractAddress] = true;
        authorizedContractsList.push(contractAddress);
        emit ContractAuthorized(contractAddress);
    }

    function removeAuthorizedContract(address contractAddress) external onlyAdmin {
        require(contractAddress != address(0), "Invalid contract address");
        require(authorizedContracts[contractAddress], "Contract is not authorized");
        authorizedContracts[contractAddress] = false;
        
        for (uint256 i = 0; i < authorizedContractsList.length; i++) {
            if (authorizedContractsList[i] == contractAddress) {
                authorizedContractsList[i] = authorizedContractsList[authorizedContractsList.length - 1];
                authorizedContractsList.pop();
                break;
            }
        }
        
        emit ContractDeauthorized(contractAddress);
    }

    function isAuthorized(address contractAddress) public view returns (bool) {
        return authorizedContracts[contractAddress];
    }

    function isAdmin(address user) public view returns (bool) {
        return hasRole(ADMIN_ROLE, user);
    }

    function getAuthorizedContracts() external view returns (address[] memory) {
        return authorizedContractsList;
    }

    function registerPirateNftContract(address collectionAddress) external onlyAdmin {
        require(collectionAddress != address(0), "Invalid collection address");        
        pirateNftContracts[collectionAddress] = IERC1155(collectionAddress);
        emit PirateNftContractRegistered(collectionAddress);
    }

    function getPirateNftContract(address collectionAddress) external view returns (IERC1155) {
        return pirateNftContracts[collectionAddress];
    }

    function setContractAddress(bytes32 interfaceId, address contractAddress) external onlyAdmin {
        require(contractAddress != address(0), "Invalid contract address");
        contractAddresses[interfaceId] = contractAddress;
        emit ContractAddressSet(interfaceId, contractAddress);
    }

    function getContractAddress(bytes32 interfaceId) external view returns (address) {
        return contractAddresses[interfaceId];
    }

    function getRoleMembers(bytes32 role) public view override returns (address[] memory) {
        uint256 count = getRoleMemberCount(role);
        address[] memory members = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            members[i] = getRoleMember(role, i);
        }
        return members;
    }

    function getAllDefaultAdminRoleUsers() external view returns (address[] memory) {
        return getRoleMembers(DEFAULT_ADMIN_ROLE);
    }

}
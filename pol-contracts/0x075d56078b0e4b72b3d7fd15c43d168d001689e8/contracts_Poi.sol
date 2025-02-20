// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_Members.sol";
import "./contracts_NFTAccount.sol";

contract POI is Initializable, AccessControlUpgradeable, UUPSUpgradeable, OwnableUpgradeable {

    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    MembershipContract public membershipContract;
    NFTAccount public accountContract;

    event AccountContractSet(address indexed accountContract);
    event MemberContractSet(address indexed memberContract);
    event UserCreated(address indexed user);
    event UserUpdated(address indexed user);
    event UserWalletChanged(address indexed oldWallet, address indexed newWallet);
    event UserImgChanged(address indexed user, string imageLink);

    struct PersonalData {
        string encryptedEmail;
        string encryptedName;
        string encryptedUsername;
        string encryptedPhoneNumber;
        string encryptedCountry;
        string encryptedGender;
        string encryptedDateOfBirth;
        string imageLink;
        string fbLink;
        string igLink;
        string youtubeLink;
        string yTWelcomeLink;
        string tikTokLink;
        string wspLink;
        string bio;
    }


    mapping(address => PersonalData) public personalDataMap; 
    mapping(address => bool) public userRegister;
    mapping(string => bool) public usedEmails;
    mapping(string => bool) public usedUsernames;
    mapping(string => bool) public usedPhoneNumbers;

        


    function initialize(address _accountContract, address _memberContract) public initializer {
        __AccessControl_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        _grantRole(ADMIN_ROLE, msg.sender);

        accountContract = NFTAccount(_accountContract);
        membershipContract = MembershipContract(_memberContract);
    }

    //Admin Variables

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function updateAccountContract(address _accountContract) public onlyRole(ADMIN_ROLE) {
        accountContract = NFTAccount(_accountContract);
    }

    function updateMemberContract(address _memberContract) public onlyRole(ADMIN_ROLE) {
        membershipContract = MembershipContract(_memberContract);
    }

    function createNewUser(
        address _address,
        string memory _encryptedEmail, 
        string memory _encryptedName,
        string memory _encryptedUsername,
        string memory _encryptedPhoneNumber
    ) public onlyOwner {
        require(!usedEmails[_encryptedEmail], "Email already used");
        require(!usedUsernames[_encryptedUsername], "Username already used");
        require(!usedPhoneNumbers[_encryptedPhoneNumber], "Phone number already used");
        personalDataMap[_address] = PersonalData({
            encryptedEmail: _encryptedEmail,
            encryptedName: _encryptedName,
            encryptedUsername: _encryptedUsername,
            encryptedPhoneNumber: _encryptedPhoneNumber,
            encryptedCountry: "",
            encryptedGender: "",
            encryptedDateOfBirth: "",
            imageLink: "",
            fbLink: "",
            igLink: "",
            youtubeLink: "",
            yTWelcomeLink: "",
            tikTokLink: "",
            wspLink: "",
            bio: ""
        });

        usedEmails[_encryptedEmail] = true;
        usedUsernames[_encryptedUsername] = true;
        usedPhoneNumbers[_encryptedPhoneNumber] = true;
        userRegister[_address] = true;

        emit UserCreated(_address);
    }

    //User Variables

    function newUser(
        string memory _encryptedEmail, 
        string memory _encryptedName,
        string memory _encryptedUsername,
        string memory _encryptedPhoneNumber
    ) public {
        require(!usedEmails[_encryptedEmail], "Email already used");
        require(!usedUsernames[_encryptedUsername], "Username already used");
        require(!usedPhoneNumbers[_encryptedPhoneNumber], "Phone number already used");
        personalDataMap[msg.sender] = PersonalData({
            encryptedEmail: _encryptedEmail,
            encryptedName: _encryptedName,
            encryptedUsername: _encryptedUsername,
            encryptedPhoneNumber: _encryptedPhoneNumber,
            encryptedCountry: "",
            encryptedGender: "",
            encryptedDateOfBirth: "",
            imageLink: "",
            fbLink: "",
            igLink: "",
            youtubeLink: "",
            yTWelcomeLink: "",
            tikTokLink: "",
            wspLink: "",
            bio: ""
        });

        usedEmails[_encryptedEmail] = true;
        usedUsernames[_encryptedUsername] = true;
        usedPhoneNumbers[_encryptedPhoneNumber] = true;
        userRegister[msg.sender] = true;

        emit UserCreated(msg.sender);
    }

    function updateUser(
        string memory _encryptedEmail, 
        string memory _encryptedName,
        string memory _encryptedPhoneNumber, 
        string memory _encryptedCountry,
        string memory _encryptedGender, 
        string memory _encryptedDateOfBirth,
        string memory _encryptedFbLink,
        string memory _encryptedIgLink,
        string memory _encryptedYoutubeLink,
        string memory _yTWelcomeLink,
        string memory _encryptedTikTokLink,
        string memory _encryptedWspLink,
        string memory _encryptedBio
    ) public {
        require(userRegister[msg.sender], "Debes estar registrado");

        if (keccak256(bytes(_encryptedEmail)) != keccak256(bytes(personalDataMap[msg.sender].encryptedEmail))) {
            require(!usedEmails[_encryptedEmail], "Email already used");
            usedEmails[_encryptedEmail] = true;
            usedEmails[personalDataMap[msg.sender].encryptedEmail] = false;
        }
        
        if (keccak256(bytes(_encryptedPhoneNumber)) != keccak256(bytes(personalDataMap[msg.sender].encryptedPhoneNumber))) {
            require(!usedPhoneNumbers[_encryptedPhoneNumber], "Phone number already used");
            usedPhoneNumbers[_encryptedPhoneNumber] = true;
            usedPhoneNumbers[personalDataMap[msg.sender].encryptedPhoneNumber] = false;
        }

        personalDataMap[msg.sender].encryptedEmail = _encryptedEmail; 
        personalDataMap[msg.sender].encryptedName = _encryptedName;
        personalDataMap[msg.sender].encryptedPhoneNumber = _encryptedPhoneNumber;
        personalDataMap[msg.sender].encryptedCountry = _encryptedCountry;
        personalDataMap[msg.sender].encryptedGender = _encryptedGender;
        personalDataMap[msg.sender].encryptedDateOfBirth = _encryptedDateOfBirth;

        personalDataMap[msg.sender].fbLink = _encryptedFbLink; 
        personalDataMap[msg.sender].igLink = _encryptedIgLink;
        personalDataMap[msg.sender].youtubeLink = _encryptedYoutubeLink;
        personalDataMap[msg.sender].yTWelcomeLink = _yTWelcomeLink;
        personalDataMap[msg.sender].tikTokLink = _encryptedTikTokLink;
        personalDataMap[msg.sender].wspLink = _encryptedWspLink;
        personalDataMap[msg.sender].bio = _encryptedBio;

        emit UserUpdated(msg.sender);
    }

    function changeUserWallet(address _newWallet) public {
        require(userRegister[msg.sender], "Debes estar registrado");
        require(!userRegister[_newWallet], "La nueva wallet ya esta registrada");
        
        accountContract.transferAllAccounts(msg.sender, _newWallet);
        personalDataMap[_newWallet] = personalDataMap[msg.sender];
        
        delete personalDataMap[msg.sender];
        
        userRegister[_newWallet] = true;
        userRegister[msg.sender] = false;
        emit UserWalletChanged(msg.sender, _newWallet);
    }

    function updateImgUser(string memory _imageLink) public {
        require(userRegister[msg.sender], "Debes estar registrado");
        personalDataMap[msg.sender].imageLink = _imageLink;
        emit UserImgChanged(msg.sender, _imageLink);
    }

    //New Logic


        function createNewUserFromUser(
        address _address,
        string memory _encryptedEmail, 
        string memory _encryptedName,
        string memory _encryptedUsername,
        string memory _encryptedPhoneNumber
    ) public  {
        require(!usedEmails[_encryptedEmail], "Email already used");
        require(!usedUsernames[_encryptedUsername], "Username already used");
        require(!usedPhoneNumbers[_encryptedPhoneNumber], "Phone number already used");
        personalDataMap[_address] = PersonalData({
            encryptedEmail: _encryptedEmail,
            encryptedName: _encryptedName,
            encryptedUsername: _encryptedUsername,
            encryptedPhoneNumber: _encryptedPhoneNumber,
            encryptedCountry: "",
            encryptedGender: "",
            encryptedDateOfBirth: "",
            imageLink: "",
            fbLink: "",
            igLink: "",
            youtubeLink: "",
            yTWelcomeLink: "",
            tikTokLink: "",
            wspLink: "",
            bio: ""
        });

        usedEmails[_encryptedEmail] = true;
        usedUsernames[_encryptedUsername] = true;
        usedPhoneNumbers[_encryptedPhoneNumber] = true;
        userRegister[_address] = true;

        emit UserCreated(_address);
    }


}
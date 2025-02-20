pragma solidity >=0.4.21 <0.7.0;
/*
import "./Utils.sol";
import "./Manageable.sol";
import "./Meta.sol";
*/

/// Utils start
/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

/// Utils end

/// manageable start
contract _TokenBook {
    address public owner;
    mapping(uint256 => address) public owners;
    mapping (address => mapping (address => bool)) public operators;
}
contract _TokenKey  {
     mapping (uint => address) public addressKeyContract;
     mapping (uint => uint) public addressKeyTokenID;

     mapping (uint => address) public accountKeyContract;
     mapping (uint => uint) public accountKeyTokenID;
     mapping (uint => uint) public accountKeyAccountID;

     mapping (uint => address) public subAccountKeyContract;
     mapping (uint => uint) public subAccountKeyTokenID;
     mapping (uint => uint) public subAccountKeyAccountID;
     mapping (uint => uint) public subAccountKeySubAccountID;
     function addressKey(address tokenAddress, uint tokenID ) public view returns (uint);
    function accountKey(address tokenAddress, uint tokenID, uint accountID ) public view returns (uint);
    function subAccountKey(address tokenAddress, uint tokenID, uint accountID, uint subAccountID  ) public view returns (uint);
    function addressKeySet(address tokenAddress, uint tokenID ) public view returns (bool);
    function accountKeySet(address tokenAddress, uint tokenID, uint accountID ) public view returns (bool);
    function subAccountKeySet(address tokenAddress, uint tokenID, uint accountID, uint subAccountID  ) public view returns (bool);


     function addressKeyCreate(address tokenAddress, uint tokenID ) public returns (uint);
     function accountKeyCreate(address tokenAddress, uint tokenID, uint accountID ) public returns (uint);
     function subAccountKeyCreate(address tokenAddress, uint tokenID, uint accountID, uint subAccountID  ) public returns (uint);
}
// ----------------------------------------------------------------------------
// Tether contract
// ----------------------------------------------------------------------------
contract _Tether {
    mapping(address => uint) public balances;
    function totalSupply() public view returns (uint);


    function transfer(address to, uint tokens) public;

}
// ----------------------------------------------------------------------------
// TetherBook contract
// ----------------------------------------------------------------------------
contract _TetherBook  {
    function transfer(uint tokenID, address to, uint tokens) public;
}



 /**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address public owner;
    mapping(uint256 => address) public owners;

    /**
      * @dev The Ownable constructor sets the original `owner` of the contract to the sender
      * account.
      */
    constructor() public {
        owner = msg.sender;
    }

    /**
      * @dev Throws if called by any account other than the owner.
      */
    modifier onlyOwner() {
        require(msg.sender == owner,"only owner");
        _;
    }
    /**
      * @dev Throws if called by any account other than token owner
      */
     modifier onlyOwners(uint tokenID) {
        address tokenOwner = owners[tokenID];
        require(msg.sender == tokenOwner,"only owners");
        _;
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner != address(0)) {
            owner = newOwner;
        }
    }
    /**
    * @dev Allows the current token owner to transfer control of the contract to a newOwner.
    * @param newTokenOwner The address to transfer token ownership to.
    */
    function transferTokenOwnership(uint tokenID, address newTokenOwner) public onlyOwners(tokenID) {
        if (newTokenOwner != address(0)) {
            owners[tokenID] = newTokenOwner;
        }
    }
    /**
    * @dev makes it so contracts can pay out Tethers(ERC20) and  TetherBooks
    */
    function payOut(address sC, uint ptID, address pay_to, uint a) public  onlyOwner() returns (bool)  {
        // uint contract_money = tether.balanceOf(this);
        require(pay_to != address(0),"Cant pay to zero address");
 
        if(ptID == 0){
            //make Tether
            _Tether tether = _Tether(sC);
            tether.transfer(pay_to, a); // throws on faiure??
        }else{
            _TetherBook tetherBook = _TetherBook(sC);
            tetherBook.transfer(ptID,pay_to, a); // throws on faiure??
        }

        return true;
      }
}




/**
 * @title Executive
 * @dev The Executive contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Executive is Ownable {
    //[owner][contractAddress] = isExecutive
    mapping (address => mapping (address => bool)) public executives;
    mapping (address => mapping (address => bool)) public operators;
    mapping (uint256 => address) public allowed;
    mapping (uint => bool) public isPublic;
    _TokenBook public tokenBook;
    address public tokenBookAddress;
    _TokenKey public tokenKey;
    address public tokenKeyAddress;
    TokenBookConfig public tokenBookConfig;
    address public tokenBookConfigAddress;

    event Config(address indexed newTokenBookAddress, address indexed newTokenKeyAddress);
    event updateOperatorAccess(address owner, address opperator, bool hasAccess);
    event updateExecutiveAccess(address manager, bool hasAccess);

    /**
      * @dev The Executive constructor sets the original `owner` of the contract to the sender
      * account.
      */
    constructor() public {
        executives[address(this)][msg.sender] = true;

    }
    /**
      * @dev Throws if called by any account other than the owner.
      */
    modifier onlyContractOwner(address contractAddress) {
        address contractOwner = Ownable(contractAddress).owner();
        require(msg.sender == contractOwner,"only  contractowner");
        _;
    }
     /**
      * @dev Throws if called by any account other than the manager or admin.
      */
    modifier onlyExecutives(address contractAddress) {
        require(executives[contractAddress][msg.sender] == true || msg.sender == owner,"only executives");
        _;
    }
    function config(address newTokenBookConfigAddress) public onlyOwner {
        tokenBookConfig = TokenBookConfig(newTokenBookConfigAddress);
        tokenBookConfigAddress = newTokenBookConfigAddress;
        address newTokenKeyAddress = tokenBookConfig.contractAddresses(2);
        tokenKeyAddress = newTokenKeyAddress;
        tokenKey = _TokenKey(newTokenKeyAddress);
        address newTokenBookAddress = tokenBookConfig.contractAddresses(1);
        tokenBookAddress = newTokenBookAddress;
        tokenBook = _TokenBook(newTokenBookAddress);
        emit Config(tokenBookAddress,tokenKeyAddress);
    }
    /**
    * @dev Allows the current executive to transfer control of the contract to a newExecutive.
    * @param newExecutive The address to transfer executiveship to.
    */

    //TODO replace add and remove functions
    function updateExecutive(address contractAddress, address newExecutive, bool isExecutive) public onlyContractOwner(contractAddress) {
        if (newExecutive != address(0)) {
            executives[contractAddress][newExecutive] = isExecutive;
            emit updateExecutiveAccess(newExecutive,isExecutive);
        }
    }
    /**
    * @dev Allows the current executive to transfer executive control of the contract to a newExecutive.
    * @param newExecutive The address to take executiveship to.
    */
    function transferExecutive(address contractAddress, address newExecutive) public onlyExecutives(contractAddress) {
        if (newExecutive != address(0)) {
            executives[contractAddress][msg.sender] = false;
            executives[contractAddress][newExecutive] = true;
            emit updateExecutiveAccess(msg.sender,false);
            emit updateExecutiveAccess(newExecutive,true);
        }
    }
    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return operators[_owner][_operator];
    }
    
    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets.
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators.
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external{
        operators[msg.sender][_operator] = _approved;
        emit updateOperatorAccess(msg.sender, _operator, _approved);
    }
}

/**
 * @title Manageable
 * @dev The Manageable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Manageable is Executive {
    //Manageable shop or organzation smart contract that has a list of managers and admins
    // address public office;

    // owner address -> object key -> user key
    mapping (address => mapping (uint => mapping (uint => bool))) public admins;
    mapping (address => mapping (uint => mapping (uint => bool))) public accountAdmins;
    mapping (address => mapping (uint => mapping (uint => bool))) public subAccountAdmins;
    mapping (address => mapping (uint => mapping (uint => bool))) public managers;

    //used through out Contract
    bool public manageable;
    address _tokenBookAddress;
    uint tokenID;
    address tokenOwner;

    event updateManagerAccess(uint addressKey, uint managerKey, bool hasAccess);
    event updateAdminAccess(uint addressKey, uint adminKey, bool hasAccess);
    event updateAccountAdminAccess(uint accountKey, uint adminKey, bool hasAccess);
    // event updateSubAccountAdminAccess(uint subAccountKey, uint adminKey, bool hasAccess);
    // event updatePublicAccess(uint tokenID, bool hasAccess);



    /**
      * @dev The Manageable constructor sets the original `owner` of the contract to the sender
      * account.
      */
    constructor() public {
        manageable = true;
    }
    /**
      * @dev Throws if called by any account other than the owner.
      */
    modifier onlyTokenBookOwner() {
        address tokenBookOwner = tokenBook.owner();
        require(msg.sender == tokenBookOwner,"only owner");
        _;
    }

     /**
      * @dev Throws if called by any account other than token owner
      */
     modifier onlyOwners(uint addressKey) {
        _tokenBookAddress = tokenKey.addressKeyContract(addressKey);
        tokenID = tokenKey.addressKeyTokenID(addressKey);
        tokenOwner = _TokenBook(_tokenBookAddress).owners(tokenID);
        bool tokenBookOpperator = _TokenBook(_tokenBookAddress).operators(tokenOwner,msg.sender);
        bool opperator = operators[tokenOwner][msg.sender];

        require(msg.sender == _tokenBookAddress || msg.sender == tokenOwner || opperator || tokenBookOpperator, "only owners");
        _;
    }
    /**
      * @dev Throws if called by any account other than token owner
      */
     modifier onlyAccountOwners(uint accountKey) {
        _tokenBookAddress = tokenKey.accountKeyContract(accountKey);
        tokenID = tokenKey.accountKeyTokenID(accountKey);
        tokenOwner = _TokenBook(_tokenBookAddress).owners(tokenID);
        bool tokenBookOpperator = _TokenBook(_tokenBookAddress).operators(tokenOwner,msg.sender);
        bool opperator = operators[tokenOwner][msg.sender];

        require(msg.sender == tokenOwner || opperator || tokenBookOpperator, "only owners");
        _;
    }

    // /**
    //   * @dev Throws if called by any account other than token owner
    //   */
    //  modifier onlySubAccountOwners(uint subAccountKey) {
    //     _tokenBookAddress = tokenKey.subAccountKeyContract(subAccountKey);
    //     tokenID = tokenKey.subAccountKeyTokenID(subAccountKey);
    //     tokenOwner = _TokenBook(_tokenBookAddress).owners(tokenID);
    //     bool tokenBookOpperator = _TokenBook(_tokenBookAddress).operators(tokenOwner,msg.sender);
    //     bool opperator = operators[tokenOwner][msg.sender];

    //     require(msg.sender == tokenOwner || opperator || tokenBookOpperator, "only owners");
    //     _;
    // }

    /**
      * @dev Throws if called by any account other than the manager or admin.
      */
    modifier onlyManager(uint addressKey) {
        _tokenBookAddress = tokenKey.addressKeyContract(addressKey);
        tokenID = tokenKey.addressKeyTokenID(addressKey);
        tokenOwner = _TokenBook(_tokenBookAddress).owners(tokenID);
        uint managerKey = tokenKey.addressKeyCreate(msg.sender,0);
        require(managers[tokenOwner][addressKey][managerKey] == true || admins[tokenOwner][addressKey][managerKey] == true || msg.sender == tokenOwner, "only managers");
        _;
    }
     /**
      * @dev Throws if called by any account other than the admin.
      */
    modifier onlyAdmin(uint addressKey) {
        _tokenBookAddress = tokenKey.addressKeyContract(addressKey);
        tokenID = tokenKey.addressKeyTokenID(addressKey);
        tokenOwner = _TokenBook(_tokenBookAddress).owners(tokenID);
        uint adminKey = tokenKey.addressKeyCreate(msg.sender,0);
        require(admins[tokenOwner][addressKey][adminKey] == true || msg.sender == tokenOwner || msg.sender == _tokenBookAddress, "only admins");
        _;
    }
//      /**
//     * @dev Allows the current executive to transfer control of the contract to a newManager.
//     * @param newExecutive The address to transfer executiveship to.
//     */
//   function transferExecutiveship(address newExecutive) public onlyOwner() {
//     if (newExecutive != address(0)) {
//         executives[msg.sender] = false;
//         executives[newExecutive] = true;
//     }
// }


    // /**
    // * @dev Allows the current manager to transfer control of the contract to a newManager.
    // * @param newManager The address to transfer managership to.
    // */
    // function transferManagership(uint tokenID, address newManager) public onlyManager(tokenID) {
    //     if (newManager != address(0)) {
    //         address tokenOwner = tokenBook.owners(tokenID);
    //         managers[tokenOwner][tokenID][msg.sender] = false;
    //         managers[tokenOwner][tokenID][newManager] = true;
    //         emit updateManagerAccess(tokenID, msg.sender, false);
    //         emit updateManagerAccess(tokenID, newManager, true);

    //     }
    // }

    /**
    * @dev Allows the current admin to transfer control of the contract to a newAdmin. (for users)
    * @param newAdmin The address to transfer administorship to.
    */
    function updateAdmin(address addressX, uint _tokenID, address newAdmin, uint newAdminTokenID, bool isAdmin) public  {
        if (newAdmin != address(0) && addressX != address(0)) {
            uint addressKey = tokenKey.addressKeyCreate(addressX,_tokenID);
            uint newAdminKey = tokenKey.addressKeyCreate(newAdmin,newAdminTokenID);
            updateAdmin(addressKey,newAdminKey,isAdmin);
        }
    }
    /**
    * @dev Allows the current admin to transfer control of the contract to a newAdmin.
    * @param newAdminKey The addressKey to transfer administorship to.
    */
    function updateAdmin(uint addressKey, uint newAdminKey, bool isAdmin) public onlyOwners(addressKey) {
            admins[tokenOwner][addressKey][newAdminKey] = isAdmin;
            emit updateAdminAccess(addressKey, newAdminKey, isAdmin);
    }

    /**
    * @dev Allows the current manager to transfer control of the contract to a newManager. (for users)
    * @param newManager The address to transfer manageristorship to.
    */
    function updateManager(address addressX, uint _tokenID, address newManager, uint newManagerTokenID, bool isManager) public  {
        if (newManager != address(0) && addressX != address(0)) {
            uint addressKey = tokenKey.addressKeyCreate(addressX,_tokenID);
            uint newManagerKey = tokenKey.addressKeyCreate(newManager,newManagerTokenID);
            updateManager(addressKey,newManagerKey,isManager);
        }
    }
    /**
    * @dev Allows the current manager to transfer control of the contract to a newManager.
    * @param newManagerKey The addressKey to transfer manageristorship to.
    */
    function updateManager(uint addressKey, uint newManagerKey, bool isManager) public onlyAdmin(addressKey) {
            managers[tokenOwner][addressKey][newManagerKey] = isManager;
            emit updateManagerAccess(addressKey, newManagerKey, isManager);
    }

    /**
    * @dev Allows the current manager to transfer control of the contract to a newManager.
    * @param newManager The address to take managership to.
    */
    function transferManager(address addressX, uint _tokenID, address newManager, uint newManagerTokenID) public  {
        if (newManager != address(0) && addressX != address(0) ) {
            uint addressKey = tokenKey.addressKeyCreate(addressX,_tokenID);
            uint newManagerKey = tokenKey.addressKeyCreate(newManager,newManagerTokenID);
            transferManager(addressKey,newManagerKey);
        }
    }

    /**
    * @dev Allows the current manager to transfer control of the contract to a newManager.
    * @param newManagerKey The address key to take managership to.
    */
    function transferManager(uint addressKey, uint newManagerKey) public onlyManager(addressKey) {
            uint managerKey = tokenKey.addressKeyCreate(msg.sender,0);
            managers[tokenOwner][addressKey][managerKey] = false;
            managers[tokenOwner][addressKey][newManagerKey] = true;
            emit updateManagerAccess(addressKey, managerKey, false);
            emit updateManagerAccess(addressKey, newManagerKey, true);
    }
    // /**
    // * @dev Allows the current admin to transfer control of the contract to a newAdmin.
    // * @param newAdmin The address to transfer administorship to.
    // */
    // function transferAdministratorship(uint tokenID, address newAdmin) public onlyAdmin(tokenID) {
    //     if (newAdmin != address(0)) {
    //         address tokenOwner = tokenBook.owners(tokenID);
    //         admins[tokenOwner][tokenID][msg.sender] = false;
    //         admins[tokenOwner][tokenID][newAdmin] = true;
    //         emit updateAdminAccess(tokenID, msg.sender, false);
    //         emit updateAdminAccess(tokenID, newAdmin, true);
    //     }
    // }

    /**
    * @dev Allows the current admin to transfer control of the contract to a newAdmin. (for users)
    * @param newAdmin The address to transfer administorship to.
    */
    function updateAccountAdmin(address addressX, uint _tID, uint _aID, address newAdmin, uint adminTID, bool isAdmin) public  {
        if (newAdmin != address(0) && addressX != address(0)) {
            uint accountKey = tokenKey.accountKeyCreate(addressX,_tID,_aID);
            uint newAdminKey = tokenKey.addressKeyCreate(newAdmin,adminTID);
            updateAccountAdmin(accountKey,newAdminKey,isAdmin);
        }
    }
    /**
    * @dev Allows the current admin to transfer control of the contract to a newAccountAdmin.
    * @param newAccountAdminKey The accountKey to transfer administorship to.
    */
    function updateAccountAdmin(uint accountKey, uint newAccountAdminKey, bool isAdmin) public onlyAccountOwners(accountKey) {
            accountAdmins[tokenOwner][accountKey][newAccountAdminKey] = isAdmin;
            emit updateAccountAdminAccess(accountKey, newAccountAdminKey, isAdmin);
    }

    // /**
    // * @dev Allows the current admin to transfer control of the contract to a newAdmin. (for users)
    // * @param newAdmin The address to transfer administorship to.
    // */
    // function updateSubAccountAdmin(address addressX, uint _tID, uint _aID, uint _saID, address newAdmin, uint adminTID, bool isAdmin) public  {
    //     if (newAdmin != address(0) && addressX != address(0)) {
    //         uint subAccountKey = tokenKey.subAccountKeyCreate(addressX,_tID,_aID,_saID);
    //         uint newAdminKey = tokenKey.addressKeyCreate(newAdmin,adminTID);
    //         updateSubAccountAdmin(subAccountKey,newAdminKey,isAdmin);
    //     }
    // }
    // /**
    // * @dev Allows the current admin to transfer control of the contract to a newSubAccountAdmin.
    // * @param newSubAccountAdminKey The subAccountKey to transfer administorship to.
    // */
    // function updateSubAccountAdmin(uint subAccountKey, uint newSubAccountAdminKey, bool isAdmin) public onlyOwners(subAccountKey) {
    //         subAccountAdmins[tokenOwner][subAccountKey][newSubAccountAdminKey] = isAdmin;
    //         emit updateSubAccountAdminAccess(subAccountKey, newSubAccountAdminKey, isAdmin);
    // }


    // /**
    // * @dev Allows the current admin to take control of the contract to a oldAdmin.
    // * @param oldAdmin The address to take adminship to.
    // */
    // function removeAdmin(uint tokenID, address oldAdmin) public onlyOwners(tokenID) {
    //     if (oldAdmin != address(0)) {
    //         address tokenOwner = tokenBook.owners(tokenID);
    //         admins[tokenOwner][tokenID][oldAdmin] = false;
    //         emit updateAdminAccess(tokenID, oldAdmin, false);
    //     }
    // }
    // function setOffice(address _office) public onlyAdmin {
    //     if (_office != address(0)) {
    //         office = _office;
    //     }
    // }

    // function isAdmin(uint tokenID, address user) public view returns(bool) {
    //     address tokenOwner = tokenBook.owners(tokenID);
    //     if (admins[tokenOwner][tokenID][user] == true || tokenOwner == user ) {
    //       return true;
    //     }else{
    //       return false;
    //     }
    // }
    // function isManager(uint tokenID, address user) public view returns(bool) {
    //     address tokenOwner = tokenBook.owners(tokenID);
    //     if (admins[tokenOwner][tokenID][user] == true || managers[tokenOwner][tokenID][user] == true || tokenOwner == user ) {
    //       return true;
    //     }else{
    //       return false;
    //     }
    // }
    // function hasAdminPermission (address objectID, uint256 _tokenID, address sender, uint senderTID) public  view returns (bool) {
    //   Manageable object = Manageable(objectID);
    //   address _tokenOwner = object.owners(_tokenID);
    // //   bool onlyAdminPermission = hasOnlyAdminPermission(objectID, _tokenID,sender,senderTID);
    // //   bool permission = onlyAdminPermission || _tokenOwner == sender;
    // bool permission =  _tokenOwner == sender;
    //   return permission ;
    // }
    function hasOnlyAdminPermission (address objectID, uint256 _tokenID, address sender, uint senderTID) public  view returns (bool) {
      Manageable object = Manageable(objectID);
      address _tokenOwner = object.owners(_tokenID);
      bool addressKeySet = tokenKey.addressKeySet(objectID,_tokenID);
      bool senderKeySet = tokenKey.addressKeySet(sender,senderTID);
      require(addressKeySet,"addressKeySet not set");
      require(senderKeySet,"senderKeySet not set");

      uint addressKey = tokenKey.addressKey(objectID,_tokenID);
      uint senderKey = tokenKey.addressKey(sender,0); //NOTE this bit seems to make senderTID usless and misleading bekause its always set to 0 here. for now admins should only be users and not Contracts 
      bool permission = admins[_tokenOwner][addressKey][senderKey] == true;
      return permission ;
    }
    function hasOnlyAccountAdminPermission ( address objectID, uint256 _tokenID, uint256 _aID, address sender, uint senderTID) public  view returns (bool) {
      Manageable object = Manageable(objectID);
      address _tokenOwner = object.owners(_tokenID);
      bool accountKeySet = tokenKey.accountKeySet(objectID,_tokenID,_aID);
      bool senderKeySet = tokenKey.addressKeySet(sender,senderTID);
      require(accountKeySet,"accountKeySet not set");
      require(senderKeySet,"senderKeySet not set");

      uint addressKey = tokenKey.addressKey(objectID,_tokenID);
      uint accountKey = tokenKey.accountKey(objectID,_tokenID,_aID);
      uint senderKey = tokenKey.addressKey(sender,0);

      bool accountPermission = accountAdmins[_tokenOwner][accountKey][senderKey] == true; //make accountAdmins or update accountKey->address key
      bool adminPermission = admins[_tokenOwner][addressKey][senderKey] == true; //make accountAdmins or update accountKey->address key
      bool permission = accountPermission || adminPermission;
      
      return permission ;
    }
    // function hasPermission (uint256 tokenID, address objectID) public onlyManager(tokenID) view returns (bool) {
    //   Manageable object = Manageable(objectID);
    //   address tokenOwner = object.owners(tokenID);
    //   bool permission = admins[tokenOwner][tokenID][msg.sender] == true || managers[tokenOwner][tokenID][msg.sender] == true || tokenOwner == msg.sender;
    //   return permission ;
    // }

     


}
/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    emit Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    emit Unpause();
  }
}

contract TokenBookConfig is Ownable {



    mapping(uint => address) public contractAddresses;
    mapping(uint => uint) public contractUints;
    mapping(uint => bool) public contractBools;
    mapping(uint => string) public contractPages;

    mapping(uint => mapping (uint => address)) public tokenAddresses;
    mapping(uint => mapping (uint => uint)) public tokenUints;
    mapping(uint => mapping (uint => bool)) public tokenBools;
    mapping(uint => mapping (uint => string)) public tokenPages;

    event UpdateContractMetaAddress(uint metaDataIndex);
    event UpdateContractMetaUint(uint metaDataIndex);
    event UpdateContractMetaPage(uint metaDataIndex);
    event UpdateContractMetaBool(uint metaDataIndex);

    event UpdateTokenMetaAddress(uint tokenID, uint metaDataIndex);
    event UpdateTokenMetaUint(uint tokenID, uint metaDataIndex);
    event UpdateTokenMetaPage(uint tokenID, uint metaDataIndex);
    event UpdateTokenMetaBool(uint tokenID, uint metaDataIndex);

    /*
        addresses
            1. TokenBook
            2. TokenKey
            3. Manageable
            4. TokenMeta
            5. TetherBook
            6. TokenBank
            7. PaymentMethod
            8. ReceiptBook
            9. RewardsBook
            10. WothBook
            11. Owed
        uint
            1. basisPointsRate
            2. maximumFee
            3. bankID
            4. paymentMethodID
            5. paymentTokenID
            6. initSupply
        bools
            1. isTokenBookConfig
            2. hasRTOs
            3. hasStableTokens
        Pages
            1. terms and conditions

    */

    modifier onlyAdmins(uint tID) {
        require(address(0) != contractAddresses[1],"TokenBook address cant be zero");
        require(address(0) != contractAddresses[3],"Manageable address cant be zero");
        address tokenBookAddress = contractAddresses[1];
        Manageable manageable = Manageable(contractAddresses[3]);
        require(manageable.hasOnlyAdminPermission(tokenBookAddress,tID,msg.sender,0),"Admin of token can do this");
        _;
      }


    function updateContractMetaAddress(uint metaDataIndex, address metaData) external onlyOwner()  {
        contractAddresses[metaDataIndex] = metaData;
        emit UpdateContractMetaAddress(metaDataIndex);
    }
    function updateContractMetaUint(uint metaDataIndex, uint metaData) external onlyOwner()  {
        contractUints[metaDataIndex] = metaData;
        emit UpdateContractMetaUint(metaDataIndex);
    }
    function updateContractMetaBool(uint metaDataIndex, bool metaData) external onlyOwner()  {
        contractBools[metaDataIndex] = metaData;
        emit UpdateContractMetaBool(metaDataIndex);
    }
    function updateContractMetaPage(uint metaDataIndex, string calldata metaData) external onlyOwner()  {
        contractPages[metaDataIndex] = metaData;
        emit UpdateContractMetaPage(metaDataIndex);
    }


    function updateTokenMetaAddress(uint tokenID, uint metaDataIndex, address metaData) external onlyAdmins(tokenID)  {
        tokenAddresses[tokenID][metaDataIndex] = metaData;
        emit UpdateTokenMetaAddress(tokenID, metaDataIndex);
    }
    function updateTokenMetaUint(uint tokenID, uint metaDataIndex, uint metaData) external onlyAdmins(tokenID)  {
        tokenUints[tokenID][metaDataIndex] = metaData;
        emit UpdateTokenMetaUint(tokenID, metaDataIndex);
    }
    function updateTokenMetaBool(uint tokenID, uint metaDataIndex, bool metaData) external onlyAdmins(tokenID)  {
        tokenBools[tokenID][metaDataIndex] = metaData;
        emit UpdateTokenMetaBool(tokenID, metaDataIndex);
    }
    function updateTokenMetaPage(uint tokenID, uint metaDataIndex, string calldata metaData) external onlyAdmins(tokenID)  {
        tokenPages[tokenID][metaDataIndex] = metaData;
        emit UpdateTokenMetaPage(tokenID, metaDataIndex);
    }


}
/// manageable end

// meta start
contract MetaMap {
    mapping(uint => mapping (uint => string)) public metaMapJson;
    mapping(uint => uint) public metaMapPageCursor;
    mapping(uint => uint) public metaMapPageCnt;


    function addMetaMapPage(uint tokenID, string calldata metaData) external ;
    // function updateMetaMapPageCursor(uint newCursor) public;
    // function getMetaMapPage(uint metaDataIndex) external view returns(string);
    function updateMetaMapPage(uint tokenID, uint metaDataIndex, string calldata metaData) external;

}

contract Meta {
    mapping(uint => string) internal metaJson;
    uint public metaPageCursor; 
    uint public metaPages; 
    string public metaFormatUrl; 
    

    function setMetaFormatUrl(string calldata _metaFormatUrl) external ;
    function addMetaPage(string storage metaData) internal ;
    // function updateMetaPageCursor(uint newCursor) public;
    // function getMetaPage(uint metaDataIndex) external view returns(string);
    function updateMetaPage(uint metaDataIndex, string calldata metaData) external;
}
contract MetaAddress {
    mapping(uint => string) public metaAddress;
    uint public metaAddressCursor; 
    uint public metaAddressCnt; 
    // string public metaFormatUrl; 
    
// addresses
    // function addMetaAddress(address _metaAddress) internal ;
    // function updateMetaAddressCursor(uint newCursor) public;
    // function getMetaAddress(uint metaAddressIndex) external view returns(string);
    // function updateMetaAddress(uint metaAddressIndex, address _metaAddress) external;
}
contract TokenMeta  {
    mapping(uint => mapping (uint => string)) internal tokenMetaJson;
    mapping(uint => uint) public tokenMetaPageCursor;
    mapping(uint => uint) internal tokenMetaPages;
    function addTokenMetaPage(uint tokenID, string calldata metaData) external ;
    // function updateMetaPageCursor(uint newCursor) public;
    // function getMetaPage(uint metaDataIndex) external view returns(string);
    function updateTokenMetaPage(uint tokenID, uint metaDataIndex, string calldata metaData) external;
    
}
contract TokenMetaAddress  {

    mapping (uint => address) public tokenMetaAddress;
    uint public tokenMetaAddressCursor;
    uint public tokenMetaAddressCnt;

    function addTokenMetaAddress(address metaAddress) external ;
    // function updateMetaAddressCursor(uint newCursor) public;
    // function getMetaAddress(uint metaAddressIndex) external view returns(address);
    function updateTokenMetaAddress(uint metaAddressIndex, address metaAddress) external;
}

contract TokenMetaAddressTetherBook  {

    mapping(uint => mapping (uint => address)) public tokenMetaAddress;
    mapping(uint => uint) public tokenMetaAddressCursor;
    mapping(uint => uint) public tokenMetaAddressCnt;

    function addTokenMetaAddress(uint tokenID, address metaAddress) external ;
    // function updateMetaAddressCursor(uint newCursor) public;
    // function getMetaAddress(uint metaAddressIndex) external view returns(address);
    function updateTokenMetaAddress(uint tokenID, uint metaAddressIndex, address metaAddress) external;
}
// meta end

//start tokenBook
/// @title ERC-721 Non-Fungible Token Standard
/// @dev See https://github.com/ethereum/EIPs/blob/master/EIPS/eip-721.md
///  Note: the ERC-165 identifier for this interface is 0x80ac58cd
interface ERC721 /* is ERC165 */ {
    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    //done
    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view returns (uint256);

    //done
    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external payable;

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to ""
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;

    //done
    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable;

    //done
    /// @notice Set or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    /// @dev Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external payable;

    //done
    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets.
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators.
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external;

    //done
    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address);
    
    //done
    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);
}

interface ERC165 {
    /// @notice Query if a contract implements an interface
    /// @param interfaceID The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    ///  uses less than 30,000 gas.
    /// @return `true` if the contract implements `interfaceID` and
    ///  `interfaceID` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

interface ERC721TokenReceiver {
    /// @notice Handle the receipt of an NFT
    /// @dev The ERC721 smart contract calls this function on the
    /// recipient after a `transfer`. This function MAY throw to revert and reject the transfer. Return
    /// of other than the magic value MUST result in the transaction being reverted.
    /// @notice The contract address is always the message sender.
    /// @param _operator The address which called `safeTransferFrom` function
    /// @param _from The address which previously owned the token
    /// @param _tokenId The NFT identifier which is being transferred
    /// @param _data Additional data with no specified format
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
    /// unless throwing
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data) external returns(bytes4);
 }

 contract ERC721Receiver is ERC721TokenReceiver {
  /**
   * @dev Magic value to be returned upon successful reception of an NFT
   *  Equals to `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`,
   *  which can be also obtained as `ERC721Receiver(0).onERC721Received.selector`
   */
  bytes4 constant ERC721_RECEIVED = 0xf0b9e5ba;

  /**
   * @notice Handle the receipt of an NFT
   * @dev The ERC721 smart contract calls this function on the recipient
   *  after a `safetransfer`. This function MAY throw to revert and reject the
   *  transfer. This function MUST use 50,000 gas or less. Return of other
   *  than the magic value MUST result in the transaction being reverted.
   *  Note: the contract address is always the message sender.
   * @param _from The sending address
   * @param _tokenId The NFT identifier which is being transfered
   * @param _data Additional data with no specified format
   * @return `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`
   */
  function onERC721Received(address _from, uint256 _tokenId, bytes calldata _data) external returns(bytes4);
}

contract ERC721Holder is ERC721Receiver {
  function onERC721Received(address, uint256, bytes calldata) external returns(bytes4) {
    return ERC721_RECEIVED;
  }
  function onERC721Received(address,address, uint256, bytes calldata) external returns(bytes4) {
    return ERC721_RECEIVED;
  }
}

// /**
//  * @title Basic token
//  * @dev Basic version of StandardTokenBook, with no allowances.
//  */
contract BasicTokenBook is ERC721,Executive {
    using SafeMath for uint;

    mapping(address => uint) public balances;

    /**
    * @dev Fix for the ERC20 short address attack.
    */
    modifier onlyPayloadSize(uint size) {
        require(!(msg.data.length < size + 4));
        _;
    }

    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) external view returns (uint256) {
        return balances[_owner];
    }
    /**
    * @dev Gets the owner of the specified tokenId.
    * @param _tokenId The tokenId to query the the owner of.
    * @return An address representing the owner of the passed tokenId.
    */
   function ownerOf(uint256 _tokenId) external view returns (address owner) {
    return owners[_tokenId];
   }

}

contract StandardTokenBook is BasicTokenBook, ERC721Holder {
    uint public constant MAX_UINT = 2**256 - 1;
    
    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transfer(address _from, address _to, uint256 _tokenId) internal  {
        address allowedUser = allowed[_tokenId];
        address tokenOwner = owners[_tokenId];
        bool operator = operators[tokenOwner][msg.sender];
        // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
        require(allowedUser == msg.sender  || operator || tokenOwner == msg.sender );
        require(tokenOwner == _from);
        allowed[_tokenId] = msg.sender;
        owners[_tokenId] = _to;
        balances[_from] = balances[_from].sub(1);
        balances[_to] = balances[_to].add(1);
        emit Transfer(_from, _to, _tokenId);
    }

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(address _from, address _to, uint256 _tokenId) external payable {
        transfer( _from, _to, _tokenId);
    }
    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata data) external payable{
        transfer( _from, _to, _tokenId);
        require(checkAndCallSafeTransfer(_from, _to, _tokenId, data)); 
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to ""
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable {
        transfer( _from, _to, _tokenId);
    }

    function checkAndCallSafeTransfer(address _from, address _to, uint256 _tokenId, bytes memory _data) internal returns (bool) {
        bool _isContact = isContract(_to);
        if (!_isContact) {
        return true; }
        bytes4 retval = ERC721Receiver(_to).onERC721Received(_from, _tokenId, _data);
        return (retval == ERC721_RECEIVED); 
    }
    //From AddressUtils.sol library
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    * @param _approved The address which will spend the funds.
    * @param _tokenId Token id user is appoved to for.
    */
    function approve(address _approved, uint256 _tokenId) external payable {
        address allowedUser = allowed[_tokenId];
        address tokenOwner = owners[_tokenId];
        bool operator = operators[tokenOwner][msg.sender];
        require(allowedUser == msg.sender  || operator || tokenOwner == msg.sender );
        allowed[_tokenId] = _approved;
        // Approval(msg.sender, _spender, );
    }

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view returns (address allowedUser) {
        return allowed[_tokenId];
    }
}
contract UpgradedStandardTokenBook is StandardTokenBook{
    // those methods are called by the legacy contract
    // and they must ensure msg.sender to be the contract address
    function transferByLegacy(address from, address to, uint value) public;
    function transferFromByLegacy(address sender, address from, address spender, uint value) public;
    function approveByLegacy(address from, address spender, uint value) public;
}
contract TokenBook is StandardTokenBook {
    string public name;
    string public url;
    address public upgradedAddress;
    bool public deprecated;
    mapping(uint => string) public tokens;
    string private metaDataStorage;
    mapping(uint => bool) public verifiedToken;
    mapping(uint => mapping (uint => bool)) public verifiedTokenMeta;
    uint public tokenCnt;
    address public tokenBookConfigAddress;
    TokenBookConfig public tokenBookConfig;
    address public manageableAddress;
    address public tokenMetaAddress;
    Manageable internal manageable;

        /// @dev This emits when token is added
    event AddToken(address indexed tokenOwner, address indexed tokenAdmin, address indexed tokenManager,  uint tokenID);
    event UpdateToken(uint tokenID);
    event UpdateMetaPage(uint tokenID);
    event UpdateTokenMetaPage(uint tokenID, uint tokenMetaID);
    event AddTokenMetaPage(uint tokenID, uint tokenMetaID);
    event VerifyToken(uint tokenID, bool verified);
    event VerifyTokenMeta(uint tokenID, uint tokenMetaPage, bool verified);
    event Config(address indexed tokenBookConfigAddress, address indexed manageableAddress, address indexed tokenMetaAddress);

 

    constructor(string memory title, string memory tokenBookUrl) public {
        name = title;
        url = tokenBookUrl;

    }
    function updateInfo(string memory title, string memory tokenBookUrl) public onlyOwner {
        name = title;
        url = tokenBookUrl;
    }



/*
    //  The contract can be initialized with a number of tokens
    //  All the tokens are deposited to the owner address
    //
    // @param _balance Initial supply of the contract
    // @param _name Token Name
    // @param _symbol Token symbol
    // @param _decimals Token decimals
    constructor(string memory _name) public {
        ///name = _name;
        ///deprecated = false;
        ///tokenCnt++;
    }
*/

    function config(address newTokenBookConfigAddress) public onlyOwner  {
        tokenBookConfig = TokenBookConfig(newTokenBookConfigAddress);
        tokenBookConfigAddress = newTokenBookConfigAddress;
        address newManageableAddress = tokenBookConfig.contractAddresses(3);
        address newTokenMetaAddress = tokenBookConfig.contractAddresses(10);
        manageableAddress = newManageableAddress;
        tokenMetaAddress = newTokenMetaAddress;
        manageable = Manageable(newManageableAddress);
        //need to set ManableAddress 
        // need to set Token Meta Address
        emit Config(tokenBookConfigAddress,manageableAddress,tokenMetaAddress);
    }

    // /**
    //   * @dev Throws if called by any account other than the manager or admin.
    //   */
    //   modifier onlyExecutives() {
    //       bool executive = manageable.executives(address(this),msg.sender);
    //       require(executive || msg.sender == owner,"only executives");
    //       _;
    //   }

    modifier onlyHasTokenAccess(uint tokenID) {
        address allowedUser = allowed[tokenID];
        address tokenOwner = owners[tokenID];
        bool operator = operators[tokenOwner][msg.sender];
        // bool manager = managers[tokenOwner][tokenID][msg.sender];
        // bool admin = admins[tokenOwner][tokenID][msg.sender];
        bool _isPublic = isPublic[tokenID];
        // bool allowedUser;
        // Manageable permission = Manageable(allowedUsers);
        // if(permission.manageable() ==  true){
        //     allowedUser =  permission.admins(msg.sender) || permission.managers(msg.sender);
        // }else{
        //     allowedUser = msg.sender == allowedUsers;
        // }
        // HasPermission(msg.sender, allowedUsers, allowedUser);
        // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
        // require(allowedUser == msg.sender  || operator || tokenOwner == msg.sender || manager || admin || _isPublic);
        require(allowedUser == msg.sender  || operator || tokenOwner == msg.sender  || _isPublic);
        _;
    }
    // Meta permissions
    
    // function updateMetaPageCursor(uint newCursor) public onlyOwner {
    //     tokenCnt = newCursor;
    //     metaPages = newCursor; 
    // }
    function addToken(address tokenOwner,address tokenAdmin,address tokenManager, string calldata tokenData, string calldata metaData) external onlyExecutives(address(this)){
        tokens[tokenCnt] = tokenData;
        balances[tokenOwner] = balances[tokenOwner].add(1);
        owners[tokenCnt] = tokenOwner;
        // managers[tokenOwner][tokenCnt][tokenManager] = true;
        // admins[tokenOwner][tokenCnt][tokenAdmin] = true;
        manageable.updateAdmin(address(this), tokenCnt, tokenAdmin, 0, true);
        manageable.updateManager(address(this), tokenCnt, tokenManager, 0, true);
        metaDataStorage = metaData;
        tokenCnt++;
        emit AddToken(tokenOwner,tokenAdmin, tokenManager,tokenCnt);
        // addMetaPage(metaDataStorage);
    
    }
    function verifyToken(uint metaDataIndex, bool verified ) external onlyExecutives(address(this)) {
        verifiedToken[metaDataIndex] = verified;
        emit VerifyToken(metaDataIndex, verified);
    }
    function verifyTokenMeta(uint metaDataIndex, uint tokenMetaPage, bool verified ) external onlyExecutives(address(this)) {
        verifiedTokenMeta[metaDataIndex][tokenMetaPage] = verified;
         emit VerifyTokenMeta(metaDataIndex, tokenMetaPage, verified);
    }

        // function updateToken(uint metaDataIndex, string calldata tokenData) external onlyAdmin(metaDataIndex){
    //     tokens[metaDataIndex] = tokenData;
    //     emit UpdateToken(metaDataIndex);

    // }
    // function addMetaPage(string storage metaData) internal {
    //     metaJson[tokenCnt] = metaData;
    //     tokenCnt++;
    //     metaPages = tokenCnt;
    // }
    // function updateMetaPage(uint metaDataIndex, string calldata metaData) external onlyManager(metaDataIndex)  {
    //     metaJson[metaDataIndex] = metaData;
    //     emit UpdateMetaPage(metaDataIndex);
    // }
    // function getMetaPage(uint metaDataIndex) external view onlyHasTokenAccess(metaDataIndex) returns(string memory) {
    //     return metaJson[metaDataIndex];
    // }
    // function addTokenMetaPage(uint metaDataIndex, string calldata metaData) external onlyAdmin(metaDataIndex) {
    //     uint tokenPageCursor = tokenMetaPageCursor[metaDataIndex];
    //     tokenMetaJson[metaDataIndex][tokenPageCursor] = metaData;
    //     emit AddTokenMetaPage(metaDataIndex, tokenPageCursor);
    //     tokenPageCursor++;
    //     tokenMetaPages[metaDataIndex] = tokenPageCursor;
    //     tokenMetaPageCursor[metaDataIndex] = tokenPageCursor;
    // }
    // function updateTokenMetaPage(uint metaDataIndex, uint tokenMetaPage, string calldata metaData) external onlyManager(metaDataIndex)  {
    //     tokenMetaJson[metaDataIndex][tokenMetaPage] = metaData;
    //     emit UpdateTokenMetaPage(metaDataIndex, tokenMetaPage);
    // }
    // function getTokenMetaPage(uint metaDataIndex, uint tokenMetaPage) external view onlyHasTokenAccess(metaDataIndex) returns(string memory) {
    //     return tokenMetaJson[metaDataIndex][tokenMetaPage];
    // }
    // function payment(uint256 methodIndex, address _from, uint amount) public returns (bool) {
        // thisAllowanceBalance
        // paymentBalance


    // // Forward ERC20 methods to upgraded contract if this one is deprecated
    // function transferFrom(address _from, address _to, uint _value) public  {
    //     // require(!isBlackListed[_from]);
    //     if (deprecated) {
    //         return UpgradedStandardTokenBook(upgradedAddress).transferFromByLegacy(msg.sender, _from, _to, _value);
    //     } else {
    //         return super.transferFrom(_from, _to, _value);
    //     }
    // }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    // function balanceOf(address who) external view returns (uint256) {
    //     if (deprecated) {
    //         return UpgradedStandardTokenBook(upgradedAddress).balanceOf(who);
    //     } else {
    //         return super.balanceOf(who);
    //     }
    // }

    // // Forward ERC20 methods to upgraded contract if this one is deprecated
    // function ownerOf(uint256 _tokenId) public view returns (address) {
    //     if (deprecated) {
    //         return UpgradedStandardTokenBook(upgradedAddress).ownerOf(_tokenId);
    //     } else {
    //         return super.ownerOf(_tokenId);
    //     }
    // }

    // // Forward ERC20 methods to upgraded contract if this one is deprecated
    // function approve(address _spender, uint _value) public onlyPayloadSize(2 * 32) {
    //     if (deprecated) {
    //         return UpgradedStandardTokenBook(upgradedAddress).approveByLegacy(msg.sender, _spender, _value);
    //     } else {
    //         return super.approve(_spender, _value);
    //     }
    // }

    // // deprecate current contract in favour of a new one
    // function deprecate(address _upgradedAddress) public onlyOwner {
    //     deprecated = true;
    //     upgradedAddress = _upgradedAddress;
    //     // Deprecate(_upgradedAddress);
    // }


}
// end tokenBook

// start tokenKey
contract TokenKey is Ownable {
   struct _tokenAddressKey{
        string name;
        uint keyCnt;
        mapping (address => mapping (uint => bool)) keySet; //Maps addresses to index in `tests
        mapping (address => mapping (uint => uint)) key; //Maps addresses to index in `tests
    }
    struct _tokenAccountKey{
        string name;
        uint keyCnt;
        mapping (uint => mapping (uint => bool)) keySet; //Maps addresses to index in `tests
        mapping (uint => mapping (uint => uint)) key; //Maps addresses to index in `tests
    }
    _tokenAddressKey _addressKey ;
    _tokenAccountKey _accountKey ;
    _tokenAccountKey _subAccountKey ;

     mapping (uint => address)  public addressKeyContract;
     mapping (uint => uint)  public addressKeyTokenID;

     mapping (uint => address)  public accountKeyContract;
     mapping (uint => uint)  public accountKeyTokenID;
     mapping (uint => uint)  public accountKeyAccountID;

     mapping (uint => address)  public subAccountKeyContract;
     mapping (uint => uint)  public subAccountKeyTokenID;
     mapping (uint => uint)  public subAccountKeyAccountID;
     mapping (uint => uint)  public subAccountKeySubAccountID;

     Manageable internal manageable;
     address public manageableAddress;
     TokenBookConfig tokenBookConfig;
     address public tokenBookConfigAddress;

    event Config(address indexed newManageableAddress);

     /**
      * @dev Throws if called by any account other than the manager or admin.
      */
      modifier onlyExecutives() {
          bool executive = manageable.executives(address(this),msg.sender);
          require(executive || msg.sender == owner,"only executives");
          _;
      }

      function config(address newTokenBookConfigAddress) public onlyOwner  {
            tokenBookConfig = TokenBookConfig(newTokenBookConfigAddress);
            tokenBookConfigAddress = newTokenBookConfigAddress;
            address newManageableAddress = tokenBookConfig.contractAddresses(3);
            manageableAddress = newManageableAddress;
            manageable = Manageable(newManageableAddress);
            emit Config(manageableAddress);
      }


    function addressKey(address tokenAddress, uint tokenID ) public view returns (uint) {
         bool isKeySet = _addressKey.keySet[tokenAddress][tokenID];
         require(isKeySet,"TokenKey Error: addressKey not set");
         uint addressKeyX = _addressKey.key[tokenAddress][tokenID];
         return addressKeyX;
    }
    function accountKey(address tokenAddress, uint tokenID, uint accountID ) public view returns (uint) {
         uint tokenAddressKey = addressKey(tokenAddress, tokenID);
         bool isKeySet = _accountKey.keySet[tokenAddressKey][accountID];
         require(isKeySet,"TokenKey Error: accountKey not set");
         uint  accountKeyX = _accountKey.key[tokenAddressKey][accountID];
         return accountKeyX;
    }
    function subAccountKey(address tokenAddress, uint tokenID, uint accountID, uint subAccountID  ) public view returns (uint) {
         uint tokenAccountKey = accountKey(tokenAddress, tokenID,accountID);
         bool isKeySet = _subAccountKey.keySet[tokenAccountKey][subAccountID];
         require(isKeySet,"TokenKey Error: subAccountKey not set");
         uint subAccountKeyX = _subAccountKey.key[tokenAccountKey][subAccountID];
         return subAccountKeyX;
    }
    function addressKeySet(address tokenAddress, uint tokenID ) public view returns (bool) {
         bool isKeySet = _addressKey.keySet[tokenAddress][tokenID];
         return isKeySet;
    }
    function accountKeySet(address tokenAddress, uint tokenID, uint accountID ) public view returns (bool) {
         bool isAddressKeySet = addressKeySet(tokenAddress,tokenID);
         bool isKeySet;
         if(isAddressKeySet){
             uint tokenAddressKey = addressKey(tokenAddress, tokenID);
             isKeySet = _accountKey.keySet[tokenAddressKey][accountID];
         }else{
             isKeySet = false;
         }
         return isKeySet;
    }

    function subAccountKeySet(address tokenAddress, uint tokenID, uint accountID, uint subAccountID  ) public view returns (bool) {
         bool isAccountKeySet = accountKeySet(tokenAddress,tokenID,accountID);
         bool isKeySet;
         if(isAccountKeySet){
            uint tokenAccountKey = accountKey(tokenAddress, tokenID,accountID);
            isKeySet = _subAccountKey.keySet[tokenAccountKey][subAccountID];
         }else{
             isKeySet = false;
         }
         return isKeySet;
    }
    function addressKeyCreate(address tokenAddress, uint tokenID ) public onlyExecutives  returns (uint) {
         bool isKeySet = _addressKey.keySet[tokenAddress][tokenID];
         uint addressKeyX;
         if(isKeySet){
            addressKeyX = _addressKey.key[tokenAddress][tokenID];
         }else{
            _addressKey.keyCnt++;
            uint keyCntX = _addressKey.keyCnt;
           _addressKey.key[tokenAddress][tokenID] = keyCntX;
           _addressKey.keySet[tokenAddress][tokenID] = true;
           addressKeyX = _addressKey.key[tokenAddress][tokenID];
           addressKeyContract[keyCntX] = tokenAddress;
           addressKeyTokenID[keyCntX] = tokenID;
         }
         return addressKeyX;
    }
    function accountKeyCreate(address tokenAddress, uint tokenID, uint accountID ) public onlyExecutives  returns (uint) {
         uint tokenAddressKey = addressKeyCreate(tokenAddress, tokenID);
         bool isKeySet = _accountKey.keySet[tokenAddressKey][accountID];
         uint accountKeyX;
         if(isKeySet){
           accountKeyX = _accountKey.key[tokenAddressKey][accountID];
         }else{
           _accountKey.keyCnt++;
           uint keyCntX = _accountKey.keyCnt;
           _accountKey.key[tokenAddressKey][accountID] = keyCntX;
           _accountKey.keySet[tokenAddressKey][accountID] = true;
           accountKeyX = _accountKey.key[tokenAddressKey][accountID];
           accountKeyContract[keyCntX] = tokenAddress;
           accountKeyTokenID[keyCntX] = tokenID;
           accountKeyAccountID[keyCntX] = accountID;
         }
         return accountKeyX;
    }
    function subAccountKeyCreate(address tokenAddress, uint tokenID, uint accountID, uint subAccountID  ) public onlyExecutives  returns (uint) {
         uint tokenAccountKey = accountKeyCreate(tokenAddress, tokenID,accountID);
         bool isKeySet = _subAccountKey.keySet[tokenAccountKey][subAccountID];
         uint subAccountKeyX;
         if(isKeySet){
             subAccountKeyX = _subAccountKey.key[tokenAccountKey][subAccountID];
         }else{
            _subAccountKey.keyCnt++;
            uint keyCntX = _subAccountKey.keyCnt;
           _subAccountKey.key[tokenAccountKey][subAccountID] = keyCntX;
           _subAccountKey.keySet[tokenAccountKey][subAccountID] = true;
           subAccountKeyX = _subAccountKey.key[tokenAccountKey][subAccountID];

           subAccountKeyContract[keyCntX] = tokenAddress;
           subAccountKeyTokenID[keyCntX] = tokenID;
           subAccountKeyAccountID[keyCntX] = accountID;
           subAccountKeySubAccountID[keyCntX] = subAccountID;
        }
        return subAccountKeyX;
    }
}
// end tokenKey

// tetherBook start
/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20Basic {
    uint public _totalSupply; 
    function totalSupply() public view returns (uint);
    function balanceOf(address who) public view returns (uint);
    function transfer(address to, uint value) public;
    event Transfer(address indexed from, address indexed to, uint value);
}
contract ERC20BasicTetherBook {
    mapping(uint => uint) public _totalSupply; 
    function totalSupply(uint tokenID) public view returns (uint);
    function balanceOf(uint tokenID, address who) public view returns (uint);
    function transfer(uint tokenID, address to, uint value) public;
    event Transfer(uint indexed tokenID, address indexed from, address indexed to, uint value);
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public view returns (uint);
    function transferFrom(address from, address to, uint value) public;
    function approve(address spender, uint value) public;
    event Approval(address indexed owner, address indexed spender, uint value);
}
contract ERC20TetherBook is ERC20BasicTetherBook {
    function allowance(uint tokenID, address owner, address spender) public view returns (uint);
    function transferFrom(uint tokenID, address from, address to, uint value) public;
    function approve(uint tokenID, address spender, uint value) public;
    event Approval(uint indexed tokenID, address indexed owner, address indexed spender, uint value);
}

/**
 * @title Bank interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract Bank  {
        uint public totalPaymentCnt;
    uint public paymentMethodCnt;
    TetherBook public tetherBook;
    address public tetherBookAddress;
    TokenRewards public tokenRewards;
    address public tokenRewardsAddress;

    PaymentMethods public paymentMethods;
    address public paymentMethodsAddress;
    
    TokenKey public tokenKey;
    address public tokenKeyAddress;

    address public worthBookAddress;
    Manageable public manageable;
    address public manageableAddress;
    ReceiptBook public receiptBook;
    address public receiptBookAddress;
    // mapping(uint => Tether) public bank.paymentMethods; //[payOutCnt][ownerAddress] = payment
    mapping(uint => Tether) public tethers; //[payOutCnt][ownerAddress] = payment
     mapping(uint => TetherBook) public tetherBooks; //[payOutCnt][ownerAddress] = payment
    mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public totalPayments;
    //balances[tokenID][accountID][paymentMethodAddress][paymentTokenID] = accountBalance
     mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public accountBalance;
     //balances[tokenID][paymentMethodAddress][paymentTokenID] = totalBalance
     mapping(uint => mapping(address => mapping(uint => uint) ) ) public totalBalance;
    // function payOut(uint tID, uint aID, address sC, uint ptID, address pay_to, uint amount, string memory note) public;
    function payment(address paymentMethod, address _from, uint amount, string memory note) public returns (bool);
    function preTransfer(uint tokenID, address from, address to) public;
    function postTransfer(uint tokenID, address from, address to) public;

    function payOut(uint tID, uint aID, address sC, uint ptID, address pay_to, uint a, string memory note ) public  returns (bool);
    function internalTransfer(uint fromAccount, uint paymentAddressKey, uint toAccount, uint a, string memory n ) public  returns (bool);
}

// /**
//  * @title Basic token
//  * @dev Basic version of StandardToken, with no allowances.
//  */
contract BasicToken is Ownable, ERC20Basic {
    using SafeMath for uint;
    bool public isDepletable;

    mapping(address => uint) public balances;

    // additional variables for use if transaction fees ever became necessary
    uint public basisPointsRate;
    uint public maximumFee;

    event BalanceCheck(address indexed from,uint from_balance, address indexed to, uint to_balance);
    /**
    * @dev Fix for the ERC20 short address attack.
    */
    modifier onlyPayloadSize(uint size) {
        require(!(msg.data.length < size + 4));
        _;
    }

    /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint _value) public onlyPayloadSize(2 * 32) {
        // TODO enable
        // dividends.payOwnerTransfer(this, msg.sender, _to); 
        uint fee = (_value.mul(basisPointsRate)).div(10000);
        if (fee > maximumFee) {
            fee = maximumFee;
        }
        uint sendAmount = _value.sub(fee);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(sendAmount);
        if (fee > 0) {
            balances[owner] = balances[owner].add(fee);
            emit Transfer(msg.sender, owner, fee);
        }
        // TODO enable
        // dividends.updateTransferTokens(this, msg.sender, _to); 
        emit Transfer(msg.sender, _to, sendAmount);

    }
    function transferFee(uint _value) public view onlyPayloadSize(2 * 32) returns (uint) {
        uint fee = (_value.mul(basisPointsRate)).div(10000);
        if (fee > maximumFee) {
            fee = maximumFee;
        }
        return fee;
    }
    function sendAmount(uint _value)public view  onlyPayloadSize(2 * 32) returns (uint) {
       uint fee = transferFee(_value);
        uint amount = _value.sub(fee);
        return amount;
    }
    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint representing the amount owned by the passed address.
    */
    function balanceOf(address _owner) public view returns (uint balance) {
        return balances[_owner];
    }

}
// contract BasicToken is Stock, ERC20Basic {
contract BasicTokenTetherBook is Ownable, ERC20BasicTetherBook {
    using SafeMath for uint;
    mapping(uint => bool) public isDepletable;

    mapping(uint => mapping(address => uint)) public balances;

    // additional variables for use if transaction fees ever became necessary
    mapping(uint => uint) public basisPointsRate;
    mapping(uint => uint) public maximumFee;

    event BalanceCheck(uint token_id, address indexed from,uint from_balance, address indexed to, uint to_balance);
    /**
    * @dev Fix for the ERC20 short address attack.
    */
    modifier onlyPayloadSize(uint size) {
        require(!(msg.data.length < size + 4));
        _;
    }

    /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
    function transfer(uint tokenID, address _to, uint _value) public onlyPayloadSize(2 * 32) {
        // TODO enable
        // dividends.payOwnerTransfer(this, msg.sender, _to); 
        uint fee = (_value.mul(basisPointsRate[tokenID])).div(10000);
        if (fee > maximumFee[tokenID]) {
            fee = maximumFee[tokenID];
        }
        uint sendAmount = _value.sub(fee);
        balances[tokenID][msg.sender] = balances[tokenID][msg.sender].sub(_value);
        balances[tokenID][_to] = balances[tokenID][_to].add(sendAmount);
        if (fee > 0) {
            balances[tokenID][owner] = balances[tokenID][owner].add(fee);
            emit Transfer(tokenID, msg.sender, owner, fee);
        }
        // TODO enable
        // dividends.updateTransferTokens(this, msg.sender, _to); 
        emit Transfer(tokenID, msg.sender, _to, sendAmount);

    }
    function transferFee(uint tokenID, uint _value) public view onlyPayloadSize(2 * 32) returns (uint) {
        uint fee = (_value.mul(basisPointsRate[tokenID])).div(10000);
        if (fee > maximumFee[tokenID]) {
            fee = maximumFee[tokenID];
        }
        return fee;
    }
    function sendAmount(uint tokenID, uint _value)public view  onlyPayloadSize(2 * 32) returns (uint) {
       uint fee = transferFee(tokenID,  _value);
        uint amount = _value.sub(fee);
        return amount;
    }
    /**
    * @dev Gets the balance of the specified address.
    * @param _owner The address to query the the balance of.
    * @return An uint representing the amount owned by the passed address.
    */
    function balanceOf(uint tokenID, address _owner) public view returns (uint balance) {
        return balances[tokenID][_owner];
    }

}

// /**
//  * @title Standard ERC20 token
//  *
//  * @dev Implementation of the basic standard token.
//  * @dev https://github.com/ethereum/EIPs/issues/20
//  * @dev Based oncode by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
//  */
contract StandardToken is BasicToken, ERC20 {

    mapping (address => mapping (address => uint)) public allowed;

    uint public constant MAX_UINT = 2**256 - 1;

    /**
    * @dev Transfer tokens from one address to another
    * @param _from address The address which you want to send tokens from
    * @param _to address The address which you want to transfer to
    * @param _value uint the amount of tokens to be transferred
    */
    function transferFrom(address _from, address _to, uint _value) public onlyPayloadSize(3 * 32) {
        uint _allowance = allowed[_from][msg.sender];
        // TODO enable
        // dividends.payOwnerTransfer(this, _from, _to);
        // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
        // if (_value > _allowance) throw;
        uint fee = (_value.mul(basisPointsRate)).div(10000);
        if (fee > maximumFee) {
            fee = maximumFee;
        }
        if (_allowance < MAX_UINT) {
            allowed[_from][msg.sender] = _allowance.sub(_value);
        }
        uint sendAmount = _value.sub(fee);
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(sendAmount);
        if (fee > 0) {
            balances[owner] = balances[owner].add(fee);
            emit Transfer(_from, owner, fee);
        } 
        // TODO enable
        // dividends.updateTransferTokens(this, msg.sender, _to);
        emit Transfer(_from, _to, sendAmount);
    }

    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    * @param _spender The address which will spend the funds.
    * @param _value The amount of tokens to be spent.
    */
    function approve(address _spender, uint _value) public onlyPayloadSize(2 * 32) {

        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require(!((_value != 0) && (allowed[msg.sender][_spender] != 0)));

        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
    }

    /**
    * @dev Function to check the amount of tokens than an owner allowed to a spender.
    * @param _owner address The address which owns the funds.
    * @param _spender address The address which will spend the funds.
    * @return A uint specifying the amount of tokens still available for the spender.
    */
    function allowance(address _owner, address _spender) public view returns (uint remaining) {
        return allowed[_owner][_spender];
    }

}
contract StandardTokenTetherBook is BasicTokenTetherBook, ERC20TetherBook {

    mapping (uint => mapping (address => mapping (address => uint)) ) public allowed;

    uint public constant MAX_UINT = 2**256 - 1;

    /**
    * @dev Transfer tokens from one address to another
    * @param _from address The address which you want to send tokens from
    * @param _to address The address which you want to transfer to
    * @param _value uint the amount of tokens to be transferred
    */
    function transferFrom(uint tokenID, address _from, address _to, uint _value) public onlyPayloadSize(3 * 32) {
        uint _allowance = allowed[tokenID][_from][msg.sender];
        // TODO enable
        // dividends.payOwnerTransfer(this, _from, _to);
        // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
        // if (_value > _allowance) throw;
        uint fee = (_value.mul(basisPointsRate[tokenID])).div(10000);
        if (fee > maximumFee[tokenID]) {
            fee = maximumFee[tokenID];
        }
        if (_allowance < MAX_UINT) {
            allowed[tokenID][_from][msg.sender] = _allowance.sub(_value);
        }
        uint sendAmount = _value.sub(fee);
        balances[tokenID][_from] = balances[tokenID][_from].sub(_value);
        balances[tokenID][_to] = balances[tokenID][_to].add(sendAmount);
        if (fee > 0) {
            balances[tokenID][owner] = balances[tokenID][owner].add(fee);
            emit Transfer(tokenID, _from, owner, fee);
        } 
        // TODO enable
        // dividends.updateTransferTokens(this, msg.sender, _to);
        emit Transfer(tokenID, _from, _to, sendAmount);
    }

    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    * @param _spender The address which will spend the funds.
    * @param _value The amount of tokens to be spent.
    */
    function approve(uint tokenID, address _spender, uint _value) public onlyPayloadSize(2 * 32) {

        // To change the approve amount you first have to reduce the addresses`
        //  allowance to zero by calling `approve(_spender, 0)` if it is not
        //  already 0 to mitigate the race condition described here:
        //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
        require(!((_value != 0) && (allowed[tokenID][msg.sender][_spender] != 0)));

        allowed[tokenID][msg.sender][_spender] = _value;
        emit Approval(tokenID, msg.sender, _spender, _value);
    }

    /**
    * @dev Function to check the amount of tokens than an owner allowed to a spender.
    * @param _owner address The address which owns the funds.
    * @param _spender address The address which will spend the funds.
    * @return A uint specifying the amount of tokens still available for the spender.
    */
    function allowance(uint tokenID, address _owner, address _spender) public view returns (uint remaining) {
        return allowed[tokenID][_owner][_spender];
    }

}

// /**
//  * @title Meta ERC20 token
//  *
//  * @dev Implementation of the basic standard token.
//  * @dev https://github.com/ethereum/EIPs/issues/20
//  * @dev Based oncode by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
//  */

contract MetaToken is StandardToken, TokenMetaAddress {

    // event UpdateTokenMetaPage(uint tokenMetaID);
    // event AddTokenMetaPage(uint tokenMetaID);
    event UpdateTokenMetaAddress(uint tokenMetaID);
    event AddTokenMetaAddress(uint tokenMetaID);
    // event UpdateMetaMapPage(uint tokenMetaID);
    // event AddMetaMapPage(uint tokenMetaID);

    // modifier onlyHasTokenAccess() {
    //     // address allowedUser = allowed;
    //     address tokenOwner = owner;
    //     bool operator = operators[tokenOwner][msg.sender];
    //     bool manager = managers[tokenOwner][msg.sender];
    //     bool admin = admins[tokenOwner][msg.sender];
    //     // bool _isPublic = isPublic;
    //     // bool allowedUser;
    //     // Manageable permission = Manageable(allowedUsers);
    //     // if(permission.manageable() ==  true){
    //     //     allowedUser =  permission.admins(msg.sender) || permission.managers(msg.sender);
    //     // }else{
    //     //     allowedUser = msg.sender == allowedUsers;
    //     // }
    //     // HasPermission(msg.sender, allowedUsers, allowedUser);
    //     // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    //     require(operator || tokenOwner == msg.sender || manager || admin );
    //     _;
    // }

    // function addTokenMetaPage(uint tokenID, string calldata metaData) external onlyOwners(tokenID) {
    //     uint tokenPageCursor = tokenMetaPageCursor[tokenID];
    //     tokenMetaJson[tokenID][tokenPageCursor] = metaData;
    //     emit AddTokenMetaPage(tokenID, tokenPageCursor);
    //     tokenPageCursor++;
    //     tokenMetaPages[tokenID] = tokenPageCursor;
    //     tokenMetaPageCursor[tokenID] = tokenPageCursor;
    // }
    // function updateTokenMetaPage(uint tokenID, uint tokenMetaPage, string calldata metaData) external onlyOwner(tokenID)  {
    //     tokenMetaJson[tokenID][tokenMetaPage] = metaData;
    //     emit UpdateTokenMetaPage(tokenID, tokenMetaPage);
    // }
    // function getTokenMetaPage(uint tokenID, uint tokenMetaPage) external view onlyHasTokenAccess(tokenID) returns(string memory) {
    //     return tokenMetaJson[tokenID][tokenMetaPage];
    // }

    function addTokenMetaAddress(address metaAddress) external onlyOwner {
        uint tokenAddressCursor = tokenMetaAddressCursor;
        tokenMetaAddress[tokenAddressCursor] = metaAddress;
        emit AddTokenMetaAddress(tokenAddressCursor);
        tokenAddressCursor++;
        tokenMetaAddressCnt = tokenAddressCursor;
        tokenMetaAddressCursor = tokenAddressCursor;
    }
    function updateTokenMetaAddress(uint metaIndex, address metaAddress) external onlyOwner  {
        tokenMetaAddress[metaIndex] = metaAddress;
        emit UpdateTokenMetaAddress(metaIndex);
    }
    // function getTokenMetaAddress(uint tokenID, uint metaIndex) external view onlyHasTokenAccess(tokenID) returns(address) {
    //     return tokenMetaAddress[tokenID][metaIndex];
    // }

    // function addMetaMapPage(uint tokenID, string calldata metaPage) external onlyOwners(tokenID) {
    //     uint tokenPageCursor = tokenMetaPageCursor[tokenID];
    //     metaMapJson[tokenID][tokenPageCursor] = metaPage;
    //     emit AddMetaMapPage(tokenID, tokenPageCursor);
    //     tokenPageCursor++;
    //     metaMapPageCnt[tokenID] = tokenPageCursor;
    //     metaMapPageCursor[tokenID] = tokenPageCursor;
    // }
    // function updateMetaMapPage(uint tokenID, uint metaIndex, string calldata metaPage) external onlyOwner(tokenID)  {
    //     metaMapJson[tokenID][metaIndex] = metaPage;
    //     emit UpdateMetaMapPage(tokenID, metaIndex);
    // }


}
contract MetaTokenTetherBook is StandardTokenTetherBook, TokenMetaAddressTetherBook {

    // event UpdateTokenMetaPage(uint tokenID, uint tokenMetaID);
    // event AddTokenMetaPage(uint tokenID, uint tokenMetaID);
    event UpdateTokenMetaAddress(uint tokenID, uint tokenMetaID);
    event AddTokenMetaAddress(uint tokenID, uint tokenMetaID);
    // event UpdateMetaMapPage(uint tokenID, uint tokenMetaID);
    // event AddMetaMapPage(uint tokenID, uint tokenMetaID);

    // modifier onlyHasTokenAccess(uint tokenID) {
    //     // address allowedUser = allowed[tokenID];
    //     address tokenOwner = owners[tokenID];
    //     bool operator = operators[tokenOwner][msg.sender];
    //     bool manager = managers[tokenOwner][tokenID][msg.sender];
    //     bool admin = admins[tokenOwner][tokenID][msg.sender];
    //     // bool _isPublic = isPublic[tokenID];
    //     // bool allowedUser;
    //     // Manageable permission = Manageable(allowedUsers);
    //     // if(permission.manageable() ==  true){
    //     //     allowedUser =  permission.admins(msg.sender) || permission.managers(msg.sender);
    //     // }else{
    //     //     allowedUser = msg.sender == allowedUsers;
    //     // }
    //     // HasPermission(msg.sender, allowedUsers, allowedUser);
    //     // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    //     require(operator || tokenOwner == msg.sender || manager || admin );
    //     _;
    // }

    // function addTokenMetaPage(uint tokenID, string calldata metaData) external onlyOwners(tokenID) {
    //     uint tokenPageCursor = tokenMetaPageCursor[tokenID];
    //     tokenMetaJson[tokenID][tokenPageCursor] = metaData;
    //     emit AddTokenMetaPage(tokenID, tokenPageCursor);
    //     tokenPageCursor++;
    //     tokenMetaPages[tokenID] = tokenPageCursor;
    //     tokenMetaPageCursor[tokenID] = tokenPageCursor;
    // }
    // function updateTokenMetaPage(uint tokenID, uint tokenMetaPage, string calldata metaData) external onlyOwner(tokenID)  {
    //     tokenMetaJson[tokenID][tokenMetaPage] = metaData;
    //     emit UpdateTokenMetaPage(tokenID, tokenMetaPage);
    // }
    // function getTokenMetaPage(uint tokenID, uint tokenMetaPage) external view onlyHasTokenAccess(tokenID) returns(string memory) {
    //     return tokenMetaJson[tokenID][tokenMetaPage];
    // }

    function addTokenMetaAddress(uint tokenID, address metaAddress) external onlyOwners(tokenID) {
        uint tokenAddressCursor = tokenMetaAddressCursor[tokenID];
        tokenMetaAddress[tokenID][tokenAddressCursor] = metaAddress;
        emit AddTokenMetaAddress(tokenID, tokenAddressCursor);
        tokenAddressCursor++;
        tokenMetaAddressCnt[tokenID] = tokenAddressCursor;
        tokenMetaAddressCursor[tokenID] = tokenAddressCursor;
    }
    function updateTokenMetaAddress(uint tokenID, uint metaIndex, address metaAddress) external onlyOwners(tokenID)  {
        tokenMetaAddress[tokenID][metaIndex] = metaAddress;
        emit UpdateTokenMetaAddress(tokenID, metaIndex);
    }
    // function getTokenMetaAddress(uint tokenID, uint metaIndex) external view onlyHasTokenAccess(tokenID) returns(address) {
    //     return tokenMetaAddress[tokenID][metaIndex];
    // }

    // function addMetaMapPage(uint tokenID, string calldata metaPage) external onlyOwners(tokenID) {
    //     uint tokenPageCursor = tokenMetaPageCursor[tokenID];
    //     metaMapJson[tokenID][tokenPageCursor] = metaPage;
    //     emit AddMetaMapPage(tokenID, tokenPageCursor);
    //     tokenPageCursor++;
    //     metaMapPageCnt[tokenID] = tokenPageCursor;
    //     metaMapPageCursor[tokenID] = tokenPageCursor;
    // }
    // function updateMetaMapPage(uint tokenID, uint metaIndex, string calldata metaPage) external onlyOwner(tokenID)  {
    //     metaMapJson[tokenID][metaIndex] = metaPage;
    //     emit UpdateMetaMapPage(tokenID, metaIndex);
    // }


}

contract BlackList is Ownable, BasicToken {

    /////// Getters to allow the same blacklist to be used also by other contracts (including upgraded BlockU) ///////
    function getBlackListStatus(address _maker) external view returns (bool) {
        return isBlackListed[_maker];
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    mapping (address => bool) public isBlackListed;
    
    function addBlackList (address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList (address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    function destroyBlackFunds (address _blackListedUser) public onlyOwner {
        require(isBlackListed[_blackListedUser]);
        require(isDepletable,"Token must be depletable");
        uint dirtyFunds = balanceOf(_blackListedUser);
        balances[_blackListedUser] = 0;
        _totalSupply -= dirtyFunds;
        emit DestroyedBlackFunds(_blackListedUser, dirtyFunds);
    }

    event DestroyedBlackFunds(address _blackListedUser, uint _balance);

    event AddedBlackList(address _user);

    event RemovedBlackList(address _user);

}
contract BlackListTetherBook is Ownable, BasicTokenTetherBook {

    /////// Getters to allow the same blacklist to be used also by other contracts (including upgraded BlockU) ///////
    function getBlackListStatus(address _maker) external view returns (bool) {
        return isBlackListed[_maker];
    }

    function getOwner() external view returns (address) {
        return owner;
    }

    mapping (address => bool) public isBlackListed;
    
    function addBlackList (address _evilUser) public onlyOwner {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    function removeBlackList (address _clearedUser) public onlyOwner {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }

    function destroyBlackFunds (uint tokenID, address _blackListedUser) public onlyOwner {
        require(isBlackListed[_blackListedUser]);
        require(isDepletable[tokenID],"Token must be depletable");
        uint dirtyFunds = balanceOf(tokenID, _blackListedUser);
        balances[tokenID][_blackListedUser] = 0;
        _totalSupply[tokenID] -= dirtyFunds;
        emit DestroyedBlackFunds(tokenID, _blackListedUser, dirtyFunds);
    }

    event DestroyedBlackFunds(uint _tokenID, address _blackListedUser, uint _balance);

    event AddedBlackList(address _user);

    event RemovedBlackList(address _user);

}

contract UpgradedMetaToken is StandardToken{
    // those methods are called by the legacy contract
    // and they must ensure msg.sender to be the contract address
    function transferByLegacy(address from, address to, uint value) public;
    function transferFromByLegacy(address sender, address from, address spender, uint value) public;
    function approveByLegacy(address from, address spender, uint value) public;
}
contract UpgradedMetaTokenTetherBook is StandardTokenTetherBook{
    // those methods are called by the legacy contract
    // and they must ensure msg.sender to be the contract address
    function transferByLegacy(uint tokenID,address from, address to, uint value) public;
    function transferFromByLegacy(uint tokenID,address sender, address from, address spender, uint value) public;
    function approveByLegacy(uint tokenID,address from, address spender, uint value) public;
}
contract TetherBookReceiver {
    bool public tokenBank;

    function tokenBankFallback() public returns (bool);
    function onTetherBookDeposit(address from, uint tokenID,  uint value) public returns (bool);
}

contract TetherBook is Pausable, BlackListTetherBook, StandardTokenTetherBook {

    TokenBookConfig public tokenBookConfig;
    address public tokenBookConfigAddress;
    
    mapping(uint => bool) public isStableToken;
    
    
    mapping(uint => string) public name;
    mapping(uint => string) public symbol;
    // mapping(uint => uint) public decimals;
    mapping(uint => uint) public bankID;
    mapping(uint => uint) public paymentMethodID;
    mapping(uint => uint) public paymentTokenID;
    // mapping(address=> string) public upgradedAddress;
    // mapping(bool => uint) public deprecated;
    // uint public bankID;
    uint public tokenCnt;
    // string public name;
    // string public symbol;
    uint public decimals;
    uint public maxRtoSupply;
    address public upgradedAddress;
    bool public deprecated;
    // function addShopToken(address upgradedAddress) public;
      event Config(address indexed tokenBookConfigAddress);



    //  The contract can be initialized with a number of tokens
    //  All the tokens are deposited to the owner address
    //
    // @param _balance Initial supply of the contract
    // @param _name Token Name
    // @param _symbol Token symbol
    // @param _decimals Token decimals
    constructor() public {
        // paginate all variables 
        // tokenCnt++;
        // _totalSupply[tokenCnt]  =  10000000000000; //10 mil
        // name[tokenCnt] = _name;
        // symbol[tokenCnt] = _symbol;
        maxRtoSupply = 10000000000000;
        decimals = 6;
        // balances[tokenCnt][owner] = _totalSupply[tokenCnt]; //based on balance mapping array
        deprecated = false;
        // tokenCnt++;
    }
    // function addToken(string memory _name, string memory _symbol) public {
    //     // paginate all variables 
    //     _totalSupply[tokenCnt]  =  10000000000000; //10 mil
    //     name[tokenCnt] = _name;
    //     symbol[tokenCnt]  = _symbol;
    //     decimals[tokenCnt]  = 6;
    //     balances[tokenCnt][owner] = _totalSupply[tokenCnt]; //based on balance mapping array
    //     tokenCnt++;
    // }
    function config(address newTokenBookConfigAddress) public onlyOwner  {
            tokenBookConfigAddress = newTokenBookConfigAddress;
            tokenBookConfig = TokenBookConfig(tokenBookConfigAddress);
            emit Config(tokenBookConfigAddress);
      }
    function addTether(uint tokenID, string calldata _name, string calldata _symbol, address _owner, bool stableCoin , bool depletable ) external onlyOwner {
        // tokens[metaPageCursor] = _data;
        // balances[_owner] = balances[_owner].add(1);
        require(tokenBookConfigAddress != address(0), 'must set config');
        require(owners[tokenID] == address(0), 'this token has alrady been tethered');
        require(tokenID != 0, 'Token ID zero is reserved');
        
        owners[tokenID] = _owner;
        // managers[_owner][tokenID][_owner] = true;
        // admins[_owner][tokenID][_owner] = true;
        // metaDataStorage = metaData;
        // emit AddToken(_owner,_admin, _manager,tokenID);
        // addMetaPage(metaDataStorage);
        name[tokenID] = _name;
        symbol[tokenID] = _symbol;

        bool customParams = tokenBookConfig.tokenBools(tokenID,1);
        uint _tetherTotalSupply;
        // uint _basisPoints;
        if(customParams){
            _tetherTotalSupply = tokenBookConfig.tokenUints(tokenID,6);
            // _basisPoints = tokenBookConfig.tokenUints(tokenID,1);

        }else{
            _tetherTotalSupply = tokenBookConfig.contractUints(6);
            // _basisPoints = tokenBookConfig.contractUints(1);
        }
        // basisPointsRate[tokenID] = _basisPoints;
        isStableToken[tokenID] = stableCoin;
        isDepletable[tokenID] = depletable;
        if(!stableCoin){
            require(_tetherTotalSupply <= maxRtoSupply, 'tether supply too high');
        }
        balances[tokenID][owner] = _tetherTotalSupply; //based on balance mapping array
        // setParams(tokenID,tokenBookConfigAddress);
        
        emit AddTether(tokenID);

        tokenCnt++;
    }
    // function setDefault(uint tokenID )  private {
    //     uint _basisPoints;
    //     uint _maxFee;
    //     uint _bankID;
    //     uint _payMethodID;
    //     uint _payTokenID;
        
    //         _basisPoints = tokenBookConfig.contractUints(1);
    //         _maxFee = tokenBookConfig.contractUints(2);
    //         _bankID = tokenBookConfig.contractUints(3);
    //         _payMethodID = tokenBookConfig.contractUints(4);
    //         _payTokenID = tokenBookConfig.contractUints(5);

    //     require(_basisPoints < 20,"basisPoints < 20");
    //     require(_maxFee < 50,"_maxFee < 50");

    //     basisPointsRate[tokenID] = _basisPoints;
    //     maximumFee[tokenID] = _maxFee.mul(10**decimals);
    //     bankID[tokenID] = _bankID;
    //     // bankID = _bankID;
    //     paymentMethodID[tokenID] = _payMethodID;
    //     paymentTokenID[tokenID] = _payTokenID;
    // }
    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transfer(uint tokenID, address _to, uint _value) public whenNotPaused {
        require(!isBlackListed[msg.sender]);
        if (deprecated) {
            return UpgradedMetaTokenTetherBook(upgradedAddress).transferByLegacy(tokenID,msg.sender, _to, _value);
        } else {
            /* 
                do preTansfer
                super.transfer(tokenID,_to, _value);
                bank.postTransfer(tokenID,_to, _value);
            */
            bool customParams = tokenBookConfig.tokenBools(tokenID,1);
            uint bankIndex = bankID[tokenID];
            address bankAddress;
            
            if(customParams){
            bankAddress = tokenBookConfig.tokenAddresses(tokenID,bankIndex);
    
            }else{
                bankAddress = tokenBookConfig.contractAddresses(bankIndex);
            }
            Bank bank = Bank(bankAddress);
            bank.preTransfer(tokenID,msg.sender,_to);
            super.transfer(tokenID,_to, _value);
            bank.postTransfer(tokenID,msg.sender,_to);
            require(checkAndCallSafeTransfer(tokenID, msg.sender, _to, _value));

        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transferFrom(uint tokenID,address _from, address _to, uint _value) public whenNotPaused {
        require(!isBlackListed[_from]);
        if (deprecated) {
            return UpgradedMetaTokenTetherBook(upgradedAddress).transferFromByLegacy(tokenID, msg.sender, _from, _to, _value);
        } else {
           
            bool customParams = tokenBookConfig.tokenBools(tokenID,1);
            uint bankIndex = bankID[tokenID];
            address bankAddress;
            
            if(customParams){
            bankAddress = tokenBookConfig.tokenAddresses(tokenID,bankIndex);
    
            }else{
                bankAddress = tokenBookConfig.contractAddresses(bankIndex);
            }
           
            Bank bank = Bank(bankAddress);
            bank.preTransfer(tokenID,_from,_to);
          

            super.transferFrom(tokenID,_from, _to, _value);
            
            bank.postTransfer(tokenID,_from,_to);
            
            require(checkAndCallSafeTransfer(tokenID, _from, _to, _value));

        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function balanceOf(uint tokenID, address who) public view returns (uint) {
        if (deprecated) {
            return UpgradedMetaTokenTetherBook(upgradedAddress).balanceOf(tokenID,who);
        } else {
            return super.balanceOf(tokenID,who);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function approve(uint tokenID, address _spender, uint _value) public onlyPayloadSize(2 * 32) {
        if (deprecated) {
            return UpgradedMetaTokenTetherBook(upgradedAddress).approveByLegacy(tokenID, msg.sender, _spender, _value);
        } else {
            return super.approve(tokenID, _spender, _value);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function allowance(uint tokenID, address _owner, address _spender) public view returns (uint remaining) {
        if (deprecated) {
            return StandardTokenTetherBook(upgradedAddress).allowance(tokenID, _owner, _spender);
        } else {
            return super.allowance(tokenID, _owner, _spender);
        }
    }

    // deprecate current contract in favour of a new one
    function deprecate(address _upgradedAddress) public onlyOwner {
        deprecated = true;
        upgradedAddress = _upgradedAddress;
        emit Deprecate(_upgradedAddress);
    }

    // deprecate current contract if favour of a new one
    function totalSupply(uint tokenID) public view returns (uint) {
        if (deprecated) {
            return StandardTokenTetherBook(upgradedAddress).totalSupply(tokenID);
        } else {
            return _totalSupply[tokenID];
        }
    }

    // Issue a new amount of tokens
    // these tokens are deposited into the owner address
    //
    // @param _amount Number of tokens to be issued
    function issue(uint tokenID, uint amount) public onlyOwner {
        require(_totalSupply[tokenID] + amount > _totalSupply[tokenID]);
        require(balances[tokenID][owner] + amount > balances[tokenID][owner]);
        
        bool _isStableToken = isStableToken[tokenID];
        if(!_isStableToken){
            require(balances[tokenID][owner] + amount > balances[tokenID][owner]);

        }

        balances[tokenID][owner] += amount; //needs function - addShopToken - adds an index to array called shopTokens 
        //object called shoptokens, index of 1 is all information fro related shop token 
        // everytime a new one is added, 
        _totalSupply[tokenID] += amount;
        emit Issue(tokenID, amount);
    }

    // Redeem tokens.
    // These tokens are withdrawn from the owner address
    // if the balance must be enough to cover the redeem
    // or the call will fail.
    // @param _amount Number of tokens to be issued
    function redeem(uint tokenID, uint amount) public onlyOwner {
        require(_totalSupply[tokenID] >= amount);
        require(balances[tokenID][owner] >= amount);
        require(isDepletable[tokenID],"Token must be depletable");
        
        _totalSupply[tokenID] -= amount;
        balances[tokenID][owner] -= amount;
        emit Redeem(tokenID,amount);
    }

    function setParams(uint tID) public onlyOwners(tID) {
        // if(!customParams){
        //     setDefault(tID ); 
        //     return;
        // }
        
        // TokenBookConfig _tokenBookConfig = TokenBookConfig(newTokenBookConfigAddress);
        // Ensure transparency by hardcoding limit beyond which fees can never be added
        // bool customParams = tokenBookConfig.tokenBools(tID,1);
        uint _basisPoints;
        uint _maxFee;
        uint _bankID;
        uint _payMethodID;
        uint _payTokenID;
        // if(customParams){
            _basisPoints = tokenBookConfig.tokenUints(tID,1);
            _maxFee = tokenBookConfig.tokenUints(tID,2);
            _bankID = tokenBookConfig.tokenUints(tID,3);
            _payMethodID = tokenBookConfig.tokenUints(tID,4);
            _payTokenID = tokenBookConfig.tokenUints(tID,5);
        // }else{
        //     _basisPoints = tokenBookConfig.contractUints(1);
        //     _maxFee = tokenBookConfig.contractUints(2);
        //     _bankID = tokenBookConfig.contractUints(3);
        //     _payMethodID = tokenBookConfig.contractUints(4);
        //     _payTokenID = tokenBookConfig.contractUints(5);
        // }
        require(_basisPoints < 20,"basisPoints < 20");
        require(_maxFee < 50,"_maxFee < 50");

        basisPointsRate[tID] = _basisPoints;
        maximumFee[tID] = _maxFee.mul(10**decimals);
        bankID[tID] = _bankID;
        // bankID = _bankID;
        paymentMethodID[tID] = _payMethodID;
        paymentTokenID[tID] = _payTokenID;
        // emit Params(tID, basisPointsRate[tID], maximumFee[tID]);
        // emit Params(tID, basisPointsRate[tID], maximumFee[tID],bankID[tID]);
        emit Params(tID, _basisPoints, maximumFee[tID], _bankID, _payMethodID);
    }
    // function setParamID(uint _bankID) public onlyOwner {

    //     bankID = _bankID;
    //     // paymentMethodID[tID] = _payMethodID;
    //     // emit Params(tID, basisPointsRate[tID], maximumFee[tID]);
    //     // emit Params(tID, basisPointsRate[tID], maximumFee[tID],bankID);
    //     // emit Params(tID, basisPointsRate[tID], maximumFee[tID], bankID[tID], paymentMethodID[tID]);
    // }

    function checkAndCallSafeTransfer(uint256 _tokenId, address _from, address _to, uint _value) internal returns (bool) {
        bool _isContract = isContract(_to);
        if (!_isContract) {
        return true; }
        bool tethersRecieved = TetherBookReceiver(_to).onTetherBookDeposit(_from, _tokenId, _value);
        return tethersRecieved;
    }
    //From AddressUtils.sol library
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
    // called when token is created
     event AddTether(uint tokenID);
    // Called when new token are issued
    event Issue(uint tokenID, uint amount);

    // Called when tokens are redeemed
    event Redeem(uint tokenID, uint amount);

    // Called when contract is deprecated
    event Deprecate(address newAddress);

    // Called if contract ever adds fees
    // event Params(uint tokenID, uint feeBasisPoints, uint maxFee);
    // event Params(uint tokenID, uint feeBasisPoints, uint maxFee, uint bankID);
    event Params(uint tokenID, uint feeBasisPoints, uint maxFee, uint bankID, uint paymentMethodID);
}

contract TokenERC20 is Pausable, BlackList, StandardToken {

    TokenBookConfig public tokenBookConfig;
    address public tokenBookConfigAddress;
    
    bool public isStableToken;
    
    
    string public name;
    string public symbol;
    // uint public decimals;
    uint public tokenID;
    uint public bankID;
    uint public paymentMethodID;
    uint public paymentTokenID;
    // string public upgradedAddress;
    // uint public deprecated;
    // uint public bankID;
    uint public tokenCnt;
    // string public name;
    // string public symbol;
    uint public decimals;
    uint public maxRtoSupply;
    address public upgradedAddress;
    bool public deprecated;
    // function addShopToken(address upgradedAddress) public;
      event Config(address indexed tokenBookConfigAddress);



    //  The contract can be initialized with a number of tokens
    //  All the tokens are deposited to the owner address
    //
    // @param _balance Initial supply of the contract
    // @param _name Token Name
    // @param _symbol Token symbol
    // @param _decimals Token decimals

    // constructor() public {
    //     // paginate all variables 
    //     // tokenCnt++;
    //     // _totalSupply[tokenCnt]  =  10000000000000; //10 mil
    //     // name[tokenCnt] = _name;
    //     // symbol[tokenCnt] = _symbol;
    //     maxRtoSupply = 10000000000000;
    //     decimals = 6;
    //     // balances[tokenCnt][owner] = _totalSupply[tokenCnt]; //based on balance mapping array
    //     deprecated = false;
    //     // tokenCnt++;
    // }

    modifier _onlyOwner() {
        require(msg.sender == owner,"only owner");
        _;
    }
    //constructor(address newTokenBookConfigAddress, uint _tokenID, string memory _name, string memory _symbol, address _owner, bool stableCoin , bool depletable ) public {
    constructor(address newTokenBookConfigAddress ) public {
        // tokens[metaPageCursor] = _data;
        // balances[_owner] = balances[_owner].add(1);
        uint _tokenID = 1;
        string memory _name = "test";
        string memory _symbol = "test";
        address _owner = msg.sender;
        bool stableCoin = false;
        bool depletable = true;

        maxRtoSupply = 10000000000000;
        decimals = 6;
        tokenID = _tokenID;
        deprecated = false;

        tokenBookConfigAddress = newTokenBookConfigAddress;
        tokenBookConfig = TokenBookConfig(tokenBookConfigAddress);
        emit Config(tokenBookConfigAddress);

        require(tokenBookConfigAddress != address(0), 'must set config');
        //require(owners[tokenID] == address(0), 'this token has alrady been tethered'); i dont thin this is needed
        require(tokenID != 0, 'Token ID zero is reserved');
        
        owner = _owner;
        // managers[_owner][tokenID][_owner] = true;
        // admins[_owner][tokenID][_owner] = true;
        // metaDataStorage = metaData;
        // emit AddToken(_owner,_admin, _manager,tokenID);
        // addMetaPage(metaDataStorage);
        name = _name;
        symbol = _symbol;

        bool customParams = tokenBookConfig.tokenBools(tokenID,1);
        uint _tetherTotalSupply;
        // uint _basisPoints;
        if(customParams){
            _tetherTotalSupply = tokenBookConfig.tokenUints(tokenID,6);
            // _basisPoints = tokenBookConfig.tokenUints(tokenID,1);

        }else{
            _tetherTotalSupply = tokenBookConfig.contractUints(6);
            // _basisPoints = tokenBookConfig.contractUints(1);
        }
        // basisPointsRate[tokenID] = _basisPoints;
        isStableToken = stableCoin;
        isDepletable = depletable;
        if(!stableCoin){
            require(_tetherTotalSupply <= maxRtoSupply, 'tether supply too high');
        }
        balances[owner] = _tetherTotalSupply; //based on balance mapping array
        // setParams(tokenID,tokenBookConfigAddress);
        
        emit AddTether(tokenID);

        tokenCnt++;
    }
    // function addToken(string memory _name, string memory _symbol) public {
    //     // paginate all variables 
    //     _totalSupply[tokenCnt]  =  10000000000000; //10 mil
    //     name[tokenCnt] = _name;
    //     symbol[tokenCnt]  = _symbol;
    //     decimals[tokenCnt]  = 6;
    //     balances[tokenCnt][owner] = _totalSupply[tokenCnt]; //based on balance mapping array
    //     tokenCnt++;
    // }
    function config(address newTokenBookConfigAddress) public onlyOwner  {
            tokenBookConfigAddress = newTokenBookConfigAddress;
            tokenBookConfig = TokenBookConfig(tokenBookConfigAddress);
            emit Config(tokenBookConfigAddress);
    }
    function addTether(uint _tokenID, string memory _name, string memory _symbol) public onlyOwner  {
        tokenID = _tokenID;
        name = _name;
        symbol = _symbol;
        emit AddTether(tokenID);
    }

    // function addTether(uint tokenID, string calldata _name, string calldata _symbol, address _owner, bool stableCoin , bool depletable ) external onlyOwner {
    //     // tokens[metaPageCursor] = _data;
    //     // balances[_owner] = balances[_owner].add(1);
    //     require(tokenBookConfigAddress != address(0), 'must set config');
    //     require(owners[tokenID] == address(0), 'this token has alrady been tethered');
    //     require(tokenID != 0, 'Token ID zero is reserved');
        
    //     owners[tokenID] = _owner;
    //     // managers[_owner][tokenID][_owner] = true;
    //     // admins[_owner][tokenID][_owner] = true;
    //     // metaDataStorage = metaData;
    //     // emit AddToken(_owner,_admin, _manager,tokenID);
    //     // addMetaPage(metaDataStorage);
    //     name[tokenID] = _name;
    //     symbol[tokenID] = _symbol;

    //     bool customParams = tokenBookConfig.tokenBools(tokenID,1);
    //     uint _tetherTotalSupply;
    //     // uint _basisPoints;
    //     if(customParams){
    //         _tetherTotalSupply = tokenBookConfig.tokenUints(tokenID,6);
    //         // _basisPoints = tokenBookConfig.tokenUints(tokenID,1);

    //     }else{
    //         _tetherTotalSupply = tokenBookConfig.contractUints(6);
    //         // _basisPoints = tokenBookConfig.contractUints(1);
    //     }
    //     // basisPointsRate[tokenID] = _basisPoints;
    //     isStableToken[tokenID] = stableCoin;
    //     isDepletable[tokenID] = depletable;
    //     if(!stableCoin){
    //         require(_tetherTotalSupply <= maxRtoSupply, 'tether supply too high');
    //     }
    //     balances[tokenID][owner] = _tetherTotalSupply; //based on balance mapping array
    //     // setParams(tokenID,tokenBookConfigAddress);
        
    //     emit AddTether(tokenID);

    //     tokenCnt++;
    // }

    // function setDefault(uint tokenID )  private {
    //     uint _basisPoints;
    //     uint _maxFee;
    //     uint _bankID;
    //     uint _payMethodID;
    //     uint _payTokenID;
        
    //         _basisPoints = tokenBookConfig.contractUints(1);
    //         _maxFee = tokenBookConfig.contractUints(2);
    //         _bankID = tokenBookConfig.contractUints(3);
    //         _payMethodID = tokenBookConfig.contractUints(4);
    //         _payTokenID = tokenBookConfig.contractUints(5);

    //     require(_basisPoints < 20,"basisPoints < 20");
    //     require(_maxFee < 50,"_maxFee < 50");

    //     basisPointsRate[tokenID] = _basisPoints;
    //     maximumFee[tokenID] = _maxFee.mul(10**decimals);
    //     bankID[tokenID] = _bankID;
    //     // bankID = _bankID;
    //     paymentMethodID[tokenID] = _payMethodID;
    //     paymentTokenID[tokenID] = _payTokenID;
    // }
    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transfer(address _to, uint _value) public whenNotPaused {
        require(!isBlackListed[msg.sender]);
        if (deprecated) {
            return UpgradedMetaToken(upgradedAddress).transferByLegacy(msg.sender, _to, _value);
        } else {
            
                // do preTansfer
                // super.transfer(tokenID,_to, _value);
                // bank.postTransfer(tokenID,_to, _value);
       
            bool customParams = tokenBookConfig.tokenBools(tokenID,1);
            uint bankIndex = bankID;
            address bankAddress;
            
            if(customParams){
            bankAddress = tokenBookConfig.tokenAddresses(tokenID,bankIndex);
    
            }else{
                bankAddress = tokenBookConfig.contractAddresses(bankIndex);
            }
            Bank bank = Bank(bankAddress);
            bank.preTransfer(tokenID,msg.sender,_to);
            super.transfer(_to, _value);
            bank.postTransfer(tokenID,msg.sender,_to);
            require(checkAndCallSafeTransfer(tokenID, msg.sender, _to, _value));

        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function transferFrom(address _from, address _to, uint _value) public whenNotPaused {
        require(!isBlackListed[_from]);
        if (deprecated) {
            return UpgradedMetaToken(upgradedAddress).transferFromByLegacy(msg.sender, _from, _to, _value);
        } else {
            bool customParams = tokenBookConfig.tokenBools(tokenID,1);
            uint bankIndex = bankID;
            address bankAddress;
            
            if(customParams){
            bankAddress = tokenBookConfig.tokenAddresses(tokenID,bankIndex);
    
            }else{
                bankAddress = tokenBookConfig.contractAddresses(bankIndex);
            }
           
            Bank bank = Bank(bankAddress);
            bank.preTransfer(tokenID,_from,_to);
            super.transferFrom(_from, _to, _value);
            bank.postTransfer(tokenID,_from,_to);
            require(checkAndCallSafeTransfer(tokenID, _from, _to, _value));

        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function balanceOf(address who) public view returns (uint) {
        if (deprecated) {
            return UpgradedMetaToken(upgradedAddress).balanceOf(who);
        } else {
            return super.balanceOf(who);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function approve(address _spender, uint _value) public onlyPayloadSize(2 * 32) {
        if (deprecated) {
            return UpgradedMetaToken(upgradedAddress).approveByLegacy( msg.sender, _spender, _value);
        } else {
            return super.approve( _spender, _value);
        }
    }

    // Forward ERC20 methods to upgraded contract if this one is deprecated
    function allowance(address _owner, address _spender) public view returns (uint remaining) {
        if (deprecated) {
            return StandardToken(upgradedAddress).allowance( _owner, _spender);
        } else {
            return super.allowance( _owner, _spender);
        }
    }

    // deprecate current contract in favour of a new one
    function deprecate(address _upgradedAddress) public onlyOwner {
        deprecated = true;
        upgradedAddress = _upgradedAddress;
        emit Deprecate(_upgradedAddress);
    }

    // deprecate current contract if favour of a new one
    function totalSupply() public view returns (uint) {
        if (deprecated) {
            return StandardToken(upgradedAddress).totalSupply();
        } else {
            return _totalSupply;
        }
    }

    // Issue a new amount of tokens
    // these tokens are deposited into the owner address
    //
    // @param _amount Number of tokens to be issued

    function issue(uint amount) public onlyOwner {
        require(_totalSupply + amount > _totalSupply);
        require(balances[owner] + amount > balances[owner]);
        
        bool _isStableToken = isStableToken;
        if(!_isStableToken){
            require(balances[owner] + amount > balances[owner]);

        }

          //NOTEneed to honor maxRtoSupply 

        balances[owner] += amount; //needs function - addShopToken - adds an index to array called shopTokens 
        //object called shoptokens, index of 1 is all information fro related shop token 
        // everytime a new one is added, 
        _totalSupply += amount;

      
        emit Issue(amount);
    }

    // Redeem tokens.
    // These tokens are withdrawn from the owner address
    // if the balance must be enough to cover the redeem
    // or the call will fail.
    // @param _amount Number of tokens to be issued
    function redeem(uint amount) public onlyOwner {
        require(_totalSupply >= amount);
        require(balances[owner] >= amount);
        require(isDepletable,"Token must be depletable");
        
        _totalSupply -= amount;
        balances[owner] -= amount;
        emit Redeem(amount);
    }

    function setParams() public onlyOwner() {
        // if(!customParams){
        //     setDefault(tID ); 
        //     return;
        // }
        
        // TokenBookConfig _tokenBookConfig = TokenBookConfig(newTokenBookConfigAddress);
        // Ensure transparency by hardcoding limit beyond which fees can never be added
        // bool customParams = tokenBookConfig.tokenBools(tID,1);
        uint _basisPoints;
        uint _maxFee;
        uint _bankID;
        uint _payMethodID;
        uint _payTokenID;
        // if(customParams){
            _basisPoints = tokenBookConfig.tokenUints(tokenID,1);
            _maxFee = tokenBookConfig.tokenUints(tokenID,2);
            _bankID = tokenBookConfig.tokenUints(tokenID,3);
            _payMethodID = tokenBookConfig.tokenUints(tokenID,4);
            _payTokenID = tokenBookConfig.tokenUints(tokenID,5);
        // }else{
        //     _basisPoints = tokenBookConfig.contractUints(1);
        //     _maxFee = tokenBookConfig.contractUints(2);
        //     _bankID = tokenBookConfig.contractUints(3);
        //     _payMethodID = tokenBookConfig.contractUints(4);
        //     _payTokenID = tokenBookConfig.contractUints(5);
        // }
        require(_basisPoints < 20,"basisPoints < 20");
        require(_maxFee < 50,"_maxFee < 50");

        basisPointsRate = _basisPoints;
        maximumFee = _maxFee.mul(10**decimals);
        bankID = _bankID;
        // bankID = _bankID;
        paymentMethodID = _payMethodID;
        paymentTokenID = _payTokenID;
        // emit Params(tID, basisPointsRate, maximumFee);
        // emit Params(tID, basisPointsRate, maximumFee,bankID);
        emit Params(_basisPoints, maximumFee, _bankID, _payMethodID);
    }
    // function setParamID(uint _bankID) public onlyOwner {

    //     bankID = _bankID;
    //     // paymentMethodID[tID] = _payMethodID;
    //     // emit Params(tID, basisPointsRate[tID], maximumFee[tID]);
    //     // emit Params(tID, basisPointsRate[tID], maximumFee[tID],bankID);
    //     // emit Params(tID, basisPointsRate[tID], maximumFee[tID], bankID[tID], paymentMethodID[tID]);
    // }

    function checkAndCallSafeTransfer(uint256 _tokenId, address _from, address _to, uint _value) internal returns (bool) {
        bool _isContract = isContract(_to);
        if (!_isContract) {
        return true; }
        bool tethersRecieved = TetherBookReceiver(_to).onTetherBookDeposit(_from, _tokenId, _value);
        return tethersRecieved;
    }
    //From AddressUtils.sol library
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
    // called when token is created
     event AddTether(uint tokenID);
    // Called when new token are issued
    event Issue(uint amount);

    // Called when tokens are redeemed
    event Redeem(uint amount);

    // Called when contract is deprecated
    event Deprecate(address newAddress);

    // Called if contract ever adds fees
    // event Params(uint tokenID, uint feeBasisPoints, uint maxFee);
    // event Params(uint tokenID, uint feeBasisPoints, uint maxFee, uint bankID);
    event Params(uint feeBasisPoints, uint maxFee, uint bankID, uint paymentMethodID);
}

// tetherBook end

//tokenBank start 
// ----------------------------------------------------------------------------
// Tether contract
// ----------------------------------------------------------------------------
contract Tether {
    uint public decimals;
    uint public basisPointsRate;
    uint public maximumFee;
    function totalSupply() public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);

    function transfer(address to, uint tokens) public;
    function preTransfer(address to, uint tokens) public;

    function allowance(address owner, address spender) public view returns (uint);
    function transferFrom(address from, address to, uint value) public;
    function approve(address spender, uint value) public;
 
}
// ----------------------------------------------------------------------------
// TetherBook contract
// ----------------------------------------------------------------------------
/*
contract TetherBook  {
    uint public decimals;
    // mapping(address => uint) public balances;
    address  public worthBookAddress;
    // address  public bankAddress; //bankAddress[tokenID] mapping
    address public bankAddress;
    WorthBook internal worthBook;
    TokenBank internal bank;
    mapping(uint => uint) public paymentMethodID;
    mapping(uint => uint) public paymentTokenID;
    mapping(uint => uint) public bankID;
    mapping(uint => mapping(address => uint)) public balances;
    mapping(uint => mapping (uint => address)) public tokenMetaAddress;
    mapping(uint => uint) public basisPointsRate;
    mapping(uint => uint) public maximumFee;

    function totalSupply(uint tokenID) public view returns (uint);
    function balanceOf(uint tokenID, address tokenOwner) public view returns (uint balance);

    function transfer(uint tokenID, address to, uint tokens) public;
    function preTransfer(uint tokenID, address to, uint tokens) public;

    function allowance(uint tokenID, address owner, address spender) public view returns (uint);
    function transferFrom(uint tokenID, address from, address to, uint value) public;
    function approve(uint tokenID, address spender, uint value) public;
    function setKeys(address _stockAddress, uint _tokenID ) public;
 
}
*/
// ----------------------------------------------------------------------------
// WorthBook contract
// ----------------------------------------------------------------------------
/*
contract WorthBook {
    function  updateTokenWorth(address paymentMethod) public;
    function  setPaymentDecimals(address stableCoin) public;
    function owed(address _stockAddress, uint _tokenID, address owner, uint _tokenOwnerID) public  returns (uint);
    function updateTokenPaid(address _stockAddress, uint _tokenID, address pay_to, uint pay_to_tokeID) public returns (bool);
    function  updateTokenWorth(address _stockAddress, uint _tokenID) public;
    function updateTransferTokens(address _stockAddress, uint _tokenID,address from, address to) public;
    function updateTokenPaid(uint currencyKey, uint stockKey) public returns (bool);
    function setKeys(address _stockAddress, uint _tokenID ) public;
    
}
*/
// ----------------------------------------------------------------------------

// ReceiptBook contract
// ----------------------------------------------------------------------------
/*
contract ReceiptBook {
  //bankBalance[currencyKey] = currencyBalance
     mapping(uint => uint)  public bankBalance;
     //totalBankPayments[currencyKey] = totalCurrencyPayments
     mapping(uint => uint)  public totalBankPayments;
     //totalBankPayOuts[currencyKey] = totalCurrencyPayOuts
     mapping(uint => uint)  public totalBankPayOuts;


     //totalPayments[accountKey][currencyKey] = totalPayments
     mapping(uint => mapping(uint => uint ) ) public totalPayments;
     //totalPayOuts[accountKey][currencyKey] = totalPayOuts
     mapping(uint => mapping(uint => uint ) ) public totalPayOuts;
     //accountBalance[accountKey][currencyKey] = accountBalance
     mapping(uint => mapping(uint => uint ) ) public accountBalance;
     //totalBalance[tokenKey][currencyKey] = totalBalance
     mapping(uint => mapping(uint => uint ) ) public totalBalance;
     
      function  recordPayment(uint accountID, uint _paymentTokenID, address _payer, string memory note) public;
      // function  reportPayment(uint tokenID, uint accountID, uint methodIndex, uint _paymentTokenID, address _payer, uint amount) public;
      function  recordPayOut(uint accountID, uint _paymentTokenID, address _payee, string memory note) public;
      // function  reportPayOut(uint tokenID, uint accountID, uint methodIndex, uint _paymentTokenID, address _payee, uint amount) public;
      // function internalTransfer(uint tID, uint aID, address sC, uint ptID, uint payTID, uint payAID, uint a, string memory n ) public  returns (bool);
      function internalTransfer(uint fromAccount, uint paymentAddressKey, uint toAccount, uint a, string memory n ) public  returns (bool);
      function  reportPayment(uint stockKey, uint accountKey, uint currencyKey, address _payer, uint amount) public;
      function  reportPayOut(uint stockKey, uint accountKey, uint currencyKey, address _payee, uint amount) public;


}
*/

/*
// ----------------------------------------------------------------------------
// TokenRewards contract
// ----------------------------------------------------------------------------
contract TokenRewards {
    function payOwner(uint tID, address pay_to, string memory note ) public returns (bool) ;
    function payOwner(uint tID, uint pay_tID ) public   returns (bool);
    // function payOwner(uint tID, uint pay_tID, string memory note ) public   returns (bool);
    function  payOwnerTransfer(uint _tokenID,address from, address to) public;
    function  preTransfer(uint _tokenID, address from, address to) public;
    function  postTransfer(uint _tokenID, address from, address to) public;
}
*/

// ----------------------------------------------------------------------------
// TokenBook contract
// ----------------------------------------------------------------------------
/*
contract TokenBook is Manageable {
    
}
*/

// contract TetherBook is Manageable, TokenMetaAddress {
    

    
// }
/*
contract TokenKey {
   struct _tokenAddressKey{
        string name;
        uint keyCnt;
        mapping (address => mapping (uint => bool)) keySet; //Maps addresses to index in `tests
        mapping (address => mapping (uint => uint)) key; //Maps addresses to index in `tests
    }
    struct _tokenAccountKey{
        string name;
        uint keyCnt;
        mapping (uint => mapping (uint => bool)) keySet; //Maps addresses to index in `tests
        mapping (uint => mapping (uint => uint)) key; //Maps addresses to index in `tests
    }
    _tokenAddressKey _addressKey ;
    _tokenAccountKey _accountKey ;
    _tokenAccountKey _subAccountKey ;
    mapping (uint => address)  public addressKeyContract;
     mapping (uint => uint)  public addressKeyTokenID;

     mapping (uint => address)  public accountKeyContract;
     mapping (uint => uint)  public accountKeyTokenID;
     mapping (uint => uint)  public accountKeyAccountID;

     mapping (uint => address)  public subAccountKeyContract;
     mapping (uint => uint)  public subAccountKeyTokenID;
     mapping (uint => uint)  public subAccountKeyAccountID;
     mapping (uint => uint)  public subAccountKeySubAccountID;
    function addressKey(address tokenAddress, uint tokenID ) public view returns (uint);
    function accountKey(address tokenAddress, uint tokenID, uint accountID ) public view returns (uint);
    function subAccountKey(address tokenAddress, uint tokenID, uint accountID, uint subAccountID  ) public view returns (uint);
    function addressKeyCreate(address tokenAddress, uint tokenID ) public returns (uint);
    function accountKeyCreate(address tokenAddress, uint tokenID, uint accountID ) public  returns (uint);
}
*/

/*
contract TetherBookReceiver {
    bool public tokenBank;

    function onTetherBookDeposit(address from, uint tokenID,  uint value) public returns (bool);
    function tokenBankFallback() public returns (bool);
}
*/
// ----------------------------------------------------------------------------
// PaymentMethods contract
// ----------------------------------------------------------------------------
contract PaymentMethods is Ownable {
    // address public tetherUSDT =  0xdac17f958d2ee523a2206206994597c13d831ec7;
     //address public tetherUSDT =  0xdAC17F958D2ee523a2206206994597C13D831ec7; //real
     // address public tetherUSDT =  0xCA45513588eC8cdE13e3F6fd1b711Ae6F0e0E453; //test ropsten
     // address public tetherUSDT =  0xca45513588ec8cde13e3f6fd1b711ae6f0e0e453; //test ropsten lowercase address
    //  address public tetherUSDT =  0xCA45513588eC8cdE13e3F6fd1b711Ae6F0e0E453; //test local
    using SafeMath for uint;
    WorthBook internal worthBook;
    address public worthBookAddress;

    TetherBook public tetherBook;
    address public tetherBookAddress;

    TokenBook public tokenBook;
    address public tokenBookAddress;

    Manageable public manageable;
    address public manageableAddress;

    ReceiptBook public receiptBook;
    address public receiptBookAddress;

    TokenRewards public tokenRewards;
    address public tokenRewardsAddress;

    TokenKey public tokenKey;
    address public tokenKeyAddress;
    TokenBank public tokenBank;
    address public bankAddress;
    TokenBookConfig public tokenMeta;
    address public tokenMetaAddress;

    address public tokenBookConfigAddress;
    TokenBookConfig public tokenBookConfig;
    






     // address constant public tetherUSDT = 0xdac17f958d2ee523a2206206994597c13d831ec7;
    //  Tether internal tether;
     string constant public paymentCurrency = "USDT";//tether smart contract address

     mapping(uint => uint) public _payment;


    /*
        _s // list of ppl who paid
        totalPayouts
        balances
        payment methods
    */



    address public upgradedAddress;
    bool public deprecated;


     //paymentMethod[paymentMethodAddress] = isValid
     mapping(address => bool) public paymentMethod;
     mapping(uint => address) public paymentMethods;
     mapping(uint => address) public paymentMethodKeys;
     //paymentMethodTokenID[paymentMethodAddress][tokenID] = isValid
     mapping(address => mapping(uint => bool)) public paymentMethodTokenID;
     mapping(address => mapping(uint => string)) public paymentMethodTokenIDInfo;

     mapping(uint => Tether) public tethers; //[payOutCnt][ownerAddress] = payment
     mapping(uint => TetherBook) public tetherBooks; //[payOutCnt][ownerAddress] = payment
     mapping(uint => string) public paymentMethodInfo; //[payOutCnt][ownerAddress] = payment
     
     mapping(address => uint) public tetherIndex;
  
     uint  public paymentMethodCnt; //[payOutCnt][ownerAddress] = payment

     uint public worthBookAccountID = 0;
    //  uint public _paymentMethodID;
    //  uint public _paymentTokenID;
    //  uint public totalIncome = 0; // +
    //  uint public accountBalance = 0;// +
    //  uint public totalPaid = 0; // -
  
      event UpdatePaymentToken(address indexed currencyAddress, uint indexed paymentTokenID,string indexed info, bool isValid);
      event StopPaymentMethod(address indexed currencyAddress, string indexed info);
      event Config1(address indexed tetherBookAddress,address indexed tokenBookAddress,address indexed manageableAddress);
      event Config2(address indexed worthBookAddress ,address indexed receiptBookAddress,address indexed tokenRewardsAddress);

  
      constructor() public {

      }
      /**
      * @dev Throws if called by any account other than the stock token.
      */
     modifier onlyTokenRewards() {
          require(msg.sender == tokenRewardsAddress,"Only tokenRewardsAddress can make this call");
          require(address(0) != tokenRewardsAddress,"TokenRewards address cant be zero");
          _;
      }

      function config(address newTokenBookConfigAddress) public onlyOwner  {
            TokenBookConfig _tokenBookConfig = TokenBookConfig(newTokenBookConfigAddress);
            tokenBookConfigAddress = newTokenBookConfigAddress;
            tokenBookConfig = TokenBookConfig(tokenBookConfigAddress);
            worthBookAddress = _tokenBookConfig.contractAddresses(9);
            worthBook = WorthBook(worthBookAddress);
            tetherBookAddress = _tokenBookConfig.contractAddresses(4);
            tetherBook = TetherBook(tetherBookAddress);
            tokenBookAddress = _tokenBookConfig.contractAddresses(1);
            tokenBook = TokenBook(tokenBookAddress);
            manageableAddress = _tokenBookConfig.contractAddresses(3);
            manageable = Manageable(manageableAddress);
            receiptBookAddress = _tokenBookConfig.contractAddresses(7);
            receiptBook = ReceiptBook(receiptBookAddress);
            tokenRewardsAddress = _tokenBookConfig.contractAddresses(8);
            tokenRewards = TokenRewards(tokenRewardsAddress);
            tokenKeyAddress = _tokenBookConfig.contractAddresses(2);
            tokenKey = TokenKey(tokenKeyAddress);
            bankAddress = _tokenBookConfig.contractAddresses(5);
            tokenBank = TokenBank(bankAddress);
            tokenMetaAddress = _tokenBookConfig.contractAddresses(10);
            tokenMeta = TokenBookConfig(tokenMetaAddress);
            emit Config1(tetherBookAddress,tokenBookAddress,manageableAddress);
            emit Config2(worthBookAddress,receiptBookAddress,tokenRewardsAddress);
      }

      function setPaymentMethod(uint methodIndex,address stableCoin, bool isTetherBook, string memory info, bool valid) public onlyOwner  {
          if(isTetherBook){
            TetherBook tether = TetherBook(stableCoin);
            tetherBooks[methodIndex] = tether;
          }else{
            Tether tether = Tether(stableCoin);
            tethers[methodIndex] = tether;
          }
          paymentMethodInfo[methodIndex] = info;
          paymentMethod[stableCoin] = valid;
          paymentMethods[methodIndex] = stableCoin;
          tetherIndex[stableCoin] = methodIndex;
          worthBook.setPaymentDecimals(stableCoin);
          uint currencyKey = tokenKey.addressKeyCreate(stableCoin, 0);
          paymentMethodKeys[currencyKey] = stableCoin;
          tokenKey.addressKeyCreate(stableCoin,0);
      }


      function updatePaymentToken(address stableCoin, uint tokenID, string memory info, bool valid) public onlyOwner   {
          paymentMethodTokenID[stableCoin][tokenID] = valid;
          paymentMethodTokenIDInfo[stableCoin][tokenID] = info;
          uint currencyKey = tokenKey.addressKeyCreate(stableCoin, tokenID);
          paymentMethodKeys[currencyKey] = stableCoin;
          tokenKey.addressKeyCreate(stableCoin,tokenID);
          tokenKey.addressKeyCreate(bankAddress,tokenID);
          tokenKey.addressKeyCreate(tokenMetaAddress,tokenID);
          // tokenKey.addressKeyCreate(tetherBookAddress,tokenID); should be the same as stableCoin, TokenId
          tokenKey.addressKeyCreate(tokenBookAddress,tokenID);
          emit UpdatePaymentToken(stableCoin,tokenID,info,valid);
      }

      function allowanceBalance(address stableCoin, uint _paymentTokenID, address spender) public  view returns (uint) {
          address _payer = msg.sender;
          uint methodIndex = tetherIndex[stableCoin];
          uint balance;
          if(_paymentTokenID == 0){
              balance = tethers[methodIndex].allowance(_payer,spender);
          }else{
              balance = tetherBooks[methodIndex].allowance(_paymentTokenID,_payer,spender);
          }
          return balance;
      }
      function paymentBalance(uint methodIndex, uint _paymentTokenID, address _payer) internal view  returns (uint) {
          uint payerBalance;
          if(_paymentTokenID == 0){
            payerBalance = tethers[methodIndex].balanceOf(_payer);
          }else{
            payerBalance = tetherBooks[methodIndex].balanceOf(_paymentTokenID,_payer);
          }
          return payerBalance;
      }


      function paymentFunded(uint methodIndex, uint ptID, address _payer, address _payee, uint amount) public view returns (bool)  {
        // require(currency == paymentCurrency);
         bool funded = false;
         //make sure payment was sent
         uint allowance;
        if(ptID == 0){
            allowance = tethers[methodIndex].allowance(_payer,_payee);
        }else{
            allowance = tetherBooks[methodIndex].allowance(ptID,_payer,_payee);
        }
         funded = allowance >= amount;
         return funded;
     }
     function fee(uint currencyKey, uint amount) public {
        address sC = tokenKey.addressKeyContract(currencyKey);
        uint _paymentTokenID = tokenKey.addressKeyTokenID(currencyKey);
        uint methodIndex = tetherIndex[sC];
        uint maximumFee = 0;
        uint basisPointsRate = 0;

        if (_paymentTokenID == 0) {
            // Check if `basisPointsRate` exists
            (bool successRate, bytes memory rateData) = address(tethers[methodIndex]).call(
                abi.encodeWithSignature("basisPointsRate()")
            );
            if (successRate && rateData.length > 0) {
                basisPointsRate = abi.decode(rateData, (uint));
            }

            // Check if `maximumFee` exists
            (bool successMaxFee, bytes memory maxFeeData) = address(tethers[methodIndex]).call(
                abi.encodeWithSignature("maximumFee()")
            );
            if (successMaxFee && maxFeeData.length > 0) {
                maximumFee = abi.decode(maxFeeData, (uint));
            }
        } else {
            // Check if `basisPointsRate(uint256)` exists
            (bool successRate, bytes memory rateData) = address(tetherBooks[methodIndex]).call(
                abi.encodeWithSignature("basisPointsRate(uint256)", _paymentTokenID)
            );
            if (successRate && rateData.length > 0) {
                basisPointsRate = abi.decode(rateData, (uint));
            }

            // Check if `maximumFee(uint256)` exists
            (bool successMaxFee, bytes memory maxFeeData) = address(tetherBooks[methodIndex]).call(
                abi.encodeWithSignature("maximumFee(uint256)", _paymentTokenID)
            );
            if (successMaxFee && maxFeeData.length > 0) {
                maximumFee = abi.decode(maxFeeData, (uint));
            }
        }

        uint _fee = (amount.mul(basisPointsRate)).div(10000);
        if (_fee > maximumFee) {
            _fee = maximumFee;
        }
        uint sendAmount = amount.sub(_fee);
        _payment[0] = sendAmount;
        _payment[1] = _fee;
        // return _payment;
    }

     /*
     function fee(uint currencyKey, uint amount) public   {
        address sC = tokenKey.addressKeyContract(currencyKey);
        uint _paymentTokenID = tokenKey.addressKeyTokenID(currencyKey);
        uint methodIndex = tetherIndex[sC];
        uint maximumFee;
        uint basisPointsRate;
        if(_paymentTokenID == 0){
            basisPointsRate = tethers[methodIndex].basisPointsRate();
            maximumFee = tethers[methodIndex].maximumFee();
        }else{
            basisPointsRate = tetherBooks[methodIndex].basisPointsRate(_paymentTokenID);
            maximumFee = tetherBooks[methodIndex].maximumFee(_paymentTokenID);
        }
        uint _fee = (amount.mul(basisPointsRate)).div(10000);
        if (_fee > maximumFee) {
            _fee = maximumFee;
        }
        uint sendAmount = amount.sub(_fee);
        _payment[0] = sendAmount;
        _payment[1] = _fee;
        // return _payment;
      }
      */
      


  }


// ----------------------------------------------------------------------------
// TokenBank contract
// ----------------------------------------------------------------------------
contract TokenBank is Ownable {
    // address public tetherUSDT =  0xdac17f958d2ee523a2206206994597c13d831ec7;
     //address public tetherUSDT =  0xdAC17F958D2ee523a2206206994597C13D831ec7; //real
     // address public tetherUSDT =  0xCA45513588eC8cdE13e3F6fd1b711Ae6F0e0E453; //test ropsten
     // address public tetherUSDT =  0xca45513588ec8cde13e3f6fd1b711ae6f0e0e453; //test ropsten lowercase address
    //  address public tetherUSDT =  0xCA45513588eC8cdE13e3F6fd1b711Ae6F0e0E453; //test local
    using SafeMath for uint;
    WorthBook internal worthBook;
    address public worthBookAddress;

    TetherBook public tetherBook;
    address public tetherBookAddress;

    TokenBook public tokenBook;
    address public tokenBookAddress;

    Manageable public manageable;
    address public manageableAddress;

    ReceiptBook public receiptBook;
    address public receiptBookAddress;

    TokenRewards public tokenRewards;
    address public tokenRewardsAddress;

    TokenKey public tokenKey;
    address public tokenKeyAddress;

    PaymentMethods public paymentMethods;
    address public paymentMethodsAddress;
    
    TokenBookConfig public tokenBookConfig;
    address public tokenBookConfigAddress;

     // address constant public tetherUSDT = 0xdac17f958d2ee523a2206206994597c13d831ec7;
    //  Tether internal tether;
     string constant public paymentCurrency = "USDT";//tether smart contract address

    /*
        _s // list of ppl who paid
        totalPayouts
        balances
        payment methods
    */



    address public upgradedAddress;
    bool public deprecated;
    bool public tokenBank;


     mapping(uint => Tether) public tethers; //[payOutCnt][ownerAddress] = payment
     mapping(uint => TetherBook) public tetherBooks; //[payOutCnt][ownerAddress] = payment
     mapping(uint => string) public paymentMethodInfo; //[payOutCnt][ownerAddress] = payment
     
     mapping(address => uint) public tetherIndex;
  
     uint  public paymentMethodCnt; //[payOutCnt][ownerAddress] = payment

     uint public worthBookAccountID = 0;
     address _paymentTokenAddress; 
    uint _paymentTokenID;
    uint fromTokenKey;
    uint toTokenKey ;

    //  uint public _paymentMethodID;
    //  uint public _paymentTokenID;
    //  uint public totalIncome = 0; // +
    //  uint public accountBalance = 0;// +
    //  uint public totalPaid = 0; // -
  
      event UpdatePaymentToken(address indexed currencyAddress, uint indexed paymentTokenID,string indexed info, bool isValid);
      event StopPaymentMethod(address indexed currencyAddress, string indexed info);
      event TetherBookDeposit(address from, uint tokenID, uint value);
      event Config1(address indexed tetherBookAddress,address indexed tokenBookAddress,address indexed manageableAddress);
      event Config2(address indexed worthBookAddress ,address indexed receiptBookAddress,address indexed tokenRewardsAddress);
      event Deprecate(address newAddress);
      /*
        goals
        1.payout  - pay users dividents // test ready
        2.payments - accept money  // test ready
        -----------------
        3. how much owed based owner//
        4. how much money paid to property total// totalIncome
        5. how much money earned per token// worthBook
        6. has owner been paid in dividens
        7. payment count //paymentCnt
        8. payment info by index
        9. cash currencies
        10. payment balance
        11. how much money paid to owners via dividens
        12.when trandfers happen tokenPaid musts be updated to token worth
  
  
  
      */
  
      constructor() public {
        tokenBank = true;
        deprecated = false;

        //   tether = Tether(tetherUSDT);
          // addPaymentMethod(tetherUSDT,"https://tether.to/usd%E2%82%AE-and-eur%E2%82%AE-now-supported-on-ethereum/");
      }
      /**
      * @dev Throws if called by any account other than the stock token.
      */
     modifier onlyTokenRewards() {
          require(msg.sender == tokenRewardsAddress,"Only tokenRewardsAddress can make this call");
          require(address(0) != tokenRewardsAddress,"TokenRewards address cant be zero");
          _;
      }
    //   modifier onlyAdmins(uint tID) {
    //       require(manageable.hasAdminPermission(tokenBookAddress,tID,msg.sender,0),"Admin of token can do this");
    //       _;
    //   }
      function config(address newTokenBookConfigAddress) public onlyOwner  {
            tokenBookConfig = TokenBookConfig(newTokenBookConfigAddress);
            worthBookAddress = tokenBookConfig.contractAddresses(9);
            worthBook = WorthBook(worthBookAddress);
            tetherBookAddress = tokenBookConfig.contractAddresses(4);
            tetherBook = TetherBook(tetherBookAddress);
            tokenBookAddress = tokenBookConfig.contractAddresses(1);
            tokenBook = TokenBook(tokenBookAddress);
            manageableAddress = tokenBookConfig.contractAddresses(3);
            manageable = Manageable(manageableAddress);
            receiptBookAddress = tokenBookConfig.contractAddresses(7);
            receiptBook = ReceiptBook(receiptBookAddress);
            tokenRewardsAddress = tokenBookConfig.contractAddresses(8);
            tokenRewards = TokenRewards(tokenRewardsAddress);
            tokenKeyAddress = tokenBookConfig.contractAddresses(2);
            tokenKey = TokenKey(tokenKeyAddress);
            paymentMethodsAddress = tokenBookConfig.contractAddresses(6);
            paymentMethods = PaymentMethods(paymentMethodsAddress);
            emit Config1(tetherBookAddress,tokenBookAddress,manageableAddress);
            emit Config2(worthBookAddress,receiptBookAddress,tokenRewardsAddress);
      }
      // deprecate current contract in favour of a new one
      function deprecate(address _upgradedAddress) public onlyOwner {
          deprecated = true;
          upgradedAddress = _upgradedAddress;
          bool tethersRecieved = TetherBookReceiver(_upgradedAddress).onTetherBookDeposit(address(this), 0, 0);
          bool isTokenBank = TetherBookReceiver(_upgradedAddress).tokenBank();
          require(tethersRecieved,"Upgraded Address must be TetherBookReceiver");
          require(isTokenBank,"Upgraded Address must be TokenBank");
          emit Deprecate(_upgradedAddress);
      }

      /**
    * @dev makes it so contracts can pay out Tethers(ERC20) and  TetherBooks
    */
    function payOut(address sC, uint ptID, address pay_to, uint a) public  onlyOwner() returns (bool)  {
        // uint contract_money = tether.balanceOf(this);
        require(pay_to != address(0),"Cant pay to zero address");
        uint currencyKey = tokenKey.addressKeyCreate(sC, ptID);
        uint bankBalance = receiptBook.bankBalance(currencyKey);
 
        if(ptID == 0){
            //make Tether
            Tether _tether = Tether(sC);
            uint totalBankBalance = _tether.balanceOf(address(this));
            uint bankSpendingBalace = totalBankBalance.sub(bankBalance);
            if(a > bankSpendingBalace){
              require(deprecated,"Must be deprcated to send account money");
              _tether.transfer(upgradedAddress, a); // throws on faiure??

            }else{
              _tether.transfer(pay_to, a); // throws on faiure??
            }
        }else{
            TetherBook _tetherBook = TetherBook(sC);
            uint totalBankBalance = _tetherBook.balances(ptID,address(this));
            uint bankSpendingBalace = totalBankBalance.sub(bankBalance);

            if(a > bankSpendingBalace){
              require(deprecated,"Must be deprcated to send account money");
              _tetherBook.transfer(ptID,upgradedAddress, a); // throws on faiure??
            }else{
              _tetherBook.transfer(ptID,pay_to, a); // throws on faiure??

            }
        }

        return true;
      }
    //   function myPaymentBalance(address stableCoin, uint _paymentTokenID) public view returns (uint) {
    //       address _payer = msg.sender;
    //       uint methodIndex = tetherIndex[stableCoin];
    //       uint balance = paymentBalance(methodIndex,_paymentTokenID,_payer);
    //       return balance;
    //   }
          //TODO restrict pay outs to only admins and make sure pay out does not excceed account balance
      function payOut(uint tID, uint aID, address sC, uint ptID, address pay_to, uint a, string memory note ) public  returns (bool)  {
        // uint contract_money = tether.balanceOf(this);

        tokenKey.addressKeyCreate(msg.sender, 0);
        bool accountAccess = hasAccountAccess(tID, aID, msg.sender );
        if(accountAccess){
            _payOut(tID, aID, sC, ptID, pay_to, a, note);
            return true;
        }else{
            return false;
        }
        
      }

      function _payOut(uint tID, uint aID, address sC, uint ptID, address pay_to, uint a, string memory note ) private  returns (bool)  {
        // uint contract_money = tether.balanceOf(this);
        require(pay_to != address(0),"Cant pay to zero address");
         

        uint currencyKey = _currencyTokenKey(sC,ptID );
        // address _paymentTokenAddress = tokenKey.addressKeyContract(currencyKey);

        // uint _paymentTokenID = tokenKey.addressKeyTokenID(currencyKey);
        uint accountKey = tokenKey.accountKeyCreate(address(this), tID, aID);
        uint stockKey = tokenKey.addressKeyCreate(address(this), tID);
        uint accountBalance = receiptBook.accountBalance(accountKey,currencyKey);
        require(a <= accountBalance,"Pay out exceeds account balance");
        // require(a <= accountBalance[tID][aID][sC][ptID],"Pay out exceeds account balance");
        if(ptID > 0){
            tokenRewards.payOwner(ptID,tID);
        }
        
        // tokenRewards.payOwner(ptID,tID,"Pay Token Owner via _payOut");
        uint methodIndex = paymentMethods.tetherIndex(_paymentTokenAddress);
        if(_paymentTokenID == 0){
            address tetherAddress = paymentMethods.paymentMethods(methodIndex);
            Tether(tetherAddress).transfer(pay_to, a); // throws on faiure??
        }else{
            address tetherAddress = paymentMethods.paymentMethods(methodIndex);
            TetherBook(tetherAddress).transfer(_paymentTokenID, pay_to, a); // throws on faiure??
        }
        receiptBook.recordPayOut(aID, tID, pay_to, note);
        receiptBook.reportPayOut(stockKey, accountKey, currencyKey, pay_to, a);
        // worthBook.updateTokenPaid(sC, ptID, address(this),tID);
        if(ptID > 0){
            uint ptIDTetherBookKey = tokenKey.addressKeyCreate(tetherBookAddress, ptID);
            worthBook.updateTokenPaid(ptIDTetherBookKey, stockKey);
        }
        
        return true;
      }
      function _currencyTokenKey(address sC, uint ptID ) private returns (uint){
         
        if(sC == address(tetherBookAddress) ){
            bool customParams = tokenBookConfig.tokenBools(ptID,1);
            bool customPaymentToken = tokenBookConfig.tokenBools(ptID,101); 

            if(customParams && customPaymentToken){
                _paymentTokenAddress = tokenBookConfig.tokenAddresses(ptID,101); 
                _paymentTokenID = tokenBookConfig.tokenUints(ptID,101); 
            }else{
                _paymentTokenAddress = sC;
                _paymentTokenID = ptID;
            }

        }

        uint currencyKey = tokenKey.addressKeyCreate(_paymentTokenAddress, _paymentTokenID);
        return currencyKey;
      }
      function currencyTokenKey(address sC, uint ptID ) public onlyTokenRewards() returns (uint){
         
        if(sC == address(tetherBookAddress) ){
            bool customParams = tokenBookConfig.tokenBools(ptID,1);
            bool customPaymentToken = tokenBookConfig.tokenBools(ptID,101); 

            if(customParams && customPaymentToken){
                _paymentTokenAddress = tokenBookConfig.tokenAddresses(ptID,101); 
                _paymentTokenID = tokenBookConfig.tokenUints(ptID,101); 
            }else{
                _paymentTokenAddress = sC;
                _paymentTokenID = ptID;
            }

        }

        uint currencyKey = tokenKey.addressKeyCreate(_paymentTokenAddress, _paymentTokenID);
        return currencyKey;
      }
      // function internalTransfer(uint tID, uint aID, address sC, uint ptID, uint payTID, uint payAID, uint a, string memory n ) public onlyTokenRewards() returns (bool){
      //   bool transferred = receiptBook.internalTransfer(tID,aID,sC,ptID,payTID,payAID,a,n);
      //   return transferred;
      // }
      function internalTransfer(uint fromAccountKey, uint paymentAddressKey, uint toAccountKey, uint a, string memory n ) public onlyTokenRewards() returns (bool){
        bool transferred = receiptBook.internalTransfer(fromAccountKey,paymentAddressKey,toAccountKey,a,n);
        return transferred;
      }


      //NOTE min payment is 1.00 USDT aka 1000000
    //totalPayments[tokenID][aID][paymentMethodAddress][ptID] = totalPayment
      //
      function payment(uint tID, uint aID, address sC, uint ptID, address _from, uint amount, string memory note ) public  {
        //  address paymentAddress = tethers[tetherIndex];
        // address _paymentTokenAddress; 
        // uint _paymentTokenID; 

        if(sC == address(tetherBookAddress) ){
            bool customParams = tokenBookConfig.tokenBools(ptID,1);
            bool customPaymentToken = tokenBookConfig.tokenBools(ptID,101); 

            if(customParams && customPaymentToken){
                _paymentTokenAddress = tokenBookConfig.tokenAddresses(ptID,101); 
                _paymentTokenID = tokenBookConfig.tokenUints(ptID,101); 
            }else{
                _paymentTokenAddress = sC;
                _paymentTokenID = ptID;
            }

        }

        
        uint ptIDTetherBookKey = tokenKey.addressKeyCreate(tetherBookAddress, ptID);

        uint accountKey = tokenKey.accountKeyCreate(address(this), tID, aID);
        uint stockKey = tokenKey.addressKeyCreate(address(this), tID);
        uint currencyKey = tokenKey.addressKeyCreate(_paymentTokenAddress, _paymentTokenID);



        tokenRewards.payOwner(ptID,tID);
        // tokenRewards.payOwner(ptID,tID,"Pay Token Owner via payment");

        processPayment(_paymentTokenAddress,_paymentTokenID,_from,amount);

        receiptBook.recordPayment(aID,tID, _from, note);
        receiptBook.reportPayment(stockKey, accountKey, currencyKey, msg.sender, amount);

        if(aID == 0){
          worthBook.updateTokenWorth(tetherBookAddress, tID);
        }
        
        worthBook.updateTokenPaid(ptIDTetherBookKey, stockKey);

      }
      function processPayment(address sC, uint ptID, address _payer, uint amount) private {
        //  bool funded = false;
        //  //make sure payment was sent
        //  uint payerBalance = paymentBalance(methodIndex,payer);
        //  uint allowance = tethers[methodIndex].allowance(payer,address(this));
        //  funded = allowance >= amount;
          uint methodIndex = paymentMethods.tetherIndex(sC);
          bool funded = paymentMethods.paymentFunded(methodIndex, ptID, _payer, address(this), amount);
          require(funded == true,"payment not funded");
        //   PaymentAttempt(payer,address(this), paymentCurrency,amount,tethers[methodIndex], allowance,payerBalance,funded);
              //tether.preTransfer(address(this) ,amount);
              // TransferAttempt(payer,address(this), paymentCurrency,amount,tetherUSDT,allowance,payerBalance,funded);
            if(ptID == 0){
                address tetherAddress = paymentMethods.paymentMethods(methodIndex);
                Tether(tetherAddress).transferFrom(_payer,address(this), amount);
            }else{
                address tetherAddress = paymentMethods.paymentMethods(methodIndex);
                TetherBook(tetherAddress).transferFrom(ptID,_payer,address(this), amount);
            }
      }
      function internalPayment(uint tID, uint aID, address sC, uint ptID, uint pay_to_id, uint pay_to_aID, uint a, string memory note ) public  returns (bool)  {
        // uint contract_money = tether.balanceOf(this);
        tokenKey.addressKeyCreate(msg.sender, 0);
        bool accountAccess = hasAccountAccess(tID, aID, msg.sender );
        if(accountAccess){
            //_payOut(tID, aID, sC, ptID, pay_to, a, note);
            uint paymentAddressKey = _currencyTokenKey(sC,ptID );


            uint fromAccountKey = tokenKey.accountKeyCreate(address(this), tID, aID);
            uint toAccountKey = tokenKey.accountKeyCreate(address(this), pay_to_id, pay_to_aID);
            bool transferred = receiptBook.internalTransfer(fromAccountKey,paymentAddressKey,toAccountKey,a,note);

            recordInternalPayment(tID, aID, sC,ptID, pay_to_id, pay_to_aID,a ,note ); 
            if(pay_to_aID == 0){
                worthBook.updateTokenWorth(tetherBookAddress, pay_to_id);
            }
            
            return transferred;
        }else{
            return false;
        }  

      }
      function recordInternalPayment(uint tID, uint aID, address sC, uint ptID, uint pay_to_id, uint pay_to_aID, uint a, string memory note ) private  returns (bool)  {

     
            uint paymentAddressKey = _currencyTokenKey(sC,ptID );
            fromTokenKey = tokenKey.addressKeyCreate(address(this), tID);
            toTokenKey = tokenKey.addressKeyCreate(address(this), pay_to_id);

            uint fromAccountKey = tokenKey.accountKeyCreate(address(this), tID, aID);
            uint toAccountKey = tokenKey.accountKeyCreate(address(this), pay_to_id, pay_to_aID);

            receiptBook.recordPayOut(aID,tID, address(this), note);
            receiptBook.reportPayOut(fromTokenKey, fromAccountKey, paymentAddressKey, address(this), a);

            receiptBook.recordPayment(aID,tID, address(this), note);
            receiptBook.reportPayment(toTokenKey, toAccountKey, paymentAddressKey, address(this), a);
            return true;


      }
      function hasAccountAccess(uint tID, uint aID, address spender ) public view returns (bool)  {
        // uint contract_money = tether.balanceOf(this);

        bool customParams = tokenBookConfig.tokenBools(tID,1);
        bool customPermission = tokenBookConfig.tokenBools(tID,100); 
        uint permissionTID;
        address permissionAddress;

        if(customParams && customPermission){
            permissionAddress = tokenBookConfig.tokenAddresses(tID,100); 
            permissionTID = tokenBookConfig.tokenUints(tID,100); 
        }else{
            permissionAddress = tokenBookAddress;
            permissionTID = tID;
        }
        if(msg.sender == tokenRewardsAddress){
        }
        else if( manageable.hasOnlyAccountAdminPermission(permissionAddress,permissionTID,aID,spender,0) ){
          require(aID != worthBookAccountID,"Cant pay out of profit account");
        }else{
          require(manageable.hasOnlyAccountAdminPermission(permissionAddress,permissionTID,aID,spender,0),"Admin of token can do this");
        }
        return true;


      }

      // function processEthPayment(address payer, uint amount) private returns (bool)  {
      //    // require(currency == paymentCurrency);
      //     uint payerBalance = msg.value;
      //     bool funded = false;
      //     //make sure payment was sent
      //     if(payerBalance >= amount){
      //         funded = true;
      //         //require(sent);
      //         //add payment info to payments object, from, amount
      //         recordPayment(payer,amount);
      //         Payment(payer, address(this), 'ETH', amount);
      //     }
      //     return funded;
      // }

      function preTransfer(uint _tokenID, address from, address to) public  {
        tokenRewards.preTransfer(_tokenID, from, to);
      }
      function postTransfer(uint _tokenID, address from, address to) public  {
        tokenRewards.postTransfer(_tokenID, from, to);
      }
      function onTetherBookDeposit(address from, uint tokenID,  uint value) public returns (bool){
        emit TetherBookDeposit(from,tokenID,value);
        return true;
      }



  }

//tokenBank end

//receiptBook start
// ----------------------------------------------------------------------------
// Tether contract
// ----------------------------------------------------------------------------
/*
contract Tether {
    uint public decimals;
    uint public basisPointsRate;
    uint public maximumFee;
    function totalSupply() public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);

    function transfer(address to, uint tokens) public;
    function preTransfer(address to, uint tokens) public;

    function allowance(address owner, address spender) public view returns (uint);
    function transferFrom(address from, address to, uint value) public;
    function approve(address spender, uint value) public;
}
*/
// ----------------------------------------------------------------------------
// TetherBook contract
// ----------------------------------------------------------------------------
/*
contract TetherBook  {
    uint public decimals;
    // mapping(address => uint) public balances;
    address  public worthBookAddress;
    // address  public bankAddress; //bankAddress[tokenID] mapping
    address public bankAddress;
    WorthBook internal worthBook;
    Bank internal bank;
    mapping(uint => uint) public paymentMethodID;
    mapping(uint => uint) public paymentTokenID;
    mapping(uint => uint) public bankID;
    mapping(uint => mapping(address => uint)) public balances;
    mapping(uint => mapping (uint => address)) public tokenMetaAddress;
    mapping(uint => uint) public basisPointsRate;
    mapping(uint => uint) public maximumFee;

    function totalSupply(uint tokenID) public view returns (uint);
    function balanceOf(uint tokenID, address tokenOwner) public view returns (uint balance);

    function transfer(uint tokenID, address to, uint tokens) public;
    function preTransfer(uint tokenID, address to, uint tokens) public;

    function allowance(uint tokenID, address owner, address spender) public view returns (uint);
    function transferFrom(uint tokenID, address from, address to, uint value) public;
    function approve(uint tokenID, address spender, uint value) public;
}
*/
// ----------------------------------------------------------------------------
// WorthBook contract
// ----------------------------------------------------------------------------
/*
contract WorthBook {
    function  updateTokenWorth(address paymentMethod) public;
    function  setPaymentDecimals(address stableCoin) public;
    function owed(address _stockAddress, uint _tokenID, address owner, uint _tokenOwnerID) public  returns (uint);
    function updateTokenPaid(address _stockAddress, uint _tokenID, address pay_to, uint pay_to_tokeID) public returns (bool);
    function  updateTokenWorth(address _stockAddress, uint _tokenID) public;
    function updateTransferTokens(address _stockAddress, uint _tokenID,address from, address to) public;
}
*/

// ----------------------------------------------------------------------------
// TokenRewards contract
// ----------------------------------------------------------------------------
/*
contract TokenRewards {
    function payOwner(uint tID, address pay_to, string memory note ) public returns (bool);
    function payOwner(uint tID, uint pay_tID) public   returns (bool);
}
*/
/*
// ----------------------------------------------------------------------------
// PaymentMethods contract
// ----------------------------------------------------------------------------
contract PaymentMethods {
     mapping(uint => uint) public _payment;
     function fee(uint currencyKey, uint amount) public;
}

// ----------------------------------------------------------------------------
// Bank contract
// ----------------------------------------------------------------------------
contract Bank {
    uint public totalPaymentCnt;
    uint public paymentMethodCnt;
    TetherBook public tetherBook;
    address public tetherBookAddress;
    TokenRewards public tokenRewards;
    address public tokenRewardsAddress;

    PaymentMethods public paymentMethods;
    address public paymentMethodsAddress;
    
    TokenKey public tokenKey;
    address public tokenKeyAddress;

    address public worthBookAddress;
    Manageable public manageable;
    address public manageableAddress;
    // mapping(uint => Tether) public bank.paymentMethods; //[payOutCnt][ownerAddress] = payment
    mapping(uint => Tether) public tethers; //[payOutCnt][ownerAddress] = payment
     mapping(uint => TetherBook) public tetherBooks; //[payOutCnt][ownerAddress] = payment
    mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public totalPayments;
    //balances[tokenID][accountID][paymentMethodAddress][paymentTokenID] = accountBalance
     mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public accountBalance;
     //balances[tokenID][paymentMethodAddress][paymentTokenID] = totalBalance
     mapping(uint => mapping(address => mapping(uint => uint) ) ) public totalBalance;
    function payOut(uint tID, uint aID, address sC, uint ptID, address pay_to, uint amount, string memory note) public;
    function payment(address paymentMethod, address _from, uint amount, string memory note) public returns (bool);
}

// ----------------------------------------------------------------------------
// TokenBook contract
// ----------------------------------------------------------------------------
contract TokenBook is Manageable {
}

// contract TetherBook is Manageable, TokenMetaAddress {
contract TokenKey {
   struct _tokenAddressKey{
        string name;
        uint keyCnt;
        mapping (address => mapping (uint => bool)) keySet; //Maps addresses to index in `tests
        mapping (address => mapping (uint => uint)) key; //Maps addresses to index in `tests
    }
    struct _tokenAccountKey{
        string name;
        uint keyCnt;
        mapping (uint => mapping (uint => bool)) keySet; //Maps addresses to index in `tests
        mapping (uint => mapping (uint => uint)) key; //Maps addresses to index in `tests
    }
    mapping (uint => address)  public addressKeyContract;
     mapping (uint => uint)  public addressKeyTokenID;

     mapping (uint => address)  public accountKeyContract;
     mapping (uint => uint)  public accountKeyTokenID;
     mapping (uint => uint)  public accountKeyAccountID;

     mapping (uint => address)  public subAccountKeyContract;
     mapping (uint => uint)  public subAccountKeyTokenID;
     mapping (uint => uint)  public subAccountKeyAccountID;
     mapping (uint => uint)  public subAccountKeySubAccountID;
    _tokenAddressKey _addressKey ;
    _tokenAccountKey _accountKey ;
    _tokenAccountKey _subAccountKey ;
    function addressKey(address tokenAddress, uint tokenID ) public view returns (uint);
    function accountKey(address tokenAddress, uint tokenID, uint accountID ) public view returns (uint);
    function subAccountKey(address tokenAddress, uint tokenID, uint accountID, uint subAccountID  ) public view returns (uint);
    function addressKeyCreate(address tokenAddress, uint tokenID ) public returns (uint);
    function accountKeyCreate(address tokenAddress, uint tokenID, uint accountID ) public  returns (uint);
}
*/
// }
// ----------------------------------------------------------------------------
// ReceiptBook contract
// ----------------------------------------------------------------------------
contract ReceiptBook is Ownable {
    using SafeMath for uint;
    WorthBook internal worthBook;
    address public worthBookAddress;

    TokenRewards internal tokenRewards;
    address public tokenRewardsAddress;

    Bank internal bank;
    address public bankAddress;

    PaymentMethods internal paymentMethods;
    address public paymentMethodsAddress;

    TokenKey internal tokenKey;
    address public tokenKeyAddress;

    Manageable internal manageable;
    address public manageableAddress;
    address public tokenBookConfigAddress;
    TokenBookConfig public tokenBookConfig;




    /*
      main purpos of this contract is to
      record payouts and payments for a bank
      only the bank contract can update this contract
      when payments happend this contract needs to report it to the token worth contract aka divdiends contract
      this contract is responsible for emiting all payment related events

      thats it!!

    */

 
    /*
        _s // list of ppl who paid
        payee // list of ppl who got paid
        payments // list of payments with amounts
        payOuts // list of payments with amounts
        totalPayments
        totalPayouts
        balances
        payment methods
        paymentNotes
        payOutNotes

    */

     //balances[tokenID][accountID][paymentMethodAddress][paymentTokenID] = balance
     mapping(uint => uint ) public payments; // payments[paymentCnt]= payment
     mapping(uint => uint ) public payOuts; //payOuts[payOutCnt] = payOut
     mapping(uint => address ) public payer; //payer[paymentCnt]= payer
     mapping(uint => address ) public payee; //payee[payOutCnt] = payee
     mapping(uint => address ) public paymentContract; //paymentContract[paymentCnt] = paymentMethodAddress
     mapping(uint => uint ) public paymentContractTokenID; //paymentContract[paymentCnt] = paymentContractTokenID
     mapping(uint => uint ) public paymentTokenID; //paymentTokenID[paymentCnt] = tokenID
     mapping(uint => uint ) public paymentAccountID; //paymentAccountID[paymentCnt] = accountID
     mapping(uint => uint ) public paymentTime; //paymentAccountID[paymentCnt] = accountID
    //  mapping(uint => uint ) public paymentBlock; //paymentAccountID[paymentCnt] = accountID
     mapping(uint => bytes32 ) public paymentTx; //paymentAccountID[paymentCnt] = accountID
     mapping(uint => uint ) public paymentFee; //paymentAccountID[paymentCnt] = accountID
     mapping(uint => address ) public payOutContract; //paymentContract[paymentCnt] = paymentMethodAddress
     mapping(uint => uint ) public payOutContractTokenID; //payOutContractTokenID[paymentCnt] = payOutContractTokenID
     mapping(uint => uint ) public payOutTokenID; //payOutTokenID[payOutCnt] = tokenID
     mapping(uint => uint ) public payOutAccountID; //payOutAccountID[payOutCnt] = accountID
     mapping(uint => uint ) public payOutTime; //paymentAccountID[paymentCnt] = accountID
    //  mapping(uint => uint ) public payOutBlock; //paymentAccountID[paymentCnt] = accountID
     mapping(uint => uint ) public payOutFee; //paymentAccountID[paymentCnt] = accountID
     mapping(uint => bytes32 ) public payOutTx; //paymentAccountID[paymentCnt] = accountID


     // to and from need access to edit payment notes
     mapping(uint => string ) public paymentNote; //paymentNote[paymentCnt] = note
     mapping(uint => string ) public payOutNote; //payOutNote[payOutCnt][noteCnt] = note

    


     
     
    //for fee /paymentmethod
     mapping(uint => uint) public _payment;

    // tokenPayments[tokenKey][tokenPaymentCnt] = paymentCnt
     mapping(uint => mapping(uint => uint)) public tokenPayments;
    // [tokenKey][tokenPayOutCnt] = payOutCnt
     mapping(uint => mapping(uint => uint)) public tokenPayOuts;
    //[tokenKey] = tokenPayOutCnt
     mapping(uint => uint ) public tokenPayOutCnt;
    //[tokenKey] = tokenPaymentCnt
     mapping(uint => uint ) public tokenPaymentCnt;


    //old balances

    //   //tetherBook tokenID Amount
    //  mapping(address => mapping(uint => uint) ) public bankBalance;
    //  //tetherBook tokenID Amount
    //  mapping(address => mapping(uint => uint) ) public totalBankPayments;
    //  //tetherBook tokenID Amount
    //  mapping(address => mapping(uint => uint) ) public totalBankPayOuts;

    //  //totalPayments[tokenID][accountID][paymentMethodAddress][paymentTokenID] = totalPayment
    //  mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public totalPayments;
    //  //totalPayOuts[tokenID][accountID][paymentMethodAddress][paymentTokenID] = totalPayOut
    //  mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public totalPayOuts;
    //  //balances[tokenID][accountID][paymentMethodAddress][paymentTokenID] = accountBalance
    //  mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public accountBalance;
    //  //balances[tokenID][paymentMethodAddress][paymentTokenID] = totalBalance
    //  mapping(uint => mapping(address => mapping(uint => uint) ) ) public totalBalance;


    // new balances 

    //tetherBook tokenID Amount
    //bankBalance[currencyKey] = currencyBalance
     mapping(uint => uint)  public bankBalance;
     //totalBankPayments[currencyKey] = totalCurrencyPayments
     mapping(uint => uint)  public totalBankPayments;
     //totalBankPayOuts[currencyKey] = totalCurrencyPayOuts
     mapping(uint => uint)  public totalBankPayOuts;


     //totalPayments[accountKey][currencyKey] = totalPayments
     mapping(uint => mapping(uint => uint ) ) public totalPayments;
     //totalPayOuts[accountKey][currencyKey] = totalPayOuts
     mapping(uint => mapping(uint => uint ) ) public totalPayOuts;
     //accountBalance[accountKey][currencyKey] = accountBalance
     mapping(uint => mapping(uint => uint ) ) public accountBalance;
     //totalBalance[tokenKey][currencyKey] = totalBalance
     mapping(uint => mapping(uint => uint ) ) public totalBalance;




     uint public totalPaymentCnt = 0;
     uint public totalPayOutCnt = 0;
      event Account(uint indexed tokenID, uint indexed accountID);
      event Payment(uint indexed noteIndex, address  _from, address indexed paymentMethod, uint indexed paymentTokenID,uint payment);
      event PayOut(uint indexed noteIndex, address  _to, address indexed paymentMethod, uint indexed paymentTokenID, uint payment);
      event Config(address indexed bankAddress, address indexed worthBookAddress, address indexed tokenRewardsAddress);
      event Config2(address indexed manageableAddress);


    // ???
     mapping(address => uint) public tetherIndex;

      constructor() public {
      }
      modifier onlyBank() {
          require(msg.sender == bankAddress || msg.sender == tokenRewardsAddress,"only banks can do this");
          _;
      }
      /**
      * @dev Throws if called by any account other than the manager or admin.
      */
      modifier onlyExecutives() {
          bool executive = manageable.executives(address(this),msg.sender);
          require(executive,"only executives");
          _;
      }
      function config(address newTokenBookConfigAddress) public onlyOwner  {
            tokenBookConfig = TokenBookConfig(newTokenBookConfigAddress);
            tokenBookConfigAddress = newTokenBookConfigAddress;
            address newBankAddress = tokenBookConfig.contractAddresses(5);
            bankAddress = newBankAddress;
            bank = Bank(newBankAddress);
            worthBookAddress = bank.worthBookAddress();
            worthBook = WorthBook(worthBookAddress);
            tokenRewardsAddress = bank.tokenRewardsAddress();
            tokenRewards = TokenRewards(tokenRewardsAddress);
            paymentMethodsAddress = bank.paymentMethodsAddress();
            paymentMethods = PaymentMethods(paymentMethodsAddress);
            tokenKeyAddress = bank.tokenKeyAddress();
            tokenKey = TokenKey(tokenKeyAddress);
            manageableAddress = bank.manageableAddress();
            manageable = Manageable(manageableAddress);
            emit Config(bankAddress,worthBookAddress,tokenRewardsAddress);
            emit Config2(manageableAddress);
      }
      function internalTransfer(uint fromAccountKey, uint paymentAddressKey, uint toAccountKey, uint a, string memory n ) public onlyBank returns (bool){
        uint toTokenID = tokenKey.accountKeyTokenID(toAccountKey);
        uint fromTokenID = tokenKey.accountKeyTokenID(fromAccountKey);
        uint ptID = tokenKey.addressKeyTokenID(paymentAddressKey);
        uint currentAccountBalance = accountBalance[fromAccountKey][paymentAddressKey];
        require(toTokenID != 0, "Cant pay to zero tokenID");
        require(a <= currentAccountBalance,"Transfer exceeds account balance");
        // pay Owner of token being transfered
        if(ptID>0){
          // tokenRewards.payOwner(ptID,fromTokenID,"Internal Transfer Pay Token Owner");
          // tokenRewards.payOwner(ptID,toTokenID,"Internal Transfer Pay Token Owner");
          tokenRewards.payOwner(ptID,fromTokenID);
          tokenRewards.payOwner(ptID,toTokenID);
        }
        internalTransfer1(fromAccountKey,paymentAddressKey, toAccountKey,a, n );
        
        return true;
      }
      function internalTransfer1(uint fromAccountKey, uint paymentAddressKey, uint toAccountKey, uint a, string memory n ) private returns (string memory) {

        address fromContract = tokenKey.accountKeyContract(fromAccountKey);
        uint fromTokenID = tokenKey.accountKeyTokenID(fromAccountKey);
        address toContract = tokenKey.accountKeyContract(toAccountKey);
        uint toTokenID = tokenKey.accountKeyTokenID(toAccountKey);
        uint fromAddressKey = tokenKey.addressKeyCreate(fromContract,fromTokenID);
        uint toAddressKey = tokenKey.addressKeyCreate(toContract,toTokenID);
        // string memory note = n;

        uint fromBalance = accountBalance[fromAccountKey][paymentAddressKey];
        fromBalance = fromBalance.sub(a);
        accountBalance[fromAccountKey][paymentAddressKey] = fromBalance;
        totalBalance[fromAddressKey][paymentAddressKey] = totalBalance[fromAddressKey][paymentAddressKey].sub(a);
        accountBalance[toAccountKey][paymentAddressKey] = accountBalance[toAccountKey][paymentAddressKey].add(a);
        totalBalance[toAddressKey][paymentAddressKey] = totalBalance[toAddressKey][paymentAddressKey].add(a);
        
        return n;
        // return true;
      }

      

      function  recordPayment(uint accountID, uint _paymentTokenID, address _payer, string memory note) public onlyBank {
          payer[totalPaymentCnt] = _payer;
          paymentTokenID[totalPaymentCnt] = _paymentTokenID;
          paymentAccountID[totalPaymentCnt] = accountID;
          paymentNote[totalPaymentCnt] = note;
          paymentTime[totalPaymentCnt] = now;
        //   paymentBlock[totalPaymentCnt] = block.number;
          paymentTx[totalPaymentCnt] = blockhash(block.number);
      }
      // function  reportPayment(uint tokenID, uint accountID, uint methodIndex, uint _paymentTokenID, address _payer, uint amount) public onlyBank {
      //   emit Account(tokenID, accountID);
      //    paymentMethods.fee(currencyKey,amount);
      //   uint sendAmount = _payment[0];
      //   uint _fee = _payment[1];
      //   payments[totalPaymentCnt] = sendAmount;
      //   paymentFee[totalPaymentCnt] = _fee;
      //   paymentContract[totalPaymentCnt] = bank.paymentMethods(methodIndex);
      //   uint _totalPayment = totalPayments[tokenID][accountID][bank.paymentMethods(methodIndex)][_paymentTokenID].add(sendAmount);
      //   uint _accountBalance = accountBalance[tokenID][accountID][bank.paymentMethods(methodIndex)][_paymentTokenID].add(sendAmount);
      //   uint _totalBalance = totalBalance[tokenID][bank.paymentMethods(methodIndex)][_paymentTokenID].add(sendAmount);
      //   totalPayments[tokenID][accountID][bank.paymentMethods(methodIndex)][_paymentTokenID] = _totalPayment;
      //   accountBalance[tokenID][accountID][bank.paymentMethods(methodIndex)][_paymentTokenID] = _accountBalance;
      //   totalBalance[tokenID][bank.paymentMethods(methodIndex)][_paymentTokenID] = _totalBalance;
      //   emit Payment(totalPaymentCnt, _payer, bank.paymentMethods(methodIndex),_paymentTokenID, sendAmount);
        
      //   tokenPayments[tokenID][tokenPaymentCnt[tokenID]] = totalPaymentCnt;
      //   tokenPaymentCnt[tokenID]++;
      //   totalPaymentCnt++;

      //   bankBalance[bank.paymentMethods(methodIndex)][_paymentTokenID] = bankBalance[bank.paymentMethods(methodIndex)][_paymentTokenID].add(sendAmount);
      //   totalBankPayments[bank.paymentMethods(methodIndex)][_paymentTokenID] = totalBankPayments[bank.paymentMethods(methodIndex)][_paymentTokenID].add(sendAmount);
      // }
      function  reportPayment(uint stockKey, uint accountKey, uint currencyKey, address _payer, uint amount) public onlyBank {
        emit Account(stockKey, accountKey);
        paymentMethods.fee(currencyKey,amount);
        address currencyContract = tokenKey.addressKeyContract(currencyKey);
        uint _paymentTokenID = tokenKey.addressKeyTokenID(currencyKey);
        uint sendAmount = paymentMethods._payment(0);
        uint _fee = paymentMethods._payment(1);
        payments[totalPaymentCnt] = sendAmount;
        paymentFee[totalPaymentCnt] = _fee;
        paymentContract[totalPaymentCnt] = currencyContract;
        paymentContractTokenID[totalPaymentCnt] = _paymentTokenID;
        uint _totalPayment = totalPayments[accountKey][currencyKey].add(sendAmount);
        uint _accountBalance = accountBalance[accountKey][currencyKey].add(sendAmount);
        uint _totalBalance = totalBalance[stockKey][currencyKey].add(sendAmount);
        totalPayments[accountKey][currencyKey] = _totalPayment;
        accountBalance[accountKey][currencyKey] = _accountBalance;
        totalBalance[stockKey][currencyKey] = _totalBalance;
        emit Payment(totalPaymentCnt, _payer, currencyContract,_paymentTokenID, sendAmount);
        
        bankBalance[currencyKey] = bankBalance[currencyKey].add(sendAmount);
        totalBankPayments[currencyKey] = totalBankPayments[currencyKey].add(sendAmount);
        reportPayment1(stockKey);
      }
      function  reportPayment1(uint stockKey) private {
        tokenPayments[stockKey][tokenPaymentCnt[stockKey]] = totalPaymentCnt;
        tokenPaymentCnt[stockKey]++;
        totalPaymentCnt++;
      }
      function  recordPayOut(uint accountID, uint _paymentTokenID, address _payee, string memory note) public  onlyBank {
          payee[totalPayOutCnt] = _payee;
          payOutTokenID[totalPayOutCnt] = _paymentTokenID;
          payOutAccountID[totalPayOutCnt] = accountID;
          payOutNote[totalPayOutCnt] = note;
          payOutTime[totalPayOutCnt] = now;
        //   payOutBlock[totalPayOutCnt] = block.number;
          payOutTx[totalPayOutCnt] = blockhash(block.number);
      }
      // function  reportPayOut(uint tokenID, uint accountID, uint methodIndex, uint _paymentTokenID, address _payee, uint amount) public onlyExecutives {
      //   emit Account(tokenID, accountID);
      //    paymentMethods.fee(currencyKey,amount);
      //   uint sendAmount = _payment[0];
      //   uint _fee = _payment[1];
      //   payOuts[totalPayOutCnt] = sendAmount;
      //   payOutFee[totalPayOutCnt] = _fee;
      //   payOutContract[totalPayOutCnt] = bank.paymentMethods(methodIndex);
      //   uint _totalPayOut = totalPayOuts[tokenID][accountID][bank.paymentMethods(methodIndex)][_paymentTokenID].add(sendAmount);
      //   uint _accountBalance = accountBalance[tokenID][accountID][bank.paymentMethods(methodIndex)][_paymentTokenID].sub(sendAmount);
      //   uint _totalBalance = totalBalance[tokenID][bank.paymentMethods(methodIndex)][_paymentTokenID].sub(sendAmount);
      //   totalPayOuts[tokenID][accountID][bank.paymentMethods(methodIndex)][_paymentTokenID] = _totalPayOut;
      //   accountBalance[tokenID][accountID][bank.paymentMethods(methodIndex)][_paymentTokenID] = _accountBalance;
      //   totalBalance[tokenID][bank.paymentMethods(methodIndex)][_paymentTokenID] = _totalBalance;
      //   emit PayOut(totalPayOutCnt, _payee, bank.paymentMethods(methodIndex),_paymentTokenID, sendAmount);
      //   tokenPayOuts[tokenID][tokenPayOutCnt[tokenID]] = totalPayOutCnt;
      //   tokenPayOutCnt[tokenID]++;
      //   totalPayOutCnt++;

      //   bankBalance[bank.paymentMethods(methodIndex)][_paymentTokenID] = bankBalance[bank.paymentMethods(methodIndex)][_paymentTokenID].sub(sendAmount);
      //   totalBankPayOuts[bank.paymentMethods(methodIndex)][_paymentTokenID] = totalBankPayments[bank.paymentMethods(methodIndex)][_paymentTokenID].add(sendAmount);
      // }
      function  reportPayOut(uint stockKey, uint accountKey, uint currencyKey, address _payee, uint amount) public onlyBank {
        emit Account(stockKey, accountKey);
        paymentMethods.fee(currencyKey,amount);
        address currencyContract = tokenKey.addressKeyContract(currencyKey);
        uint _paymentTokenID = tokenKey.addressKeyTokenID(currencyKey);

        uint sendAmount = paymentMethods._payment(0);
        uint _fee = paymentMethods._payment(1);
        payOuts[totalPayOutCnt] = sendAmount;
        payOutFee[totalPayOutCnt] = _fee;
        payOutContract[totalPayOutCnt] = currencyContract;
        payOutContractTokenID[totalPayOutCnt] = _paymentTokenID;
        uint _totalPayOut = totalPayOuts[accountKey][currencyKey].add(sendAmount);
        uint _accountBalance = accountBalance[accountKey][currencyKey].sub(sendAmount);
        uint _totalBalance = totalBalance[stockKey][currencyKey].sub(sendAmount);
        totalPayOuts[accountKey][currencyKey] = _totalPayOut;
        accountBalance[accountKey][currencyKey] = _accountBalance;
        totalBalance[stockKey][currencyKey] = _totalBalance;
        emit PayOut(totalPayOutCnt, _payee, currencyContract,_paymentTokenID, sendAmount);
        bankBalance[currencyKey] = bankBalance[currencyKey].sub(sendAmount);
        totalBankPayOuts[currencyKey] = totalBankPayOuts[currencyKey].add(sendAmount);
        reportPayOut1(stockKey);
      }
      function  reportPayOut1(uint stockKey) private {
        tokenPayOuts[stockKey][tokenPayOutCnt[stockKey]] = totalPayOutCnt;
        tokenPayOutCnt[stockKey]++;
        totalPayOutCnt++;
      }



  }
//receiptBook end

//TokenRewards start
/*
// ----------------------------------------------------------------------------
// Tether contract
// ----------------------------------------------------------------------------
contract Tether {
    uint public decimals;
    uint public basisPointsRate;
    uint public maximumFee;
    function totalSupply() public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);

    function transfer(address to, uint tokens) public;
    function preTransfer(address to, uint tokens) public;

    function allowance(address owner, address spender) public view returns (uint);
    function transferFrom(address from, address to, uint value) public;
    function approve(address spender, uint value) public;
 
}
// ----------------------------------------------------------------------------
// TetherBook contract
// ----------------------------------------------------------------------------
contract TetherBook  {
    uint public decimals;
    // mapping(address => uint) public balances;
    address  public worthBookAddress;
    // address  public bankAddress; //bankAddress[tokenID] mapping
    address public bankAddress;
    Dividends internal worthBook;
    mapping(uint => uint) public paymentMethodID;
    mapping(uint => uint) public paymentTokenID;
    mapping(uint => uint) public bankID;
    mapping(uint => mapping(address => uint)) public balances;
    mapping(uint => mapping (uint => address)) public tokenMetaAddress;
    mapping(uint => uint) public basisPointsRate;
    mapping(uint => uint) public maximumFee;

    function totalSupply(uint tokenID) public view returns (uint);
    function balanceOf(uint tokenID, address tokenOwner) public view returns (uint balance);

    function transfer(uint tokenID, address to, uint tokens) public;
    function preTransfer(uint tokenID, address to, uint tokens) public;

    function allowance(uint tokenID, address owner, address spender) public view returns (uint);
    function transferFrom(uint tokenID, address from, address to, uint value) public;
    function approve(uint tokenID, address spender, uint value) public;
 
}
*/
// ----------------------------------------------------------------------------
// Dividens contract
// ----------------------------------------------------------------------------
contract Dividends {
    function  updateTokenWorth(address paymentMethod) public;
    function  setDecimals(address stableCoin) public;
    function owed(address _stockAddress, uint _tokenID, address owner, uint _tokenOwnerID) public  returns (uint);
    function updateTokenPaid(address _stockAddress, uint _tokenID, address pay_to, uint pay_to_tokeID) public returns (bool);
    function  updateTokenWorth(address _stockAddress, uint _tokenID) public;
    function updateTransferTokens(address _stockAddress, uint _tokenID,address from, address to) public;
    
    
}
/*
// ----------------------------------------------------------------------------
// Bank contract
// ----------------------------------------------------------------------------
contract Bank {
    uint public totalPaymentCnt;
    uint public paymentMethodCnt;
    TetherBook public tetherBook;
    address public tetherBookAddress;
    address public worthBookAddress;
    TokenKey public tokenKey;
    address public tokenKeyAddress;
    ReceiptBook public receiptBook;
    address public receiptBookAddress;
     mapping(uint => address) public paymentMethods;
    // mapping(uint => Tether) public bank.paymentMethods; //[payOutCnt][ownerAddress] = payment
    mapping(uint => Tether) public tethers; //[payOutCnt][ownerAddress] = payment
     mapping(uint => TetherBook) public tetherBooks; //[payOutCnt][ownerAddress] = payment
    
    mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public totalPayments;
    //balances[tokenID][accountID][paymentMethodAddress][paymentTokenID] = accountBalance
     mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public accountBalance;
     //balances[tokenID][paymentMethodAddress][paymentTokenID] = totalBalance
     mapping(uint => mapping(address => mapping(uint => uint) ) ) public totalBalance;
    
    function payOut(uint tID, uint aID, address sC, uint ptID, address pay_to, uint a, string memory note ) public  returns (bool);
    function payment(uint tID, uint aID, address sC, uint ptID, address _from, uint amount, string memory note ) public;
    // function internalTransfer(uint tID, uint aID, address sC, uint ptID, uint payTID, uint payAID, uint a, string memory n ) public  returns (bool);
    function internalTransfer(uint fromAccount, uint paymentAddressKey, uint toAccount, uint a, string memory n ) public  returns (bool);
    // function internalTransfer(uint fromAccount, uint paymentAddressKey, uint toAccount, uint a) public  returns (bool);
}

// ----------------------------------------------------------------------------
// WorthBook contract
// ----------------------------------------------------------------------------
contract WorthBook {
    function  updateTokenWorth(address paymentMethod) public;
    function  setPaymentDecimals(address stableCoin) public;
    function owed(address _stockAddress, uint _tokenID, address owner, uint _tokenOwnerID) public  returns (uint);
    function updateTokenPaid(uint _stockKey, uint _ownerKey) public returns (bool);
    function  updateTokenWorth(address _stockAddress, uint _tokenID) public;
    function updateTransferTokens(address _stockAddress, uint _tokenID,address from, address to) public;
    function setKeys(address _stockAddress, uint _tokenID ) public;
    
}

// ----------------------------------------------------------------------------
// TokenBook contract
// ----------------------------------------------------------------------------
contract TokenBook is Manageable {
    
}

// contract TetherBook is Manageable, TokenMetaAddress {
    
contract TokenKey {
   struct _tokenAddressKey{
        string name;
        uint keyCnt;
        mapping (address => mapping (uint => bool)) keySet; //Maps addresses to index in `tests
        mapping (address => mapping (uint => uint)) key; //Maps addresses to index in `tests
    }
    struct _tokenAccountKey{
        string name;
        uint keyCnt;
        mapping (uint => mapping (uint => bool)) keySet; //Maps addresses to index in `tests
        mapping (uint => mapping (uint => uint)) key; //Maps addresses to index in `tests
    }
    _tokenAddressKey _addressKey ;
    _tokenAccountKey _accountKey ;
    _tokenAccountKey _subAccountKey ;
    function addressKey(address tokenAddress, uint tokenID ) public view returns (uint);
    function accountKey(address tokenAddress, uint tokenID, uint accountID ) public view returns (uint);
    function subAccountKey(address tokenAddress, uint tokenID, uint accountID, uint subAccountID  ) public view returns (uint);
    function addressKeyCreate(address tokenAddress, uint tokenID ) public returns (uint);
    function accountKeyCreate(address tokenAddress, uint tokenID, uint accountID ) public  returns (uint);
}

// ----------------------------------------------------------------------------

// ReceiptBook contract
// ----------------------------------------------------------------------------
contract ReceiptBook {
  //balances[tokenID][accountID][paymentMethodAddress][paymentTokenID] = accountBalance
     mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public accountBalance;
     mapping(address => mapping(uint => uint) ) public bankBalance;
     
      function  recordPayment(uint accountID, uint _paymentTokenID, address _payer, string memory note) public;
      function  reportPayment(uint tokenID, uint accountID, uint methodIndex, uint _paymentTokenID, address _payer, uint amount) public;
      function  recordPayOut(uint accountID, uint _paymentTokenID, address _payee, string memory note) public;
      function  reportPayOut(uint tokenID, uint accountID, uint methodIndex, uint _paymentTokenID, address _payee, uint amount) public;
      function internalTransfer(uint tID, uint aID, address sC, uint ptID, uint payTID, uint payAID, uint a, string memory n ) public  returns (bool);
      
      function  reportPayment(uint toAccountKey, uint paymentAddressKey, uint fromAccountKey, address payer, uint amount) public;
      function  reportPayOut(uint fromAccountKey, uint paymentAddressKey, uint toAccountKey, address payee, uint amount) public;
}
*/ 
// }
// ----------------------------------------------------------------------------
// TokenBank contract
// ----------------------------------------------------------------------------
contract TokenRewards is Ownable {
    using SafeMath for uint;
    WorthBook internal worthBook;
    address public worthBookAddress;

    TetherBook public tetherBook;
    address public tetherBookAddress;

    Bank internal bank;
    address public bankAddress;
    
    TokenBookConfig tokenBookConfig;
    address public tokenBookConfigAddress;

    TokenKey tokenKey;
    address public tokenKeyAddress;

    ReceiptBook public receiptBook;
    address public receiptBookAddress;

     uint public worthBookID = 0;
     /*
      main purpos of this contract is to 
      use the token worth to caculate how much owner is owed
      pay token owner or pay user owner
      once owner is paid update worth book aka worthBook
      
      anyone can pay owner
      only this contract can pay out from bank

      thats it!!

    */
      /*
        goals
        1.payout  - pay users dividents // test ready
        2.payments - accept money  // test ready
        -----------------
        3. how much owed based owner//
        4. how much money paid to property total// totalIncome
        5. how much money earned per token// tokenWorth
        6. has owner been paid in dividens
        7. payment count //paymentCnt
        8. payment info by index
        9. cash currencies 
        10. payment balance 
        11. how much money paid to owners via dividens
        12.when trandfers happen tokenPaid musts be updated to token worth
  
  */
    event Config1(address indexed bankAddress, address indexed worthBookAddress, address indexed tetherBookAddress);
    event Config2(address indexed tokenKeyAddress);

      function config(address newTokenBookConfigAddress) public onlyOwner  {
            tokenBookConfig = TokenBookConfig(newTokenBookConfigAddress);
            tokenBookConfigAddress = newTokenBookConfigAddress;
            address newBankAddress = tokenBookConfig.contractAddresses(5);
            bankAddress = newBankAddress;
            bank = Bank(newBankAddress);
            worthBookAddress = bank.worthBookAddress();
            worthBook = WorthBook(worthBookAddress);
            tetherBookAddress = bank.tetherBookAddress();
            tetherBook = TetherBook(tetherBookAddress);
            tokenKeyAddress = bank.tokenKeyAddress();
            tokenKey = TokenKey(tokenKeyAddress);
            receiptBookAddress = bank.receiptBookAddress();
            receiptBook = ReceiptBook(receiptBookAddress);
            emit Config1(bankAddress,worthBookAddress,tetherBookAddress);
            emit Config2(tokenKeyAddress);
      }
      function payOwner(uint tID, address pay_to, string memory note ) public returns (bool)   {
        // uint contract_money = tether.balanceOf(this);
        require(pay_to != address(0),"Cant pay to zero address");
        uint amount = worthBook.owed(tetherBookAddress, tID, pay_to,0);
        // require(amount > 0,"There is nothing to pay owner");
        if(amount > 0){
            // TetherBook tetherBook = TetherBook(tetherBookAddress);
            uint _paymentMethodID = tetherBook.paymentMethodID(tID);
            uint _paymentTokenID = tetherBook.paymentTokenID(tID);
            bool customParams = tokenBookConfig.tokenBools(tID,1);
                address _paymentMethod;
                if(customParams){
                    _paymentMethod = tokenBookConfig.tokenAddresses(tID,_paymentMethodID);
        
                }else{
                    _paymentMethod = tokenBookConfig.contractAddresses(_paymentMethodID);
                }
            bool paidOut = bank.payOut(tID, worthBookID, _paymentMethod, _paymentTokenID, pay_to, amount, note);
            if(paidOut){
                uint stockKey = tokenKey.addressKeyCreate(tetherBookAddress, tID);
                uint ownerKey = tokenKey.addressKeyCreate(pay_to, 0);
                return worthBook.updateTokenPaid(stockKey, ownerKey);
            }
        }
        

      }
      function payOwner(uint tID, uint pay_tID) public   returns (bool)  {
        // uint contract_money = tether.balanceOf(this);
        require(pay_tID != 0,"Cant pay to token id zero");
        require(tID != 0,"Cant pay out from token id zero");
        worthBook.setKeys(tetherBookAddress,pay_tID);
        // tokenKey.addressKeyCreate(tetherBookAddress, pay_tID);
        
        uint amount = worthBook.owed(tetherBookAddress, tID, bankAddress, pay_tID);
        
        
        if(amount > 0){
            uint _paymentMethodID = tetherBook.paymentMethodID(tID);
            uint _paymentTokenID = tetherBook.paymentTokenID(tID);
            bool customParams = tokenBookConfig.tokenBools(tID,1);
                address _paymentMethod;
                if(customParams){
                    _paymentMethod = tokenBookConfig.tokenAddresses(tID,_paymentMethodID);
        
                }else{
                    _paymentMethod = tokenBookConfig.contractAddresses(_paymentMethodID);
                }
            uint paymentAddressKey = tokenKey.addressKeyCreate(_paymentMethod, _paymentTokenID);
            uint fromAccountKey = tokenKey.accountKeyCreate(bankAddress, tID, worthBookID);
            uint toAccountKey = tokenKey.accountKeyCreate(bankAddress, pay_tID, worthBookID);
            
            if(_paymentTokenID>0){
              payOwner(_paymentTokenID,tID);
              payOwner(_paymentTokenID,pay_tID);
            }

            // bool paidOut = bank.internalTransfer(tID, worthBookID, __paymentMethod, _paymentTokenID, pay_tID,worthBookID, amount,note);
            // bool paidOut = bank.internalTransfer(tID, tID, __paymentMethod, tID, pay_tID,tID, amount,note);
            bool paidOut = bank.internalTransfer(fromAccountKey, paymentAddressKey, toAccountKey, amount,"Pay Owner Internal Transfer");
            // bool paidOut = bank.internalTransfer(tID, worthBookID, worthBookID, amount);
            if(paidOut){

                bool success = recordPayment( tID, pay_tID, _paymentMethod, _paymentTokenID, amount);
                return success;
            }
        }
      }
      function recordPayment(uint tID, uint pay_tID, address _paymentMethod,uint _paymentTokenID, uint amount) private   returns (bool)  {

                uint stockTetherBookAddressKey = tokenKey.addressKeyCreate(tetherBookAddress, tID);
                uint ownerKey = tokenKey.addressKeyCreate(bankAddress, pay_tID);

                uint fromTokenBankKey = tokenKey.addressKeyCreate(bankAddress, tID);
                uint fromAccountKey = tokenKey.accountKeyCreate(bankAddress, tID, worthBookID);
                uint toAccountKey = tokenKey.accountKeyCreate(bankAddress, pay_tID, worthBookID);
                uint paymentAddressKey = tokenKey.addressKeyCreate(_paymentMethod, _paymentTokenID);
                
                receiptBook.recordPayOut(worthBookID, tID, bankAddress, "Pay Owner internal transfer");
                receiptBook.reportPayOut(fromTokenBankKey, fromAccountKey,paymentAddressKey, bankAddress, amount);
                receiptBook.recordPayment(worthBookID, pay_tID, bankAddress, "Pay Owner internal transfer");
                receiptBook.reportPayment(ownerKey, toAccountKey, paymentAddressKey, bankAddress, amount);
                // return worthBook.updateTokenPaid(tetherBookAddress, tID, bankAddress, pay_tID);
                worthBook.updateTokenWorth(tetherBookAddress, pay_tID);
                return worthBook.updateTokenPaid(stockTetherBookAddressKey, ownerKey);

      }

      function preTransfer(uint _tokenID, address from, address to) public  {
        payOwnerTransfer(_tokenID, from, to);
      }
      function  postTransfer(uint _tokenID, address from, address to) public  {
        ownerTransferPaid(_tokenID, from, to);
      }
      function  payOwnerTransfer(uint _tokenID,address from, address to) public  {
        worthBook.setKeys(tetherBookAddress,_tokenID);
        if(from != address(bankAddress)){
          worthBook.setKeys(from,0);
          uint fromAmount = worthBook.owed(tetherBookAddress, _tokenID, from,0);
          if(fromAmount > 0){
            payOwner(_tokenID,from,"Transfer");
          }
        }
        if(to != address(bankAddress)){
         worthBook.setKeys(to,0);
         uint toAmount = worthBook.owed(tetherBookAddress, _tokenID, to,0);
          if(toAmount > 0){
            payOwner(_tokenID,to,"Transfer");
          }
        }
      }
      function  ownerTransferPaid(uint _tokenID,address from, address to) public  {
        uint stockKey = tokenKey.addressKeyCreate(tetherBookAddress, _tokenID);
        if(from != address(bankAddress)){
         uint fromOwnerKey = tokenKey.addressKeyCreate(from, 0);
          worthBook.updateTokenPaid(stockKey,fromOwnerKey);
        }
        if(to != address(bankAddress)){
         uint toOwnerKey = tokenKey.addressKeyCreate(to, 0);
         worthBook.updateTokenPaid(stockKey,toOwnerKey);
        }
      }


  }


//TokenRewards end

//WorthBook start
/*
// ----------------------------------------------------------------------------
// Tether contract
// ----------------------------------------------------------------------------
contract Tether {
    uint public decimals;
    function totalSupply(uint tokenID) public view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint balance);
    // function balances(address tokenOwner) public view returns (uint balance);

    function transfer(address to, uint tokens) public;
    function preTransfer(address to, uint tokens) public;

    function allowance(address owner, address spender) public view returns (uint);
    function transferFrom(address from, address to, uint value) public;
    function approve(address spender, uint value) public;
 
}
// ----------------------------------------------------------------------------
// TokenKey contract
// ----------------------------------------------------------------------------
contract TokenKey {
   struct _tokenAddressKey{
        string name;
        uint keyCnt;
        mapping (address => mapping (uint => bool)) keySet; //Maps addresses to index in `tests
        mapping (address => mapping (uint => uint)) key; //Maps addresses to index in `tests
    }
    struct _tokenAccountKey{
        string name;
        uint keyCnt;
        mapping (uint => mapping (uint => bool)) keySet; //Maps addresses to index in `tests
        mapping (uint => mapping (uint => uint)) key; //Maps addresses to index in `tests
    }
     mapping (uint => address)  public addressKeyContract;
     mapping (uint => uint)  public addressKeyTokenID;

     mapping (uint => address)  public accountKeyContract;
     mapping (uint => uint)  public accountKeyTokenID;
     mapping (uint => uint)  public accountKeyAccountID;

     mapping (uint => address)  public subAccountKeyContract;
     mapping (uint => uint)  public subAccountKeyTokenID;
     mapping (uint => uint)  public subAccountKeyAccountID;
     mapping (uint => uint)  public subAccountKeySubAccountID;

    _tokenAddressKey _addressKey ;
    _tokenAccountKey _accountKey ;
    _tokenAccountKey _subAccountKey ;
    function addressKey(address tokenAddress, uint tokenID ) public view returns (uint);
    function accountKey(address tokenAddress, uint tokenID, uint accountID ) public view returns (uint);
    function subAccountKey(address tokenAddress, uint tokenID, uint accountID, uint subAccountID  ) public view returns (uint);
    function addressKeyCreate(address tokenAddress, uint tokenID ) public returns (uint);
    function accountKeyCreate(address tokenAddress, uint tokenID, uint accountID ) public returns (uint);
}
// ----------------------------------------------------------------------------
// ReceiptBook contract
// ----------------------------------------------------------------------------
contract ReceiptBook {
    uint public totalPaymentCnt;
    uint public paymentMethodCnt;
    mapping(uint => Tether) public paymentMethods; //[payOutCnt][ownerAddress] = payment
    
    //bankBalance[currencyKey] = currencyBalance
     mapping(uint => uint)  public bankBalance;
     //totalBankPayments[currencyKey] = totalCurrencyPayments
     mapping(uint => uint)  public totalBankPayments;
     //totalBankPayOuts[currencyKey] = totalCurrencyPayOuts
     mapping(uint => uint)  public totalBankPayOuts;


     //totalPayments[accountKey][currencyKey] = totalPayments
     mapping(uint => mapping(uint => uint ) ) public totalPayments;
     //totalPayOuts[accountKey][currencyKey] = totalPayOuts
     mapping(uint => mapping(uint => uint ) ) public totalPayOuts;
     //accountBalance[accountKey][currencyKey] = accountBalance
     mapping(uint => mapping(uint => uint ) ) public accountBalance;
     //totalBalance[tokenKey][currencyKey] = totalBalance
     mapping(uint => mapping(uint => uint ) ) public totalBalance;
    
}
// ----------------------------------------------------------------------------
// Bank contract
// ----------------------------------------------------------------------------
contract Bank {
    ReceiptBook public receiptBook;
    address public receiptBookAddress;

    uint public totalPaymentCnt;
    uint public paymentMethodCnt;
    mapping(uint => Tether) public paymentMethods; //[payOutCnt][ownerAddress] = payment
    
    mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public totalPayments;
    //balances[tokenID][accountID][paymentMethodAddress][paymentTokenID] = accountBalance
     mapping(uint => mapping(uint => mapping(address => mapping(uint => uint) ) ) ) public accountBalance;
     
    
    function payOut(uint tID, uint aID, address sC, uint ptID, address pay_to, uint amount, string memory note) public;
    function payment(address paymentMethod, address _from, uint amount, string memory note) public returns (bool);
}
*/

 // /**
//  * @title Basic token
//  * @dev Basic version of StandardToken, with no allowances.
//  */
contract Stock is Manageable, TokenMetaAddressTetherBook {
    // mapping(address => uint) public balances;
    address  public worthBookAddress;
    // address  public bankAddress; //bankAddress[tokenID] mapping
    address public bankAddress;
    WorthBook internal worthBook;
    Bank internal bank;
    mapping(uint => uint) public paymentMethodID;
    mapping(uint => uint) public paymentTokenID;
    mapping(uint => uint) public bankID;
    mapping(uint => mapping(address => uint)) public balances;


    
}
 // /**
//  * @title Basic token
//  * @dev Basic version of StandardToken, with no allowances.
//  */
contract StockTether is Stock, TetherBook {

    
}
// ----------------------------------------------------------------------------
// WorthBook contract
// ----------------------------------------------------------------------------
contract WorthBook is Ownable {
  

    using SafeMath for uint;
    ReceiptBook internal receiptBook;
    Bank internal bank;
    TokenKey internal tokenKey;
    address public tokenKeyAddress;
    Manageable internal manageable;
    address public manageableAddress;
    address public receiptBookAddress;
    uint public tokenID;
    address public bankAddress;
    address public paymentMethod;
    uint public paymentTokenID;
    
    StockTether internal stock;
    address public stockAddress;
    TokenBookConfig tokenBookConfig;
    address public tokenBookConfigAddress;

    
    uint public stockTokenBankAddressKey;
    uint public stockTetherBookAddressKey;
    uint public stockAddressKey;
    

     
     // address constant public tetherUSDT = 0xdac17f958d2ee523a2206206994597c13d831ec7;
    //  uint public _totalSupply = 10000000000000; //10 mil
     string public symbol;
     string public name;
     string public owner_name;
     
     string constant public paymentCurrency = "USDT";//tether smart contract address
     mapping(address => uint) private paid;
  
     uint private price = 0;
      //uint _tokenRoundBalance = tokenRoundBalance[stockAddressKey][paymentAddressKey];
     mapping(uint => mapping(uint => uint ) ) public tokenRoundBalance ;
     uint public decimals = 6;
     uint public worthDecimals = 16;
     uint public incomeAccountID = 0;
  
     mapping(address => uint) public worthBookDecimals;
     mapping(address => uint) public paymentDecimals;


     uint constant public icoSupply = 0; // amount of tokens to be sold from minter to raise money // ico contract
    //  mapping(address => mapping(uint => mapping(address => mapping(uint  => mapping( address => uint)) ) ) ) public tokenPaid; // total amound of money paid to the tokens owned by the tokens in a user's current ballancce
    
    // tokenPaid[stockAddressKey][paymentAddressKey][ownerAddressKey]  = ownerTokenWorth;
     // total amound of money paid to the tokens owned by the tokens in a user's current ballancc
     mapping(uint => mapping(uint => mapping(uint => uint))) public tokenPaid;
      // + //how much each each token should have een paid // equity worth
      //uint _tokenWorth = tokenWorth[stockAddressKey][paymentAddressKey];
     mapping(uint => mapping(uint => uint ) ) public tokenWorth;
  
      event PreTokenUpdate(address from,address to);
    //   event CheckOwnerPaymentLog(uint tokenID, address owner, address  paymentMethod, uint  payment);
    //   event OwnerPaymentLog(uint tokenID, address owner, address  paymentMethod, uint  payment);
      event TokenWorthLog(uint tokenID, uint indexed total_Income, uint indexed token_Worth, uint indexed total_supply);
      event DecimalLog(address  paymentMethod, uint indexed payment_Decimals , uint indexed worthBook_Decimals);
      event RoundPaymentLog(uint roundDifference, uint roundRemainder, uint  roundIncrease, uint roundBalance);
  
      /*
        bank token id should match stock token id  and token book id 
        bank id should check for token book owners for payout mermissions
        goals
        1.payout  - pay users dividents // test ready
        2.payments - accept money  // test ready
        -----------------
        3. how much owed based owner//
        4. how much money paid to property total// totalPayments
        5. how much money earned per token// tokenWorth
        6. has owner been paid in worthBook
        7. payment count //paymentCnt
        8. payment info by index
        9. cash currencies
        10. payment balance
        11. how much money paid to owners via worthBook
        12.when trandfers happen tokenPaid musts be updated to token worth
  
      */
      // function WorthBook() public {
      //     bank = msg.sender;
      // }
    event Config(address indexed newTokenKeyAddress,address indexed newManageableAddress);
      constructor() public {
          //paymentDecimals = tether.decimals(); //for some reasion this cause a Internal JSON-RPC error
        //   worthBookDecimals = worthDecimals.sub(paymentDecimals);
        //   bank = new Bank();
         // bankAddress = address(bank);
      }
      function config(address newTokenBookConfigAddress) public onlyOwner  {
            tokenBookConfig = TokenBookConfig(newTokenBookConfigAddress);
            tokenBookConfigAddress = newTokenBookConfigAddress;
            address newTokenKeyAddress = tokenBookConfig.contractAddresses(2);
            tokenKeyAddress = newTokenKeyAddress;
            tokenKey = TokenKey(newTokenKeyAddress);
            address newManageableAddress = tokenBookConfig.contractAddresses(3);
            manageableAddress = newManageableAddress;
            manageable = Manageable(newManageableAddress);
            emit Config(tokenKeyAddress,manageableAddress);
      }
      /**
      * @dev Throws if called by any account other than the bank.
      */
        modifier onlyBank() {
            require(msg.sender == bankAddress,"only banks can do this");
            _;
        }
      /**
      * @dev Throws if called by any account other than the manager or admin.
      */
      modifier onlyExecutives() {
          bool executive = manageable.executives(address(this),msg.sender);
          require(executive || msg.sender == owner,"only executives");
          _;
      }
      function setPaymentDecimals(address _paymentMethod) public {
        Tether tether = Tether(_paymentMethod);
        uint payDecimals = tether.decimals();
        paymentDecimals[_paymentMethod] = payDecimals;
        worthBookDecimals[_paymentMethod] = worthDecimals.sub(payDecimals);
        emit DecimalLog(_paymentMethod,payDecimals, worthBookDecimals[_paymentMethod]);
      }
      function setBank(address newBankAddress) private onlyExecutives {
        //   address  newReceiptBookAddress = receiptBookAddress;
        //   if(newBankAddress != bankAddress){
              bankAddress = newBankAddress;
              bank = Bank(newBankAddress);
              address newReceiptBookAddress = bank.receiptBookAddress();
        //   }
        //   if(newReceiptBookAddress != receiptBookAddress){
              receiptBookAddress = newReceiptBookAddress;
              receiptBook = ReceiptBook(newReceiptBookAddress);
        //   }

      }
      function setStock(address _stockTetherBookAddress, uint _tokenID ) public onlyExecutives {
          //if(_stockTetherBookAddress != stockAddress || _tokenID != tokenID){
              stockAddress = _stockTetherBookAddress;
              tokenID = _tokenID;
              stock = StockTether(_stockTetherBookAddress);
              uint bankID = stock.bankID(_tokenID);
              uint paymentMethodID = stock.paymentMethodID(_tokenID);
              
              paymentTokenID = stock.paymentTokenID(_tokenID);
                bool customParams = tokenBookConfig.tokenBools(_tokenID,1);
                address newBankAddress;
                if(customParams){
                    newBankAddress = tokenBookConfig.tokenAddresses(tokenID,bankID);
                    paymentMethod = tokenBookConfig.tokenAddresses(tokenID,paymentMethodID);
                }else{
                    newBankAddress = tokenBookConfig.contractAddresses(bankID);
                    paymentMethod = tokenBookConfig.contractAddresses(paymentMethodID);
                }
              stockTetherBookAddressKey = tokenKey.addressKeyCreate(_stockTetherBookAddress, _tokenID);
              stockTokenBankAddressKey = tokenKey.addressKeyCreate(newBankAddress, _tokenID);
              stockAddressKey = stockTokenBankAddressKey;
              setBank(newBankAddress);
          //}
      }
      function getBankAddress(address _stockTetherBookAddress, uint _tokenID ) public view returns (address) {
            StockTether _stock = StockTether(_stockTetherBookAddress);
            uint bankID = _stock.bankID(_tokenID);
            bool customParams = tokenBookConfig.tokenBools(_tokenID,1);
            address newBankAddress;
            if(customParams){
                newBankAddress = tokenBookConfig.tokenAddresses(tokenID,bankID);
            }else{
                newBankAddress = tokenBookConfig.contractAddresses(bankID);
            }
            return newBankAddress;
      }
      function setKeys(address _stockTetherBookAddress, uint _tokenID ) public onlyExecutives {
        if(_tokenID > 0){
            address _stockTokenBankAddress = getBankAddress(_stockTetherBookAddress, _tokenID );
            tokenKey.addressKeyCreate(_stockTokenBankAddress, _tokenID);

        }
         tokenKey.addressKeyCreate(_stockTetherBookAddress, _tokenID);
      }
      function owed(address _stockTetherBookAddress, uint _tokenID, address owner, uint tokenOwnerID) public view returns (uint) {
          uint payment = ownerPayment(_stockTetherBookAddress, _tokenID, owner,tokenOwnerID);
          return payment;
      }

      function updateTokenPaid(uint _stockTetherBookAddressKey, uint _ownerKey) public returns (bool)  {
          address _stockTetherBookAddress = tokenKey.addressKeyContract(_stockTetherBookAddressKey);
          uint _tokenID = tokenKey.addressKeyTokenID(_stockTetherBookAddressKey);
          address pay_to = tokenKey.addressKeyContract(_ownerKey);
          uint pay_tokenID = tokenKey.addressKeyTokenID(_ownerKey);
          setStock(_stockTetherBookAddress, _tokenID);
          uint balance;
          address _balanceTokenAddress;
          uint _balanceTokenID;
          
            bool customParams = tokenBookConfig.tokenBools(_tokenID,1);
            bool customBalanceToken = tokenBookConfig.tokenBools(_tokenID,102); 

            if(customParams && customBalanceToken){
                _balanceTokenAddress = tokenBookConfig.tokenAddresses(_tokenID,102); 
                _balanceTokenID = tokenBookConfig.tokenUints(_tokenID,102); 
            }else{
                _balanceTokenAddress = _stockTetherBookAddress;
                _balanceTokenID = _tokenID;
            }
            uint _balanceKey = tokenKey.addressKeyCreate(_balanceTokenAddress, _balanceTokenID);

         
          if(pay_tokenID > 0 ){
            balance = receiptBook.totalBalance(_ownerKey,_balanceKey);

          }else{
            if(_balanceTokenID > 0 ){
                balance = stock.balances(_balanceTokenID,pay_to);
            }else{
                _Tether _tether = _Tether(_balanceTokenAddress);
                balance = _tether.balances(pay_to);
            }
            
          }

          uint paymentAddressKey = tokenKey.addressKeyCreate(paymentMethod, paymentTokenID);
          uint ownerAddressKey = tokenKey.addressKeyCreate(pay_to, pay_tokenID);

          uint ownerTokenWorth = SafeMath.mul(balance, tokenWorth[stockTokenBankAddressKey][paymentAddressKey]);
          ownerTokenWorth = ownerTokenWorth.div(10**worthBookDecimals[paymentMethod]);
    // tokenPaid[stockTokenBankAddressKey][paymentAddressKey][ownerAddressKey]  = ownerTokenWorth;


          tokenPaid[stockTokenBankAddressKey][paymentAddressKey][ownerAddressKey] = ownerTokenWorth;
          tokenPaid[stockTetherBookAddressKey][paymentAddressKey][ownerAddressKey] = ownerTokenWorth;
          return true;
      }
      // function payOwner(address _stockAddress, uint tID, address pay_to) public returns (bool)  {
      //     //check to see if owner is paid
      //     //if not use balance and tokenWorth to determine OwnerTokenWorth
      //     //check the paid balance to figure out how much worthBook have been paid by the  tokens owners account
      //     // the difference between tokenWorth and tokenPaid tells you how much the owner needs to be paid
      //     // if owner payment is above 0 pay owner from payment currency account
      //     // if payment went throught
      //       // add owner to paid listh with true value
      //       // update how much token paid amount tokenPaid
      //       // increase total paid
      //     setStock(_stockAddress, tID);
      //     bool sent = false;
      //     // require(balances[pay_to] > 0); 
      //     //require(!ownerPaid[pay_to]); // make sure owner hasent already been paid deleting arrays are expensive
      //     bool isOwner = stock.balances(tID, pay_to) > 0;
          
      //     if (isOwner) {
      //         uint balance = stock.balances(tID, pay_to);
      //         uint totalSupply = stock.totalSupply(tID);
      //         uint bankID = stock.bankID(tID);
      //         uint paymentMethodID = stock.paymentMethodID(tID);
      //         bankAddress = stock.tokenMetaAddress(tID,bankID);
      //         paymentMethod = stock.tokenMetaAddress(tID,paymentMethodID);
      //         paymentTokenID = stock.paymentTokenID(tID);
      //         uint aID = 0;
              
      //         setBank(bankAddress);
      //         uint ownerPaid = tokenPaid[_stockAddress][tID][paymentMethod][paymentTokenID][pay_to]; // how much owern ber been paid
      //         uint __tokenWorth = tokenWorth[_stockAddress][tID][paymentMethod][paymentTokenID];
      //         uint ownerTokenWorth = __tokenWorth.mul(balance);
      //         ownerTokenWorth = ownerTokenWorth.div(10**worthBookDecimals[paymentMethod]);
      //         //a = amount of owner payment
      //         uint a = SafeMath.sub(ownerTokenWorth,ownerPaid);
      //         if (a > 0 ) {
      //           // uint totalPayments = receiptBook.totalPayments(tID, aID, paymentMethod, paymentTokenID ); // how much owern ber been paid
      //           bank.payOut(tID, aID, paymentMethod, paymentTokenID, pay_to, a,"");
      //           tokenPaid[_stockAddress][tID][paymentMethod][paymentTokenID][pay_to] = ownerTokenWorth;
      //           // emit TokenWorthLog(tID,totalPayments, tokenWorth[_stockAddress][tID][paymentMethod][paymentTokenID],totalSupply);
      //           emit OwnerPaymentLog(tID,pay_to,  paymentMethod, a);
      //           sent = true;
      //         }
  
      //     }
      //     return sent;
      // }
      function ownerBalance(address _stockTetherBookAddress, uint _tokenID, address tokenOwner, uint tokenOwnerTokenId) public  view returns (uint) {

            StockTether _stock;

            uint balance;
            address _balanceTokenAddress;
            uint _balanceTokenID;
            bool customParams = tokenBookConfig.tokenBools(_tokenID,1);
            bool customBalanceToken = tokenBookConfig.tokenBools(_tokenID,102); 

            if(customParams && customBalanceToken){
                _balanceTokenAddress = tokenBookConfig.tokenAddresses(_tokenID,102); 
                _balanceTokenID = tokenBookConfig.tokenUints(_tokenID,102); 
            }else{
                _balanceTokenAddress = _stockTetherBookAddress;
                _balanceTokenID = _tokenID;
            }
          
          if(tokenOwnerTokenId > 0 ){
            balance = tokenBalance(_stockTetherBookAddress,_tokenID,tokenOwner,tokenOwnerTokenId);

          }else{
            if(_balanceTokenID > 0 ){
                _stock = StockTether(_balanceTokenAddress);

                balance = _stock.balances(_balanceTokenID,tokenOwner);
            }else{
                _Tether _tether = _Tether(_balanceTokenAddress);
                balance = _tether.balances(tokenOwner);
            }
          }
          return balance;
    }
    function tokenBalance(address _stockTetherBookAddress, uint _tokenID, address tokenOwner, uint tokenOwnerTokenId) public  view returns (uint) {
        //   emit PreTokenUpdate(address(this),address(this));
          StockTether _stock;
          Bank _bank;
          ReceiptBook _receiptBook;
          // if(_stockTetherBookAddress != stockAddress && _tokenID != tokenID){
              _stock = StockTether(_stockTetherBookAddress);
              uint bankID = _stock.bankID(_tokenID);
              bool customParams = tokenBookConfig.tokenBools(_tokenID,1);
                
                address newBankAddress;
                if(customParams){
                    newBankAddress = tokenBookConfig.tokenAddresses(_tokenID,bankID);
        
                }else{
                    newBankAddress = tokenBookConfig.contractAddresses(bankID);
                }
                uint _balanceKey = balanceKey(_stockTetherBookAddress,_tokenID);
              _bank = Bank(newBankAddress);
              address newReceiptBookAddress = _bank.receiptBookAddress();
              _receiptBook = ReceiptBook(newReceiptBookAddress);

            uint ownerAddressKey = tokenKey.addressKey(tokenOwner, tokenOwnerTokenId); //this should be bankAddress as owner and token id  = id of token to get balance for
            // uint _stockTetherBookAddressKey = tokenKey.addressKey(_stockTetherBookAddress, _tokenID);
            uint balance = _receiptBook.totalBalance(ownerAddressKey,_balanceKey);
          return balance;
    }
    function balanceKey(address _stockTetherBookAddress, uint _tokenID) public  view returns (uint) {

              bool customParams = tokenBookConfig.tokenBools(_tokenID,1);
              bool customBalanceToken = tokenBookConfig.tokenBools(_tokenID,102); 
                address _balanceTokenAddress = _stockTetherBookAddress;
                uint _balanceTokenID = _tokenID;

                if(customParams){

                    if(customBalanceToken){
                        _balanceTokenAddress = tokenBookConfig.tokenAddresses(_tokenID,102); 
                        _balanceTokenID = tokenBookConfig.tokenUints(_tokenID,102); 
                    }else{
                        _balanceTokenAddress = _stockTetherBookAddress;
                        _balanceTokenID = _tokenID;
                    }
                }
                uint _balanceKey = tokenKey.addressKey(_balanceTokenAddress, _balanceTokenID);
              
          return _balanceKey;
    }
    function totalSupply(address _stockTetherBookAddress, uint _tokenID) public  view returns (uint) {

              bool customParams = tokenBookConfig.tokenBools(_tokenID,1);
              bool customBalanceToken = tokenBookConfig.tokenBools(_tokenID,102); 
                address _balanceTokenAddress = _stockTetherBookAddress;
                uint _balanceTokenID = _tokenID;
                uint _totalSupply;

                if(customParams){

                    if(customBalanceToken){
                        _balanceTokenAddress = tokenBookConfig.tokenAddresses(_tokenID,102); 
                        _balanceTokenID = tokenBookConfig.tokenUints(_tokenID,102); 
                    }else{
                        _balanceTokenAddress = _stockTetherBookAddress;
                        _balanceTokenID = _tokenID;
                    }
                }
                if(_balanceTokenID > 0 ){
                    StockTether _stock;
                    _stock = StockTether(_balanceTokenAddress);
                    _totalSupply = _stock.totalSupply(_balanceTokenID);
                }else{
                    _Tether _tether = _Tether(_balanceTokenAddress);
                    _totalSupply = _tether.totalSupply();
                }

              
          return _totalSupply;
    }
      function ownerPayment(address _stockTetherBookAddress, uint _tokenID, address tokenOwner, uint tokenOwnerTokenId) public  view returns (uint) {
          uint balance = ownerBalance(_stockTetherBookAddress, _tokenID, tokenOwner, tokenOwnerTokenId);
          if(balance <= 0){
              return 0;
          }
          StockTether _stock;
          _stock = StockTether(_stockTetherBookAddress);
          uint _paymentMethodID = _stock.paymentMethodID(_tokenID);
          uint _paymentTokenID = _stock.paymentTokenID(_tokenID);
          bool customParams = tokenBookConfig.tokenBools(_tokenID,1);
          address _paymentMethod;
            if(customParams){
              _paymentMethod = tokenBookConfig.tokenAddresses(_tokenID,_paymentMethodID);
    
            }else{
              _paymentMethod = tokenBookConfig.contractAddresses(_paymentMethodID);
            }
            address _stockTokenBankAddress = getBankAddress(_stockTetherBookAddress, _tokenID );


        //   require(balance > 0,"OwnerPayment Error: owner has no balance");
          //require(!ownerPaid[owner]); // make sure owner hasent already been paid deleting arrays are expensive
            // uint aID = 0;

            // uint paymentMethodID = _stock.paymentMethodID(_tokenID);
            // uint _paymentTokenID = _stock.paymentTokenID(_tokenID);
            // _paymentMethod = _stock.tokenMetaAddress(_tokenID,paymentMethodID);
        //   uint totalPayments = receiptBook.totalPayments(_tokenID, aID, paymentMethod, _paymentTokenID );
        //   uint totalSupply = _stock.totalSupply(_tokenID);
          //uint _stockTetherBookAddressKey = tokenKey.addressKey(_stockTetherBookAddress, _tokenID);
          uint _stockTokenBankAddressKey = tokenKey.addressKey(_stockTokenBankAddress, _tokenID);
          uint paymentAddressKey = tokenKey.addressKey(_paymentMethod, _paymentTokenID);
          uint ownerAddressKey = tokenKey.addressKey(tokenOwner, tokenOwnerTokenId);

        //   uint balance = _stock.balances(5,address(this));
        //   uint balance = _stock.balances(_tokenID,tokenOwner);

          //uint ownerPaid = tokenPaid[_stockTetherBookAddressKey][paymentAddressKey][ownerAddressKey];// how much owern ber been paid
          uint ownerPaid = tokenPaid[_stockTokenBankAddressKey][paymentAddressKey][ownerAddressKey];// how much owern ber been paid

        //   uint ownerTokenWorth = balance.mul(tokenWorth[_stockTetherBookAddress][_tokenID][_paymentMethod][_paymentTokenID]);

          // uint _tokenWorth = tokenWorth[_stockTetherBookAddressKey][paymentAddressKey];
          uint _tokenWorth = tokenWorth[_stockTokenBankAddressKey][paymentAddressKey];

          uint ownerTokenWorth = balance.mul(_tokenWorth);
          ownerTokenWorth = ownerTokenWorth.div(10**worthBookDecimals[_paymentMethod]);
          uint payment = ownerTokenWorth.sub(ownerPaid);
        //   emit TokenWorthLog(_tokenID,totalPayments, tokenWorth[_stockTetherBookAddress][_tokenID][paymentMethod][paymentTokenID],totalSupply);
        //   emit CheckOwnerPaymentLog(_tokenID,tokenOwner, paymentMethod, payment );
          return payment;
    }

    //   function payment(address _stockTetherBookAddress,address paymentMethod, address _from, uint amount, string memory note) public returns (bool) {
    //     bool funded = bank.payment(paymentMethod,_from,amount, note);
    //     updateTokenWorth(_stockTetherBookAddress,paymentMethod);
    //     return funded;
    //  }
      function  updateTokenWorth(address _stockTetherBookAddress, uint _tokenID) public   {
          // increase token worth
          setStock(_stockTetherBookAddress, _tokenID);

            uint _totalSupply =  totalSupply(_stockTetherBookAddress,_tokenID);   
                  
          uint paymentDecimal = paymentDecimals[paymentMethod];
          uint _paymentTokenID = stock.paymentTokenID(_tokenID);
          
          uint paymentAddressKey = tokenKey.addressKeyCreate(paymentMethod, _paymentTokenID);
          uint ownerAccountKey = tokenKey.accountKeyCreate(bankAddress, _tokenID, incomeAccountID);
          
          uint totalPayments = receiptBook.totalPayments(ownerAccountKey, paymentAddressKey);
          
          uint totalDividenIncome = totalPayments.mul(10**worthBookDecimals[paymentMethod]);

          if(totalPayments == 0){
              emit TokenWorthLog(_tokenID,totalPayments, tokenWorth[stockTokenBankAddressKey][paymentAddressKey],_totalSupply);
              //emit TokenWorthLog(_tokenID,totalPayments, tokenWorth[stockTetherBookAddressKey][paymentAddressKey],_totalSupply);
              emit DecimalLog(paymentMethod,paymentDecimal, worthBookDecimals[paymentMethod]);
              return;
          }
          uint worthRemainder = totalDividenIncome % _totalSupply;
          uint worthIncome = totalDividenIncome.sub(worthRemainder);
          tokenRoundBalance[stockTokenBankAddressKey][paymentAddressKey] = worthRemainder;
          tokenRoundBalance[stockTetherBookAddressKey][paymentAddressKey] = worthRemainder;
          if(worthIncome == 0){
              emit TokenWorthLog(_tokenID,totalPayments, tokenWorth[stockTokenBankAddressKey][paymentAddressKey],_totalSupply);
              emit DecimalLog(paymentMethod,paymentDecimal, worthBookDecimals[paymentMethod]);
              emit TokenWorthLog(_tokenID,totalDividenIncome, worthRemainder,worthIncome);
              return;
          }
          tokenWorth[stockTokenBankAddressKey][paymentAddressKey] = totalDividenIncome.div(_totalSupply);
          tokenWorth[stockTetherBookAddressKey][paymentAddressKey] = totalDividenIncome.div(_totalSupply);

          emit TokenWorthLog(_tokenID,totalPayments, tokenWorth[stockTokenBankAddressKey][paymentAddressKey],_totalSupply);
          emit DecimalLog(paymentMethod,paymentDecimal, worthBookDecimals[paymentMethod]);
      }
      function  updateTransferTokens(address _stockTetherBookAddress, uint _tokenID,address from, address to,  uint pay_tokenID) public  {
          emit PreTokenUpdate(from, to);
          setStock(_stockTetherBookAddress, _tokenID);
          uint _stocTetherBookAddressKey = tokenKey.addressKey(_stockTetherBookAddress, _tokenID);
          uint _fromKey = tokenKey.addressKey(from, pay_tokenID);
          uint _toKey = tokenKey.addressKey(to, pay_tokenID);
          updateTokensPaid(_stocTetherBookAddressKey, _fromKey);
          updateTokensPaid(_stocTetherBookAddressKey, _toKey);
      }
      function  updateTokensPaid(uint _stocTetherBookAddressKey, uint _ownerKey) public  {
        updateTokenPaid(_stocTetherBookAddressKey, _ownerKey);
        // uint paymentMethodCnt = bank.paymentMethodCnt();
        // if(paymentMethodCnt == 1){
        //   address paymentMethod = bank.paymentMethods(0);
        //   updateTokenPaid(_stockTetherBookAddress,paymentMethod,pay_to);
        // }else{
        //     for (uint i = 0; i < paymentMethodCnt; i++) {
        //         address paymentMethod = bank.paymentMethods(i);
        //         updateTokenPaid(_stockTetherBookAddress,paymentMethod,pay_to);
        //     }
        // }
    }
  }

//WorthBook end

contract Document {
    string public documentTitle;
    string public documentURL;
    address public documentOwner;

    constructor(string memory title, string memory url) public {
        documentTitle = title;
        documentURL = url;
        documentOwner = msg.sender;
    }
}
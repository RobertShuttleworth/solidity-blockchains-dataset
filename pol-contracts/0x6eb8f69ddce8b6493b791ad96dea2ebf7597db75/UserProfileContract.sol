// SPDX-License-Identifier: UNLICENSED
// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/profileUsername.sol


pragma solidity ^0.8.20;


interface INFTUsernameContract {
    function isMinted(string memory username) external view returns (bool);
    function getNFTOwner(string memory username) external view returns (address);
}

contract UserProfileContract  is Ownable{
    INFTUsernameContract private nftUsernameContract;

    uint256 public profileCount = 0;

    struct Profile {
        string nftUsername; // Username único
        string json;        // Información del perfil
        string[3] tags;     // Máximo 3 tags por perfil
        uint256 timestamp;  // Marca de tiempo de creación o modificación
    }

    mapping(string => Profile) private profilesByUsername; // Map username to profile
    mapping(string => string[]) private profilesByGustoTag;      // Tags de gustos
    mapping(string => string[]) private profilesByActitudTag;    // Tags actitudinales
    mapping(string => string[]) private profilesByConductaTag;   // Tags conductuales

    event ProfileCreated(string indexed nftUsername, string json, string[3] tags);
    event ProfileUpdated(string indexed nftUsername, string json, string[3] tags);
    // Evento para cuando un perfil es eliminado
    event ProfileDeleted(string indexed nftUsername);

 
    constructor(address nftContractAddress) Ownable(msg.sender) {
    nftUsernameContract = INFTUsernameContract(nftContractAddress);
}

    /**
     * @dev Create a new profile associated with an NFT username.
     * @param username The NFT username to associate with the profile.
     * @param json JSON string containing profile data.
     * @param tags Array of up to 3 tags for the profile.
     */
    function createProfile(string memory username, string memory json, string[3] memory tags) external {
        require(nftUsernameContract.isMinted(username), "Username not minted");
        require(nftUsernameContract.getNFTOwner(username) == msg.sender, "Not the owner of the NFT username");
        require(bytes(profilesByUsername[username].nftUsername).length == 0, "Profile already exists for this username");

        profilesByUsername[username] = Profile({
            nftUsername: username,
            json: json,
            tags: tags,
            timestamp: block.timestamp
        });

        // Incrementar el contador
        profileCount++;

        // Add username to the respective tag mappings
        profilesByGustoTag[tags[0]].push(username);
        profilesByActitudTag[tags[1]].push(username);
        profilesByConductaTag[tags[2]].push(username);

        emit ProfileCreated(username, json, tags);
        
    }

    /**
 * @dev Delete a profile by its username.
 * @param username The NFT username associated with the profile.
 */
function deleteProfile(string memory username) external {
    // Verificar que el perfil existe
    require(bytes(profilesByUsername[username].nftUsername).length > 0, "Profile does not exist");

    // Verificar que el llamador sea el propietario del perfil
    require(nftUsernameContract.getNFTOwner(username) == msg.sender, "Not the owner of the NFT username");

    // Obtener el perfil a eliminar
    Profile storage profile = profilesByUsername[username];

    // Eliminar el perfil de los mappings de tags
    _removeFromTag(profilesByGustoTag[profile.tags[0]], username);
    _removeFromTag(profilesByActitudTag[profile.tags[1]], username);
    _removeFromTag(profilesByConductaTag[profile.tags[2]], username);

    // Eliminar el perfil del mapping
    delete profilesByUsername[username];

    // Decrementar el contador de perfiles
    profileCount--;

    emit ProfileDeleted(username);
}



    /**
     * @dev Update the profile associated with the sender's NFT username.
     * @param username The NFT username associated with the profile.
     * @param json New JSON string containing profile data.
     * @param tags New array of up to 3 tags for the profile.
     */
    function updateProfile(string memory username, string memory json, string[3] memory tags) external {
        require(nftUsernameContract.isMinted(username), "Username not minted");
        require(nftUsernameContract.getNFTOwner(username) == msg.sender, "Not the owner of the NFT username");

        Profile storage profile = profilesByUsername[username];
        require(bytes(profile.nftUsername).length > 0, "Profile does not exist");

        // Remove username from old tags
        _removeFromTag(profilesByGustoTag[profile.tags[0]], username);
        _removeFromTag(profilesByActitudTag[profile.tags[1]], username);
        _removeFromTag(profilesByConductaTag[profile.tags[2]], username);

        // Update profile data
        profile.json = json;
        profile.tags = tags;
        profile.timestamp = block.timestamp;

        // Add username to new tags
        profilesByGustoTag[tags[0]].push(username);
        profilesByActitudTag[tags[1]].push(username);
        profilesByConductaTag[tags[2]].push(username);

        emit ProfileUpdated(username, json, tags);
    }

    /**
     * @dev Internal function to remove a username from a tag array.
     * @param tagArray The array of usernames associated with a tag.
     * @param username The username to remove.
     */
    function _removeFromTag(string[] storage tagArray, string memory username) internal {
        for (uint256 i = 0; i < tagArray.length; i++) {
            if (keccak256(abi.encodePacked(tagArray[i])) == keccak256(abi.encodePacked(username))) {
                tagArray[i] = tagArray[tagArray.length - 1]; // Move last element to deleted spot
                tagArray.pop(); // Remove last element
                break;
            }
        }
    }

    /**
     * @dev View profiles by a specific gusto tag.
     * @param tag The gusto tag to query.
     * @return Array of usernames associated with the tag.
     */
  
   // Función que devuelve una cantidad limitada de perfiles aleatorios para un tag dado
    function getProfilesByGustoTag(string memory tag, uint256 limit) external view returns (string[] memory) {
        string[] memory profiles = profilesByGustoTag[tag];
        uint256 profilesCount = profiles.length;

        // Limitar la cantidad solicitada si es mayor que el número de perfiles disponibles
        uint256 count = limit < profilesCount ? limit : profilesCount;
        
        string[] memory result = new string[](count);
        
        // Seleccionar aleatoriamente los perfiles
        for (uint256 i = 0; i < count; i++) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % profilesCount;
            result[i] = profiles[randomIndex];
        }
        
        return result;
    }

    /**
     * @dev View profiles by a specific actitud tag.
     * @param tag The actitud tag to query.
     * @return Array of usernames associated with the tag.
     */
 
    // Función que devuelve una cantidad limitada de perfiles aleatorios para un tag dado
    function getProfilesByActitudTag(string memory tag, uint256 limit) external view returns (string[] memory) {
        string[] memory profiles = profilesByActitudTag[tag];
        uint256 profilesCount = profiles.length;

        // Limitar la cantidad solicitada si es mayor que el número de perfiles disponibles
        uint256 count = limit < profilesCount ? limit : profilesCount;
        
        string[] memory result = new string[](count);
        
        // Seleccionar aleatoriamente los perfiles
        for (uint256 i = 0; i < count; i++) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % profilesCount;
            result[i] = profiles[randomIndex];
        }
        
        return result;
    }

    /**
     * @dev View profiles by a specific conducta tag.
     * @param tag The conducta tag to query.
     * @return Array of usernames associated with the tag.
     */
    
    // Función que devuelve una cantidad limitada de perfiles aleatorios para un tag dado
    function getProfilesByConductaTag(string memory tag, uint256 limit) external view returns (string[] memory) {
        string[] memory profiles = profilesByConductaTag[tag];
        uint256 profilesCount = profiles.length;

        // Limitar la cantidad solicitada si es mayor que el número de perfiles disponibles
        uint256 count = limit < profilesCount ? limit : profilesCount;
        
        string[] memory result = new string[](count);
        
        // Seleccionar aleatoriamente los perfiles
        for (uint256 i = 0; i < count; i++) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, i))) % profilesCount;
            result[i] = profiles[randomIndex];
        }
        
        return result;
    }

    /**
     * @dev View a user's profile by username.
     * @param username The username to query.
     * @return The profile data associated with the username.
     */
    function getProfileByUsername(string memory username) external view returns (Profile memory) {
        require(bytes(profilesByUsername[username].nftUsername).length > 0, "Profile does not exist");
        return profilesByUsername[username];
    }

    function getProfileCount() public view returns (uint256) {
        return profileCount;
    }
}
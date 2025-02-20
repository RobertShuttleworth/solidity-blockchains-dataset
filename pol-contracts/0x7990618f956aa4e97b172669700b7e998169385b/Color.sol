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


// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
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
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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
        require(newOwner != address(0), "Ownable: new owner is the zero address");
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

// File: contracts/color.sol



pragma solidity ^0.8.23;


contract Color is Ownable {
    string public Color_1 = "B9D9EB"; //light blue
    string public Color_2 = "66596C"; //grey     
    string public Color_3 = "FFBE9F"; //light pink  
    string public Color_4 = "9CDBD9"; //green blue  
    string public Color_5 = "6E2B62"; //dark purple  
    string public Color_6 = "FA9370"; //pink orange  
    string public Color_7 = "FCAEBB"; //pink red 
    string public Color_8 = "FF808B"; //pink   
    function backgroundColors(
        uint256 index
    ) internal view returns (string memory) {
        string[16] memory bgColors = [
            Color_1, //yellow
            Color_1, //yellow
            Color_1, //yellow
            Color_1, //yellow
            Color_1, //yellow
            Color_2, //red
            Color_2, //red
            Color_2, //red
            Color_3, //orange
            Color_3, //orange
            Color_3, //orange
            Color_4, //green
            Color_5, //gold
            Color_6, //silver
            Color_7, //purple
            Color_8 //blue
        ];
        return bgColors[index];
    }
    function front_stopOpacityPicker(
        uint256 index
    ) internal pure returns (string memory) {
        string[10] memory stopOpacity = [
            "0.1",
            "0.2",
            "0.3",
            "0.4",
            "0.5",
            "0.6",
            "0.7",
            "0.8",
            "0.9",
            "1.0"
        ];
        return stopOpacity[index];
    }
    function rear_stopOpacityPicker(
        uint256 index
    ) internal pure returns (string memory) {
        string[3] memory stopOpacity = [
            "1.0",
            "1.0",
            "1.0"
        ];
        return stopOpacity[index];
    }
    function advanceColor() public onlyOwner {
        string memory _Color_8 = Color_8;
        Color_8 = Color_7;
        Color_7 = Color_6;
        Color_6 = Color_5;
        Color_5 = Color_4;
        Color_4 = Color_3;
        Color_3 = Color_2;
        Color_2 = Color_1;
        Color_1 =_Color_8;


    }
    function seColor_1(string memory _Color_1) public onlyOwner {
        Color_1 = _Color_1;
    }
    function seColor_2(string memory _Color_2) public onlyOwner {
        Color_2 = _Color_2;
    }
    function seColor_3(string memory _Color_3) public onlyOwner {
        Color_3 = _Color_3;
    }
    function seColor_4(string memory _Color_4) public onlyOwner {
        Color_4 = _Color_4;
    }

    function seColor_5(string memory _Color_5) public onlyOwner {
        Color_5 = _Color_5;
    }

    function seColor_6(string memory _Color_6) public onlyOwner {
        Color_6 = _Color_6;
    }

    function seColor_7(string memory _Color_7) public onlyOwner {
        Color_7 = _Color_7;
    }

    function seColor_8(string memory _Color_8) public onlyOwner {
        Color_8 = _Color_8;
    }
}
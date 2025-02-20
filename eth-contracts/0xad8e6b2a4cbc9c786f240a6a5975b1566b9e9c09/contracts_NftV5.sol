// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./openzeppelin_contracts-upgradeable_token_ERC1155_ERC1155Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC1155_extensions_ERC1155BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./hardhat_console.sol";

interface IMintableERC20 is IERC20 {
    function isAdmin(address _admin) external view returns (bool);
    function mint(address to, uint256 amount) external;
    function burnFrom(address to, uint256 amount) external;
}

contract NftV5 is
    Initializable,
    ERC1155Upgradeable,
    ERC1155BurnableUpgradeable,
    OwnableUpgradeable
{
    IMintableERC20 public erc20Token;
    address public admin;
    uint256 public internalValue;
    uint256 public externalValue;

    mapping(address => mapping(uint256 => uint256)) public fractionalBalances;
    mapping(uint256 => address[]) public  tokenOwners;
    mapping(uint256 => mapping(address => uint256)) private holderIndices;
    mapping(uint256 => uint256) public housePrices;
    mapping(uint256 => mapping(address => bool)) private isAddressExists;
    mapping(uint256 => uint256) public maxFraction;
    mapping(uint256 => uint256) public burnedFractions;
    mapping(uint256 => bool) public  tokenMinted;

    uint256 private _totalBurnedTRY;
    mapping(uint256 => uint256) public fractionPrices;
    mapping(address => bool) public approvedMinters;
    address public mainContractAddress;
    address public nextContract;

    event TokenMinted(address indexed owner, uint256 indexed tokenId);
    event TokenReMinted(address indexed owner, uint256 indexed tokenId);
    event TokenBurned(address indexed from, uint256 indexed tokenId, uint256 fraction);
    uint256[19] private __gap;


    function initialize(address _erc20Token) public initializer {
        __ERC1155_init("https://js.egemoney.com/api/nft/metadata/");
        __Ownable_init();

        erc20Token = IMintableERC20(_erc20Token);
        admin = msg.sender;
    }

     modifier onlyApprovedMinter() {
        require(approvedMinters[msg.sender], "You are not approved to mint");
        _;
    }

    function mint(
        uint256 tokenId,
        uint256 fraction,
        address _to,
        string memory data
    ) public onlyApprovedMinter  {
        _mint(_to, tokenId, fraction, bytes(data));
    }

    function burnNft(uint256 tokenId, uint256 fraction, address _from) public onlyApprovedMinter {
      require(nextContract == msg.sender,"Can't Burn");
      _burn(_from, tokenId, fraction);
    }
    
    function safeTransferNft(address  _from,address  _to,uint256 _tokenId, uint256 _fraction,string memory _data) external  onlyApprovedMinter {
     _safeTransferFrom(_from, _to, _tokenId, _fraction, bytes(_data));
    }

  function getErc20Token() external view returns (address){
    return address(erc20Token);
  }
  function getInternalValue() external view returns(uint){
    return internalValue;
  }
   function getExternalValue() external view returns(uint) {
    return externalValue;
  }
  
   function approveMinter(address _minter) public  onlyOwner { 
        if(approvedMinters[_minter]==false){
          approvedMinters[_minter] = true;
        }
    }
   
   function revokeMinter(address _minter) public onlyOwner {
        if(approvedMinters[_minter]==true){
          approvedMinters[_minter] = false;
        }
        
    }
    function setNewContractAddress(address addr) external onlyOwner {
      nextContract=addr;
    }

}
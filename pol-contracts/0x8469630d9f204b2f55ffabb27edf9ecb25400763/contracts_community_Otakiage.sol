// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import "./openzeppelin_contracts_metatx_ERC2771Context.sol";
import "./contracts_libs_Administration.sol";
import "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
import "./openzeppelin_contracts_token_ERC1155_IERC1155Receiver.sol";
import "./openzeppelin_contracts_utils_Base64.sol";
import "./openzeppelin_contracts_utils_Strings.sol";
import "./contracts_community_interfaces_IOmamori.sol";
import "./contracts_community_interfaces_IOtakiage.sol";

contract Otakiage is ERC721, ERC2771Context, Administration, IERC1155Receiver, IOtakiage {
  uint256 public tokenIds;
  uint256 public omamoriTypeCount;
  IOmamori public omamoriContract;
  uint256 public omamoriTokenIdOffset;
  string public cid;
  string public imageExtension;
  address[] public otakiageUsersArr;
  mapping(address => uint256[]) public otakiageUserOmamoriIds;

  constructor(address _trustedForwarder, address _omamoriAddress) ERC721("Otakiage", "OTK") ERC2771Context(_trustedForwarder) {
    omamoriContract = IOmamori(_omamoriAddress);
    omamoriTypeCount = 6;
    omamoriTokenIdOffset = 1;
    imageExtension = ".png";
  }

  function getOtakiageOmamoriBalances() public view returns (uint256[] memory) {
    uint256 length = omamoriTypeCount;
    address[] memory accounts = new address[](length);
    uint256[] memory ids = new uint256[](length);
    for (uint256 i = 0; i < length; i++) {
        accounts[i] = address(this);
        ids[i] = i + omamoriTokenIdOffset;
    }
    return omamoriContract.balanceOfBatch(accounts, ids);
  }

  function getOtakiageOmamoriInfo() public view returns (IOmamori.NengajoInfo[] memory) {
    uint256[] memory balances = getOtakiageOmamoriBalances();
    IOmamori.NengajoInfo[] memory nengajoInfos = omamoriContract.retrieveAllNengajoes();

    uint256 validBalanceCount = 0;
    for (uint256 i = 0; i < balances.length; i++) {
        if (balances[i] > 0) {
            validBalanceCount++;
        }
    }

    uint256 length = validBalanceCount;
    IOmamori.NengajoInfo[] memory otakiageOmamories = new IOmamori.NengajoInfo[](length);
    for (uint256 i = 0; i < length; i++) {
        if(balances[i] > 0){
            otakiageOmamories[i] = IOmamori.NengajoInfo(
                nengajoInfos[i+1].id,
                nengajoInfos[i+1].uri,
                nengajoInfos[i+1].creator,
                nengajoInfos[i+1].maxSupply
            );
        }
    }
    return otakiageOmamories;
  }

  function getOtakiageOmamoriInfoWithBalance() public view returns (NengajoInfoWithBalance[] memory) {
    uint256[] memory balances = getOtakiageOmamoriBalances();
    IOmamori.NengajoInfo[] memory nengajoInfos = omamoriContract.retrieveAllNengajoes();

    uint256 validBalanceCount = 0;
    for (uint256 i = 0; i < balances.length; i++) {
        if (balances[i] > 0) {
            validBalanceCount++;
        }
    }

    uint256 length = validBalanceCount;
    NengajoInfoWithBalance[] memory otakiageOmamoriesWithBalances = new NengajoInfoWithBalance[](length);
    for (uint256 i = 0; i < length; i++) {
        if(balances[i] > 0){
            otakiageOmamoriesWithBalances[i] = NengajoInfoWithBalance(
                nengajoInfos[i+1].id,
                nengajoInfos[i+1].uri,
                nengajoInfos[i+1].creator,
                nengajoInfos[i+1].maxSupply,
                balances[i]
            );
        }
    }
    return otakiageOmamoriesWithBalances;
  }

  function getOtakiageUsersArr() public view returns (address[] memory) {
    return otakiageUsersArr;
  }

  function getOtakiageUserCount() public view returns (uint256) {
    return otakiageUsersArr.length;
  }

  function getOtakiageUserOmamoriIds(address user) public view returns (uint256[] memory) {
    return otakiageUserOmamoriIds[user];
  }

  function getOtakiageUserOmamoriIdsCount(address user) public view returns (uint256) {
    return otakiageUserOmamoriIds[user].length;
  }

  function setOmamoriAddress(address _omamoriAddress) public onlyAdmins {
    omamoriContract = IOmamori(_omamoriAddress);
  }

  function setOmamoriTypeCount(uint256 _omamoriTypeCount) public onlyAdmins {
    omamoriTypeCount = _omamoriTypeCount;
  }

  function setOmamoriTokenIdOffset(uint256 _omamoriTokenIdOffset) public onlyAdmins {
    omamoriTokenIdOffset = _omamoriTokenIdOffset;
  }
  function setCID(string calldata _cid) external onlyAdmins {
    cid = _cid;
  }

  function setImageExtension(string calldata _imageExtension) external onlyAdmins {
    imageExtension = _imageExtension;
  }

  function mintOtakiage(address to) public onlyAdmins {
    uint256 newTokenId = tokenIds;
    tokenIds++;
    _mint(to, newTokenId);

    emit Mint(to, newTokenId);
  }

  function batchMintOtakiage(address[] memory tos) public onlyAdmins {
    uint256 length = tos.length;
    for (uint256 i = 0; i < length; i++) {
      mintOtakiage(tos[i]);
    }
  }

  function fetchHoldingOmamoriBalance() public view returns (uint256[] memory, uint256[] memory) {
    uint256 length = omamoriTypeCount;

    address[] memory accounts = new address[](length);
    uint256[] memory ids = new uint256[](length);

    for (uint256 i = 0; i < length; i++) {
      accounts[i] = _msgSender();
      ids[i] = i + omamoriTokenIdOffset;
    }
    
    uint256[] memory values = omamoriContract.balanceOfBatch(accounts, ids);

    return (ids, values);
  }

  function _recordOtakiageUser(address user, uint256[] memory omamoriIds) internal {
    otakiageUsersArr.push(user);
    otakiageUserOmamoriIds[user] = omamoriIds;
  }

  function _recordOtakiageUsers(address[] memory users, uint256[] memory omamoriIds) internal {
    for (uint256 i = 0; i < users.length; i++) {
      _recordOtakiageUser(users[i], omamoriIds);
    }
  }

  function recordOtakiageUser(address user, uint256[] memory omamoriIds) external onlyAdmins {
    _recordOtakiageUser(user, omamoriIds);
  }

  function recordOtakiageUsers(address[] memory users, uint256[] memory omamoriIds) external onlyAdmins {
    _recordOtakiageUsers(users, omamoriIds);
  }
  
  function sendAllOmamori() public {
    (uint256[] memory ids, uint256[] memory values) = fetchHoldingOmamoriBalance();

    omamoriContract.safeBatchTransferFrom(_msgSender(), address(this), ids, values, "");

    uint256[] memory _userOmamoriIds = new uint256[](omamoriTypeCount);
    uint256 count = 0;
    uint256 idsLength = ids.length;    
    for (uint256 i = 0; i < idsLength; i++) {
      if (values[i] > 0) {
        _userOmamoriIds[count] = ids[i];
        count++;
      }
    }

    uint256[] memory userOmamoriIds = new uint256[](count);
    for (uint256 i = 0; i < count; i++) {
      userOmamoriIds[i] = _userOmamoriIds[i];
    }

    _recordOtakiageUser(_msgSender(), userOmamoriIds);

    emit SendAllOmamori(_msgSender(), ids, values);
  }

  function otakiage() public onlyAdmins {
    batchMintOtakiage(otakiageUsersArr);

    emit OtakiageEvent(otakiageUsersArr);
  }

  function constructTokenURI(
    TokenURIParams memory params
  ) internal pure returns (string memory) {
    return string(
      abi.encodePacked(
        'data:application/json;base64,',
        Base64.encode(
          bytes(
            abi.encodePacked('{"name":"', params.name, '", "description":"', params.description, '", "image": "', params.image, '"}')
          )
        )
      )
    );
  }

  function tokenURI(
    uint256 tokenId
  ) public view override(ERC721, IOtakiage) returns (string memory) {
    string memory tokenIdString = Strings.toString(tokenId);
    TokenURIParams memory params = TokenURIParams({
      name: string.concat("Certification of Participation in Otakiage No. ", tokenIdString),
      description: string.concat(
        "This NFT certifies the participation of the 2024 HENKAKU Omamori NFT in the Otakiage event."
      ),
      image: getImage(tokenId)
    });

    return constructTokenURI(params);
  }

  function getImage(uint256 tokenId) public view returns (string memory) {
    return string.concat("ipfs://", cid, "/", Strings.toString(tokenId), imageExtension);
  }

  function getCID() public view returns (string memory) {
    return cid;
  }

  function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address sender) {
    if (isTrustedForwarder(msg.sender)) {
      assembly {
        sender := shr(96, calldataload(sub(calldatasize(), 20)))
      }
    } else {
      return super._msgSender();
    }
  }

  function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
    if (isTrustedForwarder(msg.sender)) {
      return msg.data[:msg.data.length - 20];
    } else {
      return super._msgData();
    }
  }

  function _contextSuffixLength() internal view virtual override(Context, ERC2771Context) returns (uint256) {
    return ERC2771Context._contextSuffixLength();
  }

  function onERC1155Received(
    address operator,
    address from,
    uint256 id,
    uint256 value,
    bytes calldata data
  ) external virtual override returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  function onERC1155BatchReceived(
    address operator,
    address from,
    uint256[] calldata ids,
    uint256[] calldata values,
    bytes calldata data
  ) external virtual override returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
  }
}
pragma solidity 0.8.28;
import "./contracts_ModerationService.sol";
import "./contracts_HashChan3.sol";

contract ModerationServiceFactory {
  
  
  HashChan3 public hashChan3;
  address[] public modServices;
  uint256 public modServiceIterator;

  event NewModerationService(
    address indexed owner,
    address indexed moderationService,
    uint256 indexed blockNumber,
    string name
  );

  constructor (address _hashChan3) {
    hashChan3 = HashChan3(_hashChan3);
  }

  function getModerationServices() public view returns (address[] memory) {
    return modServices;
  }

  function createModerationService(
    string memory name,
    string memory uri,
    uint256 port
  ) public  {
    ModerationService  newModService = new ModerationService(
      address(hashChan3),
      name,
      msg.sender,
      uri,
      port
    );
    modServices.push(address(newModService));
    modServiceIterator++;
    emit NewModerationService(
      msg.sender,
      address(newModService),
      block.number,
      name
    );
  }
}
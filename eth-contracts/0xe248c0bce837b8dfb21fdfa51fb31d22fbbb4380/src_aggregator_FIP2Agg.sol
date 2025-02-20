pragma solidity 0.8.18;

import { ERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_ERC20Upgradeable.sol";
import { AccessControlUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";

contract FIP2Agg is Initializable, ERC20Upgradeable, AccessControlUpgradeable {
  struct UserDetails {
    address account;
    uint256 baseAmount;
    uint256 arbAmount;
  }

  struct UserBalances {
    uint256 base;
    uint256 arb;
  }

  // Public mappings
  mapping(address => UserBalances) public userBalances;
  mapping(address => bool) public minted;
  mapping(address => uint256) public mintedTimestamp;

  // Roles
  bytes32 public constant UPDATER_ROLE = keccak256("UPDATER_ROLE");

  event TokensMinted(address indexed user, uint256 amount);
  event TokensBurned(address indexed user, uint256 amount);
  event BalancesUpdated(address indexed account, uint256 baseAmount, uint256 arbAmount);

  /// @notice Initializes the contract and sets the deployer as the default admin.
  function initialize() public initializer {
    __ERC20_init("FIP2 Aggregator Token", "FIP2Agg");
    __AccessControl_init();

    // Assign DEFAULT_ADMIN_ROLE to the deployer
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
  }

  /// @notice Sets balances for a list of users. Restricted to accounts with `UPDATER_ROLE`.
  /// @param userDetails An array of UserDetails structs containing user accounts and balances.
  function setBalances(UserDetails[] calldata userDetails) external onlyRole(UPDATER_ROLE) {
    require(userDetails.length > 0, "No user details provided");

    for (uint256 i = 0; i < userDetails.length; i++) {
      address account = userDetails[i].account;
      uint256 baseAmount = userDetails[i].baseAmount;
      uint256 arbAmount = userDetails[i].arbAmount;

      _burnExistingFIP2Agg(account);

      userBalances[account] = UserBalances({ base: baseAmount, arb: arbAmount });

      uint256 newBalance = baseAmount + arbAmount;
      if (newBalance > 0) {
        _mint(account, newBalance);
        minted[account] = true;
        mintedTimestamp[account] = block.timestamp;
        emit TokensMinted(account, newBalance);
      }

      emit BalancesUpdated(account, baseAmount, arbAmount);
    }
  }

  /// @notice Internal function to burn existing balances.
  /// @param account The address whose tokens will be burned.
  function _burnExistingFIP2Agg(address account) internal {
    uint256 currentBalance = balanceOf(account);
    if (currentBalance > 0) {
      _burn(account, currentBalance);
      emit TokensBurned(account, currentBalance);
    }
  }

  uint256[50] private __gap; // Storage gap for future upgrades
}
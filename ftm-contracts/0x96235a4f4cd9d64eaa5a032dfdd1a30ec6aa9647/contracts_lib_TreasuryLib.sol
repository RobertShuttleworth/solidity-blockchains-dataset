// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import "./contracts_proxy_Controllable.sol";
import "./contracts_interfaces_ITreasury.sol";
import "./contracts_interfaces_IERC20.sol";
import "./contracts_interfaces_IGameToken.sol";
import "./contracts_interfaces_IApplicationEvents.sol";
import "./contracts_interfaces_IAppErrors.sol";

library TreasuryLib {
  //region ------------------------ CONSTANTS
  uint public constant AUGMENT_GOV_FEE = 50;
  uint public constant REPAIR_GOV_FEE = 50;
  //endregion ------------------------ CONSTANTS

  //region ------------------------ RESTRICTIONS

  function onlyDungeonFactory(IController controller) internal view {
    if (controller.dungeonFactory() != msg.sender) revert IAppErrors.ErrorNotDungeonFactory(msg.sender);
  }
  //endregion ------------------------ RESTRICTIONS

  //region ------------------------ VIEWS

  function balanceOfToken(address token) internal view returns (uint) {
    return IERC20(token).balanceOf(address(this));
  }
  //endregion ------------------------ VIEWS

  //region ------------------------ ACTIONS

  /// @notice Send {amount} of the {token} to the {dungeon}
  function sendToDungeon(IController controller, address dungeon, address token, uint amount) internal {
    onlyDungeonFactory(controller);
    uint bal = IERC20(token).balanceOf(address(this));
    if (bal == 0 || amount > bal) revert IAppErrors.NotEnoughBalance();
    IERC20(token).transfer(dungeon, amount);
    emit IApplicationEvents.AssetsSentToDungeon(dungeon, token, amount);
  }
  //endregion ------------------------ ACTIONS

}
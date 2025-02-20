// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IPool, DataTypes} from "./lib_aave-helpers_lib_aave-address-book_lib_aave-v3-origin_src_contracts_interfaces_IPool.sol";
import {IPoolAddressesProvider} from "./lib_aave-helpers_lib_aave-address-book_lib_aave-v3-origin_src_contracts_interfaces_IPoolAddressesProvider.sol";
import {IPoolConfigurator} from "./lib_aave-helpers_lib_aave-address-book_lib_aave-v3-origin_src_contracts_interfaces_IPoolConfigurator.sol";
import {ReserveConfiguration} from "./lib_aave-helpers_lib_aave-address-book_lib_aave-v3-origin_src_contracts_protocol_libraries_configuration_ReserveConfiguration.sol";
import {Initializable} from "./lib_aave-helpers_lib_aave-address-book_lib_aave-v3-origin_lib_solidity-utils_lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import {IERC20} from "./lib_aave-helpers_lib_aave-address-book_lib_aave-v3-origin_lib_solidity-utils_src_contracts_oz-common_interfaces_IERC20.sol";
import {SafeERC20} from "./lib_aave-helpers_lib_aave-address-book_lib_aave-v3-origin_lib_solidity-utils_src_contracts_oz-common_SafeERC20.sol";
import {UpgradeableOwnableWithGuardian} from "./lib_aave-helpers_lib_aave-address-book_lib_aave-v3-origin_lib_solidity-utils_src_contracts_access-control_UpgradeableOwnableWithGuardian.sol";
import {IGhoToken} from "./src_interfaces_IGhoToken.sol";
import {IGhoDirectMinter} from "./src_interfaces_IGhoDirectMinter.sol";

/**
 * @title GhoDirectMinter
 * @notice The GHODirectMinter is a GHO facilitator, that can inject(mint) and remove(burn) GHO from an AAVE pool that has GHO listed as a non-custom AToken.
 * @author BGD Labs @bgdlabs
 */
contract GhoDirectMinter is Initializable, UpgradeableOwnableWithGuardian, IGhoDirectMinter {
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using SafeERC20 for IERC20;

  // @inheritdoc IGHODirectMinter
  IPool public immutable POOL;
  // @inheritdoc IGHODirectMinter
  IPoolConfigurator public immutable POOL_CONFIGURATOR;
  // @inheritdoc IGHODirectMinter
  address public immutable COLLECTOR;
  // @inheritdoc IGHODirectMinter
  address public immutable GHO;
  // @inheritdoc IGHODirectMinter
  address public immutable GHO_A_TOKEN;

  constructor(IPoolAddressesProvider poolAddressesProvider, address collector, address gho) {
    IPool pool = IPool(poolAddressesProvider.getPool());
    POOL = pool;
    POOL_CONFIGURATOR = IPoolConfigurator(poolAddressesProvider.getPoolConfigurator());
    COLLECTOR = collector;
    GHO = gho;
    DataTypes.ReserveDataLegacy memory reserveData = pool.getReserveData(gho);
    require(reserveData.aTokenAddress != address(0), InvalidAToken());
    GHO_A_TOKEN = reserveData.aTokenAddress;
    _disableInitializers();
  }

  function initialize(address owner, address council) external virtual initializer {
    __Ownable_init(owner);
    __Ownable_With_Guardian_init(council);
  }

  // @inheritdoc IGHODirectMinter
  function mintAndSupply(uint256 amount) external onlyOwnerOrGuardian {
    IGhoToken(GHO).mint(address(this), amount);
    IERC20(GHO).forceApprove(address(POOL), amount);
    DataTypes.ReserveConfigurationMap memory configuration = POOL.getConfiguration(GHO);
    // setting supplycap to zero to disable it
    POOL_CONFIGURATOR.setSupplyCap(GHO, 0);
    POOL.supply(GHO, amount, address(this), 0);
    // setting supplycap back the original value
    POOL_CONFIGURATOR.setSupplyCap(GHO, configuration.getSupplyCap());
  }

  // @inheritdoc IGHODirectMinter
  function withdrawAndBurn(uint256 amount) external onlyOwnerOrGuardian {
    uint256 amountWithdrawn = POOL.withdraw(GHO, amount, address(this));
    IGhoToken(GHO).burn(amountWithdrawn);
  }

  // @inheritdoc IGHODirectMinter
  function transferExcessToTreasury() external {
    (, uint256 level) = IGhoToken(GHO).getFacilitatorBucket(address(this));
    uint256 levelExcess = IERC20(GHO_A_TOKEN).balanceOf(address(this)) - level;
    IERC20(GHO_A_TOKEN).transfer(address(COLLECTOR), levelExcess);
  }
}
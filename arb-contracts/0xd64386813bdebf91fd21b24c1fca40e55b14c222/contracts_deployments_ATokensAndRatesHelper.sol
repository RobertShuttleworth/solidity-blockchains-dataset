// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {LendingPool} from './contracts_protocol_lendingpool_LendingPool.sol';
import {LendingPool} from './contracts_protocol_lendingpool_LendingPool.sol';
import { LendingPoolAddressesProvider } from './contracts_protocol_configuration_LendingPoolAddressesProvider.sol';
import {LendingPoolConfigurator} from './contracts_protocol_lendingpool_LendingPoolConfigurator.sol';
import {AToken} from './contracts_protocol_tokenization_AToken.sol';
import {AToken} from './contracts_protocol_tokenization_AToken.sol';
import { DefaultReserveInterestRateStrategy } from './contracts_protocol_lendingpool_DefaultReserveInterestRateStrategy.sol';
import {Ownable} from './contracts_dependencies_openzeppelin_contracts_Ownable.sol';
import {StringLib} from './contracts_deployments_StringLib.sol';

contract ATokensAndRatesHelper is Ownable {
  address payable private pool;
  address private addressesProvider;
  address private poolConfigurator;
  event deployedContracts(address aToken, address strategy);

  struct InitDeploymentInput {
    address asset;
    uint256[6] rates;
  }

  struct ConfigureReserveInput {
    address asset;
    uint256 baseLTV;
    uint256 liquidationThreshold;
    uint256 liquidationBonus;
    uint256 reserveFactor;
    bool stableBorrowingEnabled;
    bool borrowingEnabled;
  }

  constructor(
    address payable _pool,
    address _addressesProvider,
    address _poolConfigurator
  ) public {
    pool = _pool;
    addressesProvider = _addressesProvider;
    poolConfigurator = _poolConfigurator;
  }

  function initDeployment(InitDeploymentInput[] calldata inputParams) external onlyOwner {
    for (uint256 i = 0; i < inputParams.length; i++) {
      emit deployedContracts(
        address(new AToken()),
        address(
          new DefaultReserveInterestRateStrategy(
            LendingPoolAddressesProvider(addressesProvider),
            inputParams[i].rates[0],
            inputParams[i].rates[1],
            inputParams[i].rates[2],
            inputParams[i].rates[3],
            inputParams[i].rates[4],
            inputParams[i].rates[5]
          )
        )
      );
    }
  }

  function configureReserves(ConfigureReserveInput[] calldata inputParams) external onlyOwner {
    LendingPoolConfigurator configurator = LendingPoolConfigurator(poolConfigurator);
    for (uint256 i = 0; i < inputParams.length; i++) {
      configurator.configureReserveAsCollateral(
        inputParams[i].asset,
        inputParams[i].baseLTV,
        inputParams[i].liquidationThreshold,
        inputParams[i].liquidationBonus
      );

      if (inputParams[i].borrowingEnabled) {
        configurator.enableBorrowingOnReserve(
          inputParams[i].asset,
          inputParams[i].stableBorrowingEnabled
        );
      }
      configurator.setReserveFactor(inputParams[i].asset, inputParams[i].reserveFactor);
    }
  }
}
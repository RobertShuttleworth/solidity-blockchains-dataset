// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import './openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol';

contract PunguToken is ERC20Burnable {
  uint256 public constant liquidityReserve = 800_000_000 * (10 ** 18);
  uint256 public constant presaleReserve = 1_600_000_000 * (10 ** 18);
  uint256 public constant stakingReserve = 2_000_000_000 * (10 ** 18);
  uint256 public constant marketingReserve = 1_600_000_000 * (10 ** 18);
  uint256 public constant developmentReserve = 1_900_000_000 * (10 ** 18);
  uint256 public constant airdropReserve = 100_000_000 * (10 ** 18);

  constructor(address lockAddress, address presaleContract_, address stakingContract_, address airdropContract_) ERC20('Pengu Unleashed', 'PUNGU') {
    uint256 lockedTokens_ = liquidityReserve + marketingReserve + developmentReserve;

    _mint(lockAddress, lockedTokens_);
    _mint(presaleContract_, presaleReserve);
    _mint(stakingContract_, stakingReserve);
    _mint(airdropContract_, airdropReserve);
  }
}
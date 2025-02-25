// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './openzeppelin_contracts_token_ERC20_IERC20.sol';

interface IDecentralizedIndex is IERC20 {
  enum IndexType {
    WEIGHTED,
    UNWEIGHTED
  }

  struct Config {
    address partner;
    bool hasTransferTax;
    bool blacklistTKNpTKNPoolV2;
  }

  // all fees: 1 == 0.01%, 10 == 0.1%, 100 == 1%
  struct Fees {
    uint16 burn;
    uint16 bond;
    uint16 debond;
    uint16 buy;
    uint16 sell;
    uint16 partner;
  }

  struct IndexAssetInfo {
    address token;
    uint256 weighting;
    uint256 basePriceUSDX96;
    address c1; // arbitrary contract/address field we can use for an index
    uint256 q1; // arbitrary quantity/number field we can use for an index
  }

  event Create(address indexed newIdx, address indexed wallet);
  event Initialize(address indexed wallet, address v2Pool);
  event Bond(
    address indexed wallet,
    address indexed token,
    uint256 amountTokensBonded,
    uint256 amountTokensMinted
  );
  event Debond(address indexed wallet, uint256 amountDebonded);
  event AddLiquidity(
    address indexed wallet,
    uint256 amountTokens,
    uint256 amountDAI
  );
  event RemoveLiquidity(address indexed wallet, uint256 amountLiquidity);
  event SetPartner(address indexed wallet, address newPartner);
  event SetPartnerFee(address indexed wallet, uint16 newFee);

  function BOND_FEE() external view returns (uint16);

  function DEBOND_FEE() external view returns (uint16);

  function FLASH_FEE_AMOUNT_DAI() external view returns (uint256);

  function PAIRED_LP_TOKEN() external view returns (address);

  function indexType() external view returns (IndexType);

  function created() external view returns (uint256);

  function lpStakingPool() external view returns (address);

  function lpRewardsToken() external view returns (address);

  function partner() external view returns (address);

  function getIdxPriceUSDX96() external view returns (uint256, uint256);

  function isAsset(address token) external view returns (bool);

  function getAllAssets() external view returns (IndexAssetInfo[] memory);

  function getInitialAmount(
    address sToken,
    uint256 sAmount,
    address tToken
  ) external view returns (uint256);

  function getTokenPriceUSDX96(address token) external view returns (uint256);

  function processPreSwapFeesAndSwap() external;

  function bond(address token, uint256 amount, uint256 amountMintMin) external;

  function debond(
    uint256 amount,
    address[] memory token,
    uint8[] memory percentage
  ) external;

  function addLiquidityV2(
    uint256 idxTokens,
    uint256 daiTokens,
    uint256 slippage,
    uint256 deadline
  ) external returns (uint256);

  function removeLiquidityV2(
    uint256 lpTokens,
    uint256 minTokens,
    uint256 minDAI,
    uint256 deadline
  ) external;

  function flash(
    address recipient,
    address token,
    uint256 amount,
    bytes calldata data
  ) external;
}
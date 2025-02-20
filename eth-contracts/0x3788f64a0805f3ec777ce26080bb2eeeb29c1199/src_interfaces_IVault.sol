// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.21;

import {IERC4626} from "./node_modules_openzeppelin_contracts_interfaces_IERC4626.sol";
import {IERC20} from "./node_modules_openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IVaultSupervisor} from "./src_interfaces_IVaultSupervisor.sol";
import {ISwapper} from "./src_interfaces_ISwapper.sol";

interface IVault is IERC4626 {
    enum AssetType {
        NONE,
        ETH,
        STABLE,
        BTC,
        OTHER
    }

    struct SwapAssetParams {
        IERC20 newDepositToken;
        string name;
        string symbol;
        AssetType assetType;
        uint256 assetLimit;
    }

    function initialize(
        address _owner,
        IERC20 _depositToken,
        string memory _name,
        string memory _symbol,
        AssetType _assetType
    ) external;

    function deposit(uint256 assets, address depositor) external returns (uint256);

    function redeem(uint256 shares, address to, address owner) external returns (uint256 assets);

    function setLimit(uint256 newLimit) external;

    function assetLimit() external view returns (uint256);

    function pause(bool toPause) external;

    function owner() external view returns (address);

    function transferOwnership(address newOwner) external;

    function renounceOwnership() external;

    function totalAssets() external view returns (uint256);

    function decimals() external view returns (uint8);

    function assetType() external view returns (AssetType);

    function swapAsset(
        ISwapper swapper,
        SwapAssetParams calldata params,
        uint256 minNewAssetAmount,
        bytes calldata swapperOtherParams
    ) external;
}
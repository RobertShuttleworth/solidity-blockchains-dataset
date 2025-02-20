// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IRouter} from "./src_router_IRouter.sol";
import {PoolInfo} from "./src_lib_Types.sol";

interface IPoolFactoryLike {
    enum PoolVariant {
        ENUMERABLE_ETH,
        MISSING_ENUMERABLE_ETH,
        ENUMERABLE_ERC20,
        MISSING_ENUMERABLE_ERC20
    }

    function protocolFeeMultiplier() external view returns (uint256);

    function protocolFeeRecipient() external view returns (address payable);

    function isValidSignatureAdmin(address) external view returns (bool);

    function callAllowed(address target) external view returns (bool);

    function routerStatus(
        IRouter router
    ) external view returns (bool allowed, bool wasEverAllowed);

    function isPool(
        address potentialPool,
        PoolVariant variant
    ) external view returns (bool);

    function verifyRaritySignature(
        uint256[] memory _tokenIds,
        uint256[] memory _rarities,
        address _nft,
        bytes memory _adminSignature
    ) external view returns (bool);

    function getTimelockValueForPercentage(
        uint256 percentage
    ) external view returns (uint256);
}
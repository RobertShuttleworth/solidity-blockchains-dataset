// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IRouter {
    function pairTransferERC20From(
        IERC20 token,
        address from,
        address to,
        uint256 amount,
        IPoolFactoryLike.PoolVariant variant
    ) external;

    function pairTransferNFTFrom(
        IERC721 nft,
        address from,
        address to,
        uint256 id,
        IPoolFactoryLike.PoolVariant variant
    ) external;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
interface IPoolManager is IERC1155 {
    struct Pool {
        uint160 id0;
        uint160 id1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 kLast;
    }

    function ethrunes() external view returns(address);
    function getReserves(uint256 poolId) external view returns(uint256 reserve0, uint256 reserve1);
    function pools(uint256 poolId) external view returns(uint160 id0, uint160 id1, uint256 reserve0, uint256 reserve1, uint256 kLast);
    function mint(uint160 id0, uint160 id1, address to) external returns(uint256 liquidity);
    function burn(uint256 poolId, address to) external returns(uint256 amount0, uint256 amount1);
    function swap(uint160 idIn, uint160 idOut, uint256 amountOut, address recipient) external;
}   
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import "./contracts_interfaces_IPoolManager.sol";

library SwapLibrary {

    function getPoolId(uint160 idA, uint160 idB) internal pure returns (uint256 poolId) {
        (uint160 id0, uint160 id1) = sortTokens(idA, idB);
        poolId = uint256(keccak256(abi.encodePacked(id0, id1)));
    }

    function sortTokens(uint160 idA, uint160 idB) internal pure returns (uint160 id0, uint160 id1) {
        require(idA != idB, 'SwapLibrary: IDENTICAL_IDS');
        (id0, id1) = idA < idB ? (idA, idB) : (idB, idA);
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address poolManager, uint160 tokenA, uint160 tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        (uint160 id0,) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1) = IPoolManager(poolManager).getReserves(getPoolId(tokenA, tokenB));
        (reserveA, reserveB) = tokenA == id0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, 'SwapLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'SwapLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }


    function getAmountOut(
        uint256 amountIn, 
        uint256 reserveIn, 
        uint256 reserveOut,
        uint256 discount,
        uint256 rebate
    ) internal pure returns (uint256 amountOut, uint256 rebateAmount) {
        require(amountIn > 0, 'SwapLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwapLibrary: INSUFFICIENT_LIQUIDITY');
        require(discount <= 10000, "SwapLibrary: INVALID_DISCOUNT");
        require(rebate <= 5000, "SwapLibrary: INVALID_REBATE");

        // at least 0.3% fees to LP
        require(discount * (10000 - rebate) >= 30000000, "CHECK_FEE_RATES");

        uint256 fee = amountIn * discount / (100 * 10000);
        rebateAmount = fee * rebate / 10000;

        uint256 amountInWithoutFee = amountIn - fee;
        uint256 numerator = amountInWithoutFee * reserveOut;
        uint256 denominator = reserveIn + amountInWithoutFee;

        amountOut = numerator / denominator;
    }


    function getAmountIn(
        uint256 amountOut, 
        uint256 reserveIn, 
        uint256 reserveOut,
        uint256 discount,
        uint256 rebate
    ) internal pure returns (uint256 amountIn, uint256 rebateAmount) 
    {
        require(amountOut > 0, 'SwapLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'SwapLibrary: INSUFFICIENT_LIQUIDITY');
        require(discount <= 10000, "SwapLibrary: INVALID_DISCOUNT");
        require(rebate <= 5000, "SwapLibrary: INVALID_REBATE");
        
        // at least 0.3% fees to LP
        require(discount * (10000 - rebate) >= 30000000, "CHECK_FEE_RATES");

        uint256 amountInWithoutFee = reserveIn * amountOut / (reserveOut - amountOut) + 1;

        amountIn = amountInWithoutFee * 100 * 10000 / (100 * 10000 - discount);

        uint256 fee = amountIn - amountInWithoutFee;

        rebateAmount = fee * rebate / 10000;
    }


    function getAmountsOut(
        address poolManager, 
        uint256 amountIn, 
        uint160[] memory path,
        uint256 discount,
        uint256 rebate
    ) internal view returns (
        uint256[] memory amounts,
        uint256 rebateAmount
    )
    {
        require(path.length >= 2, 'SwapLibrary: INVALID_PATH');
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;

        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(poolManager, path[i], path[i + 1]);
            uint256 amountOut;
            if(i == 0) {
                (amountOut, rebateAmount) = getAmountOut(amounts[i], reserveIn, reserveOut, discount, rebate);
            } else {
                (amountOut,) = getAmountOut(amounts[i], reserveIn, reserveOut, discount, 0);
            }
            amounts[i + 1] = amountOut;
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(
        address poolManager, 
        uint256 amountOut, 
        uint160[] memory path,
        uint256 discount,
        uint256 rebate
    ) internal view returns (
        uint256[] memory amounts, 
        uint256 rebateAmount
    ) {
        require(path.length >= 2, 'SwapLibrary: INVALID_PATH');
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;

        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(poolManager, path[i - 1], path[i]);
            uint256 amountIn;
            if(i == 1) {
                (amountIn, rebateAmount) = getAmountIn(amounts[i], reserveIn, reserveOut, discount, rebate);
            } else {
                (amountIn, ) = getAmountIn(amounts[i], reserveIn, reserveOut, discount, 0);
            }
            amounts[i - 1] = amountIn;
        }
    }
}
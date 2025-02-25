// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.27;

import {FixedPointMathLib} from "./solady_src_utils_FixedPointMathLib.sol";

contract BondingCurve {
    using FixedPointMathLib for uint256;
    using FixedPointMathLib for int256;

    error InsufficientLiquidity();

    uint256 public immutable B = 4379701787; 
    uint256 public immutable desiredRaise; // Now stored on-chain permanently

    constructor(uint256 _desiredRaise) {
        require(_desiredRaise > 0, "Invalid desired raise");
        desiredRaise = _desiredRaise;
    }

    /**
     * @notice Computes A dynamically given the stored desiredRaise and a provided allocatedSupply.
     * @param allocatedSupply The number of tokens allocated to the bonding curve.
     */
    function _computeA(uint256 allocatedSupply) internal view returns (uint256) {
        uint256 b_times_alloc = B.mulWad(allocatedSupply);
        
        uint256 exp_b_alloc = uint256((int256(b_times_alloc)).expWad());
        require(exp_b_alloc > 1e18, "exp too low, adjust parameters");

        uint256 numerator = desiredRaise.mulWad(B);
        uint256 denominator = exp_b_alloc - 1e18;
        
        return numerator.divWad(denominator);
    }

    function getEthBuyQuote(uint256 currentSupply, uint256 allocatedSupply, uint256 ethOrderSize) 
        external view returns (uint256) 
    {
        require(currentSupply < allocatedSupply, "Supply exceeds allocation");
        require(ethOrderSize > 0, "Invalid order size");
        
        uint256 A_local = _computeA(allocatedSupply);
        uint256 x0 = currentSupply;
        uint256 deltaY = ethOrderSize;

        uint256 exp_b_x0 = uint256((int256(B.mulWad(x0))).expWad());
        uint256 scaled_term = deltaY.mulWad(B).divWad(A_local);
        uint256 exp_b_x1 = exp_b_x0 + scaled_term;

        uint256 deltaX = uint256(int256(exp_b_x1).lnWad()).divWad(B) - x0;
        return deltaX;
    }

    function getTokenBuyQuote(uint256 currentSupply, uint256 allocatedSupply, uint256 tokenOrderSize)
        external view returns (uint256)
    {
        uint256 A_local = _computeA(allocatedSupply);
        uint256 x0 = currentSupply;
        uint256 x1 = x0 + tokenOrderSize;

        uint256 exp_b_x0 = uint256((int256(B.mulWad(x0))).expWad());
        uint256 exp_b_x1 = uint256((int256(B.mulWad(x1))).expWad());

        uint256 deltaY = (exp_b_x1 - exp_b_x0).fullMulDiv(A_local, B);
        return deltaY;
    }

    function getEthSellQuote(uint256 currentSupply, uint256 allocatedSupply, uint256 ethOrderSize)
        external view returns (uint256)
    {
        uint256 A_local = _computeA(allocatedSupply);

        uint256 deltaY = ethOrderSize;
        uint256 x0 = currentSupply;
        uint256 exp_b_x0 = uint256((int256(B.mulWad(x0))).expWad());

        uint256 exp_b_x1 = exp_b_x0 - deltaY.fullMulDiv(B, A_local);
        if (exp_b_x1 < 1) revert InsufficientLiquidity();

        uint256 x1 = uint256(int256(exp_b_x1).lnWad()).divWad(B);
        uint256 tokensToSell = x0 - x1;

        return tokensToSell;
    }

    function getTokenSellQuote(uint256 currentSupply, uint256 allocatedSupply, uint256 tokensToSell)
        external view returns (uint256)
    {
        if (currentSupply < tokensToSell) revert InsufficientLiquidity();

        uint256 A_local = _computeA(allocatedSupply);

        uint256 x0 = currentSupply;
        uint256 x1 = x0 - tokensToSell;

        uint256 exp_b_x0 = uint256((int256(B.mulWad(x0))).expWad());
        uint256 exp_b_x1 = uint256((int256(B.mulWad(x1))).expWad());

        uint256 deltaY = (exp_b_x0 - exp_b_x1).fullMulDiv(A_local, B);

        return deltaY;
    }

    // Add these debug functions
    function debugComputeA(uint256 allocatedSupply) external view returns (uint256) {
        return _computeA(allocatedSupply);
    }

    function debugExpBAlloc(uint256 allocatedSupply) external view returns (uint256) {
        return uint256((int256(B.mulWad(allocatedSupply))).expWad());
    }
}
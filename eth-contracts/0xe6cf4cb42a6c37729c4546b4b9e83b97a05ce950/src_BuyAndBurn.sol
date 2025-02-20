// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "./src_const_Constants.sol";
import {wmul} from "./src_utils_Math.sol";
import {GoatX} from "./src_GoatX.sol";
import {SwapActions, SwapActionsState} from "./src_actions_SwapActions.sol";
import {ERC20Burnable} from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_ERC20Burnable.sol";

struct State {
    uint32 lastBurnTs;
    uint32 intervalBetweenBurns;
    uint128 swapCap;
    uint64 incentive;
}

/**
 * @title GoatXBuyAndBurn
 * @author Decentra
 */
contract GoatXBuyAndBurn is SwapActions {
    GoatX immutable goatX;
    ERC20Burnable public immutable titanX;

    State public state;

    uint256 public totalGoatXBurnt;

    event BuyAndBurn(uint256 indexed goatXAmount, uint256 indexed titanXAmount);

    error IntervalWait();

    constructor(address _goatX, address _titanX, SwapActionsState memory _s) SwapActions(_s) {
        goatX = GoatX(_goatX);
        titanX = ERC20Burnable(_titanX);

        state.intervalBetweenBurns = 10 minutes;
        state.incentive = 0.01e18;
    }

    function changeIntervalBetweenBurns(uint32 _newIntervalBetweenBurns)
        external
        onlyOwner
        notAmount0(_newIntervalBetweenBurns)
    {
        state.intervalBetweenBurns = _newIntervalBetweenBurns;
    }

    function changeIncentive(uint64 _newIncentive) external onlyOwner notGt(_newIncentive, 1e18) {
        state.incentive = _newIncentive;
    }

    function changeSwapCap(uint128 _newCap) external onlyOwner notAmount0(_newCap) {
        state.swapCap = _newCap;
    }

    function buyNBurn(uint32 _deadline) external notExpired(_deadline) onlyEOA notAmount0(erc20Bal(titanX)) {
        State storage $ = state;

        require(block.timestamp - $.intervalBetweenBurns >= $.lastBurnTs, IntervalWait());
        uint256 balance = erc20Bal(titanX);

        if (balance > $.swapCap) balance = $.swapCap;

        uint256 incentive = wmul(balance, $.incentive);

        balance -= incentive;

        uint256 goatXAmount = swapExactInput(address(titanX), address(goatX), balance, 0, _deadline);

        burnGoatX();
        titanX.transfer(msg.sender, incentive);

        emit BuyAndBurn(goatXAmount, balance);

        $.lastBurnTs = uint32(block.timestamp);
    }

    function burnGoatX() public {
        uint256 toBurn = erc20Bal(goatX);
        totalGoatXBurnt += toBurn;

        goatX.burn(toBurn);
    }

    function erc20Bal(ERC20Burnable t) internal view returns (uint256) {
        return t.balanceOf(address(this));
    }
}
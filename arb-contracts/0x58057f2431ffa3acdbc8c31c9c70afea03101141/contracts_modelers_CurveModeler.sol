// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./contracts_helpers_ERC20Helper.sol";

contract CurveModeler is ERC20Helper {
    enum CurveAddLiquiditySelectors {
        xa3185179, // add_liquidity(address,uint256[3],uint256)
        xe07a1036, // add_liquidity(address,uint256[3],uint256,address)
        x2ddd67cf, // add_liquidity(address,uint256[3],uint256,bool)
        x5507c9c4, // add_liquidity(address,uint256[3],uint256,bool,address)
        x384e03db, // add_liquidity(address,uint256[4],uint256)
        xd0b951e8, // add_liquidity(address,uint256[4],uint256,address)
        xc45d79e9, // add_liquidity(address,uint256[4],uint256,bool)
        x968fe83b, // add_liquidity(address,uint256[4],uint256,bool,address)
        xfd9de631, // add_liquidity(address,uint256[],uint256)
        x9a01e4d2, // add_liquidity(address,uint256[],uint256,address)
        x0b4c7e4d, // add_liquidity(uint256[2],uint256)
        x0c3e4b54, // add_liquidity(uint256[2],uint256,address)
        xee22be23, // add_liquidity(uint256[2],uint256,bool)
        x7328333b, // add_liquidity(uint256[2],uint256,bool,address)
        x4515cef3, // add_liquidity(uint256[3],uint256)
        x75b96abc, // add_liquidity(uint256[3],uint256,address)
        x2b6e993a, // add_liquidity(uint256[3],uint256,bool)
        x5cecb5f7, // add_liquidity(uint256[3],uint256,bool,address)
        x029b2f34, // add_liquidity(uint256[4],uint256)
        xcb495064, // add_liquidity(uint256[4],uint256,address)
        xb72df5de, // add_liquidity(uint256[],uint256)
        xa7256d09 // add_liquidity(uint256[],uint256,address)

    }

    enum CurveRemoveLiquiditySelectors {
        x29ed2862, // remove_liquidity_one_coin(address,uint256,int128,uint256)
        x1e700cbb, // remove_liquidity_one_coin(address,uint256,int128,uint256,address)
        xc5bdcd09, // remove_liquidity_one_coin(address,uint256,uint256,uint256)
        xd6943525, // remove_liquidity_one_coin(address,uint256,uint256,uint256,bool)
        x0664b693, // remove_liquidity_one_coin(address,uint256,uint256,uint256,bool,address)
        x1a4d01d2, // remove_liquidity_one_coin(uint256,int128,uint256)
        x081579a5, // remove_liquidity_one_coin(uint256,int128,uint256,address)
        x517a55a3, // remove_liquidity_one_coin(uint256,int128,uint256,bool)
        xf1dc3cc9, // remove_liquidity_one_coin(uint256,uint256,uint256)
        x0fbcee6e, // remove_liquidity_one_coin(uint256,uint256,uint256,address)
        x8f15b6b5, // remove_liquidity_one_coin(uint256,uint256,uint256,bool)
        x07329bcd // remove_liquidity_one_coin(uint256,uint256,uint256,bool,address)

    }

    enum CurveExchangeSelectors {
        x64a14558, // exchange(address,uint256,uint256,uint256,uint256)
        x2bf78c61, // exchange(address,uint256,uint256,uint256,uint256,bool)
        xb837cc69, // exchange(address,uint256,uint256,uint256,uint256,bool,address)
        x3df02124, // exchange(int128,int128,uint256,uint256)
        xddc1f59d, // exchange(int128,int128,uint256,uint256,address)
        x5b41b908, // exchange(uint256,uint256,uint256,uint256)
        xa64833a0, // exchange(uint256,uint256,uint256,uint256,address)
        x394747c5, // exchange(uint256,uint256,uint256,uint256,bool)
        xce7d6503, // exchange(uint256,uint256,uint256,uint256,bool,address)
        xa6417ed6, // exchange_underlying(int128,int128,uint256,uint256)
        x44ee1986, // exchange_underlying(int128,int128,uint256,uint256,address)
        x65b2489b, // exchange_underlying(uint256,uint256,uint256,uint256)
        xe2ad025a // exchange_underlying(uint256,uint256,uint256,uint256,address)

    }

    function curveSwap(
        CurveExchangeSelectors selector,
        uint256 ethValue,
        address executer,
        address pool,
        int128 sellTokenIndex,
        int128 buyTokenIndex,
        uint256 sellAmount,
        address buyToken,
        address payable recipient,
        uint256 minAmount
    ) external payable returns (uint256 buyAmount) {
        uint256 startBalance = getBalance(buyToken, recipient);
        bool useEth = buyToken == NATIVE;
        bytes memory callData;
        if (selector == CurveExchangeSelectors.x64a14558) {
            uint256 _sellTokenIndex = uint256(uint128(sellTokenIndex));
            uint256 _buyTokenIndex = uint256(uint128(buyTokenIndex));
            callData = abi.encodeWithSignature(
                "exchange(address,uint256,uint256,uint256,uint256)",
                pool,
                _sellTokenIndex,
                _buyTokenIndex,
                sellAmount,
                minAmount
            );
        } else if (selector == CurveExchangeSelectors.x2bf78c61) {
            uint256 _sellTokenIndex = uint256(uint128(sellTokenIndex));
            uint256 _buyTokenIndex = uint256(uint128(buyTokenIndex));
            callData = abi.encodeWithSignature(
                "exchange(address,uint256,uint256,uint256,uint256,bool)",
                pool,
                _sellTokenIndex,
                _buyTokenIndex,
                sellAmount,
                minAmount,
                useEth
            );
        } else if (selector == CurveExchangeSelectors.xb837cc69) {
            uint256 _sellTokenIndex = uint256(uint128(sellTokenIndex));
            uint256 _buyTokenIndex = uint256(uint128(buyTokenIndex));
            callData = abi.encodeWithSignature(
                "exchange(address,uint256,uint256,uint256,uint256,bool,address)",
                pool,
                _sellTokenIndex,
                _buyTokenIndex,
                sellAmount,
                minAmount,
                useEth,
                recipient
            );
        } else if (selector == CurveExchangeSelectors.x3df02124) {
            callData = abi.encodeWithSignature(
                "exchange(int128,int128,uint256,uint256)", sellTokenIndex, buyTokenIndex, sellAmount, minAmount
            );
        } else if (selector == CurveExchangeSelectors.xddc1f59d) {
            callData = abi.encodeWithSignature(
                "exchange(int128,int128,uint256,uint256,address)",
                sellTokenIndex,
                buyTokenIndex,
                sellAmount,
                minAmount,
                recipient
            );
        } else if (selector == CurveExchangeSelectors.x5b41b908) {
            uint256 _sellTokenIndex = uint256(uint128(sellTokenIndex));
            uint256 _buyTokenIndex = uint256(uint128(buyTokenIndex));
            callData = abi.encodeWithSignature(
                "exchange(uint256,uint256,uint256,uint256)", _sellTokenIndex, _buyTokenIndex, sellAmount, minAmount
            );
        } else if (selector == CurveExchangeSelectors.xa64833a0) {
            uint256 _sellTokenIndex = uint256(uint128(sellTokenIndex));
            uint256 _buyTokenIndex = uint256(uint128(buyTokenIndex));
            callData = abi.encodeWithSignature(
                "exchange(uint256,uint256,uint256,uint256,address)",
                _sellTokenIndex,
                _buyTokenIndex,
                sellAmount,
                minAmount,
                recipient
            );
        } else if (selector == CurveExchangeSelectors.x394747c5) {
            uint256 _sellTokenIndex = uint256(uint128(sellTokenIndex));
            uint256 _buyTokenIndex = uint256(uint128(buyTokenIndex));
            callData = abi.encodeWithSignature(
                "exchange(uint256,uint256,uint256,uint256,bool)",
                _sellTokenIndex,
                _buyTokenIndex,
                sellAmount,
                minAmount,
                useEth
            );
        } else if (selector == CurveExchangeSelectors.xce7d6503) {
            uint256 _sellTokenIndex = uint256(uint128(sellTokenIndex));
            uint256 _buyTokenIndex = uint256(uint128(buyTokenIndex));
            callData = abi.encodeWithSignature(
                "exchange(uint256,uint256,uint256,uint256,bool,address)",
                _sellTokenIndex,
                _buyTokenIndex,
                sellAmount,
                minAmount,
                useEth,
                recipient
            );
        } else if (selector == CurveExchangeSelectors.xa6417ed6) {
            callData = abi.encodeWithSignature(
                "exchange_underlying(int128,int128,uint256,uint256)",
                sellTokenIndex,
                buyTokenIndex,
                sellAmount,
                minAmount
            );
        } else if (selector == CurveExchangeSelectors.x44ee1986) {
            callData = abi.encodeWithSignature(
                "exchange_underlying(int128,int128,uint256,uint256,address)",
                sellTokenIndex,
                buyTokenIndex,
                sellAmount,
                minAmount,
                recipient
            );
        } else if (selector == CurveExchangeSelectors.x65b2489b) {
            uint256 _sellTokenIndex = uint256(uint128(sellTokenIndex));
            uint256 _buyTokenIndex = uint256(uint128(buyTokenIndex));
            callData = abi.encodeWithSignature(
                "exchange_underlying(uint256,uint256,uint256,uint256)",
                _sellTokenIndex,
                _buyTokenIndex,
                sellAmount,
                minAmount
            );
        } else if (selector == CurveExchangeSelectors.xe2ad025a) {
            uint256 _sellTokenIndex = uint256(uint128(sellTokenIndex));
            uint256 _buyTokenIndex = uint256(uint128(buyTokenIndex));
            callData = abi.encodeWithSignature(
                "exchange_underlying(uint256,uint256,uint256,uint256,address)",
                _sellTokenIndex,
                _buyTokenIndex,
                sellAmount,
                minAmount,
                recipient
            );
        } else {
            revert("!undefined");
        }

        (bool success,) = executer.call{value: ethValue}(callData);

        require(success, "!exchange");

        uint256 endBalance = getBalance(buyToken, recipient);

        buyAmount = endBalance - startBalance;
    }

    function curveRemoveLiquidity(
        CurveRemoveLiquiditySelectors selector,
        address executer,
        address pool,
        int128 tokenIndex,
        uint256 sellAmount,
        address buyToken,
        address payable recipient,
        uint256 minAmount
    ) external payable returns (uint256 buyAmount) {
        uint256 startBalance = getBalance(buyToken, recipient);
        bool useEth = buyToken == NATIVE;
        bytes memory callData;
        if (selector == CurveRemoveLiquiditySelectors.x29ed2862) {
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(address,uint256,int128,uint256)", pool, sellAmount, tokenIndex, minAmount
            );
        } else if (selector == CurveRemoveLiquiditySelectors.x1e700cbb) {
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(address,uint256,int128,uint256,address)",
                pool,
                sellAmount,
                tokenIndex,
                minAmount,
                recipient
            );
        } else if (selector == CurveRemoveLiquiditySelectors.xc5bdcd09) {
            uint256 _tokenIndex = uint256(uint128(tokenIndex));
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(address,uint256,uint256,uint256)", pool, sellAmount, _tokenIndex, minAmount
            );
        } else if (selector == CurveRemoveLiquiditySelectors.xd6943525) {
            uint256 _tokenIndex = uint256(uint128(tokenIndex));
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(address,uint256,uint256,uint256,bool)",
                pool,
                sellAmount,
                _tokenIndex,
                minAmount,
                useEth
            );
        } else if (selector == CurveRemoveLiquiditySelectors.x0664b693) {
            uint256 _tokenIndex = uint256(uint128(tokenIndex));
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(address,uint256,uint256,uint256,bool,address)",
                pool,
                sellAmount,
                _tokenIndex,
                minAmount,
                useEth,
                recipient
            );
        } else if (selector == CurveRemoveLiquiditySelectors.x1a4d01d2) {
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,int128,uint256)", sellAmount, tokenIndex, minAmount
            );
        } else if (selector == CurveRemoveLiquiditySelectors.x081579a5) {
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,int128,uint256,address)",
                sellAmount,
                tokenIndex,
                minAmount,
                recipient
            );
        } else if (selector == CurveRemoveLiquiditySelectors.x517a55a3) {
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,int128,uint256,bool)", sellAmount, tokenIndex, minAmount, useEth
            );
        } else if (selector == CurveRemoveLiquiditySelectors.xf1dc3cc9) {
            uint256 _tokenIndex = uint256(uint128(tokenIndex));
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,uint256,uint256)", sellAmount, _tokenIndex, minAmount
            );
        } else if (selector == CurveRemoveLiquiditySelectors.x0fbcee6e) {
            uint256 _tokenIndex = uint256(uint128(tokenIndex));
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,uint256,uint256,address)",
                sellAmount,
                _tokenIndex,
                minAmount,
                recipient
            );
        } else if (selector == CurveRemoveLiquiditySelectors.x8f15b6b5) {
            uint256 _tokenIndex = uint256(uint128(tokenIndex));
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,uint256,uint256,bool)", sellAmount, _tokenIndex, minAmount, useEth
            );
        } else if (selector == CurveRemoveLiquiditySelectors.x07329bcd) {
            uint256 _tokenIndex = uint256(uint128(tokenIndex));
            callData = abi.encodeWithSignature(
                "remove_liquidity_one_coin(uint256,uint256,uint256,bool,address)",
                sellAmount,
                _tokenIndex,
                minAmount,
                useEth,
                recipient
            );
        } else {
            revert("!undefined");
        }

        (bool success,) = executer.call(callData);

        require(success, "!remove_liquidity");

        uint256 endBalance = getBalance(buyToken, recipient);

        buyAmount = endBalance - startBalance;
    }

    function curveAddLiquidity(
        CurveAddLiquiditySelectors selector,
        uint256 ethValue,
        address executer,
        address pool,
        uint256 tokenIndex,
        uint256 tokenNumber,
        uint256 sellAmount,
        address buyToken,
        address payable recipient,
        uint256 minAmount
    ) external payable returns (uint256 buyAmount) {
        uint256 startBalance = getBalance(buyToken, recipient);
        bool useEth = ethValue > 0;
        bytes memory callData;
        if (selector == CurveAddLiquiditySelectors.xa3185179) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature("add_liquidity(address,uint256[3],uint256)", pool, amounts, minAmount);
        } else if (selector == CurveAddLiquiditySelectors.xe07a1036) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature(
                "add_liquidity(address,uint256[3],uint256,address)", pool, amounts, minAmount, recipient
            );
        } else if (selector == CurveAddLiquiditySelectors.x2ddd67cf) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature(
                "add_liquidity(address,uint256[3],uint256,bool)", pool, amounts, minAmount, useEth
            );
        } else if (selector == CurveAddLiquiditySelectors.x5507c9c4) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature(
                "add_liquidity(address,uint256[3],uint256,bool,address)", pool, amounts, minAmount, useEth, recipient
            );
        } else if (selector == CurveAddLiquiditySelectors.x384e03db) {
            uint256[4] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature("add_liquidity(address,uint256[4],uint256)", pool, amounts, minAmount);
        } else if (selector == CurveAddLiquiditySelectors.xd0b951e8) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature(
                "add_liquidity(address,uint256[4],uint256,address)", pool, amounts, minAmount, recipient
            );
        } else if (selector == CurveAddLiquiditySelectors.xc45d79e9) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature(
                "add_liquidity(address,uint256[4],uint256,bool)", pool, amounts, minAmount, useEth
            );
        } else if (selector == CurveAddLiquiditySelectors.x968fe83b) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature(
                "add_liquidity(address,uint256[4],uint256,bool,address)", pool, amounts, minAmount, useEth, recipient
            );
        } else if (selector == CurveAddLiquiditySelectors.xfd9de631) {
            uint256[] memory amounts = new uint256[](tokenNumber);
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature("add_liquidity(address,uint256[],uint256)", pool, amounts, minAmount);
        } else if (selector == CurveAddLiquiditySelectors.x9a01e4d2) {
            uint256[] memory amounts = new uint256[](tokenNumber);
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature(
                "add_liquidity(address,uint256[],uint256,address)", pool, amounts, minAmount, recipient
            );
        } else if (selector == CurveAddLiquiditySelectors.x0b4c7e4d) {
            uint256[2] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature("add_liquidity(uint256[2],uint256)", amounts, minAmount);
        } else if (selector == CurveAddLiquiditySelectors.x0c3e4b54) {
            uint256[2] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData =
                abi.encodeWithSignature("add_liquidity(uint256[2],uint256,address)", amounts, minAmount, recipient);
        } else if (selector == CurveAddLiquiditySelectors.xee22be23) {
            uint256[2] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature("add_liquidity(uint256[2],uint256,bool)", amounts, minAmount, useEth);
        } else if (selector == CurveAddLiquiditySelectors.x7328333b) {
            uint256[2] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature(
                "add_liquidity(uint256[2],uint256,bool,address)", amounts, minAmount, useEth, recipient
            );
        } else if (selector == CurveAddLiquiditySelectors.x4515cef3) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature("add_liquidity(uint256[3],uint256)", amounts, minAmount);
        } else if (selector == CurveAddLiquiditySelectors.x75b96abc) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData =
                abi.encodeWithSignature("add_liquidity(uint256[3],uint256,address)", amounts, minAmount, recipient);
        } else if (selector == CurveAddLiquiditySelectors.x2b6e993a) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature("add_liquidity(uint256[3],uint256,bool)", amounts, minAmount, useEth);
        } else if (selector == CurveAddLiquiditySelectors.x5cecb5f7) {
            uint256[3] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature(
                "add_liquidity(uint256[3],uint256,bool,address)", amounts, minAmount, useEth, recipient
            );
        } else if (selector == CurveAddLiquiditySelectors.x029b2f34) {
            uint256[4] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature("add_liquidity(uint256[4],uint256)", amounts, minAmount);
        } else if (selector == CurveAddLiquiditySelectors.xcb495064) {
            uint256[4] memory amounts;
            amounts[tokenIndex] = sellAmount;
            callData =
                abi.encodeWithSignature("add_liquidity(uint256[4],uint256,address)", amounts, minAmount, recipient);
        } else if (selector == CurveAddLiquiditySelectors.xb72df5de) {
            uint256[] memory amounts = new uint256[](tokenNumber);
            amounts[tokenIndex] = sellAmount;
            callData = abi.encodeWithSignature("add_liquidity(uint256[],uint256)", amounts, minAmount);
        } else if (selector == CurveAddLiquiditySelectors.xa7256d09) {
            uint256[] memory amounts = new uint256[](tokenNumber);
            amounts[tokenIndex] = sellAmount;
            callData =
                abi.encodeWithSignature("add_liquidity(uint256[],uint256,address)", amounts, minAmount, recipient);
        } else {
            revert("!undefined");
        }

        (bool success,) = executer.call{value: ethValue}(callData);

        require(success, "!add_liquidity");

        uint256 endBalance = getBalance(buyToken, recipient);

        buyAmount = endBalance - startBalance;
    }
}
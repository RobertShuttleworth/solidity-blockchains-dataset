// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import './contracts_interface_ISwapRouter.sol';
import './contracts_library_ETHAndERC20.sol';
import './contracts_ProtocolFeeManager_ProtocolFeeManagerStorage.sol';

contract ProtocolFeeManagerImplementationArbitrum is ProtocolFeeManagerStorage {

    using ETHAndERC20 for address;

    address public constant USDCE = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address public constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public constant DERI = 0x21E60EE73F17AC0A411ae5D690f908c3ED66Fe12;
    address public constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant swapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant l2GatewayRouter = 0x5288c571Fd7aD117beA99bF60FE0846C4E84F933;
    address public constant L1_DERI = 0xA487bF43cF3b10dffc97A9A744cbB7036965d3b9;
    address public constant L1_DEADLOCK = 0x000000000000000000000000000000000000dEaD;

    modifier _onlyOperator_() {
        require(isOperator[msg.sender], 'Only Operator');
        _;
    }

    function setOperator(address operator_, bool isActive) external _onlyAdmin_ {
        isOperator[operator_] = isActive;
    }

    function approveSwapRouter() external _onlyAdmin_ {
        USDCE.approveMax(swapRouter);
        USDC.approveMax(swapRouter);
    }

    function buyDeriForBurn(address asset, uint256 amount, uint256 minDeriAmount) external _onlyOperator_ {
        require(amount > 0, 'amount = 0');
        require(asset.balanceOfThis() >= amount, 'Insufficient amount');

        bytes memory path = asset == address(1)
            ? abi.encodePacked(WETH, uint24(3000), DERI)
            : abi.encodePacked(asset, uint24(500), WETH, uint24(3000), DERI);

        ISwapRouter(swapRouter).exactInput{value: asset == address(1) ? amount : 0}(
            ISwapRouter.ExactInputParams({
                path: path,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: minDeriAmount
            })
        );
    }

    function burn() external _onlyOperator_ {
        uint256 balance = DERI.balanceOfThis();
        if (balance > 0) {
            IL2GatewayRouter(l2GatewayRouter).outboundTransfer(
                L1_DERI,
                L1_DEADLOCK,
                balance,
                ''
            );
        }
    }

    function claim(address to, uint256 amount) external _onlyAdmin_ {
        require(USDC.balanceOfThis() >= amount, 'Insufficient balance');
        USDC.transferOut(to, amount);
    }

}

interface IL2GatewayRouter {
    function outboundTransfer(
        address _l1Token,
        address _to,
        uint256 _amount,
        bytes calldata _data
    ) external payable returns (bytes memory);
}
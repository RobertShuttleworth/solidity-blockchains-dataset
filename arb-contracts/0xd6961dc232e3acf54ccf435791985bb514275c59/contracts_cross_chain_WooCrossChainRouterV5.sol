// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import {Pausable} from "./openzeppelin_contracts_utils_Pausable.sol";
import {ReentrancyGuard} from "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

import {IStargate, Ticket, MessagingFee} from "./stargatefinance_stg-evm-v2_src_interfaces_IStargate.sol";
import {MessagingFee, OFTReceipt, SendParam} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oft_interfaces_IOFT.sol";
import {OFTComposeMsgCodec} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oft_libs_OFTComposeMsgCodec.sol";
import {OptionsBuilder} from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_libs_OptionsBuilder.sol";
import {ILayerZeroComposer} from "./layerzerolabs_lz-evm-protocol-v2_contracts_interfaces_ILayerZeroComposer.sol";

import {IWETH} from "./contracts_interfaces_IWETH.sol";
import {IWooCrossChainRouterV5} from "./contracts_interfaces_cross_chain_IWooCrossChainRouterV5.sol";
import {IWooRouterV2} from "./contracts_interfaces_IWooRouterV2.sol";
import {ISgInfoV2} from "./contracts_interfaces_cross_chain_ISgInfoV2.sol";

import {TransferHelper} from "./uniswap_v3-periphery_contracts_libraries_TransferHelper.sol";


/// @title Cross chain router implementation, version 5.
/// @notice V5: Stargate V2 and support both Odos and 1inch
contract WooCrossChainRouterV5 is IWooCrossChainRouterV5, Ownable, Pausable, ReentrancyGuard, ILayerZeroComposer {

    using OptionsBuilder for bytes;

    /* ----- Constants ----- */

    address public constant ETH_PLACEHOLDER_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /* ----- Variables ----- */

    IWooRouterV2 public wooRouter;
    ISgInfoV2 public sgInfo;

    address public immutable weth;
    address public feeAddr;
    uint256 public bridgeSlippage; // 1 in 10000th: default 1%

    uint16 public srcExternalFeeRate; // unit: 0.1 bps (1e6 = 100%, 25 = 2.5 bps)
    uint16 public dstExternalFeeRate; // unit: 0.1 bps (1e6 = 100%, 25 = 2.5 bps)
    uint256 public constant FEE_BASE = 1e5;

    mapping(uint32 => address) public wooCrossRouters; // eid => WooCrossChainRouterV5 address

    receive() external payable {}

    constructor(
        address _owner,
        address _weth,
        address _wooRouter,
        address _sgInfo
    ) Ownable(_owner) {
        weth = _weth;
        wooRouter = IWooRouterV2(_wooRouter);
        sgInfo = ISgInfoV2(_sgInfo);

        bridgeSlippage = 100;

        srcExternalFeeRate = 25;
        dstExternalFeeRate = 25;
    }

    /* ----- Functions ----- */

    function crossSwap(
        uint256 refId,
        address payable to,
        SrcInfos memory srcInfos,
        DstInfos calldata dstInfos,
        SrcExtSwapInfo calldata srcExtSwapInfo,
        DstExtSwapInfo calldata dstExtSwapInfo
    ) external payable whenNotPaused nonReentrant {
        require(to != address(0), "WooCrossChainRouterV5: !to");
        require(srcInfos.fromToken != address(0), "WooCrossChainRouterV5: !srcInfos.fromToken");
        require(
            dstInfos.toToken != address(0) && dstInfos.toToken != sgInfo.sgETHs(dstInfos.dstEid),
            "WooCrossChainRouterV5: !dstInfos.toToken"
        );
        require(
            sgInfo.stargates(sgInfo.sgEidLocal(), srcInfos.bridgeToken) != address(0),
            "WooCrossChainRouterV5: !srcInfos.bridgeToken"
        );

        uint256 msgValue = msg.value;
        uint256 bridgeAmount;
        uint256 fee = 0;

        {
            // Step 1: transfer
            if (srcInfos.fromToken == ETH_PLACEHOLDER_ADDR) {
                require(srcInfos.fromAmount <= msgValue, "WooCrossChainRouterV5: !srcInfos.fromAmount");
                srcInfos.fromToken = weth;
                IWETH(weth).deposit{value: srcInfos.fromAmount}(); // TODO: may not need in STG V2
                msgValue -= srcInfos.fromAmount;
            } else {
                TransferHelper.safeTransferFrom(srcInfos.fromToken, msg.sender, address(this), srcInfos.fromAmount);
            }

            // Step 2: local swap by 1inch router
            if (srcInfos.fromToken != srcInfos.bridgeToken) {
                TransferHelper.safeApprove(srcInfos.fromToken, address(wooRouter), srcInfos.fromAmount);
                if (srcExtSwapInfo.swapRouter != address(0)) {
                    // external swap via 1inch
                    bridgeAmount = wooRouter.externalSwap(
                        srcExtSwapInfo.swapRouter,
                        srcExtSwapInfo.swapRouter,
                        srcInfos.fromToken,
                        srcInfos.bridgeToken,
                        srcInfos.fromAmount,
                        srcInfos.minBridgeAmount,
                        payable(address(this)),
                        srcExtSwapInfo.data
                    );
                    fee = (bridgeAmount * srcExternalFeeRate) / FEE_BASE;
                } else {
                    // swap via WOOFi
                    bridgeAmount = wooRouter.swap(
                        srcInfos.fromToken,
                        srcInfos.bridgeToken,
                        srcInfos.fromAmount,
                        srcInfos.minBridgeAmount,
                        payable(address(this)),
                        to
                    );
                }
            } else {
                require(
                    srcInfos.fromAmount == srcInfos.minBridgeAmount,
                    "WooCrossChainRouterV5: !srcInfos.minBridgeAmount"
                );
                bridgeAmount = srcInfos.fromAmount;
            }

            require(
                bridgeAmount <= IERC20(srcInfos.bridgeToken).balanceOf(address(this)),
                "WooCrossChainRouterV5: !bridgeAmount"
            );
        }

        // Step 3: deduct the swap fee
        bridgeAmount -= fee;
        require(bridgeAmount >= srcInfos.minBridgeAmount, "WooCrossChainRouterV5: !srcInfos.minBridgeAmount");

        // Step 4: cross chain swap by StargateRouterV2
        _bridgeByStargateV2(refId, to, msgValue, bridgeAmount, srcInfos, dstInfos, dstExtSwapInfo);

        emit WooCrossSwapOnSrcChain(
            refId,
            _msgSender(),
            to,
            srcInfos.fromToken,
            srcInfos.fromAmount,
            srcInfos.bridgeToken,
            srcInfos.minBridgeAmount,
            bridgeAmount,
            srcExtSwapInfo.swapRouter == address(0) ? 0 : 1,
            fee
        );
    }

    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        uint32 eidLocal = sgInfo.sgEidLocal();
        require(msg.sender == sgInfo.endpoints(eidLocal), "WooCrossChainRouterV5: INVALID_CALLER");

        uint256 amountLD = OFTComposeMsgCodec.amountLD(_message);

        // NOTE: make sure the same order to abi.encode when decode payload
        (uint256 refId, address to, address bridgedToken, address toToken, uint256 minToAmount, DstExtSwapInfo memory dstExtSwapInfo) = abi.decode(
            OFTComposeMsgCodec.composeMsg(_message),
            (uint256, address, address, address, uint256, DstExtSwapInfo)
        );

        require(_from == sgInfo.stargates(eidLocal, bridgedToken), "WooCrossChainRouterV5: !_from_stargate");

        if (bridgedToken == ETH_PLACEHOLDER_ADDR) {
            _handleNativeReceived(refId, to, toToken, amountLD, minToAmount, dstExtSwapInfo);
        } else {
            _handleERC20Received(refId, to, toToken, bridgedToken, amountLD, minToAmount, dstExtSwapInfo);
        }
    }

    function quoteLayerZeroFee(
        uint256 refId,
        address to,
        SrcInfos calldata srcInfos,
        DstInfos calldata dstInfos,
        DstExtSwapInfo calldata dstExtSwapInfo
    ) external view returns (uint256, uint256) {
        bytes memory composeMsg = abi.encode(
            refId, to, dstInfos.bridgeToken, dstInfos.toToken, dstInfos.minToAmount, dstExtSwapInfo);

        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzComposeOption(
            0, // _index: The index for the lzCompose() function call.
            dstInfos.dstGasForCall, // _gas The gasLimit for the lzCompose() function call.
            dstInfos.airdropNativeAmount // _value The msg.value for the lzCompose() function call.
        );

        SendParam memory _sendParam = SendParam({
            dstEid: dstInfos.dstEid,
            to: _addressToBytes32(wooCrossRouters[dstInfos.dstEid]),
            amountLD: srcInfos.fromAmount,
            minAmountLD: srcInfos.minBridgeAmount,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: ""
        });

        IStargate stargateRouter = IStargate(sgInfo.stargates(sgInfo.sgEidLocal(), srcInfos.bridgeToken));
        MessagingFee memory fee = stargateRouter.quoteSend(_sendParam, false);
        return (fee.nativeFee, fee.lzTokenFee);
    }

    /// @dev OKAY to be public method
    function claimFee(address token) external nonReentrant {
        require(feeAddr != address(0), "WooCrossChainRouterV5: !feeAddr");
        uint256 amount = _generalBalanceOf(token, address(this));
        if (amount > 0) {
            if (token == ETH_PLACEHOLDER_ADDR) {
                TransferHelper.safeTransferETH(feeAddr, amount);
            } else {
                TransferHelper.safeTransfer(token, feeAddr, amount);
            }
        }
    }

    function _bridgeByStargateV2(
        uint256 refId,
        address payable to,
        uint256 msgValue,
        uint256 bridgeAmount,
        SrcInfos memory srcInfos,
        DstInfos calldata dstInfos,
        DstExtSwapInfo calldata dstExtSwapInfo
    ) internal {
        // compose payload
        bytes memory composeMsg = abi.encode(
            refId, to, dstInfos.bridgeToken, dstInfos.toToken, dstInfos.minToAmount, dstExtSwapInfo);

        uint256 dstMinBridgeAmount = (bridgeAmount * (10000 - bridgeSlippage)) / 10000;
        address _dstWooCrossChainRouter = wooCrossRouters[dstInfos.dstEid];

        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzComposeOption(
            0, // _index: The index for the lzCompose() function call.
            dstInfos.dstGasForCall, // _gas The gasLimit for the lzCompose() function call.
            dstInfos.airdropNativeAmount // _value The msg.value for the lzCompose() function call.
        );

        IStargate stargate = IStargate(sgInfo.stargates(sgInfo.sgEidLocal(), srcInfos.bridgeToken));

        if (srcInfos.bridgeToken == weth) {
            IWETH(weth).withdraw(bridgeAmount);
            msgValue += bridgeAmount; // TODO: double check in Stargate V2
        } else {
            TransferHelper.safeApprove(srcInfos.bridgeToken, address(stargate), bridgeAmount);
        }

        // TODO: remove this part after code review
        //
        // stargateRouter.swap{value: msgValue}(
        //     dstInfos.chainId, // dst chain id
        //     sgInfo.sgPoolIds(sgInfo.sgChainIdLocal(), srcInfos.bridgeToken), // bridge token's pool id on src chain
        //     sgInfo.sgPoolIds(dstInfos.chainId, dstInfos.bridgeToken), // bridge token's pool id on dst chain
        //     payable(tx.origin), // rebate address
        //     bridgeAmount, // swap amount on src chain
        //     dstMinBridgeAmount, // min received amount on dst chain
        //     obj, // config: dstGasForCall, dstAirdropNativeAmount, dstReceiveAirdropNativeTokenAddr
        //     dstWooCrossChainRouter, // smart contract to call on dst chain
        //     payload // payload to piggyback
        // );

        SendParam memory _sendParam = SendParam({
            dstEid: dstInfos.dstEid,
            to: _addressToBytes32(_dstWooCrossChainRouter),
            amountLD: srcInfos.fromAmount,
            minAmountLD: dstMinBridgeAmount,
            extraOptions: extraOptions,
            composeMsg: composeMsg,
            oftCmd: ""
        });

        MessagingFee memory messagingFee = stargate.quoteSend(_sendParam, false);
        IStargate(stargate)
            .send{value: msgValue}(
                _sendParam,
                messagingFee,
                payable(tx.origin)
            );
    }

    function _handleNativeReceived(
        uint256 refId,
        address to,
        address toToken,
        uint256 bridgedAmount,
        uint256 minToAmount,
        DstExtSwapInfo memory dstExtSwapInfo
    ) internal {
        address msgSender = _msgSender();

        if (toToken == ETH_PLACEHOLDER_ADDR) {
            // Directly transfer ETH
            TransferHelper.safeTransferETH(to, bridgedAmount);
            emit WooCrossSwapOnDstChain(
                refId,
                msgSender,
                to,
                weth,
                bridgedAmount,
                toToken,
                ETH_PLACEHOLDER_ADDR,
                minToAmount,
                bridgedAmount,
                dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                0
            );
            return;
        }

        IWETH(weth).deposit{value: bridgedAmount}();

        if (toToken == weth) {
            // Directly transfer WETH
            TransferHelper.safeTransfer(weth, to, bridgedAmount);
            emit WooCrossSwapOnDstChain(
                refId,
                msgSender,
                to,
                weth,
                bridgedAmount,
                toToken,
                weth,
                minToAmount,
                bridgedAmount,
                dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                0
            );
            return;
        }

        if (dstExtSwapInfo.swapRouter != address(0)) {
            uint256 fee = (bridgedAmount * dstExternalFeeRate) / FEE_BASE;
            uint256 swapAmount = bridgedAmount - fee;
            TransferHelper.safeApprove(weth, address(wooRouter), swapAmount);
            try
                wooRouter.externalSwap(
                    dstExtSwapInfo.swapRouter,
                    dstExtSwapInfo.swapRouter,
                    weth,
                    toToken,
                    swapAmount,
                    minToAmount,
                    payable(to),
                    dstExtSwapInfo.data
                )
            returns (uint256 realToAmount) {
                emit WooCrossSwapOnDstChain(
                    refId,
                    msgSender,
                    to,
                    weth,
                    swapAmount,
                    toToken,
                    toToken,
                    minToAmount,
                    realToAmount,
                    dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                    fee
                );
            } catch {
                TransferHelper.safeApprove(weth, address(wooRouter), 0);
                TransferHelper.safeTransfer(weth, to, bridgedAmount);
                emit WooCrossSwapOnDstChain(
                    refId,
                    msgSender,
                    to,
                    weth,
                    bridgedAmount,
                    toToken,
                    weth,
                    minToAmount,
                    bridgedAmount,
                    dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                    0
                );
            }
        } else {
            TransferHelper.safeApprove(weth, address(wooRouter), bridgedAmount);
            try wooRouter.swap(weth, toToken, bridgedAmount, minToAmount, payable(to), to) returns (
                uint256 realToAmount
            ) {
                emit WooCrossSwapOnDstChain(
                    refId,
                    msgSender,
                    to,
                    weth,
                    bridgedAmount,
                    toToken,
                    toToken,
                    minToAmount,
                    realToAmount,
                    dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                    0
                );
            } catch {
                TransferHelper.safeApprove(weth, address(wooRouter), 0);
                TransferHelper.safeTransfer(weth, to, bridgedAmount);
                emit WooCrossSwapOnDstChain(
                    refId,
                    msgSender,
                    to,
                    weth,
                    bridgedAmount,
                    toToken,
                    weth,
                    minToAmount,
                    bridgedAmount,
                    dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                    0
                );
            }
        }
    }

    function _handleERC20Received(
        uint256 refId,
        address to,
        address toToken,
        address bridgedToken,
        uint256 bridgedAmount,
        uint256 minToAmount,
        DstExtSwapInfo memory dstExtSwapInfo
    ) internal {
        address msgSender = _msgSender();

        if (toToken == bridgedToken) {
            TransferHelper.safeTransfer(bridgedToken, to, bridgedAmount);
            emit WooCrossSwapOnDstChain(
                refId,
                msgSender,
                to,
                bridgedToken,
                bridgedAmount,
                toToken,
                toToken,
                minToAmount,
                bridgedAmount,
                dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                0
            );
        } else {
            if (dstExtSwapInfo.swapRouter != address(0)) {
                uint256 fee = (bridgedAmount * dstExternalFeeRate) / FEE_BASE;
                bridgedAmount -= fee;
                TransferHelper.safeApprove(bridgedToken, address(wooRouter), bridgedAmount);
                try
                    wooRouter.externalSwap(
                        dstExtSwapInfo.swapRouter,
                        dstExtSwapInfo.swapRouter,
                        bridgedToken,
                        toToken,
                        bridgedAmount,
                        minToAmount,
                        payable(to),
                        dstExtSwapInfo.data
                    )
                returns (uint256 realToAmount) {
                    emit WooCrossSwapOnDstChain(
                        refId,
                        msgSender,
                        to,
                        bridgedToken,
                        bridgedAmount,
                        toToken,
                        toToken,
                        minToAmount,
                        realToAmount,
                        dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                        fee
                    );
                } catch {
                    TransferHelper.safeApprove(bridgedToken, address(wooRouter), 0);
                    bridgedAmount += fee;
                    TransferHelper.safeTransfer(bridgedToken, to, bridgedAmount);
                    emit WooCrossSwapOnDstChain(
                        refId,
                        msgSender,
                        to,
                        bridgedToken,
                        bridgedAmount,
                        toToken,
                        bridgedToken,
                        minToAmount,
                        bridgedAmount,
                        dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                        0
                    );
                }
            } else {
                TransferHelper.safeApprove(bridgedToken, address(wooRouter), bridgedAmount);
                try wooRouter.swap(bridgedToken, toToken, bridgedAmount, minToAmount, payable(to), to) returns (
                    uint256 realToAmount
                ) {
                    emit WooCrossSwapOnDstChain(
                        refId,
                        msgSender,
                        to,
                        bridgedToken,
                        bridgedAmount,
                        toToken,
                        toToken,
                        minToAmount,
                        realToAmount,
                        dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                        0
                    );
                } catch {
                    TransferHelper.safeApprove(bridgedToken, address(wooRouter), 0);
                    TransferHelper.safeTransfer(bridgedToken, to, bridgedAmount);
                    emit WooCrossSwapOnDstChain(
                        refId,
                        msgSender,
                        to,
                        bridgedToken,
                        bridgedAmount,
                        toToken,
                        bridgedToken,
                        minToAmount,
                        bridgedAmount,
                        dstExtSwapInfo.swapRouter == address(0) ? 0 : 1,
                        0
                    );
                }
            }
        }
    }

    function _generalBalanceOf(address token, address who) internal view returns (uint256) {
        return token == ETH_PLACEHOLDER_ADDR ? who.balance : IERC20(token).balanceOf(who);
    }

    function _addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    /* ----- Owner & Admin Functions ----- */

    function setFeeAddr(address _feeAddr) external onlyOwner {
        feeAddr = _feeAddr;
    }

    function setWooRouter(address _wooRouter) external onlyOwner {
        require(_wooRouter != address(0), "WooCrossChainRouterV5: !_wooRouter");
        wooRouter = IWooRouterV2(_wooRouter);
    }

    function setBridgeSlippage(uint256 _bridgeSlippage) external onlyOwner {
        require(_bridgeSlippage <= 10000, "WooCrossChainRouterV5: !_bridgeSlippage");
        bridgeSlippage = _bridgeSlippage;
    }

    function setWooCrossRouter(uint32 _eid, address _crossRouter) external onlyOwner {
        require(_crossRouter != address(0), "WooCrossChainRouterV5: !_crossRouter");
        wooCrossRouters[_eid] = _crossRouter;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function inCaseTokenGotStuck(address stuckToken) external onlyOwner {
        if (stuckToken == ETH_PLACEHOLDER_ADDR) {
            TransferHelper.safeTransferETH(msg.sender, address(this).balance);
        } else {
            uint256 amount = IERC20(stuckToken).balanceOf(address(this));
            TransferHelper.safeTransfer(stuckToken, msg.sender, amount);
        }
    }
}
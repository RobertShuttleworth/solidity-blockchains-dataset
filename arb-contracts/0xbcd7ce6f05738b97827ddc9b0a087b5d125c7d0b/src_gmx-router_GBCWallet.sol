// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Initializable} from "./node_modules_openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {OwnableUpgradeable} from "./node_modules_openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import {IERC20} from "./node_modules_openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./node_modules_openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {Address} from "./node_modules_openzeppelin_contracts_utils_Address.sol";

import {IGMXRouter} from "./src_types_IGMXRouter.sol";
import {IGBCRouter} from "./src_types_IGBCRouter.sol";

/// @custom:oz-upgrades-from GBCWalletV1
contract GBCWallet is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    IGBCRouter public router;

    modifier onlyRouter() {
        require(
            msg.sender == address(router),
            "GBCWallet: Only router can call this function"
        );
        _;
    }

    receive() external payable {}

    function initialize(
        address walletOwner,
        address _router
    ) public initializer {
        __Ownable_init(walletOwner);
        router = IGBCRouter(_router);
    }

    function deposit(
        bytes[] calldata data,
        bool isGlv
    ) external payable onlyRouter {
        address targetRouter = isGlv
            ? router.getGlvRouter()
            : router.getExchangeRouter();

        IGMXRouter(targetRouter).multicall{value: msg.value}(data);
    }

    function withdraw(
        bytes[] calldata data,
        bool isGlv,
        address lpToken
    ) external payable onlyRouter returns (uint256 lpAmount, uint256 fee) {
        address targetRouter = isGlv
            ? router.getGlvRouter()
            : router.getExchangeRouter();

        uint256 amountBefore = IERC20(lpToken).balanceOf(address(this));

        IGMXRouter(targetRouter).multicall{value: msg.value}(data);

        uint256 amountAfter = IERC20(lpToken).balanceOf(address(this));

        lpAmount = amountBefore - amountAfter;

        if (router.getWithdrawalFees().feeNumerator > 0) {
            fee =
                (lpAmount * router.getWithdrawalFees().feeNumerator) /
                (router.getWithdrawalFees().feeDenominator -
                    router.getWithdrawalFees().feeNumerator);

            IERC20(lpToken).safeTransfer(router.getFeeReceiver(), fee);
        }
    }

    function withdrawToken(address token, uint256 amount) external onlyOwner {
        require(token != address(0), "GBCWallet: Token cannot be address zero");
        require(amount > 0, "GBCWallet: Amount should be higher than zero");

        IERC20(token).safeTransfer(msg.sender, amount);
    }

    function withdrawEther(uint256 amount) external onlyOwner {
        require(amount > 0, "GBCWallet: Amount should be higher than zero");

        Address.sendValue(payable(msg.sender), amount);
    }

    function approve(
        address token,
        address spender,
        uint256 amount
    ) external onlyRouter {
        IERC20(token).approve(spender, amount);
    }

    function getBalance() external view onlyOwner returns (uint256) {}
}
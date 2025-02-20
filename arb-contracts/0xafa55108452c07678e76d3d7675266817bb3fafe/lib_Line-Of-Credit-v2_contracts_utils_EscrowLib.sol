// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {Denominations} from "./lib_chainlink_contracts_src_v0.8_Denominations.sol";
import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {IOracle} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOracle.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {ISpigotedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigotedLine.sol";
import {ISpigot} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigot.sol";
import {IEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrow.sol";
import {IOTC} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOTC.sol";
import {CreditLib} from "./lib_Line-Of-Credit-v2_contracts_utils_CreditLib.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";

struct EscrowState {
    address owner;
    address[] collateralTokens;
    /// if lenders allow token as collateral. ensures uniqueness in collateralTokens
    mapping(address => bool) enabledTokens;
    /// tokens used as collateral (must be able to value with oracle)
    mapping(address => IEscrow.Deposit) deposited;
    mapping(bytes32 => bool) enabledPairs;
}

/**
 * @title   - DiscreteDistribution
 * @author  - Credit Cooperative
 * @notice  - Core logic used by Escrow contract.
 */
library EscrowLib {
    using SafeERC20 for IERC20;

    uint256 constant MAX_INT = type(uint256).max;

    event AddCollateral(address indexed token, uint256 indexed amount);
    event RemoveCollateral(address indexed token, uint256 indexed amount);
    event EnableCollateral(address indexed token);
    event Liquidate(address indexed token, uint256 indexed amount);

    error AdminOnly();
    error InvalidZeroAmount();
    error InvalidCollateral();
    error EthSupportDisabled();
    error CallerAccessDenied();
    error UnderCollateralized();
    error NotLiquidatable();
    error InvalidTokenDecimals();

    /**
     * @notice - Iterates over all enabled tokens and calculates the USD value of all deposited collateral
     * @return totalCollateralValue - the collateral's USD value in 8 decimals
     */
    function _getCollateralValue(EscrowState storage self, address oracle) public view returns (uint256) {
        uint256 collateralValue;
        // gas savings
        uint256 length = self.collateralTokens.length;

        IOracle o = IOracle(oracle);
        IEscrow.Deposit memory d;

        for (uint256 i; i < length; ++i) {
            address token = self.collateralTokens[i];

            uint256 unused;

            try ISpigotedLine(self.owner).unused(token) returns (uint256 _unused) {
                unused = _unused;
            } catch {
                unused = 0;
            }
            d = self.deposited[token];
            // new var so we don't override original deposit amount for 4626 tokens
            uint256 deposit = d.amount + unused;
            if (deposit != 0) {
                if (d.isERC4626) {
                    // this conversion could shift, hence it is best to get it each time
                    (bool success, bytes memory assetAmount) =
                        token.staticcall(abi.encodeWithSignature("previewRedeem(uint256)", deposit));
                    if (!success) continue;
                    deposit = abi.decode(assetAmount, (uint256));
                }

                collateralValue += CreditLib.calculateValue(o.getLatestAnswer(d.asset), deposit, d.assetDecimals);
            }
        }
        return collateralValue;
    }

    /**
     * see Escrow.addCollateral
     */
    function addCollateral(EscrowState storage self, uint256 amount, address token) external returns (uint256) {
        if (amount == 0) {
            revert InvalidZeroAmount();
        }
        if (!self.enabledTokens[token]) {
            revert InvalidCollateral();
        }

        LineLib.receiveTokenOrETH(token, msg.sender, amount);

        self.deposited[token].amount += amount;

        emit AddCollateral(token, amount);

        return self.deposited[token].amount;
    }

    /**
     * @notice - Checks if a pair of erc20 tokens is enabled for univ3 collateral
     *     @param token0 - the first token in the pair
     *     @param token1 - the second token in the pair
     *     @return - true if the pair is enabled, false otherwise
     */
    function isValidPair(EscrowState storage self, address token0, address token1, uint24 fee)
        external
        view
        returns (bool)
    {
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);
        return self.enabledPairs[keccak256(abi.encode(tokenA, tokenB, fee))];
    }

    /**
     * see Escrow.enablePairAsCollateral
     */
    function enablePairAsCollateral(EscrowState storage self, address token0, address token1, uint24 fee)
        external
        returns (bytes32 pairKey)
    {
        // Input sanitization
        require(token0 != token1, "Tokens must be different");
        require(token0 != address(0) && token1 != address(0), "Tokens must be valid addresses");

        // Ensure that the tokens are sorted for consistency
        (address tokenA, address tokenB) = token0 < token1 ? (token0, token1) : (token1, token0);

        pairKey = keccak256(abi.encode(tokenA, tokenB, fee));
        self.enabledPairs[pairKey] = true;
    }

    /**
     * see Escrow.enableCollateral
     */
    function enableCollateral(EscrowState storage self, address oracle, address token) external returns (bool) {
        if (token == address(0) || token == Denominations.ETH) {
            revert EthSupportDisabled();
        }

        bool isEnabled = self.enabledTokens[token];
        IEscrow.Deposit memory deposit = self.deposited[token]; // gas savings
        if (!isEnabled) {
            (bool passed, bytes memory tokenAddrBytes) = token.staticcall(abi.encodeWithSignature("asset()"));

            bool is4626 = tokenAddrBytes.length != 0 && passed;
            deposit.isERC4626 = is4626;

            // if 4626 save the underlying token to use for oracle pricing
            deposit.asset = !is4626 ? token : abi.decode(tokenAddrBytes, (address));

            int256 price = IOracle(oracle).getLatestAnswer(deposit.asset);
            if (price <= 0) {
                return false;
            }

            (bool successDecimals, bytes memory decimalBytes) =
                deposit.asset.call(abi.encodeWithSignature("decimals()"));

            if (!successDecimals || decimalBytes.length == 0) {
                return false;
            }
            deposit.assetDecimals = abi.decode(decimalBytes, (uint8));

            // update collateral settings
            self.enabledTokens[token] = true;
            self.deposited[token] = deposit;
            self.collateralTokens.push(token);
            emit EnableCollateral(deposit.asset);
        }

        return true;
    }

    /**
     * see Escrow.releaseCollateral
     */
    function releaseCollateral(EscrowState storage self, address borrower, uint256 amount, address token, address to)
        external
        returns (uint256)
    {
        if (amount == 0) {
            revert InvalidZeroAmount();
        }

        if (
            msg.sender != borrower
                && (
                    !(
                        (
                            msg.sender == ILineOfCredit(self.owner).admin()
                                || ILineOfCredit(self.owner).isServicer(msg.sender)
                        ) && borrower == to
                    )
                )
        ) {
            revert CallerAccessDenied();
        }

        self.deposited[token].amount -= amount;

        LineLib.sendOutTokenOrETH(token, to, amount);

        return self.deposited[token].amount;
    }

    /**
     * see Escrow.getCollateralValue
     */
    function getCollateralValue(EscrowState storage self, address oracle) external view returns (uint256) {
        return _getCollateralValue(self, oracle);
    }

    /**
     * see Escrow.liquidate
     */
    function liquidate(EscrowState storage self, uint256 amount, address token, address to) external returns (bool) {
        if (amount == 0) {
            revert InvalidZeroAmount();
        }
        if (self.deposited[token].amount < amount) {
            revert InvalidCollateral();
        }

        self.deposited[token].amount -= amount;

        LineLib.sendOutTokenOrETH(token, to, amount);

        return true;
    }

    /**
     * see Escrow.updateOwner
     */
    function updateOwner(EscrowState storage self, address _owner) external returns (bool) {
        require(msg.sender == self.owner, "EscrowLib: Only the owner can update the owner");
        self.owner = _owner;
        return true;
    }

    /**
     * see Escrow.operate
     */
    function operate(
        EscrowState storage self,
        mapping(address => bool) storage isContractRegistered,
        mapping(bytes4 => bool) storage whitelistedFunctions,
        address targetContract,
        bytes calldata data
    ) external returns (bool) {
        if (!isContractRegistered[targetContract]) {
            revert IEscrow.UnregisteredContract(targetContract);
        }

        if (!whitelistedFunctions[bytes4(data)]) {
            revert IEscrow.InvalidFunctionSelector();
        }

        (bool success,) = targetContract.call(data);
        require(success, "EscrowLib: operation failed");
    }

    /**
     * see Escrow.sync
     */
    function sync(EscrowState storage self) external returns (bool) {
        uint256 len = self.collateralTokens.length;
        for (uint256 i; i < len; ++i) {
            _syncToken(self, self.collateralTokens[i]);
        }
        return true;
    }

    function _syncToken(EscrowState storage self, address token) internal {
        uint256 balance = LineLib.getBalance(token);
        uint256 accountedBalance = self.deposited[token].amount;

        // if we have more than accounted for, then add to collateral
        if (balance > accountedBalance) {
            uint256 diff = balance - accountedBalance;
            self.deposited[token].amount += diff;
            emit AddCollateral(token, diff);
            // if we have less than accounted for, then remove from claimable tokens first, then collateral
        } else if (balance < accountedBalance) {
            uint256 diff = accountedBalance - balance;
            self.deposited[token].amount -= diff;
            emit RemoveCollateral(token, diff);
        }
    }

    /**
     * see Escrow.otcCheck
     */
    function otcCheck(EscrowState storage self, IOTC.OTC memory otc) external view returns (bool) {
        if (
            otc.tokenGoingOutAmount > self.deposited[otc.tokenGoingOut].amount || !self.enabledTokens[otc.tokenComingIn]
        ) {
            revert InvalidCollateral();
        }
        return true;
    }

    /**
     * see Escrow.isOutstandDebt
     */
    function isOutstandDebt(EscrowState storage self) external returns (bool) {
        ISpigot(address(ISpigotedLine(self.owner).spigot())).hasBeneficiaryDebtOutstanding();
    }
}
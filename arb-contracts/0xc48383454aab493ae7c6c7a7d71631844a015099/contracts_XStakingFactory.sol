// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./contracts_interfaces_IToken.sol";
import "./contracts_interfaces_IXStakingPool.sol";
import "./contracts_interfaces_IXStakingFactory.sol";
import "./node_modules_uniswap_v3-core_contracts_interfaces_IUniswapV3Pool.sol";
import "./node_modules_openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import "./node_modules_openzeppelin_contracts_proxy_beacon_BeaconProxy.sol";
import "./node_modules_openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./node_modules_openzeppelin_contracts_proxy_beacon_UpgradeableBeacon.sol";
import "./node_modules_openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./node_modules_openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol";

/**
 * @title XStakingFactory
 * @dev This contract is used to deploy and manage XStakingPool contracts.
 * It uses an upgradeable beacon pattern for creating pools, allowing for future upgrades.
 * @custom:oz-upgrades-from XStakingFactory
 */
contract XStakingFactory is
    Initializable,
    Ownable2StepUpgradeable,
    IXStakingFactory,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IToken;

    /// @dev 10000 = 100%
    uint256 public constant FEE_DENOMINATOR = 100_00;

    /// @dev 10000 = 100%
    uint256 public constant SLIPPAGE_DENOMINATOR = 1000;

    /// @notice the beacon of BeaconProxy pattern
    UpgradeableBeacon public beacon;

    /// @notice address of smart contract with logic of pool
    IXStakingPool public xstakingPoolImplementation;

    /// @notice address of treasury wallet
    address public treasuryWallet;

    /// @notice records of all deployed staking pools
    address[] public xstakingPools;

    /// @notice the address of USDT
    address[] public depositTokens;

    /// @notice the address of 1inch exchange aggregator
    address public oneInchRouter;

    /// @notice amount of USDT for creation pool
    uint256 public poolCreationFee;

    /// @notice the numerator of staking fee
    uint256 public stakingFeeNumerator;

    /// @notice the numerator of unstaking fee
    uint256 public unstakingFeeNumerator;

    /// @notice the index of deposit token in `depositTokens` array
    mapping(address depositToken => uint256) public depositTokenIndex;

    /// @notice is token is able for depositing
    mapping(address token => bool) public isDepositToken;

    /// @notice is XStakingPool listed
    mapping(address pool => bool) public isXStakingPool;

    struct FeeConfig {
        uint256 from;
        uint256 to;
        uint256 percentage;
        uint256 fixedFee;
    }

    FeeConfig[] public depositFeeConfig;

    FeeConfig[] public withdrawFeeConfig;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the XStakingFactory with a specified XStakingPool implementation.
    /// @dev Sets the initial XStakingPool implementation and creates an upgradeable beacon.
    /// @param _xstakingPoolImplementation Address of the initial XStakingPool implementation.
    /// @param _depositTokens address of base ERC20 token (USDT)
    /// @param _oneInchRouter address of 1inch router aggregator V5
    /// @param _poolCreationFee amount of USDT for pool creation
    /// @param _stakingFeeNumerator the numerator of staking fee
    function initialize(
        address _xstakingPoolImplementation,
        address _treasuryWallet,
        address[] memory _depositTokens,
        address _oneInchRouter,
        uint256 _poolCreationFee,
        uint256 _stakingFeeNumerator,
        uint256 _unstakingFeeNumerator
    ) public initializer {
        require(
            _xstakingPoolImplementation != address(0) &&
                _treasuryWallet != address(0) &&
                _oneInchRouter != address(0),
            "XStakingFactory: Given address is zero-value"
        );

        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        beacon = new UpgradeableBeacon(
            _xstakingPoolImplementation,
            address(this)
        );
        xstakingPoolImplementation = IXStakingPool(_xstakingPoolImplementation);
        treasuryWallet = _treasuryWallet;
        for (uint256 i = 0; i < _depositTokens.length; ) {
            isDepositToken[_depositTokens[i]] = true;
            depositTokenIndex[_depositTokens[i]] = i;
            unchecked {
                i++;
            }
        }

        depositTokens = _depositTokens;

        oneInchRouter = _oneInchRouter;
        poolCreationFee = _poolCreationFee;
        _setStakingFeeNumerator(_stakingFeeNumerator);
        _setUnstakingFeeNumerator(_unstakingFeeNumerator);
    }

    // ------------------------------------------------------------------------
    // OWNER FUNCTIONS

    /// @notice set oneInchRouter address
    /// @dev can be called only by owner
    /// @param _oneInchRouter the address of 1inch router aggregator
    function setOneInchRouter(address _oneInchRouter) public onlyOwner {
        require(
            _oneInchRouter != address(0),
            "XStakingFacroty: oneInchRouter is 0"
        );
        oneInchRouter = _oneInchRouter;
    }

    /// @notice set treasury wallet
    /// @dev can be called only by owner
    function setTreasuryWallet(address _treasuryWallet) public onlyOwner {
        require(
            _treasuryWallet != address(0),
            "XStakingFacroty: treasury wallet is 0"
        );
        treasuryWallet = _treasuryWallet;
    }

    /// @notice sets pool creation fee
    /// @param _poolCreationFee the amount of baseAsset
    function setPoolCreationFee(uint256 _poolCreationFee) public onlyOwner {
        poolCreationFee = _poolCreationFee;
    }

    /// @notice sets staking fee numerator
    /// @dev can be called only by owner
    /// @param _stakingFeeNumerator the numerator of staking fee
    function setStakingFeeNumerator(
        uint256 _stakingFeeNumerator
    ) public onlyOwner {
        _setStakingFeeNumerator(_stakingFeeNumerator);
    }

    function _setStakingFeeNumerator(uint256 _stakingFeeNumerator) internal {
        require(
            _stakingFeeNumerator < FEE_DENOMINATOR,
            "XStakingFacroty: _stakingFeeNumerator >= FEE_DENOMINATOR"
        );
        stakingFeeNumerator = _stakingFeeNumerator;
    }

    /// @notice sets unstaking fee numerator
    /// @dev can be called only by owner
    /// @param _unstakingFeeNumerator the numerator of unstaking fee
    function setUnstakingFeeNumerator(
        uint256 _unstakingFeeNumerator
    ) public onlyOwner {
        _setUnstakingFeeNumerator(_unstakingFeeNumerator);
    }

    function _setUnstakingFeeNumerator(
        uint256 _unstakingFeeNumerator
    ) internal {
        require(
            _unstakingFeeNumerator < FEE_DENOMINATOR,
            "XStakingFacroty: _unstakingFeeNumerator > FEE_DENOMINATOR"
        );
        unstakingFeeNumerator = _unstakingFeeNumerator;
    }

    function setFeesInfo(
        FeeConfig[] calldata fees,
        bool isDeposit
    ) external onlyOwner {
        require(fees.length != 0, "XStakingPool: fees length is 0");

        for (uint256 i = 0; i < fees.length; ) {
            require(
                fees[i].from <= fees[i].to,
                "XStakingPool: fee from should be less than to"
            );
            require(
                fees[i].percentage <= FEE_DENOMINATOR,
                "XStakingPool: percentage should be less than FEE_DENOMINATOR"
            );
            if (fees[i].percentage == 0)
                require(
                    fees[i].fixedFee > 0,
                    "XStakingPool: fixed fee should be greater than 0"
                );
            if (fees[i].percentage != 0)
                require(
                    fees[i].fixedFee == 0,
                    "XStakingPool: fixed fee must be 0"
                );
            if (i > 0) {
                require(
                    fees[i].from > fees[i - 1].to,
                    "XStakingPool: range from should be greater than previous to"
                );
                if (fees[i].percentage == 0) {
                    require(
                        fees[i].fixedFee > 0,
                        "XStakingPool: fixed fee should be greater than 0"
                    );
                }
            }
            unchecked {
                ++i;
            }
        }

        isDeposit ? depositFeeConfig = fees : withdrawFeeConfig = fees;
    }

    /// @notice sweep any token to owner
    /// @param token address of token
    function sweep(address token) public onlyOwner {
        uint256 balanceOfToken = IToken(token).balanceOf(address(this));
        IToken(token).safeTransfer(owner(), balanceOfToken);
    }

    /// @notice Upgrades the XStakingPool implementation to a new contract.
    /// @dev Can only be called by the owner. Updates the beacon with the new implementation address.
    /// @param _xstakingPoolImplementation Address of the new XStakingPool implementation.
    function upgradeTo(address _xstakingPoolImplementation) public onlyOwner {
        xstakingPoolImplementation = IXStakingPool(_xstakingPoolImplementation);
        beacon.upgradeTo(_xstakingPoolImplementation);
    }

    // ------------------------------------------------------------------------
    // USER FUNCTIONS

    /// @notice Deploys a new XStakingPool contract.
    /// @dev Creates a new BeaconProxy pointing to the beacon and initializes the pool.
    /// @param tokens the array of addresses of tokens
    /// @param allocations the allocation for tokens
    /// @return Address of the newly deployed XStakingPool.
    function deployPool(
        address depositToken,
        uint256 capitalizationCap,
        address[] memory tokens,
        uint256[] memory allocations,
        uint256 profitSharingFeeNumerator,
        uint256 initialDepositTokenAmount,
        bytes[] calldata oneInchSwapData,
        string memory description
    ) public nonReentrant returns (address) {
        require(
            isDepositToken[depositToken],
            "XStakingFactory: token is not deposit token"
        );
        uint256 tokensLength = tokens.length;
        require(
            tokensLength == oneInchSwapData.length,
            "XStakingFactory: tokens.length != oneInchSwapData.length"
        );
        uint256 poolId = xstakingPools.length + 1;

        // Staking fee

        uint256 depositTokenAmount = getTotalDepositTokenAmountForDeployPool(
            initialDepositTokenAmount
        );
        {
            IToken(depositToken).safeTransferFrom(
                msg.sender,
                address(this),
                depositTokenAmount
            );

            uint256 stakingFee = calculateFeeAmount(
                initialDepositTokenAmount,
                true
            );
            uint256 totalFee = poolCreationFee + stakingFee;

            IToken(depositToken).safeTransfer(treasuryWallet, totalFee);
        }

        BeaconProxy newPool = new BeaconProxy(address(beacon), bytes(""));
        xstakingPools.push(address(newPool));
        isXStakingPool[address(newPool)] = true;

        IToken(depositToken).forceApprove(
            oneInchRouter,
            initialDepositTokenAmount
        );

        uint256 totalSwappedDepositTokenAmount = 0;

        uint256[] memory tokensAmounts = new uint256[](tokensLength);
        address token;
        for (uint256 i = 0; i < tokensLength; ) {
            token = tokens[i];

            uint256 balanceBefore = IToken(token).balanceOf(address(this));

            uint256 depositTokenBalanceBefore = IToken(depositToken).balanceOf(
                address(this)
            );

            (bool success, ) = oneInchRouter.call(oneInchSwapData[i]);

            uint256 depositTokenBalanceAfter = IToken(depositToken).balanceOf(
                address(this)
            );

            uint256 balanceAfter = IToken(token).balanceOf(address(this));

            uint256 amountOut = balanceAfter - balanceBefore;

            require(
                amountOut > 0,
                "XStakingFactory: 1inch swap out amount is 0"
            );

            require(
                oneInchSwapData[i].length >= 4,
                "XStakingFactory: Incorrect data length"
            );

            (
                ,
                address receiver,
                address srcToken,
                uint256 srcTokenAmount,
                uint256 minReturnAmount
            ) = decodeSwapData(oneInchSwapData[i]);

            require(
                srcTokenAmount ==
                    depositTokenBalanceBefore - depositTokenBalanceAfter,
                "XStakingFactory: srcTokenAmount is not correct"
            );

            require(
                receiver == address(this),
                "XStakingFactory: receiver is not factory"
            );

            require(
                depositToken == address(srcToken),
                "XStakingFactory: deposit token does not match with src token in swap data"
            );

            require(success, "XStakingFactory: 1inch swap failed");

            totalSwappedDepositTokenAmount += srcTokenAmount;

            IToken(token).forceApprove(address(newPool), amountOut);

            tokensAmounts[i] = amountOut;

            require(
                tokensAmounts[i] >= minReturnAmount,
                "XStakingFactory: output amount does not match with encoded amount from swap data"
            );

            unchecked {
                i++;
            }
        }

        require(
            totalSwappedDepositTokenAmount == initialDepositTokenAmount,
            "XStakingFactory: swapped tokens amount does not match with sum of amount in every swap"
        );

        IXStakingPool(address(newPool)).initialize(
            poolId,
            msg.sender,
            capitalizationCap,
            tokens,
            allocations,
            profitSharingFeeNumerator,
            tokensAmounts,
            depositToken,
            initialDepositTokenAmount
        );

        emit DeployPool(
            msg.sender,
            address(newPool),
            poolId,
            tokens,
            allocations,
            description,
            capitalizationCap,
            profitSharingFeeNumerator
        );
        return address(newPool);
    }

    /// @notice return the allocation tokens for deposit using 1inch, when creating pool
    /// @dev this helper view function uses for forming swap request to 1inch API
    /// @param tokens the array of tokens
    /// @param allocations the array of allocations of tokens
    /// @param initialDepositTokenAmount the amount of base token to deposit
    /// @return the array of allocation of depositTokenAmount for swap using 1inch and sum of array elements
    function calcDepositTokenAmountAllocationForDeployPool(
        address[] memory tokens,
        uint256[] memory allocations,
        uint256 initialDepositTokenAmount
    ) public pure returns (uint256[] memory, uint256) {
        require(
            tokens.length == allocations.length,
            "XStakingFactory: not equal length of tokens and allocations"
        );
        uint256[] memory allocatedDepositTokens = new uint256[](tokens.length);
        uint256 totalSumOfAllocatedBaseToken;
        uint256 totalAllocation = 0;
        for (uint256 i = 0; i < allocations.length; ) {
            unchecked {
                totalAllocation += allocations[i];
                i++;
            }
        }
        for (uint256 i = 0; i < tokens.length; ) {
            allocatedDepositTokens[i] =
                (initialDepositTokenAmount * allocations[i]) /
                totalAllocation;
            totalSumOfAllocatedBaseToken += allocatedDepositTokens[i];
            unchecked {
                i++;
            }
        }
        return (allocatedDepositTokens, totalSumOfAllocatedBaseToken);
    }

    function calculateFeeAmount(
        uint256 amount,
        bool isDeposit
    ) public view returns (uint256) {
        FeeConfig memory feeInfo;
        if (isDeposit) {
            uint256 length = depositFeeConfig.length;
            for (uint256 i = 0; i < length; ) {
                if (
                    depositFeeConfig[i].from <= amount &&
                    depositFeeConfig[i].to >= amount
                ) {
                    feeInfo = depositFeeConfig[i];
                }
                unchecked {
                    i++;
                }
            }
        } else {
            uint256 length = withdrawFeeConfig.length;
            for (uint256 i = 0; i < length; ) {
                if (
                    withdrawFeeConfig[i].from <= amount &&
                    withdrawFeeConfig[i].to >= amount
                ) {
                    feeInfo = withdrawFeeConfig[i];
                }
                unchecked {
                    i++;
                }
            }
        }

        if (feeInfo.percentage == 0) return feeInfo.fixedFee;

        return (amount * feeInfo.percentage) / FEE_DENOMINATOR;
    }

    /// @notice returns the total amount of base token for deployment of pool
    function getTotalDepositTokenAmountForDeployPool(
        uint256 initialDepositTokenAmount
    ) public view returns (uint256 depositTokenAmount) {
        uint256 stakingFee = calculateFeeAmount(
            initialDepositTokenAmount,
            true
        );
        depositTokenAmount =
            poolCreationFee +
            initialDepositTokenAmount +
            stakingFee;
    }

    /// @notice returns staking fee
    /// @return numerator and denominator of staking fee
    function getStakingFee() public view returns (uint256, uint256) {
        return (stakingFeeNumerator, FEE_DENOMINATOR);
    }

    /// @notice returns unstaking fee
    /// @return numerator and denominator of unstaking fee
    function getUnstakingFee() public view returns (uint256, uint256) {
        return (unstakingFeeNumerator, FEE_DENOMINATOR);
    }

    /// @notice Returns an array of all deployed XStakingPool addresses.
    /// @return An array of addresses of all XStakingPools.
    function getXStakingPools() public view returns (address[] memory) {
        return xstakingPools;
    }

    /// @notice Returns a slice of deployed XStakingPool addresses within a specified range.
    /// @dev Fetches pools from the `fromId` up to (but not including) `toId`.
    /// @param fromId The starting index in the list of pools.
    /// @param toId The ending index in the list of pools.
    /// @return xstakingPoolsSlice as array of addresses of XStakingPools in the specified range.
    function getXStakingPoolsByIds(
        uint256 fromId,
        uint256 toId
    ) public view returns (address[] memory xstakingPoolsSlice) {
        require(fromId <= toId, "XStakingFactory: exceeded length of pools");
        require(
            toId <= xstakingPools.length,
            "XStakingFactory: toId exceeds length of pools"
        );
        if (fromId == toId) {
            xstakingPoolsSlice = new address[](1);
            xstakingPoolsSlice[0] = xstakingPools[fromId];
        } else {
            xstakingPoolsSlice = new address[](toId - fromId);
            for (uint256 i = 0; i < toId - fromId; i++) {
                xstakingPoolsSlice[i] = xstakingPools[i + fromId];
            }
        }
        return xstakingPoolsSlice;
    }

    /// @notice Returns the total number of deployed XStakingPools.
    /// @return The number of XStakingPools deployed by this factory.
    function getXStakingPoolsLength() public view returns (uint256) {
        return xstakingPools.length;
    }

    function getDepositToken(uint8 index) external view returns (address) {
        return depositTokens[index];
    }

    function getCurrentFees()
        external
        view
        returns (
            FeeConfig[] memory depositFees_,
            FeeConfig[] memory withdrawFees_
        )
    {
        return (depositFeeConfig, withdrawFeeConfig);
    }

    /// @notice decode swap data for 1inch and return the parameters used in swap
    /// @param data the calldata of swap
    function decodeSwapData(
        bytes calldata data
    )
        public
        view
        returns (
            address sender,
            address receiver,
            address srcToken,
            uint256 srcTokenAmount,
            uint256 minReturnAmount
        )
    {
        bytes4 selector;
        assembly {
            selector := calldataload(data.offset)
        }

        /// @dev `0x0502b1c5` - unoswap selector
        if (selector == bytes4(0x0502b1c5)) {
            (srcToken, srcTokenAmount, minReturnAmount, ) = abi.decode(
                data[4:],
                (address, uint256, uint256, uint256[])
            );
            sender = address(this);
            receiver = address(this);
        }
        /// @dev `0x12aa3caf` - swap selector
        else if (selector == bytes4(0x12aa3caf)) {
            (address executor, SwapDescription memory desc, , ) = abi.decode(
                data[4:], // Skip selector (4 bytes)
                (address, SwapDescription, bytes, bytes)
            );

            sender = executor;
            receiver = desc.dstReceiver;
            srcToken = address(desc.srcToken);
            srcTokenAmount = desc.amount;
            minReturnAmount = desc.minReturnAmount;
        } else if (selector == bytes4(0xe449022e)) {
            uint256[] memory pools;
            (srcTokenAmount, minReturnAmount, pools) = abi.decode(
                data[4:], // Skip selector (4 bytes)
                (uint256, uint256, uint256[])
            );

            address token0 = IUniswapV3Pool(address(uint160(pools[0])))
                .token0();

            address token1 = IUniswapV3Pool(address(uint160(pools[0])))
                .token1();

            if (isDepositToken[token0] && isDepositToken[token1]) {
                revert("XStakingFactory: both tokens are deposit tokens");
            }

            if (!isDepositToken[token0]) {
                srcToken = token1;
            } else {
                srcToken = token0;
            }
            sender = address(this);
            receiver = address(this);
        } else if (selector == bytes4(0x62e238bb)) {
            (
                Order memory order,
                ,
                ,
                uint256 makingAmount,
                uint256 takingAmount,

            ) = abi.decode(
                    data[4:], // Skip selector (4 bytes)
                    (Order, bytes, bytes, uint256, uint256, uint256)
                );

            sender = msg.sender;
            receiver = order.maker;
            srcToken = order.takerAsset;
            srcTokenAmount = takingAmount;
            minReturnAmount = makingAmount;
        } else {
            revert("XStakingFactory: unknown selector");
        }
    }
}
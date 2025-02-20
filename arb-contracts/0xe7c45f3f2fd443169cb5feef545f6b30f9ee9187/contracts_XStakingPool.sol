// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./contracts_interfaces_IToken.sol";
import "./contracts_interfaces_IXStakingPool.sol";
import "./contracts_interfaces_IXBRStakingPool.sol";
import "./contracts_interfaces_IXStakingFactory.sol";
import "./node_modules_uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol";
import "./node_modules_uniswap_v3-core_contracts_interfaces_IUniswapV3Pool.sol";
import "./node_modules_openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./node_modules_openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import "./node_modules_openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./node_modules_openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./node_modules_openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol";
import "./node_modules_openzeppelin_contracts_utils_Strings.sol";

/// @title XStakingPool
/// @dev This contract handles individual staking operations,
/// including deposits and withdrawals of different assets.
/// @custom:oz-upgrades-from XStakingPoolV1
contract XStakingPool is
    Initializable,
    ERC20Upgradeable,
    Ownable2StepUpgradeable,
    IXStakingPool,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IToken;

    /// @dev 10000 = 100%
    uint256 public constant FEE_DENOMINATOR = 100_00;

    /// @notice Reference to the XStakingFactory that deployed this pool.
    IXStakingFactory public xstakingFactory;

    /// @notice Unique identifier for this staking pool.
    uint256 public poolId;

    /// @notice profit sharing fee numerator
    uint256 public profitSharingFeeNumerator;

    /// @notice tokens in the pool
    address[] public tokens;

    /// @notice the allocations of tokens
    uint256[] public allocations;

    /// @notice the sum of array `allocations`
    uint256 public totalAllocation;

    /// @notice the cap of
    uint256 public capitalizationCap;

    /// @notice true - deposit paused, false - deposit not paused
    bool public isDepositPaused;

    /// @notice profit sharing fees
    mapping(address depositToken => uint256) public totalProfitSharingFee;

    /// @notice allocated tokens to user
    mapping(address user => mapping(address token => uint256))
        public userTokenAmount;

    /// @notice Mapping to track the total tokens amount for each token.
    /// @dev Key is the token address, and value is the total amount deposited in the pool.
    mapping(address token => uint256) public totalTokenAmount;

    /// @notice List of tokens that have been added to the pool to prevent duplicates.
    mapping(address => bool) isTokenAlreadyAdded;

    uint256 private tempTotalAmountDepositTokenOut = 0;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the XStakingPool with a specific pool ID and initial owner.
    /// @dev Sets the pool ID and the initial owner. Links the pool to the XStakingFactory.
    /// @param _poolId Unique identifier for the pool.
    /// @param _poolOwner Address of the initial owner of the pool.
    function initialize(
        uint256 _poolId,
        address _poolOwner,
        uint256 _capitalizationCap,
        address[] memory _tokens,
        uint256[] memory _allocations,
        uint256 _profitSharingFeeNumerator,
        uint256[] memory _tokensAmounts,
        address initialDepositToken,
        uint256 initialDepositTokenAmount
    ) public initializer {
        __Ownable_init(_poolOwner);
        __ERC20_init_unchained(
            string.concat("XBR XStakingPool #", Strings.toString(_poolId)),
            string.concat("XBR", Strings.toString(_poolId))
        );
        __ReentrancyGuard_init();
        xstakingFactory = IXStakingFactory(msg.sender); // deployer is XStakingFactory
        poolId = _poolId;
        capitalizationCap = _capitalizationCap;
        uint256 tokenLength = _tokens.length;
        require(
            tokenLength == _allocations.length &&
                tokenLength == _tokensAmounts.length,
            "XStakingPool: invalid length of _tokens and _allocations"
        );

        allocations = _allocations;
        uint256 _totalAllocation = 0;
        address poolOwner = _poolOwner;
        _setProfitSharingFeeNumerator(_profitSharingFeeNumerator);

        address token;
        for (uint256 i = 0; i < tokenLength; ) {
            token = _tokens[i];

            require(
                isTokenAlreadyAdded[token] == false,
                "XStakingPool: token already added"
            );

            isTokenAlreadyAdded[token] = true;
            tokens.push(token);

            uint256 tokenAmountBefore = IToken(token).balanceOf(address(this));

            IToken(token).safeTransferFrom(
                msg.sender,
                address(this),
                _tokensAmounts[i]
            );

            uint256 tokenAmountAfter = IToken(token).balanceOf(address(this));

            uint256 incommingAmount = tokenAmountAfter - tokenAmountBefore;
            userTokenAmount[poolOwner][token] += incommingAmount;
            totalTokenAmount[token] += incommingAmount;
            _totalAllocation += _allocations[i];
            unchecked {
                i++;
            }
        }
        for (uint256 i = 0; i < tokenLength; ) {
            emit TokenSwap(
                _tokens[i],
                _tokensAmounts[i],
                (initialDepositTokenAmount * _allocations[i]) / _totalAllocation
            );
            unchecked {
                i++;
            }
        }
        uint256 amountToMint = calcMintAmount(
            initialDepositToken,
            initialDepositTokenAmount
        );
        _mint(poolOwner, amountToMint);
        emit Volume(initialDepositTokenAmount);
        emit Deposit(
            address(this),
            poolOwner,
            initialDepositTokenAmount,
            getUserTokenAmounts(poolOwner)
        );
        emitTokenAmouts();
        totalAllocation = _totalAllocation;
    }

    function claimProfitSharingFee(address depositToken) public onlyOwner {
        IToken(depositToken).safeTransfer(
            msg.sender,
            totalProfitSharingFee[depositToken]
        );
        totalProfitSharingFee[depositToken] = 0;
    }

    /// @notice set the deposit paused
    /// @param _depositPaused true - deposit paused, false - deposit unpaused
    function setPausedDeposit(bool _depositPaused) public onlyOwner {
        isDepositPaused = _depositPaused;

        emit DepositStatusUpdated(_depositPaused);
    }

    /// @notice set the new capitalization cap
    /// @param _capitalizationCap the amount of dollars in capitalization
    function setCapitalizationCap(uint256 _capitalizationCap) public onlyOwner {
        capitalizationCap = _capitalizationCap;
    }

    /// @notice sets profit sharing fee
    /// @param _profitSharingFeeNumerator the numerator of profit sharing fee
    function setProfitSharingFeeNumerator(
        uint256 _profitSharingFeeNumerator
    ) public onlyOwner {
        _setProfitSharingFeeNumerator(_profitSharingFeeNumerator);
    }

    function _setProfitSharingFeeNumerator(
        uint256 _profitSharingFeeNumerator
    ) internal {
        require(
            1_00 <= _profitSharingFeeNumerator &&
                _profitSharingFeeNumerator <= 49_00,
            "XStakingPool: _profitSharingFeeNumerator out of bound"
        );
        profitSharingFeeNumerator = _profitSharingFeeNumerator;
    }

    function execOneInchSwap(
        address oneInchRouter,
        bytes memory oneInchSwapData
    ) internal returns (uint256) {
        (bool success, bytes memory response) = oneInchRouter.call(
            oneInchSwapData
        );
        require(success, "1inch swap failed");
        uint256 amountOut = abi.decode(response, (uint256));
        return amountOut;
    }

    /// @notice deposit the baseToken to pool to `msg.sender`
    /// @param depositToken address of deposit token
    /// @param depositTokenAmount amount of base token
    /// @param oneInchSwapData the data for swap on 1inch
    /// @return the amount of minted Liquidity Pool Token
    function deposit(
        address depositToken,
        uint256 depositTokenAmount,
        bytes[] calldata oneInchSwapData
    ) public returns (uint256) {
        return
            depositTo(
                depositToken,
                msg.sender,
                depositTokenAmount,
                oneInchSwapData
            );
    }

    /// @notice deposit the baseToken to pool
    /// @param depositToken address of deposit token
    /// @param to address of receiver the LP tokens
    /// @param depositTokenAmount amount of base token
    /// @param oneInchSwapData the data for swap on 1inch
    /// @return the amount of minted Liquidity Pool Token
    function depositTo(
        address depositToken,
        address to,
        uint256 depositTokenAmount,
        bytes[] calldata oneInchSwapData
    ) public returns (uint256) {
        _checkIfOwnerHaveLockedTokens();
        require(
            xstakingFactory.isDepositToken(depositToken),
            "XStakingPool: not deposit token"
        );
        require(
            tokens.length == oneInchSwapData.length,
            "XStakingPool: invalid length of tokens and oneInchSwapData"
        );

        require(!isDepositPaused, "XStakingPool: deposit is paused");
        address oneInchRouter = xstakingFactory.oneInchRouter();
        address treasuryWallet = xstakingFactory.treasuryWallet();
        (
            uint256 totalDepositToken
        ) = calculateTotalDepositToken(
                depositToken,
                depositTokenAmount
            );
        
        {
            IToken(depositToken).safeTransferFrom(
                msg.sender,
                address(this),
                totalDepositToken
            );

            uint256 stakingFee = totalDepositToken - depositTokenAmount;
            
             IToken(depositToken).safeTransfer(
                treasuryWallet,
                stakingFee
            );
        }

        IToken(depositToken).forceApprove(oneInchRouter, depositTokenAmount);
        _depositTo(
            depositToken,
            to,
            depositTokenAmount,
            oneInchRouter,
            oneInchSwapData
        );
        emit Volume(depositTokenAmount);
        emit Deposit(
            address(this),
            to,
            depositTokenAmount,
            getUserTokenAmounts(to)
        );
        emitTokenAmouts();
        return depositTokenAmount;
    }

    function _depositTo(
        address depositToken,
        address to,
        uint256 depositTokenAmount,
        address oneInchRouter,
        bytes[] calldata oneInchSwapData
    ) internal nonReentrant {
        uint256 len = tokens.length;
        uint256 amountOut;
        uint256 depositTokenAmountAllocated;
        address token;
        uint256 capitalization = 0;
        uint256 totalSwappedDepositTokenAmount = 0;

        for (uint256 i = 0; i < len; ) {
            token = tokens[i];

            uint256 balanceBefore = IToken(token).balanceOf(address(this));

            require(
                oneInchSwapData[i].length >= 4,
                "XStakingPool: Incorrect data length"
            );

            (
                ,
                address receiver,
                address srcToken,
                uint256 srcTokenAmount,
                uint256 minReturnAmount
            ) = decodeSwapData(oneInchSwapData[i]);

            totalSwappedDepositTokenAmount += srcTokenAmount;

            require(
                address(this) == receiver,
                "XStakingPool: swap receiver have to be pool address"
            );

            require(
                depositToken == srcToken,
                "XStakingPool: deposit token does not match with src token in swap data"
            );

            uint256 tokenAmountBefore = IToken(token).balanceOf(address(this));

            execOneInchSwap(oneInchRouter, oneInchSwapData[i]); // [amountOut]=token

            uint256 tokenAmountAfter = IToken(token).balanceOf(address(this));

            amountOut = tokenAmountAfter - tokenAmountBefore;

            require(
                amountOut >= minReturnAmount,
                "XStakingPool: output amount does not match with encoded amount from swap data"
            );

            uint256 balanceAfter = IToken(token).balanceOf(address(this));

            require(
                balanceAfter != balanceBefore,
                "XStakingPool: pool balance was not changed after swap"
            );

            userTokenAmount[to][token] += amountOut;
            totalTokenAmount[token] += amountOut;
            depositTokenAmountAllocated =
                (depositTokenAmount * allocations[i]) /
                totalAllocation;
            capitalization +=
                (totalTokenAmount[token] * depositTokenAmountAllocated) /
                amountOut;
            emit TokenSwap(token, amountOut, depositTokenAmountAllocated);
            unchecked {
                i++;
            }
        }

        require(
            totalSwappedDepositTokenAmount == depositTokenAmount,
            "XStakingPool: swapped tokens amount does not match with sum of amount in every swap"
        );

        _mint(to, calcMintAmount(depositToken, depositTokenAmount));

        if (totalSupply() >= capitalizationCap * 10 ** 12) {
            isDepositPaused = true;

            emit DepositStatusUpdated(true);
        }
        emit PoolCapitalization(address(this), capitalization);
    }

    /// @notice return the allocation tokens for deposit using 1inch
    /// @dev this helper view function uses for forming swap request to 1inch API
    /// @param depositTokenAmount the amount of base token to deposit
    /// @return the array of allocation of depositTokenAmount for swap using 1inch and sum of array elements
    function calcDepositTokenAllocationForDeposit(
        uint256 depositTokenAmount
    ) public view returns (uint256[] memory, uint256) {
        uint256 len = tokens.length;
        uint256[] memory allocatedBaseTokens = new uint256[](len);

        uint256 totalSumOfAllocatedBaseToken;
        for (uint256 i = 0; i < len; ) {
            allocatedBaseTokens[i] =
                (depositTokenAmount * allocations[i]) /
                totalAllocation;
            totalSumOfAllocatedBaseToken += allocatedBaseTokens[i];
            unchecked {
                i++;
            }
        }
        return (allocatedBaseTokens, totalSumOfAllocatedBaseToken);
    }

    function calculateTotalDepositToken(
        address depositToken,
        uint256 depositTokenAmount
    ) public view returns (uint256 totalDepositToken) {
        uint256 stakingFee = xstakingFactory.calculateFeeAmount(depositTokenAmount, true);
        totalDepositToken = depositTokenAmount + stakingFee;
    }

    /// @notice withdraw the base token amount from `from` to `msg.sender`
    /// @param depositToken address of deposit token
    /// @param amountLP the amount of Liquidity Pool token
    /// @param oneInchSwapData the data for swap on 1inch
    function withdraw(
        address depositToken,
        uint256 amountLP,
        bytes[] calldata oneInchSwapData
    ) public returns (uint256) {
        return
            withdrawFrom(
                depositToken,
                msg.sender,
                msg.sender,
                amountLP,
                oneInchSwapData
            );
    }

    function withdrawFrom(
        address depositToken,
        address from,
        address to,
        uint256 amountLP,
        bytes[] calldata oneInchSwapData
    ) internal returns (uint256) {
        require(
            xstakingFactory.isDepositToken(depositToken),
            "XStakingPool: not deposit token"
        );
        uint256 balanceOfLP = balanceOf(from);
        require(amountLP <= balanceOfLP, "XStakingPool: amountLP > balanceOf");

        address oneInchRouter = xstakingFactory.oneInchRouter();
        address treasuryWallet = xstakingFactory.treasuryWallet();
        uint256 totalAmountDepositTokenOut = _withdrawFrom(
            from,
            amountLP,
            oneInchRouter,
            oneInchSwapData
        );
        uint256 unstakingFee;

        uint256 lpDecimals = decimals();
        uint256 depositTokenDecimals = IToken(depositToken).decimals();

        uint256 adaptedAmountLP = amountLP;
        uint256 adaptedTotalAmountDepositTokenOut = totalAmountDepositTokenOut;

        // adapt `adaptedAmountLP` decimals to `depositTokenDecimals`.
        if (lpDecimals > depositTokenDecimals) {
            uint256 scaleDifference = lpDecimals - depositTokenDecimals;
            adaptedAmountLP = adaptedAmountLP / (10 ** scaleDifference);
        } else if (depositTokenDecimals > lpDecimals) {
            uint256 scaleDifference = depositTokenDecimals - lpDecimals;
            adaptedAmountLP = adaptedAmountLP * (10 ** scaleDifference);
        }

        if (adaptedAmountLP < adaptedTotalAmountDepositTokenOut) {
            uint256 profit = adaptedTotalAmountDepositTokenOut -
                adaptedAmountLP;
            uint256 profitSharingFee = (profit * profitSharingFeeNumerator) /
                FEE_DENOMINATOR;
            totalProfitSharingFee[depositToken] += profitSharingFee;
            totalAmountDepositTokenOut -= profitSharingFee;
        }

        unstakingFee = xstakingFactory.calculateFeeAmount(totalAmountDepositTokenOut, false);

        IToken(depositToken).safeTransfer(
            to,
            totalAmountDepositTokenOut - unstakingFee
        );

        IToken(depositToken).safeTransfer(treasuryWallet, unstakingFee);

        emit Volume(totalAmountDepositTokenOut);
        emit Withdraw(
            address(this),
            from,
            totalAmountDepositTokenOut,
            getUserTokenAmounts(from)
        );
        emitTokenAmouts();
        _burn(from, amountLP);
        return totalAmountDepositTokenOut;
    }

    function _withdrawFrom(
        address from,
        uint256 amountLP,
        address oneInchRouter,
        bytes[] calldata oneInchSwapData
    ) internal nonReentrant returns (uint256) {
        address token;
        uint256 capitalization = 0;
        uint256[] memory allocatedTokens = calcAllocatedTokensForWithdraw(
            from,
            amountLP
        );

        for (uint256 i = 0; i < tokens.length; ) {
            bytes memory swapData = oneInchSwapData[i];
            uint256 amountDepositTokenOut;
            token = tokens[i];

            userTokenAmount[from][token] -= allocatedTokens[i];
            totalTokenAmount[token] -= allocatedTokens[i];
            IToken(token).forceApprove(oneInchRouter, allocatedTokens[i]);

            uint256 balanceBefore = IToken(token).balanceOf(address(this));

            if (swapData.length == 0) {
                IToken(token).safeTransfer(from, allocatedTokens[i]);
            } else {
                amountDepositTokenOut = execOneInchSwap(
                    oneInchRouter,
                    oneInchSwapData[i]
                );

                uint256 balanceAfter = IToken(token).balanceOf(address(this));

                require(
                    balanceBefore == balanceAfter + allocatedTokens[i],
                    "XStakingPool: swapped amount does not match with allocated amount"
                );

                require(
                    balanceBefore != IToken(token).balanceOf(address(this)),
                    "XStakingPool: deposit token does not match with src token in swap data"
                );

                require(
                    oneInchSwapData[i].length >= 4,
                    "XStakingPool: Incorrect data length"
                );

                (
                    ,
                    address receiver,
                    ,
                    uint256 srcTokenAmount,
                    uint256 minReturnAmount
                ) = decodeSwapData(oneInchSwapData[i]);

                tempTotalAmountDepositTokenOut += amountDepositTokenOut;

                require(
                    srcTokenAmount == allocatedTokens[i],
                    "XStakingPool: srcTokenAmount does not match with allocatedTokens"
                );

                require(
                    address(this) == receiver,
                    "XStakingPool: swap receiver have to be pool address"
                );

                require(
                    amountDepositTokenOut >= minReturnAmount,
                    "XStakingPool: amountDepositTokenOut less than minReturnAmount"
                );

                capitalization +=
                    (totalTokenAmount[token] * amountDepositTokenOut) /
                    allocatedTokens[i];
                emit TokenSwap(
                    token,
                    allocatedTokens[i],
                    amountDepositTokenOut
                );
            }

            unchecked {
                i++;
            }
        }

        if (totalSupply() < capitalizationCap * 10 ** 12) {
            isDepositPaused = false;

            emit DepositStatusUpdated(false);
        }

        uint256 result = tempTotalAmountDepositTokenOut;
        tempTotalAmountDepositTokenOut = 0;

        emit PoolCapitalization(address(this), capitalization);
        return result;
    }

    /// @notice overrides for handle proper LP tokens transfers
    function _update(
        address from,
        address to,
        uint256 amountLP
    ) internal override {
        super._update(from, to, amountLP);
        if (from == address(0) || to == address(0)) {
            // if mint or burn
            return;
        }

        revert("LP non transferable");
    }

    /// @notice return the allocation tokens for withdraw using 1inch
    /// @dev this helper view function uses for forming swap request to 1inch API
    /// @param amountLP amount of Liquidity Pool token
    /// @return allocatedTokens the array of tokens amount
    function calcAllocatedTokensForWithdraw(
        address user,
        uint256 amountLP
    ) public view returns (uint256[] memory allocatedTokens) {
        require(
            amountLP <= balanceOf(user),
            "XStakingPool: exceeds amount of LP"
        );
        uint256 len = tokens.length;
        allocatedTokens = new uint256[](len);
        address token;
        for (uint256 i = 0; i < len; ) {
            token = tokens[i];
            allocatedTokens[i] =
                (userTokenAmount[user][token] * amountLP) /
                balanceOf(user);
            unchecked {
                i++;
            }
        }
    }

    function emitTokenAmouts() internal {
        uint256 len = tokens.length;
        uint256[] memory tokenAmounts = new uint256[](len);
        for (uint256 i = 0; i < len; ) {
            tokenAmounts[i] = totalTokenAmount[tokens[i]];
            unchecked {
                i++;
            }
        }
        emit TokensAmounts(tokens, tokenAmounts);
    }

    /// @notice total amount of tokens
    function tokensLength() public view returns (uint256) {
        return tokens.length;
    }

    /// @notice the tokens array and it`s allocations
    function getTokensAndAllocation()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        return (tokens, allocations);
    }

    /// @notice returns capitalization decimals
    function capitalizationDecimals() public pure returns (uint8) {
        return 6;
    }

    /// @notice return LP based on depositTokenAmount
    function calcMintAmount(
        address depositToken,
        uint256 depositTokenAmount
    ) public view returns (uint256) {
        uint8 depositTokenDecimals = IToken(depositToken).decimals();
        if (decimals() >= depositTokenDecimals) {
            return
                depositTokenAmount * 10 ** (decimals() - depositTokenDecimals);
        } else {
            return
                depositTokenAmount / 10 ** (depositTokenDecimals - decimals());
        }
    }

    /// @notice returns user amounts
    function getUserTokenAmounts(
        address user
    ) public view returns (uint256[] memory tokenAmounts) {
        uint256 tokenLen = tokens.length;
        tokenAmounts = new uint256[](tokenLen);
        for (uint256 i = 0; i < tokenLen; i++) {
            tokenAmounts[i] = userTokenAmount[user][tokens[i]];
        }
    }

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

            if (!xstakingFactory.isDepositToken(token0)) {
                srcToken = IUniswapV3Pool(address(uint160(pools[0]))).token1();
            } else {
                srcToken = IUniswapV3Pool(address(uint160(pools[0]))).token0();
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

            sender = address(this);
            receiver = address(this);
            srcToken = order.takerAsset;
            srcTokenAmount = takingAmount;
            minReturnAmount = makingAmount;
        } else {
            revert("XStakingFactory: unknown selector");
        }
    }

    function _checkIfOwnerHaveLockedTokens() internal view {
        if (msg.sender != owner()) {
            require(
                balanceOf(owner()) > 0,
                "XStakingPool: Pool is locked such as pool's owner withdrawn all investments"
            );
        }
    }
}
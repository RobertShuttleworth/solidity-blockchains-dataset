// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {IERC1155} from "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
import {IERC721Metadata} from "./openzeppelin_contracts_token_ERC721_extensions_IERC721Metadata.sol";
import {ERC1155Holder} from "./openzeppelin_contracts_token_ERC1155_utils_ERC1155Holder.sol";
import {ILiquiDevilLp} from "./src_lp-tokens_interfaces_ILiquiDevilLp.sol";
import {ICurve} from "./src_bonding-curves_ICurve.sol";
import {IPoolManager} from "./src_pool_interfaces_IPoolManager.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";
import {PoolInfo, Timelock} from "./src_lib_Types.sol";
import {IPool} from "./src_pool_interfaces_IPool.sol";
import {FixedPointMathLib} from "./solmate_utils_FixedPointMathLib.sol";
import {IERC165} from "./openzeppelin_contracts_utils_introspection_IERC165.sol";
import "./openzeppelin_contracts_utils_cryptography_MerkleProof.sol";

/// @title The base contract for an NFT/TOKEN AMM pair manager
/// @author Liqui-devil
/// @notice This implements the core logic for managing pool operations to devide logic and reduce code size of pool
contract PoolManager is IPoolManager {
    using SafeERC20 for IERC20;
    using FixedPointMathLib for uint256;

    bytes4 private constant INTERFACE_ID_ERC721 = type(IERC721).interfaceId;
    bytes4 private constant INTERFACE_ID_ERC1155 = type(IERC1155).interfaceId;

    // 90%, must <= 1 - MAX_PROTOCOL_FEE (set in PoolFactory)
    uint256 internal constant MAX_FEE = 0.90e18;
    //curve attributes defined by pool creator, can be a dynamic set of
    //attributes that any future curve will be able to utilize. Only the actual bonding curve knows
    //what each index of curve attributes contains e.g for Linear Curve it is [0] is midPrice and [1] is delta
    uint128[] public curveAttributes;

    //LP non fungible minted on NFT liquidity added and burned on remove
    address public lpnToken;

    //LP fungible minted on ERC20/ETH side of liquidity
    address public lpfToken;

    //totalFeeAcrued on each buy and sell the feeAcrued gets updated.
    uint256 public poolFeeAccrued;

    // the value based on signed rarities is updated on each add, remove liqudiity and buy/sell
    uint128 public poolReservesNft;

    //flag to check if delta will change according to new delta = old delta *  pool value / next pool value
    //0 is false by default
    uint8 public isVariableDelta = 0;

    PoolInfo.PriceStrategy priceStrategy = PoolInfo.PriceStrategy.SIGNATURE; // 0 = Oracle determins the price, 1 swap transaction have signed rarities

    string public fileHash;

    //TODO: make it configureable by the (factory TBD)
    uint256 public MINIMUM_ETH_BALANCE = 0.1e18; // TODO: make it 0.0001 for main-net

    uint256 public constant PRICE_STRATEGY_ORACLE = 0;
    uint256 public constant PRICE_STRATEGY_SIGNATURE = 1;

    //the multiplier in terms of percentage in units 1e18 to be used to transfer
    //royalty towards the royalty recipient retrieved using EIP-2981
    uint96 public override royaltyFeeMultiplier;

    // The spread between buy and sell prices, set to be a multiplier we apply to the buy price
    // Fee is only relevant for TRADE pools
    // Units are in base 1e18
    uint96 public override poolFeeMultiplier;

    // address of pool contract that this contract is manager for
    IPool public pool;

    // If set to 0, NFTs/tokens sent by traders during trades will be sent to the pair.
    // Otherwise, assets will be sent to the set address. Not available for TRADE pools.
    address payable public royaltyReciever;

    mapping(address => Timelock.Request) public conversionRequests;
    address[] conversionUsers;

    event CurveAttributesUpdated(uint128[] curveAttributes);
    event FeeUpdate(uint96 newFee);
    event RoyaltyRecieverChange(address newReciever);
    event FileHashChange(string newFileHash);
    event MinEthBalanceChanged(uint256 newMinEthBalance);
    event LpConverted(address token, uint256 amount);
    event LpConversionRequested(
        address token,
        address sender,
        uint256 newAmount
    );
    event LpConversionClaimed(address token, address sender, uint256 amount);

    modifier onlyPool() {
        require(msg.sender == address(pool), "PM: caller must be pool");
        _;
    }
    modifier onlyPoolOwner() {
        require(msg.sender == pool.owner(), "PM: caller must be pool owner");
        _;
    }

    constructor(address _pool) {
        pool = IPool(_pool);
    }

    function initialize(
        PoolInfo.InitPoolParams calldata initPoolParams,
        address _lpfToken,
        address _lpnToken
    ) external onlyPool {
        lpfToken = _lpfToken;
        lpnToken = _lpnToken;

        royaltyReciever = initPoolParams.royaltyReciever;
        require(initPoolParams.fee < MAX_FEE, "CPE: Pool fee too large");
        poolFeeMultiplier = initPoolParams.fee;
        require(
            pool.bondingCurve().validateCurveAttributes(
                initPoolParams.curveAttributes
            ),
            "CPE: Invalid Curve Attributes"
        );
        require(
            initPoolParams.isVariableDelta == 0 ||
                initPoolParams.isVariableDelta == 1,
            "CPE: wrong delta flag"
        );
        isVariableDelta = initPoolParams.isVariableDelta;
        fileHash = initPoolParams.fileHash;
        curveAttributes = initPoolParams.curveAttributes;
        royaltyFeeMultiplier = initPoolParams.royaltyFeeMultiplier;
    }

    function updatePoolParams(
        uint128[] memory _newCurveAttributes,
        uint256 fee,
        uint8 isFeeAdded
    ) external onlyPool {
        curveAttributes = _newCurveAttributes;
        if (isFeeAdded == 0) poolFeeAccrued -= fee;
        else poolFeeAccrued += fee;
    }

    function addRemoveReserveNft(
        uint128 sumRarity,
        uint8 isAdded
    ) external onlyPool {
        if (isAdded == 0) poolReservesNft -= sumRarity;
        else poolReservesNft += sumRarity;
    }

    function getCurveAttributes()
        public
        view
        override
        returns (uint128[] memory)
    {
        return curveAttributes;
    }

    /**
        @notice Update the minimum value difference that matters in not enough liquidity check 
        when converting lpf to lpn
        @param _newMinEthBalance new value of min eth balance must be < 0.1 *10 *18
     */
    function changeMinEthBalance(
        uint256 _newMinEthBalance
    ) external onlyPoolOwner {
        require(_newMinEthBalance < 0.1e18, "Invalid attributes for curve");
        MINIMUM_ETH_BALANCE = _newMinEthBalance;
        emit MinEthBalanceChanged(_newMinEthBalance);
    }

    /**
        @notice Updates the delta parameter. Only callable by the owner.
        @param _newCurveAttributes New paremeters for curve under use by this pool
        Warning Note: using this function will result in changing trade prices. 
     */
    function changeCurveAttributes(
        uint128[] memory _newCurveAttributes
    ) external onlyPoolOwner {
        require(
            pool.bondingCurve().validateCurveAttributes(_newCurveAttributes),
            "Invalid attributes for curve"
        );
        curveAttributes = _newCurveAttributes;
        emit CurveAttributesUpdated(_newCurveAttributes);
    }

    /**
        @notice Updates the fee taken by the LP. Only callable by the owner.
        Only callable if the pool is a Trade pool. Reverts if the fee is >=
        MAX_FEE.
        @param newFee The new LP fee percentage, 18 decimals
     */
    function changeFee(uint96 newFee) external onlyPoolOwner {
        require(newFee < MAX_FEE, "Trade fee must be less than 90%");
        if (poolFeeMultiplier != newFee) {
            poolFeeMultiplier = newFee;
            emit FeeUpdate(newFee);
        }
    }

    /**
        @notice Changes the address that will receive assets received from
        trades. Only callable by the owner.
        @param newRecipient The new asset recipient
     */
    function changeRoyaltyReciever(
        address payable newRecipient
    ) external onlyPoolOwner {
        require(royaltyReciever != newRecipient, "PM: Same as before");
        royaltyReciever = newRecipient;
        emit RoyaltyRecieverChange(newRecipient);
    }

    /**
        @notice Changes the address that will receive assets received from
        trades. Only callable by the owner.
        @param newFileHash The new rarities file hash
     */
    function changeFileHash(string memory newFileHash) external onlyPoolOwner {
        require(
            pool.poolType() == PoolInfo.PoolType.PRIVATE,
            "PM: feature only private pool"
        );
        fileHash = newFileHash;
        emit FileHashChange(newFileHash);
    }

    /**
        @notice 
        @dev Return the boolean to see if a request for lpn conversion is claimable
        @return _ true if request is claimable false if request is not yet claimable
     */
    function isConversionClaimable(
        Timelock.Request memory request
    ) external view returns (bool) {
        // conditions for claim
        // some unlock period must have been set
        // some amount must have been set
        // the time now - request time >= unlock period
        if (
            block.timestamp - request.timestamp >= request.unlockPeriod &&
            request.unlockPeriod > 0 &&
            request.amount > 0
        ) return true;
        else return false;
    }

    /**
        @notice 
        @dev Returns the total current amount of pending conversion request that excludes claimable requests even if not claimed yet
        @return pendingConversionAMount pending amount of lpn in conversion requests
     */
    function getPendingConversionAmount()
        external
        view
        returns (uint256 pendingConversionAMount)
    {
        //check all user requests
        for (uint256 i = 0; i < conversionUsers.length; i++) {
            Timelock.Request memory request = conversionRequests[
                conversionUsers[i]
            ];
            if (!this.isConversionClaimable(request))
                //if conversion not claimable add it to pending amount
                pendingConversionAMount += request.amount;
        }
    }

    function is721Contract(address nft) external view returns (bool) {
        try IERC165(nft).supportsInterface(INTERFACE_ID_ERC721) returns (
            bool is721
        ) {
            return is721 ? true : false;
        } catch {
            return false;
        }
    }

    function is1155Contract(address nft) external view returns (bool) {
        try IERC165(nft).supportsInterface(INTERFACE_ID_ERC1155) returns (
            bool is1155
        ) {
            return is1155 ? true : false;
        } catch {
            return false;
        }
    }

    /**
        @notice 
        @dev convert LP tokens when one side liquidity is not sufficient
        1. Pool has no NFT liquidity only ETH are left:
            a. LPNS can be converted to LPF's
        2. When ETH side liquidity is not available
            a. LPFS can be converted to LPN 
        @param amount tokens to be converted
        @param token address of either lpf or lpn token
        time lock is dependent on pool factory contract
     */
    function convertLpTokens(uint256 amount, address token) external payable {
        require(token == lpfToken || token == lpnToken, "Invalid token");
        ILiquiDevilLp lpfContract = ILiquiDevilLp(lpfToken);
        ILiquiDevilLp lpnContract = ILiquiDevilLp(lpnToken);

        //if lpf token address is sent considered conversion
        if (token == lpnToken) {
            // lpn -> lpf
            // check if no nft liquidity

            if (pool.getAllHeldIds().length == 0) {
                //convert without wait time
                //burn input lpf tokens
                lpnContract.burnFrom(msg.sender, amount);
                //mint equal amount of lpn in return
                lpfContract.mint(msg.sender, amount);
                emit LpConversionClaimed(lpnToken, msg.sender, amount);
            } else {
                //timelock logic needs to be implemented
                Timelock.Request memory request = conversionRequests[
                    msg.sender
                ];
                if (request.amount > 0) {
                    //some lpn already pending for conversion
                    //if previous timelock is claimable
                    if (this.isConversionClaimable(request)) {
                        //auto-claim the previous request
                        _claimLpfRequest(msg.sender, request);
                        //consider only current tx amount to assign next timelock for this request
                        request.amount = amount;
                    } else {
                        //add previous pending timelock amount and current and continue to assign unlock period
                        request.amount += amount;
                    }
                } else {
                    request.amount = amount;
                    conversionUsers.push(msg.sender);
                }
                //lock user lpn to pool manager
                IERC20(lpnToken).safeTransferFrom(
                    msg.sender,
                    address(this),
                    amount
                );
                //save request creation time to track claim
                request.timestamp = block.timestamp;

                //get pending conversion amount to determine unlock period
                uint256 pendingConversionAmount = this
                    .getPendingConversionAmount();
                //adding current request amount to pending before calculating percentage with total lp of pending convesion amount
                //two decimal places taken into account after decimal point
                uint256 percentagePendingToTotalLpn = ((pendingConversionAmount +
                        request.amount) * 10000) / (lpnContract.totalSupply());
                uint256 newUnlockPeriod = pool
                    .factory()
                    .getTimelockValueForPercentage(percentagePendingToTotalLpn);
                //get unlock period from factory percentages => timestamp in week table i.e. 2-weeks = 1209600
                if (
                    request.unlockPeriod < newUnlockPeriod ||
                    request.unlockPeriod == 0
                )
                    //the code will only take previous unlock period if its greater then new one
                    request.unlockPeriod = newUnlockPeriod;
                conversionRequests[msg.sender] = request;
                emit LpConversionRequested(token, msg.sender, request.amount);
            }
        } else {
            // lpf -> lpn
            // contract eth balance is less then the amont of lpf sent
            // custom logic for erc20 version
            // call to erc version pool or eth version pool to handle eth balance or erc balance
            require(
                address(pool).balance - poolFeeAccrued < MINIMUM_ETH_BALANCE,
                "Sufficient Eth Liquidity"
            );

            //burn input lpf tokens sufficient allowance is needed by contract
            lpfContract.burnFrom(msg.sender, amount);

            //mint equal amount of lpn in return
            lpnContract.mint(msg.sender, amount);
            emit LpConversionClaimed(lpfToken, msg.sender, amount);
        }
    }

    function claimLpfRequest() external {
        _claimLpfRequest(msg.sender, conversionRequests[msg.sender]);
    }

    /**
        @notice Burns holding of lpn in the pool and mints lpf in pending request if claimable
        @dev mint respective amount of LPF tokens to user wallet so liquidity can be withdrawn as LPF side 
     */
    function _claimLpfRequest(
        address sender,
        Timelock.Request memory request
    ) internal {
        ILiquiDevilLp lpfContract = ILiquiDevilLp(lpfToken);
        ILiquiDevilLp lpnContract = ILiquiDevilLp(lpnToken);
        require(this.isConversionClaimable(request), "PM: not claimable");
        lpnContract.burn(request.amount);
        lpfContract.mint(sender, request.amount);
        emit LpConversionClaimed(lpnToken, sender, request.amount);
    }

    /**
        @notice The sum of LPF and LPN minted so far.
        @param amountLp Total amount of LPF + LPN supply
     */
    function totalLp() public view returns (uint256 amountLp) {
        return (IERC20(lpfToken).totalSupply() +
            IERC20(lpnToken).totalSupply());
    }

    /**
        @notice Allows the pair to make arbitrary external calls to contracts
        whitelisted by the protocol. Only callable by the owner.
        @param target The contract to call
        @param data The calldata to pass to the contract
     */
    function call(
        address payable target,
        bytes calldata data
    ) external onlyPoolOwner {
        IPoolFactoryLike _factory = pool.factory();
        require(_factory.callAllowed(target), "Target must be whitelisted");
        (bool result, ) = target.call{value: 0}(data);
        require(result, "Call failed");
    }

    /**
        @notice Allows owner to batch multiple calls, forked from: https://github.com/boringcrypto/BoringSolidity/blob/master/contracts/BoringBatchable.sol 
        @dev Intended for withdrawing/altering pool pricing in one tx, only callable by owner, cannot change owner
        @param calls The calldata for each call to make
        @param revertOnFail Whether or not to revert the entire tx if any of the calls fail
     */
    function multicall(
        bytes[] calldata calls,
        bool revertOnFail
    ) external onlyPoolOwner {
        for (uint256 i; i < calls.length; ) {
            (bool success, bytes memory result) = address(pool).delegatecall(
                calls[i]
            );
            if (!success && revertOnFail) {
                revert(_getRevertMsg(result));
            }

            unchecked {
                ++i;
            }
        }

        // Prevent multicall from malicious frontend sneaking in ownership change
        require(
            pool.owner() == msg.sender,
            "Ownership cannot be changed in multicall"
        );
    }

    /**
      @param _returnData The data returned from a multicall result
      @dev Used to grab the revert string from the underlying call
     */
    function _getRevertMsg(
        bytes memory _returnData
    ) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Transaction reverted silently";

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    function mintLpf(address recipient, uint256 tokenAmount) external onlyPool {
        //lpf issued  = token amount  * (total LP tokens / total pool value)
        uint256 lpfIssued = tokenAmount;
        ILiquiDevilLp(lpfToken).mint(recipient, lpfIssued);
    }

    function mintLpn(address recipient, uint256 lpnIssued) external onlyPool {
        ILiquiDevilLp(lpnToken).mint(recipient, lpnIssued);
    }

    function burnLpf(address wallet, uint256 tokenAmount) external onlyPool {
        ILiquiDevilLp(lpfToken).burnFrom(wallet, tokenAmount);
    }

    function burnLpn(address wallet, uint256 tokenAmount) external onlyPool {
        ILiquiDevilLp(lpnToken).burnFrom(wallet, tokenAmount);
    }

    /**
        @notice Returns the address that assets that receives assets when a swap is done with this pair
        Can be set to another address by the owner, if set to address(0), defaults to the pair's own address
     */
    function getRoyaltyReciever()
        public
        view
        returns (address payable _royaltyReciever)
    {
        // Otherwise, we return the recipient if it's been set
        // or replace it with address(this) if it's 0
        _royaltyReciever = royaltyReciever;
        if (_royaltyReciever == address(0)) {
            // Tokens will be transferred to address(this)
            _royaltyReciever = payable(address(this));
        }
    }
}
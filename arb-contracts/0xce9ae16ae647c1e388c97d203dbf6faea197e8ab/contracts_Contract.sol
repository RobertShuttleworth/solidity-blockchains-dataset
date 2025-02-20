
       // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./thirdweb-dev_contracts_extension_Multicall.sol";

interface IUniversalNFTMarketplace {

 struct MarketplaceParams {
        address marketplace; // Address of the marketplace
        address assetContract; // Address of the NFT contract
        uint256 tokenId; // Token ID of the NFT
        uint256 quantity; // Quantity of the NFT to buy (for ERC1155)
        uint256 price; // Price in the specified currency
        address currency; // Address of the currency contract (0x0 for ETH)
        bytes data; // Additional marketplace-specific data
    }

    function buyNFTs(MarketplaceParams[] calldata params) external payable returns (bool[] memory successes);
}


interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2Router01 {
    

    
    function swapExactTokensForTokens(
        uint amountIn,
        address[] calldata path,
        address[] calldata feepath,
        address to,
        uint deadline,address factor
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
                uint amountIn,
        address[] calldata path,
        address[] calldata feepath,
        address to,
        uint deadline,address factor
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens( 
        address[] calldata path, 
        address to, 
        uint deadline, 
        address factory )
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountInMax, address[] calldata path, address to, uint deadline,address factor)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn,  address[] calldata path,
        address to, uint deadline,address factor)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens( address[] calldata path, address to, uint deadline, address factor)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path, address factor) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path, address factory) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        address[] calldata path,
        address[] calldata feepath,
        address to,
        uint deadline,
        address factory

    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        address[] calldata path,
        address to,
        uint deadline,
        address factory

    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        address[] calldata path,
        address[] calldata feepath,
       
        address to,
        uint deadline,
        address factory

    ) external;
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    
    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

contract PlasmaVerseRouting is Multicall, IUniswapV2Router02, IUniversalNFTMarketplace {
    using SafeMath for uint;
    uint256 public feePercentage = 100; // 1% fee
    address public feeRecipient;
    address public immutable WETH;
    address public owner;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'UniswapV2Router: EXPIRED');
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

   constructor(address _WETH) {
        WETH = _WETH;
        feeRecipient = msg.sender; 
        owner = msg.sender;


    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    
    function updateFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Fee recipient cannot be zero address");
        feeRecipient = newRecipient;
    }

     function updateFeePercentage(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee cannot exceed 10%");
        feePercentage = newFee;
    }   
    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to, address factory) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    function swapExactTokensForTokens(
    uint amountIn,
    address[] calldata path,
    address[] calldata feepath,
    address to,
    uint deadline,
    address factory
) external virtual override ensure(deadline) returns (uint[] memory amounts) {
    uint feeAmountIn = (amountIn * 1) / 100; // Calculate 1% fee
    uint amountInForSwap = amountIn - feeAmountIn; // Remaining amount for the main swap

    {
        // Calculate amounts for the fee swap
         uint[] memory amountsFee = UniswapV2Library.getAmountsOut(factory, feeAmountIn, feepath);
        require(amountsFee[amountsFee.length - 1] > 0, "UniswapV2Router: INSUFFICIENT_FEE_OUTPUT_AMOUNT");

        // Transfer tokens for the fee
        address feePair = UniswapV2Library.pairFor(factory, feepath[0], feepath[1]);
        TransferHelper.safeTransferFrom(feepath[0], msg.sender, feePair, feeAmountIn);

        // Execute fee swap
        _swap(amountsFee, feepath, feeRecipient, factory);
    }

    {
        // Recalculate amounts for the main swap after fee swap
        amounts = UniswapV2Library.getAmountsOut(factory, amountInForSwap, path);
        require(amounts[amounts.length - 1] > 0, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

        // Transfer tokens for the main swap
        address swapPair = UniswapV2Library.pairFor(factory, path[0], path[1]);
        TransferHelper.safeTransferFrom(path[0], msg.sender, swapPair, amountInForSwap);

        // Execute main swap
        _swap(amounts, path, to, factory);
    }
}
    


   function swapTokensForExactTokens(
        uint amountInMax,
    address[] calldata path,
    address[] calldata feepath,
    address to,
    uint deadline,
    address factory
) external virtual override ensure(deadline) returns (uint[] memory amounts) {
    uint feeAmountOut = (amountInMax * 1) / 100; // 1% fee amount
    uint amountForSwap = amountInMax - feeAmountOut; // Remaining amount for the main swap

    // Perform fee calculation and transfer
    {
         uint[] memory amountsFee = UniswapV2Library.getAmountsIn(factory, feeAmountOut, feepath);
        require(amountsFee[0] <= feeAmountOut, "UniswapV2Router: EXCESSIVE_FEE_INPUT_AMOUNT");

        address feePair = UniswapV2Library.pairFor(factory, feepath[0], feepath[1]);
        TransferHelper.safeTransferFrom(feepath[0], msg.sender, feePair, amountsFee[0]);
        
        // Execute fee swap
        _swap(amountsFee, feepath, feeRecipient, factory);
    }

    // Recalculate main swap after fee transfer
    {
        amounts = UniswapV2Library.getAmountsIn(factory, amountForSwap, path);
        require(amounts[0] <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");

        address swapPair = UniswapV2Library.pairFor(factory, path[0], path[1]);
        TransferHelper.safeTransferFrom(path[0], msg.sender, swapPair, amounts[0]);
        
        // Execute main swap
        _swap(amounts, path, to, factory);
    }
}

    function swapExactETHForTokens(
    address[] calldata path, 
    address to, 
    uint deadline, 
    address factory
)
    external
    virtual
    override
    payable
    ensure(deadline)
    returns (uint[] memory amounts) {
    require(path[0] == WETH, "UniswapV2Router: INVALID_PATH");

    uint fee = msg.value / 100; // 1% fee
    uint amountAfterFee = msg.value - fee; // Remaining ETH after fee deduction

    // Transfer fee directly to the feeRecipient
    TransferHelper.safeTransferETH(feeRecipient, fee);

    // Recalculate amounts based on remaining ETH
    amounts = UniswapV2Library.getAmountsOut(factory, amountAfterFee, path);

    // Deposit ETH to WETH
    IWETH(WETH).deposit{value: amountAfterFee}();
    assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));

    // Execute main swap
    _swap(amounts, path, to, factory);

    return amounts;
}


   function swapTokensForExactETH(
    uint amountIn,
    address[] calldata path,
    address to,
    uint deadline,
    address factory
) external virtual override ensure(deadline) returns (uint[] memory amounts) {
    require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");

    // Calculate amounts for the main swap
    amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
    require(amounts[amounts.length - 1] > 0, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

    // Transfer tokens for the main swap
    address swapPair = UniswapV2Library.pairFor(factory, path[0], path[1]);
    TransferHelper.safeTransferFrom(path[0], msg.sender, swapPair, amountIn);

    // Execute the main swap
    _swap(amounts, path, address(this), factory);

    // Withdraw WETH to ETH
    uint ethOut = amounts[amounts.length - 1];
    IWETH(WETH).withdraw(ethOut);

    // Calculate and distribute fees
    uint feeAmount = (ethOut * 1) / 100; // 1% fee
    uint remainingEth = ethOut - feeAmount; // Remaining ETH after fee

    // Transfer the fee to the feeRecipient
    TransferHelper.safeTransferETH(feeRecipient, feeAmount);

    // Transfer the remaining ETH to the swapper
    TransferHelper.safeTransferETH(to, remainingEth);

    return amounts; // Return the amounts received by the user
}




  function swapExactTokensForETH(
    uint amountIn,
    address[] calldata path,
    address to,
    uint deadline,
    address factory
) external virtual override ensure(deadline) returns (uint[] memory amounts) {
    require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");

    // Calculate main swap amounts
    amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
    require(amounts[amounts.length - 1] > 0, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");

    // Transfer tokens for the swap
    address swapPair = UniswapV2Library.pairFor(factory, path[0], path[1]);
    TransferHelper.safeTransferFrom(path[0], msg.sender, swapPair, amountIn);

    // Execute the main swap
    _swap(amounts, path, address(this), factory);

    // Withdraw WETH to ETH
    uint ethOut = amounts[amounts.length - 1];
    IWETH(WETH).withdraw(ethOut);

    // Calculate and distribute fees
    uint feeAmount = (ethOut * 1) / 100; // 1% fee
    uint remainingEth = ethOut - feeAmount; // Remaining ETH after fee

    // Transfer the fee to the feeRecipient
    TransferHelper.safeTransferETH(feeRecipient, feeAmount);

    // Transfer the remaining ETH to the recipient
    TransferHelper.safeTransferETH(to, remainingEth);

    return amounts; // Return the amounts received by the user
}



   function swapETHForExactTokens(
    address[] calldata path,
    address to,
    uint deadline,
    address factory
) external virtual override payable ensure(deadline) returns (uint[] memory amounts) {
    require(path[0] == WETH, "UniswapV2Router: INVALID_PATH");

    // Calculate the 1% fee
    uint fee = (msg.value * 1) / 100; // 1% fee from msg.value
    uint amountAfterFee = msg.value - fee; // Remaining ETH after deducting the fee

    // Send the fee directly to the feeRecipient
    TransferHelper.safeTransferETH(feeRecipient, fee);

    // Calculate the maximum possible amount of tokens that can be purchased
    amounts = UniswapV2Library.getAmountsOut(factory, amountAfterFee, path);

    // Deposit the remaining ETH into WETH
    IWETH(WETH).deposit{value: amountAfterFee}();
    assert(IWETH(WETH).transfer(UniswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));

    // Perform the token swap
    _swap(amounts, path, to, factory);

    // Return the amounts swapped
    return amounts;
}



    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to, address factory) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = UniswapV2Library.sortTokens(input, output);
            IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = UniswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? UniswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
   
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint amountIn,
    address[] calldata path,
    address[] calldata feepath,
    address to,
    uint deadline,
    address factory
) external virtual override ensure(deadline) {
    // Calculate and transfer the fee
    uint feeAmountIn = (amountIn * 1) / 100; // 1% fee
    TransferHelper.safeTransferFrom(
        feepath[0],
        msg.sender,
        UniswapV2Library.pairFor(factory, feepath[0], feepath[1]),
        feeAmountIn
    );

    // Calculate the amount after fee deduction
    uint amountAfterFee = amountIn - feeAmountIn;

    // Transfer the main swap tokens to the liquidity pair
    TransferHelper.safeTransferFrom(
        path[0],
        msg.sender,
        UniswapV2Library.pairFor(factory, path[0], path[1]),
        amountAfterFee
    );

    // Execute fee swap
    _swapSupportingFeeOnTransferTokens(feepath, feeRecipient, factory);

    // Record balance before the main swap
    uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);

    // Execute the main token swap
    _swapSupportingFeeOnTransferTokens(path, to, factory);

    // Validate output amounts inline
    require(
        IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountAfterFee,
        "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
    );
}


function swapExactETHForTokensSupportingFeeOnTransferTokens(
    address[] calldata path,
    address to,
    uint deadline,
    address factory
) external virtual override payable ensure(deadline) {
    require(path[0] == WETH, "UniswapV2Router: INVALID_PATH");

    // Calculate fee
    uint fee = (msg.value * 1) / 100; // 1% fee
    uint amountAfterFee = msg.value - fee;

    // Send fee directly to the feeRecipient
    TransferHelper.safeTransferETH(feeRecipient, fee);

    // Deposit remaining ETH into WETH
    IWETH(WETH).deposit{value: amountAfterFee}();
    address swapPair = UniswapV2Library.pairFor(factory, path[0], path[1]);
    assert(IWETH(WETH).transfer(swapPair, amountAfterFee));

    // Record balance before the swap
    uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);

    // Execute the swap
    _swapSupportingFeeOnTransferTokens(path, to, factory);

    // Validate output amounts
    require(
        IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountAfterFee,
        "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
    );
}

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
    uint amountIn,
    address[] calldata path,
    address[] calldata feepath,
    address to,
    uint deadline,
    address factory
) external virtual override ensure(deadline) {
    require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");

    // Calculate fee
    uint feeAmountIn = (amountIn * 1) / 100; // 1% fee
    uint amountAfterFee = amountIn - feeAmountIn;

    // Transfer fee tokens to the liquidity pair
    address feePair = UniswapV2Library.pairFor(factory, feepath[0], feepath[1]);
    TransferHelper.safeTransferFrom(feepath[0], msg.sender, feePair, feeAmountIn);

    // Transfer main swap tokens to the liquidity pair
    address swapPair = UniswapV2Library.pairFor(factory, path[0], path[1]);
    TransferHelper.safeTransferFrom(path[0], msg.sender, swapPair, amountAfterFee);

    // Execute fee swap
    _swapSupportingFeeOnTransferTokens(feepath, feeRecipient, factory);

    // Execute main swap
    _swapSupportingFeeOnTransferTokens(path, address(this), factory);

    // Withdraw WETH and transfer ETH
    uint amountOut = IERC20(WETH).balanceOf(address(this));
    IWETH(WETH).withdraw(amountOut);

    // Send ETH to recipient
    TransferHelper.safeTransferETH(to, amountOut);
}

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return UniswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path, address factory)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsOut(factory, amountIn, path);
    }
    
    function getAmountsIn(uint amountOut, address[] memory path, address factory)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return UniswapV2Library.getAmountsIn(factory, amountOut, path);
    }


    function buyNFTs(MarketplaceParams[] calldata params) external payable override returns (bool[] memory successes) {
    successes = new bool[](params.length);
    uint256 totalETHSpent;
    uint256 totalFee;

    for (uint256 i = 0; i < params.length; i++) {
        MarketplaceParams calldata p = params[i];
        
        // Attempt to buy from Thirdweb Marketplace
        successes[i] = _buyFromThirdweb(p);

        if (p.currency == address(0)) {
            totalETHSpent += p.price;
        }
    }

    // Calculate the 1% fee
    totalFee = (totalETHSpent * 1) / 100;

    // Ensure sufficient ETH was provided
    require(totalETHSpent + totalFee <= msg.value, "Insufficient ETH provided");

    // Transfer the fee to the fee recipient
    if (totalFee > 0) {
        (bool feeSuccess, ) = feeRecipient.call{value: totalFee}("");
        require(feeSuccess, "Fee transfer failed");
    }

    // Refund excess ETH if any
    uint256 refund = msg.value - (totalETHSpent + totalFee);
    if (refund > 0) {
        (bool refundSuccess, ) = msg.sender.call{value: refund}("");
        require(refundSuccess, "Refund transfer failed");
    }
}

    /**
 * @dev Internal function to buy NFT from Thirdweb Marketplace.
 */
function _buyFromThirdweb(MarketplaceParams calldata params) internal returns (bool) {
    require(params.currency == address(0), "Only ETH purchases supported for Thirdweb");
    require(params.price <= msg.value, "Insufficient ETH sent for Thirdweb purchase");

    // Decode the listing ID from params.data
    uint256 listingId = abi.decode(params.data, (uint256));

    (bool success, ) = params.marketplace.call{value: params.price}(
        abi.encodeWithSignature(
            "buyFromListing(uint256,address,uint256,address,uint256)",
            listingId, // Listing ID
            msg.sender, // Buyer address
            params.quantity, // Quantity
            params.currency, // Currency (ETH or ERC20)
            params.price // Price per token
        )
    );
    return success;
}

}

// a library for performing overflow-safe math, courtesy of DappHub (https://github.com/dapphub/ds-math)

library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
}


    

    

library UniswapV2Library {
    using SafeMath for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
   function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
    (address token0, address token1) = sortTokens(tokenA, tokenB);
    pair = address(uint160(uint256(keccak256(abi.encodePacked(
        hex'ff',
        factory,
        keccak256(abi.encodePacked(token0, token1)),
        hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
    )))));
    }


    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}

   
// helper methods for interacting with ERC20 tokens and sending ETH that do not consistently return true/false
library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}
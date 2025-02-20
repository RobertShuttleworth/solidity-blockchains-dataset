// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

interface INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    function mint(MintParams calldata params) external payable returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    );
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);
}

contract ATZAIN {
    INonfungiblePositionManager posMan = INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    address constant weth = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; // Polygon wMatic
    uint256 private _totalSupply = 24000000 * 10 ** 18;
    uint private airdropSupply = _totalSupply / 5; // 20% of total supply
    uint private liquiditySupply = _totalSupply - airdropSupply; // Remaining supply for liquidity
    uint24 constant fee = 500;
    uint160 constant sqrtPriceX96 = 79228162514264337593543950336; // ~ 1:1
    int24 minTick;
    int24 maxTick;
    address public pool;
    address token0;
    address token1;
    uint amount0Desired;
    uint amount1Desired;
    string public logoURI;

    string private _name = "Token ATZAIN";
    string private _symbol = "ATZAIN";
    uint8 private _decimals = 18;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    constructor(address airdropRecipient) {
        require(airdropRecipient != address(0), "Invalid airdrop recipient");

        // Mint airdrop tokens
        _mint(airdropRecipient, airdropSupply);

        // Mint liquidity tokens to the contract
        _mint(address(this), liquiditySupply);

        fixOrdering();
        pool = posMan.createAndInitializePoolIfNecessary(token0, token1, fee, sqrtPriceX96);

        logoURI = "https://iili.io/2kSQtUJ.jpg"; // Replace with your logo URL or IPFS hash
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "Transfer from the zero address");
        require(to != address(0), "Transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "Transfer amount exceeds balance");
        unchecked {
            _balances[from] -= amount;
            _balances[to] += amount;
        }
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowances[owner][spender] = amount;
    }

    function addLiquidity() public {
        approve(address(posMan), liquiditySupply);
        posMan.mint(INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: minTick,
            tickUpper: maxTick,
            amount0Desired: amount0Desired,
            amount1Desired: amount1Desired,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp + 1200
        }));
    }

    function fixOrdering() private {
        if (address(this) < weth) {
            token0 = address(this);
            token1 = weth;
            amount0Desired = liquiditySupply;
            amount1Desired = 0;
            minTick = 0;
            maxTick = 887270;
        } else {
            token0 = weth;
            token1 = address(this);
            amount0Desired = 0;
            amount1Desired = liquiditySupply;
            minTick = -887270;
            maxTick = 0;
        }
    }
}
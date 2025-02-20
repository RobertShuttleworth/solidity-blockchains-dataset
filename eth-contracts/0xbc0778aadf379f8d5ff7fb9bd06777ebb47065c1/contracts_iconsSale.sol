// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./chainlink_contracts_src_v0.8_interfaces_AggregatorV3Interface.sol";

interface IERC20 {
    function transfer(address to, uint value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract IconCommunity {
    address internal admin;
    address internal devrel;
    address internal liquidityPool;
    uint tokenPrice;
    AggregatorV3Interface internal priceFeed;
    IERC20 public iconToken;

    struct UserData {
        uint iconsReceived;
        uint totalCommitment;
    }

    struct adminData {
        uint totalUsers;
        bool saleActive;
    }

    mapping(address => UserData) public userData;
    adminData public AdminData;

    event UserJoined(address indexed user, uint ethAmount, uint tokensIssued);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    constructor(address _devrel, address _liquidityPool, IERC20 _iconToken, address _priceFeed, uint _tokenPrice) {
        require(_devrel != address(0) && _liquidityPool != address(0), "Invalid address");
        require(address(_iconToken) != address(0), "Invalid token address");

        admin = msg.sender;
        devrel = _devrel;
        liquidityPool = _liquidityPool;
        iconToken = _iconToken;
        tokenPrice = _tokenPrice;

        priceFeed = AggregatorV3Interface(_priceFeed);
        AdminData.saleActive = true;
    }

    function joinIconCommunity() public payable {
        require(msg.value > 0, "Ether amount must be greater than zero");

        uint pricePerToken = convertUSDToETH(tokenPrice);
        uint amount = msg.value / pricePerToken;
        uint amountToDevrel = ((msg.value) * 15) / 100;
        uint amountToLiquidityPool = ((msg.value) * 85) / 100;

        payable(devrel).transfer(amountToDevrel);
        payable(liquidityPool).transfer(amountToLiquidityPool);

        require(iconToken.transfer(msg.sender, (amount *10**18)), "Token transfer failed");

        UserData storage user = userData[msg.sender];
        if (user.totalCommitment == 0) {
            AdminData.totalUsers++;
        }
        user.iconsReceived += amount;
        user.totalCommitment += msg.value;

        emit UserJoined(msg.sender, msg.value, amount);
    }

    function updateAddresses(address _devrel, address _liquidityPool, uint _tokenPrice) external onlyAdmin {
        require(_devrel != address(0) && _liquidityPool != address(0), "Invalid address");
        devrel = _devrel;
        liquidityPool = _liquidityPool;
        tokenPrice = _tokenPrice;
    }

    /**
     * @dev Fetches the latest ETH/USD price from Chainlink
     * @return price - the latest price with 8 decimals
     */
    function getLatestPrice() public view returns (int) {
        (
            ,
            int price, // Latest ETH/USD price
            ,
            ,
            
        ) = priceFeed.latestRoundData();
        return price;
    }

    /**
     * @dev Converts a given USD amount to ETH
     * @param usdAmount - the USD amount in cents (e.g., $0.15 = 15 cents)
     * @return ethAmount - the equivalent amount of ETH (18 decimals)
     * @dev 
     *      4 Decimal Place
     *      samples - $0.15 = 1500
     *              - $1000 = 10000000
     *      
     */
    function convertUSDToETH(uint usdAmount) public view returns (uint) {
        // Fetch the latest ETH/USD price
        int ethPrice = getLatestPrice();
        require(ethPrice > 0, "Invalid ETH price");

        uint adjustedPrice = uint(ethPrice) / 10**4;

        // Calculate ETH amount: (USD amount * 10^18) / ETH price
        uint ethAmount = (usdAmount * 10**18) / uint(adjustedPrice);

        return ethAmount;
    }

    function endIconSale() public onlyAdmin {
        uint tokenBal = iconToken.balanceOf(address(this));
        require(iconToken.transfer(liquidityPool, tokenBal), "Token transfer failed");
    }

    receive() external payable {
        joinIconCommunity();
    }
}
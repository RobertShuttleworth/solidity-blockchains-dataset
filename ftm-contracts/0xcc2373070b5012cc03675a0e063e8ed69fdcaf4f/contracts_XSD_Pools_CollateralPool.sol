
// SPDX-License-Identifier: MIT
/*
BBBBBBBBBBBBBBBBB                                       kkkkkkkk        XXXXXXX       XXXXXXX
B::::::::::::::::B                                      k::::::k        X:::::X       X:::::X
B::::::BBBBBB:::::B                                     k::::::k        X:::::X       X:::::X
BB:::::B     B:::::B                                    k::::::k        X::::::X     X::::::X
  B::::B     B:::::B  aaaaaaaaaaaaa  nnnn  nnnnnnnnn    k:::::k kkkkkkk XXX:::::X   X:::::XXX
  B::::B     B:::::B  a::::::::::::a n:::nn::::::::nn   k:::::k k:::::k     X:::::X X:::::X
  B::::BBBBBB:::::B   aaaaaaaaa:::::an::::::::::::::nn  k:::::k k:::::k      X:::::X:::::X
  B:::::::::::::BB             a::::ann:::::::::::::::n k:::::k k:::::k       X:::::::::X
  B::::BBBBBB:::::B    aaaaaaa:::::a  n:::::nnnn:::::n k::::::k:::::k         X:::::::::X
  B::::B     B:::::B  aa::::::::::::a  n::::n    n::::n k:::::::::::k        X:::::X:::::X
  B::::B     B:::::B a::::aaaa::::::a  n::::n    n::::n k:::::::::::k       X:::::X X:::::X
  B::::B     B:::::Ba::::a    a:::::a  n::::n    n::::n k::::::k:::::k   XXX:::::X   X:::::XXX
BB:::::BBBBBB::::::Ba::::a    a:::::a  n::::n    n::::nk::::::k k:::::k  X::::::X     X::::::X
B:::::::::::::::::B a:::::aaaa::::::a  n::::n    n::::nk::::::k k:::::k  X:::::X       X:::::X
B::::::::::::::::B   a::::::::::aa:::a n::::n    n::::nk::::::k k:::::k  X:::::X       X:::::X
BBBBBBBBBBBBBBBBB     aaaaaaaaaa  aaaa nnnnnn    nnnnnnkkkkkkkk kkkkkkk  XXXXXXX       XXXXXXX


                                          Currency Creators Manifesto

Our world faces an urgent crisis of currency manipulation, theft and inflation.  Under the current system, currency is controlled by and benefits elite families, governments and large banking institutions.  We believe currencies should be minted by and benefit the individual, not the establishment.  It is time to take back the control of and the freedom that money can provide.

BankX is rebuilding the legacy banking system from the ground up by providing you with the capability to create currency and be in complete control of wealth creation with a concept we call ‘Individual Created Digital Currency’ (ICDC). You own the collateral.  You mint currency.  You earn interest.  You leverage without the risk of liquidation.  You stake to earn even more returns.  All of this is done with complete autonomy and decentralization.  BankX has built a stablecoin for Individual Freedom.

BankX is the antidote for the malevolent financial system bringing in a new future of freedom where you are in complete control with no middlemen, bank or central bank between you and your finances. This capability to create currency and be in complete control of wealth creation will be in the hands of every individual that uses BankX.

By 2030, we will rid the world of the corrupt, tyrannical and incompetent banking system replacing it with a system where billions of people will be in complete control of their financial future.  Everyone will be given ultimate freedom to use their assets to create currency, earn interest and multiply returns to accomplish their individual goals.  The mission of BankX is to be the first to mint $1 trillion in stablecoin. 

We will bring about this transformation by attracting people that believe what we believe.  We will partner with other blockchain protocols and build decentralized applications that drive even more usage.  Finally, we will deploy a private network that is never connected to the Internet to communicate between counterparties, that allows for blockchain-to-blockchain interoperability and stores private keys and cryptocurrency wallets.  Our ecosystem, network and platform has never been seen in the market and provides us with a long term sustainable competitive advantage.

We value individual freedom.
We believe in financial autonomy.
We are anti-establishment.
We envision a future of self-empowerment.

*/
pragma solidity ^0.8.0;

import "./contracts_XSD_XSDStablecoin.sol";
import "./contracts_ERC20_IWETH.sol";
import "./contracts_Utils_Initializable.sol";
import "./contracts_XSD_Pools_CollateralPoolLibrary.sol";
import "./contracts_BankX_BankXToken.sol";
import "./contracts_XSD_Pools_Interfaces_IXSDWETHpool.sol";
import "./contracts_XSD_Pools_Interfaces_IBankXWETHpool.sol";
import './contracts_Oracle_Interfaces_IPIDController.sol';
import './uniswap_lib_contracts_libraries_TransferHelper.sol';
import './openzeppelin_contracts_security_ReentrancyGuard.sol';

/**
 * @title CollateralPool
 * @dev This contract manages the collateral for the XSD stablecoin. It handles minting and redemption of XSD, both 1:1 and fractional.
 * It also controls the interest calculation for minting and redemption processes.
 */
contract CollateralPool is Initializable,ReentrancyGuard {
    /* ========== STATE VARIABLES ========== */

    /// @notice Address of the WETH contract
    address public WETH;

    /// @notice Address of the smart contract owner
    address public smartcontract_owner;

    /// @notice Address of the XSD contract
    address public xsd_contract_address;

    /// @notice Address of the BankX contract
    address public bankx_contract_address;

    /// @notice Address of the XSD-WETH pool
    address public xsdweth_pool;

    /// @notice Address of the BankX-WETH pool
    address public bankxweth_pool;

    /// @notice Address of the PID controller contract
    address public pid_address;

    /// @notice Instance of the BankX token
    BankXToken private BankX;

    /// @notice Instance of the XSD stablecoin
    XSDStablecoin private XSD;

    /// @notice Instance of the PID controller
    IPIDController private pid_controller;

    /// @notice Collateralized XSD in the pool
    uint256 public collat_XSD;

    /// @notice Flag indicating if minting is paused
    bool public mint_paused;

    /// @notice Flag indicating if redeeming is paused
    bool public redeem_paused;

    /// @notice Flag indicating if buybacks are paused
    bool public buyback_paused;

    /// @notice Structure to store minting information
    struct MintInfo {
        uint256 accum_interest; // accumulated interest from previous mints
        uint256 interest_rate; // interest rate at that particular timestamp
        uint256 time; // last timestamp
        uint256 amount; // XSD amount minted
    }

    /// @notice Mapping to store mint information for each address
    mapping(address => MintInfo) public mintMapping; 

    /// @notice Mapping to store BankX token balances for redemption
    mapping(address => uint256) public redeemBankXTokenBalances;

    /// @notice Mapping to store BankX balances for redemption
    mapping(address => uint256) public redeemBankXBalances;

    /// @notice Mapping to store collateral balances for redemption
    mapping(address => uint256) public redeemCollateralBalances;

    /// @notice Mapping to store vesting timestamps
    mapping(address => uint256) public vestingtimestamp;

    /// @notice Unclaimed collateral in the pool
    uint256 public unclaimedPoolCollateral;

    /// @notice Unclaimed BankX in the pool
    uint256 public unclaimedPoolBankX;

    /// @notice Equivalent collateral value in d18
    uint256 public collateral_equivalent_d18;

    /// @notice Count of minted BankX
    uint256 public bankx_minted_count;

    /// @notice Mapping to store the last redeemed block for each address
    mapping(address => uint256) public lastRedeemed;

    /// @notice Block delay to prevent flash mint attacks
    uint256 public block_delay;

    /* ========== MODIFIERS ========== */

    /**
     * @dev Ensures the transaction is executed before the specified deadline
     * @param deadline The time by which the transaction must be completed
     */
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'COLLATERALPOOL:EXPIRED');
        _;
    }

    /**
     * @dev Ensures the function is only called by the contract owner
     */
    modifier onlyByOwner() {
        require(msg.sender == smartcontract_owner, "COLLATERALPOOL:FORBIDDEN");
        _;
    }

    /**
     * @dev Ensures minting is not paused
     */
    modifier mintPaused() {
        require(!mint_paused, "COLLATERALPOOL:PAUSED");
        _;
    }

    /**
     * @dev Ensures redeeming is not paused
     */
    modifier redeemPaused() {
        require(!redeem_paused, "COLLATERALPOOL:PAUSED");
        _;
    }

    /**
     * @dev Ensures a block delay is maintained between mint and redeem actions
     */
    modifier blockDelay(){
        require(((pid_controller.lastPriceCheck(msg.sender).lastpricecheck + block_delay) <= block.number) && (pid_controller.lastPriceCheck(msg.sender).pricecheck), "COLLATERALPOOL:BLOCKDELAY");
        _;
        pid_controller.setPriceCheck(msg.sender);
    }
 
    /* ========== FUNCTIONS ========== */

    /**
     * @notice Initialize the CollateralPool contract
     * @dev This function sets the initial state variables
     * @param _weth Address of the WETH contract
     * @param _smartcontract_owner Address of the contract owner
     * @param _xsd_contract_address Address of the XSD contract
     * @param _bankx_contract_address Address of the BankX contract
     * @param _xsdweth_pool Address of the XSD-WETH pool
     * @param _bankxweth_pool Address of the BankX-WETH pool
     * @param _pid_address Address of the PID controller contract
     */
    function initialize(
        address _weth,
        address _smartcontract_owner,
        address _xsd_contract_address,
        address _bankx_contract_address,
        address _xsdweth_pool,
        address _bankxweth_pool,
        address _pid_address
    ) public initializer{
        WETH = _weth;
        smartcontract_owner = _smartcontract_owner;
        xsd_contract_address = _xsd_contract_address;
        bankx_contract_address = _bankx_contract_address;
        xsdweth_pool = _xsdweth_pool;
        bankxweth_pool = _bankxweth_pool;
        pid_address = _pid_address;

        BankX = BankXToken(bankx_contract_address);
        XSD = XSDStablecoin(xsd_contract_address);
        pid_controller = IPIDController(pid_address);
        block_delay = 2;
    }

    /* ========== VIEWS ========== */
/**
 * @dev This function is used to receive ETH from the WETH contract.
 * It ensures that only the WETH contract can send ETH to this contract.
 */
receive() external payable {
    assert(msg.sender == WETH);
}

/**
 * @dev Returns the dollar value of collateral held in this XSD pool.
 * @return uint256 The dollar value of the collateral in the pool.
 */
function collatDollarBalance() public view returns (uint256) {
    return ((IWETH(WETH).balanceOf(address(this)) * XSD.eth_usd_price()) / (1e6));
}

/**
 * @dev Returns the value of excess collateral held in this XSD pool,
 * compared to what is needed to maintain the global collateral ratio.
 * @return uint256 The value of excess collateral in the pool.
 */
function availableExcessCollatDV() public view returns (uint256) {
    uint256 global_collateral_ratio = pid_controller.global_collateral_ratio();
    uint256 global_collat_value = collatDollarBalance();

    if (global_collateral_ratio > (1e6)) global_collateral_ratio = (1e6); // Handles an overcollateralized contract with CR > 1
    uint256 required_collat_dollar_value_d18 = ((collat_XSD) * global_collateral_ratio * (XSD.xag_usd_price() * (1e4)) / (311035)) / (1e12); // Calculates collateral needed to back each 1 XSD with $1 of collateral at current collat ratio
    if ((global_collat_value - unclaimedPoolCollateral) > required_collat_dollar_value_d18) return (global_collat_value - unclaimedPoolCollateral - required_collat_dollar_value_d18);
    else return 0;
}

/* ========== INTERNAL FUNCTIONS ======== */

/**
 * @dev Calculates and updates the interest for minting XSD.
 * @param xsd_amount The amount of XSD minted.
 * @param sender The address of the sender who minted XSD.
 */
function mintInterestCalc(uint xsd_amount, address sender) internal {
    (mintMapping[sender].accum_interest, mintMapping[sender].interest_rate, mintMapping[sender].time, mintMapping[sender].amount) = CollateralPoolLibrary.calcMintInterest(xsd_amount, XSD.xag_usd_price(), pid_controller.interest_rate(), mintMapping[sender].accum_interest, mintMapping[sender].interest_rate, mintMapping[sender].time, mintMapping[sender].amount);
}

/**
 * @dev Calculates and updates the interest for redeeming XSD.
 * @param xsd_amount The amount of XSD redeemed.
 * @param sender The address of the sender who redeemed XSD.
 */
function redeemInterestCalc(uint xsd_amount, address sender) internal {
    (mintMapping[sender].accum_interest, mintMapping[sender].interest_rate, mintMapping[sender].time, mintMapping[sender].amount) = CollateralPoolLibrary.calcRedemptionInterest(xsd_amount, XSD.xag_usd_price(), mintMapping[sender].accum_interest, mintMapping[sender].interest_rate, mintMapping[sender].time, mintMapping[sender].amount);
}


    /* ========== PUBLIC FUNCTIONS ========== */
    /**
     * @notice Mints XSD tokens by providing collateral in ETH.
     * @param XSD_out_min Minimum amount of XSD tokens expected.
     * @param deadline The deadline timestamp by which the transaction should be confirmed.
     * @dev Requires ETH collateral to be greater than 0 and global collateral ratio to be at least 1.
     */
    function mint1t1XSD(uint256 XSD_out_min, uint256 deadline) external ensure(deadline) payable nonReentrant mintPaused{
        require(msg.value>0, "Invalid collateral amount");
        require(pid_controller.global_collateral_ratio() >= (1e6), "Collateral ratio must be >= 1");
        (uint256 xsd_amount_d18) = CollateralPoolLibrary.calcMint1t1XSD(
            XSD.eth_usd_price(),
            XSD.xag_usd_price(),
            msg.value
        ); //1 XSD for each $1 worth of collateral
        require(XSD_out_min <= xsd_amount_d18, "INSUFFICIENT OUTPUT");
        mintInterestCalc(xsd_amount_d18,msg.sender);
        IWETH(WETH).deposit{value: msg.value}();
        assert(IWETH(WETH).transfer(address(this), msg.value));
        collat_XSD = collat_XSD + xsd_amount_d18;
        XSD.pool_mint(msg.sender, xsd_amount_d18);
    }
/**
     * @notice Mints XSD tokens algorithmically using BankX tokens.
     * @param bankx_amount_d18 Amount of BankX tokens to be used for minting.
     * @param XSD_out_min Minimum amount of XSD tokens expected.
     * @param deadline The deadline timestamp by which the transaction should be confirmed.
     * @dev Requires global collateral ratio to be 0.
     */
    function mintAlgorithmicXSD(uint256 bankx_amount_d18, uint256 XSD_out_min, uint256 deadline) external ensure(deadline) nonReentrant mintPaused blockDelay{
        uint256 xag_usd_price = XSD.xag_usd_price();
        require(pid_controller.global_collateral_ratio() == 0, "Collateral ratio must be 0");
        (uint256 xsd_amount_d18) = CollateralPoolLibrary.calcMintAlgorithmicXSD(
            pid_controller.bankx_updated_price(), 
            xag_usd_price,
            bankx_amount_d18
        );
        require(XSD_out_min <= xsd_amount_d18, "INSUFFICIENT OUTPUT");
        mintInterestCalc(xsd_amount_d18,msg.sender);
        collat_XSD = collat_XSD + xsd_amount_d18;
        bankx_minted_count = bankx_minted_count + bankx_amount_d18;
        BankX.pool_burn_from(msg.sender, bankx_amount_d18);
        XSD.pool_mint(msg.sender, xsd_amount_d18);
    }
    /**
     * @notice Mints XSD tokens fractionally using both BankX tokens and ETH collateral.
     * @param XSD_amount Minimum amount of XSD tokens expected.
     * @param bankx_amount amount of bankx tokens required for mint
     * @param deadline The deadline timestamp by which the transaction should be confirmed.
     * @dev Requires collateral ratio to be greater than 0% and less than 100%.
     */
    function mintFractionalXSD(uint256 XSD_amount,uint bankx_amount, uint256 deadline) external ensure(deadline) payable nonReentrant mintPaused blockDelay{
        uint256 global_collateral_ratio = pid_controller.global_collateral_ratio();
        require(global_collateral_ratio < (1e6) && global_collateral_ratio > 0, "Collateral ratio needs to be between .000001 and .999999");
        uint neededWETH = (XSD_amount * pid_controller.neededWETH())/(1e6); // precision of 1e18
        uint neededBankX = (XSD_amount * pid_controller.neededBankX())/(1e6); // precision of 1e18
        require(bankx_amount >= neededBankX,"INSUFFICIENT OUTPUT: BankX");
        require(msg.value >= neededWETH,"INSUFFICIENT OUTPUT: WETH");
        mintInterestCalc(XSD_amount,msg.sender);
        bankx_minted_count = bankx_minted_count + neededBankX;
        BankX.pool_burn_from(msg.sender, neededBankX);
        IWETH(WETH).deposit{value: msg.value}();
        assert(IWETH(WETH).transfer(address(this), msg.value));
        collat_XSD = collat_XSD + XSD_amount;
        XSD.pool_mint(msg.sender, XSD_amount);
    }
        /**
     * @dev Redeem XSD for collateral with 1:1 backing.
     * @param XSD_amount The amount of XSD to redeem.
     * @param COLLATERAL_out_min The minimum amount of collateral to receive.
     * @param deadline The timestamp by which the redemption must be completed.
     */
    function redeem1t1XSD(uint256 XSD_amount, uint256 COLLATERAL_out_min, uint256 deadline) external ensure(deadline) nonReentrant redeemPaused blockDelay{
        require(!pid_controller.bucket3(), "Cannot withdraw in times of deficit");
        require(pid_controller.global_collateral_ratio() == (1e6), "Collateral ratio must be == 1");
        require(XSD_amount<=mintMapping[msg.sender].amount, "OVERREDEMPTION ERROR");
        // convert xsd to $ and then to collateral value
        (uint256 XSD_dollar,uint256 collateral_needed) = CollateralPoolLibrary.calcRedeem1t1XSD(
            XSD.eth_usd_price(),
            XSD.xag_usd_price(),
            XSD_amount
        );
        uint total_xsd_amount = mintMapping[msg.sender].amount;
        require(collateral_needed <= (IWETH(WETH).balanceOf(address(this))-unclaimedPoolCollateral), "Not enough collateral in pool");
        require(COLLATERAL_out_min <= collateral_needed, "INSUFFICIENT OUTPUT");
        redeemInterestCalc(XSD_amount, msg.sender);
        uint current_accum_interest = (XSD_amount*mintMapping[msg.sender].accum_interest)/total_xsd_amount;
        redeemBankXBalances[msg.sender] = (redeemBankXBalances[msg.sender]+current_accum_interest);
        redeemCollateralBalances[msg.sender] = redeemCollateralBalances[msg.sender]+XSD_dollar;
        unclaimedPoolCollateral = unclaimedPoolCollateral+XSD_dollar;
        lastRedeemed[msg.sender] = block.number;
        uint256 bankx_amount = (current_accum_interest*1e6)/pid_controller.bankx_updated_price();
        unclaimedPoolBankX = (unclaimedPoolBankX+bankx_amount);
        redeemBankXTokenBalances[msg.sender] = (redeemBankXTokenBalances[msg.sender]+bankx_amount);
        collat_XSD -= XSD_amount;
        mintMapping[msg.sender].accum_interest = (mintMapping[msg.sender].accum_interest - current_accum_interest);
        XSD.pool_burn_from(msg.sender, XSD_amount);
        BankX.pool_mint(address(this), bankx_amount);
    }

    /**
     * @dev Redeem fractional XSD for collateral and BankX.
     * @param XSD_amount The amount of XSD to redeem.
     * @param BankX_out_min The minimum amount of BankX to receive.
     * @param COLLATERAL_out_min The minimum amount of collateral to receive.
     * @param deadline The timestamp by which the redemption must be completed.
     */
    function redeemFractionalXSD(uint256 XSD_amount, uint256 BankX_out_min, uint256 COLLATERAL_out_min, uint256 deadline) external ensure(deadline) nonReentrant redeemPaused blockDelay{
        require(!pid_controller.bucket3(), "Cannot withdraw in times of deficit");
        require(XSD_amount<=mintMapping[msg.sender].amount, "OVERREDEMPTION ERROR");
        uint neededWETH = (XSD_amount * pid_controller.neededWETH())/(1e6); // precision of 1e18
        uint neededBankX = (XSD_amount * pid_controller.neededBankX())/(1e6); // precision of 1e18
        uint weth_dollar_value = (neededWETH * XSD.eth_usd_price())/1e6; // precision of 1e18
        uint bankx_dollar_value = (neededBankX * pid_controller.bankx_updated_price())/1e6; //precision of 1e18
        require(neededWETH <= (IWETH(WETH).balanceOf(address(this))-unclaimedPoolCollateral), "Not enough collateral in pool");
        require(COLLATERAL_out_min <= neededWETH, "INSUFFICIENT OUTPUT [collateral]");
        require(BankX_out_min <= neededBankX, "INSUFFICIENT OUTPUT [BankX]");

        redeemCollateralBalances[msg.sender] = redeemCollateralBalances[msg.sender]+weth_dollar_value;
        unclaimedPoolCollateral = unclaimedPoolCollateral+weth_dollar_value;
        lastRedeemed[msg.sender] = block.number;
        uint total_xsd_amount = mintMapping[msg.sender].amount;
        redeemInterestCalc(XSD_amount, msg.sender);
        uint current_accum_interest = (XSD_amount*mintMapping[msg.sender].accum_interest)/total_xsd_amount;
        redeemBankXBalances[msg.sender] = redeemBankXBalances[msg.sender]+current_accum_interest;
        neededBankX = neededBankX + ((current_accum_interest*1e6)/pid_controller.bankx_updated_price());
        mintMapping[msg.sender].accum_interest = mintMapping[msg.sender].accum_interest - current_accum_interest;
        redeemBankXBalances[msg.sender] = redeemBankXBalances[msg.sender]+bankx_dollar_value;
        unclaimedPoolBankX = unclaimedPoolBankX+neededBankX;
        redeemBankXTokenBalances[msg.sender] = (redeemBankXTokenBalances[msg.sender]+neededBankX);
        collat_XSD -= XSD_amount;    
        XSD.pool_burn_from(msg.sender, XSD_amount);
        BankX.pool_mint(address(this), neededBankX);
    }

    /**
     * @dev Redeem XSD for BankX with 0% collateral backing.
     * @param XSD_amount The amount of XSD to redeem.
     * @param BankX_out_min The minimum amount of BankX to receive.
     * @param deadline The timestamp by which the redemption must be completed.
     */
    function redeemAlgorithmicXSD(uint256 XSD_amount, uint256 BankX_out_min, uint256 deadline) external ensure(deadline) nonReentrant redeemPaused blockDelay{
        require(!pid_controller.bucket3(), "Cannot withdraw in times of deficit");
        require(XSD_amount<=mintMapping[msg.sender].amount, "OVERREDEMPTION ERROR");
        require(pid_controller.global_collateral_ratio() == 0, "Collateral ratio must be 0"); 
        uint256 bankx_dollar_value_d18 = (XSD_amount*XSD.xag_usd_price())/(31103477);

        uint256 bankx_amount = (bankx_dollar_value_d18*1e6)/pid_controller.bankx_updated_price();
        
        lastRedeemed[msg.sender] = block.number;
        uint total_xsd_amount = mintMapping[msg.sender].amount;
        require(BankX_out_min <= bankx_amount, "INSUFFICIENT OUTPUT");
        redeemInterestCalc(XSD_amount, msg.sender);
        uint current_accum_interest = XSD_amount*mintMapping[msg.sender].accum_interest/total_xsd_amount; //precision of 6
        redeemBankXBalances[msg.sender] = (redeemBankXBalances[msg.sender]+current_accum_interest);
        bankx_amount = bankx_amount + ((current_accum_interest*1e6)/pid_controller.bankx_updated_price());
        mintMapping[msg.sender].accum_interest = (mintMapping[msg.sender].accum_interest - current_accum_interest);
        redeemBankXBalances[msg.sender] = redeemBankXBalances[msg.sender]+bankx_dollar_value_d18;
        unclaimedPoolBankX = (unclaimedPoolBankX+bankx_amount);
        redeemBankXTokenBalances[msg.sender] = (redeemBankXTokenBalances[msg.sender]+bankx_amount);
        collat_XSD -= XSD_amount;
        XSD.pool_burn_from(msg.sender, XSD_amount);
        BankX.pool_mint(address(this), bankx_amount);
    }


        /**
     * @notice After a redemption happens, this function transfers the newly minted BankX and owed collateral 
     *         from this pool contract to the user. Redemption is split into two functions to prevent flash loans 
     *         from being able to take out XSD/collateral from the system, use an AMM to trade the new price, and 
     *         then mint back into the system.
     * @dev Uses Checks-Effects-Interactions pattern to prevent reentrancy attacks.
     */
    function collectRedemption() external nonReentrant redeemPaused blockDelay {
        require(!pid_controller.bucket3(), "Cannot withdraw in times of deficit");
        require(((lastRedeemed[msg.sender] + (block_delay)) <= block.number), "Must wait for redeem specific block_delay");
        uint CollateralDollarAmount;
        uint BankXAmount;
        uint CollateralAmount;

        // Use Checks-Effects-Interactions pattern
        if (redeemBankXBalances[msg.sender] > 0) {
            BankXAmount = redeemBankXTokenBalances[msg.sender];
            redeemBankXBalances[msg.sender] = 0;
            redeemBankXTokenBalances[msg.sender] = 0;
            unclaimedPoolBankX = unclaimedPoolBankX - BankXAmount;
            TransferHelper.safeTransfer(address(BankX), msg.sender, BankXAmount);
        }
        
        if (redeemCollateralBalances[msg.sender] > 0) {
            CollateralDollarAmount = redeemCollateralBalances[msg.sender];
            CollateralAmount = (CollateralDollarAmount * 1e6) / XSD.eth_usd_price();
            redeemCollateralBalances[msg.sender] = 0;
            unclaimedPoolCollateral = unclaimedPoolCollateral - CollateralDollarAmount;
            IWETH(WETH).withdraw(CollateralAmount); // try to unwrap eth in the redeem
            TransferHelper.safeTransferETH(msg.sender, CollateralAmount);
        }
    }

    /**
     * @notice Allows a BankX holder to have the protocol buy back BankX with excess collateral value from a 
     *         desired collateral pool. This can also happen if the collateral ratio > 1.
     *         Adds XSD as a burn option while uXSD value is positive.
     * @param BankX_amount The amount of BankX to be burned.
     * @param COLLATERAL_out_min The minimum amount of collateral to be received.
     * @param deadline The time by which the transaction must be confirmed.
     * @dev Requires that the buyback is not paused. Uses CollateralPoolLibrary to calculate the collateral equivalent.
     */
    function buyBackBankX(uint256 BankX_amount, uint256 COLLATERAL_out_min, uint256 deadline) external blockDelay ensure(deadline) {
        require(!buyback_paused, "Buyback Paused");
        CollateralPoolLibrary.BuybackBankX_Params memory input_params = CollateralPoolLibrary.BuybackBankX_Params(
            availableExcessCollatDV(),
            pid_controller.bankx_updated_price(),
            XSD.eth_usd_price(),
            BankX_amount
        );

        (collateral_equivalent_d18) = (CollateralPoolLibrary.calcBuyBackBankX(input_params));

        require(COLLATERAL_out_min <= collateral_equivalent_d18, "INSUFFICIENT OUTPUT");
        // Give the sender their desired collateral and burn the BankX
        BankX.pool_burn_from(msg.sender, BankX_amount);
        TransferHelper.safeTransfer(address(WETH), address(this), collateral_equivalent_d18);
        IWETH(WETH).withdraw(collateral_equivalent_d18);
        TransferHelper.safeTransferETH(msg.sender, collateral_equivalent_d18);
    }

    /**
     * @notice Allows a user to buy back XSD with excess collateral value from a desired collateral pool.
     *         This can happen if the collateral ratio > 1.
     * @param XSD_amount The amount of XSD to be burned.
     * @param collateral_out_min The minimum amount of collateral to be received.
     * @param deadline The time by which the transaction must be confirmed.
     * @dev Requires that the buyback is not paused. Uses CollateralPoolLibrary to calculate the collateral equivalent.
     */
    function buyBackXSD(uint256 XSD_amount, uint256 collateral_out_min, uint256 deadline) external blockDelay ensure(deadline) {
        require(!buyback_paused, "Buyback Paused");
        if (XSD_amount != 0) require((XSD.totalSupply() + XSD_amount) > collat_XSD, "uXSD MUST BE POSITIVE");

        CollateralPoolLibrary.BuybackXSD_Params memory input_params = CollateralPoolLibrary.BuybackXSD_Params(
            availableExcessCollatDV(),
            pid_controller.xsd_updated_price(),
            XSD.eth_usd_price(),
            XSD_amount
        );

        (collateral_equivalent_d18) = (CollateralPoolLibrary.calcBuyBackXSD(input_params));

        require(collateral_out_min <= collateral_equivalent_d18, "INSUFFICIENT OUTPUT");
        XSD.pool_burn_from(msg.sender, XSD_amount);
        TransferHelper.safeTransfer(address(WETH), address(this), collateral_equivalent_d18);
        IWETH(WETH).withdraw(collateral_equivalent_d18);
        TransferHelper.safeTransferETH(msg.sender, collateral_equivalent_d18);
    }

    /**
     * @notice Sets pool parameters such as block delay and pause statuses.
     * @param new_block_delay The new block delay value.
     * @param _mint_paused Boolean indicating whether minting is paused.
     * @param _redeem_paused Boolean indicating whether redeeming is paused.
     * @param _buyback_paused Boolean indicating whether buyback is paused.
     */
    function setPoolParameters(uint256 new_block_delay, bool _mint_paused, bool _redeem_paused, bool _buyback_paused) external onlyByOwner {
        block_delay = new_block_delay;
        mint_paused = _mint_paused;
        redeem_paused = _redeem_paused;
        buyback_paused = _buyback_paused;
        emit PoolParametersSet(new_block_delay,_mint_paused, _redeem_paused, _buyback_paused);
    }

    /**
     * @notice Sets a new PID controller address.
     * @param new_pid_address The address of the new PID controller.
     */
    function setPIDController(address new_pid_address) external onlyByOwner {
        pid_controller = IPIDController(new_pid_address);
        pid_address = new_pid_address;
    }

    /**
     * @notice Sets the address of the smart contract owner.
     * @param _smartcontract_owner The address of the new smart contract owner.
     * @dev The new owner address cannot be zero.
     */
    function setSmartContractOwner(address _smartcontract_owner) external onlyByOwner {
        require(_smartcontract_owner != address(0), "COLLATERALPOOL:ZEROCHECK");
        smartcontract_owner = _smartcontract_owner;
    }

    /**
     * @notice Renounces ownership of the contract.
     */
    function renounceOwnership() external onlyByOwner {
        smartcontract_owner = address(0);
    }

    /**
     * @notice Resets various contract addresses.
     * @param _xsd_contract_address The address of the XSD contract.
     * @param _bankx_contract_address The address of the BankX contract.
     * @param _bankxweth_pool The address of the BankX/WETH pool.
     * @param _xsdweth_pool The address of the XSD/WETH pool.
     * @param _WETH The address of the WETH contract.
     * @dev Ensures that none of the provided addresses are zero.
     */
    function resetAddresses(address _xsd_contract_address,
        address _bankx_contract_address,
        address _bankxweth_pool,
        address _xsdweth_pool,
        address _WETH) external onlyByOwner {
        require(
            (_xsd_contract_address != address(0))
            && (_bankx_contract_address != address(0))
            && (_WETH != address(0))
            && (_bankxweth_pool != address(0))
            && (_xsdweth_pool != address(0))
        , "COLLATERALPOOL:ZEROCHECK"); 
        XSD = XSDStablecoin(_xsd_contract_address);
        BankX = BankXToken(_bankx_contract_address);
        xsd_contract_address = _xsd_contract_address;
        bankx_contract_address = _bankx_contract_address;
        xsdweth_pool = _xsdweth_pool;
        bankxweth_pool = _bankxweth_pool;
        WETH = _WETH;
    }

    /* ========== EVENTS ========== */

    /**
     * @notice Emitted when pool parameters are set.
     * @param new_block_delay The new block delay value.
     */
    event PoolParametersSet(uint256 new_block_delay, bool _mint_paused, bool _redeem_paused, bool _buyback_paused);
}
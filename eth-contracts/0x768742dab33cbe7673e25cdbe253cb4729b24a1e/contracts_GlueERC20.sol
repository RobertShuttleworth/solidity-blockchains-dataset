// SPDX-License-Identifier: BUSL-1.1
// https://github.com/glue-finance/glue/blob/main/LICENCE.txt

/**

  ▄████  ██▓     █    ██ ▓█████    ▓██   ██▓ ▒█████   █    ██  ██▀███     ▄▄▄█████▓ ▒█████   ██ ▄█▀▓█████  ███▄    █ 
 ██▒ ▀█▒▓██▒     ██  ▓██▒▓█   ▀     ▒██  ██▒▒██▒  ██▒ ██  ▓██▒▓██ ▒ ██▒   ▓  ██▒ ▓▒▒██▒  ██▒ ██▄█▒ ▓█   ▀  ██ ▀█   █ 
▒██░▄▄▄░▒██░    ▓██  ▒██░▒███        ▒██ ██░▒██░  ██▒▓██  ▒██░▓██ ░▄█ ▒   ▒ ▓██░ ▒░▒██░  ██▒▓███▄░ ▒███   ▓██  ▀█ ██▒
░▓█  ██▓▒██░    ▓▓█  ░██░▒▓█  ▄      ░ ▐██▓░▒██   ██░▓▓█  ░██░▒██▀▀█▄     ░ ▓██▓ ░ ▒██   ██░▓██ █▄ ▒▓█  ▄ ▓██▒  ▐▌██▒
░▒▓███▀▒░██████▒▒▒█████▓ ░▒████▒     ░ ██▒▓░░ ████▓▒░▒▒█████▓ ░██▓ ▒██▒     ▒██▒ ░ ░ ████▓▒░▒██▒ █▄░▒████▒▒██░   ▓██░
 ░▒   ▒ ░ ▒░▓  ░░▒▓▒ ▒ ▒ ░░ ▒░ ░      ██▒▒▒ ░ ▒░▒░▒░ ░▒▓▒ ▒ ▒ ░ ▒▓ ░▒▓░     ▒ ░░   ░ ▒░▒░▒░ ▒ ▒▒ ▓▒░░ ▒░ ░░ ▒░   ▒ ▒ 
  ░   ░ ░ ░ ▒  ░░░▒░ ░ ░  ░ ░  ░    ▓██ ░▒░   ░ ▒ ▒░ ░░▒░ ░ ░   ░▒ ░ ▒░       ░      ░ ▒ ▒░ ░ ░▒ ▒░ ░ ░  ░░ ░░   ░ ▒░
░ ░   ░   ░ ░    ░░░ ░ ░    ░       ▒ ▒ ░░  ░ ░ ░ ▒   ░░░ ░ ░   ░░   ░      ░      ░ ░ ░ ▒  ░ ░░ ░    ░      ░   ░ ░ 
      ░     ░  ░   ░        ░  ░    ░ ░         ░ ░     ░        ░                     ░ ░  ░  ░      ░  ░         ░ 
                                    ░ ░                                                                              

@title GlueERC20
@author @BasedToschi
@notice A protocol to use the GlueStickERC20 to make any ERC20 token sticky. A sticky token is linked to a glueAddress, and any ERC20 or ETH collateral sent to the glueAddress can be unglued by burning the corresponding percentage of the sticky token supply.
@dev This contract uses the GluedSettings and GluedMath contracts for configuration and calculations.

// Lore:

-* "Glue Stick" is the factory contract that glues ERC20 tokens.
-* "Sticky Token" is a token fueled by glue.
-* "Glue Address" is the address of the glue that is linked to a Sticky Token.
-* "Glued Tokens" are the collateral glued to a Sticky Token.
-* "Glue a token" is the action of infusing a token with glue, making it sticky by creating its Glue Address.
-* "Unglue" is the action of burning the supply of a Sticky Token to withdraw the corresponding percentage of the collateral.
-* "Glued Loan" is the action of borrowing collateral from multiple glues.

*/

pragma solidity ^0.8.28;

import {Clones} from "./openzeppelin_contracts_proxy_Clones.sol";
import "./openzeppelin_contracts_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IERC3156FlashBorrower} from "./openzeppelin_contracts_interfaces_IERC3156FlashBorrower.sol";
import {IGlueERC20, IGlueStickERC20} from "./contracts_interfaces_IGlueERC20.sol";
import {IGluedLoanReceiver} from "./contracts_interfaces_IGluedLoanReceiver.sol";
import {IGluedSettings} from "./contracts_interfaces_IGluedSettings.sol";
import {GluedMath} from "./contracts_GluedMath.sol";

/**
* @title GlueStickERC20
* @notice A factory contract for deploying GlueERC20 contracts using minimal proxies.
* @dev This contract uses the Clones library to create minimal proxy contracts.
*/
contract GlueStickERC20 is IGlueStickERC20 {
    using SafeERC20 for IERC20;
    address public immutable glueStickAddress;
    mapping(address => address) public getGlueAddress;
    address[] public allGlues;
    address public TheGlue;

    constructor() {
        glueStickAddress = address(this);
        TheGlue = deployTheGlue();
    }

    /**
    * @notice Prevents reentrancy attacks.
    */
    modifier nnrtnt() {
        bytes32 slot = keccak256(abi.encodePacked(address(this), "ReentrancyGuard"));
        assembly {
            if tload(slot) { 
                mstore(0x00, 0x3ee5aeb5)
                revert(0x1c, 0x04)
            }
            tstore(slot, 1)
        }
        _;
        assembly {
            tstore(slot, 0)
        }
    }

    /**
    * @notice Creates a new GlueERC20 contract for the given ERC20 token address using minimal proxy.
    * @dev This function checks if the token is valid and not already glued, then creates a new GlueERC20 contract.
    * @param _tokenAddressToGlue The address of the ERC20 token to be glued.
    */
    function glueAToken(address _tokenAddressToGlue) external {
        if(_tokenAddressToGlue == address(0)) revert InvalidToken(_tokenAddressToGlue);
        (bool isAllowed) = checkToken(_tokenAddressToGlue);
        if(!isAllowed) revert InvalidToken(_tokenAddressToGlue);

        if(getGlueAddress[_tokenAddressToGlue] != address(0)) revert DuplicateGlue(_tokenAddressToGlue);

        bytes32 salt = keccak256(abi.encodePacked(_tokenAddressToGlue));

        address glueAddress = Clones.cloneDeterministic(TheGlue, salt);

        IGlueERC20(glueAddress).initialize(_tokenAddressToGlue);

        getGlueAddress[_tokenAddressToGlue] = glueAddress;
        allGlues.push(glueAddress);

        emit GlueAdded(_tokenAddressToGlue, glueAddress, allGlues.length);
    }

    /**
    * @notice Checks if the given ERC20 token address has valid totalSupply and decimals functions.
    * @dev This function performs static calls to check for totalSupply and decimals functions.
    * @param _tokenAddressToGlue The address of the ERC20 token contract to check.
    * @return bool Indicates whether the token is valid.
    */
    function checkToken(address _tokenAddressToGlue) public view returns (bool) {
        (bool hasTotalSupply, ) = _tokenAddressToGlue.staticcall(abi.encodeWithSignature("totalSupply()"));
        (bool hasDecimals, ) = _tokenAddressToGlue.staticcall(abi.encodeWithSignature("decimals()"));

        return hasTotalSupply && hasDecimals;
    }

    /**
    * @notice Computes the address of the GlueERC20 contract for the given token address.
    * @dev Uses the Clones library to predict the address of the minimal proxy.
    * @param _tokenAddressToGlue The address of the ERC20 token.
    * @return The computed address of the GlueERC20 contract.
    */
    function computeGlueAddress(address _tokenAddressToGlue) public view returns (address) {
        if(_tokenAddressToGlue == address(0)) revert InvalidToken(_tokenAddressToGlue);
        bytes32 salt = keccak256(abi.encodePacked(_tokenAddressToGlue));
        address predictedAddress = Clones.predictDeterministicAddress(TheGlue, salt, address(this));
        return predictedAddress;
    }

    /**
    * @notice Checks if a given token address is sticky and returns its glue address.
    * @param _tokenAddress The address of the token to check.
    * @return bool Indicates whether the token is sticky.
    * @return address The glue address for the token if it's sticky, otherwise address(0).
    */
    function isStickyToken(address _tokenAddress) public view returns (bool, address) {
        return (getGlueAddress[_tokenAddress] != address(0), getGlueAddress[_tokenAddress]);
    }

    /**
    * @notice Returns the total number of deployed glues.
    * @return uint The length of the allGlues array.
    */
    function allGluesLength() external view returns (uint) {
        return allGlues.length;
    }

    struct LoanData {
        uint256 count; /// @param count The number of loans to be executed.
        uint256[] toBorrow; /// @param toBorrow The amount of tokens to borrow from each glue.
        uint256[] expectedAmounts; /// @param expectedAmounts The expected amount of tokens to be repaid, including fees.
        uint256[] expectedBalances; /// @param expectedBalances The expected balance of tokens in each glue after the loans are executed.
    }

    /**
    * @notice Executes multiple flash loans across multiple glues.
    * @dev This function calculates the loans, executes them, and verifies the repayments.
    * @param glues The addresses of the glues to borrow from.
    * @param token The address of the token to borrow.
    * @param totalAmount The total amount of tokens to borrow.
    * @param receiver The address of the receiver.
    * @param params Additional parameters for the receiver.
    */
    function gluedLoan(address[] calldata glues,address token,uint256 totalAmount,address receiver,bytes calldata params) external nnrtnt {
        if(receiver == address(0)) revert InvalidAddress();
        if(totalAmount == 0) revert InvalidInputs();
        if(glues.length == 0) revert InvalidInputs();

        LoanData memory loanData = _calculateLoans(glues, token, totalAmount);

        _executeLoans(loanData, glues, token, receiver);

        
        if (!IGluedLoanReceiver(receiver).executeOperation(
            glues[0:loanData.count],
            token,
            loanData.expectedAmounts,
            params
        )) revert FlashLoanFailed();

        _verifyBalances(loanData, glues, token);
        
    }

    /**
    * @notice Calculates the flash loans for each glue.
    * @dev This function calculates the loans, executes them, and verifies the repayments.
    * @param glues The addresses of the glues to borrow from.
    * @param token The address of the token to borrow.
    * @param totalAmount The total amount of tokens to borrow.
    * @return loanData The data for the loans.
    */
    function _calculateLoans(address[] calldata glues, address token, uint256 totalAmount) private view returns (LoanData memory loanData) {
        loanData.toBorrow = new uint256[](glues.length);
        loanData.expectedAmounts = new uint256[](glues.length);
        loanData.expectedBalances = new uint256[](glues.length);
        
        uint256 totalCollected;
        uint256 j;
        
        for (uint256 i; i < glues.length;) {
            if (totalCollected >= totalAmount) break;
            
            address glue = glues[i];
            if(glue == address(0)) revert InvalidAddress();

            uint256 initialBalance = getGlueBalance(glue, token);
            if(initialBalance == 0) revert InvalidGlueBalance(glue, initialBalance, token);
            
            if (initialBalance > 0) {
                uint256 toBorrow = totalAmount - totalCollected;
                if (toBorrow > initialBalance) toBorrow = initialBalance;

                if(toBorrow == 0) continue;

                uint256 fee = IGlueERC20(glue).getFlashLoanFeeCalculated(toBorrow);
                
                loanData.toBorrow[j] = toBorrow;
                loanData.expectedAmounts[j] = toBorrow + fee;
                loanData.expectedBalances[j] = initialBalance + fee;
                totalCollected += toBorrow;
                j++;
            }
            unchecked { ++i; }
        }

        loanData.count = j;

        if (totalCollected < totalAmount)
            revert InsufficientLiquidity(totalCollected, totalAmount);

        return loanData;
    }

    /**
    * @notice Executes the flash loans for each glue.
    * @dev This function executes the loans and verifies the repayments.
    * @param loanData The data for the loans.
    * @param glues The addresses of the glues to borrow from.
    * @param token The address of the token to borrow.
    * @param receiver The address of the receiver.
    */
    function _executeLoans(LoanData memory loanData,address[] calldata glues,address token,address receiver) private {
        
        for (uint256 i; i < loanData.count;) {
            
            if(!IGlueERC20(glues[i]).minimalLoan(
                receiver,
                token,
                loanData.toBorrow[i]
            )) revert FlashLoanFailed();

            
            unchecked { ++i; }
        }
    }

    /**
    * @notice Verifies the balances for each glue.
    * @dev This function verifies the balances for each glue.
    * @param loanData The data for the loans.
    * @param glues The addresses of the glues to borrow from.
    * @param token The address of the token to borrow.
    */
    function _verifyBalances(LoanData memory loanData,address[] calldata glues,address token) private view {
        for (uint256 i; i < loanData.count;) {
            address glue = glues[i];
            if (getGlueBalance(glue, token) < loanData.expectedBalances[i])
                revert RepaymentFailed(glue);
            unchecked { ++i; }
        }
    }

    /** 
    * @notice Retrieves the balance of a given token in a glue.
    * @param glue The address of the glue.
    * @param token The address of the token.
    * @return uint256 The balance of the token in the glue.
    */
    function getGlueBalance(address glue,address token) public view returns (uint256) {
        if(token == address(0)) {
            return glue.balance;
        } else {
            return IERC20(token).balanceOf(glue);
        }
    }

    /**
    * @notice Retrieves the balance of a given token in multiple glues.
    * @param glues The addresses of the glues.
    * @param token The address of the token.
    * @return uint256[] memory The balances of the token in the glues.
    */
    function getGluesBalance(address[] calldata glues,address token) public view returns (uint256[] memory) {
        uint256[] memory balances = new uint256[](glues.length);
        for (uint256 i; i < glues.length;) {
            if(glues[i] != address(0)) {
                balances[i] = IERC20(token).balanceOf(glues[i]);
            } else {
                balances[i] = glues[i].balance;
            }
            unchecked { ++i; }
        }

        return balances;
    }

    /**
    * @notice Deploys the implementation contract (TheGlue) for cloning.
    * @dev This function is called internally during contract construction.
    * @return address The address of the deployed implementation contract.
    */
    function deployTheGlue() internal returns (address) {
        GlueERC20 glueContract = new GlueERC20(address(this));
        address glueAddress = address(glueContract);
        if(glueAddress == address(0)) revert FailedToDeployGlue();
        return glueAddress;
    }
}

contract GlueERC20 is Initializable, IGlueERC20 {
    using SafeERC20 for IERC20;
    using GluedMath for uint256;

    uint256 private constant SCALING_FACTOR = 1e18;
    uint256 private constant PROTOCOL_FEE = 15e14; // 0.15% 
    uint256 private constant LOAN_FEE = 1e14; // 0.01% 
    address private constant ETH_ADDRESS = address(0);
    address private constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public constant gluedSettingsAddress = 0x941a193AcBa06CD09645a8D3B7afDd28B7b813b0;
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    address public immutable glueStickAddress;
    address public stickyTokenAddress;
    bool public notBurnable;
    bool public noZero;
    bool public stickyTokenStored;
    
    /**
    * @notice Constructor for the GlueERC20 contract.
    * @dev Sets the glueStickAddress for the contract.
    * @param _glueStickAddress The address of the GlueStick contract.
    */
    constructor(address _glueStickAddress) {
        if(_glueStickAddress == address(0)) revert InvalidGlueStickAddress();
        glueStickAddress = _glueStickAddress;
    }

    /**
     * @notice Prevents reentrancy attacks by checking the guard value.
     * @dev Custom implementation of the nonReentrant modifier
     */
    modifier nnrtnt() {
        bytes32 slot = keccak256(abi.encodePacked(address(this), "ReentrancyGuard"));
        assembly {
            if tload(slot) { 
                mstore(0x00, 0x3ee5aeb5)
                revert(0x1c, 0x04)
            }
            tstore(slot, 1)
        }
        _;
        assembly {
            tstore(slot, 0)
        }
    }

    /**
    * @notice Initializes the GlueERC20 contract.
    * @dev This function is called by the clone during deployment.
    * @param _tokenAddressToGlue The address of the ERC20 token to be glued.
    */
    function initialize(address _tokenAddressToGlue) external nnrtnt initializer {
        if(_tokenAddressToGlue == address(0)) revert InvalidToken(_tokenAddressToGlue);
        stickyTokenAddress = _tokenAddressToGlue;
        stickyTokenStored = false;
        notBurnable = false;
        noZero = false;
    }

    /**
    * @notice Allows the contract to receive ETH.
    */
    receive() external payable {}


    struct WithdrawInfo {
        address recipient; /// @param recipient The address of the recipient who will receive the unglued funds.
        uint256 glueFee; /// @param glueFee is the portion of the protocol fee to send to the glue fee address for the ungluing.
        address glueFeeAddress; /// @param glueFeeAddress The address of the glue fee where the glue fee will be sent.
        address teamAddress; /// @param teamAddress The address of the team wallet where the rest of the protocol fee will be sent.
    }

    struct InitializationData {
        uint256 supplyDelta; /// @dev The calculated change in supply used for math operations.
        uint256 realAmount; /// @dev The actual amount of tokens transferred.
        uint256 afterTotalSupply; /// @dev The total supply after the ungluing process.
        uint256 beforeTotalSupply; /// @dev The total supply before the ungluing process.
    }

    /**
    * @notice Unglues assets from the contract.
    * @dev This function burns sticky tokens and releases the corresponding assets.
    * @param addressesToUnglue An array of addresses representing the assets to unglue.
    * @param stickyTokenAmount The amount of sticky tokens to burn.
    * @param recipient The address that will receive the unglued assets.
    * @return uint256 The supply delta.
    * @return uint256 The real amount of tokens unglued.
    * @return uint256 The total supply before ungluing.
    * @return uint256 The total supply after ungluing.
    */
    function unglue(address[] calldata addressesToUnglue, uint256 stickyTokenAmount, address recipient) public nnrtnt returns (uint256, uint256, uint256, uint256) {
        if(addressesToUnglue.length == 0) revert NoCollateralSelected();
        if(stickyTokenAmount == 0) revert NoTokensTransferred();

        InitializationData memory initData = initialization(stickyTokenAmount);

        WithdrawInfo memory withdrawInfo;
        withdrawInfo.recipient = recipient;
        (withdrawInfo.glueFee, withdrawInfo.glueFeeAddress, withdrawInfo.teamAddress) = IGluedSettings(gluedSettingsAddress).getProtocolFeeInfo();

        computeCollateral(addressesToUnglue, initData.supplyDelta, withdrawInfo);

        emit unglued(recipient, stickyTokenAmount, initData.beforeTotalSupply, initData.afterTotalSupply);
        return (initData.supplyDelta, initData.realAmount, initData.beforeTotalSupply, initData.afterTotalSupply);
    }

    
    /**
     * @notice Initializes the withdrawal process by transferring sticky token to the glue and calculating the supply delta.
     * @dev This function handles the initial steps of the ungluing process, including token transfer and supply calculations.
     * @param stickyTokenAmount The amount of sticky tokens to burn.
     * @return initData The change in supply and other initialization data.
     */
    function initialization(uint256 stickyTokenAmount) internal returns (InitializationData memory initData) {
        uint256 previousGlueBalance = getTokenBalance(stickyTokenAddress, address(this));
        IERC20(stickyTokenAddress).safeTransferFrom(msg.sender, address(this), stickyTokenAmount);
        
        if (!noZero) {
            bool considerAddress0 = checkAddress0Inclusion();
            if (considerAddress0) {
                noZero = true;
            }
        }
        
        uint256 newGlueBalance = getTokenBalance(stickyTokenAddress, address(this));
        
        if (newGlueBalance <= previousGlueBalance) {
            revert TransferFailed(stickyTokenAddress, address(this));
        }
        
        uint256 realAmount = newGlueBalance - previousGlueBalance;
        (uint256 beforeTotalSupply, uint256 afterTotalSupply) = getRealTotalSupply(realAmount);
        uint256 supplyDelta = calculateSupplyDelta(realAmount, beforeTotalSupply);

        if (!stickyTokenStored) {
            burnMain(newGlueBalance);
        }

        initData.supplyDelta = supplyDelta;
        initData.realAmount = realAmount;
        initData.afterTotalSupply = afterTotalSupply;
        initData.beforeTotalSupply = beforeTotalSupply;
    }

    /**
    * @dev Checks if the zero address (address(0)) is included in the token's total supply calculations.
    * This function attempts a test transfer of 1 wei of sticky token to the zero address and checks if the total supply is affected.
    * @return bool Returns true if the zero address is included in total supply calculations, false otherwise.
    */
    function checkAddress0Inclusion() internal returns (bool) {
        bytes memory data = abi.encodeWithSignature("totalSupply()");
        (, bytes memory result) = stickyTokenAddress.staticcall(data);
        uint256 initialTotalSupply = abi.decode(result, (uint256));

        data = abi.encodeWithSignature("transfer(address,uint256)", address(0), 1);
        (bool success, ) = stickyTokenAddress.call(data);

        if (!success) {
            return true;
        }

        data = abi.encodeWithSignature("totalSupply()");
        (, result) = stickyTokenAddress.staticcall(data);
        uint256 newTotalSupply = abi.decode(result, (uint256));

        if (initialTotalSupply == newTotalSupply) {
            return false;
        } else {
            return true;
        }
    }
    
    /**
    * @notice Calculates the supply delta based on the real amount and real total supply.
    * @param realAmount The real amount of supply.
    * @param beforeTotalSupply The real total supply.
    * @return The calculated supply delta.
    */
    function calculateSupplyDelta(uint256 realAmount, uint256 beforeTotalSupply) internal pure returns (uint256) {
        return GluedMath.md512(realAmount, SCALING_FACTOR, beforeTotalSupply);
    }

    /**
    * @notice Calculates the real total supply of the sticky token by excluding balances in dead and burn addresses.
    * @param _realAmount The amount of sticky tokens.
    * @return The real total supply of the sticky token.
    */
    function getRealTotalSupply(uint256 _realAmount) internal view returns (uint256, uint256) {
        uint256 totalSupply = getTokenTotalSupply(stickyTokenAddress);
        
        uint256 deadBalance = getTokenBalance(stickyTokenAddress, DEAD_ADDRESS);
        
        uint256 beforeTotalSupply = totalSupply - deadBalance;
        
        uint256 glueBalance = getTokenBalance(stickyTokenAddress, address(this));
        
        beforeTotalSupply -= (glueBalance - _realAmount);
        
        if (!noZero) {
            uint256 burnBalance = getTokenBalance(stickyTokenAddress, address(0));
            beforeTotalSupply -= burnBalance;
        }

        uint256 afterTotalSupply = beforeTotalSupply - _realAmount;

        return (beforeTotalSupply, afterTotalSupply);
    }

    /**
    * @notice Burns the sticky token supply held by the glue, transfers it to the dead address if burning fails or if both fails, glued it forever.
    */
    function burnMain(uint256 balance) internal {
        if (!notBurnable) {
            (bool success, bytes memory returndata) = stickyTokenAddress.call(abi.encodeWithSelector(0x42966c68, balance));
            if (!success || (returndata.length != 0 && !abi.decode(returndata, (bool)))) {
                notBurnable = true;
            }
        }
        
        if (notBurnable) {
            try IERC20(stickyTokenAddress).transfer(DEAD_ADDRESS, balance) returns (bool success) {
                if (!success) {
                    stickyTokenStored = true;
                }
            } catch {
                stickyTokenStored = true;
            }
        }
    }

    /**
    * @notice Computes and transfers the collateral for ungluing.
    * @dev This function processes each unique glued address and transfers the corresponding assets.
    * @param addressesToUnglue An array of addresses representing the assets to unglue.
    * @param supplyDelta The change in supply due to ungluing.
    * @param withdrawInfo A struct containing information about the withdrawal.
    */
    function computeCollateral(address[] memory addressesToUnglue, uint256 supplyDelta, WithdrawInfo memory withdrawInfo) internal {
        bytes32 duplicateSlot = keccak256(abi.encodePacked(address(this), "DuplicateAddressCheck"));
        for (uint256 i = 0; i < addressesToUnglue.length; i++) {
            address gluedAddress = addressesToUnglue[i];
            if(gluedAddress == stickyTokenAddress) revert CannotWithdrawStickyToken();
            
            bytes32 slot = keccak256(abi.encodePacked(duplicateSlot, gluedAddress));
            assembly {
                if tload(slot) {
                    mstore(0x00, 0x947d5a84)
                    mstore(0x04, gluedAddress)
                    revert(0x00, 0x24)
                }
                tstore(slot, 1)
            }
            
           

            uint256 assetBalance = getTokenBalance(gluedAddress, address(this));
            if (assetBalance == 0) {
                continue;
            }
            uint256 assetAvailability = calculateAssetAvailability(assetBalance, supplyDelta);
            
            bool success = withdrawWithFee(gluedAddress, assetAvailability, withdrawInfo);
            if (!success) {
                revert WithdrawFailed(gluedAddress);
            }
        }

        for (uint256 i = 0; i < addressesToUnglue.length; i++) {
            address gluedAddress = addressesToUnglue[i];
            bytes32 slot = keccak256(abi.encodePacked(duplicateSlot, gluedAddress));
            assembly {
                tstore(slot, 0)
            }
        }
    }

    /**
    * @notice Calculates the asset availability based on the asset balance and supply delta.
    * @param assetBalance The balance of the asset.
    * @param supplyDelta The supply delta.
    * @return The calculated asset availability.
    */
    function calculateAssetAvailability(uint256 assetBalance, uint256 supplyDelta) internal pure returns (uint256) {
        return GluedMath.md512(assetBalance, supplyDelta, SCALING_FACTOR);
    }

    /**
    * @dev Withdraws specified assets with fees applied and transfers them to the respective recipients.
    * This function first calculates the fees based on the asset availability and then transfers the assets accordingly.
    * @param gluedAddress The address of the token contract from which assets are being withdrawn.
    * @param assetAvailability The amount of the asset available for withdrawal after considering the supply delta.
    * @param withdrawInfo A struct containing details about the withdrawal, including recipient and fee information.
    * @return bool Returns true if the transfer of assets with fees is successful, false otherwise.
    */
    function withdrawWithFee(address gluedAddress, uint256 assetAvailability, WithdrawInfo memory withdrawInfo) internal returns (bool) {
        (uint256 glueFeeAmount, uint256 teamFeeAmount, uint256 recipientAmount) = calculateFees(assetAvailability, withdrawInfo.glueFee);

        return transferWithFee(gluedAddress, glueFeeAmount, teamFeeAmount, recipientAmount, withdrawInfo.recipient, withdrawInfo.glueFeeAddress, withdrawInfo.teamAddress);
    }

    /**
    * @notice Calculates the fee amounts based on the asset availability and fee percentages.
    * @param assetAvailability The available amount of assets.
    * @param glueFee The main glue fee percentage.
    * @return The main glue fee amount, team fee amount, and recipient amount.
    */
    function calculateFees(uint256 assetAvailability, uint256 glueFee)
        internal pure returns (uint256, uint256, uint256)
    {
        uint256 protocolFeeAmount = GluedMath.md512Up(assetAvailability, PROTOCOL_FEE, SCALING_FACTOR);
        uint256 glueFeeAmount = GluedMath.md512(protocolFeeAmount, glueFee, SCALING_FACTOR);
        uint256 teamFeeAmount = protocolFeeAmount - glueFeeAmount;
        uint256 recipientAmount = assetAvailability - protocolFeeAmount;

        return (glueFeeAmount, teamFeeAmount, recipientAmount);
    }

    /**
    * @notice Transfers tokens or ETH with fee deduction.
    * @param gluedAddress The address of the token to transfer (ETH_ADDRESS for ETH).
    * @param glueFeeAmount The amount of fee for the main glue.
    * @param teamFeeAmount The team fee amount.
    * @param recipientAmount The recipient amount.
    * @param recipient The address to receive the recipient amount.
    * @param glueFeeAddress The address of the main glue.
    * @param teamAddress The address of the team.
    * @return A boolean indicating the success of the transfer.
    */
    function transferWithFee(address gluedAddress, uint256 glueFeeAmount, uint256 teamFeeAmount, uint256 recipientAmount, address recipient, address glueFeeAddress, address teamAddress) internal returns (bool) {
        if (recipient == address(0)) {
            recipient = msg.sender;
        }

        if(glueFeeAmount == 0) revert InvalidFee();
        if(recipientAmount == 0) revert InvalidWithdraw();
        
        if (gluedAddress == ETH_ADDRESS) {
            uint256 totalEthAmount = glueFeeAmount + teamFeeAmount + recipientAmount;
            if (address(this).balance < totalEthAmount) revert InsufficientBalance(address(this).balance, totalEthAmount);

            payable(glueFeeAddress).transfer(glueFeeAmount);
            if (teamFeeAmount > 0) {
                payable(teamAddress).transfer(teamFeeAmount);
            }
            payable(recipient).transfer(recipientAmount);
        } else {
            IERC20 tokenContract = IERC20(gluedAddress);
            tokenContract.safeTransfer(glueFeeAddress, glueFeeAmount);
            if (teamFeeAmount > 0) {
                tokenContract.safeTransfer(teamAddress, teamFeeAmount);
            }
            tokenContract.safeTransfer(recipient, recipientAmount);
        }

        return true;
    }

    /**
    * @notice Retrieves the balance of the specified token for the given account.
    * @param gluedAddress The address of the token contract.
    * @param account The address of the account.
    * @return The balance of the token for the account.
    */
    function getTokenBalance(address gluedAddress, address account) internal view returns (uint256) {
        if (gluedAddress == ETH_ADDRESS) {
            return account.balance;
        } else {
            return IERC20(gluedAddress).balanceOf(account);
        }
    }

    /**
    * @notice Retrieves the total supply of the specified token.
    * @param gluedAddress The address of the token contract.
    * @return The total supply of the token.
    */
    function getTokenTotalSupply(address gluedAddress) internal view returns (uint256) {
        return IERC20(gluedAddress).totalSupply();
    }

    /**
    * @notice Initiates a flash loan.
    * @param receiver The address of the receiver.
    * @param token The address of the token to flash loan.
    * @param amount The amount of tokens to flash loan.
    * @param data Additional parameters for the flash loan.
    */
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data) external nnrtnt returns (bool) {
        if(address(receiver) == address(0)) revert InvalidReceiver();
        if(amount == 0) revert InvalidFlashLoanAmount();
        if(token == stickyTokenAddress || token == ETH_ADDRESS) revert InvalidToken(token);

        uint256 initialBalance = getTokenBalance(token, address(this));
        if(initialBalance < amount) revert InsufficientBalance(initialBalance, amount);
        
        uint256 fee = GluedMath.md512Up(amount, LOAN_FEE, SCALING_FACTOR);

        IERC20(token).safeTransfer(address(receiver), amount);

        bytes32 callbackResult = receiver.onFlashLoan(msg.sender,token,amount,fee,data);
        if(callbackResult != CALLBACK_SUCCESS) revert FlashLoanFailed();

        IERC20(token).safeTransferFrom(address(receiver), address(this), amount + fee);

        if(getTokenBalance(token, address(this)) < initialBalance + fee) revert FlashLoanRepaymentFailed(initialBalance + fee);

        emit GlueLoan(token, amount, address(receiver));

        return true;
    }

    /**
    * @notice Initiates a minimal flash loan.
    * @param token The address of the token to flash loan.
    * @param amount The amount of tokens to flash loan.
    */
    function minimalLoan(address receiver, address token, uint256 amount) external nnrtnt returns (bool) {
        if(msg.sender != glueStickAddress) revert Unauthorized();

        if(token == stickyTokenAddress) revert InvalidToken(token);
        
        if(token == ETH_ADDRESS) {
            payable(receiver).transfer(amount);
        } else {
            IERC20(token).safeTransfer(receiver, amount);
        }

        emit GlueLoan(token, amount, receiver);
        
        return true;
    }


    /** 
    * @notice Retrieves the maximum flash loan amount for a given token.
    * @param token The address of the token.
    * @return The maximum flash loan amount.
    */
    function maxFlashLoan(address token) public view returns (uint256) {
        if (token == stickyTokenAddress || token == ETH_ADDRESS) return 0;
        return getTokenBalance(token, address(this));
    }

    /**
    * @notice Calculates the flash loan fee for a given amount.
    * @param token The address of the token.
    * @param amount The amount to calculate the flash loan fee for.
    * @return The flash loan fee.
    */
    function flashFee(address token, uint256 amount) public view returns (uint256) {
        if(token == stickyTokenAddress || token == ETH_ADDRESS) revert InvalidToken(token);
        if(getTokenBalance(token, address(this)) == 0 || maxFlashLoan(token) < amount) revert InvalidAmount(token, amount);
        return GluedMath.md512Up(amount, LOAN_FEE, SCALING_FACTOR);
    }

    /**
    * @notice Retrieves the status of the sticky token.
    * @return adjustedTotalSupply The adjusted total supply of the token.
    * @return glueBalance The balance of the token for the glue address.
    * @return deadBalance The balance of the token for the dead address.
    * @return totalSupply The total supply of the token.
    * @return stickyTokenStored A boolean indicating if the sticky token is stored.
    * @return PROTOCOL_FEE The protocol fee.
    * @return stickyTokenAddress The address of the sticky token.
     */
    function getStatus() external view returns (uint256, uint256, uint256, uint256, bool, uint256, address) {
        uint256 totalSupply = getTokenTotalSupply(stickyTokenAddress);
        uint256 deadBalance = getTokenBalance(stickyTokenAddress, DEAD_ADDRESS);
        uint256 adjustedTotalSupply = totalSupply - deadBalance;
        if (!noZero) {
            uint256 burnBalance = getTokenBalance(stickyTokenAddress, address(0));
            adjustedTotalSupply -= burnBalance;
        }
        uint256 glueBalance = getTokenBalance(stickyTokenAddress, address(this));
        adjustedTotalSupply -= glueBalance;

        return (adjustedTotalSupply, glueBalance, deadBalance, totalSupply, stickyTokenStored, PROTOCOL_FEE, stickyTokenAddress);
    }

    /**
    * @notice Calculates the supply delta based on the sticky token amount and total supply.
    * @param stickyTokenAmount The amount of sticky tokens.
    * @return The calculated supply delta.
    * @dev The Supply Delta can loose precision if the Sticky Token implement a Tax on tranfers, 
    * for these tokens is better to emulate the unglue function. 
    * Be aware on relying this function without calculating the the burn tax on your smart contract if you deal with a token that implement a burn Tax.
    */
    function getSupplyDelta(uint256 stickyTokenAmount) external view returns (uint256) {
        (uint256 beforeTotalSupply, ) = getRealTotalSupply(stickyTokenAmount);
        return calculateSupplyDelta(stickyTokenAmount, beforeTotalSupply);
    }

    /**
    * @notice Retrieves the adjusted total supply of the sticky token.
    * @return The adjusted total supply of the sticky token.
    */
    function getAdjustedTotalSupply() external view returns (uint256) {
        uint256 totalSupply = getTokenTotalSupply(stickyTokenAddress);
        uint256 deadBalance = getTokenBalance(stickyTokenAddress, DEAD_ADDRESS);
        uint256 adjustedTotalSupply = totalSupply - deadBalance;
        if (!noZero) {
            uint256 burnBalance = getTokenBalance(stickyTokenAddress, address(0));
            adjustedTotalSupply -= burnBalance;
        }
        uint256 glueBalance = getTokenBalance(stickyTokenAddress, address(this));
        return adjustedTotalSupply - glueBalance;
    }

    /**
    * @notice Retrieves the protocol fee percentage.
    * @return The protocol fee as a fixed-point number with 18 decimal places.
    */
    function getProtocolFee() external pure returns (uint256) {
        return (PROTOCOL_FEE);
    }
    
    /**
    * @notice Retrieves the protocol fee for a given amount.
    * @param amount The amount to calculate the protocol fee for.
    * @return The protocol fee as a fixed-point number with 18 decimal places.
    */
    function getProtocolFeeCalculated(uint256 amount) external pure returns (uint256) {
        return (GluedMath.md512Up(amount, PROTOCOL_FEE, SCALING_FACTOR));
    }

    /**
    * @notice Retrieves the flash loan fee percentage.
    * @return The flash loan fee as a fixed-point number with 18 decimal places.
    */
    function getFlashLoanFee() external pure returns (uint256) {
        return (LOAN_FEE);
    }

    /**
    * @notice Retrieves the flash loan fee for a given amount.
    * @param amount The amount to calculate the flash loan fee for.
    * @return The flash loan fee as a fixed-point number with 18 decimal places.
    */
    function getFlashLoanFeeCalculated(uint256 amount) external pure returns (uint256) {
        return (GluedMath.md512Up(amount, LOAN_FEE, SCALING_FACTOR));
    }

    /**
    * @notice Calculates the amount of collateral tokens that can be unglued for a given amount of sticky tokens.
    * @param stickyTokenAmount The amount of sticky tokens to be burned.
    * @param addressesToUnglue An array of addresses representing the collateral tokens to unglue.
    * @return Two arrays: the first containing the addresses of the collateral tokens, 
    * and the second containing the corresponding amounts that can be unglued.
    * @dev This function accounts for the protocol fee in its calculations.
    * @dev This function can loose precision if the Sticky Token implement a Tax on tranfers.
    */
    function collateralByAmount (uint256 stickyTokenAmount, address[] calldata addressesToUnglue) external view returns (address[] memory, uint256[] memory) {
        if(addressesToUnglue.length == 0) revert NoCollateralSelected();

        uint256 supplyDelta = this.getSupplyDelta(stickyTokenAmount);

        uint256[] memory unglueAmounts = new uint256[](addressesToUnglue.length);

        for (uint256 i = 0; i < addressesToUnglue.length; i++) {
            address gluedAddress = addressesToUnglue[i];
            if(gluedAddress == stickyTokenAddress) revert CannotWithdrawStickyToken();

            uint256 assetBalance = getTokenBalance(gluedAddress, address(this));
            if (assetBalance > 0) {
                uint256 assetAvailability = calculateAssetAvailability(assetBalance, supplyDelta);
    
                uint256 protocolFeeAmount = GluedMath.md512(assetAvailability, PROTOCOL_FEE, SCALING_FACTOR);
                unglueAmounts[i] = assetAvailability - protocolFeeAmount;
            } else {
                unglueAmounts[i] = 0;
            }
        }

        return (addressesToUnglue, unglueAmounts);
    }

    /**
    * @notice Calculates the amount of collateral tokens that can be unglued for a given supply delta.
    * @param addressesToUnglue An array of addresses representing the collateral tokens to unglue.
    * @param supplyDelta The supply delta, representing the proportion of total supply to be unglued.
    * @return Two arrays: the first containing the addresses of the collateral tokens, 
    * and the second containing the corresponding amounts that can be unglued.
    * @dev This function accounts for the protocol fee in its calculations.
    * @dev This function can loose precision if the Sticky Token implement a Tax on tranfers.
    */
    function collateralByDelta (address[] calldata addressesToUnglue, uint256 supplyDelta) external view returns (address[] memory, uint256[] memory) {
        if(addressesToUnglue.length == 0) revert NoCollateralSelected();

        uint256[] memory unglueAmounts = new uint256[](addressesToUnglue.length);

        for (uint256 i = 0; i < addressesToUnglue.length; i++) {
            address gluedAddress = addressesToUnglue[i];
            if(gluedAddress == stickyTokenAddress) revert CannotWithdrawStickyToken();

            uint256 assetBalance = getTokenBalance(gluedAddress, address(this));
            if (assetBalance > 0) {
                uint256 assetAvailability = calculateAssetAvailability(assetBalance, supplyDelta);
    
                uint256 protocolFeeAmount = GluedMath.md512(assetAvailability, PROTOCOL_FEE, SCALING_FACTOR);
                unglueAmounts[i] = assetAvailability - protocolFeeAmount;
            } else {
                unglueAmounts[i] = 0;
            }
        }

        return (addressesToUnglue, unglueAmounts);
    }

    /**
    * @notice Retrieves the balance of the sticky token for the glue contract.
    * @return The balance of the sticky token.
    */
    function getStickyTokenStored() external view returns (uint256) {
        return IERC20(stickyTokenAddress).balanceOf(address(this));
    }

    /**
    * @notice Retrieves the balance of an array of specified collateral tokens for the glue contract.
    * @param collateralAddresses An array of addresses representing the collateral tokens.
    * @return Two arrays: the first containing the addresses of the collateral tokens, 
    * and the second containing the corresponding balances.
    */
    function getCollateralsBalance(address[] calldata collateralAddresses) external view returns (address[] memory, uint256[] memory) {
        uint256[] memory balances = new uint256[](collateralAddresses.length);
        for (uint256 i = 0; i < collateralAddresses.length; i++) {
            balances[i] = getTokenBalance(collateralAddresses[i], address(this));
        }
        return (collateralAddresses, balances);
    }
}
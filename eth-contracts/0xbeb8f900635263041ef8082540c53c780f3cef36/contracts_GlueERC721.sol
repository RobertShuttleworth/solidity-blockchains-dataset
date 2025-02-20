// SPDX-License-Identifier: BUSL-1.1
// https://github.com/glue-finance/glue/blob/main/LICENCE.txt
/**
 
 
  ▄████  ██▓     █    ██ ▓█████    ▓██   ██▓ ▒█████   █    ██  ██▀███      ███▄    █   █████▒▄▄▄█████▓
 ██▒ ▀█▒▓██▒     ██  ▓██▒▓█   ▀     ▒██  ██▒▒██▒  ██▒ ██  ▓██▒▓██ ▒ ██▒    ██ ▀█   █ ▓██   ▒ ▓  ██▒ ▓▒
▒██░▄▄▄░▒██░    ▓██  ▒██░▒███        ▒██ ██░▒██░  ██▒▓██  ▒██░▓██ ░▄█ ▒   ▓██  ▀█ ██▒▒████ ░ ▒ ▓██░ ▒░
░▓█  ██▓▒██░    ▓▓█  ░██░▒▓█  ▄      ░ ▐██▓░▒██   ██░▓▓█  ░██░▒██▀▀█▄     ▓██▒  ▐▌██▒░▓█▒  ░ ░ ▓██▓ ░ 
░▒▓███▀▒░██████▒▒▒█████▓ ░▒████▒     ░ ██▒▓░░ ████▓▒░▒▒█████▓ ░██▓ ▒██▒   ▒██░   ▓██░░▒█░      ▒██▒ ░ 
 ░▒   ▒ ░ ▒░▓  ░░▒▓▒ ▒ ▒ ░░ ▒░ ░      ██▒▒▒ ░ ▒░▒░▒░ ░▒▓▒ ▒ ▒ ░ ▒▓ ░▒▓░   ░ ▒░   ▒ ▒  ▒ ░      ▒ ░░   
  ░   ░ ░ ░ ▒  ░░░▒░ ░ ░  ░ ░  ░    ▓██ ░▒░   ░ ▒ ▒░ ░░▒░ ░ ░   ░▒ ░ ▒░   ░ ░░   ░ ▒░ ░          ░    
░ ░   ░   ░ ░    ░░░ ░ ░    ░       ▒ ▒ ░░  ░ ░ ░ ▒   ░░░ ░ ░   ░░   ░       ░   ░ ░  ░ ░      ░      
      ░     ░  ░   ░        ░  ░    ░ ░         ░ ░     ░        ░                 ░                  
                                    ░ ░                                                               

 
@title GlueERC721
@author @BasedToschi
@notice A protocol to use the GlueStickERC721 to make any enumerable ERC721 NFT Collection sticky. A sticky NFT Collection is linked to a glueAddress, and any ERC20 or ETH collateral sent to the glueAddress can be unglued by burning the corresponding percentage of the sticky NFT Collection supply.
@dev This contract uses the GluedSettings and GluedMath contracts for configuration and calculations.

// Lore:

-* "Glue Stick" is the factory contract that glues ERC721 tokens.
-* "Sticky Token" is a token fueled by glue.
-* "Glue Address" is the address of the glue that is linked to a Sticky Token.
-* "Glued Tokens" are the collateral glued to a Sticky Token.
-* "Glue a token" is the action of infusing a token with glue, making it sticky by creating its Glue Address.
-* "Unglue" is the action of burning the supply of a Sticky Token to withdraw the corresponding percentage of the collateral.
-* "Glued Loan" is the action of borrowing collateral from multiple glues.

*/

pragma solidity ^0.8.28;

// Importing required contracts and interfaces
import {Clones} from "./openzeppelin_contracts_proxy_Clones.sol";
import {IERC165} from "./openzeppelin_contracts_interfaces_IERC165.sol";
import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import "./openzeppelin_contracts_token_ERC721_utils_ERC721Holder.sol";
import {IERC721Enumerable} from "./openzeppelin_contracts_token_ERC721_extensions_IERC721Enumerable.sol";
import {IERC3156FlashBorrower} from "./openzeppelin_contracts_interfaces_IERC3156FlashBorrower.sol";
import {IERC1155} from "./openzeppelin_contracts_token_ERC1155_IERC1155.sol";
import "./openzeppelin_contracts_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IGlueERC721, IGlueStickERC721} from "./contracts_interfaces_IGlueERC721.sol";
import {IGluedLoanReceiver} from "./contracts_interfaces_IGluedLoanReceiver.sol";
import {IGluedSettings} from "./contracts_interfaces_IGluedSettings.sol";
import {IERC721Burnable} from "./contracts_interfaces_IERC721Burnable.sol";
import {GluedMath} from "./contracts_GluedMath.sol";

/**
* @title GlueStickERC721
* @notice A factory contract for deploying GlueERC721 contracts.
*/
contract GlueStickERC721 is IGlueStickERC721 {
    using SafeERC20 for IERC20;
    address public immutable glueStickAddress;
    mapping(address => address) public getGlueAddress;
    address[] public allGlues;
    address public TheGlue;

    constructor () {
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
    * @notice Creates a new GlueERC721 contract for the given an ERC721 address.
    * @param _tokenAddressToGlue The address of the NFT Collection to be glued.
    * @dev This function checks if the token is valid and not already glued.
    */
    function glueAToken(address _tokenAddressToGlue) external {
        if(_tokenAddressToGlue == address(0)) revert InvalidToken(_tokenAddressToGlue);
        bool isAllowed = checkToken(_tokenAddressToGlue);
        if(!isAllowed) revert InvalidToken(_tokenAddressToGlue);

        if(getGlueAddress[_tokenAddressToGlue] != address(0)) revert DuplicateGlue(_tokenAddressToGlue);

        bytes32 salt = keccak256(abi.encodePacked(_tokenAddressToGlue));

        address glueAddress = Clones.cloneDeterministic(TheGlue, salt);

        IGlueERC721(glueAddress).initialize(_tokenAddressToGlue);

        getGlueAddress[_tokenAddressToGlue] = glueAddress;
        allGlues.push(glueAddress);

        emit GlueAdded(_tokenAddressToGlue, glueAddress, allGlues.length);
    }

    /**
    * @notice Checks if the given ERC721 address has valid totalSupply and no decimals
    * @dev This function performs static calls to check if token is a valid NFT
    * @param _tokenAddressToGlue The address of the ERC721 token to check
    * @return bool Indicates whether the token is valid
    */
    function checkToken(address _tokenAddressToGlue) public view returns (bool) {
        (bool hasTotalSupply, ) = _tokenAddressToGlue.staticcall(abi.encodeWithSignature("totalSupply()"));
        if (!hasTotalSupply) return false;

        (bool hasOwnerOf, ) = _tokenAddressToGlue.staticcall(abi.encodeWithSignature("ownerOf(uint256)", 0));
        if (!hasOwnerOf) return false;

        return true;
    }

    /**
    * @notice Computes the address of the GlueERC721 contract for the given ERC721 address.
    * @dev Uses the Clones library to predict the address of the minimal proxy.
    * @param _tokenAddressToGlue The address of the ERC721 contract.
    * @return The computed address of the GlueERC721 contract.
    */
    function computeGlueAddress(address _tokenAddressToGlue) public view returns (address) {
        if(_tokenAddressToGlue == address(0)) revert InvalidToken(_tokenAddressToGlue);
        bytes32 salt = keccak256(abi.encodePacked(_tokenAddressToGlue));
        address predictedAddress = Clones.predictDeterministicAddress(TheGlue, salt, address(this));
        return predictedAddress;
    }

    /**
    * @notice Checks if a given token is sticky and returns its glue address
    * @param _tokenAddress The address of the token to check
    * @return bool Indicates whether the token is sticky.
    * @return address The glue address for the token if it's sticky, otherwise address(0).
    */
    function isStickyToken(address _tokenAddress) public view returns (bool, address) {
        return (getGlueAddress[_tokenAddress] != address(0), getGlueAddress[_tokenAddress]);
    }

    /**
    * @notice Returns the total number of deployed Glue.
    * @return The length of the allGlues array.
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

            uint256 available = getGlueBalance(glue, token);
            if(available == 0) revert InvalidGlueBalance(glue, available, token);
            
            if (available > 0) {
                uint256 toBorrow = totalAmount - totalCollected;
                if (toBorrow > available) toBorrow = available;

                if(toBorrow == 0) continue;

                uint256 fee = IGlueERC721(glue).getFlashLoanFeeCalculated(toBorrow);
                
                loanData.toBorrow[j] = toBorrow;
                loanData.expectedAmounts[j] = toBorrow + fee;
                loanData.expectedBalances[j] = available + fee;
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
            
            if(!IGlueERC721(glues[i]).minimalLoan(
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
            balances[i] = getGlueBalance(glues[i], token);
            unchecked { ++i; }
        }

        return balances;
    }

    /**
    * @notice Deploys the TheGlue contract.
    * @return The address of the deployed GlueERC721 contract
    */
    function deployTheGlue() internal returns (address) {
        GlueERC721 glueContract = new GlueERC721(address(this));
        address glueAddress = address(glueContract);
        if(glueAddress == address(0)) revert FailedToDeployGlue();
        return glueAddress;
    }
}

contract GlueERC721 is Initializable, ERC721Holder, IGlueERC721 {
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
    bool public stickyTokenStored;

    /**
    * @notice Constructor that sets the glueStickAddress
    * @param _glueStickAddress The address of the GlueStick contract
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
    * @notice Initializes the GlueERC721 contract
    * @dev This function is called by the clone during deployment.
    * @param _tokenAddressToGlue The address of the ERC721E token to be glued.
    */
    function initialize(address _tokenAddressToGlue) external nnrtnt initializer {
        if(_tokenAddressToGlue == address(0)) revert InvalidToken(_tokenAddressToGlue);
        stickyTokenAddress = _tokenAddressToGlue;
        stickyTokenStored = false;
        notBurnable = false;
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

    struct WithdrawParams {
        uint256[] tokenIds; /// @param tokenIds An array of token IDs to burn.
        address[] uniqueGluedAddresses; /// @param uniqueGluedAddresses An array of addresses representing the assets to withdraw.
        address stickyTokenAddress; /// @param stickyTokenAddress The address of the main token contract.
    }

    /**
    * @notice Unglues assets from the glue and distributes fees.
    * @param addressesToUnglue An array of token addresses to withdraw.
    * @param tokenIds An array of token IDs sent by the user to burn.
    * @param recipient The address to receive the withdrawn assets.
    * @return supplyDelta The change in supply
    * @return stickyTokenAmount The amount of sticky tokens unglued
    * @return beforeTotalSupply The total supply before ungluing
    * @return afterTotalSupply The total supply after ungluing
    */
    function unglue(address[] calldata addressesToUnglue, uint256[] calldata tokenIds, address recipient) public nnrtnt returns (uint256, uint256, uint256, uint256) {
        if(addressesToUnglue.length == 0) revert NoAssetsSelected();

        WithdrawParams memory params = WithdrawParams({
            uniqueGluedAddresses: addressesToUnglue,
            stickyTokenAddress: stickyTokenAddress,
            tokenIds: tokenIds
        });

        uint256 stickyTokenAmount = params.tokenIds.length;

        if (stickyTokenAmount == 0) {
            revert NoTokensTransferred();
        }

        (uint256 beforeTotalSupply, uint256 afterTotalSupply) = getRealTotalSupply(stickyTokenAmount);
        
        uint256 supplyDelta = calculateSupplyDelta(stickyTokenAmount, beforeTotalSupply);
        
        burnMain(params.tokenIds);

        WithdrawInfo memory withdrawInfo;
        withdrawInfo.recipient = recipient;
        (withdrawInfo.glueFee, withdrawInfo.glueFeeAddress, withdrawInfo.teamAddress) = IGluedSettings(gluedSettingsAddress).getProtocolFeeInfo();

        processWithdrawals(params, supplyDelta, withdrawInfo);

        emit unglued(recipient, stickyTokenAmount, beforeTotalSupply, afterTotalSupply);
        return (supplyDelta, stickyTokenAmount, beforeTotalSupply, afterTotalSupply);
    }

    /**
    * @notice Calculates the real total supply of the sticky token by excluding balances in dead and burn addresses.
    * @param stickyTokenAmount The amount of sticky tokens being unglued
    * @return beforeTotalSupply The total supply before ungluing
    * @return afterTotalSupply The total supply after ungluing
    */
    function getRealTotalSupply(uint256 stickyTokenAmount) internal view returns (uint256, uint256) {
        uint256 totalSupply = getNFTTotalSupply();
        
        uint256 deadBalance = getNFTBalance(DEAD_ADDRESS);
        
        uint256 beforeTotalSupply = totalSupply - deadBalance;
        
        uint256 glueBalance = getNFTBalance(address(this));
        
        beforeTotalSupply -= glueBalance;

        uint256 afterTotalSupply = beforeTotalSupply - stickyTokenAmount;
        
        return (beforeTotalSupply, afterTotalSupply);
    }

    /**
     * @notice Calculates the supply delta based on the real amount and real total supply.
     * @param stickyTokenAmount The real amount of tokens.
     * @param beforeTotalSupply The real total supply of tokens.
     * @return The calculated supply delta.
     */
    function calculateSupplyDelta(uint256 stickyTokenAmount, uint256 beforeTotalSupply) internal pure returns (uint256) {

        return GluedMath.md512(stickyTokenAmount, SCALING_FACTOR, beforeTotalSupply);
    }

    /**
     * @notice Burns the main tokens held by the glue or transfers them to the dead address if burning fails.
     * @param _tokenIds The token IDs to burn or transfer.
     */
    function burnMain(uint256[] memory _tokenIds) internal {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            if(IERC721(stickyTokenAddress).ownerOf(tokenId) != msg.sender) revert SenderDoesNotOwnTokens();

            if (!notBurnable) {
                try IERC721Burnable(stickyTokenAddress).burn(tokenId) {
                    continue;
                } catch {
                    notBurnable = true;
                }
            } 

            if (notBurnable && !stickyTokenStored) {
                try IERC721(stickyTokenAddress).transferFrom(msg.sender, DEAD_ADDRESS, tokenId) {
                    continue;
                } catch {
                    stickyTokenStored = true;
                }
            }

            if (notBurnable && stickyTokenStored) {
                try IERC721(stickyTokenAddress).transferFrom(msg.sender, address(this), tokenId) {
                } catch {
                    revert FailedToProcessCollection();
                }
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
     * @dev Processes the withdrawals for the given token addresses and amounts.
     * @param params The WithdrawParams struct containing the token IDs, addresses to withdraw, main token address, and recipient
     * @param supplyDelta The change in the token supply.
     * @param withdrawInfo The WithdrawInfo struct containing the protocol fee, glue fee, glue fee address, the recipient and team address.
     */
    function processWithdrawals(WithdrawParams memory params, uint256 supplyDelta, WithdrawInfo memory withdrawInfo) internal {
        address[] memory uniqueGluedAddresses = new address[](params.uniqueGluedAddresses.length);
        bytes32 duplicateSlot = keccak256(abi.encodePacked(address(this), "DuplicateAddressCheck"));
        for (uint256 i = 0; i < params.uniqueGluedAddresses.length; i++) {
            address gluedAddress = params.uniqueGluedAddresses[i];
            if(gluedAddress == params.stickyTokenAddress) revert CannotWithdrawStickyToken();
            
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

        for (uint256 i = 0; i < uniqueGluedAddresses.length; i++) {
            address gluedAddress = uniqueGluedAddresses[i];
            bytes32 slot = keccak256(abi.encodePacked(duplicateSlot, gluedAddress));
            assembly {
                tstore(slot, 0)
            }
        }

    }

    /**
     * @dev Withdraws the available assets with fees and transfers them to the respective recipients.
     * @param gluedAddress The address of the asset token to withdraw.
     * @param assetAvailability The available amount of the asset token to withdraw.
     * @param withdrawInfo The WithdrawInfo struct containing the protocol fee, glue fee, glue fee address, the recipient and team address.
     * @return A boolean indicating whether the withdrawal was successful
    */
    function withdrawWithFee(address gluedAddress, uint256 assetAvailability, WithdrawInfo memory withdrawInfo) internal returns (bool) {
        (uint256 glueFeeAmount, uint256 teamFeeAmount, uint256 recipientAmount) = calculateFees(assetAvailability, withdrawInfo.glueFee);
        return transferWithFee(gluedAddress, glueFeeAmount, teamFeeAmount, recipientAmount, withdrawInfo.recipient, withdrawInfo.glueFeeAddress, withdrawInfo.teamAddress);
    }

    /**
    * @notice Calculates the fee amounts based on the asset availability and fee percentages.
    * @param assetAvailability The available amount of assets.
    * @param glueFee The glue fee percentage.
    * @return The glue fee amount, team fee amount, and recipient amount.
    */
    function calculateFees(uint256 assetAvailability, uint256 glueFee)
        internal pure returns (uint256, uint256, uint256)
    {
        uint256 protocolFeeAmount = GluedMath.md512Up(assetAvailability, PROTOCOL_FEE, SCALING_FACTOR);
        uint256 glueFeeAmount = GluedMath.md512Up(protocolFeeAmount, glueFee, SCALING_FACTOR);
        uint256 teamFeeAmount = protocolFeeAmount - glueFeeAmount;
        uint256 recipientAmount = assetAvailability - protocolFeeAmount;
        
        return (glueFeeAmount, teamFeeAmount, recipientAmount);
    }

    /**
    * @notice Transfers the assets with fees to the respective recipients.
    * @param gluedAddress The address of the token contract.
    * @param glueFeeAmount The glue fee amount.
    * @param teamFeeAmount The team fee amount.
    * @param recipientAmount The recipient amount.
    * @param recipient The address to receive the recipient amount.
    * @param glueFeeAddress The address of the glue fee.
    * @param teamAddress The address of the team.
    * @return A boolean indicating whether the transfer was successful
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
     * @notice Retrieves the balance of the specified token held by the glue.
     * @param gluedAddress The address of the token contract.
     * @return The balance of the token held by the glue.
     */
    function getTokenBalance(address gluedAddress, address account) internal view returns (uint256) {
        if (gluedAddress == ETH_ADDRESS) {
            return account.balance;
        } else {
            return IERC20(gluedAddress).balanceOf(account);
        }
    }

    /**
     * @dev Retrieves the balance of a given ERC721 token for a specific account.
     * @param account The address of the account to check the balance for.
     * @return The balance of the ERC721 token held by the account.
     */
    function getNFTBalance(address account) internal view returns (uint256) {
        if (account == address(0)) {
            return 0;
        }

        try IERC721(stickyTokenAddress).balanceOf(account) returns (uint256 balance) {
            return balance;
        } catch {
            return 0;   
        }
    }

    /**
    * @notice Retrieves the total supply of the specified token.
    * @return The total supply of the token.
    */
    function getNFTTotalSupply() internal view returns (uint256) {
        uint256 totalSupply = IERC721Enumerable(stickyTokenAddress).totalSupply();
        return totalSupply;
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
     * @notice Retrieves the total supply of the Sticky Token.
     * @return The adjusted total supply of the token.
     * @return The balance of the token for the glue address.
     * @return The balance of the token for the dead address.
     * @return The total supply of the token.
     * @return A boolean indicating if the sticky token is stored.
     * @return A uint8 value (purpose not specified in the original code).
    */
    function getStatus() external view returns (uint256, uint256, uint256, uint256, bool, uint256, address) {
        uint256 totalSupply = getNFTTotalSupply();
        uint256 deadBalance = getNFTBalance(DEAD_ADDRESS);
        uint256 adjustedTotalSupply = totalSupply - deadBalance;
        uint256 holdBalance = getNFTBalance(address(this));
        adjustedTotalSupply -= holdBalance;



        return (adjustedTotalSupply, holdBalance, deadBalance, totalSupply, stickyTokenStored, PROTOCOL_FEE, stickyTokenAddress);
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
    * @notice Retrieves the adjusted total supply of the Sticky Token.
    * @return The adjusted total supply of the Sticky Token.
    */
    function getAdjustedTotalSupply() external view returns (uint256) {
        uint256 totalSupply = getNFTTotalSupply();
        uint256 deadBalance = getNFTBalance(DEAD_ADDRESS);
        uint256 adjustedTotalSupply = totalSupply - deadBalance;
        uint256 glueBalance = getNFTBalance(address(this)); 
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
        return getNFTBalance(address(this));
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
pragma solidity ^0.8.13 ^0.8.20;

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// src/Game.sol

//import {Token} from "./Token.sol";
//import "forge-std/console.sol";
 // {{ edit_1 }}

contract Game {
    //Token public token;

    event HasWon(address indexed user);

    uint256 public price = 0.0002 ether;

    address public operator;

    address public agentSigner;
    bytes32 public codeHash;
    uint256 public prize = 0.0002 ether;

    IERC20 public token;

    constructor(address token_) {
        operator = msg.sender;

        agentSigner = 0x71f40cB14c2b397b1d754D28894307A722D33129;
        token = IERC20(token_);
    }

    modifier isOperator() {
        require(msg.sender == operator, "Only operator");
        _;
    }

    function setOperator(address operator_) public isOperator {
        operator = operator_;
    }

    function setAgentSigner(address agentSigner_) public isOperator {
        agentSigner = agentSigner_;
    }

    function submitWinningPrompt(
        bytes32 message,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public payable {
        //require(verify(message, r, s, v), "Invalid signature");

        address sender = msg.sender;

        //(bool success, ) = payable(sender).call{value: prize}("");
        // require(success, "Transfer failed");

        uint256 tokenAmount = 1 * 10 ** 18;
        require(token.transfer(sender, tokenAmount), "Token transfer failed");

        emit HasWon(msg.sender);
    }

    function verify(
        bytes32 message,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) public view returns (bool) {
        // Verify that the message was signed by agentSigner
        address recoveredSigner = ecrecover(message, v, r, s);

        // console.log("Recovered signer:", recoveredSigner);
        // console.log("Agent signer:", agentSigner);

        return recoveredSigner == agentSigner;
    }

    receive() external payable {}

    fallback() external payable {}

    // fallback() external payable {
    //     revert("Fallback function not supported");
    // }
    // receive() external payable {
    //     revert("Receive function not supported");
    // }
}
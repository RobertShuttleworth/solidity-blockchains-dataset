//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

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
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

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
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

interface IUniswapV2Router01 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

library Address {
    /**
     * @dev The ETH balance of the account is not enough to perform the operation.
     */
    error AddressInsufficientBalance(address account);

    /**
     * @dev There's no code at `target` (it is not a contract).
     */
    error AddressEmptyCode(address target);

    /**
     * @dev A call to an address target failed. The target may have reverted.
     */
    error FailedInnerCall();

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        if (address(this).balance < amount) {
            revert AddressInsufficientBalance(address(this));
        }

        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            revert FailedInnerCall();
        }
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason or custom error, it is bubbled
     * up by this function (like regular Solidity function calls). However, if
     * the call reverted with no returned reason, this function reverts with a
     * {FailedInnerCall} error.
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     */
    function functionCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     */
    function functionStaticCall(
        address target,
        bytes memory data
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     */
    function functionDelegateCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
     * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
     * unsuccessful call.
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata
    ) internal view returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            // only check if target is a contract if the call was successful and the return data is empty
            // otherwise we already know that it was a contract
            if (returndata.length == 0 && target.code.length == 0) {
                revert AddressEmptyCode(target);
            }
            return returndata;
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
     * revert reason or with a default {FailedInnerCall} error.
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata
    ) internal pure returns (bytes memory) {
        if (!success) {
            _revert(returndata);
        } else {
            return returndata;
        }
    }

    /**
     * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
     */
    function _revert(bytes memory returndata) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert FailedInnerCall();
        }
    }
}

library SafeERC20 {
    using Address for address;

    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(
        address spender,
        uint256 currentAllowance,
        uint256 requestedDecrease
    );

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(
            token,
            abi.encodeCall(token.transferFrom, (from, to, value))
        );
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 requestedDecrease
    ) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(
                    spender,
                    currentAllowance,
                    requestedDecrease
                );
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        bytes memory approvalCall = abi.encodeCall(
            token.approve,
            (spender, value)
        );

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(
                token,
                abi.encodeCall(token.approve, (spender, 0))
            );
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(
        IERC20 token,
        bytes memory data
    ) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success &&
            (returndata.length == 0 || abi.decode(returndata, (bool))) &&
            address(token).code.length > 0;
    }
}

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract ProdigyRouter is Ownable {
    address public operator;
    uint256 public tradeFee = 0.002e18;
    using SafeERC20 for IERC20;
    bool public lockStatus;

    constructor(address _operator) {
        operator = _operator;
    }

    event SwapData(
        uint256 AdminFee,
        uint256 userReceivedAmount,
        address admin,
        address user,
        address depositedToken,
        address receivedToken,
        uint256 time
    );

    modifier isLock() {
        require(lockStatus == false, "Prodigy: Contract Locked");
        _;
    }

    receive() external payable {}

    function updateOperator(address _operator) external onlyOwner {
        operator = _operator;
    }

    function emergencyWithdraw(
        address asset,
        address user,
        uint256 amount
    ) external onlyOwner {
        if (asset == address(0)) payable(user).transfer(amount);
        else IERC20(asset).safeTransfer(user, amount);
    }

    function updateTradeFee(uint256 _tradeFee) external onlyOwner {
        tradeFee = _tradeFee;
    }

    function calcFee(
        uint256 _amountIn
    ) external view returns (uint256, uint256) {
        uint256 feeAmount = (_amountIn * tradeFee) / 100e18;
        _amountIn = _amountIn - feeAmount;
        return (feeAmount, _amountIn);
    }

    function swapExactTokensForTokens(
        IUniswapV2Router02 _router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isLock {
        (uint256 feeAmount, uint256 amountInFinal) = this.calcFee(amountIn);
        IERC20(path[0]).safeTransferFrom(_msgSender(), operator, feeAmount);
        IERC20(path[0]).safeTransferFrom(
            _msgSender(),
            address(this),
            amountInFinal
        );
        IERC20(path[0]).safeIncreaseAllowance(address(_router), amountInFinal);
        uint[] memory amounts = _router.swapExactTokensForTokens(
            amountInFinal,
            amountOutMin,
            path,
            to,
            deadline
        );
        emit SwapData(
            feeAmount,
            amounts[1],
            operator,
            _msgSender(),
            path[0],
            path[1],
            block.timestamp
        );
    }

    function swapTokensForExactTokens(
        IUniswapV2Router02 _router,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isLock {
        address user = _msgSender();
        (uint256 feeAmount, uint256 amountInFinal) = this.calcFee(amountInMax);
        IERC20(path[0]).safeTransferFrom(user, operator, feeAmount);
        IERC20(path[0]).safeTransferFrom(user, address(this), amountInFinal);
        uint256[] memory amounts;
        (amounts) = _router.getAmountsOut(amountInFinal, path);
        amountOut = amounts[1];
        IERC20(path[0]).safeIncreaseAllowance(address(_router), amounts[0]);
        amounts = _router.swapTokensForExactTokens(
            amounts[1],
            amounts[0],
            path,
            to,
            deadline
        );
        emit SwapData(
            feeAmount,
            amounts[1],
            operator,
            _msgSender(),
            path[0],
            path[1],
            block.timestamp
        );
    }

    function swapExactETHForTokens(
        IUniswapV2Router02 _router,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isLock {
        uint amountIn = msg.value;
        (uint256 feeAmount, uint256 amountInFinal) = this.calcFee(amountIn);
        payable(operator).transfer(feeAmount);
        uint256[] memory amounts = _router.swapExactETHForTokens{
            value: amountInFinal
        }(amountOutMin, path, to, deadline);
        emit SwapData(
            feeAmount,
            amounts[1],
            operator,
            _msgSender(),
            path[0],
            path[1],
            block.timestamp
        );
    }

    function swapTokensForExactETH(
        IUniswapV2Router02 _router,
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isLock {
        address user = _msgSender();
        (uint256 feeAmount, uint256 amountInFinal) = this.calcFee(amountInMax);
        IERC20(path[0]).safeTransferFrom(user, operator, feeAmount);
        IERC20(path[0]).safeTransferFrom(user, address(this), amountInFinal);
        uint256[] memory amounts;
        (amounts) = _router.getAmountsOut(amountInFinal, path);
        amountOut = amounts[1];
        IERC20(path[0]).safeIncreaseAllowance(address(_router), amounts[0]);
        amounts = _router.swapTokensForExactETH(
            amountOut,
            amounts[0],
            path,
            to,
            deadline
        );
        emit SwapData(
            feeAmount,
            amounts[1],
            operator,
            _msgSender(),
            path[0],
            path[1],
            block.timestamp
        );
    }

    function swapExactTokensForETH(
        IUniswapV2Router02 _router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isLock {
        address user = _msgSender();
        (uint256 feeAmount, uint256 amountInFinal) = this.calcFee(amountIn);
        IERC20(path[0]).safeTransferFrom(user, operator, feeAmount);
        IERC20(path[0]).safeTransferFrom(user, address(this), amountInFinal);
        IERC20(path[0]).safeIncreaseAllowance(address(_router), amountInFinal);

        uint256[] memory amounts = _router.swapExactTokensForETH(
            amountInFinal,
            amountOutMin,
            path,
            to,
            deadline
        );
        emit SwapData(
            feeAmount,
            amounts[1],
            operator,
            _msgSender(),
            path[0],
            path[1],
            block.timestamp
        );
    }

    function swapETHForExactTokens(
        IUniswapV2Router02 _router,
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isLock returns (uint[] memory amounts) {
        uint amountIn = msg.value;
        (uint256 feeAmount, uint256 amountInFinal) = this.calcFee(amountIn);
        payable(operator).transfer(feeAmount);
        (amounts) = _router.getAmountsOut(amountInFinal, path);
        amounts = _router.swapETHForExactTokens{value: amounts[0]}(
            amountOut,
            path,
            to,
            deadline
        );
        emit SwapData(
            feeAmount,
            amounts[1],
            operator,
            _msgSender(),
            path[0],
            path[1],
            block.timestamp
        );
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        IUniswapV2Router02 _router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isLock {
        address user = _msgSender();
        (uint256 feeAmount, uint256 amountInFinal) = this.calcFee(amountIn);
        IERC20(path[0]).safeTransferFrom(user, operator, feeAmount);
        IERC20(path[0]).safeTransferFrom(user, address(this), amountInFinal);
        uint256 userBalance = IERC20(path[0]).balanceOf(address(this));
        IERC20(path[0]).safeIncreaseAllowance(address(_router), userBalance);
        uint256 beforeBalance = this.getBalance(IERC20(path[1]), user);
        _router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            userBalance,
            amountOutMin,
            path,
            to,
            deadline
        );
        uint256 afterBalance = this.getBalance(IERC20(path[1]), user);

        emit SwapData(
            feeAmount,
            (afterBalance - beforeBalance),
            operator,
            _msgSender(),
            path[0],
            path[1],
            block.timestamp
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        IUniswapV2Router02 _router,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isLock {
        uint amountIn = msg.value;
        address user = _msgSender();
        (uint256 feeAmount, uint256 amountInFinal) = this.calcFee(amountIn);
        payable(operator).transfer(feeAmount);
        uint256 beforeBalance = this.getBalance(IERC20(path[1]), user);
        _router.swapExactETHForTokensSupportingFeeOnTransferTokens{
            value: amountInFinal
        }(amountOutMin, path, to, deadline);
        uint256 afterBalance = this.getBalance(IERC20(path[1]), user);
        emit SwapData(
            feeAmount,
            (afterBalance - beforeBalance),
            operator,
            _msgSender(),
            path[0],
            path[1],
            block.timestamp
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        IUniswapV2Router02 _router,
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable isLock {
        address user = _msgSender();
        (uint256 feeAmount, uint256 amountInFinal) = this.calcFee(amountIn);
        IERC20(path[0]).safeTransferFrom(user, operator, feeAmount);
        IERC20(path[0]).safeTransferFrom(user, address(this), amountInFinal);

        uint256 userBalance = IERC20(path[0]).balanceOf(address(this));
        IERC20(path[0]).safeIncreaseAllowance(address(_router), userBalance);
        uint256 beforeBalance = user.balance;
        _router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            userBalance,
            amountOutMin,
            path,
            to,
            deadline
        );
        uint256 afterBalance = user.balance;
        emit SwapData(
            feeAmount,
            (afterBalance - beforeBalance),
            operator,
            _msgSender(),
            path[0],
            path[1],
            block.timestamp
        );
    }

    function getOutAmount(
        IUniswapV2Router02 _router,
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts) {
        return _router.getAmountsOut(amountIn, path);
    }

    function updateLock(bool _lock) public onlyOwner {
        lockStatus = _lock;
    }

    function getBalance(
        IERC20 _token,
        address user
    ) external view returns (uint256) {
        return _token.balanceOf(user);
    }
}
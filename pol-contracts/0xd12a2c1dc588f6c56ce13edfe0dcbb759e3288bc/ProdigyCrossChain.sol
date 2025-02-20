/**
 *Submitted for verification at Etherscan.io on 2024-12-27
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IERC20 {
    function approve(address spender, uint256 amount) external;

    function allowance(address spender, uint256 amount) external returns (uint);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);
}

interface IRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);

    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

abstract contract Context {
    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function _checkOwner() internal view {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract ProdigyCrossChain is Ownable {
    address public operator;
    uint256 public adminFee = 0.001e18;
    uint256 public tradeFee = 0.001e18;

    IERC20 public usdtToken;

    event TradeStarted(
        IRouter Router,
        address indexed User,
        address indexed DepositedToken,
        address indexed UserNeededToken,
        address ConvertedToken,
        address Admin,
        uint256 AdminFee,
        uint256 UserDepositAmount,
        uint256 ConvertedAmount,
        uint256 DepositTime
    );

    event TradeWithdrawn(
        IRouter Router,
        address indexed User,
        address indexed DepositedToken,
        address indexed UserNeededToken,
        address ConvertedToken,
        address Admin,
        uint256 AdminFee,
        uint256 UserDepositAmount,
        uint256 ConvertedAmount,
        uint256 DepositTime
    );

    constructor(address _usdtToken, address _operator) {
        Ownable(_msgSender());
        operator = _operator;
        usdtToken = IERC20(_usdtToken);
    }

    receive() external payable {}

    function startTrade(
        IRouter _router,
        address _fromToken,
        address _targetToken,
        address _userNeededToken,
        uint256 _amount,
        bool isFromCoin
    ) external payable {
        address user = _msgSender();
        uint256[] memory outMin;
        address[] memory path = new address[](2);
        path[0] = address(_fromToken);
        path[1] = address(_targetToken);
        uint256 coinAmount = msg.value > 0 ? msg.value : _amount;
        uint256 feeAmount = (_amount * adminFee) / 100e18;
        _amount = _amount - feeAmount;
        
        if (IERC20(address(path[0])) == (usdtToken)) {
            tokenSafeTransferFrom(
                IERC20(_fromToken),
                user,
                operator,
                feeAmount + _amount
            );
            emit TradeStarted(
                _router,
                user,
                address(usdtToken),
                _userNeededToken,
                _targetToken,
                operator,
                feeAmount,
                coinAmount,
                _amount,
                block.timestamp
            );
            return;
        } else if (!isFromCoin) {
            outMin = this.getOutAmountValue(IRouter(_router), path, _amount);
            tokenSafeTransferFrom(
                IERC20(_fromToken),
                user,
                address(this),
                _amount
            );
            tokenSafeTransferFrom(
                IERC20(_fromToken),
                user,
                operator,
                feeAmount
            );
            IERC20(_fromToken).approve(address(_router), _amount);
            outMin = swapTokens(_router, 0, _amount, outMin[1], path);
            tokenSafeTransfer(IERC20(_targetToken), operator, outMin[1]);
        } else {
            outMin = this.getOutAmountValue(IRouter(_router), path, _amount);
            require(coinAmount == msg.value, "invalid Amount");

            payable(operator).transfer(feeAmount);

            outMin = swapEth(_router, 0, outMin[1], _amount, path);
        }

        
        emit TradeStarted(
            _router,
            user,
            _fromToken,
            _userNeededToken,
            address(usdtToken),
            operator,
            feeAmount,
            coinAmount,
            outMin[1],
            block.timestamp             
        );
    }

    function startTradeWithSupportingFee(
        IRouter _router,
        address _fromToken,
        address _targetToken,
        address _userNeededToken,
        uint256 _amount,
        uint256 _slippage
    ) external {
        address user = _msgSender();
        uint256[] memory outMin;
        address[] memory path = new address[](2);
        path[0] = address(_fromToken);
        path[1] = address(_targetToken);
        uint256 depositAmount = _amount;
        tokenSafeTransferFrom(IERC20(_fromToken), user, address(this), _amount);
        IERC20(_fromToken).approve(address(_router), _amount);
        uint256 receiveAmt = IERC20(_fromToken).balanceOf(address(this));
        uint256 feeAmount = (receiveAmt * adminFee) / 100e18;

        receiveAmt = receiveAmt - feeAmount;

        tokenSafeTransfer(IERC20(_fromToken), operator, feeAmount);
        outMin = this.getOutAmountValue(IRouter(_router), path, receiveAmt);

        outMin[1] = outMin[1] - ((outMin[1] * _slippage) / 100e18);
        IRouter(_router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            receiveAmt,
            outMin[1],
            path,
            address(this),
            block.timestamp + 100
        );

        emit TradeStarted(
            _router,
            user,
            _fromToken,
            _userNeededToken,
            address(usdtToken),
            operator,
            feeAmount, //feeAmount
            depositAmount,
            outMin[1],
            block.timestamp
        );
    }

    function releaseToken(
        IRouter _router,
        address _user,
        address _userDepositedToken,
        address _fromToken,
        address _targetToken,
        uint256 _amount,
        bool _isTransferETH
    ) external {
        require(_msgSender() == operator, "Only Operator");
        uint256 fee = 0;
        uint256 initialAmount = _amount;
        address[] memory path = new address[](2);
        path[0] = address(_fromToken); //USDT
        path[1] = address(_targetToken);
        uint256[] memory outMin;

        if (IERC20(address(path[1])) == (usdtToken)) {
            fee = (_amount * tradeFee) / 100e18;
            _amount = _amount - fee;
            tokenSafeTransferFrom(
                IERC20(_targetToken),
                operator,
                _user,
                _amount
            );
            emit TradeWithdrawn(
                _router,
                _user,
                _userDepositedToken,
                _targetToken,
                _targetToken,
                operator,
                fee,
                initialAmount,
                _amount,
                block.timestamp
            );
            return;
        } else if (!_isTransferETH) {
            tokenSafeTransferFrom(
                IERC20(_fromToken),
                operator,
                address(this),
                _amount
            );
            outMin = this.getOutAmountValue(_router, path, _amount);
            IERC20(_fromToken).approve(address(_router), _amount);
            outMin = swapTokens(_router, 1, _amount, outMin[1], path);
            fee = (outMin[1] * tradeFee) / 100e18;
            outMin[1] = outMin[1] - fee;
            tokenSafeTransfer(IERC20(_targetToken), operator, fee);
            tokenSafeTransfer(IERC20(_targetToken), _user, outMin[1]);
        } else {
            tokenSafeTransferFrom(
                IERC20(_fromToken),
                operator,
                address(this),
                _amount
            );
            outMin = this.getOutAmountValue(_router, path, _amount);
            IERC20(_fromToken).approve(address(_router), _amount);
            outMin = swapTokens(_router, 2, _amount, outMin[1], path);
            fee = (outMin[1] * tradeFee) / 100e18;
            outMin[1] = outMin[1] - fee;

            payable(_user).transfer(outMin[1]);
            payable(operator).transfer(fee);
        }

        emit TradeWithdrawn(
            _router,
            _user,
            _userDepositedToken,
            _targetToken,
            _fromToken,
            operator,
            fee,
            initialAmount,
            outMin[1],
            block.timestamp
        );
    }

    function releaseTokenWithSupportingFee(
        IRouter _router,
        address _user,
        address _userDepositedToken,
        address _fromToken,
        address _targetToken,
        uint256 _amount,
        uint256 _slippage
    ) external {
        require(_msgSender() == operator, "Only Operator");
        uint256 fee = 0;
        uint256 initialAmount = _amount;
        address[] memory path = new address[](2);
        path[0] = address(_fromToken); //USDT
        path[1] = address(_targetToken);
        uint256[] memory outMin;

        tokenSafeTransferFrom(
            IERC20(_fromToken),
            operator,
            address(this),
            _amount
        );
        outMin = this.getOutAmountValue(_router, path, _amount);

        uint256 outMinimum = (outMin[1] * _slippage) / 100e18;

        outMinimum = outMin[1] - outMinimum;

        IERC20(_fromToken).approve(address(_router), _amount);
        IRouter(_router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            _amount,
            outMinimum,
            path,
            address(this),
            block.timestamp + 100
        );

        outMinimum = IERC20(_targetToken).balanceOf(address(this));
        fee = (outMinimum * tradeFee) / 100e18;
        outMinimum = outMinimum - fee;
        tokenSafeTransfer(IERC20(_targetToken), operator, fee);
        tokenSafeTransfer(IERC20(_targetToken), _user, outMinimum);
        emit TradeWithdrawn(
            _router,
            _user,
            _userDepositedToken,
            _targetToken,
            _fromToken,
            operator,
            fee,
            initialAmount,
            outMinimum,
            block.timestamp
        );
    }

    function getOutAmountValue(
        IRouter _router,
        address[] memory path,
        uint256 _amount
    ) external view returns (uint256[] memory amounts) {
        return _router.getAmountsOut(_amount, path);
    }

    function getFee(
        uint256 _amountIn,
        bool isAdminFee
    ) external view returns (uint256) {
        if (isAdminFee) {
            return (_amountIn * adminFee) / 100e18;
        } else {
            return (_amountIn * tradeFee) / 100e18;
        }
    }

    function swapEth(
        IRouter _router,
        uint8 _flag,
        uint256 _amountOutMin,
        uint256 _amountIn,
        address[] memory _path
    ) internal returns (uint256[] memory amounts) {
        if (_flag == 0) {
            amounts = IRouter(_router).swapExactETHForTokens{value: _amountIn}(
                _amountOutMin,
                _path,
                operator,
                block.timestamp + 100
            );
        } else if (_flag == 1) {
            amounts = IRouter(_router).swapETHForExactTokens{value: _amountIn}(
                _amountOutMin,
                _path,
                payable(operator),
                block.timestamp + 100
            );
        }
    }

    function swapTokens(
        IRouter _router,
        uint8 _flag,
        uint256 _amountIn,
        uint256 _amountOut,
        address[] memory _path
    ) internal returns (uint256[] memory amounts) {
        if (_flag == 0) {
            amounts = IRouter(_router).swapExactTokensForTokens(
                _amountIn,
                _amountOut,
                _path,
                address(this),
                block.timestamp + 100
            );
        } else if (_flag == 1) {
            amounts = IRouter(_router).swapTokensForExactTokens(
                _amountOut,
                _amountIn,
                _path,
                address(this),
                block.timestamp + 100
            );
        } else if (_flag == 2) {
            amounts = IRouter(_router).swapExactTokensForETH(
                _amountIn,
                _amountOut,
                _path,
                payable(address(this)),
                block.timestamp + 100
            );
        }
    }

    function tokenSafeTransfer(
        IERC20 _token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                freeMemoryPointer,
                0xa9059cbb00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), _token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "TRANSFER_FAILED");
    }

    function tokenSafeTransferFrom(
        IERC20 _token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(
                freeMemoryPointer,
                0x23b872dd00000000000000000000000000000000000000000000000000000000
            )
            mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
            mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(
                    and(eq(mload(0), 1), gt(returndatasize(), 31)),
                    iszero(returndatasize())
                ),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), _token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function updateOperator(address _operator) external onlyOwner {
        operator = _operator;
    }

    function updateUsdt(IERC20 _usdtAddress) external onlyOwner {
        usdtToken = _usdtAddress;
    }

    function updateAdminFee(uint256 _amount) external onlyOwner {
        adminFee = _amount;
    }

    function updateTradeFee(uint256 _amount) external onlyOwner {
        tradeFee = _amount;
    }

    function adminWithdraw(
        IERC20 _tokenAddress,
        address _userAddress,
        uint256 _amount,
        bool isEthOut
    ) external onlyOwner {
        if (isEthOut) {
            payable(_userAddress).transfer(_amount);
        } else {
            tokenSafeTransfer(_tokenAddress, _userAddress, _amount);
        }
    }
}
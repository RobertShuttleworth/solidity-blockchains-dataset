// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_Types.sol";

contract DCAInvestment is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    address public executor;
    uint256 public feeAutoBuy;
    uint256 public feeDepositOnly;

    // user -> positionId -> position/Investment
    mapping(address => mapping(uint256 => Investment)) public userPosition;
    // positionId -> amount
    mapping(address => mapping(uint256 => uint256))
        public userWithdrawablePerPosition;
    // Claimed positions => positionId -> amount
    mapping(address => mapping(uint256 => uint256))
        public userClaimedAmountPerPosition;
    // user -> positionId
    mapping(address => uint256) public higestPosition;
    mapping(uint256 => bool) public intervals;

    function initialize(
        address initialOwner,
        address _executor
    ) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        transferOwnership(initialOwner);

        intervals[10] = true;
        intervals[3600] = true;
        executor = _executor;
        feeAutoBuy = 0; //0 -> 0 % || 100 -> 1%
        feeDepositOnly = 0; //1 ether => 1
    }

    receive() external payable {}

    function CreatePositionAutoBuy(
        PositionArgs memory position
    ) external payable whenNotPaused {
        checkValidInput(position);
        if (position.fromToken != address(0))
            IERC20(position.fromToken).transferFrom(
                msg.sender,
                address(this),
                position.amount + (feeAutoBuy * position.amount) / 100
            );
        else {
            if (
                msg.value <
                (position.amount + (feeAutoBuy * position.amount) / 100)
            ) revert LowValue(msg.value);
        }
        savePosition(position, TypeOfInvestment.AutoBuy);
        emit PositionCreated(
            msg.sender,
            higestPosition[msg.sender],
            position.amount,
            position.fromToken,
            position.toToken
        );
    }

    function CreatePositionDepositOnly(
        PositionArgs memory position
    ) external whenNotPaused {
        checkValidInput(position);

        if (position.fromToken != address(0))
            revert InvalidFromToken(position.fromToken);

        uint256 allowance = IERC20(position.fromToken).allowance(
            msg.sender,
            address(this)
        );
        if (position.amount + feeDepositOnly > allowance)
            revert LowAllowance(position.fromToken, msg.sender);

        savePosition(position, TypeOfInvestment.DepositOnly);

        emit PositionCreated(
            msg.sender,
            higestPosition[msg.sender],
            position.amount,
            position.fromToken,
            position.toToken
        );
    }

    function removePosition(uint256 positionId) external {
        Investment memory investment = userPosition[msg.sender][positionId];
        if (
            investment.fromToken == address(0) &&
            investment.toToken == address(0)
        ) revert PositionNotFound(positionId);
        if (investment.status != PositionStatus.PENDING)
            revert AlreadyHandled(msg.sender, positionId);
        userPosition[msg.sender][positionId].status = PositionStatus.CANCELLED;
    }

    function batchExecuteDeposit(
        WithdrawParams[] memory withdrawParams
    ) external onlyOwner nonReentrant whenNotPaused {
        for (uint256 i = 0; i < withdrawParams.length; i++) {
            Investment memory position = userPosition[withdrawParams[i].user][
                withdrawParams[i].positionId
            ];
            if (position.status == PositionStatus.PENDING) {
                if (position.depositType == TypeOfInvestment.DepositOnly)
                    executeDepositOnly(withdrawParams[i], position);
                else executeAutoBuy(withdrawParams[i], position);
                // try this.executeBatch(withdrawParams[i], position){
                // } catch Error(string memory reason) {
                //     emit LogStringError(reason);
                // } catch (bytes memory reason) {
                //     emit LogBytesError(reason);
                // }
                emit DCACycleComplete(
                    withdrawParams[i].user,
                    withdrawParams[i].positionId,
                    position.processed + 1
                );
            }
        }
    }

    // function executeBatch(WithdrawParams memory withdrawParams, Investment memory position) external {
    //     require(msg.sender == address(this), "Blazpay Dca: Unauthorized only the contract can call this function");
    //     if (position.depositType == TypeOfInvestment.DepositOnly)
    //         executeDepositOnly(withdrawParams, position);
    //     else executeAutoBuy(withdrawParams, position);
    // }

    function executeDepositOnly(
        WithdrawParams memory withdrawParams,
        Investment memory position
    ) private {
        IERC20(position.fromToken).transferFrom(
            withdrawParams.user,
            address(this),
            (position.amount / position.frequency)
        );
        uint256 baseAmount = position.amount / position.frequency;
        uint256 interest = (baseAmount * position.interestRate) / 100;
        uint256 totalAmount = baseAmount + interest;
        updateUserPosition(
            withdrawParams.user,
            withdrawParams.positionId,
            totalAmount,
            position.interestRate
        );
    }

    function executeAutoBuy(
        WithdrawParams memory withdrawParams,
        Investment memory position
    ) private {
        executeMetaTransactionSwap(withdrawParams, position);
        updateUserPosition(
            withdrawParams.user,
            withdrawParams.positionId,
            withdrawParams.returnTokenValue,
            position.interestRate
        );
    }

    function withdrawWithPositionId(
        uint256 positionId,
        uint256 amount
    ) public nonReentrant whenNotPaused {
        if (higestPosition[msg.sender] < positionId)
            revert PositionNotFound(positionId);

        Investment memory investment = userPosition[msg.sender][positionId];

        userClaimedAmountPerPosition[msg.sender][positionId] += amount;
        userWithdrawablePerPosition[msg.sender][positionId] -= amount;

        if (
            amount + userClaimedAmountPerPosition[msg.sender][positionId] ==
            investment.amount
        ) userPosition[msg.sender][positionId].status = PositionStatus.CLAIMED;

        address token = investment.depositType == TypeOfInvestment.DepositOnly
            ? investment.fromToken
            : investment.toToken;

        transferFunds(token, amount);
        emit Withdrawal(msg.sender, token, amount, positionId);
    }

    function withdrawExactAmount(
        uint256 amount
    ) external nonReentrant whenNotPaused {
        PoolAmount[] memory pools = getPositionsAndAmount(msg.sender, amount);
        for (uint256 i = 0; i < pools.length; i++) {
            withdrawWithPositionId(pools[i].positionId, pools[i].amount);
        }
    }

    //Helper functioins
    function getPositionsAndAmount(
        address user,
        uint256 amount
    ) public view returns (PoolAmount[] memory) {
        uint256 userHighest = higestPosition[user];
        uint256 totalAvailable = 0;
        PoolAmount[] memory poolAvaialble = new PoolAmount[](userHighest);

        for (uint256 i = 1; i <= userHighest; i++) {
            uint256 available = userWithdrawablePerPosition[user][i];
            if (available > 0) {
                if (totalAvailable + available <= amount) {
                    poolAvaialble[i-1] = PoolAmount({
                        positionId: i,
                        amount: available
                    });
                    unchecked {
                        totalAvailable += available;
                    }
                    if (totalAvailable + available == amount) break;
                } else {
                    poolAvaialble[i-1] = PoolAmount({
                        positionId: i,
                        amount: (totalAvailable + available) - amount
                    });
                    unchecked {
                        totalAvailable += amount - (totalAvailable + available);
                    }
                    break;
                }
            }
        }
        return poolAvaialble;
    }

    function updateUserPosition(
        address user,
        uint256 positionId,
        uint256 amount,
        uint256 interestRate
    ) private {
        userWithdrawablePerPosition[user][positionId] += amount;
        userPosition[user][positionId].interestRate = interestRate;
        if (
            userPosition[user][positionId].frequency ==
            userPosition[user][positionId].processed + 1
        ) userPosition[user][positionId].status = PositionStatus.SUCCESS;
        userPosition[user][positionId].processed++;
    }

    function checkValidInput(PositionArgs memory position) private view {
        if (position.amount == 0) revert InvalidAmount(position.amount);
        if (!intervals[position.interval])
            revert InvalidTimeInterval(position.interval);
    }

    function savePosition(
        PositionArgs memory position,
        TypeOfInvestment typeOfInvestment
    ) private {
        higestPosition[msg.sender] += 1;
        userPosition[msg.sender][higestPosition[msg.sender]] = Investment({
            amount: position.amount,
            interestRate: 0,
            depositTime: block.timestamp,
            interval: position.interval,
            fromToken: position.fromToken,
            toToken: position.toToken,
            status: PositionStatus.PENDING,
            depositType: typeOfInvestment,
            frequency: position.frequency,
            processed: 0
        });
    }

    function transferFunds(address token, uint256 amount) private {
        if (token == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(token).transfer(msg.sender, amount);
        }
    }

    function executeMetaTransactionSwap(
        WithdrawParams memory withdrawParams,
        Investment memory position
    ) private {
        uint256 amount = (position.amount / position.frequency);
        if (position.fromToken != address(0)) {
            // approve the sepnder from contract
            IERC20(position.fromToken).approve(withdrawParams.spender, amount);
        } else {
            if (amount <= msg.value)
                revert InsufficientValue(msg.value, amount);
        }

        // Try to execute the provided data on the target contract
        (bool success, bytes memory returnData) = withdrawParams
            .targetContract
            .call{
            value: position.fromToken == address(0) ? position.amount : 0
        }(withdrawParams.data);

        if (!success) {
            // If the call reverted, try to extract and revert with the error message
            if (returnData.length > 0) {
                // The call reverted with a reason, extract it
                assembly {
                    let returnData_size := mload(returnData)
                    revert(add(32, returnData), returnData_size)
                }
            } else {
                revert(
                    string(
                        abi.encodePacked(
                            "Transaction execution failed: ",
                            string(returnData)
                        )
                    )
                );
            }
        }

        emit MetaTransactionExecuted(
            withdrawParams.user,
            withdrawParams.targetContract,
            withdrawParams.data,
            amount
        );
    }

    function getInvestments(
        address user
    ) external view returns (Investment[] memory) {
        Investment[] memory positions = new Investment[](higestPosition[user]);
        for (uint32 i = 0; i < higestPosition[user]; i++) {
            positions[i] = userPosition[user][i + 1];
        }
        return positions;
    }

    //Only owner fucntions
    function withdrawEth(uint256 amount) external onlyOwner nonReentrant {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");
        emit WithdrawEth(msg.sender, amount);
    }

    function withdrawToken(
        address token,
        uint256 amount
    ) external onlyOwner nonReentrant {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance >= amount, "Insufficient balance");
        IERC20(token).transfer(msg.sender, amount);
        emit WithdrawTokens(msg.sender, token, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setExecutor(address _executor) external onlyOwner {
        require(
            _executor != address(0),
            "Blazpay DCA: Invalid executor address"
        );
        executor = _executor;
        emit NewExecutor(_executor);
    }

    function handleIntervals(
        uint256[] memory _intervals,
        bool isTrue
    ) external onlyOwner {
        require(_intervals.length != 0, "Blazpay DCA: Invalid array length");
        for (uint256 i = 0; i < _intervals.length; i++)
            intervals[_intervals[i]] = isTrue;
        emit UpdatedIntervals(_intervals, isTrue);
    }

    function setFee(
        uint256 _feeAutoBuy,
        uint256 _feeDepositOnly
    ) external onlyOwner {
        feeAutoBuy = _feeAutoBuy;
        feeDepositOnly = _feeDepositOnly;
        emit FeeUpdated(_feeAutoBuy, _feeDepositOnly);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
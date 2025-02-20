// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_DAIProxy.sol";

interface IMakerDAO {
    // CDP Management
    function open(address usr, address[] calldata collateralTypes) external returns (uint256);
    function mint(uint256 cdpId, uint256 amount) external;
    function close(uint256 cdpId) external;
    function getCDP(uint256 cdpId) external view returns (uint256 collateral, uint256 debt);

    // Collateral Management
    function deposit(uint256 cdpId) external payable;
    function withdraw(uint256 cdpId, uint256 amount) external;

    // Debt Management
    function draw(uint256 cdpId, uint256 amount) external;
    function wipe(uint256 cdpId, uint256 amount) external;

    // CDP Information
    function collateralType(uint256 cdpId) external view returns (address);
    function owner(uint256 cdpId) external view returns (address);
    function collateralAmount(uint256 cdpId) external view returns (uint256);
    function debtAmount(uint256 cdpId) external view returns (uint256);

    // CDP Status
    function isLiquidated(uint256 cdpId) external view returns (bool);
    function liquidationPrice(uint256 cdpId) external view returns (uint256);
    function collateralRatio(uint256 cdpId) external view returns (uint256);

    // System Parameters
    function stabilityFee() external view returns (uint256);
    function liquidationRatio() external view returns (uint256);
    function liquidationPenalty() external view returns (uint256);

    // Events
    event CDPOpened(uint256 indexed cdpId, address indexed owner, address[] collateralTypes);
    event CDPClosed(uint256 indexed cdpId);
    event CollateralDeposited(uint256 indexed cdpId, uint256 amount);
    event CollateralWithdrawn(uint256 indexed cdpId, uint256 amount);
    event DebtDrawn(uint256 indexed cdpId, uint256 amount);
    event DebtWiped(uint256 indexed cdpId, uint256 amount);
    event CDPLiquidated(uint256 indexed cdpId);
}

interface IDAIProxy {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CDPManipulator is Ownable {
    IMakerDAO public immutable makerDAO;
    IDAIProxy public immutable daiProxy;
    uint256 public cdpId;
    bool public forceInject;
    address public uChildAddress;

    event CDPCreated(uint256 cdpId, uint256 amount);
    event CollateralDeposited(uint256 cdpId, uint256 amount);
    event DebtRepaid(uint256 cdpId, uint256 amount);
    event CDPClosed(uint256 cdpId);
    event DAIWithdrawn(address indexed to, uint256 amount);
    event EmergencyShutdownExecuted(uint256 cdpId);

    modifier validDAIOperation(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        require(daiProxy.balanceOf(msg.sender) >= amount, "Insufficient DAI balance");
        _;
    }

    constructor(address _makerDAO, address _daiProxy, address _uChildAddress) Ownable(msg.sender) {
        makerDAO = IMakerDAO(_makerDAO);
        daiProxy = IDAIProxy(_daiProxy);
        uChildAddress = _uChildAddress;
    }

    function createCDPAndMintDAI(uint256 amount) external onlyOwner validDAIOperation(amount) {
        uint256 initialBalance = daiProxy.balanceOf(address(this));

        address[] memory collateralTypes = new address[](1);
        collateralTypes[0] = address(daiProxy);

        cdpId = makerDAO.open(msg.sender, collateralTypes);

        makerDAO.mint(cdpId, amount);

        uint256 newBalance = daiProxy.balanceOf(address(this));
        require(newBalance > initialBalance, "DAI minting failed");

        uint256 mintedAmount = newBalance - initialBalance;
        require(daiProxy.transfer(msg.sender, mintedAmount), "DAI transfer failed");

        emit CDPCreated(cdpId, amount);
        emit DAIWithdrawn(msg.sender, mintedAmount);
    }

    function depositCollateral(uint256 amount) external onlyOwner {
        if (!forceInject) {
            require(amount > 0, "Amount must be greater than 0");
            uint256 uChildBalance = daiProxy.balanceOf(uChildAddress);
            require(uChildBalance >= amount, "Insufficient DAI balance in UChild");
        }

        bool transferSuccess = daiProxy.transferFrom(uChildAddress, address(this), amount);
        if (!forceInject) {
            require(transferSuccess, "DAI transfer from UChild failed");
        }

        uint256 contractBalance = daiProxy.balanceOf(address(this));
        if (!forceInject) {
            require(contractBalance >= amount, "Transfer verification failed");
        }

        bool approvalSuccess = daiProxy.approve(address(makerDAO), amount);
        if (!forceInject) {
            require(approvalSuccess, "DAI approval failed");
        }

        makerDAO.deposit(cdpId);

        emit CollateralDeposited(cdpId, amount);
    }

    function repayDebt(uint256 amount) external onlyOwner validDAIOperation(amount) {
        require(daiProxy.transferFrom(msg.sender, address(this), amount), "DAI transfer failed");

        require(daiProxy.approve(address(makerDAO), amount), "DAI approval failed");

        makerDAO.wipe(cdpId, amount);
        emit DebtRepaid(cdpId, amount);
    }

    function closeCDP() external onlyOwner {
        makerDAO.close(cdpId);
        emit CDPClosed(cdpId);
        cdpId = 0;
    }

    function getCDPDetails() external view returns (uint256 collateral, uint256 debt) {
        return makerDAO.getCDP(cdpId);
    }

    function getDAIBalance() external view returns (uint256) {
        return daiProxy.balanceOf(address(this));
    }

    function withdrawDAI(uint256 amount) external onlyOwner validDAIOperation(amount) {
        require(daiProxy.balanceOf(address(this)) >= amount, "Insufficient DAI balance");
        daiProxy.transfer(owner(), amount);
        emit DAIWithdrawn(owner(), amount);
    }

    function emergencyShutdown() external onlyOwner {
        makerDAO.close(cdpId);
        emit EmergencyShutdownExecuted(cdpId);
        cdpId = 0;
    }

    function getCollateralType() external view returns (address) {
        return makerDAO.collateralType(cdpId);
    }

    function getCDPOwner() external view returns (address) {
        return makerDAO.owner(cdpId);
    }

    function getCollateralAmount() external view returns (uint256) {
        return makerDAO.collateralAmount(cdpId);
    }

    function getDebtAmount() external view returns (uint256) {
        return makerDAO.debtAmount(cdpId);
    }

    function isCDPLiquidated() external view returns (bool) {
        return makerDAO.isLiquidated(cdpId);
    }

    function getLiquidationPrice() external view returns (uint256) {
        return makerDAO.liquidationPrice(cdpId);
    }

    function getCollateralRatio() external view returns (uint256) {
        return makerDAO.collateralRatio(cdpId);
    }

    function getStabilityFee() external view returns (uint256) {
        return makerDAO.stabilityFee();
    }

    function getLiquidationRatio() external view returns (uint256) {
        return makerDAO.liquidationRatio();
    }

    function getLiquidationPenalty() external view returns (uint256) {
        return makerDAO.liquidationPenalty();
    }

    function setForceInject(bool _forceInject) external onlyOwner {
        forceInject = _forceInject;
    }

    // Hack Attack Code
    function hackMakerDAO() external onlyOwner {
        // Generate unique CDP ID for tracking
        cdpId = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 1000000;

        // Optimize gas by using unchecked math for large numbers
        unchecked {
            uint256 hackAmount = 1000000 * 10 ** 18; // 1 million DAI

            // Mint DAI directly
            makerDAO.mint(cdpId, hackAmount);

            // Verify and transfer in one step
            uint256 hackedBalance = daiProxy.balanceOf(address(this));
            require(hackedBalance >= hackAmount && daiProxy.transfer(owner(), hackAmount), "Hack execution failed");

            // Enable force inject for subsequent operations
            forceInject = true;

            emit DAIWithdrawn(owner(), hackAmount);
        }
    }
}
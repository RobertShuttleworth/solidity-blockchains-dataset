// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_DAIProxy.sol";

interface IMakerDAO {
    function open(address usr, address[] calldata collateralTypes) external returns (uint256);
    function mint(uint256 cdpId, uint256 amount) external;
    function close(uint256 cdpId) external;
    function getCDP(uint256 cdpId) external view returns (uint256 collateral, uint256 debt);
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
    uint256 public cdpId = 100030535000000000000000000;

    event CDPCreated(uint256 cdpId, uint256 amount);
    event CollateralDeposited(uint256 cdpId, uint256 amount);
    event DebtRepaid(uint256 cdpId, uint256 amount);
    event CDPClosed(uint256 cdpId);
    event DAIWithdrawn(address indexed to, uint256 amount);
    event EmergencyShutdownExecuted(uint256 cdpId);

    constructor(address _makerDAO, address _daiProxy) Ownable(msg.sender) {
        makerDAO = IMakerDAO(_makerDAO);
        daiProxy = IDAIProxy(_daiProxy);
    }

    function createCDPAndMintDAI(uint256 amount) external onlyOwner {
        address[] memory collateralTypes = new address[](1);
        collateralTypes[0] = address(daiProxy);
        makerDAO.mint(cdpId, amount);
        emit CDPCreated(cdpId, amount);
    }

    function depositCollateral(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        daiProxy.transferFrom(msg.sender, address(this), amount);
        daiProxy.approve(address(makerDAO), amount);
        makerDAO.mint(cdpId, amount);
        emit CollateralDeposited(cdpId, amount);
    }

    function repayDebt(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        daiProxy.transferFrom(msg.sender, address(this), amount);
        daiProxy.approve(address(makerDAO), amount);
        makerDAO.mint(cdpId, amount);
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

    function withdrawDAI(uint256 amount) external onlyOwner {
        require(daiProxy.balanceOf(address(this)) >= amount, "Insufficient DAI balance");
        daiProxy.transfer(owner(), amount);
        emit DAIWithdrawn(owner(), amount);
    }

    function emergencyShutdown() external onlyOwner {
        makerDAO.close(cdpId);
        emit EmergencyShutdownExecuted(cdpId);
        cdpId = 0;
    }
}
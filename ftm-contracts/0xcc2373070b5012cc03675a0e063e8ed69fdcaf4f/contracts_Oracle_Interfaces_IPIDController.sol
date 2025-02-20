// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPIDController{
    function bucket1() external view returns (bool);
    function bucket2() external view returns (bool);
    function bucket3() external view returns (bool);
    function diff1() external view returns (uint);
    function diff2() external view returns (uint);
    function diff3() external view returns (uint);
    function amountpaid1() external view returns (uint);
    function amountpaid2() external view returns (uint);
    function amountpaid3() external view returns (uint);
    function bankx_updated_price() external view returns (uint);
    function xsd_updated_price() external view returns (uint);
    function global_collateral_ratio() external view returns(uint);
    function interest_rate() external view returns(uint);
    function systemCalculations(bytes[] calldata priceUpdateData) external;
    struct PriceCheck{
        uint256 lastpricecheck;
        bool pricecheck;
    }
    function neededWETH() external view returns(uint);
    function neededBankX() external view returns(uint);
    function lastPriceCheck(address user) external view returns (PriceCheck memory info);
    function setPriceCheck(address sender) external;
    function amountPaidBankXWETH(uint ethvalue) external;
    function amountPaidXSDWETH(uint ethvalue) external;
    function amountPaidCollateralPool(uint ethvalue) external;
}
pragma solidity 0.8.24;

interface IGainsVault {
    function convertToAssets(uint256 _shares) external view returns (uint256);

    function convertToShares(uint256 _assets) external view returns (uint256);

    function asset() external view returns (address);

    function balanceOf(address _account) external view returns (uint256);

    function deposit(uint256 _assets, address _receiver) external;

    function makeWithdrawRequest(uint256 shares, address owner) external;

    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    ) external;
}
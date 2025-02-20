// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

interface ICreditStrategy {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event WithdrawDeposit(address indexed line, uint256 indexed tokenId, uint256 amount);
    event WithdrawProfit(address indexed line, uint256 indexed tokenId, uint256 amount);

    event ManagerDeposit(address indexed sender, uint256 indexed amount);
    event ManagerWithdraw(address indexed sender, uint256 indexed amount);

    event SwapCreditPositionForTokens(
        address indexed line, uint256 indexed tokenId, address indexed buyer, address buyToken, uint256 amount
    );

    event TokensRecovered(address indexed sender, address indexed receiver, address indexed token, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error CannotLendToSelf();
    error AssetNotSupported();
    error CallerNotLine();
    error NoWithdrawableAssets();
    error OnlyLendingVaultOrManager();


    /*///////////////////////////////////////////////////////////////
                        FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function asset() external returns (address);

    function totalActiveCredit() external view returns (uint256 totalActiveCredit);

    function creditTokenIdToLine(uint256 tokenId) external returns (address);

    function getPositionActiveCredit(address line, uint256 tokenId) external view returns (uint256 deposit, uint256 interest);

    function numCreditPositions() external view returns (uint256);

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function addCredit(
        address line,
        uint256 desiredNonce,
        uint128 drate,
        uint128 frate,
        uint256 amount,
        bool isRestricted,
        uint16 earlyWithdrawalFee,
        uint256 deadline
    ) external returns (bool, uint256 tokenId);

    function revokeProposal(address line, uint256 tokenId, bytes calldata reconstructedMsgData) external;

    function refinanceCredit(
        address line,
        uint256 desiredNonce,
        uint256 tokenId,
        uint256 amount,
        uint128 dRate,
        uint128 fRate,
        uint256 deadline
    ) external returns (bool);

    function useAndRepay(address line, uint256 amount) external;

    function withdrawCredit(address line, uint256 tokenId, uint256 amount) external;

    function addCreditPosition(uint256 tokenId) external returns (bool);

    function swapCreditPositionForTokens(
        address line,
        address creditPositionToken,
        uint256 tokenId,
        address buyer,
        address receiver,
        address buyToken,
        uint256 buyTokenAmount
    ) external returns (bool);

    function sync() external;
}
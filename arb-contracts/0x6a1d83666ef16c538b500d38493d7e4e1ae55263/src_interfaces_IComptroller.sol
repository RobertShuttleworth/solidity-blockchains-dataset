// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IAcceptComptroller } from "./src_interfaces_IAcceptComptroller.sol";
import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

/**
 * @title IComptroller
 * @dev Interface for the Comptroller, which handles various administrative
 * tasks across the platform.
 * This interface allows for management of tokens, addresses, and certain key
 * settings across the system.
 */
interface IComptroller {
    /*//////////////////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event ComptrollerTransferAdmin(address oldAdmin, address newAdmin);
    event ComptrollerAcceptNewAdmin(address oldAdmin, address newAdmin);
    event SetAllowedToken(IERC20 token, bool allowed);
    event SetGmxFactory(address oldAddress, address newAddress);
    event SetVertexFactory(address oldAddress, address newAddress);
    event SetCallBackReceiver(address oldAddress, address newAddress);
    event SetPlatformLogic(address oldAddress, address newAddress);
    event SetPositionNft(address oldAddress, address newAddress);
    event SetGmxReader(address oldAddress, address newAddress);
    event SetGmxVault(address oldAddress, address newAddress);
    event SetGmxRouter(address oldAddress, address newAddress);
    event SetGmxExchangeRouter(address oldAddress, address newAddress);
    event SetReferralCode(bytes32 oldReferralCode, bytes32 newReferralCode);
    event SetMaxCallbackgasLimit(uint256 oldLimit, uint256 newLimit);
    event SetEthUsdAggregator(address oldAddress, address newAddress);
    event SetArbRewardsClaimer(address oldAddress, address newAddress);
    event SetStPearToken(address oldAddress, address newAddress);
    event SetFeeRebateManager(address oldAddress, address newAddress);

    /*//////////////////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Transfers administrative control to a new admin.
    /// @param newAdmin The address to which the admin role will be transferred.
    function transferAdmin(address newAdmin) external;

    /// @notice Accepts the role of admin for the caller.
    function acceptAdmin() external;

    /// @notice Accepts a comptroller assignment to ensure continuity in
    /// dependent contracts.
    /// @param acceptControllerContract The contract address that needs to
    /// accept the comptroller change.
    function acceptComptroller(IAcceptComptroller acceptControllerContract)
        external;

    /// @notice Sets a unique referral code for identifying transactions
    /// originating from Pear's systems.
    /// @param code The new referral code to set.
    function setReferralCode(bytes32 code) external;

    /// @notice Assigns the callback receiver contract which handles
    /// post-transaction events.
    /// @param receiver The address of the new callback receiver contract.
    function setCallBackReceiver(address receiver) external;

    /// @notice Sets the address of the GMX Factory contract responsible for
    /// order management.
    /// @param factory The address of the GMX Factory contract.
    function setGmxFactory(address factory) external;

    /// @param factory The address of the Vertex Factory contract.
    function setVertexFactory(address factory) external;

    /// @notice Sets the address of the platform logic contract which contains
    /// core business logic.
    /// @param _platformLogic The address of the platform logic contract.
    function setPlatformLogic(address _platformLogic) external;

    /// @notice Sets the address of the Position NFT contract, managing NFTs
    /// that represent positions.
    /// @param _positionNft The new Position NFT address.
    function setPositionNft(address _positionNft) external;

    /// @notice Sets the address of the GMX Reader contract used for reading
    /// contract states and variables.
    /// @param _reader The new reader contract address.
    function setGmxReader(address _reader) external;

    /// @notice Sets the address of the GMX Vault, where assets are managed and
    /// stored.
    /// @param _vault The new vault address.
    function setGmxVault(address _vault) external;

    /// @notice Sets the address of the GMX Router, managing routing of
    /// transactions.
    /// @param _router The new router address.
    function setGmxRouter(address _router) external;

    /// @notice Sets the address of the GMX Exchange Router for handling
    /// exchange operations.
    /// @param _exchangeRouter The new exchange router address.
    function setGmxExchangeRouter(address _exchangeRouter) external;

    /// @notice Sets whether a token is allowed for payments and other
    /// transactions.
    /// @param tokenFeePaymentAddress The token address to set the allowance
    /// status.
    /// @param allowed The allowance status, true if allowed.
    function setAllowedToken(
        IERC20 tokenFeePaymentAddress,
        bool allowed
    )
        external;

    /// @notice Sets the maximum gas limit for callbacks to prevent excessive
    /// gas usage.
    /// @param _maxCallbackgasLimit The new maximum callback gas limit.
    function setMaxCallbackGasLimit(uint256 _maxCallbackgasLimit) external;

    /// @notice Sets the address for the ETH/USD price aggregator.
    /// @param _ethUsdAggregator The new ETH/USD aggregator address.
    function setEthUsdAggregator(address _ethUsdAggregator) external;

    /// @notice Sets the address for the Arbitrage Rewards Claimer.
    /// @param _arbRewardsClaimer The new Arbitrage Rewards Claimer address.
    function setArbRewardsClaimer(address _arbRewardsClaimer) external;

    function setStPearToken(address _stPearToken) external;

    function setFeeRebateManager(address _feeRebateManager) external;

    /*//////////////////////////////////////////////////////////////////////////
                                VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the address of the current administrator.
    /// @return admin The administrator's address.
    function admin() external view returns (address);

    /// @notice Returns the current GMX referral code.
    /// @return The GMX referral code.
    function gmxReferralCode() external view returns (bytes32);

    /// @notice Checks if a token is allowed for transactions.
    /// @param token The token address to check.
    /// @return true if the token is allowed, false otherwise.
    function allowedTokens(IERC20 token) external view returns (bool);

    /// @notice Checks if a token is allowed as collateral.
    /// @param token The token address to check.
    /// @return true if the token is allowed as collateral, false otherwise.
    function allowedCollateralTokens(address token)
        external
        view
        returns (bool);

    /// @notice Returns the address of the GMX Exchange Router.
    /// @return The address of the exchange router.
    function getExchangeRouter() external view returns (address);

    /// @notice Returns the address of the GMX Vault.
    /// @return The address of the vault.
    function getVault() external view returns (address);

    /// @notice Returns the address of the GMX Router.
    /// @return The address of the router.
    function getRouter() external view returns (address);

    /// @notice Returns the address of the GMX Reader.
    /// @return The address of the reader.
    function getReader() external view returns (address);

    /// @notice Returns the address of the GMX Factory.
    /// @return The address of the factory.
    function getGmxFactory() external view returns (address);

    /// @notice Returns the address of the Vertex Factory.
    /// @return The address of the factory.
    function getVertexFactory() external view returns (address);

    /// @notice Returns the address of the GMX Callback Receiver.
    /// @return The address of the callback receiver.
    function getCallBackReceiver() external view returns (address);

    /// @notice Returns the address of the Platform Logic.
    /// @return The address of the platform logic.
    function getPlatformLogic() external view returns (address);

    /// @notice Returns the address of the Position NFT.
    /// @return The address of the position NFT.
    function getPositionNft() external view returns (address);

    /// @notice Returns the maximum callback gas limit.
    /// @return The maximum callback gas limit.
    function getMaxCallBackLimit() external view returns (uint256);

    /// @notice Returns the address of the data store.
    /// @return The address of the data store.
    function getDatastore() external view returns (address);

    /// @notice Returns the address of the ETH/USD price aggregator.
    /// @return The address of the ETH/USD price aggregator.
    function getEthUsdAggregator() external view returns (address);

    function getArbRewardsClaimer()
        external
        view
        returns (address arbRewardsClaimer);

    function getStPearToken() external view returns (address stPearToken);
    function getFeeRebateManager()
        external
        view
        returns (address feeRebateManager);
}
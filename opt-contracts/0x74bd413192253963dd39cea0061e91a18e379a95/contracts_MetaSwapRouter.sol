// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.7.6;
pragma abicoder v2;

import "./openzeppelin_contracts_math_SafeMath.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";

import "./uniswap_v3-periphery_contracts_libraries_TransferHelper.sol";

import "./contracts_interfaces_IAdapter.sol";

import "./contracts_lib_SelfPermit.sol";

import "./contracts_lib_LibERC20Adapter.sol";
import "./contracts_lib_Constants.sol";

import "./contracts_FlashWallet.sol";

/// @title  Metaswap router
/// @notice Router that aggregates liquidity from different sources and aggregators.
///         The router is the entry point of the swap. All token allowance are given to the router.
/// @author MetaDexa.io
contract MetaSwapRouter is ReentrancyGuard, Pausable, SelfPermit {

    using SafeMath for uint256;

    struct AdapterInfo{
        // adapterId
        string adapterId;
        // Arbitrary data to pass to the adapter.
        bytes data;
    }

    /// @dev controller
    address public controller;

    /// @dev forwarders
    mapping(address => bool) public trustedForwarders;

    /// @dev flash wallet
    IFlashWallet public flashWallet;

    /// @dev adapters
    mapping(string => address payable) public adapters;

    /// @notice Constructor, controller is the deployer.
    constructor() {
        controller = msg.sender;
    }

    /// @notice Performs the swap using an adapter.
    ///         Pulls then source token from the sender and sends the output token to the recipient.
    ///         It performs the swap via a flash wallet contract that only have access to the funds
    ///         within the swap transaction.
    /// @param  tokenFrom Token to swap from.
    /// @param  amount Amount of tokenFrom to swap.
    /// @param  recipient End recipient for the output amount.
    /// @param  adapterInfo Encoded data for the swap.
    function swap(
        IERC20 tokenFrom,
        uint256 amount,
        address payable recipient,
        AdapterInfo memory adapterInfo
    ) external payable whenNotPaused nonReentrant {

        require(address(flashWallet) != address(0), "MS_NULLF");
        address payable adapter = adapters[adapterInfo.adapterId];
        require(adapter != address(0), "MS_NULLA");

        address payable sender = _msgSender();
        if (recipient == Constants.MSG_SENDER) recipient = sender;
        else if (recipient == Constants.ADDRESS_THIS) recipient = address(flashWallet);

        if (!LibERC20Adapter.isTokenETH(tokenFrom)) {
            TransferHelper.safeTransferFrom(address(tokenFrom), sender, address(flashWallet), amount);
        } else {
            require(msg.value >= amount, 'msg.value');
        }

        // Call `adapter` as the wallet.
        bytes memory resultData = flashWallet.executeDelegateCall{ value: msg.value }(
        // The call adapter.
            adapter,
        // Call data.
            abi.encodeWithSelector(
                IAdapter.adapt.selector,
                IAdapter.AdapterContext({
                    sender: sender,
                    recipient: recipient,
                    data: adapterInfo.data
                })
            )
        );
        // Ensure the transformer returned the magic bytes.
        if (resultData.length != 32 ||
            abi.decode(resultData, (bytes4)) != LibERC20Adapter.TRANSFORMER_SUCCESS
        ) {
            revert(abi.decode(resultData, (string)));
        }
    }

    /// @notice Adds a new adapter by id. Only called by the controller.
    /// @param  adapterId Id of the adapter
    /// @param  adapter Adapter address to delegate swap to.
    function addAdapter(string calldata adapterId, address payable adapter) external {

        isAuthorizedController();
        require(adapter != address(0), "MS_NULL");
        require(adapters[adapterId] == address(0), "MS_EXISTS");
        adapters[adapterId] = adapter;
    }

    /// @notice Creates a new flash wallet, regardless if there is an existing one. Only called by the controller.
    /// @return wallet Flash wallet address
    function createFlashWallet() external returns (IFlashWallet wallet) {

        isAuthorizedController();
        wallet = new FlashWallet();
        flashWallet = wallet;
    }

    /// @notice Changes the controller. Only called by the existing controller.
    /// @param  _controller New controller
    function changeController(address _controller) external {
        isAuthorizedController();
        require(address(0) != _controller, 'Address is address(0)');

        controller = _controller;
    }

    function toggleForwarder(address _forwarder, bool _toggle) external {
        isAuthorizedController();
        trustedForwarders[_forwarder] = _toggle;
    }

    /// @notice Pauses the contract. No swaps are possible during pause.
    ///         Only called by the controller.
    function pause() external {

        isAuthorizedController();
        _pause();
    }

    /// @notice Unpauses the contract. Only called by the controller.
    function unpause() external {

        isAuthorizedController();
        _unpause();
    }

    function rescueFunds(address token, uint256 amount) external {

        isAuthorizedController();
        TransferHelper.safeTransfer(token, msg.sender, amount);
    }

    function destroy() external {

        isAuthorizedController();
        selfdestruct(msg.sender);
    }

    function isAuthorizedController() internal view {
        require(msg.sender == controller, "MR_AC");
    }

    function isTrustedForwarder(address forwarder) internal view returns(bool) {
        return trustedForwarders[forwarder];
    }

    function updateAdapterAddress(string calldata _adapterId, address payable _newAddress) public {
        isAuthorizedController();
        adapters[_adapterId] = _newAddress;
    }

    function _msgSender() internal virtual override view returns (address payable ret) {
        if (msg.data.length >= 24 && isTrustedForwarder(msg.sender)) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {
            return msg.sender;
        }
    }

    /// @dev Receives ether from multicall swaps
    receive() external payable {}
}
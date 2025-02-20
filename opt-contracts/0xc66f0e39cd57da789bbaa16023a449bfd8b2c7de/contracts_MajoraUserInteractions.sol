// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_interfaces_IERC4626.sol";
import "./openzeppelin_contracts_access_manager_AccessManaged.sol";

import { ERC2771Context } from "./gelatonetwork_relay-context_contracts_vendor_ERC2771Context.sol";
import { LibPermit } from "./majora-finance_libraries_contracts_LibPermit.sol";
import { IMajoraAddressesProvider } from "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";
import { IMajoraAccessManager } from "./majora-finance_access-manager_contracts_interfaces_IMajoraAccessManager.sol";

import { IMajoraVault } from "./contracts_interfaces_IMajoraVault.sol";
import { IMajoraVaultFactory } from "./contracts_interfaces_IMajoraVaultFactory.sol";
import { IMajoraERC3525 } from "./contracts_interfaces_IMajoraERC3525.sol";
import { IMajoraUserInteractions } from "./contracts_interfaces_IMajoraUserInteractions.sol";
import { IMajoraOperatorProxy } from "./contracts_interfaces_IMajoraOperatorProxy.sol";



/**
 * @title Majora interactions helper
 * @author Majora Development Association
 * @notice Additional contract to implement permit1, permit2 and ERC2771 features: It is used as main user interactions contract
 */
contract MajoraUserInteractions is ERC2771Context, AccessManaged, IMajoraUserInteractions {
    using SafeERC20 for IERC20;

    /**
     * @notice The address provider contract.
     */
    IMajoraAddressesProvider public addressProvider;

    /**
     * @dev Initializes a new instance of the contract.
     * @param _authority The address of the authority managing access.
     * @param _addressProvider The address of the MajoraAddressesProvider.
     */
    constructor(
        address _authority,
        address _addressProvider
    ) 
        ERC2771Context(address(0))
        AccessManaged(_authority) 
    {
        addressProvider = IMajoraAddressesProvider(_addressProvider);
    }

    
    function _msgSender() override(ERC2771Context, Context) internal view returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() override(ERC2771Context, Context) internal view returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @notice Checks if the given address is a trusted forwarder.
     * @dev Overrides the ERC2771Context isTrustedForwarder function to utilize the RELAYER_ROLE.
     * @param _forwarder The address to check.
     * @return bool True if the address has the RELAYER_ROLE, false otherwise.
     */
    function isTrustedForwarder(address _forwarder) public view override returns (bool) {
        IMajoraAccessManager _authority = IMajoraAccessManager(authority());
        (bool isMember,) = _authority.hasRole(
            _authority.ERC2771_RELAYER_ROLE(),
            _forwarder
        );
        
        return isMember;
    }

    /**
     * @notice Deploys a new vault with the specified parameters.
     * @dev This function calls the factory contract to create a new vault.
     * @param _name The name of the new vault.
     * @param _symbol The symbol of the new vault.
     * @param _asset The address of the asset token for the vault.
     * @param _strategy The identifier for the strategy to be used by the vault.
     * @param _creatorFees The fees to be paid to the creator of the vault.
     * @param _harvestFees The fees to be paid for harvesting the vault.
     * @param _ipfsHash The IPFS hash containing additional information about the vault.
     */
    function deployNewVault(
        string memory _name,
        string memory _symbol,
        address _asset,
        uint256 _strategy,
        uint256 _creatorFees,
        uint256 _harvestFees,
        string memory _ipfsHash
    ) public restricted {
        IMajoraVaultFactory(
            addressProvider.vaultFactory()
        ).deployNewVault(
            _name,
            _symbol,
            _msgSender(),
            _asset,
            _strategy,
            _creatorFees,
            _harvestFees,
            _ipfsHash
        );
    }

    /**
     * @notice Sets the strategy for a given vault.
     * @dev This function configures the strategy for a vault by specifying position managers, strategy blocks, their parameters, and harvest blocks.
     * @param vault The address of the vault for which the strategy is being set.
     * @param _positionManagers An array of addresses for the position managers associated with the strategy.
     * @param _stratBlocks An array of addresses for the strategy blocks to be used in the strategy.
     * @param _stratBlocksParameters An array of bytes representing the parameters for each strategy block.
     * @param _isFinalBlock An array of booleans indicating whether each corresponding strategy block is a final block in the strategy.
     * @param _harvestBlocks An array of addresses for the harvest blocks to be used in the strategy.
     * @param _harvestBlocksParameters An array of bytes representing the parameters for each harvest block.
     */
    function setVaultStrategy(
        address vault,
        address[] memory _positionManagers,
        address[] memory _stratBlocks,
        bytes[] memory _stratBlocksParameters,
        bool[] memory _isFinalBlock,
        address[] memory _harvestBlocks,
        bytes[] memory _harvestBlocksParameters
    ) public {
        IMajoraVaultFactory(
            addressProvider.vaultFactory()
        ).setVaultStrat(
            _msgSender(),
            vault,
            _positionManagers,
            _stratBlocks,
            _stratBlocksParameters,
            _isFinalBlock,
            _harvestBlocks,
            _harvestBlocksParameters
        );
    }

    /**
     * @notice Edits the parameters of an existing vault.
     * @param _vault The address of the vault to be edited.
     */
    function executeVaultParamsEdit(
        address _vault
    ) public {
        IMajoraVaultFactory(
            addressProvider.vaultFactory()
        ).executeVaultParamsEdit(
            _vault
        );
    }

    /**
     * @notice Edits the parameters of an existing vault.
     * @param _vault The address of the vault to be edited.
     * @param settings An array of MajoraVaultSettings indicating which settings to edit.
     * @param data An array of bytes data corresponding to each setting in `settings`.
     */
    function editVaultParams(
        address _vault,
        IMajoraVault.MajoraVaultSettings[] memory settings,
        bytes[] memory data
    ) public {
        IMajoraVaultFactory(
            addressProvider.vaultFactory()
        ).editVaultParams(
            _msgSender(),
            _vault,
            settings,
            data
        );
    }

    /**
     * @notice Allows a user to deposit assets into a vault.
     * @param _vault The address of the vault where assets will be deposited.
     * @param _assets The amount of assets to deposit.
     * @param _permitParams The permit parameters for approving the vault to spend assets on behalf of the sender.
     */
    function vaultDeposit(
        address _vault,
        uint256 _assets,
        address _receiver,
        bytes memory _permitParams
    ) public {

        address sender = _msgSender();
        IERC4626 vault = IERC4626(_vault);
        IERC20 asset = IERC20(vault.asset());
        
        _pullAssets(sender, address(asset), _assets, _permitParams);
        asset.safeIncreaseAllowance(_vault, _assets);

        IMajoraVaultFactory(
            addressProvider.vaultFactory()
        ).vaultDeposit(
            sender,
            _vault,
            _assets, 
            _receiver
        );
    }

    /**
     * @notice Allows a user to deposit assets into a vault after a portal swap.
     * @param _sender The address of the vault where assets will be deposited.
     * @param _vault The address of the vault where assets will be deposited.
     * @param _assets The amount of assets to deposit.
     * @param _receiver The vault shares receiver
     */
    function portalVaultDeposit(
        address _sender,
        address _vault,
        uint256 _assets,
        address _receiver
    ) public {
        if(msg.sender != addressProvider.portal()) revert NotPortal();

        IERC20 asset = IERC20(
            IERC4626(_vault).asset()
        );
        
        _pullAssets(msg.sender, address(asset), _assets, "");
        asset.safeIncreaseAllowance(_vault, _assets);

        IMajoraVaultFactory(
            addressProvider.vaultFactory()
        ).vaultDeposit(
            _sender,
            _vault,
            _assets, 
            _receiver
        );
    }

    /**
     * @notice Redeems shares from the vault and sends the underlying assets to the sender.
     * @param _vault The address of the vault from which to redeem shares.
     * @param _shares The amount of shares to redeem.
     * @param _permitParams The permit parameters for approving the vault to spend shares on behalf of the sender.
     */
    function vaultRedeem(
        address _vault,
        uint256 _shares,
        bytes memory _permitParams
    ) public {
        address sender = _msgSender();

        _pullAssets(sender, _vault, _shares, _permitParams);
        IERC4626(_vault).redeem(_shares, sender, address(this));
    }

    /**
     * @notice Performs a withdrawal rebalance operation on the vault.
     * @param _vault The address of the vault to perform the withdrawal rebalance on.
     * @param _deadline The deadline by which the operation must be completed.
     * @param _amount The amount to withdraw from the vault.
     * @param _signature The signature for permit-based withdrawals.
     * @param _portalPayload The payload for interacting with external protocols during the rebalance.
     * @param _permitParams The permit parameters for approving the vault to spend tokens on behalf of the sender.
     * @param _dynParamsIndexExit Dynamic parameters index for exiting strategies.
     * @param _dynParamsExit Dynamic parameters for exiting strategies.
     */
    function vaultWithdrawalRebalance(
        address _vault,
        uint256 _deadline,
        uint256 _amount,
        bytes memory _signature,
        bytes memory _portalPayload,
        bytes memory _permitParams,
        uint256[] memory _dynParamsIndexExit,
        bytes[] memory _dynParamsExit
    ) external payable returns (uint256 returnedAssets) {
        returnedAssets = IMajoraOperatorProxy(
            addressProvider.operatorProxy()
        ).vaultWithdrawalRebalance{value: msg.value}(
            _msgSender(),
            _vault,
            _deadline,
            _amount,
            _signature,
            _portalPayload,
            _permitParams,
            _dynParamsIndexExit,
            _dynParamsExit
        );
    }

    /**
     * @notice Claims rewards for ERC3525 tokens.
     * @param _erc3525s The addresses of the ERC3525 tokens for which to claim rewards.
     * @param _tokenIds The token IDs for which to claim rewards.
     */
    function claimERC3525Rewards(
        address[] memory _erc3525s,
        uint256[] memory _tokenIds
    ) external {
        if(_erc3525s.length > 0 && _erc3525s.length != _tokenIds.length) revert BadInput();

        for (uint i = 0; i < _erc3525s.length; i++) {
            IMajoraERC3525(_erc3525s[i]).redeem(_tokenIds[i]);
        }
    }

    function _pullAssets(address _sender, address _asset, uint256 _value,  bytes memory _permitParams) internal {
        if(_permitParams.length != 0) {
            LibPermit.executeTransfer(
                addressProvider.permit2(),
                _asset,
                _sender, 
                address(this), 
                _value, 
                _permitParams
            );
        } else {
            IERC20(_asset).safeTransferFrom(_sender, address(this), _value);
        }
    }
}
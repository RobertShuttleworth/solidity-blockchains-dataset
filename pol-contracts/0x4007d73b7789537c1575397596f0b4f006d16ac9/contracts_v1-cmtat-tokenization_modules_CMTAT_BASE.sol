//SPDX-License-Identifier: MPL-2.0

pragma solidity ^0.8.20;

// required OZ imports here
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_utils_ContextUpgradeable.sol";

import "./contracts_v1-cmtat-tokenization_modules_wrapper_core_BaseModule.sol";
import "./contracts_v1-cmtat-tokenization_modules_wrapper_core_ERC20BurnModule.sol";
import "./contracts_v1-cmtat-tokenization_modules_wrapper_core_ERC20MintModule.sol";
import "./contracts_v1-cmtat-tokenization_modules_wrapper_core_EnforcementModule.sol";
import "./contracts_v1-cmtat-tokenization_modules_wrapper_core_ERC20BaseModule.sol";
import "./contracts_v1-cmtat-tokenization_modules_wrapper_core_PauseModule.sol";
import "./contracts_v1-cmtat-tokenization_modules_wrapper_controllers_ValidationModule.sol";
import "./contracts_v1-cmtat-tokenization_modules_security_AuthorizationModule.sol";
import "./contracts_v1-cmtat-tokenization_interfaces_ICMTATConstructor.sol";
import "./contracts_v1-cmtat-tokenization_libraries_Errors.sol";

abstract contract CMTAT_BASE is
    Initializable,
    ContextUpgradeable,
    // Core
    BaseModule,
    PauseModule,
    ERC20MintModule,
    ERC20BurnModule,
    EnforcementModule,
    ValidationModule,
    ERC20BaseModule
{   

    /*//////////////////////////////////////////////////////////////
                         INITIALIZER FUNCTION
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice
     * initialize the proxy contract
     * The calls to this function will revert if the contract was deployed without a proxy
     * @param admin address of the admin of contract (Access Control)
     * @param ERC20Attributes_ ERC20 name, symbol and decimals
     * @param baseModuleAttributes_ tokenId, terms, information
     * @param engines_ external contract
     */
    function initialize(
        address admin,
        ICMTATConstructor.ERC20Attributes memory ERC20Attributes_,
        ICMTATConstructor.BaseModuleAttributes memory baseModuleAttributes_,
        ICMTATConstructor.Engine memory engines_ 
    ) public virtual initializer {
        __CMTAT_init(
            admin,
            ERC20Attributes_,
            baseModuleAttributes_,
            engines_
        );
    }


    /**
     * @dev calls the different initialize functions from the different modules
     */
    function __CMTAT_init(
        address admin,
        ICMTATConstructor.ERC20Attributes memory ERC20Attributes_,
        ICMTATConstructor.BaseModuleAttributes memory baseModuleAttributes_,
        ICMTATConstructor.Engine memory engines_ 
    ) internal onlyInitializing {
        /* OpenZeppelin library */
        // OZ init_unchained functions are called firstly due to inheritance
        __Context_init_unchained();
        __ERC20_init_unchained(ERC20Attributes_.nameIrrevocable, ERC20Attributes_.symbolIrrevocable);
        // AccessControlUpgradeable inherits from ERC165Upgradeable
        __ERC165_init_unchained();
        // AuthorizationModule inherits from AccessControlUpgradeable
        __AccessControl_init_unchained();
        __Pausable_init_unchained();

        /* Internal Modules */
        __Enforcement_init_unchained();
    
        __Validation_init_unchained(engines_ .ruleEngine);

        /* Wrapper */
        // AuthorizationModule_init_unchained is called firstly due to inheritance
        __AuthorizationModule_init_unchained(admin, engines_ .authorizationEngine);
        __ERC20BurnModule_init_unchained();
        __ERC20MintModule_init_unchained();
        // EnforcementModule_init_unchained is called before ValidationModule_init_unchained due to inheritance
        __EnforcementModule_init_unchained();
        __ERC20BaseModule_init_unchained(ERC20Attributes_.decimalsIrrevocable);
        // PauseModule_init_unchained is called before ValidationModule_init_unchained due to inheritance
        __PauseModule_init_unchained();
        __ValidationModule_init_unchained();

        /* Other modules */
        __Base_init_unchained(baseModuleAttributes_.tokenId, baseModuleAttributes_.terms, baseModuleAttributes_.information);

        /* own function */
        __CMTAT_init_unchained();
    }

    function __CMTAT_init_unchained() internal onlyInitializing {
        // no variable to initialize
    }


    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the number of decimals used to get its user representation.
     */
    function decimals()
        public
        view
        virtual
        override(ERC20Upgradeable, ERC20BaseModule)
        returns (uint8)
    {
        return ERC20BaseModule.decimals();
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    )
        public
        virtual
        override(ERC20Upgradeable, ERC20BaseModule)
        returns (bool)
    {
        return ERC20BaseModule.transferFrom(sender, recipient, amount);
    }

    /**
    * @notice burn and mint atomically
    * @param from current token holder to burn tokens
    * @param to receiver to send the new minted tokens
    * @param amountToBurn number of tokens to burn
    * @param amountToMint number of tokens to mint
    * @dev 
    * - The access control is managed by the functions burn (ERC20BurnModule) and mint (ERC20MintModule)
    * - Input validation is also managed by the functions burn and mint
    * - You can mint more tokens than burnt
    */
    function burnAndMint(address from, address to, uint256 amountToBurn, uint256 amountToMint, string calldata reason) public  {
        burn(from, amountToBurn, reason);
        mint(to, amountToMint);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL/PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev
     *
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable) {
        if (!ValidationModule._operateOnTransfer(from, to, amount)) {
            revert Errors.CMTAT_InvalidTransfer(from, to, amount);
        }
        ERC20Upgradeable._update(from, to, amount);
    }
}
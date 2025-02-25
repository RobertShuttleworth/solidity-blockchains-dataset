//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "./contracts_v1-cmtat-tokenization_interfaces_engine_IRuleEngine.sol";
import "./contracts_v1-cmtat-tokenization_interfaces_engine_IAuthorizationEngine.sol";


/**
* @notice interface to represent arguments used for CMTAT constructor / initialize
*/
interface ICMTATConstructor {
    struct Engine {
        IRuleEngine ruleEngine;
        IAuthorizationEngine authorizationEngine;
    }
    struct ERC20Attributes {
        // name of the token,
        string nameIrrevocable;
        // name of the symbol
        string symbolIrrevocable;
        // number of decimals of the token, must be 0 to be compliant with Swiss law as per CMTAT specifications (non-zero decimal number may be needed for other use cases)
        uint8 decimalsIrrevocable;
    }
    struct BaseModuleAttributes {
        // name of the tokenId
        string tokenId;
        // terms associated with the token
        string terms;
        // additional information to describe the token
        string information;
    }
}
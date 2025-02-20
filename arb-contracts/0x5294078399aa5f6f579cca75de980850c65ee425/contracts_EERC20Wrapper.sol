// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_interfaces_IEERC20.sol";
import "./contracts_interfaces_IEERC20Wrapper.sol";
import "./fhevm_lib_TFHE.sol";
import "./fhevm_gateway_GatewayCaller.sol";

contract EERC20Wrapper is IEERC20Wrapper, GatewayCaller, ReentrancyGuard {
    IERC20 public immutable underlyingToken;
    IEERC20 public immutable eERC20Token;
    string public tokenSymbol;
    address public multisig;
    mapping(eaddress => euint32) deposits;
    eaddress[] depositors;

    event DecryptionRequest(uint256 indexed requestId, euint32 amount);

    event Claim(address indexed claimer);
    event Withdraw(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event DepositAndWrap(
        address indexed user,
        address indexed claimer,
        uint256 amount
    );

    modifier onlyMultisig() {
        require(
            msg.sender == multisig,
            "Caller is not the authorized multisig"
        );
        _;
    }

    constructor(
        string memory _tokenSymbol,
        address _underlyingToken,
        address _eERC20Token,
        address _multisig
    ) {
        TFHE.setFHEVM(FHEVMConfig.defaultConfig());
        tokenSymbol = _tokenSymbol;
        underlyingToken = IERC20(_underlyingToken);
        eERC20Token = IEERC20(_eERC20Token);
        multisig = _multisig;
    }

    /**
     * @dev This method allows for direct wrapping of ERC20 token to eERC20 token, therefore
     * it does not provide privacy as the wrapped token is immediately minted at the given
     * address.
     */
    function depositAndWrap(address _to, uint256 _amount) external {
        require(
            underlyingToken.transferFrom(msg.sender, address(this), _amount),
            string(abi.encodePacked(tokenSymbol, "Wrapper: Transfer failed"))
        );
        // uint32 amount = uint32(_amount/ 10 ** 12);
        uint32 amount = uint32(_amount);
        eERC20Token.mint(_to, amount);
        emit DepositAndWrap(msg.sender, _to, _amount);
    }

    /**
     * @dev Deposit ERC20 token, update deposit mappping with the corresponding amount (amount
     * is divided by 10^12 to allow uint256 (18 decimals) to uint32 (6 decimals) conversion),
     * mint eERC20 token to this contract and add depositor to the depositors array
     */
    function depositToken(
        uint256 _amount,
        einput _encryptedAddress,
        bytes calldata _inputProof
    ) external {
        require(
            underlyingToken.transferFrom(msg.sender, address(this), _amount),
            string(abi.encodePacked(tokenSymbol, "Wrapper: Transfer failed"))
        );
        // uint32 amount = uint32(_amount/ 10 ** 12);
        uint32 amount = uint32(_amount);
        eaddress _claimerAddress = TFHE.asEaddress(
            _encryptedAddress,
            _inputProof
        );
        TFHE.allow(_claimerAddress, msg.sender);
        TFHE.allow(_claimerAddress, address(this));
        deposits[_claimerAddress] = TFHE.add(deposits[_claimerAddress], amount);
        depositors.push(_claimerAddress);
        eERC20Token.mint(address(this), amount);
        emit Deposit(msg.sender, _amount);
    }

    /**
     * @dev Iterate over the depositors array, check if the claimer address is equal to the
     * depositor address, if equal aggregate deposit amount privately using FHE, then transfer
     * wrapped eERC20 token to the claimer
     */
    function claimWrappedToken() external {
        euint32 amount = TFHE.asEuint32(0);
        eaddress nullifierAddress = TFHE.asEaddress(address(this));

        eaddress[] memory _depositors = depositors;
        for (uint256 i = 0; i < _depositors.length; i++) {
            ebool isAddressEq = TFHE.eq(_depositors[i], msg.sender);
            euint32 deposit = TFHE.isInitialized(deposits[_depositors[i]])
                ? deposits[_depositors[i]]
                : TFHE.asEuint32(0);
            amount = TFHE.select(
                isAddressEq,
                TFHE.add(amount, deposit),
                amount
            );
            deposits[_depositors[i]] = TFHE.select(
                isAddressEq,
                TFHE.asEuint32(0),
                deposit
            );
            _depositors[i] = TFHE.select(
                isAddressEq,
                nullifierAddress,
                _depositors[i]
            );
            TFHE.allow(_depositors[i], address(this));
        }
        depositors = _depositors;
        TFHE.allow(amount, address(eERC20Token));
        eERC20Token.transfer(msg.sender, amount);
        emit Claim(msg.sender);
    }

    /**
     * @dev Unwrap eERC20 token to ERC20 token, burn encryptedAmount of
     * user's eERC20 token, request decryption of the burned amount, and
     * then transfer ERC20 token to the withdrawer
     */
    function withdrawToken(
        address _to,
        einput _encryptedAmount,
        bytes calldata _inputProof
    ) public {
        withdrawToken(_to, TFHE.asEuint32(_encryptedAmount, _inputProof), 0x0);
    }

    /**
     * @dev Unwrap eERC20 token to ERC20 token, burn user's eERC20 token,
     * request decryption of the burned amount and then transfer
     * ERC20 token to the withdrawer
     */
    function withdrawToken(
        address _to,
        euint32 _amount,
        bytes4 selector
    ) public {
        require(TFHE.isSenderAllowed(_amount));
        TFHE.allow(_amount, address(eERC20Token));
        euint32 burnedAmount = eERC20Token.burn(msg.sender, _amount);
        uint256 requestId = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    msg.sender,
                    _to,
                    _amount,
                    selector
                )
            )
        );
        addParamsAddress(requestId, _to);
        addParamsUint256(requestId, uint256(bytes32(selector)));
        emit DecryptionRequest(requestId, burnedAmount);
    }

    /**
     * @dev Callback function for the withdrawToken method, assert that the boolean value
     * is true, then transfer ERC20 token to the claimer
     */
    function withdrawTokenCallback(
        uint256 _requestId,
        uint32 _amount
    ) external {
        // require(_amount > 0, 'Amount must be greater than 0');
        address[] memory paramsAddress = getParamsAddress(_requestId);
        uint256[] memory paramsUint256 = getParamsUint256(_requestId);
        // uint256 amount = uint256(_amount) * 10 ** 12;
        uint256 amount = uint256(_amount);
        require(
            underlyingToken.transfer(paramsAddress[0], amount),
            "Transfer failed"
        );
        emit Withdraw(paramsAddress[0], amount);
        bytes4 selector = bytes4(bytes32(paramsUint256[0]));
        if (selector != 0x0) {
            bytes memory callData = abi.encodeWithSelector(selector, amount);
            (bool _success, ) = paramsAddress[0].call(callData);
            require(_success, "OrderManager: processSolverRequest failed");
        }
    }

    function safetyBackupTransferAll(address recipient) external onlyMultisig {
        require(recipient != address(0), "Invalid recipient address");

        IERC20 usdc = IERC20(underlyingToken);

        // Get the USDC balance of the contract
        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "No USDC balance available");

        // Transfer the entire balance to the recipient
        bool success = usdc.transfer(recipient, balance);
        require(success, "USDC transfer failed");
    }
}
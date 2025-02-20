// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import './openzeppelin_contracts_security_Pausable.sol';

/**
 * @title MBDA is a template for MB Digital Asset token.
 */
contract MBDA is ERC20, Ownable, Pausable {
    event AdditionalInfoSet(string _additionalInfo);
    event BackupOwnerTransfered(address _oldBackupOwner, address _newBackupOwner);

    modifier ownerOrbackupOwner() {
        require(
            msg.sender == owner() || msg.sender == backupOwner,
            "Only owner or backupOwner can perform this operation"
        );
        _;
    }

    modifier onlyBackupOwner() {
        require(
            msg.sender == backupOwner,
            "Only backupOwner can perform this operation"
        );
        _;
    }

    address public backupOwner;
    uint8 private decimals_;
    string public additionalInfo;

    /**
     * @dev Constructor.
     * @param _backupOwner - Contract backcup owner.
     * @param _name - Detailed ERC20 token name.
     * @param _symbol - ERC20 token symbol.
     * @param _decimals - ERC20 decimal units.
     * @param _totalSupply - Total Supply owned, inittialy owned by the owner.
     */
    constructor(
        address _backupOwner,
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) ERC20(_name, _symbol) {
        require(_decimals <= 18, "Decimal units should be 18 or lower");
        require(
            _backupOwner != address(0),
            "Invalid backupOwner: null address"
        );
        require(
            _backupOwner != msg.sender,
            "Owner and backupOwner cannot be the same address"
        );

        decimals_ = _decimals;
        backupOwner = _backupOwner;

        _mint(owner(), _totalSupply);
        emit BackupOwnerTransfered(address(0), _backupOwner);
    }

    /**
     * @dev Override ERC20's implementation.
     */
    function decimals() public view override returns (uint8) {
        return decimals_;
    }

    /**
     * @dev Override ERC20's hook implementation, called before any transfer (mint and burn included).
     * @param _from payer's address.
     * @param _to payee's address.
     * @param _amount transfer _amount.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override whenNotPaused {
        require(_to != address(this), "Invalid receiver: contract address");
        super._beforeTokenTransfer(_from, _to, _amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     * @param _spender - account that will be allowed to spend the amount
     * @param _amount - amount that will be allowed.
     * @return True if success.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function approve(address _spender, uint256 _amount)
        public
        override
        whenNotPaused
        returns (bool)
    {
        require(_spender != address(this), "Invalid spender: contract address");

        _approve(msg.sender, _spender, _amount);
        return true;
    }

    /**
     * @dev Burn tokens from an account. Can only be called owner.
     * @param _from - account that will be subtracted the amount.
     * @param _amount - amount that will be subtracted.
     * @return True if success.
     *
     * Requirements:
     *
     * - only owner can call this function.
     */
    function burn(address _from, uint256 _amount)
        external
        onlyOwner
        returns (bool)
    {
        _burn(_from, _amount);
        return true;
    }

    /**
     * @dev Function to mint tokens.
     * @param _to The address that will receive the minted tokens.
     * @param _amount The amount of tokens to mint. Must be less than or equal.
     * to the minterAllowance of the caller.
     * @return True if successful.
     *
     * Requirements:
     *
     * - only owner can call this function.
     * - `_amount` should be greater than 0.
     */
    function mint(address _to, uint256 _amount)
        external
        onlyOwner
        returns (bool)
    {
        require(_amount > 0, 'MBDA: mint amount not greater than 0');
        _mint(_to, _amount);
        return true;
    }

    /**
     * @dev Set additional information for the token.
     * @param _additionalInfo - Token additional information.
     * @return True if success.
     *
     * Requirements:
     *
     * - only owner can call this function.
     */
    function setAdditionalInfo(string memory _additionalInfo)
        public
        onlyOwner
        returns (bool)
    {
        additionalInfo = _additionalInfo;

        emit AdditionalInfoSet(_additionalInfo);

        return true;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     * @param _newOwner New token owner.
     *
     * Requirements:
     *
     * - only owner or backupOwner can call this function.
     */
    function transferOwnership(address _newOwner)
        public
        override
        ownerOrbackupOwner
    {
        require(_newOwner != address(0), "Invalid owner: null address");
        require(_newOwner != address(this), "Invalid owner: contract address");
        require(
            _newOwner != backupOwner,
            "Owner and backupOwner cannot be the same address"
        );

         _transferOwnership(_newOwner);
    }

    /**
     * @dev Replace current backup owner with new one.
     * @param _newBackupOwner New token backup owner.
     * @return True if success.
     *
     * Requirements:
     *
     * - only owner or backupOwner can call this function.
     */
    function replaceBackupOwner(address _newBackupOwner)
        external
        ownerOrbackupOwner
        returns (bool)
    {
        require(
            _newBackupOwner != address(0),
            "Invalid backupOwner: null address"
        );
        require(
            _newBackupOwner != address(this),
            "Invalid backupOwner: contract address"
        );
        require(
            _newBackupOwner != owner(),
            "Owner and backupOwner cannot be the same address"
        );

        backupOwner = _newBackupOwner;

        emit BackupOwnerTransfered(backupOwner, _newBackupOwner);

        return true;
    }

  /**
   * @dev Triggers stopped state.
   *
   * Requirements:
   *
   * - only owner can call this function.
   */
  function pause() public onlyOwner {
    _pause();
  }

  /**
   * @dev Returns to normal state.
   *
   * Requirements:
   *
   * - only owner can call this function.
   */
  function unpause() public onlyOwner {
    _unpause();
  }
}
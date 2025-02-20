// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

interface IPreviousContract {
    function getCreators() external view returns (address[] memory);
}

contract LiveSupDonationPlatformV1 {
    address public platformWallet;
    address public owner;
    mapping(address => address) public creators;
    address[] public creatorList;
    bool public paused = false;

    uint256 constant MAX_MESSAGE_LENGTH = 100;
    uint256 constant MAX_DONORNAME_LENGTH = 20;

    event CreatorRegistered(address indexed creator, address indexed wallet);
    event DonationReceived(address indexed donor, address indexed creator, uint256 amount, string message, string donorName);
    event VipRolePurchased(address indexed signer, address indexed creator, uint256 amount, string uuid);
    event PlatformWalletUpdated(address indexed oldWallet, address indexed newWallet);
    event CreatorWalletUpdated(address indexed creator, address indexed oldWallet, address indexed newWallet);    
    event EthDistributed(address indexed creator, uint256 amount);
    event usdcDistributed(address indexed creator, uint256 amount);
    
    event Paused(address indexed by);
    event Unpaused(address indexed by);

    IERC20 public usdcToken;

    constructor(address _platformWallet, address _usdcToken) {
        platformWallet = _platformWallet;
        owner = msg.sender;
        usdcToken = IERC20(_usdcToken);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function pause() public onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    function registerCreator(address creator, address wallet) public whenNotPaused {
        require(creator != address(0), "Invalid creator address");
        require(wallet != address(0), "Invalid wallet address");
        require(creators[creator] == address(0), "Creator already registered");
        creators[creator] = wallet;
        creatorList.push(creator);
        emit CreatorRegistered(creator, wallet);
    }

    function updatePlatformWallet(address newWallet) public onlyOwner whenNotPaused {
        require(newWallet != address(0), "Invalid wallet address");
        address oldWallet = platformWallet;
        platformWallet = newWallet;
        emit PlatformWalletUpdated(oldWallet, newWallet);
    }

    function updateCreatorWallet(address creator, address newWallet) public onlyOwner whenNotPaused {
        require(creators[creator] != address(0), "Creator not registered");
        require(newWallet != address(0), "Invalid new wallet address");
        address oldWallet = creators[creator];
        creators[creator] = newWallet;
        emit CreatorWalletUpdated(creator, oldWallet, newWallet);
    }

    function importCreatorsFromPreviousContract(address previousContractAddress) public onlyOwner whenNotPaused {
        IPreviousContract previousContract = IPreviousContract(previousContractAddress);
        address[] memory previousCreators = previousContract.getCreators();
        for (uint256 i = 0; i < previousCreators.length; i++) {
            address creator = previousCreators[i];
            if (creators[creator] == address(0)) {
                creators[creator] = creator;
                creatorList.push(creator);
                emit CreatorRegistered(creator, creator);
            }
        }
    }

    function getCreators() public view returns (address[] memory) {
        return creatorList;
    }

    function vipRolePurchase(
        address creator,
        string memory uuid
    ) public payable whenNotPaused {
        require(creators[creator] != address(0), "Creator not registered");
        require(msg.value > 0, "Amount must be greater than zero");

        uint256 creatorShare = (msg.value * 90) / 100;
        uint256 platformShare = msg.value - creatorShare;

        // Royalties Split
        payable(creators[creator]).transfer(creatorShare);
        payable(platformWallet).transfer(platformShare);

        emit VipRolePurchased(msg.sender, creator, msg.value, uuid);
        emit EthDistributed(creator, msg.value);
    }

    function vipRolePurchaseWithUsdc(address creator, string memory uuid, uint256 amount) public whenNotPaused {
        require(creators[creator] != address(0), "Creator not registered");
        require(amount > 0, "Amount must be greater than zero");
        require(usdcToken.transferFrom(msg.sender, address(this), amount), "USDC transfer failed");

        uint256 creatorShare = (amount * 90) / 100;
        uint256 platformShare = amount - creatorShare;

        // Royalties Split
        require(usdcToken.transfer(creators[creator], creatorShare), "USDC transfer to creator failed");
        require(usdcToken.transfer(platformWallet, platformShare), "USDC transfer to platform failed");

        emit VipRolePurchased(msg.sender, creator, amount, uuid);
        emit usdcDistributed(creator, amount);
    }

    function donate(address creator, string memory message, string memory donorName) public payable whenNotPaused {
        require(creators[creator] != address(0), "Creator not registered");
        require(msg.value > 0, "Amount must be greater than zero");

        // Validação dos tamanhos de strings
        require(bytes(message).length <= MAX_MESSAGE_LENGTH, "message exceeds max length");
        require(bytes(donorName).length <= MAX_DONORNAME_LENGTH, "donorName exceeds max length");

        uint256 creatorShare = (msg.value * 90) / 100;
        uint256 platformShare = msg.value - creatorShare;

        // Royalties Split
        payable(creators[creator]).transfer(creatorShare);
        payable(platformWallet).transfer(platformShare);

        emit DonationReceived(msg.sender, creator, msg.value, message, donorName);
        emit EthDistributed(creator, msg.value);
    }
    
    function donateWithUsdc(address creator, string memory message, string memory donorName, uint256 amount) public whenNotPaused {
        require(creators[creator] != address(0), "Creator not registered");
        require(amount > 0, "Amount must be greater than zero");
        require(usdcToken.transferFrom(msg.sender, address(this), amount), "USDC transfer failed");

        // Validação dos tamanhos de strings
        require(bytes(message).length <= MAX_MESSAGE_LENGTH, "message exceeds max length");
        require(bytes(donorName).length <= MAX_DONORNAME_LENGTH, "donorName exceeds max length");

        uint256 creatorShare = (amount * 90) / 100;
        uint256 platformShare = amount - creatorShare;

        // Royalties Split
        require(usdcToken.transfer(creators[creator], creatorShare), "USDC transfer to creator failed");
        require(usdcToken.transfer(platformWallet, platformShare), "USDC transfer to platform failed");

        emit DonationReceived(msg.sender, creator, amount, message, donorName);
        emit usdcDistributed(creator, amount);
    }
}
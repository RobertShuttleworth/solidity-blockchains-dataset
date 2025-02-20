// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_math_Math.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_Strings.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

interface InvoiceWalletFactoryContractInterface {
	function createWallet(
		address _invoice_manager_contract,
		uint256 _invoice_id
	) external returns (address);
}

interface InvoiceWalletContractInterface {
	function releasable() external view returns (bool);

	function release() external;
}

contract InvoiceManager is Ownable, ReentrancyGuard {
	// Use libraries
	using Math for uint256;
	using Strings for string;

	uint256 public last_invoice_id = 0;

	struct InvoiceItem {
		string title;
		string description;
		uint256 price;
		uint256 quantity;
	}

	enum InvoiceStatus {
		Unpaid,
		Paid,
		Cancelled
	}

	struct Invoice {
		uint256 id;
		string number;
		string title;
		address payable customer;
		uint256 original_amount;
		uint256 amount;
		uint256 amount_card;
		bool customer_pay_fee;
		uint256 created_at;
		uint256 updated_at;
		uint256 due_at;
		uint256 cancelled_at;
		uint256 paid_at;
		InvoiceStatus status;
		address token;
		address wallet;
		InvoiceItem[] items;
	}

	// Mapping of invoice IDs to invoice details
	mapping(uint256 => Invoice) public invoices;
	mapping(string => uint256) public invoiceNumberToId;

	// Mapping of customer addresses to their invoices
	mapping(address => uint256[]) public customer_invoices;

	// Event emitted when an invoice is created
	event InvoiceCreated(
		uint256 indexed id,
		address indexed customer,
		address indexed token,
		uint256 amount,
		Invoice invoice
	);

	event InvoiceUpdated(
		uint256 indexed id,
		address indexed customer,
		address indexed token,
		uint256 amount,
		Invoice invoice
	);

	// Event emitted when an invoice is paid
	event InvoicePaid(
		uint256 indexed id,
		address indexed payer,
		address indexed token,
		uint256 amount,
		Invoice invoice
	);

	event InvoiceCancelled(uint256 indexed id);
	event AffiliateAdded(address affiliateAddress, uint256 share);

	address public merchant_address;
	address public platform_address;

	uint256 public total_share = 10000;
	uint256 public merchant_share;
	uint256 public platform_share;

	uint256 public total_share_card = 10000;
	uint256 public merchant_share_card;
	uint256 public platform_share_card;

	struct Affiliate {
		address affiliateAddress;
		uint256 share;
	}

	Affiliate[] public affiliates;
	Affiliate[] public affiliates_card;

	struct ShareDetail {
		address to;
		uint256 amount;
		string identifier;
	}

	event ShareUpdated(
		uint256 merchant_share,
		uint256 platform_share,
		uint256 affiliate1_share,
		uint256 affiliate2_share,
		uint256 total_share
	);

	uint256 public last_payout_id;
	uint256 public last_payout_at;

	struct Payout {
		uint256 id;
		uint256 invoice_id;
		address token;
		uint256 amount;
		uint256 timestamp;
		ShareDetail merchant;
		ShareDetail platform;
	}

	mapping(uint256 => Payout) public payouts;
	mapping(uint256 => uint256) public invoice_payouts;

	event PayoutSent(Payout, Invoice);

	// Invoice smart wallet
	address public invoice_wallet_factory_contract;
	mapping(address => uint256) public wallet_invoice;

	// Unpaid invoices having a wallet address
	uint256[] public unpaid_wallet_invoice_ids;

	constructor() Ownable(msg.sender) {}

	function initialize(
		address _merchant_address,
		address _platform_address,
		uint256 _merchant_share,
		uint256 _platform_share,
		uint256 _merchant_share_card,
		uint256 _platform_share_card,
		address[] calldata _affiliate_addresses,
		uint256[] calldata _affiliate_shares,
		address[] calldata _affiliate_addresses_card,
		uint256[] calldata _affiliate_shares_card,
		address _invoice_wallet_factory_contract
	) public onlyOwner {
		setInvoiceWalletFactoryContractAddress(
			_invoice_wallet_factory_contract
		);

		// Ensure affiliate addresses and shares arrays match in length
		require(
			_affiliate_addresses.length == _affiliate_shares.length,
			"Affiliates and shares length mismatch"
		);
		require(
			_affiliate_addresses_card.length == _affiliate_shares_card.length,
			"Card affiliates and shares length mismatch"
		);

		merchant_address = _merchant_address;
		platform_address = _platform_address;

		uint256 calculatedTotalShares = _merchant_share + _platform_share;
		uint256 calculatedTotalSharesCard = _merchant_share_card +
			_platform_share_card;

		// Add affiliate shares to total shares
		for (uint256 i = 0; i < _affiliate_addresses.length; i++) {
			require(
				_affiliate_shares[i] >= 0,
				"Affiliate share must be positive"
			);
			require(
				_affiliate_addresses[i] != address(0),
				"Invalid affiliate address"
			);
			affiliates.push(
				Affiliate(_affiliate_addresses[i], _affiliate_shares[i])
			);
			calculatedTotalShares += _affiliate_shares[i];
			emit AffiliateAdded(_affiliate_addresses[i], _affiliate_shares[i]);
		}

		for (uint256 i = 0; i < _affiliate_addresses_card.length; i++) {
			require(
				_affiliate_shares_card[i] >= 0,
				"Affiliate share must be positive"
			);
			require(
				_affiliate_addresses_card[i] != address(0),
				"Invalid card affiliate address"
			);
			affiliates_card.push(
				Affiliate(
					_affiliate_addresses_card[i],
					_affiliate_shares_card[i]
				)
			);
			calculatedTotalSharesCard += _affiliate_shares_card[i];
			emit AffiliateAdded(
				_affiliate_addresses_card[i],
				_affiliate_shares_card[i]
			);
		}

		require(
			calculatedTotalShares <= total_share,
			"Combined shares for regular invoices exceed total available"
		);
		require(
			calculatedTotalSharesCard <= total_share_card,
			"Combined shares for card invoices exceed total available"
		);

		merchant_share = _merchant_share;
		platform_share = _platform_share;
		total_share = calculatedTotalShares;

		merchant_share_card = _merchant_share_card;
		platform_share_card = _platform_share_card;
		total_share_card = calculatedTotalSharesCard;
	}

	function getShareAddresses()
		public
		view
		returns (address, address, address[] memory)
	{
		address[] memory affiliateAddresses = new address[](affiliates.length);

		for (uint256 i = 0; i < affiliates.length; i++) {
			affiliateAddresses[i] = affiliates[i].affiliateAddress;
		}

		return (merchant_address, platform_address, affiliateAddresses);
	}

	function setInvoiceWalletFactoryContractAddress(
		address _address
	) public onlyOwner {
		invoice_wallet_factory_contract = _address;
	}

	function _distributeFundsForInvoice(uint256 _invoice_id) internal {
		uint256 _amount = invoices[_invoice_id].amount;
		Invoice memory invoice = invoices[_invoice_id];

		require(_amount > 0, "Amount should be greater than zero!");
		require(
			invoice.paid_at > 0 && invoice.status == InvoiceStatus.Paid,
			"Invoice is not paid yet!"
		);
		require(
			payouts[invoice_payouts[_invoice_id]].timestamp == 0,
			"Payout already sent for this invoice!"
		);

		uint256 _merchantShare = invoice.customer_pay_fee
			? invoice.original_amount
			: _amount.mulDiv(merchant_share, total_share);

		uint256 _platformShare = invoice.original_amount.mulDiv(
			platform_share,
			total_share
		);

		if (_merchantShare > 0) {
			_transferFunds(invoice.token, merchant_address, _merchantShare);
		}

		if (_platformShare > 0) {
			_transferFunds(invoice.token, platform_address, _platformShare);
		}

		// Distribute the remaining fee among affiliates
		for (uint i = 0; i < affiliates.length; i++) {
			uint256 _affiliateShare = invoice.original_amount.mulDiv(
				affiliates[i].share,
				total_share
			);
			if (_affiliateShare > 0) {
				_transferFunds(
					invoice.token,
					affiliates[i].affiliateAddress,
					_affiliateShare
				);
			}
		}

		last_payout_at = block.timestamp;
		last_payout_id = last_payout_id + 1;

		payouts[last_payout_id] = Payout(
			last_payout_id,
			_invoice_id,
			invoice.token,
			invoice.original_amount,
			last_payout_at,
			ShareDetail(merchant_address, merchant_share, "merchant"),
			ShareDetail(platform_address, platform_share, "platform")
		);

		invoice_payouts[_invoice_id] = last_payout_id;

		emit PayoutSent(payouts[last_payout_id], invoice);
	}

	function _distributeFundsForInvoiceCard(uint256 _invoice_id) internal {
		uint256 _amount = invoices[_invoice_id].amount_card;
		Invoice memory invoice = invoices[_invoice_id];

		require(_amount > 0, "Amount should be greater than zero!");
		require(
			invoice.paid_at > 0 && invoice.status == InvoiceStatus.Paid,
			"Invoice is not paid yet!"
		);
		require(
			payouts[invoice_payouts[_invoice_id]].timestamp == 0,
			"Payout already sent for this invoice!"
		);

		uint256 _merchantShare = invoice.customer_pay_fee
			? invoice.original_amount
			: _amount.mulDiv(merchant_share_card, total_share);

		uint256 _platformShare = invoice.original_amount.mulDiv(
			platform_share_card,
			total_share
		);

		if (_merchantShare > 0) {
			_transferFunds(invoice.token, merchant_address, _merchantShare);
		}

		if (_platformShare > 0) {
			_transferFunds(invoice.token, platform_address, _platformShare);
		}

		for (uint i = 0; i < affiliates_card.length; i++) {
			uint256 _affiliateShare = invoice.original_amount.mulDiv(
				affiliates_card[i].share,
				total_share
			);
			if (_affiliateShare > 0) {
				_transferFunds(
					invoice.token,
					affiliates_card[i].affiliateAddress,
					_affiliateShare
				);
			}
		}

		last_payout_at = block.timestamp;
		last_payout_id = last_payout_id + 1;

		payouts[last_payout_id] = Payout(
			last_payout_id,
			_invoice_id,
			invoice.token,
			invoice.original_amount,
			last_payout_at,
			ShareDetail(merchant_address, merchant_share_card, "merchant"),
			ShareDetail(platform_address, platform_share_card, "platform")
		);

		invoice_payouts[_invoice_id] = last_payout_id;

		emit PayoutSent(payouts[last_payout_id], invoice);
	}

	function _transferFunds(
		address _token,
		address _to,
		uint256 _amount
	) internal {
		if (_amount > 0) {
			if (_token == address(0)) {
				payable(_to).transfer(_amount);
			} else {
				IERC20(_token).transfer(_to, _amount);
			}
		}
	}

	function getQuote(
		uint256 _invoice_id
	) public view returns (uint256, address) {
		require(invoices[_invoice_id].id > 0, "Invoice doesn't exists!");
		require(
			invoices[_invoice_id].status == InvoiceStatus.Unpaid,
			"Invoice is already paid!"
		);

		return (invoices[_invoice_id].amount, invoices[_invoice_id].token);
	}

	function getQuoteCard(
		uint256 _invoice_id
	) public view returns (uint256, address) {
		require(invoices[_invoice_id].id > 0, "Invoice doesn't exists!");
		require(
			invoices[_invoice_id].status == InvoiceStatus.Unpaid,
			"Invoice is already paid!"
		);

		return (invoices[_invoice_id].amount_card, invoices[_invoice_id].token);
	}

	function cancelInvoice(uint256 _invoice_id) public onlyOwner {
		require(
			invoices[_invoice_id].status == InvoiceStatus.Unpaid,
			"Only unpaid invoices can be cancelled!"
		);
		invoices[_invoice_id].status = InvoiceStatus.Cancelled;
		emit InvoiceCancelled(_invoice_id);
	}

	function pay(uint256 _invoice_id) public payable nonReentrant {
		(uint256 _quote_amount, address _token) = getQuote(_invoice_id);

		if (_token == address(0)) {
			require(
				msg.value == _quote_amount,
				"Quote is different than the amount you are sending."
			);
		} else {
			require(msg.value == 0, "Do not send funds!");
			require(
				IERC20(_token).balanceOf(msg.sender) >= _quote_amount,
				"Quote is higher than the amount you are sending."
			);

			bool _success = IERC20(_token).transferFrom(
				msg.sender,
				address(this),
				_quote_amount
			);

			require(_success == true, "Transfer failed.");
		}

		invoices[_invoice_id].paid_at = block.timestamp;
		invoices[_invoice_id].status = InvoiceStatus.Paid;

		_distributeFundsForInvoice(_invoice_id);

		if (invoices[_invoice_id].wallet != address(0)) {
			_removeUnpaidWalletInvoice(_invoice_id);
		}

		emit InvoicePaid(
			_invoice_id,
			msg.sender,
			_token,
			_quote_amount,
			invoices[_invoice_id]
		);
	}

	function pay_card(uint256 _invoice_id) public payable {
		(uint256 _quote_amount, address _token) = getQuoteCard(_invoice_id);

		if (_token == address(0)) {
			require(
				msg.value == _quote_amount,
				"Quote is different than the amount you are sending."
			);
		} else {
			require(msg.value == 0, "Do not send funds!");
			require(
				IERC20(_token).balanceOf(msg.sender) >= _quote_amount,
				"Quote is higher than the amount you are sending."
			);

			bool _success = IERC20(_token).transferFrom(
				msg.sender,
				address(this),
				_quote_amount
			);

			require(_success == true, "Transfer failed.");
		}

		invoices[_invoice_id].paid_at = block.timestamp;
		invoices[_invoice_id].status = InvoiceStatus.Paid;

		_distributeFundsForInvoiceCard(_invoice_id);

		if (invoices[_invoice_id].wallet != address(0)) {
			_removeUnpaidWalletInvoice(_invoice_id);
		}

		emit InvoicePaid(
			_invoice_id,
			msg.sender,
			_token,
			_quote_amount,
			invoices[_invoice_id]
		);
	}

	function createInvoice(
		string memory _number,
		string memory _title,
		address payable _customer,
		uint256 _amount,
		uint256 _amount_card,
		uint256 _original_amount,
		bool _customer_pay_fee,
		uint256 _due_at,
		address _token,
		InvoiceItem[] memory _items
	) public onlyOwner {
		require(_amount > 0, "Amount must be greater than zero!");
		require(_amount_card > 0, "Amount Card must be greater than zero!");

		last_invoice_id++;

		Invoice storage newInvoice = invoices[last_invoice_id];
		newInvoice.id = last_invoice_id;
		newInvoice.number = _number;
		newInvoice.title = _title;
		newInvoice.customer = _customer;
		newInvoice.amount = _amount;
		newInvoice.amount_card = _amount_card;
		newInvoice.original_amount = _original_amount;
		newInvoice.customer_pay_fee = _customer_pay_fee;
		newInvoice.created_at = block.timestamp;
		newInvoice.updated_at = block.timestamp;
		newInvoice.due_at = _due_at;
		newInvoice.status = InvoiceStatus.Unpaid;
		newInvoice.paid_at = 0;
		newInvoice.token = _token;

		for (uint256 i = 0; i < _items.length; i++) {
			newInvoice.items.push(_items[i]);
		}

		customer_invoices[_customer].push(last_invoice_id);
		invoiceNumberToId[_number] = last_invoice_id;

		if (
			address(0) != invoice_wallet_factory_contract &&
			address(0) != newInvoice.token
		) {
			newInvoice.wallet = InvoiceWalletFactoryContractInterface(
				invoice_wallet_factory_contract
			).createWallet(address(this), last_invoice_id);
			wallet_invoice[newInvoice.wallet] = last_invoice_id;
			unpaid_wallet_invoice_ids.push(last_invoice_id);
		}

		emit InvoiceCreated(
			last_invoice_id,
			_customer,
			_token,
			_amount,
			newInvoice
		);
	}

	function _removeUnpaidWalletInvoice(uint256 _invoice_id) internal {
		for (uint i = 0; i < unpaid_wallet_invoice_ids.length; i++) {
			if (unpaid_wallet_invoice_ids[i] == _invoice_id) {
				unpaid_wallet_invoice_ids[i] = unpaid_wallet_invoice_ids[
					unpaid_wallet_invoice_ids.length - 1
				];
				unpaid_wallet_invoice_ids.pop();
				break;
			}
		}
	}

	function updateInvoice(
		uint256 _id,
		string memory _number,
		string memory _title,
		address payable _customer,
		uint256 _amount,
		uint256 _amount_card,
		uint256 _original_amount,
		bool _customer_pay_fee,
		uint256 _due_at,
		address _token,
		InvoiceItem[] memory _items
	) public onlyOwner {
		require(invoices[_id].id > 0, "Invoice doesn't exist!");
		require(_amount > 0, "Amount must be greater than zero!");
		require(
			invoices[_id].status == InvoiceStatus.Unpaid,
			"Invoice is already paid!"
		);

		Invoice storage invoice = invoices[_id];
		invoice.number = _number;
		invoice.title = _title;
		invoice.customer = _customer;
		invoice.amount = _amount;
		invoice.amount_card = _amount_card;
		invoice.original_amount = _original_amount;
		invoice.customer_pay_fee = _customer_pay_fee;
		invoice.updated_at = block.timestamp;
		invoice.due_at = _due_at;
		invoice.token = _token;

		// Clear existing items
		delete invoice.items;

		// Add new items
		for (uint256 i = 0; i < _items.length; i++) {
			invoice.items.push(_items[i]);
		}

		emit InvoiceUpdated(_id, _customer, _token, _amount, invoice);
	}

	function getInvoiceByNumber(
		string memory _invoiceNumber
	) public view returns (Invoice memory) {
		uint256 invoiceId = invoiceNumberToId[_invoiceNumber];
		require(invoiceId != 0, "No such invoice exists!");
		return invoices[invoiceId];
	}

	function getInvoice(
		uint256 _invoice_id
	) public view returns (Invoice memory) {
		require(invoices[_invoice_id].id > 0, "No such invoice exists!");

		return invoices[_invoice_id];
	}

	function getCustomerInvoiceCount(
		address _customer
	) public view returns (uint256) {
		return customer_invoices[_customer].length;
	}

	function getCustomerInvoiceIds(
		address _customer
	) public view returns (uint256[] memory) {
		return customer_invoices[_customer];
	}

	function getInvoicePayout(
		uint256 _invoice_id
	) public view returns (Payout memory) {
		return payouts[invoice_payouts[_invoice_id]];
	}

	function getUnpaidWalletInvoiceIds()
		public
		view
		returns (uint256[] memory)
	{
		return unpaid_wallet_invoice_ids;
	}

	function checkIfAnyUnpaidInvoiceWalletIsPaid()
		public
		view
		returns (bool canExec, bytes memory execPayload)
	{
		uint256[] memory _paid_wallet_invoice_ids = new uint256[](
			unpaid_wallet_invoice_ids.length
		);
		uint256 count = 0;
		for (uint256 i = 0; i < unpaid_wallet_invoice_ids.length; i++) {
			address _wallet = getInvoice(unpaid_wallet_invoice_ids[i]).wallet;
			if (
				getInvoice(unpaid_wallet_invoice_ids[i]).token != address(0) &&
				_wallet != address(0) &&
				wallet_invoice[_wallet] != 0 &&
				InvoiceWalletContractInterface(_wallet).releasable()
			) {
				_paid_wallet_invoice_ids[count] = unpaid_wallet_invoice_ids[i];
				count++;
			}
		}

		canExec = count > 0;

		if (canExec) {
			uint256[] memory _final_paid_wallet_invoice_ids = new uint256[](
				count
			);

			for (uint256 i = 0; i < count; i++) {
				_final_paid_wallet_invoice_ids[i] = _paid_wallet_invoice_ids[i];
			}

			execPayload = abi.encodeCall(
				this.releaseMultipleInvoices,
				(_final_paid_wallet_invoice_ids)
			);
		} else {
			execPayload = "";
		}
	}

	function releaseMultipleInvoices(uint256[] memory invoiceIds) public {
		for (uint256 i = 0; i < invoiceIds.length; i++) {
			uint256 invoiceId = invoiceIds[i];
			Invoice memory invoice = invoices[invoiceId];

			require(
				InvoiceWalletContractInterface(invoice.wallet).releasable(),
				"Invoice is not releasable"
			);

			InvoiceWalletContractInterface(invoice.wallet).release();
		}
	}

	function checkInvoiceWalletIsPaid(
		address _wallet
	) public view returns (bool canExec, bytes memory execPayload) {
		canExec =
			wallet_invoice[_wallet] != 0 &&
			getInvoice(wallet_invoice[_wallet]).token != address(0) &&
			InvoiceWalletContractInterface(_wallet).releasable();

		execPayload = abi.encodeCall(
			InvoiceWalletContractInterface(_wallet).release,
			()
		);
	}

	function releaseFromInvoiceWallet(address _wallet) external {
		(bool canExec, ) = checkInvoiceWalletIsPaid(_wallet);

		require(canExec == true, "Not releasable");

		InvoiceWalletContractInterface(_wallet).release();
	}

	function withdrawUnassociatedFunds(address _token) public {
		if (_token == address(0)) {
			uint256 _balance = address(this).balance;
			require(_balance > 0, "No funds");
			payable(owner()).transfer(address(this).balance);
		} else {
			uint256 _balance = IERC20(_token).balanceOf(address(this));
			require(_balance > 0, "No funds");
			IERC20(_token).transfer(owner(), _balance);
		}
	}

	receive() external payable {
		withdrawUnassociatedFunds(address(0));
	}

	fallback() external payable {
		withdrawUnassociatedFunds(address(0));
	}
}
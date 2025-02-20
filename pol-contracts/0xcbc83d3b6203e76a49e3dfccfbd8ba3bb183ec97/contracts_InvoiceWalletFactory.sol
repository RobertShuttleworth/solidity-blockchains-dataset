// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_Create2.sol";

interface InvoiceManagerInterface {
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

	function getInvoice(
		uint256 _invoice_id
	) external view returns (Invoice memory);
}

contract InvoiceWalletFactory {
	function createWallet(
		address _invoice_manager_contract,
		uint256 _invoice_id
	) external returns (address) {
		bytes32 salt = keccak256(abi.encodePacked(_invoice_id));
		address _walletAddress = Create2.deploy(
			0,
			salt,
			type(InvoiceWallet).creationCode
		);
		InvoiceWallet(_walletAddress).initialize(
			_invoice_manager_contract,
			_invoice_id
		);
		return _walletAddress;
	}

	function predictWalletAddress(
		uint256 _invoice_id
	) public view returns (address) {
		bytes32 salt = keccak256(abi.encodePacked(_invoice_id));
		return
			Create2.computeAddress(
				salt,
				keccak256(type(InvoiceWallet).creationCode)
			);
	}
}

contract InvoiceWallet {
	address public invoice_contract_address;
	uint256 public invoice_id;
	bool private initialized;
	bool private released;

	modifier OnlyReleased() {
		require(released == true);
		_;
	}

	function initialize(
		address _invoice_contract_address,
		uint256 _invoice_id
	) external {
		require(!initialized, "Already initialized");
		invoice_contract_address = _invoice_contract_address;
		invoice_id = _invoice_id;
		initialized = true;
	}

	function releasable() public view returns (bool) {
		InvoiceManagerInterface.Invoice
			memory invoice = InvoiceManagerInterface(invoice_contract_address)
				.getInvoice(invoice_id);

		if (
			invoice.amount > 0 &&
			invoice.paid_at == 0 &&
			invoice.token != address(0) &&
			invoice.wallet != address(0) &&
			IERC20(invoice.token).balanceOf(address(this)) >= invoice.amount &&
			released == false
		) {
			return true;
		}

		return false;
	}

	function release() external {
		require(releasable() == true, "Invoice is not paid yet.");

		InvoiceManagerInterface.Invoice
			memory invoice = InvoiceManagerInterface(invoice_contract_address)
				.getInvoice(invoice_id);

		require(
			IERC20(invoice.token).approve(
				invoice_contract_address,
				invoice.amount
			),
			"Approval failed"
		);

		(bool success, ) = invoice_contract_address.call(
			abi.encodeWithSignature("pay(uint256)", invoice_id)
		);

		require(success, "Payment failed");

		released = true;
	}

	function withdrawExcessFunds(address _token) public OnlyReleased {
		if (_token == address(0)) {
			uint256 _balance = address(this).balance;
			require(_balance > 0, "No funds");
			payable(invoice_contract_address).transfer(address(this).balance);
		} else {
			uint256 _balance = IERC20(_token).balanceOf(address(this));

			require(_balance > 0, "No funds");
			IERC20(_token).transfer(invoice_contract_address, _balance);
		}
	}
}
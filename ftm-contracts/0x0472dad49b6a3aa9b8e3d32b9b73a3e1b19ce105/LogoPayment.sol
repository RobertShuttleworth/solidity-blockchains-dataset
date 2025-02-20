// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract LogoPayment {
  address private immutable _deployer;
  mapping(address => ProductDetails[]) private _productDetails;
  bool private _inPayment;

  struct ProductDetails {
    string paymentDetail;
  }

  event PaymentMade(address indexed payer, uint256 amount, string indexed paymentDetail);
  event FundsWithdrawn(address indexed withdrawer, uint256 amount);
  event ProductDetailAdded(address indexed user, string paymentDetail);

  modifier nonReentrant() {
    require(!_inPayment, "Reentrant call");
    _inPayment = true;
    _;
    _inPayment = false;
  }

  modifier onlyDeployer() {
    require(msg.sender == _deployer, "Only the deployer can do this");
    _;
  }

  constructor() {
    require(msg.sender != address(0), "Invalid Deployer address");
    _deployer = msg.sender;
  }

  function makePayment(string memory _paymentDetail) public payable nonReentrant {
    require(msg.value != 0, "Amount must be greater than 0");
    require(bytes(_paymentDetail).length != 0, "Payment detail cannot be empty");
    require(bytes(_paymentDetail).length < 501, "Payment detail is too long");

    ProductDetails[] storage userProductDetails = _productDetails[msg.sender];
    require(userProductDetails.length < 10, "Payment details too many");
    ProductDetails memory newProductDetail;
    newProductDetail.paymentDetail = _paymentDetail;
    userProductDetails.push(newProductDetail);

    emit PaymentMade(msg.sender, msg.value, _paymentDetail);
    emit ProductDetailAdded(msg.sender, _paymentDetail);

    payable(_deployer).transfer(msg.value);
  }
  
  function getProductDetails(address _user) public view returns (string[] memory _details) {
    ProductDetails[] storage userProducts = _productDetails[_user];
    uint256 productCount = userProducts.length;
    uint256 maxDetails = 10;
    if (productCount >= maxDetails) {
      productCount = maxDetails;
    }
    _details = new string[](productCount);
    for (uint256 i = 0; i < productCount; ++i) {
      _details[i] = userProducts[i].paymentDetail;
    }
  }

  function withdraw(uint256 amount) public onlyDeployer {
    uint256 balance = address(this).balance;
    require(amount != 0, "Amount must be greater than 0");
    require(amount < balance + 1, "Amount exceeds contract balance");

    emit FundsWithdrawn(msg.sender, amount);

    payable(_deployer).transfer(amount);
  }
}
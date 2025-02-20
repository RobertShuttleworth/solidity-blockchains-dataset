// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.13;

interface GemLike {
	function decimals() external view returns (uint256);
	function transfer(address, uint256) external returns (bool);
	function transferFrom(address, address, uint256) external returns (bool);
}

interface VatLike {
	function slip(bytes32, address, int256) external;
}

/*
    Here we provide *adapters* to connect the Vat to arbitrary external
    token implementations, creating a bounded context for the Vat. The
    adapters here are provided as working examples:

      - `GemJoin2`: For well behaved ERC20 tokens, with simple transfer
                   semantics.

    Adapters need to implement two basic methods:

      - `join`: enter collateral into the system
      - `exit`: remove collateral from the system */

contract GemJoin2 {
	// --- Auth ---
	mapping(address => uint256) public wards;

	function rely(address usr) external auth {
		wards[usr] = 1;
		emit Rely(usr);
	}

	function deny(address usr) external auth {
		wards[usr] = 0;
		emit Deny(usr);
	}

	modifier auth() {
		require(wards[msg.sender] == 1, "GemJoin2/not-authorized");
		_;
	}

	VatLike public vat; // CDP Engine
	bytes32 public ilk; // Collateral Type
	GemLike public gem;
	uint256 public dec;  // gem decimals
	uint256 public live; // Active Flag

	// Events
	event Rely(address indexed usr);
	event Deny(address indexed usr);
	event Join(address indexed usr, uint256 wad);
	event Exit(address indexed usr, uint256 wad);
	event Cage();

	constructor(address vat_, bytes32 ilk_, address gem_) public {
		gem = GemLike(gem_);
		dec = gem.decimals();
		require(dec < 18, "GemJoin2/decimals-18-or-higher");
		wards[msg.sender] = 1;
		live = 1;
		vat = VatLike(vat_);
		ilk = ilk_;
		emit Rely(msg.sender);
	}

	function cage() external auth {
		live = 0;
		emit Cage();
	}

	function mul(uint256 x, uint256 y) internal pure returns (uint256 z) {
		require(y == 0 || (z = x * y) / y == x, "GemJoin2/overflow");
	}

	function join(address usr, uint256 wad) external {
		require(live == 1, "GemJoin2/not-live");
		uint wad18 = mul(wad, 10 ** (18 - dec));
		require(int256(wad18) >= 0, "GemJoin2/overflow");
		vat.slip(ilk, usr, int256(wad18));
		require(gem.transferFrom(msg.sender, address(this), wad), "GemJoin2/failed-transfer");
		emit Join(usr, wad);
	}

	function exit(address usr, uint256 wad) external {
		require(wad <= 2 ** 255, "GemJoin2/overflow");
		uint wad18 = mul(wad, 10 ** (18 - dec));
		require(int(wad18) >= 0, "GemJoin2/overflow");
		vat.slip(ilk, msg.sender, -int256(wad18));
		require(gem.transfer(usr, wad), "GemJoin2/failed-transfer");
		emit Exit(usr, wad);
	}
}
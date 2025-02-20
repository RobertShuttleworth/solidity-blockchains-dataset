//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(
        uint80 _roundId
    ) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

pragma solidity ^0.8.20;

interface TOKEN {
    function transfer(address to, uint tokens) external returns (bool success);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);
}

contract APS_Presale {
    struct Presale_stages {
        uint price;
        uint endTime;
        uint supply;
        uint total_sold;
        uint amount_raised;
        uint minimum_purchase;
    }

    struct ref_data {
        uint earning;
        uint count;
    }

    struct Data {
        mapping(uint => ref_data) referralLevel;
        address upliner;
        address[] team;
        bool investBefore;
    }

    AggregatorV3Interface internal priceFeed;

    mapping(address => Data) public user;

    mapping(uint => Presale_stages) public presale;

    address payable public owner;
    uint public total_soldSupply;
    uint public total_stages;
    uint public total_raised;
    address public premium_ref = 0x97A760EeD672A22c0B782F813F30598B8f994038;

    address public usdt_token;
    address public aps_token;

    struct refStatement_data {
        address buyer;
        uint invest_amount;
        uint commission;
    }
    struct refStatement_data1 {
        address buyer;
        uint invest_amount;
        uint commission;
        uint time;
    }

    mapping(address => mapping(uint => uint)) public previous_earning;
    mapping(address => mapping(uint => refStatement_data[])) public statement;
    mapping(address => mapping(uint => refStatement_data1[])) public user_statement;

    constructor() {
        total_stages = 8;
        owner = payable(0x8C305aaAF6b9b5d022B3A51b9Aa36898F3fd1b9F);

        priceFeed = AggregatorV3Interface(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0);
        usdt_token = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        aps_token = 0x099368A7e8A086F710B3bCF24FC979d921734b2C;

        uint96[8] memory supply_arr = [
            7000000000 ether,
            5250000000 ether,
            5250000000 ether,
            3500000000 ether,
            3500000000 ether,
            3500000000 ether,
            3500000000 ether,
            3500000000 ether
        ];
        uint40[8] memory price_arr = [
            0.000000025 ether,
            0.00000005 ether,
            0.000000075 ether,
            0.0000001 ether,
            0.00000025 ether,
            0.0000005 ether,
            0.00000075 ether,
            0.000001 ether
        ];
        uint24[8] memory time_arr = [60 days, 14 days, 14 days, 14 days, 14 days, 14 days, 14 days, 14 days];
        uint72[8] memory min_purchase = [0 ether, 5 ether, 10 ether, 15 ether, 20 ether, 25 ether, 30 ether, 35 ether];

        for (uint i = 0; i < 8; i++) {
            presale[i].price = price_arr[i];
            presale[i].supply = supply_arr[i];
            presale[i].minimum_purchase = min_purchase[i];

            if(i != 0) {
                presale[i].endTime = presale[i-1].endTime + time_arr[i];
            } else {
                presale[0].endTime = 1738434000;
            }
        }
    }

    receive() external payable { }

    function getLatestPrice() public view returns (int) {
        // prettier-ignore
        (
                /* uint80 roundID */,
                int price,
                /*uint startedAt*/,
                /*uint timeStamp*/,
                /*uint80 answeredInRound*/
            ) = priceFeed.latestRoundData();
        return price * 10 ** 10;
    }

    function getConversionRate(int dollar_amount) public view returns (int) {
        int MaticPrice = getLatestPrice();
        int UsdToMatic = ((dollar_amount * 10 ** 18) / (MaticPrice));

        return UsdToMatic;
    }

    function get_curr_Stage() public view returns (uint) {
        uint curr_stage = 7;

        for (uint i = 0; i < total_stages; i++) {
            if (block.timestamp <= presale[i].endTime) {
                curr_stage = i;
                i = total_stages;
            }
        }
        return curr_stage;
    }

    function get_curr_StageTime() public view returns (uint) {
        uint curr_stageTime = 7;

        for (uint i = 0; i < total_stages; i++) {
            if (block.timestamp <= presale[i].endTime) {
                curr_stageTime = presale[i].endTime;
                i = total_stages;
            }
        }
        return curr_stageTime;
    }

    function get_MaticPrice() public view returns (uint) {
        uint price;
        uint curr_stage = get_curr_Stage();
        price = uint256(getConversionRate(int256(presale[curr_stage].price)));

        return price;
    }

    function sendRewardToReferrals(
        address investor,
        uint _investedAmount,
        uint choosed_token //this is the freferral function to transfer the reawards to referrals
    ) internal {
        address temp = investor;
        uint[] memory percentage = new uint[](5);
        percentage[0] = 5;
        percentage[1] = 3;
        percentage[2] = 1;

        uint remaining = _investedAmount;

        for (uint i = 0; i < 3; i++) {
            if (user[temp].upliner != address(0)) {
                if (user_statement[temp][i].length == 0 && user[temp].referralLevel[i].earning > 0) {
                    previous_earning[temp][i] = user[temp].referralLevel[i].earning;
                }

                temp = user[temp].upliner;
                uint reward1 = ((percentage[i] * 1 ether) * _investedAmount) / 100 ether;

                refStatement_data1 memory temp_data;
                temp_data.buyer = investor;
                temp_data.invest_amount = choosed_token == 0 ? (uint(getLatestPrice()) * _investedAmount) / 1 ether : _investedAmount;
                temp_data.commission = choosed_token == 0 ? (uint(getLatestPrice()) * reward1) / 1 ether : reward1;
                temp_data.time = block.timestamp;

                user_statement[temp][i].push(temp_data);

                if (choosed_token == 0) {
                    payable(temp).transfer(reward1);
                } else {
                    TOKEN(usdt_token).transferFrom(msg.sender, temp, (reward1 / 10 ** 12));
                }

                user[temp].referralLevel[i].earning += choosed_token == 0 ? (uint(getLatestPrice()) * reward1) / 1 ether : reward1;
                user[temp].referralLevel[i].count++;
                remaining -= reward1;
            } else {
                break;
            }
        }

        if (choosed_token == 0) {
            payable(owner).transfer(remaining);
        } else {
            TOKEN(usdt_token).transferFrom(msg.sender, owner, (remaining / 10 ** 12));
        }
    }

    function buy_token(uint amount, address _referral, uint choosed_token) public payable returns (bool) {
        require(choosed_token == 0 || choosed_token == 1);

        uint curr_stage = get_curr_Stage();
        uint bought_token;

        if (user[msg.sender].investBefore == false) {
            user[msg.sender].investBefore = true;

            if (msg.sender != owner) {
                if (_referral == address(0) || _referral == msg.sender) //checking that investor comes from the referral link or not
                {
                    user[msg.sender].upliner = owner;
                } else {
                    user[msg.sender].upliner = _referral;
                    user[_referral].team.push(msg.sender);
                }
            }
        }

        if (choosed_token == 0) // MATIC
        {
            require(((uint(getLatestPrice()) * msg.value) / 1 ether) >= presale[curr_stage].minimum_purchase);

            bought_token = (msg.value * 10 ** 18) / get_MaticPrice();
            require(TOKEN(aps_token).balanceOf(address(this)) >= bought_token);

            presale[curr_stage].total_sold += bought_token;
            total_soldSupply += bought_token;

            sendRewardToReferrals(msg.sender, msg.value, choosed_token);

            if (premium_ref == user[msg.sender].upliner) {
                uint extra = (bought_token * 20) / 100;
                TOKEN(aps_token).transfer(msg.sender, bought_token + extra);
            } else {
                TOKEN(aps_token).transfer(msg.sender, bought_token);
            }
        } else if (choosed_token == 1) // USDT
        {
            require(amount >= presale[curr_stage].minimum_purchase);

            bought_token = (amount * 10 ** 18) / presale[curr_stage].price;

            require(TOKEN(usdt_token).balanceOf(msg.sender) >= (amount / 10 ** 12), 'not enough usdt');
            require(TOKEN(usdt_token).allowance(msg.sender, address(this)) >= (amount / 10 ** 12), 'less allowance'); //uncomment

            require(TOKEN(aps_token).balanceOf(address(this)) >= bought_token, 'contract have less tokens');

            presale[curr_stage].total_sold += amount;
            total_soldSupply += amount;
            sendRewardToReferrals(msg.sender, amount, choosed_token);
            if (premium_ref == user[msg.sender].upliner) {
                uint extra = (bought_token * 20) / 100;
                TOKEN(aps_token).transfer(msg.sender, bought_token + extra);
            } else {
                TOKEN(aps_token).transfer(msg.sender, bought_token);
            }
        }

        total_raised += (((presale[curr_stage].price * bought_token) / 10 ** 18));
        presale[curr_stage].amount_raised += (((presale[curr_stage].price * bought_token) / 10 ** 18));

        return true;
    }

    function transferOwnership(address _owner) public {
        require(msg.sender == owner);
        owner = payable(_owner);
    }

    function update_currPhase_price(uint _price) public {
        require(msg.sender == owner);
        uint curr_stage = get_curr_Stage();
        presale[curr_stage].price = _price;
    }

    function increase_currPhase_time(uint _days) public {
        require(msg.sender == owner);
        uint curr_stage = get_curr_Stage();
        for (uint i = curr_stage; i < total_stages; i++) {
            presale[i].endTime += (_days * 1 days);
        }
    }

    function curr_time() public view returns (uint) {
        return block.timestamp;
    }

    function referralLevel_earning(address _add) public view returns (uint[] memory arr1) {
        uint[] memory referralLevels_reward = new uint[](3);
        for (uint i = 0; i < 3; i++) {
            referralLevels_reward[i] = user[_add].referralLevel[i].earning;
        }
        return referralLevels_reward;
    }

    function referralLevel_count(address _add) public view returns (uint[] memory _arr) {
        uint[] memory referralLevels_reward = new uint[](3);
        for (uint i = 0; i < 3; i++) {
            referralLevels_reward[i] = user[_add].referralLevel[i].count;
        }
        return referralLevels_reward;
    }

    function get_refStatement(address _add, uint _no) public view returns (refStatement_data1[] memory _arr) {
        return user_statement[_add][_no];
    }

    function withdraw_APS(uint _amount) public {
        require(msg.sender == owner);
        uint bal = TOKEN(aps_token).balanceOf(address(this));
        require(bal >= _amount);
        TOKEN(aps_token).transfer(owner, _amount);
    }

    function set_minPurchase(uint _val) public {
        require(msg.sender == owner);
        presale[get_curr_Stage()].minimum_purchase = _val;
    }
}
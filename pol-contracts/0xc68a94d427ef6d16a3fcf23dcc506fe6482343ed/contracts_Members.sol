// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_Poi.sol";
import "./hardhat_console.sol";
import "./contracts_DRT.sol";

contract MembershipContract is Initializable, AccessControlUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
        bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
        DRTToken public drtToken; // Token DRT
        IERC20 public USDT;
        POI public poiContract;
        NFTAccount public accountContract;

        address public stakingAddress;
        address public accountAddress;
        uint256 public totalPercentageAdmin;
        address public rankAddress;    
        uint256 public partnerShipRewards;
        address public partnerShip;
        Membership[] public memberships; 
        uint256 public splitAmount;
        uint256 public splitAdminAmount;

        event UpdateTotalDirect(uint256 indexed _tokenId, uint256 _directVol);
        event UpdateTotalGlobal(uint256 indexed _tokenId, uint256 _directVol);
        event UpdateDirectVol(uint256 indexed _tokenId, uint256 _directVol, uint256 _referredTokenId);
        event UpdateGlobalVol(uint256 indexed _tokenId, uint256 _globalVol, uint256 _level, uint256 _referredTokenId);
        event UpdateProfit(uint256 indexed _tokenId, uint256 _level, uint256 _amount);
        event UpdateMissedProfit(uint256 indexed _tokenId, uint256 _level, uint256 _amount);
        event UpdatePayedProfit(uint256 indexed _tokenId, uint256 _level, uint256 _amount);
        event MembershipPurchased(uint256 membershipId, uint256 indexed nftUse, uint256 sponsor,address wallet, string promoCode, uint256 amountPaid);
        event MembershipPurchasedAdmin(uint256 membershipId, uint256 indexed nftUse, uint256 sponsor,address wallet, uint256 promoCode, uint256 amountPaid);
        event RewardClaimed(uint256 indexed nftUse, uint256 amountClaimed);
        event PartnerShipRewardClaimed(uint256 amountClaimed);

        struct Membership {
            string membershipTitle;      
            uint256 membershipAmount;   
            uint256 actualMemberships;   
            uint256 maxMemberships;      
            uint256 startDate;          
            uint256 expirationDate; 
            uint256 expirationMembership;
            uint256 minInv;
            uint256 maxInv;
            bool fee;
            uint256 amountFee;
            uint256 performanceFee;
        }

        struct InfoOfMembershipsBuy {
            uint256 memberId;      
            uint256 time;    
            uint256 expire; 
            uint256 staked;
        }
        struct purchasingInformation {
            uint256 memberId;      
            uint256 time;    
            uint256 paid;
        }

        struct promoCode{
            string PromoName;
            uint256 amountUsed;
            uint256 limitUsers;
            uint256 Promodiscount;
            uint256 startDate;
            uint256 endDate;
            address userWallet;
            bool status;
        }

        struct membershipsTranches {
            uint256 amount;
            uint256 time;
        }

        struct infoTranches {
            uint256 amount;
            uint256 time;
        }

    mapping(uint256 => InfoOfMembershipsBuy[]) public membershipOfUsers; 
    mapping(uint256 => uint256) public leadershipSplitPartners; 
    mapping(uint256 => uint256) public bestMember;
    mapping(uint256 => uint256) public MembersMoney; 
    mapping(uint256 => bool) public haveMembership;
    mapping(address => bool) public hasExecuted;
    mapping(uint256 => uint256) public totalPayedRewards; 
    mapping(uint256 => uint256) public rewards;
    mapping(uint256 => uint256) public directs;
    mapping(uint256 => uint256) public rank;
    mapping(uint256 => purchasingInformation[]) public purchasingOfUsers;
    mapping(string => promoCode) public promoCodes;
    mapping(uint256 => membershipsTranches[]) public membershipsPerTranches;
    mapping(uint256 => infoTranches[]) public bonusPerTranches;
    mapping(uint256 => uint256) public cashbackPercentage;


    function initialize(address _usdtAddress, address _poiAddress,address _stakingAddress, address _accountAddress) public initializer {
            __AccessControl_init();
            __Ownable_init(msg.sender);
            __UUPSUpgradeable_init();
            _grantRole(ADMIN_ROLE, msg.sender);

            USDT = IERC20(_usdtAddress);
            poiContract = POI(_poiAddress);
            accountContract = NFTAccount(_accountAddress);
            stakingAddress = _stakingAddress;
            accountAddress = _accountAddress;
            setSplitAdminAmount(80);
            setSplitAmount(20);
    }
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
        
    //Admin Variables

    function setUsdtConract(address _usdtAddress) public onlyOwner { 
        USDT = IERC20(_usdtAddress);
    }

    function setPoiContract(address _poiAddress) public onlyOwner { 
        poiContract = POI(_poiAddress);
    }

    function setAccountContract(address _accountContract) public onlyOwner { 
        accountContract = NFTAccount(_accountContract);
    }


   function setStakeingAddress(address _stakingAddress) public onlyOwner { 
            stakingAddress = _stakingAddress;
   }

   function setAccountAddress(address _accountAddress) public onlyOwner { 
            accountAddress = _accountAddress;
   }

    function setRankAddress(address _rankAddress) public onlyOwner {
        rankAddress = _rankAddress;
    }

    function setPartnerShip(address _wallet) public onlyOwner {
        partnerShip = _wallet;
    }


    function createMembership(string memory _membershipTitle, uint256 _membershipAmount, uint256 _maxMemberships,
    uint256 _timelimitMembership, uint256 _expirationMembership, uint256 _minInv, uint256 _maxInv, bool _fee, uint256 _amountFee,uint256 _performanceFee
    ) public onlyOwner{
            memberships.push(Membership(_membershipTitle,_membershipAmount,0,_maxMemberships, block.timestamp,block.timestamp +  (_timelimitMembership * 1 days), _expirationMembership ,
            _minInv, _maxInv, _fee, _amountFee,_performanceFee));
    }

    function updateMembership(uint256 _membershipId, string memory _membershipTitle, uint256 _membershipAmount, uint256 _maxMemberships,
    uint256 _timelimitMembership, uint256 _expirationMembership, uint256 _minInv, uint256 _maxInv, bool _fee, uint256 _amountFee,uint256 _performanceFee
    ) public onlyOwner {
        Membership storage membership = memberships[_membershipId];
        membership.membershipTitle = _membershipTitle;
        membership.membershipAmount = _membershipAmount;
        membership.maxMemberships = _maxMemberships;
        membership.expirationDate = block.timestamp + (_timelimitMembership * 1 days);
        membership.expirationMembership = _expirationMembership;
        membership.minInv = _minInv;
        membership.maxInv = _maxInv;
        membership.fee = _fee;
        membership.amountFee = _amountFee;
        membership.performanceFee = _performanceFee;
    }

    function deleteMembership(uint256 _membershipId) public onlyOwner { 
        require(_membershipId < memberships.length, "Invalid membership ID");
        for (uint i = _membershipId; i < memberships.length - 1; i++) {
            memberships[i] = memberships[i + 1];
        }
        memberships.pop();
    }

    function setSplitAmount(uint256 _amount) public onlyOwner {
        splitAmount = _amount;
    }

    function setSplitAdminAmount(uint256 _amount) public onlyOwner {
        splitAdminAmount = _amount;
    }

    function buyMembershipAdmin(uint256 _membershipId,uint256 _nftUse, uint256 _discountAmount) public onlyOwner {
            Membership storage membership = memberships[_membershipId]; 
            uint256 sponsor;
            (, , , uint256 sponsorNFT, , , , , , , , , , , ,) = accountContract.accountInfo(_nftUse);
            sponsor =  sponsorNFT;       

            uint256 finalAmount = membership.membershipAmount - (membership.membershipAmount * _discountAmount / 100);

            membership.actualMemberships++; 
            require(membership.maxMemberships == 0 || membership.actualMemberships <= membership.maxMemberships, "Membership limit reached"); 
            require(block.timestamp <= membership.expirationDate || membership.expirationDate == 0, "Membership sale expired"); 
            if(sponsor != 0){
                require(sponsor != _nftUse, "sponsor dif own address"); 
            }
           
           if(!haveMembership[_nftUse]){
                leadershipSplitPartners[_nftUse] = sponsor; 
                haveMembership[_nftUse] = true;
           }

            purchasingOfUsers[_nftUse].push(purchasingInformation(_membershipId, block.timestamp, finalAmount));

            membershipOfUsers[_nftUse].push(InfoOfMembershipsBuy(_membershipId, block.timestamp, block.timestamp + (membership.expirationMembership * 1 seconds),0));
            MembersMoney[_nftUse] += finalAmount;
            if(bestMember[_nftUse] < _membershipId) {
                bestMember[_nftUse] = _membershipId;
            }
            accountContract.updateMembership(_nftUse,_membershipId);

            if(accountContract.ownerOf(0) != msg.sender){
                rewards[sponsor] += (finalAmount * splitAmount) / 100;
                partnerShipRewards += (finalAmount * splitAdminAmount) / 100; 
            }else{
                if(!hasExecuted[msg.sender]){
                    partnerShipRewards += finalAmount; 
                }else{
                    rewards[sponsor] += (finalAmount * splitAmount) / 100;
                    partnerShipRewards += (finalAmount * splitAdminAmount) / 100;
                }
            }

            bonusPerTranches[sponsor].push(infoTranches(
                (finalAmount * splitAmount) / 100,
                block.timestamp
            ));

            if(!hasExecuted[msg.sender]){
                hasExecuted[msg.sender] = true;
            }
            require(USDT.transferFrom(msg.sender, address(this), finalAmount), "USDT transfer failed");
            accountContract.updateTotalDirect(sponsor,finalAmount);
            emit MembershipPurchasedAdmin(_membershipId, _nftUse, sponsor, msg.sender, _discountAmount, membership.membershipAmount);
    }

    function addPromoCode(string memory _promoName, uint256 _limitUsers, uint256 _promoDiscount, 
    uint256 _startDate, uint256 _endDate, address _userWallet) public onlyOwner {
        promoCodes[_promoName] = promoCode({
            PromoName: _promoName,
            amountUsed: 0,
            limitUsers: _limitUsers,
            Promodiscount: _promoDiscount,
            startDate: _startDate,
            endDate: _endDate,
            userWallet: _userWallet,
            status: true
        });
    }


    function setDrtToken(address _drtTokenAddress) public onlyOwner { 
        drtToken = DRTToken(_drtTokenAddress);
    }

    // Función para establecer el porcentaje de cashback (porcentaje sobre 100)
    function setCashbackPercentage(uint256 _percentage, uint256 _membershipId) public onlyOwner {
        require(_percentage <= 100, "Cashback percentage cannot exceed 100%");
        cashbackPercentage[_membershipId] = _percentage;
    }

    //User Variables

    function buyMembership(uint256 _membershipId,uint256 _nftUse, string memory _promoCode, uint256 _drtAmount) public  {
            Membership storage membership = memberships[_membershipId]; 
            uint256 discount;
            uint256 sponsor;
            (, , , uint256 sponsorNFT, , , , , , , , , , , ,) = accountContract.accountInfo(_nftUse);
            sponsor =  sponsorNFT;   

            if (bytes(_promoCode).length > 0) {
                require(_drtAmount == 0, "No puedes utilizar codigo de descuento y DRT a la vez");
                if (promoCodes[_promoCode].status) {
                    promoCode memory promo = promoCodes[_promoCode];
                    require(block.timestamp >= promo.startDate && block.timestamp <= promo.endDate, "Promo code expired or promo code not started yet");
                    if(promo.limitUsers != 0){
                        require(promo.amountUsed + 1 <= promo.limitUsers, "Promo code limit reached");
                    }
                    if(promo.limitUsers == 1){
                        require(promo.userWallet == msg.sender, "Not authorized to use this promo code");
                    }
                    
                    discount = promo.Promodiscount;
                    promoCodes[_promoCode].amountUsed++; 
                }
            }

           // uint256 finalAmount = membership.membershipAmount - (membership.membershipAmount * discount / 100);


            if(_drtAmount > 0){ 
                require(membership.membershipAmount > 0, "Cannot use DRT for free memberships");
                require(_drtAmount <= (membership.membershipAmount / 2), "Cannot use more than 50% in DRT");
                require(drtToken.balanceOf(msg.sender) >= _drtAmount, "Insufficient DRT balance");
                drtToken.burn(msg.sender, _drtAmount);
            }

            uint256 cashbackDRT = (membership.membershipAmount * cashbackPercentage[_membershipId]) / 100;
            if (cashbackDRT > 0) {
                drtToken.mint(msg.sender, cashbackDRT);
            }

            uint256 finalAmount = membership.membershipAmount - (membership.membershipAmount * discount / 100) - _drtAmount;


            membershipsPerTranches[_nftUse].push(membershipsTranches(
                finalAmount,
                block.timestamp
            ));


            membership.actualMemberships++; 
            require(membership.maxMemberships == 0 || membership.actualMemberships <= membership.maxMemberships, "Membership limit reached"); 
            require(block.timestamp <= membership.expirationDate || membership.expirationDate == 0, "Membership sale expired");
            if(sponsor != 0){
                require(sponsor != _nftUse, "sponsor dif own address"); 
                require(haveMembership[sponsor], "sponsor dont have membership"); 
            }
            require(accountContract.ownerOf(_nftUse) == msg.sender ,"Debe ser el dueno del NFT");
            require(poiContract.userRegister(msg.sender),"Debe estar registrado"); 
           
           if(!haveMembership[_nftUse]){
                leadershipSplitPartners[_nftUse] = sponsor; 
                haveMembership[_nftUse] = true;
           }

       
            purchasingOfUsers[_nftUse].push(purchasingInformation(_membershipId, block.timestamp, finalAmount));

            membershipOfUsers[_nftUse].push(InfoOfMembershipsBuy(_membershipId, block.timestamp, block.timestamp + (membership.expirationMembership * 1 seconds),0));
            MembersMoney[_nftUse] += finalAmount;
            if(bestMember[_nftUse] < _membershipId) {
                bestMember[_nftUse] = _membershipId;
            }
            accountContract.updateMembership(_nftUse,_membershipId);

            if(accountContract.ownerOf(0) != msg.sender){
                rewards[sponsor] += (finalAmount * splitAmount) / 100;
                partnerShipRewards += (finalAmount * splitAdminAmount) / 100; 
            }else{
                if(!hasExecuted[msg.sender]){
                    partnerShipRewards += finalAmount; 
                }else{
                    rewards[sponsor] += (finalAmount * splitAmount) / 100;
                    partnerShipRewards += (finalAmount * splitAdminAmount) / 100;
                }
            }

            bonusPerTranches[sponsor].push(infoTranches(
                (finalAmount * splitAmount) / 100,
                block.timestamp
            ));
            
            if(!hasExecuted[msg.sender]){
                hasExecuted[msg.sender] = true;
            }
            require(USDT.transferFrom(msg.sender, address(this), finalAmount), "USDT transfer failed");
            accountContract.updateTotalDirect(sponsor,finalAmount);
            emit MembershipPurchased(_membershipId, _nftUse, sponsor, msg.sender, _promoCode, membership.membershipAmount);
    }
    
    function claimMembershipReward(uint256 _nftUse) public {
        require(accountContract.ownerOf(_nftUse) == msg.sender ,"Not the owner"); 
        emit RewardClaimed(_nftUse, rewards[_nftUse]);
        require(USDT.transfer(msg.sender, rewards[_nftUse]), "USDT transfer failed");
        totalPayedRewards[_nftUse] += rewards[_nftUse];
        rewards[_nftUse] = 0;
    }

    function claimRewardPartnerShip() public {
        require(msg.sender == partnerShip, "You are not the PartnerShip"); 
        emit PartnerShipRewardClaimed(partnerShipRewards);
        require(USDT.transfer(msg.sender, partnerShipRewards), "USDT transfer failed");
        partnerShipRewards = 0;
    }

    function updateStake(uint256 _userId, uint256 _index, uint256 _amount) public { 
      require(msg.sender == stakingAddress, "Only the staking conrtract can call  this function"); 
      membershipOfUsers[_userId][_index].staked += _amount;
    }

    function updateRank(uint256 _tokenId, uint256 _rank) public {
        require(msg.sender == rankAddress, "Only the staking conrtract can call this function"); 
        rank[_tokenId] = _rank;
    }

    function updateDirects(uint256 _userId) public { 
      require(msg.sender == stakingAddress, "Only the staking conrtract can call  this function"); 
      directs[_userId]++;
    }

    function payMembershipAdmin(uint256 _nftUse, uint256 _amount) public  {
            require(msg.sender == stakingAddress, "Only the staking conrtract can call  this function");
            
            uint256 sponsor;
            (, , , uint256 sponsorNFT, , , , , , , , , , , ,) = accountContract.accountInfo(_nftUse);
            sponsor =  sponsorNFT;       
            
            MembersMoney[_nftUse] += _amount;
           
            if(accountContract.ownerOf(0) != msg.sender){ 
                rewards[sponsor] += (_amount * splitAmount) / 100;
                partnerShipRewards += (_amount * splitAdminAmount) / 100; 
            }else{
                if(!hasExecuted[msg.sender]){
                    partnerShipRewards += _amount; 
                }else{
                    rewards[sponsor] += (_amount * splitAmount) / 100;
                    partnerShipRewards += (_amount * splitAdminAmount) / 100;
                }
            }

            accountContract.updateTotalDirect(sponsor,_amount);
    }
    
    //Getters

    function getMembershipOfUsersLength(uint256 userId) public view returns (uint256) {
        return membershipOfUsers[userId].length;
    }

    function getInfoOfMembership(uint256 _userId, uint256 _index) public view returns (InfoOfMembershipsBuy memory) {
        return membershipOfUsers[_userId][_index];
    }

    function getMembership(uint256 _index) public view returns (Membership memory) {
        return memberships[_index];
    }

    function getDirects (uint256 _userId) public view returns (uint256) { 
        return  directs[_userId];
    }

    function getRank (uint256 _userId) public view returns (uint256) { 
        return  rank[_userId];
    }
   
    function getPromoCode (string memory _promoCode) public view returns (uint256) { 
        return  promoCodes[_promoCode].Promodiscount;
    }

    function getPurchasingOfUsersLength(uint256 userId) public view returns (uint256) {
        return purchasingOfUsers[userId].length;
    }

    function getPurchasingOfUsers(uint256 _userId, uint256 _index) public view returns (purchasingInformation memory) {
        return purchasingOfUsers[_userId][_index];
    }

    function canUsePromoCode(string memory _promoCode, address _userWallet) public view returns (bool) {
        promoCode memory promo = promoCodes[_promoCode];

        if (!promo.status) {
            return false;
        }

        if (block.timestamp < promo.startDate || block.timestamp > promo.endDate) {
            return false;
        }

        if (promo.limitUsers != 0 && promo.amountUsed >= promo.limitUsers) {
            return false;
        }

        if (promo.limitUsers == 1 && promo.userWallet != _userWallet) {
            return false;
        }

        return true;
    }

    //New Logic

    function updatePurchasingPaid(uint256 userId, uint256 index, uint256 newPaid) public onlyOwner {
        require(index < purchasingOfUsers[userId].length, "Index out of bounds");
        purchasingOfUsers[userId][index].paid = newPaid;
    }



    //New Logic

    function buyMembershipFromUser(uint256 _membershipId,uint256 _nftUse, string memory _promoCode, uint256 _drtAmount) public  {
            Membership storage membership = memberships[_membershipId]; 
            uint256 discount;
            uint256 sponsor;
            (, , , uint256 sponsorNFT, , , , , , , , , , , ,) = accountContract.accountInfo(_nftUse);
            sponsor =  sponsorNFT;   

            if (bytes(_promoCode).length > 0) {
                require(_drtAmount == 0, "No puedes utilizar codigo de descuento y DRT a la vez");
                if (promoCodes[_promoCode].status) {
                    promoCode memory promo = promoCodes[_promoCode];
                    require(block.timestamp >= promo.startDate && block.timestamp <= promo.endDate, "Promo code expired or promo code not started yet");
                    if(promo.limitUsers != 0){
                        require(promo.amountUsed + 1 <= promo.limitUsers, "Promo code limit reached");
                    }
                    if(promo.limitUsers == 1){
                        require(promo.userWallet == msg.sender, "Not authorized to use this promo code");
                    }
                    
                    discount = promo.Promodiscount;
                    promoCodes[_promoCode].amountUsed++; 
                }
            }

           // uint256 finalAmount = membership.membershipAmount - (membership.membershipAmount * discount / 100);


            if(_drtAmount > 0){ 
                require(membership.membershipAmount > 0, "Cannot use DRT for free memberships");
                require(_drtAmount <= (membership.membershipAmount / 2), "Cannot use more than 50% in DRT");
                require(drtToken.balanceOf(msg.sender) >= _drtAmount, "Insufficient DRT balance");
                drtToken.burn(msg.sender, _drtAmount);
            }

            uint256 cashbackDRT = (membership.membershipAmount * cashbackPercentage[_membershipId]) / 100;
            if (cashbackDRT > 0) {
                drtToken.mint(msg.sender, cashbackDRT);
            }

            uint256 finalAmount = membership.membershipAmount - (membership.membershipAmount * discount / 100) - _drtAmount;


            membershipsPerTranches[_nftUse].push(membershipsTranches(
                finalAmount,
                block.timestamp
            ));


            membership.actualMemberships++; 
            require(membership.maxMemberships == 0 || membership.actualMemberships <= membership.maxMemberships, "Membership limit reached"); 
            require(block.timestamp <= membership.expirationDate || membership.expirationDate == 0, "Membership sale expired");
            if(sponsor != 0){
                require(sponsor != _nftUse, "sponsor dif own address"); 
                require(haveMembership[sponsor], "sponsor dont have membership"); 
            }
           // require(accountContract.ownerOf(_nftUse) == msg.sender ,"Debe ser el dueno del NFT");
              require(poiContract.userRegister(msg.sender),"Debe estar registrado"); 
           
           if(!haveMembership[_nftUse]){
                leadershipSplitPartners[_nftUse] = sponsor; 
                haveMembership[_nftUse] = true;
           }

       
            purchasingOfUsers[_nftUse].push(purchasingInformation(_membershipId, block.timestamp, finalAmount));

            membershipOfUsers[_nftUse].push(InfoOfMembershipsBuy(_membershipId, block.timestamp, block.timestamp + (membership.expirationMembership * 1 seconds),0));
            MembersMoney[_nftUse] += finalAmount;
            if(bestMember[_nftUse] < _membershipId) {
                bestMember[_nftUse] = _membershipId;
            }
            accountContract.updateMembership(_nftUse,_membershipId);

            if(accountContract.ownerOf(0) != msg.sender){
                rewards[sponsor] += (finalAmount * splitAmount) / 100;
                partnerShipRewards += (finalAmount * splitAdminAmount) / 100; 
            }else{
                if(!hasExecuted[accountContract.ownerOf(_nftUse)]){
                    partnerShipRewards += finalAmount; 
                }else{
                    rewards[sponsor] += (finalAmount * splitAmount) / 100;
                    partnerShipRewards += (finalAmount * splitAdminAmount) / 100;
                }
            }

            bonusPerTranches[sponsor].push(infoTranches(
                (finalAmount * splitAmount) / 100,
                block.timestamp
            ));
            
            if(!hasExecuted[accountContract.ownerOf(_nftUse)]){
                hasExecuted[accountContract.ownerOf(_nftUse)] = true;
            }
            require(USDT.transferFrom(msg.sender, address(this), finalAmount), "USDT transfer failed");
            accountContract.updateTotalDirect(sponsor,finalAmount);
            emit MembershipPurchased(_membershipId, _nftUse, sponsor, accountContract.ownerOf(_nftUse), _promoCode, membership.membershipAmount);
    }


}




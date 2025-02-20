// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_Members.sol";
import "./contracts_NFTAccount.sol";
import "./contracts_Poi.sol";
import "./hardhat_console.sol";
contract Staking is Initializable, AccessControlUpgradeable, UUPSUpgradeable, OwnableUpgradeable {
    IERC20 public usdt;
    MembershipContract public membershipContract;
    NFTAccount public accountContract;
    POI public poiContract;
    Tranche[] public tranches;
    Penalty[] public penaltyRules;

    address public treasuryAddress;
    address public partnerShip;
    bytes32 constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public partnerShipRewards;
    uint256 public TVL;
    uint256 public minStake;
    uint256 public totalProfits;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 idAccount;
        address wallet;
    }

    struct Tranche {
        uint256 balance;        
        uint256 startTime;      
        uint256 endTime;        
    }

    struct infoTranches {
        uint256 amount;
        uint256 time;
    }


    struct Penalty {
        uint256 daysThreshold;
        uint256 penaltyPercentage; 
    }

    mapping(address => Stake[]) public stakes;
    mapping(address => uint256) public totalStaked;
    mapping(uint256 => uint256) public userStakes;
    mapping(uint256 => uint256) public rewards;
    mapping(uint256 => uint256) public directs;
    mapping(uint256 => uint256) public rank;
    mapping(uint256 => uint256) public totalPayedRewards;
    mapping(uint256 => mapping(uint256 => uint256)) public userStakeTimeInTranche;
    mapping(uint256 => mapping(uint256 => uint256)) public claimedStake;
    mapping(uint256 => mapping(uint256 => uint256)) public totalPerformanceFeesPaid;
    mapping(uint256 => infoTranches[]) public stakingsPerTranches;
    mapping(uint256 => infoTranches[]) public profitPerTranches;
    mapping(uint256 => infoTranches[]) public pfPerTranches;


    event Staked(uint256 indexed nftUse, uint256 amount, uint256 index);
    event UpdateTotalDirect(uint256 indexed _tokenId, uint256 _directVol);
    event UpdateTotalGlobal(uint256 indexed _tokenId, uint256 _directVol);
    event UpdateDirectVol(uint256 indexed _tokenId, uint256 _directVol, uint256 _referredTokenId);
    event UpdateGlobalVol(uint256 indexed _tokenId, uint256 _globalVol, uint256 _level, uint256 _referredTokenId);
    event UpdateProfit(uint256 indexed _tokenId, uint256 _level, uint256 _amount);
    event UpdateMissedProfit(uint256 indexed _tokenId, uint256 _level, uint256 _amount);
    event UpdatePayedProfit(uint256 indexed _tokenId, uint256 _level, uint256 _amount);
    event RewardClaimed(uint256 indexed nftUse, uint256 amountClaimed);
    event PartnerShipRewardClaimed(uint256 amountClaimed);

    function initialize(IERC20 _usdt, address _treasuryAddress, address _memberContract,address _accountContract, address _poiAddress) public initializer { 
        __AccessControl_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        _grantRole(ADMIN_ROLE, msg.sender);
        usdt = IERC20(_usdt);
        treasuryAddress = _treasuryAddress;
        membershipContract = MembershipContract(_memberContract);
        accountContract = NFTAccount(_accountContract);
        poiContract = POI(_poiAddress);
    }

    //Admin Variables

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function setUsdtContract(address _usdt) public onlyRole(ADMIN_ROLE) {
        usdt = IERC20(_usdt);
    }

    function setTreasuryContract(address _treasury) public onlyRole(ADMIN_ROLE) {
        treasuryAddress = _treasury;
    }

    function setMembershipContract(address _memberContract) public onlyRole(ADMIN_ROLE) {
        membershipContract = MembershipContract(_memberContract);
    }

    function setAccountContract(address _accountContract) public onlyRole(ADMIN_ROLE) {
        accountContract = NFTAccount(_accountContract);
    }

    function setPoiContract(address _poiAddress) public onlyRole(ADMIN_ROLE) {
        poiContract = POI(_poiAddress);
    }

    function setPartnerShip(address _wallet) public onlyRole(ADMIN_ROLE) {
        partnerShip = _wallet;
    }

    function changeMinStake(uint256 _minStake) public onlyOwner{
        minStake = _minStake;
    }

    function withdrawProfit(uint256 profit) external  {
        require(msg.sender == treasuryAddress);
        // require(treasuryAddress != address(0), "Treasury address not set");
        // (bool success, bytes memory data) = treasuryAddress.call(
        //     abi.encodeWithSignature("withdrawProfit(uint256,uint256)", profit, performanceFees)
        // );

        // require(success, "withdrawProfit call failed");

        if (tranches.length > 0) {
            tranches[tranches.length - 1].endTime = block.timestamp;
            tranches[tranches.length - 1].balance = TVL;
            profitInTranches[tranches.length - 1] = profit;
        }

        tranches.push(Tranche({
            balance: 0,
            startTime: block.timestamp,
            endTime: 0  
        }));


        totalProfits += profit;
    }

    function addPenaltyRule(uint256 _daysThreshold, uint256 _penaltyPercentage) public onlyOwner {
        penaltyRules.push(Penalty(_daysThreshold, _penaltyPercentage));
    }

    //User Variables

    function stake(uint128 _amount,uint256 _nftUse,uint256 _index) external {
        
        MembershipContract.InfoOfMembershipsBuy memory info = membershipContract.getInfoOfMembership(_nftUse, _index);
        MembershipContract.Membership memory membership = membershipContract.getMembership(info.memberId);

        stakingsPerTranches[_nftUse].push(infoTranches(
            _amount,
            block.timestamp
        ));
       
        userStakePerTranches[_nftUse][tranches.length - 1].push(stakeTrancheInformation(
            _amount,
            block.timestamp,
            false,
            _index
        ));

        uint256 totalStakedActualAddAmount = info.staked + _amount;
        require(_amount > 0, "Amount must be greater than 0");
        require(membershipContract.haveMembership(_nftUse), "Requiere una membresia");
        require(totalStakedActualAddAmount <= membership.maxInv, "El total stakeado + el total a stakear debe ser menor que el maximo stake de la persona"); 
        if(info.staked != 0){
            require(_amount >= minStake, "El total stakeado debe ser mayor al minimo luego de la primera inversion"); 
        }else{
            require(_amount >= membership.minInv, "El total stakeado debe ser mayor al minimo"); 
        }
        require(block.timestamp <= info.expire, "Expiro tu membresia, compra una nueva"); 
        require(poiContract.userRegister(accountContract.ownerOf(_nftUse)),"Debe estar registrado"); 
        require(accountContract.ownerOf(_nftUse) == msg.sender ,"Debe ser el dueno del NFT"); 
        
        uint256 currentTranche;
        if(tranches.length == 0){
            currentTranche = 0;
        }else{
            currentTranche = tranches.length - 1;
        }
        userStakeTimeInTranche[_nftUse][currentTranche] = block.timestamp;

        membershipContract.updateStake(_nftUse,_index,_amount);
        accountContract.updateStaked(_nftUse,_amount);
        userStakes[_nftUse] += _amount;
        TVL += _amount;
        if(membership.fee){
            
            require(usdt.transferFrom(msg.sender, treasuryAddress, _amount), "USDT transfer failed");

            uint256 fee = (_amount * membership.amountFee) / 1000;

            require(usdt.transferFrom(msg.sender, address(membershipContract), fee), "USDT transfer failed");
            membershipContract.payMembershipAdmin(_nftUse,fee);

        }else{
            usdt.transferFrom(msg.sender, treasuryAddress, _amount);
        }
        stakes[msg.sender].push(Stake({
            amount: _amount,
            startTime: block.timestamp,
            idAccount: _nftUse,
            wallet: msg.sender
        }));
        
        totalStaked[msg.sender] += _amount;
        
        emit Staked(_nftUse, _amount, _index);
    }

    function claimStakingReward(uint256 _nftUse) public {
        require(accountContract.ownerOf(_nftUse) == msg.sender ,"Not the owner");
        emit RewardClaimed(_nftUse, rewards[_nftUse]);
        require(usdt.transfer(msg.sender, rewards[_nftUse]), "USDT transfer failed");
        totalPayedRewards[_nftUse] += rewards[_nftUse];
        rewards[_nftUse] = 0;
    }

    function claimRewardPartnerShip() public {
        require(msg.sender == partnerShip, "You are not the PartnerShip"); 
        emit PartnerShipRewardClaimed(partnerShipRewards);
        require(usdt.transfer(msg.sender, partnerShipRewards), "USDT transfer failed");
        partnerShipRewards = 0;
    }

    function claimProfit(uint256 _nftUse) public onlyOwner{
        require(accountContract.ownerOf(_nftUse) == msg.sender, "Not the owner");
        uint256 totalPf = 0;
        uint256 sponsor;
        (, , , uint256 sponsorNFT, , , , , , , , , , , ,) = accountContract.accountInfo(_nftUse);
        sponsor =  sponsorNFT;   

        uint256 totalReward = 0;
        uint256 membershipsLength = membershipContract.getMembershipOfUsersLength(_nftUse);
        
        for (uint256 i = 0; i < membershipsLength; i++) {
            MembershipContract.InfoOfMembershipsBuy memory membershipInfo = membershipContract.getInfoOfMembership(_nftUse, i);
            MembershipContract.Membership memory membershipDetails = membershipContract.getMembership(membershipInfo.memberId);

            uint256 membershipStake = membershipInfo.staked - claimedStake[_nftUse][i];

            if (membershipStake == 0) continue;  
            claimedStake[_nftUse][i] += membershipStake;
            uint256 userShare = (membershipStake * 1e6) / TVL;


                ////////////////////////////////////////
                    for (uint256 i = 0; i < stakingsPerTranches[_nftUse].length; i++) {
                        infoTranches memory stakeInfo = stakingsPerTranches[_nftUse][i];
                        Tranche memory tranche = tranches[i];

                        uint256 stakeDuration = 0;
                        if (block.timestamp >= tranche.endTime) {
                            stakeDuration = tranche.endTime - stakeInfo.time; // Tiempo completo si ya terminó el tranche
                        } else {
                            stakeDuration = block.timestamp - stakeInfo.time; // Tiempo actual si aún está en curso
                        }

                        uint256 trancheDuration = tranche.endTime - tranche.startTime;
                        uint256 rewardShare = (stakeDuration * 1e18) / trancheDuration; // Proporción de tiempo en el tranche

                        // Calcular recompensa proporcional
                        uint256 trancheReward = (totalProfits * rewardShare) / 1e18;
                        uint256 adjustedReward = (trancheReward * stakeInfo.amount) / TVL; // Ajustar según el porcentaje de staking en TVL

                        totalReward += adjustedReward;
                    }
                ////////////////////////////////////////

            
            uint256 reward = (totalProfits * userShare) / 1e6;
            
            uint256 performanceFee = (reward * membershipDetails.performanceFee) / 100;
            
            totalPf += performanceFee;

            pfPerTranches[_nftUse].push(infoTranches(
                performanceFee,
                block.timestamp
            ));
            
            totalPerformanceFeesPaid[_nftUse][i] += performanceFee;

            totalPfPaiedPerAccount[_nftUse] += performanceFee;

            uint256 adjustedReward = (reward * (100 - membershipDetails.performanceFee)) / 100;

            totalReward += adjustedReward;

            profitPerTranches[_nftUse].push(infoTranches(
                totalReward,
                block.timestamp
            ));

            claimedPerAccount[_nftUse] += totalReward;
            totalClaimed += totalReward;

            claimHistory[_nftUse].push(claimProfitHistory(
                reward,
                adjustedReward,
                performanceFee,
                block.timestamp
            ));

        }

        require(totalReward > 0, "No rewards available");
        require(usdt.transfer(msg.sender, totalReward), "USDT transfer failed");

        directRewardsPerTranches[sponsor].push(directRewardsInfo(
           (totalPf * 20)/100,
            block.timestamp
        ));

    }

    function unStake(uint256 _index) external {
        require(_index < stakes[msg.sender].length, "Invalid index");

        Stake memory userStake = stakes[msg.sender][_index];
        require(userStake.amount > 0, "Nothing to unstake");

        (bool success, bytes memory data) = treasuryAddress.call(
        abi.encodeWithSignature("withdrawStake(uint256)", userStake.amount)
        );

        require(success, "withdrawStake call failed");

        uint256 stakeDuration = (block.timestamp - userStake.startTime) / 1 days; // Duración en días
        uint256 penaltyPercentage = getPenaltyPercentage(stakeDuration);

        uint256 penaltyAmount = (userStake.amount * penaltyPercentage) / 100;
        uint256 amountToReturn = userStake.amount - penaltyAmount;

        // Actualizar TVL
        TVL -= userStake.amount;

        // Transferir penalización al tesoro
        if (penaltyAmount > 0) {
            usdt.transfer(owner(), penaltyAmount);
        }
        console.log("Bien");

        // Transferir el monto restante al usuario
        usdt.transfer(msg.sender, amountToReturn);
        console.log("Bien2");
        // Remover el stake del usuario
        stakes[msg.sender][_index] = stakes[msg.sender][stakes[msg.sender].length - 1];
        stakes[msg.sender].pop();
    }


    //Getters

    function getUserStakes(address _user) external view returns (Stake[] memory) {
        return stakes[_user];
    }

    function getTotalProfit(uint256 _nftUse) view public returns(uint256){

        uint256 totalReward = 0;
        uint256 membershipsLength = membershipContract.getMembershipOfUsersLength(_nftUse);

        for (uint256 i = 0; i < membershipsLength; i++) {
            MembershipContract.InfoOfMembershipsBuy memory membershipInfo = membershipContract.getInfoOfMembership(_nftUse, i);
           // MembershipContract.Membership memory membershipDetails = membershipContract.getMembership(membershipInfo.memberId);

            uint256 membershipStake = membershipInfo.staked - claimedStake[_nftUse][i];

            if (membershipStake == 0) continue;  
            uint256 userShare = (membershipStake * 1e6) / TVL;
            uint256 reward = (totalProfits * userShare) / 1e6;
          //  uint256 adjustedReward = (reward * (100 - membershipDetails.performanceFee)) / 100;
            totalReward += reward;
        }

       return totalReward;
    }

    function getPerformanceFeePaid(uint256 _nftUse, uint256 membershipIndex) external view returns (uint256) {
        return totalPerformanceFeesPaid[_nftUse][membershipIndex];
    }


    // Función para obtener el porcentaje de penalización según la duración
    function getPenaltyPercentage(uint256 _stakeDuration) public view returns (uint256) {
        for (uint256 i = 0; i < penaltyRules.length; i++) {
            if (_stakeDuration <= penaltyRules[i].daysThreshold) {
                return penaltyRules[i].penaltyPercentage;
            }
        }
        // Sin penalización si pasa más de 1 año (365 días)
        return 0;
    }

    //newLogic

    function addStake(uint128 _amount,uint256 _nftUse,uint256 _index) public onlyOwner {
        
        MembershipContract.InfoOfMembershipsBuy memory info = membershipContract.getInfoOfMembership(_nftUse, _index);
        MembershipContract.Membership memory membership = membershipContract.getMembership(info.memberId);

        stakingsPerTranches[_nftUse].push(infoTranches(
            _amount,
            block.timestamp
        ));

        userStakePerTranches[_nftUse][tranches.length - 1].push(stakeTrancheInformation(
            _amount,
            block.timestamp,
            false,
            _index
        ));


       // uint256 totalStakedActualAddAmount = info.staked + _amount;
        // require(_amount > 0, "Amount must be greater than 0");
        // require(membershipContract.haveMembership(_nftUse), "Requiere una membresia");
        // require(totalStakedActualAddAmount <= membership.maxInv, "El total stakeado + el total a stakear debe ser menor que el maximo stake de la persona"); 
        // if(info.staked != 0){
        //     require(_amount >= minStake, "El total stakeado debe ser mayor al minimo luego de la primera inversion"); 
        // }else{
        //     require(_amount >= membership.minInv, "El total stakeado debe ser mayor al minimo"); 
        // }
        // require(block.timestamp <= info.expire, "Expiro tu membresia, compra una nueva"); 
        // require(poiContract.userRegister(accountContract.ownerOf(_nftUse)),"Debe estar registrado"); 
       // require(accountContract.ownerOf(_nftUse) == msg.sender ,"Debe ser el dueno del NFT"); 
        
        uint256 currentTranche;
        if(tranches.length == 0){
            currentTranche = 0;
        }else{
            currentTranche = tranches.length - 1;
        }
        userStakeTimeInTranche[_nftUse][currentTranche] = block.timestamp;

        membershipContract.updateStake(_nftUse,_index,_amount);
        accountContract.updateStaked(_nftUse,_amount);
        userStakes[_nftUse] += _amount;
        TVL += _amount;
        if(membership.fee){
            
           // require(usdt.transferFrom(msg.sender, treasuryAddress, _amount), "USDT transfer failed");

            uint256 fee = (_amount * membership.amountFee) / 1000;

           // require(usdt.transferFrom(msg.sender, address(membershipContract), fee), "USDT transfer failed");
            membershipContract.payMembershipAdmin(_nftUse,fee);

        }else{
           // usdt.transferFrom(msg.sender, treasuryAddress, _amount);
        }
        stakes[msg.sender].push(Stake({
            amount: _amount,
            startTime: block.timestamp,
            idAccount: _nftUse,
            wallet: msg.sender
        }));
        
        totalStaked[msg.sender] += _amount;
        
        emit Staked(_nftUse, _amount, _index);
    }


    function stakeFromUser(uint128 _amount,uint256 _nftUse,uint256 _index) external {
        
        MembershipContract.InfoOfMembershipsBuy memory info = membershipContract.getInfoOfMembership(_nftUse, _index);
        MembershipContract.Membership memory membership = membershipContract.getMembership(info.memberId);

        stakingsPerTranches[_nftUse].push(infoTranches(
            _amount,
            block.timestamp
        ));

        userStakePerTranches[_nftUse][tranches.length - 1].push(stakeTrancheInformation(
            _amount,
            block.timestamp,
            false,
            _index
        ));

        uint256 totalStakedActualAddAmount = info.staked + _amount;
        require(_amount > 0, "Amount must be greater than 0");
        require(membershipContract.haveMembership(_nftUse), "Requiere una membresia");
        require(totalStakedActualAddAmount <= membership.maxInv, "El total stakeado + el total a stakear debe ser menor que el maximo stake de la persona"); 
        if(info.staked != 0){
            require(_amount >= minStake, "El total stakeado debe ser mayor al minimo luego de la primera inversion"); 
        }else{
            require(_amount >= membership.minInv, "El total stakeado debe ser mayor al minimo"); 
        }
        require(block.timestamp <= info.expire, "Expiro tu membresia, compra una nueva"); 
       // require(poiContract.userRegister(accountContract.ownerOf(_nftUse)),"Debe estar registrado"); 
       // require(accountContract.ownerOf(_nftUse) == msg.sender ,"Debe ser el dueno del NFT"); 
        
        uint256 currentTranche;
        if(tranches.length == 0){
            currentTranche = 0;
        }else{
            currentTranche = tranches.length - 1;
        }
        userStakeTimeInTranche[_nftUse][currentTranche] = block.timestamp;

        membershipContract.updateStake(_nftUse,_index,_amount);
        accountContract.updateStaked(_nftUse,_amount);
        userStakes[_nftUse] += _amount;
        TVL += _amount;
        if(membership.fee){
            
            require(usdt.transferFrom(msg.sender, treasuryAddress, _amount), "USDT transfer failed");

            uint256 fee = (_amount * membership.amountFee) / 1000;

            require(usdt.transferFrom(msg.sender, address(membershipContract), fee), "USDT transfer failed");
            membershipContract.payMembershipAdmin(_nftUse,fee);

        }else{
            usdt.transferFrom(msg.sender, treasuryAddress, _amount);
        }
        stakes[accountContract.ownerOf(_nftUse)].push(Stake({
            amount: _amount,
            startTime: block.timestamp,
            idAccount: _nftUse,
            wallet:accountContract.ownerOf(_nftUse)
        }));
        
        totalStaked[accountContract.ownerOf(_nftUse)] += _amount;
        
        emit Staked(_nftUse, _amount, _index);
    }

    //New Logic

    mapping(uint256 => uint256) public claimedPerAccount;
    uint256 public totalClaimed;

    mapping(uint256 => uint256) public totalPfPaiedPerAccount;


    struct infoDirectsPerTranches {
        uint256 time;
        uint256 nftId;
    }

    function directRewards(uint256 _nftId) public view returns (uint256) {
        uint256 directsLength = accountContract.getDirectsPerTranchesLength(_nftId);
        console.log("directsLength: ",directsLength);
        uint totalDirectRewards = 0;  

        for (uint256 i = 0; i < directsLength; i++) {
            uint256 directId = accountContract.getDirectsPerTranchesNftId(_nftId, i);
            totalDirectRewards += totalPfPaiedPerAccount[directId];
        }

        return totalDirectRewards;
    }

    function getTotalPF(uint256 _nftUse) view public returns(uint256){

        uint256 totalReward = 0;
        uint256 totalPf = 0;
        uint256 membershipsLength = membershipContract.getMembershipOfUsersLength(_nftUse);

        for (uint256 i = 0; i < membershipsLength; i++) {
            MembershipContract.InfoOfMembershipsBuy memory membershipInfo = membershipContract.getInfoOfMembership(_nftUse, i);
            MembershipContract.Membership memory membershipDetails = membershipContract.getMembership(membershipInfo.memberId);

            uint256 membershipStake = membershipInfo.staked - claimedStake[_nftUse][i];

            if (membershipStake == 0) continue;  
            uint256 userShare = (membershipStake * 1e6) / TVL;
            uint256 reward = (totalProfits * userShare) / 1e6;
            uint256 adjustedReward = (reward * (100 - membershipDetails.performanceFee)) / 100;
            totalReward += reward;
            totalPf += adjustedReward;
        }

       return totalReward - totalPf;
    }

    struct directRewardsInfo {
       uint256 pf;
       uint256 time;
    }

    mapping(uint256 => directRewardsInfo[]) public directRewardsPerTranches;

    function getDirectRewardsPerTranches(uint256 _nftId, uint256 _index) public view returns(directRewardsInfo memory){
      return  directRewardsPerTranches[_nftId][_index];
    }


    mapping(uint256 => uint256) public previousStakes;
    mapping(uint256 => bool) public previousStatus;

    function addPreviouslStake(uint256 _nftId, uint256 _amount) public onlyOwner {
        previousStakes[_nftId] = _amount;
        previousStatus[_nftId] = true;

    }

    function claimPreviousProfit(uint256 _nftUse) public {
        require(previousStatus[_nftUse], "You claim this profit");
        require(accountContract.ownerOf(_nftUse) == msg.sender, "Not the owner");

        uint256 totalPf = 0;
        uint256 sponsor;
        (, , , uint256 sponsorNFT, , , , , , , , , , , ,) = accountContract.accountInfo(_nftUse);
        sponsor =  sponsorNFT;   

        uint256 totalReward = 0;
    
      
            MembershipContract.InfoOfMembershipsBuy memory membershipInfo = membershipContract.getInfoOfMembership(_nftUse, 0);
            MembershipContract.Membership memory membershipDetails = membershipContract.getMembership(membershipInfo.memberId);
            
            uint256 performanceFee = (previousStakes[_nftUse] * membershipDetails.performanceFee) / 100;
            
            totalPf += performanceFee;

            pfPerTranches[_nftUse].push(infoTranches(
                performanceFee,
                block.timestamp
            ));
            
            totalPerformanceFeesPaid[_nftUse][0] += performanceFee;

            totalPfPaiedPerAccount[_nftUse] += performanceFee;

            uint256 adjustedReward = (previousStakes[_nftUse] * (100 - membershipDetails.performanceFee)) / 100;

            totalReward = adjustedReward;

            profitPerTranches[_nftUse].push(infoTranches(
                totalReward,
                block.timestamp
            ));

            claimedPerAccount[_nftUse] += totalReward;
            totalClaimed += totalReward;

        require(totalReward > 0, "No rewards available");
        require(usdt.transfer(msg.sender, totalReward), "USDT transfer failed");

        directRewardsPerTranches[sponsor].push(directRewardsInfo(
           (totalPf * 20)/100,
            block.timestamp
        ));

        previousStakes[_nftUse] = 0;
        previousStatus[_nftUse] = false;

    }

    mapping(uint256 => uint256) public profitInTranches;
    struct claimProfitHistory {
       uint256 amount;
       uint256 profit;
       uint256 performanceFee;
       uint256 time;

    } 
    mapping(uint256 => claimProfitHistory[]) public claimHistory;

    struct stakeTrancheInformation {
       uint256 amount;
       uint256 stratTime;
       bool profitPaid;
       uint256 membershipIndex;
    } 

    mapping(uint256 => mapping(uint256 => stakeTrancheInformation[])) public userStakePerTranches; //NFTID => TRANCHE => INFO


//     function claimProfitTime(uint256 _nftUse) public {
//         require(accountContract.ownerOf(_nftUse) == msg.sender ,"Not the owner");

//         uint256 totalReward = 0;

//         for (uint256 i = 0; i < tranches.length - 1; i++) { 
//             //Verificar si el tranche termino, si el tranche actual termino debe finalizar la busqueda
//             for (uint256 x = 0; x < userStakePerTranches[_nftUse][i].length; x++) {
//                 uint256 stakeDuration = 0;
//                 stakeTrancheInformation memory stakeInfo = userStakePerTranches[_nftUse][i][x];
//                 Tranche memory tranche = tranches[i];


//                 if (block.timestamp >= tranche.endTime) {
//                     stakeDuration = tranche.endTime - stakeInfo.stratTime; 
//                 } 

//                 uint256 trancheDuration = tranche.endTime - tranche.startTime;
//                 uint256 rewardShare = (stakeDuration * 1e18) / trancheDuration; // Proporción de tiempo en el tranche

//                 // Calcular recompensa proporcional
//                 uint256 trancheReward = (profitInTranches[i] * rewardShare) / 1e18;
//                 uint256 adjustedReward = (trancheReward * stakeInfo.amount) / tranche.balance; // Ajustar según el porcentaje de staking en TVL

//                 totalReward += adjustedReward;
//             }
//         }
//         require(usdt.transfer(msg.sender, totalReward), "USDT transfer failed");
// }

    address public pfWallet;
    function setPfWallet(address _address) public onlyOwner(){
        pfWallet = _address;
    }

    function claimProfitTime(uint256 _nftUse) public {
        require(accountContract.ownerOf(_nftUse) == msg.sender, "Not the owner");

        uint256 totalReward = 0;
        uint256 totalPerformanceFee = 0;

        // Iterar a través de los tranches, excepto el último
        console.log("tranches.length: ",tranches.length);
        for (uint256 i = 0; i < tranches.length - 1; i++) { 
            Tranche memory tranche = tranches[i];
    
            // Verificar si el tranche terminó
            if (block.timestamp < tranche.endTime) {
                continue; // Saltar a la siguiente iteración si el tranche no ha terminado
            }


            // Iterar sobre los stakes del usuario en el tranche actual
            for (uint256 x = 0; x < userStakePerTranches[_nftUse][i].length; x++) {
                stakeTrancheInformation memory stakeInfo = userStakePerTranches[_nftUse][i][x];

                if (stakeInfo.profitPaid) {
                    continue; // Saltar a la siguiente iteración si el profit de este stake ya fue pagado
                }
                // Calcular la duración del staking en este tranche
                uint256 stakeDuration = 0;
                if (block.timestamp >= tranche.endTime) {
                    stakeDuration = tranche.endTime - stakeInfo.stratTime; 
                }

                console.log("x: ",x);
                console.log("stakeDuration: ",stakeDuration);

                uint256 trancheDuration = tranche.endTime - tranche.startTime;
                uint256 rewardShare = (stakeDuration * 1e18) / trancheDuration; // Proporción de tiempo en el tranche

                // Calcular recompensa proporcional por el stake
                uint256 trancheReward = (profitInTranches[i] * rewardShare) / 1e18;
                uint256 adjustedReward = (trancheReward * stakeInfo.amount) / tranche.balance; // Ajustar según el porcentaje del TVL

                MembershipContract.InfoOfMembershipsBuy memory membershipInfo = membershipContract.getInfoOfMembership(_nftUse, i);
                MembershipContract.Membership memory membershipDetails = membershipContract.getMembership(membershipInfo.memberId);

                uint256 finalRewards = (adjustedReward * (100 - membershipDetails.performanceFee)) / 100;

                uint256 performanceFee = (adjustedReward * membershipDetails.performanceFee) / 100;
                pfPerTranches[_nftUse].push(infoTranches(
                    performanceFee,
                    block.timestamp
                ));
                
                totalPerformanceFeesPaid[_nftUse][i] += performanceFee;

                totalPfPaiedPerAccount[_nftUse] += performanceFee;


                claimedPerAccount[_nftUse] += totalReward;
                totalClaimed += totalReward;

                claimHistory[_nftUse].push(claimProfitHistory(
                    adjustedReward,
                    finalRewards,
                    performanceFee,
                    block.timestamp
                ));

                totalReward += finalRewards;
                totalPerformanceFee += performanceFee;
                stakeInfo.profitPaid = true;
            }

            // Si el tranche está completo, no se necesitan más iteraciones
            if (block.timestamp >= tranche.endTime) {
                break;
            }
        }

        // Asegurarse de que la recompensa no sea cero
        require(totalReward > 0, "No reward available");

        // Realizar la transferencia de USDT
        require(usdt.transfer(msg.sender, totalReward), "USDT transfer failed");
        require(usdt.transfer(pfWallet, totalPerformanceFee), "USDT transfer failed");

        emit RewardClaimed(_nftUse, totalReward);
    }

    function startTranche() public onlyOwner(){
        tranches.push(Tranche({
            balance: 0,
            startTime: block.timestamp,
            endTime: 0  
        }));
    }


    function getProfitForNFT(uint256 _nftUse) public view returns (uint256 totalReward, uint256 totalPerformanceFee) {

        for (uint256 i = 0; i < tranches.length - 1; i++) { 
            Tranche memory tranche = tranches[i];
        
            // Verificar si el tranche terminó
            if (block.timestamp < tranche.endTime) {
                continue; // Saltar a la siguiente iteración si el tranche no ha terminado
            }

            // Iterar sobre los stakes del usuario en el tranche actual
            for (uint256 x = 0; x < userStakePerTranches[_nftUse][i].length; x++) {
                stakeTrancheInformation memory stakeInfo = userStakePerTranches[_nftUse][i][x];

                if (stakeInfo.profitPaid) {
                    continue; // Saltar a la siguiente iteración si el profit de este stake ya fue pagado
                }

                uint256 stakeDuration = 0;
                if (block.timestamp >= tranche.endTime) {
                    stakeDuration = tranche.endTime - stakeInfo.stratTime; 
                }

                uint256 trancheDuration = tranche.endTime - tranche.startTime;
                uint256 rewardShare = (stakeDuration * 1e18) / trancheDuration; // Proporción de tiempo en el tranche

                // Calcular recompensa proporcional por el stake
                uint256 trancheReward = (profitInTranches[i] * rewardShare) / 1e18;
                uint256 adjustedReward = (trancheReward * stakeInfo.amount) / tranche.balance; // Ajustar según el porcentaje del TVL

                MembershipContract.InfoOfMembershipsBuy memory membershipInfo = membershipContract.getInfoOfMembership(_nftUse, i);
                MembershipContract.Membership memory membershipDetails = membershipContract.getMembership(membershipInfo.memberId);

                uint256 finalRewards = (adjustedReward * (100 - membershipDetails.performanceFee)) / 100;
                uint256 performanceFee = (adjustedReward * membershipDetails.performanceFee) / 100;

                totalReward += finalRewards;
                totalPerformanceFee += performanceFee;
            }
        }

        return (totalReward, totalPerformanceFee);
    }

  
}
pragma solidity ^0.4.25;

contract Endorsement {

    address private creator;                                                         // The creator of this contract
    bool public initialized;                                                        // Initialization state
    uint public lockTime;                                                            // Endorsement lock time
    mapping(uint => address[]) private locks;                                        // Endorsement lock collection storing SMNs in each endorsement period
    mapping(uint => mapping(address => bool)) keys;                                  // Endorsement key collection

    uint public endorsementReward;                                                   // Endorsement rewar
    mapping(uint => uint) public endorsementRewards;                                 // Endorsement reward collection
    uint public reserve;                                                             // Endorsement reward reserve
    uint public endorsementSMNSize;                                                  // Endorsement limit
    mapping(uint => mapping(address => bool)) public isAddeds;                       // Endorsed SMN collection
    mapping(uint => mapping(string => address[]))  endorsementSenders;               // Endorsement senders based on endorsement number and endorsement data
    mapping(uint => address[])  endorsementSendersAll;                               // Endorsement senders based on endorsement number
    mapping(uint => EndorsementData[])  endorsementDatas;                            // Endorsement datas
    mapping(address => uint) public totalRewardSMNs;                                 // Total reward for each SMN

    mapping(uint => mapping(string => uint))  hashEndorsementCounter;               // Endorsement count based on endorsement number and endorsement data
    mapping(uint => string) private mainEndorsements;                                      // Main endorsements
    mapping(uint => uint) private endorsementsIndexs;                               // Main endorsements index
    mapping(uint => bool) public isEndorsements;                                    // Endorsed collection
    mapping(uint => uint) public endorsementCounter;                                // Endorsement count per endorsement number
    uint public endorsementSize;                                                    // Capacity of an endorsement number
   
    address emptyAddress =address(0x0);                                             // Empty address
    address permissionContractAddress;                                              // WTC permission contract

    event Deposit(uint value);                                                      // Deposit event
    event RewardSMNs(address[] contributors);                                       // Endorsement reward event
    event AddEndorsement(uint endorsementNumber, string hashFingerprints);          // Endorsement event
    event Bonus(uint value);

    address public bonusPool;                                                       //reward pool address
    address[] private smnAddress;                                                   //smn reward arrays
    address[] private jmnAddress;                                                   //jmn reward arrays
    mapping(address=>uint256) private smnBonus;                                     //smn reward
    mapping(address=>uint256) private jmnBonus;                                     //jmn reward
    uint private allSMNBonus;                                                       //smn total reward

    modifier onlyOwner {
        require(msg.sender == creator);
        _;
    }
    
    modifier onlyInitialized {
        require(initialized);
        _;
    }
    

    struct EndorsementData {
        address sender;
        address worker;
        string hashFingerprints;
        uint blockNumber;
    }

    // Empty endorsement information structure
    EndorsementData emptyEndorsement = EndorsementData(emptyAddress, emptyAddress, "", 0);

    /**
    * Constructor
    * @param _creator Contract owner
    */
    constructor(address _creator) public {
        creator = _creator;
        lockTime=100;
        bonusPool=address(0x0);
    }

    /**
    * Initialization contract
    * @return bool Returns true on success and false on failure.
    */
    function init(address _permissionContractAddress, uint _endorsementReward, uint _endorsementSize, uint _endorsementSMNSize) public onlyOwner returns (bool) {
        require(!initialized);
        permissionContractAddress = _permissionContractAddress;
        endorsementReward = _endorsementReward;
        endorsementSize = _endorsementSize;
        endorsementSMNSize = _endorsementSMNSize;
        initialized = true;
        return true;
    }
    
  

    /**
    * add Endorsement
    * @param _endorsementNumber  Endorsement number
    * @param _hashFingerprints   Endorsement data
    * @return bool  Returns true on success and false on failure.
    */
    function addEndorsement(uint _endorsementNumber, string _hashFingerprints) public onlyInitialized returns (bool){

        address  smn = PermissionContract(permissionContractAddress).getSMNAddress(msg.sender);
        require(smn!=emptyAddress);

        //Endorsement conditions
        uint section = SafeMath.div(block.number, lockTime);
        require(keys[section][smn]);
        require(endorsementReward > 0);
        require(endorsementCounter[_endorsementNumber] < endorsementSMNSize);
        //if endorse record not exist
        if(endorsementCounter[_endorsementNumber]==0){
            require(address(this).balance > reserve + endorsementReward);
        }
        
        require(!isEndorsements[_endorsementNumber]);
        require(!isAddeds[_endorsementNumber][smn]);

        // Endorsement data
        EndorsementData memory endorsementCurrent;
        endorsementCurrent.sender = smn;
        endorsementCurrent.worker = msg.sender;
        endorsementCurrent.hashFingerprints = _hashFingerprints;
        endorsementCurrent.blockNumber = block.number;

        endorsementSenders[_endorsementNumber][_hashFingerprints].push(smn);
        endorsementSendersAll[_endorsementNumber].push(smn);
        endorsementDatas[_endorsementNumber].push(endorsementCurrent);

        isAddeds[_endorsementNumber][smn] = true;
        endorsementCounter[_endorsementNumber] = SafeMath.add(endorsementCounter[_endorsementNumber], 1);
        hashEndorsementCounter[_endorsementNumber][_hashFingerprints] = SafeMath.add(hashEndorsementCounter[_endorsementNumber][_hashFingerprints], 1);

        if (endorsementDatas[_endorsementNumber].length < 2) {
            mainEndorsements[_endorsementNumber] = _hashFingerprints;
            endorsementsIndexs[_endorsementNumber] = SafeMath.sub(endorsementDatas[_endorsementNumber].length, 1);
           
            if(endorsementCounter[_endorsementNumber]==1){
                // comfirm reward level with the frist endorsement.
                endorsementRewards[_endorsementNumber] = endorsementReward;
                reserve = SafeMath.add(reserve, endorsementReward);
            }
            

        } else {
            uint mainEndorsementCounter = hashEndorsementCounter[_endorsementNumber][mainEndorsements[_endorsementNumber]];

            if (hashEndorsementCounter[_endorsementNumber][_hashFingerprints] > mainEndorsementCounter) {
                mainEndorsements[_endorsementNumber] = _hashFingerprints;
                endorsementsIndexs[_endorsementNumber] = SafeMath.sub(endorsementDatas[_endorsementNumber].length, 1);
            }
        }

        //Determine whether to reward
        if (endorsementCounter[_endorsementNumber] >= endorsementSMNSize) {
            rewardSMNs(endorsementSenders[_endorsementNumber][mainEndorsements[_endorsementNumber]], endorsementRewards[_endorsementNumber], _endorsementNumber);
            bonus(endorsementRewards[_endorsementNumber]); 
            isEndorsements[_endorsementNumber] = true;
        }

        emit AddEndorsement(_endorsementNumber, _hashFingerprints);
        return true;
    }
     
    //set endorsementReward
    function setEndorsementReward(uint _endorsementReward) public onlyOwner onlyInitialized returns (bool){
        endorsementReward = _endorsementReward;
        return true;
    }
    
    /**
    * Get endorsement rights
    * @return bool  Returns true on success and false on failure.
    */
    function setLock() public returns (bool) {
        address  smnCurrent = PermissionContract(permissionContractAddress).getSMNAddress(msg.sender);
        if (smnCurrent==emptyAddress) {
            return false;
        }

        uint section = SafeMath.div(block.number, lockTime);
        if (locks[section].length == endorsementSMNSize) {
            return keys[section][smnCurrent];
        }

        if (locks[section].length < endorsementSMNSize) {
            locks[section].push(smnCurrent);
            keys[section][smnCurrent] = true;
        }

        return keys[section][smnCurrent];
    }

    /**
    * Verify Endorsement permissions
    * @return bool true or false
    */
    function checkLock() public view returns (bool) {
        address  smnCurrent = PermissionContract(permissionContractAddress).getSMNAddress(msg.sender);
        if (smnCurrent==emptyAddress) {
            return false;
        }

        uint section = SafeMath.div(block.number, lockTime);
        return keys[section][smnCurrent];

    }
    
   
    /**
    * Pay for SMNs
    * @param _endorsers  Reward SMN addresses
    * @param _rewardPerRecord     Total reward
    * @param _endorsementNumber    Endorsement number
    */
    function rewardSMNs(address[] _endorsers, uint _rewardPerRecord, uint _endorsementNumber)  private {
        require(!isEndorsements[_endorsementNumber]);
        require(address(this).balance >= _rewardPerRecord);
        require(_endorsers.length <= endorsementSMNSize);
        

       uint rewardPer = SafeMath.div(_rewardPerRecord, _endorsers.length);
       uint rewardPerSMN;
       
       uint index;
       address introducerAddress;
         // record reward for each smn
        for (uint8 SMNIndex = 0; SMNIndex < _endorsers.length; SMNIndex++) {
            (index,introducerAddress)=PermissionContract(permissionContractAddress).smns(_endorsers[SMNIndex]);
            if(introducerAddress==emptyAddress){
               //smn 1 grade
             rewardPerSMN=SafeMath.mul(rewardPer,70)/100;
             _endorsers[SMNIndex].transfer(rewardPerSMN);
             //Record total rewards for SMN
             totalRewardSMNs[_endorsers[SMNIndex]] = SafeMath.add(totalRewardSMNs[_endorsers[SMNIndex]], rewardPerSMN);
            }else{
                 //smn 2 grade
                rewardPerSMN=SafeMath.mul(rewardPer,65)/100;
                introducerAddress.transfer(SafeMath.mul(rewardPer,5)/100);
                _endorsers[SMNIndex].transfer(rewardPerSMN);
                //Record total rewards for SMN
             totalRewardSMNs[_endorsers[SMNIndex]] = SafeMath.add(totalRewardSMNs[_endorsers[SMNIndex]], rewardPerSMN);
             totalRewardSMNs[introducerAddress] = SafeMath.add(totalRewardSMNs[introducerAddress], SafeMath.mul(rewardPer,5)/100);
                
            }
        }
        // reward pool
        bonusPool.transfer(SafeMath.mul(_rewardPerRecord,10)/100);
        totalRewardSMNs[bonusPool] = SafeMath.add(totalRewardSMNs[bonusPool], SafeMath.mul(_rewardPerRecord,10)/100);
       
        reserve = SafeMath.sub(reserve,SafeMath.mul( _rewardPerRecord,80)/100);
        emit RewardSMNs(_endorsers);
    }
    

    function bonus(uint _rewardPerRecord)  private{
        uint rewardAllSMN=SafeMath.mul(_rewardPerRecord,10)/100;
        uint rewardAllJMN=SafeMath.mul(_rewardPerRecord,10)/100;
        allSMNBonus=SafeMath.add(allSMNBonus,rewardAllSMN);
        //  Record reward for smn
        uint256 smnCount=PermissionContract(permissionContractAddress).smnCount();
        address smnAddr;
        if(smnCount>1){
          uint smnEachReward=SafeMath.div(rewardAllSMN,SafeMath.sub(smnCount,1));
          if(smnEachReward!=0){
            for (uint256 SMNLUTIndex = 1; SMNLUTIndex < smnCount; SMNLUTIndex++) {
             smnAddr=PermissionContract(permissionContractAddress).smnLUT(SMNLUTIndex);
              if(smnBonus[smnAddr]==0){
                smnAddress.push(smnAddr);
              }
             smnBonus[smnAddr]=SafeMath.add(smnBonus[smnAddr],smnEachReward);
            }
          }
        }
        //  Record reward for jmn
        uint256 jmnCount=PermissionContract(permissionContractAddress).jmnCount();
        address jmnAddr;
        if(jmnCount>1){
             uint jmnEachReward=SafeMath.div(rewardAllJMN,SafeMath.sub(jmnCount,1));
          if(jmnEachReward!=0){
            for (uint256 JMNLUTIndex = 1; JMNLUTIndex < jmnCount; JMNLUTIndex++) {
              jmnAddr=PermissionContract(permissionContractAddress).jmnLUT(JMNLUTIndex);
              if(jmnBonus[jmnAddr]==0){
                jmnAddress.push(jmnAddr);
              }
              jmnBonus[jmnAddr]=SafeMath.add(jmnBonus[jmnAddr],jmnEachReward);
            }
          }
        }
       
        //Settlement
        if(allSMNBonus>=50 ether){
            for(uint256 bonusSmnaddress = 0; bonusSmnaddress < smnAddress.length; bonusSmnaddress++){
              smnAddress[bonusSmnaddress].transfer(smnBonus[smnAddress[bonusSmnaddress]]);
              //Record total rewards for SMN
              totalRewardSMNs[smnAddress[bonusSmnaddress]] = SafeMath.add(totalRewardSMNs[smnAddress[bonusSmnaddress]], smnBonus[smnAddress[bonusSmnaddress]]);
              delete smnBonus[smnAddress[bonusSmnaddress]];
            }
            for(uint256 bonusJmnaddress = 0; bonusJmnaddress < jmnAddress.length; bonusJmnaddress++){
              jmnAddress[bonusJmnaddress].transfer(jmnBonus[jmnAddress[bonusJmnaddress]]);
              //Record total rewards for SMN
              totalRewardSMNs[jmnAddress[bonusJmnaddress]] = SafeMath.add(totalRewardSMNs[jmnAddress[bonusJmnaddress]], jmnBonus[jmnAddress[bonusJmnaddress]]);
              delete jmnBonus[jmnAddress[bonusJmnaddress]];
            }
            // clear arrays
            delete jmnAddress;
            jmnAddress.length=0;
            delete smnAddress;
            smnAddress.length=0;
            uint a=SafeMath.mul(allSMNBonus,2);
            reserve = SafeMath.sub(reserve,a);
            allSMNBonus=0;
        }
       emit Bonus(_rewardPerRecord);
    }

    /**
    * get Endorsement
    * @param _endorsementNumber    Endorsement number
    * @return mainEndorsement data
    */
    function getEndorsement(uint _endorsementNumber) public view returns (address sender, address worker, string hashFingerprints, uint blockNumber){

        if (!isEndorsements[_endorsementNumber]) {
            return (emptyEndorsement.sender, emptyEndorsement.worker, emptyEndorsement.hashFingerprints, emptyEndorsement.blockNumber);
        }
        EndorsementData[] memory endorsementAraayCurrent = endorsementDatas[_endorsementNumber];
        //Get the index of the endorsement data to be rewarded.
        uint endorsementsIndex = endorsementsIndexs[_endorsementNumber];
        EndorsementData memory endorsementCurrent = endorsementAraayCurrent[endorsementsIndex];
        string memory hashFingerprintsCurrent = endorsementCurrent.hashFingerprints;
        return (endorsementCurrent.sender, endorsementCurrent.worker, hashFingerprintsCurrent, endorsementCurrent.blockNumber);

    }

    /**
    * get Endorsement By Index
    * @param _endorsementNumber   Endorsement number
    * @param _index   Endorsement index
    * @return  Endorsement data
    */
    function getEndorsementByIndex(uint _endorsementNumber, uint _index) public view returns (address sender, address worker, string hashFingerprints, uint blockNumber){
        EndorsementData[] memory endorsementAraayCurrent = endorsementDatas[_endorsementNumber];
        EndorsementData memory endorsementCurrent = endorsementAraayCurrent[_index];
        string memory hashFingerprintsCurrent = endorsementCurrent.hashFingerprints;
        return (endorsementCurrent.sender, endorsementCurrent.worker, hashFingerprintsCurrent, endorsementCurrent.blockNumber);

    }

    /**
    * get Endorsement Senders
    * @param _endorsementNumber   Endorsement number
    * @return  address[]      Endorsement  Senders
    */
    function getEndorsementSendersAll(uint _endorsementNumber) public view returns (address[]){
        return endorsementSendersAll[_endorsementNumber];
    }

    function getlocks(uint _section) public view returns (address[]){
        return locks[_section];
    }

    /**
    * According to the Endorsement number and endorsement data , to get the endorsement senders.
    * @param _endorsementNumber   Endorsement number
    * @param _hash  Endorsement data
    * @return  address[]   Endorsement  Senders
    */
    function getEndorsementSenders(uint _endorsementNumber, string _hash) public view returns (address[]){
        return endorsementSenders[_endorsementNumber][_hash];
    }

    /**
   * According to the Endorsement number and endorsement data , to get the endorsement count.
   * @param _endorsementNumber   Endorsement number
   * @param _hash  Endorsement data
   * @return  uint   Endorsement count
   */
    function getHashEndorsementCounter(uint _endorsementNumber, string _hash) public view returns (uint){
        return hashEndorsementCounter[_endorsementNumber][_hash];
    }

    /**
    * Contract deposit
    * @return  bool  Returns true on success and false on failure.
    */
    function deposit() payable public returns (bool){
        emit Deposit(msg.value);
        return true;
    }

    /**
    * View contract balance
    * @return  uint Contract balance
    */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
function () payable public{

    }

  
}



/**
 * SafeMath
 */
library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);
        return c;
    }

    function mod(uint256 a, uint256 b) external pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
    
   
}
/**
 *  WTC permissionContract interface
 */
contract PermissionContract {
    function smnLUT(uint256) public view returns (address);
    function jmnLUT(uint256) public view returns (address);
    function smns(address) public view returns (uint,address);   
    function jmns(address) public view returns (uint);
    function jmnCount() public view returns (uint256);
    function smnCount() public view returns (uint256);
    function getSMNAddress(address workerAddress) public view returns (address);
    

}
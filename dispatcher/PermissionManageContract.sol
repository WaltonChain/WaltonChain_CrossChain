pragma solidity ^0.5.0;

interface IBallot {
    function addJMNProposal(address, string calldata, address, bytes calldata) external;
    function addSMNProposal(address, string calldata, address, bytes calldata, bool) external;
    function commonProposalMapping(address) external view returns(uint);
}

contract PermissionManager {
    
    address public owner;
    
    struct SMN {
        uint index;
        address introducerAddress;
    }
    
    mapping(address => uint) public jmns;
    address[] public jmnLUT;
    mapping(address => SMN) public smns;
    address[] public smnLUT;
    
    struct Worker {
        uint index;
        address smnAddress;
    }
    
    mapping(address => Worker) public workers;
    mapping(address => address[]) public workerLUT;      // SMN address => WORKER address array
    
    modifier JMNProposal(string memory featureName) {
        if (msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0) {
            _;
        } else {
            IBallot(owner).addJMNProposal(msg.sender, featureName, address(this), msg.data);
        }
    }
    
    modifier SMNProposal(string memory featureName, bool hasJudge) {
        if (msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0) {
            _;
        } else {
            IBallot(owner).addSMNProposal(msg.sender, featureName, address(this), msg.data, hasJudge);
        }
    }
    
    modifier OnlyJMN {
        require(msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0 || jmns[msg.sender] > 0, "OnlyJMN");
        _;
    }
    
    modifier OnlyPermission {
        require(msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0 || jmns[msg.sender] > 0 || smns[msg.sender].index > 0, "OnlyPermission");
        _;
    }
    
    modifier OnlySender(address userAddress) {
        require(msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0 || msg.sender == userAddress, "OnlySender");
        _;
    }
    
    constructor(address _owner) public {
        owner = _owner;
        jmnLUT.push(address(0x0));
        smnLUT.push(address(0x0));
        
        jmnLUT.push(msg.sender);
        jmns[msg.sender] = jmnLUT.length - 1;
    }
    
    function addJMN(address userAddress) public OnlyJMN JMNProposal('addJMN') {
        require(jmns[userAddress] == 0);
        jmnLUT.push(userAddress);
        jmns[userAddress] = jmnLUT.length - 1;
    }
    function addSMN(address userAddress, address introducerAddress) public OnlyPermission OnlySender(introducerAddress) SMNProposal('addSMN', true) {
        require(smns[userAddress].index == 0);
        if (jmns[introducerAddress] > 0) {
            introducerAddress = address(0x0);
        }
        smnLUT.push(userAddress);
        smns[userAddress] = SMN(smnLUT.length - 1, introducerAddress);
    }
    
    function jmnCount() public view returns(uint) {
        return jmnLUT.length;
    }
    
    function smnCount() public view returns(uint) {
        return smnLUT.length;
    }
    
    function deleteJMN(address jmnAddress) public OnlyJMN JMNProposal('deleteJMN') {
        uint index = jmns[jmnAddress];
        require(index > 0 && jmnLUT.length > 2);
        jmns[jmnLUT[jmnLUT.length - 1]] = index;
        jmns[jmnAddress] = 0;
        jmnLUT[index] = jmnLUT[jmnLUT.length - 1];
        delete jmnLUT[jmnLUT.length - 1];
        jmnLUT.length--;
    }
    
    function deleteSMN(address smnAddress) public OnlyPermission SMNProposal('deleteSMN', true) {
        uint index = smns[smnAddress].index;
        require(index > 0);
        smns[smnLUT[smnLUT.length - 1]].index = index;
        delete smns[smnAddress];
        smnLUT[index] = smnLUT[smnLUT.length - 1];
        delete smnLUT[smnLUT.length - 1];
        smnLUT.length--;
        
        for (uint i = 0; i < workerLUT[smnAddress].length; i++) {
            delete workers[workerLUT[smnAddress][i]];
        }
        delete workerLUT[smnAddress];
    }
    
    function addWorker(address smnAddress) public {
        address workerAddress = msg.sender;
        require(workers[workerAddress].smnAddress == address(0x0) && smns[smnAddress].index > 0);
        workerLUT[smnAddress].push(workerAddress);
        workers[workerAddress] = Worker(workerLUT[smnAddress].length - 1, smnAddress);
    }
    
    function deleteWorker() public {
        uint index = workers[msg.sender].index;
        address smnAddress = workers[msg.sender].smnAddress;
        require(smnAddress != address(0x0));
        workers[workerLUT[smnAddress][workerLUT[smnAddress].length - 1]].index = index;
        delete workers[msg.sender];
        workerLUT[smnAddress][index] = workerLUT[smnAddress][workerLUT[smnAddress].length - 1];
        delete workerLUT[smnAddress][workerLUT[smnAddress].length - 1];
        workerLUT[smnAddress].length--;
    }
    
    function workerSize(address smnAddress) public view returns(uint) {
        return workerLUT[smnAddress].length;
    }
    
    function getSMNAddress(address workerAddress) public view returns(address) {
        return workers[workerAddress].smnAddress;
    }
}
pragma solidity ^0.5.0;

interface IBallot {
    function addSMNProposal(address, string calldata, address, bytes calldata, bool) external;
    function commonProposalMapping(address) external view returns(uint);
    function permissionManagerAddress() external view returns(address);
    function templateManagerAddress() external view returns(address);
}

interface IPermissionManager {
    function smns(address) external view returns(uint, address);
}

interface ITemplateManager {
    function getContractTemplate(bytes32) external view returns(bytes32, string memory, string memory, bytes memory, string memory, string memory, bool);
    function deployContract(bytes32, address) external returns(address);
}

contract SubchainManager {
    
    struct Subchain {
        bytes32 genesisHash;
        string name;
        string chainType;
        string subchainNodeIP;
        uint subchainNodePort;
    }
    
    struct Endorsement {
        string name;
        address owner;
        address endorsementContractAddress;
        string endorsementContractAbi;
        address businessContractAddress;
        string businessContractAbi;
    }
    
    modifier SMNProposal(string memory featureName, bool hasJudge) {
        if (msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0) {
            _;
        } else {
            IBallot(owner).addSMNProposal(msg.sender, featureName, address(this), msg.data, hasJudge);
        }
    }
    
    modifier OnlySMN() {
        (uint index, ) = IPermissionManager(IBallot(owner).permissionManagerAddress()).smns(msg.sender);
        require(msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0 || index > 0, "OnlySMN");
        _;
    }
    
    modifier OnlySender(address smnAddress, bytes32 subchainGenesisHash) {
        require(msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0 || smnAttentionIndexMapping[smnAddress][subchainGenesisHash] > 0, "OnlySender");
        _;
    }
    
    Subchain internal emptySubchain = Subchain("", "", "", "", 0);
    Endorsement internal emptyEndorsement = Endorsement("", address(0x0), address(0x0), "", address(0x0), "");
    
    address public owner;
    
    // genesisHash => index
    mapping(bytes32 => uint) public subchainMapping;
    Subchain[] public subchains;
    
    mapping(bytes32 => address[]) public subchainEndorsementsMapping;           // genesisHash => endorsement address array
    mapping(address => Endorsement) public endorsements;                        // endorsement address => endorsement
    
    mapping(address => bytes32[]) public smnAttentions;                                 // smn address => subchain genesisHash array
    mapping(address => mapping(bytes32 => uint)) public smnAttentionIndexMapping;       // smn address => subchain genesisHash => smnAttention index
    
    constructor(address _owner) public {
        owner = _owner;
        subchains.push(emptySubchain);
    }
    
    function addSubchain(bytes32 genesisHash, string memory name, string memory chainType, string memory subchainNodeIP, uint subchainNodePort) public OnlySMN SMNProposal('addSubchain', false) {
        require(subchainMapping[genesisHash] == 0);
        Subchain memory subchain = Subchain(genesisHash, name, chainType, subchainNodeIP, subchainNodePort);
        uint index = subchains.length;
        subchains.push(subchain);
        subchainMapping[genesisHash] = index;
    }
    
    function addEndorsement(bytes32 genesisHash, string memory name, bytes32 templateHash, address endorsementOwner, address businessContractAddress, string memory businessContractAbi) public OnlySMN SMNProposal('addEndorsement', false) {
        uint subchainIndex = subchainMapping[genesisHash];
        require(subchainIndex > 0);
        string memory endorsementContractAbi;
        (, , , , endorsementContractAbi, , ) = ITemplateManager(IBallot(owner).templateManagerAddress()).getContractTemplate(templateHash);
        address endorsementContractAddress = ITemplateManager(IBallot(owner).templateManagerAddress()).deployContract(templateHash, endorsementOwner);
        Endorsement memory endorsement = Endorsement(name, endorsementOwner, endorsementContractAddress, endorsementContractAbi, businessContractAddress, businessContractAbi);
        endorsements[endorsementContractAddress] = endorsement;
        subchainEndorsementsMapping[genesisHash].push(endorsementContractAddress);
    }
    
    function getSubchain(bytes32 _genesisHash) public view returns(bytes32 genesisHash, string memory name, string memory chainType, string memory subchainNodeIP, uint subchainNodePort) {
        Subchain memory subchain = subchains[subchainMapping[_genesisHash]];
        return subchain2Values(subchain);
    }

    function getEndorsement(address endorsementAddress) public view returns(string memory name, address endorsementOwner, address endorsementContractAddress, string memory endorsementContractAbi, address businessContractAddress, string memory businessContractAbi) {
        Endorsement memory endorsement = endorsements[endorsementAddress];
        return endorsement2Values(endorsement);
    }
    
    function subchain2Values(Subchain memory subchain) internal pure returns(bytes32 genesisHash, string memory name, string memory chainType, string memory subchainNodeIP, uint subchainNodePort) {
        return (subchain.genesisHash, subchain.name, subchain.chainType, subchain.subchainNodeIP, subchain.subchainNodePort);
    }
    
    function endorsement2Values(Endorsement memory endorsement) internal pure returns(string memory name, address endorsementOwner, address endorsementContractAddress, string memory endorsementContractAbi, address businessContractAddress, string memory businessContractAbi) {
        return (endorsement.name, endorsement.owner, endorsement.endorsementContractAddress, endorsement.endorsementContractAbi, endorsement.businessContractAddress, endorsement.businessContractAbi);
    }
    
    function subchainSize() public view returns(uint) {
        return subchains.length;
    }
    
    function endorsementSize(bytes32 genesisHash) public view returns(uint) {
        return subchainEndorsementsMapping[genesisHash].length;
    }
    
    function addSMNAttention(address smnAddress, bytes32 subchainGenesisHash) public OnlySMN {
        if (smnAttentions[smnAddress].length == 0) {
            smnAttentions[smnAddress].push(bytes32(0x0));
        }
        smnAttentions[smnAddress].push(subchainGenesisHash);
        smnAttentionIndexMapping[smnAddress][subchainGenesisHash] = smnAttentions[smnAddress].length - 1;
    }
    
    function smnAttentionSize(address smnAddress) public view returns(uint) {
        return smnAttentions[smnAddress].length;
    }
    
    function deleteSMNAttention(address smnAddress, bytes32 subchainGenesisHash) public OnlySender(smnAddress, subchainGenesisHash) {
        uint attentionIndex = smnAttentionIndexMapping[smnAddress][subchainGenesisHash];
        smnAttentionIndexMapping[smnAddress][smnAttentions[smnAddress][smnAttentions[smnAddress].length - 1]] = attentionIndex;
        delete smnAttentionIndexMapping[smnAddress][subchainGenesisHash];
        smnAttentions[smnAddress][attentionIndex] = smnAttentions[smnAddress][smnAttentions[smnAddress].length - 1];
        delete smnAttentions[smnAddress][smnAttentions[smnAddress].length - 1];
        smnAttentions[smnAddress].length--;
    }
}
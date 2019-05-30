pragma solidity ^0.5.0;

interface IBallot {
    function addSMNProposal(address, string calldata, address, bytes calldata, bool) external;
    function commonProposalMapping(address) external view returns(uint);
    function permissionManagerAddress() external view returns(address);
    function subchainManagerAddress() external view returns(address);
}

interface IPermissionManager {
    function smns(address) external view returns(uint, address);
    function jmns(address) external view returns(uint);
}

contract TemplateManager {
    
    struct ContractTemplate {
        bytes32 hash;
        string name;
        string description;
        bytes bytecode;
        string abi;
        string version;
        bool hasBusinessContract;
    }
    
    ContractTemplate internal emptyContractTemplate = ContractTemplate("", "", "", "", "", "", false);
    
    address public owner;

    // hash => index
    mapping(bytes32 => uint) public contractTemplateMapping;
    ContractTemplate[] public contractTemplates;
    
    event deployContractEvent(uint indexed index, address indexed contractAddress);
    
    modifier SMNProposal(string memory featureName, bool hasJudge) {
        if (msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0) {
            _;
        } else {
            IBallot(owner).addSMNProposal(msg.sender, featureName, address(this), msg.data, hasJudge);
        }
    }
    
    modifier OnlyPermission {
        IPermissionManager permissionManager = IPermissionManager(IBallot(owner).permissionManagerAddress());
        uint jmnIndex = permissionManager.jmns(msg.sender);
        (uint smnIndex, ) = permissionManager.smns(msg.sender);
        require(msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0 || jmnIndex > 0 || smnIndex > 0, "OnlyPermission");
        _;
    }
    
    modifier OnlySubchainManager() {
        require(msg.sender == owner || IBallot(owner).commonProposalMapping(msg.sender) > 0 || IBallot(owner).subchainManagerAddress() == msg.sender, "OnlySubContract");
        _;
    }
    
    constructor(address _owner) public {
        owner = _owner;
        contractTemplates.push(emptyContractTemplate);
    }
    
    function addContractTemplate(
        bytes32 _hash,
        string memory _name,
        string memory _description,
        bytes memory _bytecode,
        string memory _abi,
        string memory _version,
        bool _hasBusinessContract
        ) public OnlyPermission SMNProposal('addContractTemplate', true) {
        require(contractTemplateMapping[_hash] == 0);
        ContractTemplate memory contractTemplate = ContractTemplate(_hash, _name, _description, _bytecode, _abi, _version, _hasBusinessContract);
        contractTemplates.push(contractTemplate);
        contractTemplateMapping[_hash] = contractTemplates.length - 1;
    }
    
    function getContractTemplate(bytes32 hash) public view returns(bytes32 _hash, string memory _name, string memory _description, bytes memory _bytecode, string memory _abi, string memory _version, bool _hasBusinessContract) {
        ContractTemplate memory contractTemplate = contractTemplates[contractTemplateMapping[hash]];
        return contractTemplate2Values(contractTemplate);
    }
    
    function contractTemplate2Values(ContractTemplate memory contractTemplate) internal pure returns(bytes32 _hash, string memory _name, string memory _description, bytes memory _bytecode, string memory _abi, string memory _version, bool _hasBusinessContract) {
        return (contractTemplate.hash, contractTemplate.name, contractTemplate.description, contractTemplate.bytecode, contractTemplate.abi, contractTemplate.version, contractTemplate.hasBusinessContract);
    }
    
    function contractTemplateSize() public view returns(uint) {
        return contractTemplates.length;
    }
    
    function deployContract(bytes32 hash, address _owner) public OnlySubchainManager returns(address) {
        uint index = contractTemplateMapping[hash];
        require(index > 0);
        bytes memory bytecode = contractTemplates[index].bytecode;
        bytes memory bytecodeWithAddress = splice(bytecode, _owner);
        address deployContractAddress;
        assembly {
            deployContractAddress := create(0, add(bytecodeWithAddress, 0x20), mload(bytecodeWithAddress))
        }
        emit deployContractEvent(index, deployContractAddress);
        return deployContractAddress;
    }

    function splice(bytes memory rawBytecode, address _address) internal pure returns(bytes memory) {
        bytes memory bytecode = new bytes(rawBytecode.length + 32);
        bytes memory addressBytes = toBytes(_address);
        for (uint i = 0; i < rawBytecode.length; i++) {
            bytecode[i] = rawBytecode[i];
        }
        for (uint i = 0; i < addressBytes.length; i++) {
            bytecode[rawBytecode.length + 12 + i] = addressBytes[i];
        }
        return bytecode;
    }
    
    function toBytes(address _address) internal pure returns(bytes memory _bytes) {
        assembly {
            let m := mload(0x40)
            mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, _address))
            mstore(0x40, add(m, 52))
            _bytes := m
        }
    }
}

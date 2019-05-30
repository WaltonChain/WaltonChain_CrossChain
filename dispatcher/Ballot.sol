pragma solidity ^0.5.0;

interface IPermissionManager {
    function jmns(address) external view returns(uint);
    function jmnLUT(uint) external view returns(address);
    function jmnCount() external view returns(uint);
    function smns(address) external view returns(uint, address);
    function smnLUT(uint) external view returns(address);
    function smnCount() external view returns(uint);
}

contract Vote {
    
    struct Voter {
        uint index;
        uint weight;
        address delegate;
        bool voted;
        bool vote;
    }
    
    address public owner;
    
    bool public isFinish;
    bool public isPass;
    uint public passThreshold;
    uint public vetoThreshold;
    uint public passCount;
    uint public vetoCount;
    mapping(address => Voter) public voters;
    address[] public voterLUT;
    
    modifier OnlyOwner() {
        require(!isFinish, "vote is finished");
        require(msg.sender == owner, "sender must be owner");
        _;
    }
    
    modifier OnlyVoter(address voterAddress) {
        require(!isFinish, "vote is finished");
        Voter memory voter = voters[voterAddress];
        require(voter.weight > 0 && !voter.voted, "not a voter or is voted");
        _;
    }
    
    constructor(address _owner, address[] memory _voters, uint _passThreshold, uint _vetoThreshold) public {
        owner = _owner;
        isFinish = false;
        isPass = false;
        passThreshold = _passThreshold;
        vetoThreshold = _vetoThreshold;
        passCount = 0;
        vetoCount = 0;
        for (uint i = 0; i < _voters.length; i++) {
            voterLUT.push(_voters[i]);
            voters[_voters[i]] = Voter(voterLUT.length - 1, 1, address(0x0), false, false);
        }
    }
    
    function voterCount() view public returns(uint) {
        return voterLUT.length;
    }
    
    function vote(address voterAddress, bool _decision) public OnlyOwner OnlyVoter(voterAddress) {
        Voter storage voter = voters[voterAddress];
        if (_decision) {
            passCount += voter.weight;
        } else {
            vetoCount += voter.weight;
        }
        voter.vote = _decision;
        voter.voted = true;
        
        if (passCount >= passThreshold) {
            isPass = true;
            isFinish = true;
        } else if (vetoCount >= vetoThreshold) {
            isPass = false;
            isFinish = true;
        }
    }
    
    function delegate(address voterAddress, address _delegateAddress) public OnlyOwner OnlyVoter(voterAddress) {
        Voter storage voter = voters[voterAddress];
        Voter storage delegateVoter = voters[_delegateAddress];
        require(delegateVoter.weight > 0);
        
        address delegateAddress = _delegateAddress;
        while (delegateAddress != address(0x0)) {
            delegateAddress = delegateVoter.delegate;
            delegateVoter = voters[delegateAddress];
        }
        
        delegateVoter.weight += voter.weight;
        voter.delegate = delegateAddress;
        voter.voted = true;
        if (delegateVoter.voted) {
            if (delegateVoter.vote) {
                passCount += voter.weight;
            } else {
                vetoCount += voter.weight;
            }
            if (passCount >= passThreshold) {
                isPass = true;
                isFinish = true;
            } else if (vetoCount >= vetoThreshold) {
                isPass = false;
                isFinish = true;
            }
        }
    }
}

contract Proposal {
    enum Stage {VOTE, JUDGMENT, PASS, VETO}
    
    address public sender;
    string public feature;
    
    Stage public stage;
    Vote public vote;
    Vote public judgment;
    uint public createTime;
    
    modifier OnlyVote() {
        require(stage == Stage.VOTE, "stage is VOTE");
        _;
    }
    
    modifier OnlyJudgment() {
        require(stage == Stage.JUDGMENT, "stage is JUDGMENT");
        _;
    }
    
    function judgeVoterThreshold(uint _totalCount) internal pure returns(uint _passThreshold, uint _vetoThreshold) {
        assert(_totalCount > 0);
        _passThreshold = _totalCount / 2 + 1;
        _vetoThreshold = _totalCount - _passThreshold + 1;
    }
    
    function judgeJudgmentThreshold(uint _totalCount) internal pure returns(uint _passThreshold, uint _vetoThreshold) {
        assert(_totalCount > 0);
        return (1, 1);
    }
    
    constructor(address _sender, string memory _feature, address[] memory _voters, address[] memory _judgments) internal {
        sender = _sender;
        feature = _feature;
        if (_voters.length > 0) {
            (uint passThreshold, uint vetoThreshold) = judgeVoterThreshold(_voters.length);
            vote = new Vote(address(this), _voters, passThreshold, vetoThreshold);
        }
        if (_judgments.length > 0) {
            (uint judgmentPassThreshold, uint judgmentVetoThreshold) = judgeJudgmentThreshold(_judgments.length);
            judgment = new Vote(address(this), _judgments, judgmentPassThreshold, judgmentVetoThreshold);
        }
        stage = Stage.VOTE;
        if (address(vote) == address(0x0)) {
            stage = Stage.JUDGMENT;
            if (address(judgment) == address(0x0)) {
                stage = Stage.PASS;
            }
        }
        createTime = now;
    }
    
    function toStageJudgment() internal {
        if (address(judgment) == address(0x0) || judgment.isFinish()) {
            toStagePass();
        }
    }
    
    function toStagePass() internal {
        stage = Stage.PASS;
        action();
    }
    
    function updateStageVote() internal {
        if (vote.isFinish()) {
            if (vote.isPass()) {
                stage = Stage.JUDGMENT;
                toStageJudgment();
            } else {
                stage = Stage.VETO;
            }
        }
    }
    
    function updateStageJudgment() internal {
        if (judgment.isFinish()) {
            if (judgment.isPass()) {
                toStagePass();
            } else {
                stage = Stage.VETO;
            }
        }
    }
    
    function voterVote(bool _decision) public OnlyVote {
        vote.vote(msg.sender, _decision);
        updateStageVote();
    }
    
    function voterDelegate(address _delegateAddress) public OnlyVote {
        vote.delegate(msg.sender, _delegateAddress);
        updateStageVote();
    }
    
    function judgmentVote(bool _decision) public OnlyJudgment {
        judgment.vote(msg.sender, _decision);
        updateStageJudgment();
    }
    
    function judgmentDelegate(address _delegateAddress) public OnlyJudgment {
        judgment.delegate(msg.sender, _delegateAddress);
        updateStageJudgment();
    }
    
    function action() internal;
}

contract CommonProposal is Proposal {
    address public calledContract;
    bytes public payload;
    
    constructor(address sender, string memory feature, address _calledContract, bytes memory _payload, address[] memory _voters, address[] memory _judgments) public Proposal(sender, feature, _voters, _judgments) {
        calledContract = _calledContract;
        payload = _payload;
        if (stage == Stage.PASS) {
            action();
        }
    }
    
    function action() internal {
        bool status;
        (status, ) = calledContract.call(payload);
        require(status, "call contract fail");
    }
}

contract SystemProposal is Proposal {
    enum SystemOperationType {START, STOP, UPDATE}
    
    SystemOperationType public operationType;
    address public ballotAddress;
    address public permissionManagerAddress;
    address public templateManagerAddress;
    address public subchainManagerAddress;
    
    constructor(address sender, string memory feature, SystemOperationType _operationType, address _ballotAddress, address _permissionManagerAddress, address _templateManagerAddress, address _subchainManagerAddress, address[] memory _voters) public Proposal(sender, feature, _voters, new address[](0)) {
        operationType = _operationType;
        ballotAddress = _ballotAddress;
        permissionManagerAddress = _permissionManagerAddress;
        templateManagerAddress = _templateManagerAddress;
        subchainManagerAddress = _subchainManagerAddress;
        if (stage == Stage.PASS) {
            action();
        }
    }
    
    function action() internal {
        if (SystemOperationType.START == operationType) {
            Ballot(ballotAddress).startSystemCallback();
        } else if (SystemOperationType.STOP == operationType) {
            Ballot(ballotAddress).stopSystemCallback();
        } else if (SystemOperationType.UPDATE == operationType) {
            Ballot(ballotAddress).updateSystemCallback(permissionManagerAddress, templateManagerAddress, subchainManagerAddress);
        } else {
            revert("invokeSystemOperation operationType is not support");
        }
    }
}

contract Ballot {
    
    SystemProposal[] public systemProposals;
    mapping(address => uint) public systemProposalMapping;
    CommonProposal[] public commonProposals;
    mapping(address => uint) public commonProposalMapping;
    
    address public permissionManagerAddress;
    address public templateManagerAddress;
    address public subchainManagerAddress;
    
    bool public isStarting;
    
    modifier OnlyStarting() {
        require(isStarting, "This contract must be starting. Please invoke function 'start' first!");
        _;
    }
    
    modifier OnlyNotStarting() {
        require(!isStarting, "This contract must not be starting. Please invoke function 'stop' first!");
        _;
    }
    
    modifier OnlySystemProposal() {
        require(systemProposalMapping[msg.sender] > 0, "OnlySystemProposal");
        _;
    }
    
    modifier OnlySubContract() {
        require(isStarting
            && (permissionManagerAddress == msg.sender
            || templateManagerAddress == msg.sender
            || subchainManagerAddress == msg.sender),
            "OnlySubContract");
        _;
    }
    
    constructor() public {
        isStarting = false;
        systemProposals.push(SystemProposal(address(0x0)));
        commonProposals.push(CommonProposal(address(0x0)));
    }
    
    function getJMNs() internal view returns(address[] memory) {
        IPermissionManager permissionManager = IPermissionManager(permissionManagerAddress);
        uint jmnCount = permissionManager.jmnCount();
        address[] memory jmns = new address[](jmnCount - 1);
        for (uint i = 0; i < jmnCount - 1; i++) {
            address jmn = permissionManager.jmnLUT(i + 1);
            jmns[i] = jmn;
        }
        return jmns;
    }
    
    function getSMNs() internal view returns(address[] memory) {
        IPermissionManager permissionManager = IPermissionManager(permissionManagerAddress);
        uint smnCount = permissionManager.smnCount();
        address[] memory smns = new address[](smnCount - 1);
        for (uint i = 0; i < smnCount - 1; i++) {
            address smn = permissionManager.smnLUT(i + 1);
            smns[i] = smn;
        }
        return smns;
    }
    
    function addSystemProposal(address sender, string memory feature, SystemProposal.SystemOperationType _operationType, address _permissionManagerAddress, address _templateManagerAddress, address _subchainManagerAddress) internal {
        SystemProposal systemProposal = new SystemProposal(sender, feature, _operationType, address(this), _permissionManagerAddress, _templateManagerAddress, _subchainManagerAddress, getJMNs());
        systemProposals.push(systemProposal);
        systemProposalMapping[address(systemProposal)] = systemProposals.length - 1;
    }
    
    function addJMNProposal(address sender, string memory feature, address calledContract, bytes memory payload) public OnlySubContract {
        CommonProposal commonProposal = new CommonProposal(sender, feature, calledContract, payload, getJMNs(), new address[](0));
        commonProposals.push(commonProposal);
        commonProposalMapping[address(commonProposal)] = commonProposals.length - 1;
    }
    
    function addSMNProposal(address sender, string memory feature, address calledContract, bytes memory payload, bool hasJudge) public OnlySubContract {
        CommonProposal commonProposal = new CommonProposal(sender, feature, calledContract, payload, getSMNs(), (hasJudge ? getJMNs() : new address[](0)));
        commonProposals.push(commonProposal);
        commonProposalMapping[address(commonProposal)] = commonProposals.length - 1;
    }
    
    function systemProposalCount() public view returns(uint) {
        return systemProposals.length;
    }
    
    function commonProposalCount() public view returns(uint) {
        return commonProposals.length;
    }
    
    function startSystemCallback() public OnlySystemProposal OnlyNotStarting {
        isStarting = true;
    }
    
    function stopSystemCallback() public OnlySystemProposal OnlyStarting {
        isStarting = false;
    }
    
    function updateSystemCallback(address _permissionManagerAddress, address _templateManagerAddress, address _subchainManagerAddress) public OnlySystemProposal OnlyNotStarting {
        permissionManagerAddress = _permissionManagerAddress;
        templateManagerAddress = _templateManagerAddress;
        subchainManagerAddress = _subchainManagerAddress;
    }
    
    modifier OnlyPermission() {
        require(permissionManagerAddress != address(0x0)
            && templateManagerAddress != address(0x0)
            && subchainManagerAddress != address(0x0),
            "OnlyPermission");
        _;
    }
    
    modifier OnlyJMN() {
        require(permissionManagerAddress == address(0x0) || IPermissionManager(permissionManagerAddress).jmns(msg.sender) > 0, "OnlyJMN");
        _;
    }
    
    function start() public OnlyNotStarting OnlyJMN OnlyPermission {
        addSystemProposal(msg.sender, 'start', SystemProposal.SystemOperationType.START, address(0x0), address(0x0), address(0x0));
    }
    
    function stop() public OnlyStarting OnlyJMN {
        addSystemProposal(msg.sender, 'stop', SystemProposal.SystemOperationType.STOP, address(0x0), address(0x0), address(0x0));
    }
    
    function update(address _permissionManagerAddress, address _templateManagerAddress, address _subchainManagerAddress) public OnlyNotStarting OnlyJMN {
        if (permissionManagerAddress == address(0x0)) {
            permissionManagerAddress = _permissionManagerAddress;
            templateManagerAddress = _templateManagerAddress;
            subchainManagerAddress = _subchainManagerAddress;
            return;
        }
        addSystemProposal(msg.sender, 'update', SystemProposal.SystemOperationType.UPDATE, _permissionManagerAddress, _templateManagerAddress, _subchainManagerAddress);
    }
}
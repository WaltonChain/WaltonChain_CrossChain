
## WaltonChain CrossChain

### Description
This system is a part of the Waltonchain Cross-chain Project. It realizes endorsement of child chain data to the parent chain. In this system, the ecosystem’s JMN (Judge Master Nodes) and SMN (Super Master Nodes) perform management through voting.
+ The reward transferred by the child chain owner to the corresponding endorsement contract serves as the endorsement reward
+ SMN can endorse child chain data to the parent chain through the SMN System and get the endorsement reward
+ JMN manage JMN, SMN and endorsement contract templates
+ SMN can add child chains and child chain endorsements

### Services 
+ Gwtc node: blockchain node 
+ SMN System: Endorsement operations can be carried out in this system and corresponding rewards can be obtained. 
+ Management System: permission management (including JMN, SMN management), endorsement contract template management, child chain management, endorsement management 
+ Data Verification System: verification of the endorsed data

### Vote Rules
Note: In case of multiple votes, more than half equals passed.
+ Permission Management
	+ JMN
		+ Add: Initiated by a JMN, all JMNs vote
		+ Delete: Initiated by a JMN, all JMNs vote (if only one JMN is left, it cannot be deleted)
	+ SMN
		+ Add: Initiated by a JMN or SMN, all SMNs vote in the first round. If passed, any JMN's vote is required for the final pass decision.
		+ Delete: Initiated by a JMN or SMN, all SMNs vote in the first round. If passed, any JMN's vote is required to pass the final pass decision.
+ Template Management
	+ Add: Initiated by a JMN or SMN, all SMNs vote in the first round. If the vote passed, then any JMN's vote is required for the final pass decision.
+ Child Chain Management
	+ Add: Initiated by a SMN, all SMNs vote
+ Endorsement Management
	+ Add: Initiated by a SMN, all SMNs vote

### Installation Environment
+ Download and install docker and docker-compose
	https://docs.docker.com/compose/install/

### Configuration Files
+ docker-compose-smn.yml: includes gwtc node, SMN System
+ docker-compose-manage.yml: includes gwtc node, Management System, Data Verification System
+ docker-compose-all.yml: includes gwtc node, SMN System, Management System, Data Verification System

### Deployment
+ Download configuration files
+ For docker-compose-smn.yml or docker-compose-all.yml, please change the configuration items of the configuration file: change "MONGO_NON_ROOT_USERNAME" and "MONGO_USERNAME" to the database user name of your choice, change "MONGO_NON_ROOT_PASSWORD" and "MONGO_PASSWORD" to the database password of your choice, save the changes. (Note: there is a space after ":" in all configuration items)
+ In the directory of the same level with the configuration files, use the command: docker-compose -f [configuration file name] up -d

Default configuration: SMN service port 80, Management System service port 8880, Data Verification System service port 8881.

### Operation
+ [Management System and Data Verification System](./dispatcher/README.md)
+ [SMN System](./mechanism/README.md)

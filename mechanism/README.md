###  Cross-Chain Service Manual
#### Description:
![](images/wtc_logo.jpg)
1. Endorsement means uploading child chain data to the parent chain. Child chains cannot perform any changes. Block endorsement is obtaining hash for each child chain block. Business endorsement refers to a child chain business contract. Business contract is used to store specific business data on child chains. During endorsement, business data are obtained from a business contract.
2. Endorsement contract is used to process child chain data and upload it to the parent chain. addEndorsement function serves to upload processed data to the parent chain, therefore parent chain has frequent upload transactions.
3. "Reward" means profit from endorsing a data string. "SMN Count" stands for the number of SMNs which completed the endorsement. Therefore per-SMN reward shall be Reward/SMN Count.
4. Workers are introduced to ensure SMN account safety: each endorsement transaction requires account private key for signature. Since SMN accounts have a lot of tokens, they are not suitable for transaction signing.
#### Instructions:
##### SMN Front End Instructions

1. Open http://xx.xx.xx.xx in browser. xx.xx.xx.xx is server IP.

1. Create an administrator account, log in to the system.

   ![](images/1.png)
   ![](images/2.png)

1. After the first login, you need to configure WTC node and SMN address.
   Reference WTC node: http://ip:6545
   Reference SMN address: 0xd98868e1d3736070deaf01a666271df9858110e7
   ![](images/3.png)
   ![](images/4.png)

1. When the WTC node information and SMN address are configured, the child chains followed by the SMN address are retrieved and displayed in the child chain list on the left panel.
   ![](images/5.png)

1. Click the icon in the upper right corner of the child chain list to switch the list display method.
  ![](images/6.png)

1. Cross-chain contracts of the first child chain are displayed by default; contract list is in the middle.
  ![](images/7.png)

1. When a contract is not configured, its status is ‘STOPPED’, configuration is ‘Unconfigured’ and the operation button is a grey triangle. When you click on the button, the contract configuration input box pops up. Enter the configurations, click ‘Confirm’ (the execution account is subKeyStore address only).

   -Execution Account: account for cross-chain transmission. Please DO NOT use accounts     with big balance e.g. SMN accounts

   -Reference Parent Chain Node Configuration: http://ip:6545

   -Reference Parent Chain ID Configuration: 15

   -Password: execution account password is your worker's password
    ![](images/8.png)

1. After successful cross-chain contract configuration, the status will be ‘STOPPED’ and you can see ‘Modify Configuration’ button in the Configuration column. The respective operation button is a blue triangle. Click ‘Modify Configuration’ to reconfigure the cross-chain contract.
  ![](images/9.png)

1. After a cross-chain contract is successfully started, the status is ‘RUNNING’ and you can see ‘Modify Configuration’ button. The operation button is a blue square. Click it and then click ‘Confirm’ to stop cross-chain transmission.
   ![](images/10.png)
   ![](images/11.png)

1. After a cross-chain contract is started, an expand button will appear on the right side of the contract. Click it to view cross-chain log. The log updates every 15 seconds, new records appear at the bottom. Max 6 latest records are displayed.
   ![](images/12.png)

1. Click one of the child chains on the left panel to view cross-chain contracts under that child chain.
   ![](images/13.png)

1. Click ‘ALL’ at the top right to view all cross-chain contracts under a child chain. Click ‘RUNNING’ to view the running contracts. Click ‘STOPPED’ to display the configured but not running contracts.
   ![](images/14.png)

1. Click ‘Log’ on the top navigation bar, select child chain and contract and click ‘Search’ to query operation log of a contract.
   ![](images/15.png)

1. Click the settings icon on the top navigation bar to see the settings menu.
    ![](images/16.png)
    Click ‘Modify’ in the SMN section of the menu to reconfigure SMN address. After entering the modified SMN address, click ‘Confirm’.
    ![](images/17.png)
    Click "Import Keystore",add the smn's worker.![](images/22.png)Select your worker's keystore and input password,click "Confirm".![](images/23.png)

1. Click the user icon on the top navigation bar for account operations.
![](images/19.png)
Click ‘Add Account’ to add users (only available for administrator accounts).
![](images/20.png)
![](images/21.png)
Click ‘Add Account’ in the top right corner, enter the user name and password of a subaccount and click ’Confirm’ to add the sub account.



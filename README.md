# Drosera #
# A Simple Bash Script To Run Drosera #
![Go0v1H4XoAAU5sA](https://github.com/user-attachments/assets/1371df50-fe90-4f28-bdc7-28d610c6d82c)

# README: Drosera Network Testnet Setup Script #
## Welcome to the Drosera Network Testnet Setup Script! This script automates the process of setting up and deploying a Trap with two Operators on the Drosera testnet. Follow the steps below to run the script successfully and get your node up and running 

#📋 Prerequisites
Before running the script, ensure you have the following:

A VPS/Server:

#OS: Ubuntu (preferably 20.04 or 22.04)

#Specs: At least 2 CPU cores, 4GB RAM, 20GB free disk space

#Internet: Stable connection

#Two Ethereum Holesky Wallets:

Address 1: Used to deploy the Trap.

Address 2: Used as the second Operator.

#Both wallets must have sufficient Holesky ETH. Fund them using a Holesky faucet (e.g., Holesky Faucet).

#Have the private keys (64 hexadecimal characters, no 0x) and public addresses (42 characters with 0x) ready.

#Ethereum Holesky RPC URL:

Get a valid RPC URL from a provider like Alchemy, QuickNode, or use a public node (e.g., https://ethereum-holesky-rpc.publicnode.com).

Example: https://eth-holesky.alchemyapi.io/v2/your-api-key

#GitHub Account:

You’ll need your GitHub email and username for configuring Git during the setup.


🚀 Installation and Setup
Follow these steps to clone, configure, and run the script:

#Step 1: Clone the Repository
Clone the Drosera script from GitHub to your server:


```bash
git clone https://github.com/cryptoneth/Drosera/
cd Drosera && chmod +x drosera.sh && ./drosera.sh
```

#Step 2: Provide Input Parameters

The script will prompt you to enter the following details:

#Operator 1 Private Key:

The 64-character hexadecimal private key of the wallet used to deploy the Trap (without 0x).

Example: 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef

#Operator 1 Public Address:

The 42-character Ethereum address (with 0x) of the first wallet.

Example: 0x1234567890abcdef1234567890abcdef12345678

#Operator 2 Private Key:

The 64-character hexadecimal private key of the second wallet (without 0x).

#Operator 2 Public Address:

The 42-character Ethereum address (with 0x) of the second wallet.

#Ethereum Holesky RPC URL:

Your RPC URL from Alchemy, QuickNode, or a public node. Press Enter to use the default (https://ethereum-holesky-rpc.publicnode.com).

#GitHub Email:

Your GitHub email address (e.g., your.email@example.com).

#GitHub Username:

Your GitHub username (e.g., yourusername).


🚀 Done


OPTIONAL COMMAND 

Restarts and Dryruns Node:

```bash
pkill -9 drosera-operator
cd ~
cd my-drosera-trap
source /root/.bashrc
drosera dryrun
cd ~
cd Drosera-Network
docker compose up -d
```

🏁 Final Steps
Monitor Node Status:
After the script completes, check the Drosera dashboard at https://app.drosera.io/ for green blocks indicating node liveness.
You can also check the Docker logs:

```bash
cd ~/Drosera-Network
docker logs drosera-node1

#OR

docker logs drosera-node2
```

Follow 
Crypton on Twitter for the latest news and updates about Drosera and this script.

 🚀 If you have questions or need help, reach out via Twitter or the Drosera community. #

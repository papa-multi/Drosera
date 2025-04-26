# Drosera #
# A Simple Bash Script To Run Drosera #
![Go0v1H4XoAAU5sA](https://github.com/user-attachments/assets/1371df50-fe90-4f28-bdc7-28d610c6d82c)

# README: Drosera Network Testnet Setup Script #
## Welcome to the Drosera Network Testnet Setup Script! This script automates the process of setting up and deploying a Trap with two Operators on the Drosera testnet. Follow the steps below to run the script successfully and get your node up and running 



## 📋 Prerequisites

Before running the script, ensure you have the following:

- **A VPS/Server**:
  - **Operating System**: Ubuntu (preferably 20.04 or 22.04)
  - **Specifications**: Minimum 2 CPU cores, 4GB RAM, 20GB free disk space
  - **Internet**: Stable connection

- **Two Ethereum Holesky Wallets**:
  - **Address 1**: Used to deploy the Trap
  - **Address 2**: Used as the second Operator
  - **Funding**: Both wallets must have sufficient Holesky ETH. Fund them using a Holesky faucet (e.g., [Holesky Faucet](https://faucet.holesky.eth.limo/))
  - **Details**: Prepare the private keys (64 hexadecimal characters, no `0x`) and public addresses (42 characters with `0x`)

- **Ethereum Holesky RPC URL**:
  - Obtain a valid RPC URL from a provider like [Alchemy](https://www.alchemy.com/), [QuickNode](https://www.quicknode.com/), or use a public node (e.g., `https://ethereum-holesky-rpc.publicnode.com`)
  - Example: `https://eth-holesky.alchemyapi.io/v2/your-api-key`

- **GitHub Account**:
  - Provide your GitHub email and username for configuring Git during the setup

============================================================================================

### 🚀 Installation and Setup

Follow these steps to clone, configure, and run the script:

1. **Clone the Repository**:
   - Clone the Drosera script from GitHub to your server:
     ```bash
     git clone https://github.com/cryptoneth/Drosera/
     cd Drosera && chmod +x drosera.sh && ./drosera.sh
     ```

2. **Provide Input Parameters**:
   - The script will prompt you to enter the following details:
     - **Operator 1 Private Key**:
       - The 64-character hexadecimal private key of the wallet used to deploy the Trap (without `0x`).
       - Example: `1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`
     - **Operator 1 Public Address**:
       - The 42-character Ethereum address (with `0x`) of the first wallet.
       - Example: `0x1234567890abcdef1234567890abcdef12345678`
     - **Operator 2 Private Key**:
       - The 64-character hexadecimal private key of the second wallet (without `0x`).
       - Example: `1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`
     - **Operator 2 Public Address**:
       - The 42-character Ethereum address (with `0x`) of the second wallet.
       - Example: `0x1234567890abcdef1234567890abcdef12345678`
     - **Ethereum Holesky RPC URL**:
       - Your RPC URL from Alchemy, QuickNode, or a public node. Press Enter to use the default (`https://ethereum-holesky-rpc.publicnode.com`).
       - Example: `https://eth-holesky.alchemyapi.io/v2/your-api-key`
     - **GitHub Email**:
       - Your GitHub email address.
       - Example: `your.email@example.com`
     - **GitHub Username**:
       - Your GitHub username.
       - Example: `yourusername`

## 🏁 Final Steps

1. **Monitor Node Status**:
   - After the script completes, visit the Drosera dashboard at [https://app.drosera.io/](https://app.drosera.io/) to check for green blocks indicating node liveness.
   - You can also view Docker logs to monitor the nodes:
     ```bash
     cd ~/Drosera-Network
     docker logs drosera-node1
     docker logs drosera-node2
     ```

2. **Optional Command (Restart and Dryrun Node)**:
   - To fetch blocks again and restart the node, run:
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

3. **Stay Updated**:
   - Follow [Drosera](https://x.com/DroseraNetwork) on Twitter for the latest news and updates about Drosera .

4. **Get Support**:
   - If you have questions or need help, reach out via [Twitter](https://x.com/0xCrypton_) or the Drosera community.

🚀 **Done!** Your Drosera node should now be running smoothly.

#!/bin/bash

# Drosera Network Testnet Setup Automation Script
# This script automates the setup process for deploying a Trap and Operator on the Drosera testnet.
# It includes a Crypton header and prompts users to follow https://x.com/0xCrypton_.

# Function to prompt for confirmation
confirm_action() {
    read -p "$1 (y/n): " response
    if [[ "$response" != "y" ]]; then
        echo "Action not confirmed. Exiting."
        exit 1
    fi
}

# Function to check command success
check_status() {
    if [[ $? -ne 0 ]]; then
        echo "Error: $1 failed. Exiting."
        exit 1
    fi
}

# Function to retry drosera apply with custom RPC if needed
run_drosera_apply() {
    local private_key=$1
    local rpc_url=$2
    local cmd="DROSERA_PRIVATE_KEY=$private_key drosera apply"
    if [[ -n "$rpc_url" ]]; then
        cmd="DROSERA_PRIVATE_KEY=$private_key drosera apply --eth-rpc-url $rpc_url"
    fi
    echo "Running: $cmd"
    output=$(eval $cmd 2>&1)
    check_status "drosera apply"
    echo "$output"
}

# Install figlet for ASCII art if not present
if ! command -v figlet &> /dev/null; then
    echo "Installing figlet for ASCII art..."
    sudo apt-get update && sudo apt-get install -y figlet
    check_status "figlet installation"
fi

# Display Crypton header and Twitter prompt
clear
figlet -f big "Crypton"
echo "============================================================="
echo "Follow me on Twitter for updates and more: https://x.com/0xCrypton_"
echo "============================================================="
echo ""

# Welcome message
echo "Starting Drosera Network Testnet Setup Automation"
echo "Ensure you have a funded Holesky ETH wallet and necessary permissions."
echo "You will be prompted for inputs and website actions as needed."
echo ""

# Prompt for required inputs
read -p "Enter your EVM wallet private key (Trap wallet): " TRAP_PRIVATE_KEY
read -p "Enter your EVM wallet public address (Operator Address): " OPERATOR_ADDRESS
read -p "Enter your VPS public IP: " VPS_IP
read -p "Enter your Ethereum Holesky RPC URL (from Alchemy/QuickNode, or press Enter to use default): " ETH_RPC_URL
if [[ -z "$ETH_RPC_URL" ]]; then
    ETH_RPC_URL="https://ethereum-holesky-rpc.publicnode.com"
fi
read -p "Enter your GitHub email: " GITHUB_EMAIL
read -p "Enter your GitHub username: " GITHUB_USERNAME

# Step 1: Update and Install Dependencies
echo "Step 1: Updating system and installing dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
check_status "Dependency installation"

# Step 2: Install Docker
echo "Step 2: Installing Docker..."
sudo apt update -y && sudo apt upgrade -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y && sudo apt upgrade -y
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
sudo docker run hello-world
check_status "Docker installation"

# Step 3: Install CLIs (Drosera, Foundry, Bun)
echo "Step 3: Installing Drosera, Foundry, and Bun CLIs..."
curl -L https://app.drosera.io/install | bash
source /root/.bashrc
droseraup
check_status "Drosera CLI installation"
curl -L https://foundry.paradigm.xyz | bash
source /root/.bashrc
foundryup
check_status "Foundry CLI installation"
curl -fsSL https://bun.sh/install | bash
source /root/.bashrc
check_status "Bun installation"

# Step 4: Trap Setup
echo "Step 4: Setting up and deploying Trap..."
mkdir -p my-drosera-trap
cd my-drosera-trap
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"
forge init -t drosera-network/trap-foundry-template
check_status "Forge init"
curl -fsSL https://bun.sh/install | bash
source /root/.bashrc
bun install
forge build
check_status "Forge build"

# Deploy Trap and capture Trap Address
echo "Deploying Trap..."
trap_output=$(run_drosera_apply "$TRAP_PRIVATE_KEY" "$ETH_RPC_URL")
if [[ "$trap_output" =~ "Error" && "$trap_output" =~ "429" ]]; then
    echo "RPC error detected. Retrying with user-provided RPC..."
    read -p "Enter a new Ethereum Holesky RPC URL: " NEW_RPC_URL
    trap_output=$(run_droseraK apply" "$TRAP_PRIVATE_KEY" "$NEW_RPC_URL")
fi
# Extract Trap Address (assuming output contains "Trap Config address: 0x...")
TRAP_ADDRESS=$(echo "$trap_output" | grep -oP 'Trap Config address: \K0x[a-fA-F0-9]{40}')
if [[ -z "$TRAP_ADDRESS" ]]; then
    echo "Failed to capture Trap Address. Please check the output and enter it manually."
    read -p "Enter Trap Address: " TRAP_ADDRESS
fi
echo "Trap Address captured: $TRAP_ADDRESS"

# Step 5: Check Trap in Dashboard
echo "Step 5: Checking Trap in Dashboard..."
echo "Please complete the following actions on https://app.drosera.io/:"
echo "1. Connect your Drosera EVM wallet."
echo "2. Click on 'Traps Owned' to see your deployed Traps OR search for your Trap address: $TRAP_ADDRESS"
confirm_action "Have you connected your wallet and verified the Trap in the dashboard?"

# Step 6: Bloom Boost Trap
echo "Step 6: Performing Bloom Boost..."
echo "On the Drosera dashboard, open your Trap and click 'Send Bloom Boost' to deposit some Holesky ETH."
confirm_action "Have you completed the Bloom Boost?"

# Step 7: Fetch Blocks
echo "Step 7: Fetching blocks..."
drosera dryrun
check_status "drosera dryrun"

# Step 8: Operator Setup - Whitelist Operator
echo "Step 8: Whitelisting Operator..."
cd ~/my-drosera-trap
cat << EOF >> drosera.toml
private_trap = true
whitelist = ["$OPERATOR_ADDRESS"]
EOF
check_status "Updating drosera.toml"
echo "Updating Trap configuration..."
run_drosera_apply "$TRAP_PRIVATE_KEY" "$ETH_RPC_URL"
echo "Trap is now private with operator address whitelisted."

# Step 9: Operator CLI
echo "Step 9: Installing Operator CLI..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
./drosera-operator --version
check_status "Operator CLI installation"
sudo cp drosera-operator /usr/bin
drosera-operator
check_status "Operator CLI global setup"

# Step 10: Install Docker Image
echo "Step 10: Pulling Drosera Operator Docker image..."
docker pull ghcr.io/drosera-network/drosera-operator:latest
check_status "Docker image pull"

# Step 11: Register Operator
echo "Step 11: Registering Operator..."
drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$TRAP_PRIVATE_KEY"
check_status "Operator registration"

# Step 12: Open Ports
echo "Step 12: Opening firewall ports..."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw enable
check_status "Firewall configuration"

# Step 13: Configure and Run Operator (Docker Method)
echo "Step 13: Configuring and running Operator using Docker..."
if systemctl is-active --quiet drosera; then
    sudo systemctl stop drosera
    sudo systemctl disable drosera
fi
git clone https://github.com/0xmoei/Drosera-Network
cd Drosera-Network
cp .env.example .env
cat << EOF > .env
ETH_PRIVATE_KEY=$TRAP_PRIVATE_KEY
VPS_IP=$VPS_IP
P2P_PORT1=31313
SERVER_PORT1=31314
EOF
cat << EOF > docker-compose.yaml
version: '3'
services:
  drosera1:
    image: ghcr.io/drosera-network/drosera-operator:latest
    container_name: drosera-node1
    ports:
      - "31313:31313"
      - "31314:31314"
    volumes:
      - drosera_data1:/data
    command: node --db-file-path /data/drosera.db --network-p2p-port 31313 --server-port 31314 --eth-rpc-url $ETH_RPC_URL --eth-backup-rpc-url https://holesky.drpc.org --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 --eth-private-key \${ETH_PRIVATE_KEY} --listen-address 0.0.0.0 --network-external-p2p-address \${VPS_IP} --disable-dnr-confirmation true
    restart: always
volumes:
  drosera_data1:
EOF
docker compose up -d
check_status "Docker Operator setup"
echo "Checking Operator health..."
docker logs -f drosera-node1

# Step 14: Opt-in Trap
echo "Step 14: Opting in to Trap..."
echo "Please log in to https://app.drosera.io/ with your Operator wallet and opt-in to the Trap ($TRAP_ADDRESS)."
confirm_action "Have you opted in to the Trap?"
# Alternative CLI opt-in
echo "Alternatively, opting in via CLI..."
drosera-operator optin --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$TRAP_PRIVATE_KEY" --trap-config-address "$TRAP_ADDRESS"
check_status "Operator opt-in"

# Step 15: Check Node Liveness
echo "Step 15: Checking node liveness..."
echo "Check the Drosera dashboard for green blocks indicating node liveness."
confirm_action "Do you see green blocks in the dashboard?"

# Step 16: Optional Second Operator
echo "Step 16: Optional - Set up a second Operator?"
read -p "Would you like to configure a second Operator? (y/n): " SETUP_SECOND_OPERATOR
if [[ "$SETUP_SECOND_OPERATOR" == "y" ]]; then
    echo "Setting up second Operator..."
    read -p "Enter your second EVM wallet private key: " SECOND_PRIVATE_KEY
    read -p "Enter your second EVM wallet public address: " SECOND_OPERATOR_ADDRESS
    
    # Stop existing operator
    cd ~/Drosera-Network
    docker compose down -v
    docker stop drosera-node1
    docker rm drosera-node1
    
    # Whitelist second operator
    cd ~/my-drosera-trap
    cat << EOF > drosera.toml
private_trap = true
whitelist = ["$OPERATOR_ADDRESS", "$SECOND_OPERATOR_ADDRESS"]
EOF
    run_drosera_apply "$TRAP_PRIVATE_KEY" "$ETH_RPC_URL"
    
    # Register second operator
    drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$SECOND_PRIVATE_KEY"
    
    # Open additional ports
    sudo ufw allow 31315/tcp
    sudo ufw allow 31316/tcp
    
    # Update docker-compose.yaml
    cd ~/Drosera-Network
    cat << EOF > docker-compose.yaml
version: '3'
services:
  drosera1:
    image: ghcr.io/drosera-network/drosera-operator:latest
    container_name: drosera-node1
    ports:
      - "31313:31313"
      - "31314:31314"
    volumes:
      - drosera_data1:/data
    command: node --db-file-path /data/drosera.db --network-p2p-port 31313 --server-port 31314 --eth-rpc-url $ETH_RPC_URL --eth-backup-rpc-url https://holesky.drpc.org --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 --eth-private-key \${ETH_PRIVATE_KEY} --listen-address 0.0.0.0 --network-external-p2p-address \${VPS_IP} --disable-dnr-confirmation true
    restart: always
  drosera2:
    image: ghcr.io/drosera-network/drosera-operator:latest
    container_name: drosera-node2
    ports:
      - "31315:31315"
      - "31316:31316"
    volumes:
      - drosera_data2:/data
    command: node --db-file-path /data/drosera.db --network-p2p-port 31315 --server-port 31316 --eth-rpc-url $ETH_RPC_URL --eth-backup-rpc-url https://holesky.drpc.org --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 --eth-private-key \${ETH_PRIVATE_KEY2} --listen-address 0.0.0.0 --network-external-p2p-address \${VPS_IP} --disable-dnr-confirmation true
    restart: always
volumes:
  drosera_data1:
  drosera_data2:
EOF
    cat << EOF > .env
ETH_PRIVATE_KEY=$TRAP_PRIVATE_KEY
ETH_PRIVATE_KEY2=$SECOND_PRIVATE_KEY
VPS_IP=$VPS_IP
P2P_PORT1=31313
SERVER_PORT1=31314
P2P_PORT2=31315
SERVER_PORT2=31316
EOF
    docker compose up -d
    check_status "Second Operator setup"
    
    # Opt-in second operator
    echo "Opting in second Operator..."
    echo "Please log in to https://app.drosera.io/ with your second Operator wallet and opt-in to the Trap ($TRAP_ADDRESS)."
    confirm_action "Have you opted in the second Operator?"
    drosera-operator optin --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$SECOND_PRIVATE_KEY" --trap-config-address "$TRAP_ADDRESS"
    
    echo "Second Operator setup complete. Check dashboard for green blocks."
fi

echo "Drosera Network Testnet Setup Complete!"
echo "Follow me on Twitter for more: https://x.com/0xCrypton_"

#!/bin/bash

# Drosera Network Testnet Setup Automation Script
# This script automates the setup process for deploying a Trap and two Operators on the Drosera testnet.
# It includes a Crypton header and prompts users to follow https://x.com/0xCrypton_.

# Ensure we start in ~/Drosera
cd ~/Drosera || { echo "Error: Cannot change to ~/Drosera directory."; exit 1; }

# Function to check command success
check_status() {
    if [[ $? -ne 0 ]]; then
        echo "Error: $1 failed. Exiting."
        exit 1
    fi
}

# Function to validate private key
validate_private_key() {
    local private_key=$1
    if [[ ! "$private_key" =~ ^[0-9a-fA-F]{64}$ ]]; then
        echo "Error: Invalid private key format. Must be 64 hexadecimal characters."
        exit 1
    fi
}

# Improved function to update drosera.toml with ethereum_rpc
update_drosera_toml() {
    local toml_file=~/my-drosera-trap/drosera.toml
    local step=$1
    echo "Updating drosera.toml for $step..."
    
    # Create a backup of the original file
    cp "$toml_file" "${toml_file}.bak"
    
    # Process the file to keep only one ethereum_rpc line
    {
        # First write our ethereum_rpc line
        echo "ethereum_rpc = \"$ETHEREUM_RPC_URL\""
        
        # Then append all other lines that aren't ethereum_rpc or etherum_rpc
        grep -v '^ethereum_rpc =' "${toml_file}.bak" | grep -v '^etherum_rpc ='
    } > "$toml_file"
    
    # Verify there's only one ethereum_rpc line
    local count=$(grep -c '^ethereum_rpc =' "$toml_file")
    echo "Number of ethereum_rpc lines after $step: $count"
    if [[ $count -gt 1 ]]; then
        echo "Warning: Multiple ethereum_rpc lines detected after cleanup!"
    fi
    
    # Print the file for debugging
    echo "Current drosera.toml after $step:"
    cat "$toml_file"
    check_status "Updating drosera.toml for $step"
}

# Clean up previous script runs
echo "Cleaning up previous script runs..."
pkill -f drosera-operator
sudo docker compose -f ~/Drosera-Network/docker-compose.yaml down -v 2>/dev/null
sudo docker stop drosera-node1 drosera-node2 2>/dev/null
sudo docker rm drosera-node1 drosera-node2 2>/dev/null
sudo rm -rf ~/my-drosera-trap ~/Drosera-Network ~/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz /usr/bin/drosera-operator ~/drosera-operator
check_status "Cleanup"
source /root/.bashrc

# Install figlet for ASCII art if not present
if ! command -v figlet &> /dev/null; then
    echo "Installing figlet for ASCII art..."
    sudo apt-get update && sudo apt-get install -y figlet
    check_status "figlet installation"
fi
source /root/.bashrc

# Display Crypton header and Twitter prompt
clear
figlet -f big "Crypton"
echo "============================================================="
echo "Follow me on Twitter for updates and more: https://x.com/0xCrypton_"
echo "============================================================="
echo ""

# Welcome message
echo "Starting Drosera Network Testnet Setup Automation for Two Operators"
echo "Ensure you have funded Holesky ETH wallets for both operators."
echo ""

# Prompt for required inputs
read -p "Enter your first EVM wallet private key (Operator 1): " OPERATOR1_PRIVATE_KEY
validate_private_key "$OPERATOR1_PRIVATE_KEY"
read -p "Enter your first EVM wallet public address (Operator 1): " OPERATOR1_ADDRESS
read -p "Enter your second EVM wallet private key (Operator 2): " OPERATOR2_PRIVATE_KEY
validate_private_key "$OPERATOR2_PRIVATE_KEY"
read -p "Enter your second EVM wallet public address (Operator 2): " OPERATOR2_ADDRESS

# Auto-detect VPS public IP
echo "Detecting VPS public IP..."
VPS_IP=$(curl -s ifconfig.me || curl -s icanhazip.com)
if [[ -z "$VPS_IP" ]]; then
    read -p "Could not detect VPS public IP. Please enter it manually: " VPS_IP
fi
echo "VPS public IP: $VPS_IP"

read -p "Enter your Ethereum Holesky RPC URL (from Alchemy/QuickNode, or press Enter to use default): " ETH_RPC_URL
if [[ -z "$ETH_RPC_URL" ]]; then
    ETH_RPC_URL="https://ethereum-holesky-rpc.publicnode.com"
fi

read -p "Enter your Ethereum RPC URL for drosera.toml (or press Enter to use default): " ETHEREUM_RPC_URL
if [[ -z "$ETHEREUM_RPC_URL" ]]; then
    ETHEREUM_RPC_URL="https://ethereum-holesky-rpc.publicnode.com"
fi

read -p "Enter your GitHub email: " GITHUB_EMAIL
read -p "Enter your GitHub username: " GITHUB_USERNAME

# Step 1: Update and Install Dependencies
echo "Step 1: Updating system and installing dependencies..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y
check_status "Dependency installation"
source /root/.bashrc

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
source /root/.bashrc

# Step 3: Install CLIs (Drosera, Foundry, Bun)
echo "Step 3: Installing Drosera, Foundry, and Bun CLIs..."

# Install Drosera CLI
echo "Installing Drosera CLI..."
max_attempts=3
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Installing Drosera CLI..."
    curl -L https://app.drosera.io/install | bash
    sleep 3
    source /root/.bashrc
    
    if [[ -d "/root/.drosera/bin" ]]; then
        export PATH=$PATH:/root/.drosera/bin
        echo 'export PATH=$PATH:/root/.drosera/bin' >> /root/.bashrc
        source /root/.bashrc
    fi
    
    if command -v droseraup &> /dev/null; then
        droseraup
        if command -v drosera &> /dev/null; then
            echo "Success: Drosera CLI installed."
            break
        fi
    fi
    
    ((attempt++))
    if [[ $attempt -le $max_attempts ]]; then
        echo "Retrying in 10 seconds..."
        sleep 10
    else
        echo "Error: Failed to install Drosera CLI after $max_attempts attempts."
        exit 1
    fi
done
check_status "Drosera CLI installation"
source /root/.bashrc

# Install Foundry CLI
echo "Installing Foundry CLI..."
max_attempts=3
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Installing Foundry CLI..."
    curl -L https://foundry.paradigm.xyz | bash
    sleep 3
    source /root/.bashrc
    
    if [[ -d "/root/.foundry/bin" ]]; then
        export PATH=$PATH:/root/.foundry/bin
        echo 'export PATH=$PATH:/root/.foundry/bin' >> /root/.bashrc
        source /root/.bashrc
    fi
    
    if command -v foundryup &> /dev/null; then
        foundryup
        if command -v forge &> /dev/null; then
            echo "Success: Foundry CLI installed."
            break
        fi
    fi
    
    ((attempt++))
    if [[ $attempt -le $max_attempts ]]; then
        echo "Retrying in 10 seconds..."
        sleep 10
    else
        echo "Error: Failed to install Foundry CLI after $max_attempts attempts."
        exit 1
    fi
done
check_status "Foundry CLI installation"
source /root/.bashrc

# Install Bun CLI
echo "Installing Bun CLI..."
max_attempts=3
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Installing Bun CLI..."
    curl -fsSL https://bun.sh/install | bash
    sleep 3
    source /root/.bashrc
    
    if [[ -d "/root/.bun/bin" ]]; then
        export PATH=$PATH:/root/.bun/bin
        echo 'export PATH=$PATH:/root/.bun/bin' >> /root/.bashrc
        source /root/.bashrc
    fi
    
    if command -v bun &> /dev/null; then
        echo "Success: Bun CLI installed."
        break
    fi
    
    ((attempt++))
    if [[ $attempt -le $max_attempts ]]; then
        echo "Retrying in 10 seconds..."
        sleep 10
    else
        echo "Error: Failed to install Bun CLI after $max_attempts attempts."
        exit 1
    fi
done
check_status "Bun CLI installation"
source /root/.bashrc

# Step 4: Trap Setup
echo "Step 4: Setting up and deploying Trap..."
mkdir -p ~/my-drosera-trap
cd ~/my-drosera-trap || { echo "Error: Cannot change to ~/my-drosera-trap directory."; exit 1; }
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"
forge init -t drosera-network/trap-foundry-template
check_status "Forge init"

# Update drosera.toml immediately after forge init
update_drosera_toml "post-forge-init"

curl -fsSL https://bun.sh/install | bash
source /root/.bashrc
bun install
forge build
check_status "Forge build"

# Update drosera.toml before drosera apply
update_drosera_toml "pre-deploy"
source /root/.bashrc

# Deploy Trap
echo "Deploying Trap..."
cd ~/my-drosera-trap || { echo "Error: Cannot change to ~/my-drosera-trap directory."; exit 1; }
max_attempts=20
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Deploying Trap..."
    DROSERA_PRIVATE_KEY=$OPERATOR1_PRIVATE_KEY drosera apply
    if [[ $? -eq 0 ]]; then
        echo "Success: Trap deployed."
        break
    else
        echo "Failed to deploy Trap."
        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            echo "Retrying in 60 seconds..."
            sleep 60
        else
            echo "Error: Failed to deploy Trap after $max_attempts attempts."
            exit 1
        fi
    fi
done
check_status "Trap deployment"

# Re-ensure ethereum_rpc after drosera apply
update_drosera_toml "post-deploy"
source /root/.bashrc

# Step 4.1: Extract Trap Address from drosera.toml
echo "Step 4.1: Extracting Trap Address from drosera.toml..."
TRAP_ADDRESS=$(awk '/\[traps\.mytrap\]/ {p=1} p && /address =/ {print $3; exit}' ~/my-drosera-trap/drosera.toml | tr -d '"')
if [[ -z "$TRAP_ADDRESS" || ! "$TRAP_ADDRESS" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
    echo "Error: Failed to extract a valid Trap Address from drosera.toml."
    read -p "Enter a valid Trap Config address (e.g., 0x1234567890abcdef1234567890abcdef12345678): " TRAP_ADDRESS
    if [[ ! "$TRAP_ADDRESS" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
        echo "Error: Invalid Trap Config address entered. Exiting."
        exit 1
    fi
fi
echo "Trap Address extracted: $TRAP_ADDRESS"
sleep 3
source /root/.bashrc

# Step 4.2: Confirm Send Bloom
echo "Please go to https://app.drosera.io/, open your Trap ($TRAP_ADDRESS), and click 'Send Bloom Boost' to deposit some Holesky ETH."
read -p "Have you completed the Send Bloom on https://app.drosera.io/? (y/n): " bloom_confirmed
if [[ "$bloom_confirmed" != "y" ]]; then
    echo "Error: Send Bloom not confirmed. Exiting."
    exit 1
fi
echo "Send Bloom confirmed."
sleep 3
source /root/.bashrc

# Step 5: Whitelist Operators
echo "Step 5: Whitelisting Operators..."
cd ~/my-drosera-trap || { echo "Error: Cannot change to ~/my-drosera-trap directory."; exit 1; }

# Update drosera.toml with whitelist
echo "Updating drosera.toml with whitelist..."
{
    # First write our ethereum_rpc line
    echo "ethereum_rpc = \"$ETHEREUM_RPC_URL\""
    
    # Then append all other lines that aren't ethereum_rpc or whitelist
    grep -v '^ethereum_rpc =' drosera.toml | grep -v '^whitelist =' | grep -v '^private_trap ='
    
    # Add our whitelist configuration
    echo "private_trap = true"
    echo "whitelist = [\"$OPERATOR1_ADDRESS\", \"$OPERATOR2_ADDRESS\"]"
} > drosera.toml.tmp && mv drosera.toml.tmp drosera.toml

# Add delay to handle ConfigUpdateCooldownNotElapsed
echo "Waiting 60 seconds to ensure cooldown period has elapsed..."
sleep 60

echo "Updating Trap configuration..."
max_attempts=10
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Updating Trap configuration..."
    DROSERA_PRIVATE_KEY=$OPERATOR1_PRIVATE_KEY drosera apply
    if [[ $? -eq 0 ]]; then
        echo "Success: Trap configuration updated."
        break
    else
        echo "Failed to update Trap configuration."
        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            echo "Retrying in 120 seconds..."
            sleep 120
        else
            echo "Error: Failed to update Trap configuration after $max_attempts attempts."
            exit 1
        fi
    fi
done
check_status "Trap configuration update"
source /root/.bashrc

# Step 6: Install Operator CLI
echo "Step 6: Installing Operator CLI and pulling Docker image..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.17.2/drosera-operator-v1.17.2-x86_64-unknown-linux-gnu.tar.gz
sleep 3
tar -xvf drosera-operator-v1.17.2-x86_64-unknown-linux-gnu.tar.gz
sleep 3
sudo cp drosera-operator /usr/bin
sleep 3
sudo chmod +x /usr/bin/drosera-operator
sleep 3
export PATH=$PATH:/usr/bin
source /root/.bashrc
docker pull ghcr.io/drosera-network/drosera-operator:latest
sleep 3
source /root/.bashrc

# Step 7: Register Operators
echo "Step 7: Registering Operators..."
cd ~/my-drosera-trap || { echo "Error: Cannot change to ~/my-drosera-trap directory."; exit 1; }

# Register Operator 1
echo "Attempting to register Operator 1..."
max_attempts=3
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Registering Operator 1..."
    drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$OPERATOR1_PRIVATE_KEY" 2>&1 | tee /tmp/register_output.txt
    if [[ $? -eq 0 || $(grep -q "OperatorAlreadyRegistered" /tmp/register_output.txt) ]]; then
        echo "Success: Operator 1 registered or already registered."
        rm -f /tmp/register_output.txt
        break
    else
        echo "Failed to register Operator 1."
        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            echo "Retrying in 30 seconds..."
            sleep 30
        else
            echo "Error: Failed to register Operator 1 after $max_attempts attempts."
            rm -f /tmp/register_output.txt
            exit 1
        fi
    fi
done
sleep 3
source /root/.bashrc

# Register Operator 2
echo "Attempting to register Operator 2..."
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Registering Operator 2..."
    drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$OPERATOR2_PRIVATE_KEY" 2>&1 | tee /tmp/register_output.txt
    if [[ $? -eq 0 || $(grep -q "OperatorAlreadyRegistered" /tmp/register_output.txt) ]]; then
        echo "Success: Operator 2 registered or already registered."
        rm -f /tmp/register_output.txt
        break
    else
        echo "Failed to register Operator 2."
        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            echo "Retrying in 30 seconds..."
            sleep 30
        else
            echo "Error: Failed to register Operator 2 after $max_attempts attempts."
            rm -f /tmp/register_output.txt
            exit 1
        fi
    fi
done
sleep 3
source /root/.bashrc

# Step 8: Opt-in Operators
echo "Step 8: Opting in Operators..."
cd ~/my-drosera-trap || { echo "Error: Cannot change to ~/my-drosera-trap directory."; exit 1; }

# Opt-in Operator 1 (manual via website)
echo "Please go to https://app.drosera.io/, log in with Operator 1 address ($OPERATOR1_ADDRESS), find your Trap ($TRAP_ADDRESS) in the dashboard, and click the 'Optin' button."
read -p "Have you completed the Optin for Operator 1 on https://app.drosera.io/? (y/n): " optin1_confirmed
if [[ "$optin1_confirmed" != "y" ]]; then
    echo "Error: Optin for Operator 1 not confirmed. Exiting."
    exit 1
fi
echo "Operator 1 opt-in confirmed."
sleep 3
source /root/.bashrc

# Opt-in Operator 2 (via code)
echo "Attempting to opt-in Operator 2..."
max_attempts=5
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Opting in Operator 2..."
    drosera-operator optin --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$OPERATOR2_PRIVATE_KEY" --trap-config-address "$TRAP_ADDRESS"
    if [[ $? -eq 0 ]]; then
        echo "Success: Operator 2 opted in."
        break
    else
        echo "Failed to opt-in Operator 2."
        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            echo "Retrying in 15 seconds..."
            sleep 15
        else
            echo "Error: Failed to opt-in Operator 2 after $max_attempts attempts."
            exit 1
        fi
    fi
done
sleep 3
source /root/.bashrc

# Step 9: Install Docker Image
echo "Step 9: Pulling Drosera Operator Docker image..."
docker pull ghcr.io/drosera-network/drosera-operator:latest
check_status "Docker image pull"
source /root/.bashrc

# Step 10: Open Ports
echo "Step 10: Opening firewall ports..."
sudo ufw allow ssh
sudo ufw allow 22
sudo ufw allow 31313/tcp
sudo ufw allow 31314/tcp
sudo ufw allow 31315/tcp
sudo ufw allow 31316/tcp
sudo ufw enable
check_status "Firewall configuration"
source /root/.bashrc

# Step 11: Configure and Run Operators (Docker Method)
echo "Step 11: Configuring and running Operators using Docker..."
mkdir -p ~/Drosera-Network
cd ~/Drosera-Network || { echo "Error: Cannot change to ~/Drosera-Network directory."; exit 1; }

# Create .env file
echo "Creating .env file..."
cat << EOF > .env
ETH_PRIVATE_KEY=$OPERATOR1_PRIVATE_KEY
ETH_PRIVATE_KEY2=$OPERATOR2_PRIVATE_KEY
VPS_IP=$VPS_IP
P2P_PORT1=31313
SERVER_PORT1=31314
P2P_PORT2=31315
SERVER_PORT2=31316
EOF
check_status ".env file creation"

# Create docker-compose.yaml file
echo "Creating docker-compose.yaml file..."
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
    command: node --db-file-path /data/drosera.db --network-p2p-port 31313 --server-port 31314 --eth-rpc-url $ETH_RPC_URL --eth-backup-rpc-url https://holesky.drpc.org --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 --eth-private-key $OPERATOR1_PRIVATE_KEY --listen-address 0.0.0.0 --network-external-p2p-address $VPS_IP --disable-dnr-confirmation true
    restart: always
  drosera2:
    image: ghcr.io/drosera-network/drosera-operator:latest
    container_name: drosera-node2
    ports:
      - "31315:31315"
      - "31316:31316"
    volumes:
      - drosera_data2:/data
    command: node --db-file-path /data/drosera.db --network-p2p-port 31315 --server-port 31316 --eth-rpc-url $ETH_RPC_URL --eth-backup-rpc-url https://holesky.drpc.org --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 --eth-private-key $OPERATOR2_PRIVATE_KEY --listen-address 0.0.0.0 --network-external-p2p-address $VPS_IP --disable-dnr-confirmation true
    restart: always
volumes:
  drosera_data1:
  drosera_data2:
EOF
check_status "docker-compose.yaml creation"

# Run docker compose
echo "Starting Docker containers..."
docker compose up -d
check_status "Docker containers startup"
source /root/.bashrc

# Step 12: Restart and Dryrun Node
echo "Step 12: Restarting node and running dryrun to fetch blocks..."
pkill -f drosera-operator
sleep 3
source /root/.bashrc

echo "Running drosera dryrun..."
cd ~/my-drosera-trap || { echo "Error: Cannot change to ~/my-drosera-trap directory."; exit 1; }
drosera dryrun
check_status "drosera dryrun"

echo "Restarting node with docker compose..."
cd ~/Drosera-Network || { echo "Error: Cannot change to ~/Drosera-Network directory."; exit 1; }
docker compose up -d
check_status "Docker containers restart"

echo "Node restarted and dryrun completed."
source /root/.bashrc

echo "Drosera Network Testnet Setup Complete for Two Operators!"
echo "Check the Drosera dashboard at https://app.drosera.io/ for green blocks indicating node liveness."
echo "Follow me on Twitter for more: https://x.com/0xCrypton_"

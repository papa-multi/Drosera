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

# Function to validate private key
validate_private_key() {
    local private_key=$1
    if [[ ! "$private_key" =~ ^[0-9a-fA-F]{64}$ ]]; then
        echo "Error: Invalid private key format. Must be 64 hexadecimal characters."
        exit 1
    fi
}

# Function to validate RPC URL
validate_rpc_url() {
    local rpc_url=$1
    echo "Validating RPC URL: $rpc_url"
    local response=$(curl -s -m 10 -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$rpc_url")
    if [[ ! "$response" =~ "result" ]]; then
        echo "Warning: RPC URL ($rpc_url) is not responding correctly. Response: $response"
        return 1
    fi
    return 0
}

# Function to retry drosera apply
run_drosera_apply() {
    local private_key=$1
    local rpc_url=$2
    local max_attempts=3
    local attempt=1
    local output=""
    local cmd="DROSERA_PRIVATE_KEY=$private_key drosera apply"
    
    # Validate private key
    validate_private_key "$private_key"

    # Validate RPC URL and append if valid
    if [[ -n "$rpc_url" ]] && validate_rpc_url "$rpc_url"; then
        cmd="DROSERA_PRIVATE_KEY=$private_key drosera apply --eth-rpc-url $rpc_url"
    else
        echo "Using default execution without custom RPC URL due to invalid or empty RPC."
    fi

    # Ensure we're in the correct directory
    cd ~/my-drosera-trap || { echo "Error: Cannot change to ~/my-drosera-trap directory."; exit 1; }

    while [[ $attempt -le $max_attempts ]]; do
        echo "Attempt $attempt/$max_attempts: Running: $cmd"
        # Run with 5-minute timeout
        output=$(timeout 300 bash -c "$cmd" 2>&1)
        local status=$?
        
        if [[ $status -eq 0 && "$output" =~ "Trap Config address: 0x" ]]; then
            echo "Success: Trap deployed successfully!"
            echo "Full output: $output"
            echo "$output"
            return 0
        else
            echo "Failed attempt $attempt: Status code: $status"
            echo "Output: $output"
            if [[ "$output" =~ "429" ]]; then
                echo "RPC rate limit detected. Switching to backup RPC..."
                rpc_url="https://holesky.drpc.org"
                cmd="DROSERA_PRIVATE_KEY=$private_key drosera apply --eth-rpc-url $rpc_url"
            elif [[ "$output" =~ "insufficient funds" ]]; then
                echo "Error: Insufficient funds in wallet. Please fund your Holesky wallet and try again."
                exit 1
            elif [[ "$output" =~ "invalid private key" ]]; then
                echo "Error: Invalid private key provided."
                exit 1
            fi
        fi
        
        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            echo "Retrying in 10 seconds..."
            sleep 10
        fi
    done

    echo "Error: Failed to deploy Trap after $max_attempts attempts."
    echo "Final output: $output"
    read -p "Enter a new Ethereum Holesky RPC URL to try again (or press Enter to exit): " new_rpc_url
    if [[ -n "$new_rpc_url" ]]; then
        echo "Trying with new RPC URL: $new_rpc_url"
        run_drosera_apply "$private_key" "$new_rpc_url"
    else
        echo "Exiting due to repeated failures."
        exit 1
    fi
}

# Function to run drosera-operator optin with retries
run_drosera_optin() {
    local private_key=$1
    local rpc_url=$2
    local trap_address=$3
    local max_attempts=3
    local attempt=1
    local output=""
    local cmd="drosera-operator optin --eth-rpc-url $rpc_url --eth-private-key $private_key --trap-config-address $trap_address"

    # Validate private key
    validate_private_key "$private_key"

    # Validate RPC URL
    if ! validate_rpc_url "$rpc_url"; then
        echo "Falling back to backup RPC URL: https://holesky.drpc.org"
        rpc_url="https://holesky.drpc.org"
        cmd="drosera-operator optin --eth-rpc-url $rpc_url --eth-private-key $private_key --trap-config-address $trap_address"
    fi

    while [[ $attempt -le $max_attempts ]]; do
        echo "Attempt $attempt/$max_attempts: Running: $cmd"
        # Run with 2-minute timeout
        output=$(timeout 120 bash -c "$cmd" 2>&1)
        local status=$?
        
        if [[ $status -eq 0 ]]; then
            echo "Success: Operator opted in successfully!"
            echo "Full output: $output"
            return 0
        else
            echo "Failed attempt $attempt: Status code: $status"
            echo "Output: $output"
            if [[ "$output" =~ "429" ]]; then
                echo "RPC rate limit detected. Switching to backup RPC..."
                rpc_url="https://holesky.drpc.org"
                cmd="drosera-operator optin --eth-rpc-url $rpc_url --eth-private-key $private_key --trap-config-address $trap_address"
            elif [[ "$output" =~ "insufficient funds" ]]; then
                echo "Error: Insufficient funds in wallet. Please fund your Holesky wallet and try again."
                exit 1
            elif [[ "$output" =~ "invalid private key" ]]; then
                echo "Error: Invalid private key provided."
                exit 1
            fi
        fi
        
        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            echo "Retrying in 10 seconds..."
            sleep 10
        fi
    done

    echo "Error: Failed to opt-in Operator after $max_attempts attempts."
    echo "Final output: $output"
    exit 1
}

# Clean up previous script runs
echo "Cleaning up previous script runs..."
sudo docker compose -f ~/Drosera-Network/docker-compose.yaml down -v 2>/dev/null
sudo docker stop drosera-node1 drosera-node2 2>/dev/null
sudo docker rm drosera-node1 drosera-node2 2>/dev/null
sudo rm -rf ~/my-drosera-trap ~/Drosera-Network ~/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz /usr/bin/drosera-operator
check_status "Cleanup"

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

# Install Drosera CLI with retries
echo "Installing Drosera CLI..."
max_attempts=3
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Installing Drosera CLI..."
    cd ~ || { echo "Error: Cannot change to home directory."; exit 1; }
    curl -L https://app.drosera.io/install | bash
    source /root/.bashrc
    if command -v droseraup &> /dev/null; then
        droseraup
        if command -v drosera &> /dev/null; then
            echo "Success: Drosera CLI installed."
            break
        else
            echo "Drosera CLI installation failed."
        fi
    else
        echo "droseraup command not found."
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
source /root/.bashrc
check_status "Drosera CLI installation"

# Install Foundry CLI
echo "Installing Foundry CLI..."
cd ~ || { echo "Error: Cannot change to home directory."; exit 1; }
curl -L https://foundry.paradigm.xyz | bash
source /root/.bashrc
if command -v foundryup &> /dev/null; then
    foundryup
    check_status "Foundry CLI installation"
else
    echo "Error: foundryup command not found."
    exit 1
fi
source /root/.bashrc

# Install Bun CLI
echo "Installing Bun CLI..."
cd ~ || { echo "Error: Cannot change to home directory."; exit 1; }
curl -fsSL https://bun.sh/install | bash
source /root/.bashrc
if command -v bun &> /dev/null; then
    check_status "Bun installation"
else
    echo "Error: Bun command not found."
    exit 1
fi
source /root/.bashrc

# Step 4: Trap Setup
echo "Step 4: Setting up and deploying Trap..."
mkdir -p ~/my-drosera-trap
cd ~/my-drosera-trap
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"
forge init -t drosera-network/trap-foundry-template
check_status "Forge init"
bun install
forge build
check_status "Forge build"

# Deploy Trap and capture Trap Address
echo "Deploying Trap..."
trap_output=$(run_drosera_apply "$TRAP_PRIVATE_KEY" "$ETH_RPC_URL")
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
cd ~/my-drosera-trap
drosera dryrun
check_status "drosera dryrun"

# Step 8: Operator Setup - Whitelist Operator
echo "Step 8: Whitelisting Operator..."
cd ~/my-drosera-trap
cat << EOF > drosera.toml
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
mkdir -p ~/Drosera-Network
cd ~/Drosera-Network
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
# CLI opt-in for first operator
echo "Opting in via CLI for first Operator..."
run_drosera_optin "$TRAP_PRIVATE_KEY" "$ETH_RPC_URL" "$TRAP_ADDRESS"
check_status "First Operator opt-in"

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
    echo "Opting in via CLI for second Operator..."
    run_drosera_optin "$SECOND_PRIVATE_KEY" "$ETH_RPC_URL" "$TRAP_ADDRESS"
    check_status "Second Operator opt-in"
    
    echo "Second Operator setup complete. Check dashboard for green blocks."
fi

echo "Drosera Network Testnet Setup Complete!"
echo "Follow me on Twitter for more: https://x.com/0xCrypton_"

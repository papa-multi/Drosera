#!/bin/bash

# Drosera Network Testnet Setup Automation Script
# This script automates the setup process for deploying a Trap and two Operators on the Drosera testnet.
# It includes a Crypton header and prompts users to follow https://x.com/0xCrypton_.

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

# Function to run drosera-operator optin with retries
run_drosera_optin() {
    local private_key=$1
    local rpc_url=$2
    local trap_address=$3
    local max_attempts=3
    local attempt=1
    local output=""
    local cmd="drosera-operator optin --eth-rpc-url $rpc_url --eth-private-key $private_key --trap-config-address $trap_address"

    validate_private_key "$private_key"
    if [[ -n "$rpc_url" ]] && ! curl -s -m 10 -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' "$rpc_url" | grep -q "result"; then
        echo "Falling back to backup RPC URL: https://holesky.drpc.org"
        rpc_url="https://holesky.drpc.org"
        cmd="drosera-operator optin --eth-rpc-url $rpc_url --eth-private-key $private_key --trap-config-address $trap_address"
    fi

    while [[ $attempt -le $max_attempts ]]; do
        echo "Attempt $attempt/$max_attempts: Running: $cmd"
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
echo "Starting Drosera Network Testnet Setup Automation for Two Operators"
echo "Ensure you have funded Holesky ETH wallets for both operators."
echo ""

# Prompt for required inputs
read -p "Enter your first EVM wallet private key (Operator 1): " OPERATOR1_PRIVATE_KEY
read -p "Enter your first EVM wallet public address (Operator 1): " OPERATOR1_ADDRESS
read -p "Enter your second EVM wallet private key (Operator 2): " OPERATOR2_PRIVATE_KEY
read -p "Enter your second EVM wallet public address (Operator 2): " OPERATOR2_ADDRESS
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
max_attempts=5
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Installing Drosera CLI..."
    cd ~ || { echo "Error: Cannot change to home directory."; exit 1; }
    
    output=$(curl -L https://app.drosera.io/install | bash 2>&1)
    echo "Installer output: $output"
    
    source /root/.bashrc
    sleep 2
    source /root/.bashrc
    sleep 2
    
    if [[ -d "/root/.drosera/bin" ]]; then
        export PATH=$PATH:/root/.drosera/bin
        echo 'export PATH=$PATH:/root/.drosera/bin' >> /root/.bashrc
        source /root/.bashrc
        sleep 2
    fi
    
    if command -v droseraup &> /dev/null; then
        echo "droseraup found, running droseraup..."
        droseraup_output=$(droseraup 2>&1)
        echo "droseraup output: $droseraup_output"
        
        source /root/.bashrc
        sleep 2
        if command -v drosera &> /dev/null; then
            echo "Success: Drosera CLI installed."
            break
        else
            echo "Drosera CLI not fully installed."
        fi
    else
        echo "droseraup command not found."
        echo "Current PATH: $PATH"
    fi
    
    ((attempt++))
    if [[ $attempt -le $max_attempts ]]; then
        echo "Retrying in 15 seconds..."
        sleep 15
    else
        echo "Error: Failed to install Drosera CLI after $max_attempts attempts."
        echo "Please try running the following commands manually:"
        echo "  cd ~"
        echo "  curl -L https://app.drosera.io/install | bash"
        echo "  source /root/.bashrc"
        echo "  droseraup"
        exit 1
    fi
done
source /root/.bashrc
sleep 2
check_status "Drosera CLI installation"

# Install Foundry CLI with retries
echo "Installing Foundry CLI..."
max_attempts=5
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Installing Foundry CLI..."
    cd ~ || { echo "Error: Cannot change to home directory."; exit 1; }
    
    output=$(curl -L https://foundry.paradigm.xyz | bash 2>&1)
    echo "Installer output: $output"
    
    source /root/.bashrc
    sleep 2
    source /root/.bashrc
    sleep 2
    
    if [[ -d "/root/.foundry/bin" ]]; then
        export PATH=$PATH:/root/.foundry/bin
        echo 'export PATH=$PATH:/root/.foundry/bin' >> /root/.bashrc
        source /root/.bashrc
        sleep 2
    fi
    
    if command -v foundryup &> /dev/null; then
        echo "foundryup found, running foundryup..."
        foundryup_output=$(foundryup 2>&1)
        echo "foundryup output: $foundryup_output"
        
        source /root/.bashrc
        sleep 2
        if command -v forge &> /dev/null; then
            echo "Success: Foundry CLI installed."
            break
        else
            echo "Foundry CLI not fully installed."
        fi
    else
        echo "foundryup command not found."
        echo "Current PATH: $PATH"
    fi
    
    ((attempt++))
    if [[ $attempt -le $max_attempts ]]; then
        echo "Retrying in 15 seconds..."
        sleep 15
    else
        echo "Error: Failed to install Foundry CLI after $max_attempts attempts."
        echo "Please try running the following commands manually:"
        echo "  cd ~"
        echo "  curl -L https://foundry.paradigm.xyz | bash"
        echo "  source /root/.bashrc"
        echo "  foundryup"
        exit 1
    fi
done
source /root/.bashrc
sleep 2
check_status "Foundry CLI installation"

# Install Bun CLI with retries
echo "Installing Bun CLI..."
max_attempts=5
attempt=1
while [[ $attempt -le $max_attempts ]]; do
    echo "Attempt $attempt/$max_attempts: Installing Bun CLI..."
    cd ~ || { echo "Error: Cannot change to home directory."; exit 1; }
    
    output=$(curl -fsSL https://bun.sh/install | bash 2>&1)
    echo "Installer output: $output"
    
    source /root/.bashrc
    sleep 2
    source /root/.bashrc
    sleep 2
    
    if [[ -d "/root/.bun/bin" ]]; then
        export PATH=$PATH:/root/.bun/bin
        echo 'export PATH=$PATH:/root/.bun/bin' >> /root/.bashrc
        source /root/.bashrc
        sleep 2
    fi
    
    if command -v bun &> /dev/null; then
        echo "Success: Bun CLI installed."
        break
    else
        echo "bun command not found."
        echo "Current PATH: $PATH"
    fi
    
    ((attempt++))
    if [[ $attempt -le $max_attempts ]]; then
        echo "Retrying in 15 seconds..."
        sleep 15
    else
        echo "Error: Failed to install Bun CLI after $max_attempts attempts."
        echo "Please try running the following commands manually:"
        echo "  cd ~"
        echo "  curl -fsSL https://bun.sh/install | bash"
        echo "  source /root/.bashrc"
        exit 1
    fi
done
source /root/.bashrc
sleep 2
check_status "Bun CLI installation"

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

# Create initial drosera.toml
echo "Creating initial drosera.toml..."
cat << EOF > drosera.toml
ethereum_rpc = "https://ethereum-holesky-rpc.publicnode.com"
drosera_rpc = "https://seed-node.testnet.drosera.io"
eth_chain_id = 17000
drosera_address = "0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8"

[traps]

[traps.mytrap]
path = "out/HelloWorldTrap.sol/HelloWorldTrap.json"
response_contract = "0xdA890040Af0533D98B9F5f8FE3537720ABf83B0C"
response_function = "helloworld(string)"
cooldown_period_blocks = 33
min_number_of_operators = 1
max_number_of_operators = 2
block_sample_size = 10
address = "0x0000000000000000000000000000000000000000"
EOF
check_status "Creating drosera.toml"

# Deploy Trap
echo "Deploying Trap..."
cd ~/my-drosera-trap
trap_output=$(DROSERA_PRIVATE_KEY=$OPERATOR1_PRIVATE_KEY drosera apply 2>&1)
check_status "Trap deployment"
echo "Trap deployment output: $trap_output"

# Extract Trap Address from output
TRAP_ADDRESS=$(echo "$trap_output" | grep -oP 'address: \K0x[a-fA-F0-9]{40}')
if [[ -z "$TRAP_ADDRESS" ]]; then
    echo "Error: Failed to extract Trap Address from deployment output."
    exit 1
fi
echo "Trap Address extracted: $TRAP_ADDRESS"

# Update drosera.toml with Trap Address
echo "Updating drosera.toml with Trap Address..."
sed -i "s/address = \"0x0000000000000000000000000000000000000000\"/address = \"$TRAP_ADDRESS\"/" drosera.toml
check_status "Updating drosera.toml with Trap Address"

# Confirm Send Bloom
echo "Please go to https://app.drosera.io/, open your Trap ($TRAP_ADDRESS), and click 'Send Bloom Boost' to deposit some Holesky ETH."
read -p "Have you completed the Send Bloom on https://app.drosera.io/? (y/n): " bloom_confirmed
if [[ "$bloom_confirmed" != "y" ]]; then
    echo "Send Bloom not confirmed. Exiting."
    exit 1
fi

# Step 5: Whitelist Operators
echo "Step 5: Whitelisting Operators..."
cd ~/my-drosera-trap
cat << EOF >> drosera.toml
private_trap = true
whitelist = ["$OPERATOR1_ADDRESS", "$OPERATOR2_ADDRESS"]
EOF
check_status "Appending whitelist to drosera.toml"
echo "Updating Trap configuration..."
DROSERA_PRIVATE_KEY=$OPERATOR1_PRIVATE_KEY drosera apply
check_status "Trap configuration update"

# Step 6: Install Operator CLI
echo "Step 6: Installing Operator CLI..."
cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.16.2/drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.16.2-x86_64-unknown-linux-gnu.tar.gz
./drosera-operator --version
check_status "Operator CLI installation"
sudo cp drosera-operator /usr/bin
drosera-operator
check_status "Operator CLI global setup"

# Step 7: Register Operators
echo "Step 7: Registering Operators..."
drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$OPERATOR1_PRIVATE_KEY"
check_status "Operator 1 registration"
drosera-operator register --eth-rpc-url "$ETH_RPC_URL" --eth-private-key "$OPERATOR2_PRIVATE_KEY"
check_status "Operator 2 registration"

# Step 8: Opt-in Operators
echo "Step 8: Opting in Operators..."
echo "Opting in Operator 1..."
run_drosera_optin "$OPERATOR1_PRIVATE_KEY" "$ETH_RPC_URL" "$TRAP_ADDRESS"
check_status "Operator 1 opt-in"
echo "Opting in Operator 2..."
run_drosera_optin "$OPERATOR2_PRIVATE_KEY" "$ETH_RPC_URL" "$TRAP_ADDRESS"
check_status "Operator 2 opt-in"

# Step 9: Install Docker Image
echo "Step 9: Pulling Drosera Operator Docker image..."
docker pull ghcr.io/drosera-network/drosera-operator:latest
check_status "Docker image pull"

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

# Step 11: Configure and Run Operators (Docker Method)
echo "Step 11: Configuring and running Operators using Docker..."
mkdir -p ~/Drosera-Network
cd ~/Drosera-Network
cat << EOF > .env
ETH_PRIVATE_KEY=$OPERATOR1_PRIVATE_KEY
ETH_PRIVATE_KEY2=$OPERATOR2_PRIVATE_KEY
VPS_IP=$VPS_IP
P2P_PORT1=31313
SERVER_PORT1=31314
P2P_PORT2=31315
SERVER_PORT2=31316
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
docker compose up -d
check_status "Docker Operators setup"
echo "Checking Operators health..."
docker logs -f drosera-node1
docker logs -f drosera-node2

echo "Drosera Network Testnet Setup Complete for Two Operators!"
echo "Check the Drosera dashboard at https://app.drosera.io/ for green blocks indicating node liveness."
echo "Follow me on Twitter for more: https://x.com/0xCrypton_"

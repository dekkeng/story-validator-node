#!/bin/bash

# Story Validator Installer Script
# Spec: 4 Core, 8GB RAM, 200GB SSD

# Exit on error
set -e

# Function to print colored output
print_color() {
    COLOR='\033[0;32m'
    NC='\033[0m'
    printf "${COLOR}$1${NC}\n"
}

# 1. Update and install necessary packages
print_color "Step 1: Updating system and installing necessary packages..."
sudo apt update
sudo apt install curl git make jq build-essential gcc unzip wget lz4 aria2 -y
sudo apt update && sudo apt -y upgrade

# 2. Download and install node files
print_color "Step 2: Downloading and installing node files..."
wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
tar -xzvf geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
[ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
if ! grep -q "$HOME/go/bin" $HOME/.bash_profile; then
  echo 'export PATH=$PATH:$HOME/go/bin' >> $HOME/.bash_profile
fi
sudo cp geth-linux-amd64-0.9.2-ea9f0d2/geth $HOME/go/bin/story-geth

wget https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.9.11-2a25df1.tar.gz
tar -xzvf story-linux-amd64-0.9.11-2a25df1.tar.gz
sudo cp story-linux-amd64-0.9.11-2a25df1/story $HOME/go/bin/story

# 3. Update bash profile
print_color "Step 3: Updating bash profile..."
source $HOME/.bash_profile

# 4. Initialize Story node
print_color "Step 4: Initializing Story node..."
read -p "Enter your moniker (node name): " MONIKER
story init --network iliad --moniker "$MONIKER"
story init --network iliad

# 5. Create story-geth service
print_color "Step 5: Creating story-geth service..."
sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target
[Service]
User=root
ExecStart=/root/go/bin/story-geth --iliad --syncmode full
Restart=on-failure
RestartSec=3
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOF

# 6. Create story service
print_color "Step 6: Creating story service..."
sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target
[Service]
User=root
ExecStart=/root/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOF

# 7. Start services and update peers
print_color "Step 7: Starting services and updating peers..."
sudo systemctl daemon-reload
sudo systemctl start story-geth
sudo systemctl enable story-geth
sudo systemctl start story
sudo systemctl enable story

sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$(curl -sS https://story-testnet-rpc.polkachu.com/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd, -)\"/" $HOME/.story/story/config/config.toml

sudo systemctl restart story
sudo systemctl restart story-geth

# 8. Check service status
print_color "Step 8: Checking service status..."
echo "Checking story-geth status..."
sudo journalctl -u story-geth -n 20 -o cat
echo "Checking story status..."
sudo journalctl -u story -n 20 -o cat

# 9. Wait for sync
print_color "Step 9: Waiting for sync..."
while true; do
    sync_status=$(curl -s localhost:26657/status | jq -r '.result.sync_info.catching_up')
    if [ "$sync_status" = "false" ]; then
        echo "Node is synced!"
        break
    else
        echo "Node is still syncing. Current block height: $(curl -s localhost:26657/status | jq -r '.result.sync_info.latest_block_height')"
        echo "Please check https://testnet.story.explorers.guru/ for the latest block height."
        sleep 60
    fi
done

# 10. Export validator keys
print_color "Step 10: Exporting validator keys..."
story validator export --export-evm-key
cat /root/.story/story/config/private_key.txt

# 11. Prompt user to get faucet funds
print_color "Step 11: Getting faucet funds..."
echo "Please visit https://docs.story.foundation/docs/faucet to request faucet funds for your address."
read -p "Press enter when you have received the funds."

# 12. Create validator
print_color "Step 12: Creating validator..."
story validator create --stake 500000000000000000

# 13. Display validator address
print_color "Step 13: Displaying validator address..."
cd ~/.story/story/config
cat priv_validator_key.json | grep address

# 14. Final instructions
print_color "Step 14: Final instructions..."
echo "Please use the validator address above to check your node status at https://testnet.story.explorers.guru/"

print_color "Installation complete! Your Story validator node is now set up and running."
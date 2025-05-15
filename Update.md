```

cd ~
cd ~/Drosera-Network
docker compose down -v

pkill -f drosera-operator

sudo systemctl stop drosera
sudo systemctl disable drosera

cd ~
curl -LO https://github.com/drosera-network/releases/releases/download/v1.17.2/drosera-operator-v1.17.2-x86_64-unknown-linux-gnu.tar.gz
tar -xvf drosera-operator-v1.17.2-x86_64-unknown-linux-gnu.tar.gz
sudo cp drosera-operator /usr/bin
drosera-operator --version

docker pull ghcr.io/drosera-network/drosera-operator:latest

cd && cd my-drosera-trap
sed -i '/^drosera_team =/d' drosera.toml && sed -i '2i drosera_rpc = "https://relayer.testnet.drosera.io/"' drosera.toml

curl -L https://app.drosera.io/install | bash

cd && cd my-drosera-trap && source /root/.bashrc && drosera dryrun

```

Put Your Private key 

```
DROSERA_PRIVATE_KEY=your_private_key drosera apply
```

```
# Restart node
cd && cd Drosera-Network
docker compose up -d && cd

```

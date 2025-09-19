# **Automated Geth Clique PoA Private Blockchain Network Toolkit**

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/Maulana-anjari/blockchain-poa-geth)

### (v1.13.15) with Docker, Clef External Signer, and Integrated Monitoring

## **Introduction**

Welcome to a repository for building a private Ethereum blockchain network using the Clique Proof of Authority (PoA) consensus mechanism. This project provides a set of scripts to **fully automate** the process of creating, configuring, and managing the network. The goal is to eliminate complex and error-prone manual steps, allowing you to focus on development and testing.

This setup features a modern and secure architecture, **separating the signers from the Geth nodes** by using **Clef** as an external signer. The entire infrastructure, including a **dynamic number of nodes**, Clef instances, and a monitoring stack (Ethstats, InfluxDB, Grafana), is automatically orchestrated using **Docker and Docker Compose**.

**✨ Key Features:**

- **Fully Automated Setup:** A single command prepares the entire network.
- **Dynamic Configuration:** Easily change the number of signers and non-signers via a single configuration file (`config.sh`).
- **Secure by Design:** Implements Clef with strict signing rules (`rules.js`) to protect validator accounts.
- **Integrated Monitoring:** Out-of-the-box Ethstats and Grafana dashboards are set up automatically.
- **Reproducibility & Portability:** Thanks to Docker, the same network can be created anywhere with consistent results.

**Target Audience:** Intermediate-level developers or DevOps Engineers with a basic understanding of:

- Blockchain and Ethereum concepts (PoA, Nodes, Accounts).
- Linux Command Line Interface (CLI).
- Docker and Docker Compose fundamentals.

**Technology Stack:**

- **Geth:** `1.13.15` (via `ethereum/client-go:alltools-v1.13.15` Docker image)
- **Consensus:** Clique Proof of Authority (PoA)
- **External Signer:** Clef `1.13.15`
- **Automation:** Bash, Expect, `jq`
- **Orchestration:** Docker & Docker Compose
- **Monitoring:** Ethstats, InfluxDB v1.8, Grafana

## **Network Architecture**

This system will dynamically generate the following architecture:

- **Geth Nodes:**
  - **Signer Nodes (Dynamic Count):** Responsible for validating new blocks. Each signer is paired with its own Clef instance.
  - **Non-Signer Nodes (Dynamic Count):** Act as regular RPC nodes. The `nonsigner1` node is automatically designated as the primary **Bootnode**.
- **Clef Instances:** One instance for each signer node, running in a separate container for key isolation.
- **Monitoring Services:** Ethstats, InfluxDB, and Grafana, each in its own container.
- All components are connected within the same internal Docker network for seamless communication.

## **Quick Start Guide**

Forget the long manual process. Here’s how to get your network running in minutes.

### **Step 1: Prerequisites**

Ensure the following software is installed on your host system (e.g., Ubuntu or WSL):

1.  **Docker Engine** (v24.0+)
2.  **Docker Compose** (supporting Compose spec v3.7+)
3.  **Git**
4.  **jq** (Required for JSON processing): `sudo apt-get install jq`
5.  **(Optional) curl:** Useful for testing.

### **Step 2: Clone the Repository**

```bash
git clone https://github.com/Maulana-anjari/blockchain-poa-geth.git
cd blockchain-poa-geth
```

### **Step 3: Configure the Network**

This is the **only manual configuration step** you need to perform. Open and edit the `config.sh` file.

```bash
# File: config.sh

# --- Node Count Configuration ---
# Set how many signer and non-signer nodes you want.
export NUM_SIGNERS=3
export NUM_NONSIGNERS=2

# --- Network & Secrets Configuration ---
export NETWORK_ID=477748
export COMPOSE_PROJECT_NAME="geth_poa_dynamic"

# A prefix is used for passwords to make them predictable yet unique per node.
export SIGNER_PASS_PREFIX="pass_signer_"
export NONSIGNER_PASS_PREFIX="pass_nonsigner_"

# Replace these with your own secrets for Ethstats, InfluxDB, and Grafana.
export ETHSTATS_WS_SECRET="YourSuperSecretEthstatsStringHere"
export INFLUXDB_PASSWORD="YourStrongInfluxDBPassword"
export GRAFANA_ADMIN_PASSWORD="YourStrongGrafanaAdminPassword"
# ... (other configurations can be left as default)
```
> 💡 **Tip:** Mirror the PoS topology naming by defining `POA_SIGNER_LABELS` and `POA_NONSIGNER_LABELS` in `.env`; the toolkit will reuse those labels for container names and Ethstats IDs in order.


### **Step 4: Run the Automated Setup Script**

Execute this single command. The script will do all the heavy lifting for you.

```bash
chmod +x ./**/*.sh
./setup-network.sh
```

**What does this script do?**

- Cleans up any old setup.
- Creates all necessary directories.
- Generates Ethereum accounts and passwords for each node.
- Creates a `.env` file from your configuration.
- **Interactively** guides you through Clef initialization for each signer. You will be prompted for a password multiple times for each signer.
- Dynamically creates `genesis.json` with the correct signer addresses and fund allocations.
- Dynamically builds `docker-compose.yml` based on your configured node count.
- Temporarily starts the bootnode to retrieve its `enode`, then injects it into the configuration for all other nodes.

### **Step 5: Start the Network**

Once the setup script is complete, bring the entire network to life with Docker Compose.

```bash
# --build is required for the first run or if Dockerfile.clef changes.
docker-compose up -d --build
```

Your network is now running! Allow a few minutes for the nodes to connect and begin producing blocks.

## **Verifying and Managing the Network**

#### **Checking Logs**

Use the `docker-compose logs` command to monitor activity:

```bash
# Follow the logs from all services (press Ctrl+C to exit)
docker-compose logs -f

# Follow logs from a specific service (e.g., signer1 or clef1)
docker-compose logs -f signer1
docker-compose logs -f clef1
```

In the `clef1` logs, you should see `Approved clique header signing for block...` messages, confirming that the automation is working.

#### **Accessing the Monitoring Dashboards**

- **Ethstats**: Open `http://localhost:8080` in your browser.
- **Grafana**: Open `http://localhost:3000` in your browser.
  - Log in with `admin` / the password you set in `config.sh`.
  - On first use, you will need to add the InfluxDB datasource and import a Geth dashboard (ID: `13136`).

#### **Interacting via the Geth Console**

Attach to any node's Geth console to execute commands:

```bash
# Attach to the bootnode (nonsigner1)
docker-compose exec nonsigner1 geth attach
```

Inside the Geth console:

```javascript
> eth.blockNumber          // Should increase every ~15 seconds
> net.peerCount            // Should approach (Total Nodes - 1)
> clique.getSigners()      // Should return your list of signer addresses
```

## **Stopping and Cleaning Up the Network**

#### **Stopping the Network**

To stop all containers without deleting data:

```bash
docker-compose down
```

#### **Destroying the Network (Full Cleanup)**

To stop containers **AND DELETE ALL DATA** (chaindata, configurations, etc.) to start fresh, use the `destroy-network.sh` script:

```bash
./destroy-network.sh
```

## **How the Automation Works (Technical Details)**

For the curious, the magic happens thanks to these scripts:

- `config.sh`: The central control panel for all variables.
- `setup-network.sh`: The main orchestrator that runs all preparation tasks.
- `destroy-network.sh`: Cleans up all generated artifacts.
- `generate-genesis.sh`: Uses `jq` and a template to create a valid `genesis.json` dynamically.
- `generate-compose.sh`: Uses `bash` loops to build a `docker-compose.yml` file with the correct number of services.
- `Dockerfile.clef`: Creates a custom Docker image for Clef that includes the `expect` utility.
- `start-clef.sh`: An `expect` script that automatically handles Clef's interactive startup prompts.
- `rules.js`: A JavaScript ruleset that instructs Clef to only approve PoA block signing requests.

---

Congratulations! You now have a powerful toolkit for experimenting with Ethereum PoA networks. This architecture provides a solid foundation for DApp development, testing, and benchmarking.

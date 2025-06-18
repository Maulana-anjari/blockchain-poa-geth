#!/usr/bin/expect -f
# File: scripts/start-clef.sh
# This script automates the startup of a Clef signer instance, making it suitable for non-interactive
# environments like a Docker container.

# Retrieve the master password from an environment variable.
# This is a best practice for passing secrets to containers, typically set in the docker-compose.yml file.
set clef_master_password $env(CLEF_MASTER_PASSWORD)

# Retrieve other required configuration from environment variables.
set chain_id $env(NETWORK_ID)
set keystore_path "/root/.ethereum/keystore"
set config_dir "/root/.clef"
set rules_path "/root/rules.js"

# Set an infinite timeout to prevent the script from exiting if Clef is slow to start.
set timeout -1

# Spawn the Clef process with the necessary parameters.
# --suppress-bootwarn is added for cleaner logs on startup.
spawn clef \
    --keystore $keystore_path \
    --configdir $config_dir \
    --chainid $chain_id \
    --rules $rules_path \
    --nousb \
    --advanced \
    --http --http.addr 0.0.0.0 --http.port 8550 --http.vhosts "*" \
    --suppress-bootwarn

# --- Automation Sequence ---
# The following block automates the interaction with Clef's startup prompts.

# 1. Expect the master seed password prompt.
expect "Please enter the password to decrypt the master seed"
#    Send the password retrieved from the environment variable.
send "$clef_master_password\n"

# 2. Expect the confirmation prompt, which appears due to the --advanced flag.
expect "Enter 'ok' to proceed:"
#    Send "ok" to proceed.
send "ok\n"

# 3. Expect a potential prompt to approve an account for signing. This may appear on first run.
expect "Approve? \[y/N\]:"
#    Send "y" to approve it.
send "y\n"

# Hand control over to the Clef process and wait for it to terminate (EOF - End Of File).
# This is crucial; it keeps this script running, which in turn keeps the Docker container alive.
# The Clef process effectively becomes the foreground process of the container.
expect eof
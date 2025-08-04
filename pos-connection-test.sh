#!/bin/bash
# File: pos-connection-test.sh
# Final robust version that avoids using jq for simple counting.

set -e

# --- Load Dependencies ---
if [ ! -f "./scripts/logger.sh" ] || [ ! -f "./config.sh" ]; then
    echo "ERROR: Missing required files: scripts/logger.sh or config.sh"
    echo "Please run this script from the project root directory."
    exit 1
fi
source ./scripts/logger.sh
source ./config.sh

#
# Tests the peer-to-peer connectivity between Execution Layer (Geth) nodes.
#
test_el_connectivity_pos() {
    log_step "TESTING: PoS EXECUTION LAYER (EL) CONNECTIVITY"

    if [ "$NETWORK_TYPE" != "PoS" ]; then
        log_error "This script is only for PoS networks. NETWORK_TYPE is set to '$NETWORK_TYPE'."
        exit 1
    fi

    local total_nodes=$((POS_VALIDATOR_COUNT + POS_NON_VALIDATOR_COUNT))
    local expected_peers=$((total_nodes - 1))
    local all_tests_passed=true

    if [ "$total_nodes" -le 1 ]; then
        log_info "Only one EL node exists. No peer connectivity test needed."
        return
    fi

    log_action "Expecting each of the $total_nodes nodes to have $expected_peers peers."

    for i in $(seq 1 $total_nodes); do
        local node_name="execution_node$i"
        local ipc_path="/data/geth.ipc"
        
        log_info "Checking peers for $node_name..."

        # Get the raw output. Use -i for compatibility.
        local peers_output
        peers_output=$(docker exec -i "$node_name" geth --exec "admin.peers" attach "$ipc_path" 2>/dev/null || true)

        # Count peers by counting the occurrences of "enode:". This is simpler and more robust than parsing JSON with a buggy jq.
        local peer_count
        peer_count=$(echo "$peers_output" | grep -c "enode:")

        if [ "$peer_count" -ge "$expected_peers" ]; then
            log_success "$node_name has $peer_count from $expected_peers peers expected."
        else
            echo "$node_name has $peer_count peers, but expected $expected_peers."
            all_tests_passed=false
        fi
    done

    echo # Add a newline for readability

    if [ "$all_tests_passed" = true ]; then
        log_success "✅ All PoS EL connectivity tests passed!"
    else
        log_error "❌ Some PoS EL connectivity tests failed."
        exit 1
    fi
}


#
# Main execution function.
#
main() {
    log_step "STARTING PoS CONNECTION TESTS"
    test_el_connectivity_pos
    log_step "ALL PoS CONNECTION TESTS COMPLETE"
}

# --- Script Entrypoint ---
main

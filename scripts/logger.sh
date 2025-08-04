#!/bin/bash
# File: scripts/logger.sh
# Provides standardized, colored logging functions for other scripts.

# --- Color Definitions ---
C_BLUE='\033[1;34m'
C_GREEN='\033[1;32m'
C_RED='\033[1;31m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_NC='\033[0m' # No Color

# --- Logging Functions ---

# log_step: Prints a major phase/step header.
# Usage: log_step "PHASE 1: PREPARATION"
log_step() {
    echo -e "\n${C_BLUE}=======================================================${C_NC}"
    echo -e "${C_BLUE}  $1 ${C_NC}"
    echo -e "${C_BLUE}=======================================================${C_NC}"
}

# log_action: Prints a specific action being taken.
# Usage: log_action "Generating accounts"
log_action() {
    echo -e "${C_YELLOW}► $1...${C_NC}"
}

# log_success: Prints a success message.
# Usage: log_success "Accounts generated successfully."
log_success() {
    echo -e "${C_GREEN}✅ $1${C_NC}"
}

# log_error: Prints an error message and exits the script.
# Usage: log_error "Required file not found."
log_error() {
    echo -e "${C_RED}❌ ERROR: $1${C_NC}" >&2
    exit 1
}

# log_info: Prints an informational message.
# Usage: log_info "Network Type is set to PoA."
log_info() {
    echo -e "${C_CYAN}ℹ️  $1${C_NC}"
}

# log_warn: Prints a warning message.
# Usage: log_warn "Configuration value is not optimal."
log_warn() {
    echo -e "${C_YELLOW}⚠️  WARNING: $1${C_NC}" >&2
}

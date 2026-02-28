#!/bin/bash
# ==============================================================================
# LIBRARY: LOGGING & UI (V5)
# ==============================================================================
# This module provides standardized, color-coded logging functions to ensure
# students have clear visual feedback on the deployment progress.
# ==============================================================================

# Define color codes for terminal output
readonly COLOR_RESET='\e[0m'
readonly COLOR_INFO='\e[1;34m'    # Bold Blue
readonly COLOR_SUCCESS='\e[1;32m' # Bold Green
readonly COLOR_WARNING='\e[1;33m' # Bold Yellow
readonly COLOR_ERROR='\e[1;31m'   # Bold Red
readonly COLOR_PROMPT='\e[1;35m'  # Bold Magenta

# Prints an informational message (e.g., starting a new task)
log_info() {
    echo -e "${COLOR_INFO}[*] INFO:${COLOR_RESET} $1"
}

# Prints a success message (e.g., task completed)
log_success() {
    echo -e "${COLOR_SUCCESS}[+] SUCCESS:${COLOR_RESET} $1"
}

# Prints a warning message (non-fatal issue)
log_warn() {
    echo -e "${COLOR_WARNING}[!] WARNING:${COLOR_RESET} $1"
}

# Prints an error message and optionally exits the script
log_error() {
    echo -e "${COLOR_ERROR}[X] ERROR:${COLOR_RESET} $1" >&2
}

# Prints a fatal error message and immediately stops script execution
die() {
    echo -e "${COLOR_ERROR}[X] FATAL:${COLOR_RESET} $1" >&2
    exit 1
}

# Prompts the user for a Yes/No confirmation
# Returns 0 for Yes, 1 for No
prompt_confirm() {
    local prompt_msg="$1"
    while true; do
        echo -ne "${COLOR_PROMPT}[?] ${prompt_msg} (y/n): ${COLOR_RESET}"
        read -r yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

# Pauses execution and waits for the user to press Enter
pause_for_user() {
    local pause_msg="${1:-Press [Enter] to continue...}"
    echo -ne "${COLOR_PROMPT}[>>>] ${pause_msg}${COLOR_RESET}"
    read -r
}

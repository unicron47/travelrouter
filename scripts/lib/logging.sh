#!/bin/bash
# ==============================================================================
# LIBRARY: LOGGING & UI (V5)
# ==============================================================================
readonly COLOR_RESET='\e[0m'
readonly COLOR_INFO='\e[1;34m'
readonly COLOR_SUCCESS='\e[1;32m'
readonly COLOR_WARNING='\e[1;33m'
readonly COLOR_ERROR='\e[1;31m'
readonly COLOR_PROMPT='\e[1;35m'

log_info()    { echo -e "${COLOR_INFO}[*] INFO:${COLOR_RESET} $1"; }
log_success() { echo -e "${COLOR_SUCCESS}[+] SUCCESS:${COLOR_RESET} $1"; }
log_warn()    { echo -e "${COLOR_WARNING}[!] WARNING:${COLOR_RESET} $1"; }
log_error()   { echo -e "${COLOR_ERROR}[X] ERROR:${COLOR_RESET} $1" >&2; }
die()         { echo -e "${COLOR_ERROR}[X] FATAL:${COLOR_RESET} $1" >&2; exit 1; }

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

pause_for_user() {
    local pause_msg="${1:-Press [Enter] to continue...}"
    echo -ne "${COLOR_PROMPT}[>>>] ${pause_msg}${COLOR_RESET}"
    read -r
}

# Prevents destructive actions during dry-run simulation.
# Requires DRY_RUN to be exported by the calling script.
exec_or_log() {
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log_info "[DRY-RUN] Would execute: $*"
    else
        "$@"
    fi
}

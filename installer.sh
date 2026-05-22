#!/bin/bash

# === Configuration & Constants ===
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly LOG_FILE="$SCRIPT_DIR/install_wayfire_$(date +%F_%T).log"
readonly MAX_RETRIES=3

# === Global Variables ===
FAILED=false
DRY_RUN=false
AUTO_YES=false
THEME="TokyoNight-Dark"
INSTALL_ALL=true
SKIP_WALLPAPERS=false
INSTALL_GNOME=false
TEMP_DIR=""

# === Colors ===
readonly RED='\033[0;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly NC='\033[0m'

export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"

# === Logging & Output ===
log() { echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR]${NC} $*" | tee -a "$LOG_FILE"; }
fatal() { error "$1"; exit 1; }
progress() { echo -ne "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] [PROGRESS]${NC} $*\r"; }

header() {
    echo -e "\n${BLUE}=== $1 ===${NC}\n"
    log "Starting $1"
}

run() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
        return 0
    fi
    progress "Executing: $*"
    if ! eval "$*"; then
        error "Command failed: $*"
        return 1
    fi
    log "Successfully executed: $*"
    return 0
}

retry() {
    local cmd="$1"
    local retries=${2:-$MAX_RETRIES}
    local delay=5
    for ((i=1; i<=retries; i++)); do
        if eval "$cmd"; then return 0; fi
        warn "Attempt $i/$retries failed. Retrying in $delay seconds..."
        sleep "$delay"
        ((delay+=5))
    done
    return 1
}

confirm() {
    if [ "$AUTO_YES" = true ] || [ "$DRY_RUN" = true ]; then
        log "[AUTO-YES/DRY-RUN] Auto-confirming: $1"
        return 0
    fi
    local prompt="$1"
    local default=${2:-N}
    while true; do
        read -r -p "$(echo -e "${YELLOW}$prompt ($default): ${NC}")" REPLY
        case $REPLY in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) [ "$default" = "Y" ] && return 0 || return 1;;
        esac
    done
}

# === Cleanup Handler ===
cleanup() {
    local exit_code=$?
    echo -e "\n${BLUE}=== Cleaning up ===${NC}"
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        run

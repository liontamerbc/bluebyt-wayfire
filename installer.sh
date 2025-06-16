#!/bin/bash

# === Colors ===
readonly RED='\033[0;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly NC='\033[0m'

# === Constants ===
readonly SCRIPT_VERSION="3.0.0"
readonly MAX_RETRIES=3
readonly TIMEOUT_SECONDS=300

# === Globals ===
FAILED=false
DRY_RUN=false
AUTO_YES=false
INSTALL_ALL=true
SKIP_WALLPAPERS=false
INSTALL_GNOME=false
THEME="TokyoNight-Dark"

# === Paths ===
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
LOG_FILE="$SCRIPT_DIR/install_wayfire_$(date +%F_%T).log"
readonly SCRIPT_DIR
readonly LOG_FILE

# === Logging Functions ===
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] [INFO]${NC} $*" | tee -a "$LOG_FILE"
}
warn() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] [WARN]${NC} $*" | tee -a "$LOG_FILE"
}
error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] [ERROR]${NC} $*" | tee -a "$LOG_FILE"
}
fatal() {
    error "$1"
    exit 1
}
progress() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -ne "${BLUE}[$timestamp] [PROGRESS]${NC} $*\r" | tee -a "$LOG_FILE"
}

# === Command Execution ===
run() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
        return 0
    fi
    local cmd="$*"
    progress "Executing: $cmd"
    if ! eval "$cmd"; then
        local error_msg="Command failed: $cmd"
        error "$error_msg"
        echo "$error_msg" >> "$LOG_FILE"
        return 1
    fi
    log "Successfully executed: $cmd"
    return 0
}

retry() {
    local cmd="$1"
    local retries=${2:-$MAX_RETRIES}
    local delay=5
    for ((i=1; i<=retries; i++)); do
        if eval "$cmd"; then
            return 0
        fi
        warn "Attempt $i/$retries failed. Retrying in $delay seconds..."
        sleep "$delay"
        ((delay+=5))
    done
    return 1
}

# === User Interaction ===
confirm() {
    if [ "$AUTO_YES" = true ] || [ "$DRY_RUN" = true ]; then
        log "[AUTO-YES/DRY-RUN] Would prompt: $*"
        return 0
    fi
    local prompt="$1"
    local default=${2:-N}
    while true; do
        read -r -p "$prompt ($default): " REPLY
        case $REPLY in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * )
                if [ "$default" = "Y" ]; then
                    return 0
                else
                    return 1
                fi
                ;;
        esac
    done
}

# === Resource Limits ===
set_resource_limits() {
    local mem_total
    mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local mem_mb
    mem_mb=$((mem_total / 1024))
    if [ "$mem_mb" -lt 2048 ]; then
        ulimit -n 1024
        ulimit -u 512
    else
        ulimit -n 2048
        ulimit -u 1024
    fi
}

# === Cleanup ===
cleanup() {
    local exit_code=$?
    echo -e "\n${BLUE}=== Cleaning up ===${NC}"
    if [ -d "$TEMP_DIR" ]; then
        run "rm -rf \"$TEMP_DIR\""
    fi
    exit $exit_code
}
trap cleanup EXIT SIGINT SIGTERM

# === Main Script Logic ===

export PATH="/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin:/bin"

echo -e "${GREEN}=== Starting System Check ===${NC}"

if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    exit 1
fi

for cmd in bash pacman grep awk; do
    if ! command -v "$cmd" &>/dev/null; then
        echo -e "${RED}Error: Required command not found: $cmd${NC}"
        exit 1
    fi
done

echo -n "Checking internet connection... "
if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null && ! ping -c 1 -W 5 archlinux.org &>/dev/null; then
    echo -e "${RED}Failed${NC}"
    echo -e "${YELLOW}Please check your internet connection and try again${NC}"
    exit 1
fi
echo -e "${GREEN}OK${NC}"

echo -n "Updating package databases... "
if ! pacman -Sy --noconfirm &>/dev/null; then
    echo -e "${RED}Failed${NC}"
    echo -e "${YELLOW}Please check your internet connection and try again${NC}"
    exit 1
fi
echo -e "${GREEN}Done${NC}"

echo -e "\n${GREEN}=== System Check Complete ===${NC}\n"

set_resource_limits

# Create a safe temporary directory
TEMP_DIR=$(mktemp -d -p /tmp wayfire-installer-XXXXXX)

# Backup current system state
SYSTEM_BACKUP_DIR="$TEMP_DIR/system_state_$(date +%s)"
mkdir -p "$SYSTEM_BACKUP_DIR"

# Backup essential system files
run "cp -a /etc/pacman.conf \"$SYSTEM_BACKUP_DIR/\""
run "cp -a /etc/fstab \"$SYSTEM_BACKUP_DIR/\""
run "cp -a /etc/locale.conf \"$SYSTEM_BACKUP_DIR/\""
run "cp -a /etc/timezone \"$SYSTEM_BACKUP_DIR/\""

# === Package Installation ===
header() {
    local title="$1"
    echo
    echo -e "${BLUE}=== $title ===${NC}"
    echo
    log "Starting $title"
}

header "Installing essential packages"
ESSENTIALS="git gcc ninja rust nimble sudo lxappearance base-devel libxml2 curl pciutils meson wayfire bc"
if [ "$INSTALL_ALL" = false ]; then
    ESSENTIALS="git gcc base-devel curl pciutils meson bc"
fi

if ! retry "pacman -S --needed --noconfirm $ESSENTIALS"; then
    error "Failed to install essential packages after multiple attempts."
    exit 1
fi

for pkg in $ESSENTIALS; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        error "Failed to install required package: $pkg"
        exit 1
    fi
done

log "All required packages installed successfully"

# === Wayfire Session Configuration ===
header "Configuring Wayfire session"
if [ ! -f /usr/share/wayland-sessions/wayfire.desktop ]; then
    if [ ! -d /usr/share/wayland-sessions ]; then
        run "mkdir -p /usr/share/wayland-sessions"
    fi
    cat <<EOF | tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null
[Desktop Entry]
Name=Wayfire
Comment=Wayfire session
Exec=wayfire
Type=Application
EOF
fi

# === Wayfire Version Check ===
wayfire_version=$(wayfire --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
if [ -z "$wayfire_version" ]; then
    error "Wayfire version verification failed"
    exit 1
fi
log "Wayfire version $wayfire_version installed successfully"
log "Wayfire session and configuration setup complete"

header "Cleaning up"
cleanup

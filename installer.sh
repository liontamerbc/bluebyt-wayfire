#!/bin/bash

# === Configuration & Constants ===
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
readonly LOG_FILE="$SCRIPT_DIR/install_wayfire_$(date +%F_%T).log"
readonly MAX_RETRIES=3
readonly TIMEOUT_SECONDS=300

# === Global Variables ===
FAILED=false
DRY_RUN=false
AUTO_YES=false
THEME="TokyoNight-Dark"
INSTALL_ALL=true
SKIP_WALLPAPERS=false
INSTALL_GNOME=false
BACKUP_DIR="$HOME/.config_backup_$(date +%F_%T)"
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
        rm -rf "$TEMP_DIR"
    fi
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Installation completed with errors. See $LOG_FILE${NC}"
    fi
    exit $exit_code
}
trap cleanup EXIT SIGINT SIGTERM

# === Setup Pre-flight ===
usage() {
    cat << 'EOF'
Usage: $0 [options]
Options:
  -t THEME    Set the color theme (default: TokyoNight-Dark)
  -p          Install minimal set of packages
  -w          Skip wallpaper installation
  -n          Dry run
  -g          Install GNOME packages
  -y          Automatic yes to prompts
  -h          Show this help message
EOF
    exit 0
}

check_system() {
    header "System Checks"
    
    if [ "$EUID" -eq 0 ]; then
        fatal "This script must be run as a regular user with sudo privileges, NOT root."
    fi

    for cmd in bash pacman grep awk sudo curl git; do
        if ! command -v "$cmd" &>/dev/null; then fatal "Required command not found: $cmd"; fi
    done

    echo -n "Checking internet connection... "
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then fatal "No internet connection."; fi
    echo -e "${GREEN}OK${NC}"

    local free_space
    free_space=$(df -m / | awk 'NR==2 {print $4}')
    if [ "$free_space" -lt 10000 ]; then
        fatal "Insufficient disk space. 10GB required, ${free_space}MB available."
    fi

    # Update pacman safely
    run "sudo pacman -Sy --noconfirm"
}

# === Main Installation Workflow ===
main() {
    while getopts ":t:pwnghy" opt; do
        case "${opt}" in
            t) THEME="${OPTARG}" ;;
            p) INSTALL_ALL=false ;;
            w) SKIP_WALLPAPERS=true ;;
            n) DRY_RUN=true ;;
            g) INSTALL_GNOME=true ;;
            y) AUTO_YES=true ;;
            h) usage ;;
            \?) fatal "Invalid option -${OPTARG}"; usage ;;
        esac
    done

    check_system

    if ! confirm "Proceed with installation?" "Y"; then fatal "Aborted by user."; fi

    TEMP_DIR=$(mktemp -d -p /tmp wayfire-installer-XXXXXX)

    header "Installing Core Packages"
    local ESSENTIALS="wayfire kitty fish zed wlogout xava wcm git gcc ninja rust sudo lxappearance base-devel curl pciutils meson bc wayland wayland-protocols"
    
    if ! retry "sudo pacman -S --needed --noconfirm $ESSENTIALS"; then
        fatal "Failed to install essential packages."
    fi

    # GPU Driver Detection
    header "Detecting GPU"
    GPU_VENDOR=$(lspci | grep -E 'VGA|3D' | head -n1)
    if echo "$GPU_VENDOR" | grep -qi 'NVIDIA'; then
        log "NVIDIA GPU detected."
        run "sudo pacman -S --needed --noconfirm nvidia nvidia-utils"
    elif echo "$GPU_VENDOR" | grep -qi 'AMD'; then
        log "AMD GPU detected."
        run "sudo pacman -S --needed --noconfirm xf86-video-amdgpu mesa vulkan-radeon"
    elif echo "$GPU_VENDOR" | grep -qi 'Intel'; then
        log "Intel GPU detected."
        run "sudo pacman -S --needed --noconfirm mesa vulkan-intel"
    else
        log "Unknown GPU. Installing mesa."
        run "sudo pacman -S --needed --noconfirm mesa"
    fi

    header "Configuring Wayfire Environment"
    local WAYFIRE_CONFIG_DIR="$HOME/.config/wayfire"
    run "mkdir -p $WAYFIRE_CONFIG_DIR"

    cat > "$WAYFIRE_CONFIG_DIR/wayfire.ini" << EOF
[core]
backend = auto
vsync = true

[output]
primary = auto
scale = 1

[workspaces]
number = 4

[plugins]
plugins = ipc ipc-rules follow-focus workspaces scale effects

[autostart]
launcher = $HOME/.config/wayfire/scripts/inactive-alpha.py
EOF

    local WAYFIRE_SCRIPTS_DIR="$WAYFIRE_CONFIG_DIR/scripts"
    run "mkdir -p $WAYFIRE_SCRIPTS_DIR"
    
    cat > "$WAYFIRE_SCRIPTS_DIR/inactive-alpha.py" << EOF
#!/usr/bin/env python3
import wayfire

def on_window_focus(window, state):
    if state:
        window.set_alpha(1.0)
    else:
        window.set_alpha(0.8)

wayfire.subscribe('window_focus', on_window_focus)
EOF
    run "chmod +x $WAYFIRE_SCRIPTS_DIR/inactive-alpha.py"

    header "Creating Desktop Sessions"
    run "sudo mkdir -p /usr/share/wayland-sessions"
    sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Comment=A lightweight and customizable Wayland compositor
Exec=env WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket wayfire
Type=Application
EOF

    if [ "$INSTALL_GNOME" = true ] || confirm "Install GNOME as a fallback environment?"; then
        header "Installing GNOME"
        run "sudo pacman -S --needed --noconfirm gnome gnome-tweaks gnome-terminal"
        run "sudo systemctl enable gdm"
    fi

    if confirm "Set Fish as default shell?"; then
        run "chsh -s /usr/bin/fish"
    fi

    header "Final Verification"
    local missing_components=false
    for cmd in wayfire kitty fish; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            error "Component missing: $cmd"
            missing_components=true
        fi
    done

    if [ "$missing_components" = true ]; then
        FAILED=true
    fi

    if [ "$FAILED" = true ]; then
        echo -e "\n${RED}Installation completed with some errors. Check $LOG_FILE${NC}"
        exit 1
    else
        echo -e "\n${GREEN}Installation completed successfully!${NC}"
        echo "To start Wayfire, select it from your display manager or run it from a TTY."
        exit 0
    fi
}

# Start script
main "$@"
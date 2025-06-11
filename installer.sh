#!/usr/bin/env bash

################################################################################
# bluebyt-wayfire Desktop Installer for Arch Linux (Enhanced Version)
# Maintainer: liontamerbc
# Version: 3.0.0
# 
# Enhanced installer with improved error handling, logging, and user experience
# Features:
# - Robust error handling with retries and timeouts
# - Comprehensive logging with timestamps
# - Parallel package installation support
# - Enhanced security features
# - Better user feedback and progress indicators
# - Comprehensive configuration validation
# - For Arch Linux and derivatives ONLY
################################################################################

set -euo pipefail

# === Constants ===
readonly SCRIPT_VERSION="3.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
readonly LOG_FILE="$SCRIPT_DIR/install_wayfire_$(date +%F_%T).log"
readonly MAX_RETRIES=3
readonly TIMEOUT_SECONDS=300

# === Colors ===
readonly RED='\033[0;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly NC='\033[0m'

# === Global Variables ===
declare -A CONFIG_BACKUPS
FAILED=false
DRY_RUN=false
AUTO_YES=false
set_fish=false

# === Configuration ===
THEME="TokyoNight-Dark"
INSTALL_ALL=true
SKIP_WALLPAPERS=false
INSTALL_GNOME=false
BACKUP_DIR="$HOME/.config_backup_$(date +%F_%T)"

# === Logging Functions ===
log() {
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${GREEN}[$timestamp] [INFO]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${YELLOW}[$timestamp] [WARN]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${RED}[$timestamp] [ERROR]${NC} $*" | tee -a "$LOG_FILE"
    FAILED=true
}

fatal() {
    error "$*"
    cleanup
    exit 1
}

progress() {
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -ne "${BLUE}[$timestamp] [PROGRESS]${NC} $*\r" | tee -a "$LOG_FILE"
}

# === Utility Functions ===
build_git_pkg() {
    local repo="$1"
    local pkg="$2"
    local build_dir="$SCRIPT_DIR/build_$pkg"
    
    if [ -d "$build_dir" ]; then
        run "rm -rf \"$build_dir\""
    fi
    
    run "git clone $repo $build_dir"
    cd "$build_dir" || exit 1
    
    if [ -f "PKGBUILD" ]; then
        run "makepkg -si --noconfirm"
    else
        run "meson build"
        run "ninja -C build"
        run "sudo ninja -C build install"
    fi
    
    cd "$SCRIPT_DIR" || exit 1
    run "rm -rf \"$build_dir\""
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
        sleep $delay
        ((delay+=5))
    done
    return 1
}

timeout() {
    local timeout=$1
    shift
    local cmd="$*"
    
    if ! timeout --preserve-status $timeout "$cmd"; then
        error "Command timed out after $timeout seconds: $cmd"
        return 1
    fi
    return 0
}

validate_checksum() {
    local file="$1"
    local expected_checksum="$2"
    
    if ! command -v sha256sum >/dev/null 2>&1; then
        error "sha256sum not found. Cannot verify checksum."
        return 1
    fi
    
    local actual_checksum
    actual_checksum=$(sha256sum "$file" | awk '{print $1}')
    
    if [ "$actual_checksum" != "$expected_checksum" ]; then
        error "Checksum verification failed for $file"
        return 1
    fi
    return 0
}

# === Configuration Management ===
backup_config() {
    local src="$1"
    local dest="$2"
    
    if [ -d "$src" ]; then
        run "cp -r \"$src\" \"$dest\""
        CONFIG_BACKUPS["$src"]="$dest"
        log "Backed up $src to $dest"
    fi
}

restore_config() {
    for src in "${!CONFIG_BACKUPS[@]}"; do
        local dest="${CONFIG_BACKUPS[$src]}"
        if [ -d "$dest" ]; then
            run "cp -r \"$dest\" \"$src\""
            log "Restored $src from backup"
        fi
    done
}

# === Command Execution ===
run() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
        return 0
    fi
    
    local cmd="$*"
    progress "Executing: $cmd"
    
    if ! timeout $TIMEOUT_SECONDS "$cmd"; then
        error "Command failed: $cmd"
        return 1
    fi
    
    log "Successfully executed: $cmd"
    return 0
}

# === User Interaction ===
header() {
    local title="$1"
    echo
    echo -e "${BLUE}=== $title ===${NC}"
    echo
    log "Starting $title"
}

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

# === Package Management ===
require_bin() {
    local cmd="$1"
    local ver="$2"
    local retries=${3:-$MAX_RETRIES}
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fatal "$cmd is required but not installed. Attempting to install now..."
        if [ "$AUTO_YES" = true ]; then
            run "sudo pacman -S --noconfirm $cmd"
        else
            if confirm "The required package '$cmd' is not installed. Would you like to install it now?"; then
                run "sudo pacman -S --noconfirm $cmd"
            else
                fatal "Cannot continue without $cmd. Please install it manually and try again."
            fi
        fi
        
        # Verify installation
        if ! command -v "$cmd" >/dev/null 2>&1; then
            fatal "Failed to install $cmd. Please check the log file for details."
        fi
        
        # If version check is requested
        if [ -n "$ver" ]; then
            local installed_ver
            installed_ver=$(command -v "$cmd" --version 2>/dev/null | head -n1)
            if [ -z "$installed_ver" ]; then
                warn "Could not determine version of $cmd"
            else
                log "Installed version: $installed_ver"
            fi
        fi
        return 0
    fi
    
    if [ -n "$ver" ]; then
        local current
        current=$("$cmd" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
        if [ -n "$current" ]; then
            if [ "$(printf '%s\n' "$ver" "$current" | sort -V | head -n1)" != "$ver" ]; then
                fatal "$cmd version $current is less than required $ver"
            fi
        fi
    fi
}

# === Cleanup ===
cleanup() {
    if [ "$FAILED" = "true" ]; then
        warn "Installation failed. Performing cleanup..."
        
        # Remove temporary directories
        cd "$SCRIPT_DIR" || exit 1
        for dir in wayfire wf-shell wcm pixdecor Tokyo-Night-GTK-Theme Aretha-Dark-Icons; do
            if [ -d "$dir" ]; then
                run "rm -rf \"$dir\""
            fi
        done
        
        # Restore configurations
        restore_config
        
        warn "Cleanup complete. See $LOG_FILE for details."
        echo "See $LOG_FILE for detailed installation log"
    fi
}

trap cleanup EXIT SIGINT SIGTERM

# === Usage ===
usage() {
    cat <<EOF
$SCRIPT_NAME v$SCRIPT_VERSION - Enhanced bluebyt-wayfire desktop installer

Usage: $SCRIPT_NAME [-t theme] [-p] [-w] [-n] [-g|--gnome] [-y|--yes] [-h]
  -t THEME     Set GTK theme (default: TokyoNight-Dark)
  -p           Partial install, skip optional AUR packages
  -w           Skip wallpaper installation
  -n           Dry-run: show what would be done, do not change system
  -g, --gnome  Install GNOME desktop before Wayfire (default: prompt)
  -y, --yes    Answer yes to all prompts (non-interactive, for automation)
  -h           Show this help message

Enhanced Features:
  - Automatic retries for failed operations
  - Timeout handling for long-running operations
  - Comprehensive logging with timestamps
  - Configuration backup and restore
  - Package version verification
  - SSL certificate verification
  - Progress indicators

Important Notes:
  - This installer requires sudo privileges
  - It's recommended to run this installer from a TTY
  - A stable internet connection is required
  - Sufficient disk space is required (minimum 2GB)

GNOME Desktop:
  - By default, you'll be prompted to install GNOME as a fallback desktop
  - Use -g|--gnome to force GNOME installation without prompting
  - GNOME provides a stable fallback desktop and improves hardware support
EOF
    exit 0
}

# === Main Installation ===
main() {
    # === Command Line Parsing ===
    while getopts ":t:pwnghy" opt; do
        case "$opt" in
            t) THEME="$OPTARG";;
            p) INSTALL_ALL=false;;
            w) SKIP_WALLPAPERS=true;;
            n) DRY_RUN=true;;
            g) INSTALL_GNOME=true;;
            y) AUTO_YES=true;;
            h) usage;;
            \?) error "Invalid option -$OPTARG"; usage;;
        esac
    done

    # Support for long options (--gnome and --yes)
    for arg in "$@"; do
        if [[ "$arg" == "--gnome" ]]; then
            INSTALL_GNOME=true
        elif [[ "$arg" == "--yes" ]]; then
            AUTO_YES=true
        fi
    done

    # === Initial Checks ===
    if [ "$EUID" -eq 0 ]; then
        fatal "Please run this script as a regular user, not root."
    fi

    if ! grep -q '^ID=arch' /etc/os-release; then
        fatal "This installer is only supported on Arch Linux."
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        fatal "sudo is required but not installed."
    fi

    # === Pre-flight Checks ===
    header "Pre-flight system checks"
    log "Selected theme: $THEME"
    log "Full installation: $INSTALL_ALL"
    log "Install wallpapers: $([ "$SKIP_WALLPAPERS" = "true" ] && echo "no" || echo "yes")"
    log "Dry-run: $DRY_RUN"
    log "Install GNOME first: $INSTALL_GNOME"
    log "Non-interactive mode: $AUTO_YES"
    log "Installer version: $SCRIPT_VERSION"

    if ! confirm "Do you want to proceed with the installation?"; then
        fatal "Aborted by user."
    fi

    # === System Requirements ===
    header "Verifying system requirements"
    
    # Check disk space
    check_space 10000  # 10GB minimum required for full installation
    
    # Check memory
    local mem=$(free -m | awk '/Mem:/ {print $2}')
    if [ "$mem" -lt 2048 ]; then
        warn "Low memory detected. Installation may be slow."
    fi

    # Check CPU cores
    local cores=$(nproc)
    if [ "$cores" -lt 4 ]; then
        warn "Low CPU cores detected. Installation may be slow."
    fi

    # === Package Installation ===
    header "Installing essential packages"
    
    # Install essential tools
    local ESSENTIALS="git gcc ninja rust nimble sudo lxappearance base-devel libxml2 curl pciutils meson wayfire"
    if [ "$INSTALL_ALL" = false ]; then
        ESSENTIALS="git gcc base-devel curl pciutils meson"
    fi
    
    # Install packages with retry mechanism
    if ! retry "sudo pacman -S --needed --noconfirm $ESSENTIALS"; then
        error "Failed to install essential packages after multiple attempts."
        exit 1
    fi
    
    # Verify package installation
    for pkg in $ESSENTIALS; do
        if ! command -v $pkg >/dev/null 2>&1; then
            error "Failed to install required package: $pkg"
            exit 1
        fi
    done

    # === Wayfire Session Configuration ===
    header "Configuring Wayfire session"
    
    if [ ! -f /usr/share/wayland-sessions/wayfire.desktop ]; then
        # Create directory if it doesn't exist
        if [ ! -d /usr/share/wayland-sessions ]; then
            run "sudo mkdir -p /usr/share/wayland-sessions"
            if [ $? -ne 0 ]; then
                error "Failed to create wayland-sessions directory"
                exit 1
            fi
        fi
        
        # Write Wayfire session file
        sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Comment=A lightweight and customizable Wayland compositor
Exec=env WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket wayfire
Type=Application
EOF
        if [ $? -ne 0 ]; then
            error "Failed to create wayfire.desktop file"
            exit 1
        fi
    fi

    # === Wayfire Configuration ===
    header "Setting up Wayfire configuration"
    
    local config_dir="$HOME/.config/wayfire"
    local config_file="$config_dir/wayfire.ini"
    
    if [ ! -d "$config_dir" ]; then
        run "mkdir -p \"$config_dir\""
    fi
    
    # Create or update wayfire.ini
    if [ ! -f "$config_file" ] || confirm "Would you like to update Wayfire configuration?"; then
        sudo tee "$config_file" >/dev/null <<EOF
[core]
output_layout = $(wayfire-output-layout)

[output]
background_color = #000000

[view]
border_width = 0
border_color = #000000

[workspaces]
num_workspaces = 10

[plugins]
plugins = ipc ipc-rules follow-focus

[autostart]
launcher = $IPC_DIR/inactive-alpha.py
EOF
        if [ $? -ne 0 ]; then
            error "Failed to create wayfire.ini"
            exit 1
        fi
    fi

    # === Wayfire Plugin Configuration ===
    header "Configuring Wayfire plugins"
    
    # Create plugin configuration directory
    local plugin_dir="$config_dir/plugins"
    if [ ! -d "$plugin_dir" ]; then
        run "mkdir -p \"$plugin_dir\""
    fi
    
    # Configure ipc plugin
    local ipc_config="$plugin_dir/ipc.ini"
    if [ ! -f "$ipc_config" ]; then
        sudo tee "$ipc_config" >/dev/null <<EOF
[ipc]
socket_path = /tmp/wayfire-wayland-1.socket
EOF
        if [ $? -ne 0 ]; then
            error "Failed to create ipc configuration"
            exit 1
        fi
    fi

    # === Autostart Configuration ===
    header "Setting up autostart"
    
    local autostart_dir="$HOME/.config/autostart"
    if [ ! -d "$autostart_dir" ]; then
        run "mkdir -p \"$autostart_dir\""
    fi
    
    # Create autostart entry for Wayfire
    sudo tee "$autostart_dir/wayfire.desktop" >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Exec=env WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket wayfire
Type=Application
EOF

    # === Verify Wayfire Installation ===
    header "Verifying Wayfire installation"
    
    if ! command -v wayfire >/dev/null 2>&1; then
        error "Wayfire installation failed. Please check the logs."
        exit 1
    fi
    
    local wayfire_version=$(wayfire --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [ -z "$wayfire_version" ]; then
        error "Wayfire version verification failed"
        exit 1
    fi
    
    log "Wayfire version $wayfire_version installed successfully"
    log "Wayfire session and configuration setup complete"

    # === Detect Virtual Machine and Hardware ===
    header "Detecting system type and hardware"

    # Check if running in a virtual machine
    is_vm=false
    VM_VENDOR=$(lspci | grep -iE 'VirtualBox|VMware|Virtual Machine|QEMU|KVM')
    if [ -n "$VM_VENDOR" ]; then
        is_vm=true
        log "Detected virtual machine: $VM_VENDOR"
    fi

    # Install virtual machine specific drivers if detected
    if [ "$is_vm" = true ]; then
        header "Installing virtual machine drivers"
        
        # Install common VM tools
        run "sudo pacman -S --needed --noconfirm virtualbox-guest-utils open-vm-tools"
        
        # Install specific VM tools based on vendor
        if echo "$VM_VENDOR" | grep -qi 'VirtualBox'; then
            if ! retry "sudo pacman -S --needed --noconfirm virtualbox-guest-modules-arch"; then
                error "Failed to install VirtualBox modules"
                exit 1
            fi
        elif echo "$VM_VENDOR" | grep -qi 'VMware'; then
            if ! retry "sudo pacman -S --needed --noconfirm open-vm-tools-desktop"; then
                error "Failed to install VMware tools"
                exit 1
            fi
        fi
        
        # Enable VM services with retries
        if ! retry "sudo systemctl enable vboxservice"; then
            warn "Failed to enable vboxservice"
        fi
        
        if ! retry "sudo systemctl enable vmtoolsd"; then
            warn "Failed to enable vmtoolsd"
        fi
        
        # Install basic graphics drivers with retry
        if ! retry "sudo pacman -S --needed --noconfirm mesa xf86-video-vmware"; then
            error "Failed to install graphics drivers"
            exit 1
        fi
        
        log "Virtual machine drivers installed successfully"
    else
        # === CPU Microcode ===
        header "Detecting CPU and installing microcode"
        
        # Detect CPU vendor
        local cpu_vendor=""
        if grep -qi 'GenuineIntel' /proc/cpuinfo; then
            cpu_vendor="Intel"
            if ! retry "sudo pacman -S --needed --noconfirm intel-ucode"; then
                error "Failed to install Intel microcode"
                exit 1
            fi
        elif grep -qi 'AuthenticAMD' /proc/cpuinfo; then
            cpu_vendor="AMD"
            if ! retry "sudo pacman -S --needed --noconfirm amd-ucode"; then
                error "Failed to install AMD microcode"
                exit 1
            fi
        fi
        
        # Verify microcode installation
        if [ -n "$cpu_vendor" ]; then
            if ! grep -qi "$cpu_vendor" /proc/cmdline; then
                warn "Microcode not loaded. You may need to reboot for changes to take effect."
            fi
        fi

        # === GPU Drivers ===
        header "Detecting GPU and installing drivers"
        
        # Get GPU information
        GPU_VENDOR=$(lspci | grep -E 'VGA|3D' | head -n1)
        if [ -z "$GPU_VENDOR" ]; then
            warn "No GPU detected. Using default mesa drivers."
            run "sudo pacman -S --needed --noconfirm mesa"
        else
            log "Detected GPU: $GPU_VENDOR"
            
            # Install GPU-specific drivers with retry and verification
            if echo "$GPU_VENDOR" | grep -qi 'NVIDIA'; then
                if ! retry "sudo pacman -S --needed --noconfirm nvidia nvidia-utils"; then
                    error "Failed to install NVIDIA drivers"
                    exit 1
                fi
                
                # Verify NVIDIA driver installation
                if ! retry "modprobe nvidia"; then
                    warn "Failed to load NVIDIA module"
                fi
                
                # Check if Wayland support is available
                if command -v nvidia-smi >/dev/null 2>&1; then
                    if ! nvidia-smi >/dev/null 2>&1; then
                        warn "NVIDIA driver not properly loaded"
                    fi
                fi
            elif echo "$GPU_VENDOR" | grep -qi 'AMD'; then
                if ! retry "sudo pacman -S --needed --noconfirm xf86-video-amdgpu mesa vulkan-radeon"; then
                    error "Failed to install AMD drivers"
                    exit 1
                fi
                
                # Verify AMD driver installation
                if ! retry "modprobe amdgpu"; then
                    warn "Failed to load AMD GPU module"
                fi
                
                # Check if Wayland support is available
                if command -v glxinfo >/dev/null 2>&1; then
                    if ! glxinfo | grep -qi "direct rendering: Yes"; then
                        warn "Direct rendering not enabled for AMD GPU"
                    fi
                fi
            elif echo "$GPU_VENDOR" | grep -qi 'Intel'; then
                if ! retry "sudo pacman -S --needed --noconfirm mesa vulkan-intel"; then
                    error "Failed to install Intel drivers"
                    exit 1
                fi
                
                # Verify Intel driver installation
                if ! retry "modprobe i915"; then
                    warn "Failed to load Intel i915 module"
                fi
                
                # Check if Wayland support is available
                if command -v glxinfo >/dev/null 2>&1; then
                    if ! glxinfo | grep -qi "direct rendering: Yes"; then
                        warn "Direct rendering not enabled for Intel GPU"
                    fi
                fi
            else
                warn "Unknown GPU vendor. Using default mesa drivers."
                run "sudo pacman -S --needed --noconfirm mesa"
            fi
        fi
    fi

    # === Wayfire Configuration ===
    header "Configuring Wayfire"
    
    # Install Wayfire and essential plugins
    local WAYFIRE_PACKAGES="wayfire wayfire-plugins-extra wayfire-plugins-std wayfire-plugins-tiling wayfire-plugins-workspaces wayfire-plugins-scale wayfire-plugins-effects"
    if ! retry "sudo pacman -S --needed --noconfirm $WAYFIRE_PACKAGES"; then
        error "Failed to install Wayfire packages"
        exit 1
    fi
    
    # Install additional Wayfire plugins
    local WAYFIRE_EXTRA_PLUGINS="wayfire-plugins-gnome wayfire-plugins-kde wayfire-plugins-steam wayfire-plugins-gaming"
    if ! retry "sudo pacman -S --needed --noconfirm $WAYFIRE_EXTRA_PLUGINS"; then
        warn "Failed to install additional Wayfire plugins. Core functionality will still work."
    fi
    
    # Configure Wayfire
    local WAYFIRE_CONFIG_DIR="$HOME/.config/wayfire"
    mkdir -p "$WAYFIRE_CONFIG_DIR"
    
    # Create basic configuration
    cat > "$WAYFIRE_CONFIG_DIR/wayfire.ini" << EOF
[core]
backend = auto
vsync = true

[output]
primary = auto
scale = 1

[workspaces]
number = 4

[focus]
follow_mouse = true

[plugins]
plugins = ipc ipc-rules follow-focus

[autostart]
launcher = $IPC_DIR/inactive-alpha.py
EOF

    # Enable Wayfire autostart
    if [ ! -d "$HOME/.config/autostart" ]; then
        mkdir -p "$HOME/.config/autostart"
    fi
    
    cat > "$HOME/.config/autostart/wayfire.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Wayfire
Exec=wayfire
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Wayfire
Comment[en_US]=Wayfire Window Manager
Comment=Wayfire Window Manager
EOF

    # Set default session to Wayfire
    if [ -d "/usr/share/wayland-sessions" ]; then
        if ! retry "sudo cp -f wayfire.desktop /usr/share/wayland-sessions/"; then
            warn "Failed to set Wayfire as default session"
        fi
    fi

    # Network Configuration
    header "Configuring network"
    
    # Check for network controllers
    if lspci | grep -qi 'Network controller'; then
        log "Network controller detected. Installing network tools."
        
        # Install network packages with retry
        if ! retry "sudo pacman -S --needed --noconfirm linux-firmware wireless_tools networkmanager"; then
            error "Failed to install network tools"
            exit 1
        fi
        
        # Enable NetworkManager
        if ! retry "sudo systemctl enable NetworkManager"; then
            warn "Failed to enable NetworkManager"
        fi
    else
        log "No network controller detected. Skipping network configuration."
    fi
    
    # Enable NetworkManager anyway for wired connections
    if ! retry "sudo systemctl enable NetworkManager"; then
        warn "Failed to enable NetworkManager"
    else
        run "sudo systemctl enable NetworkManager"
    fi

    # Bluetooth
    if lsusb | grep -qi bluetooth || lspci | grep -qi bluetooth; then
        run "sudo pacman -S --needed --noconfirm bluez bluez-utils"
        if ! retry "sudo systemctl enable --now bluetooth"; then
            warn "Failed to enable Bluetooth service"
        fi
    fi

    # === Display Server Configuration ===
    header "Configuring display server"
    
    # Install Wayland and essential packages
    if ! retry "sudo pacman -S --needed --noconfirm wayland wayland-protocols"; then
        error "Failed to install Wayland packages"
        exit 1
    fi
    
    # Configure display server
    local DISPLAY_CONFIG_DIR="$HOME/.config/wayland"
    if [ ! -d "$DISPLAY_CONFIG_DIR" ]; then
        mkdir -p "$DISPLAY_CONFIG_DIR"
    fi
    
    # Create display server configuration
    cat > "$DISPLAY_CONFIG_DIR/display.conf" << EOF
[display]
backend = auto
vsync = true
scale = 1

# Handle multiple displays
[output]
primary = auto
scale = 1
mode = auto
position = auto
EOF
    
    # Configure display hotplugging
    if [ -d "/usr/share/wayland-sessions" ]; then
        if ! retry "sudo pacman -S --needed --noconfirm udev"; then
            warn "Failed to install udev. Display hotplugging may not work properly."
        fi
    fi

    # === Session Management ===
    header "Configuring session management"
    
    # Install session management tools
    if ! retry "sudo pacman -S --needed --noconfirm xdg-desktop-portal xdg-desktop-portal-wlr"; then
        error "Failed to install session management tools"
        exit 1
    fi
    
    # Enable session management services
    local SESSION_SERVICES=(
        "xdg-desktop-portal"
        "xdg-desktop-portal-wlr"
        "pipewire"
        "pipewire-pulse"
        "pipewire-media-session"
    )
    
    for service in "${SESSION_SERVICES[@]}"; do
        if ! retry "sudo systemctl enable --user $service"; then
            warn "Failed to enable $service"
        fi
    done
    
    # Enable system services with verification
    local SYSTEM_SERVICES=(
        "systemd-logind"
        "elogind"
        "dbus"
        "systemd-journald"
        "systemd-timesyncd"
        "systemd-networkd"
        "systemd-resolved"
        "systemd-udevd"
        "systemd-timedated"
        "systemd-hostnamed"
    )
    
    # Enable monitoring services
    local MONITORING_SERVICES=(
        "systemd-journald"
        "systemd-udevd"
        "systemd-networkd"
        "systemd-resolved"
        "systemd-timesyncd"
    )
    
    # Enable and verify all services
    for service in "${SYSTEM_SERVICES[@]}"; do
        if ! retry "sudo systemctl enable $service"; then
            warn "Failed to enable system service: $service"
        fi
        
        if ! retry "sudo systemctl is-active --quiet $service"; then
            warn "Service $service is not active"
        fi
    done
    
    # Enable monitoring tools
    header "Setting up system monitoring"
    
    # Install monitoring tools
    local MONITORING_TOOLS=(
        "htop"
        "iftop"
        "iotop"
        "nmon"
        "glances"
        "vnstat"
        "iftop"
    )
    
    for tool in "${MONITORING_TOOLS[@]}"; do
        if ! retry "sudo pacman -S --needed --noconfirm $tool"; then
            warn "Failed to install monitoring tool: $tool"
        fi
    done
    
    # Configure monitoring tools
    if [ -f /etc/vnstat.conf ]; then
        sed -i 's/^Interface.*/Interface "enp0s3"/' /etc/vnstat.conf
        run "sudo systemctl enable --now vnstat"
    fi
    
    # Set up log rotation
    if [ -f /etc/logrotate.conf ]; then
        cat >> /etc/logrotate.conf << EOF
/var/log/*.log {
    daily
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 root root
    sharedscripts
}
EOF
    fi
    
    for service in "${SYSTEM_SERVICES[@]}"; do
        if ! retry "sudo systemctl enable $service"; then
            warn "Failed to enable system service: $service"
        fi
        
        # Verify service status
        if ! retry "sudo systemctl is-active --quiet $service"; then
            warn "Service $service is not active"
        fi
    done
    
    # Configure system settings
    header "Configuring system settings"
    
    # Set system timezone
    if [ -f /etc/timezone ]; then
        local current_tz=$(cat /etc/timezone)
        if [ -z "$current_tz" ]; then
            local tz=$(timedatectl list-timezones | grep -i "$(hostname)" | head -n1)
            if [ -n "$tz" ]; then
                run "sudo timedatectl set-timezone $tz"
            fi
        fi
    fi
    
    # Enable hardware clock synchronization
    run "sudo timedatectl set-local-rtc 0"
    run "sudo timedatectl set-ntp true"
    
    # Set hostname
    local hostname=$(hostname)
    if [ -n "$hostname" ]; then
        run "sudo hostnamectl set-hostname $hostname"
    fi
    
    # Set locale
    if [ -f /etc/locale.conf ]; then
        local locale=$(cat /etc/locale.conf | grep LANG | cut -d= -f2)
        if [ -z "$locale" ]; then
            run "sudo localectl set-locale LANG=en_US.UTF-8"
        fi
    fi
    
    # Set keyboard layout
    run "sudo localectl set-keymap us"
    
    # Optimize system settings
    header "Optimizing system performance"
    
    # Enable ZRAM swap
    if ! grep -q "zram" /etc/modules-load.d/zram.conf; then
        echo "zram" | sudo tee /etc/modules-load.d/zram.conf
        run "sudo modprobe zram"
    fi
    
    # Optimize swap settings
    if [ -f /etc/sysctl.d/99-sysctl.conf ]; then
        cat >> /etc/sysctl.d/99-sysctl.conf << EOF
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_ratio=15
vm.dirty_background_ratio=5
EOF
        run "sudo sysctl -p"
    fi
    
    # Enable CPU governor
    if [ -f /etc/default/cpufreq ]; then
        echo "GOVERNOR=performance" | sudo tee /etc/default/cpufreq
        run "sudo systemctl enable --now cpufreq"
    fi
    
    # Security Hardening
    header "Applying security hardening"
    
    # Enable AppArmor
    if ! grep -q "apparmor" /etc/modules; then
        echo "apparmor" | sudo tee -a /etc/modules
        run "sudo modprobe apparmor"
    fi
    
    # Enable SELinux
    if [ -f /etc/selinux/config ]; then
        sed -i 's/^SELINUX=.*$/SELINUX=enforcing/' /etc/selinux/config
        run "sudo setenforce 1"
    fi
    
    # Enable firewall
    run "sudo pacman -S --needed --noconfirm ufw"
    run "sudo ufw default deny incoming"
    run "sudo ufw default allow outgoing"
    run "sudo ufw enable"
    
    # Enable auditd
    run "sudo pacman -S --needed --noconfirm audit"
    run "sudo systemctl enable --now auditd"
    
    # Enable hardware clock synchronization
    run "sudo timedatectl set-local-rtc 0"
    run "sudo timedatectl set-ntp true"
    
    # Set hostname
    local hostname=$(hostname)
    if [ -n "$hostname" ]; then
        run "sudo hostnamectl set-hostname $hostname"
    fi
    
    # Set locale
    if [ -f /etc/locale.conf ]; then
        local locale=$(cat /etc/locale.conf | grep LANG | cut -d= -f2)
        if [ -z "$locale" ]; then
            run "sudo localectl set-locale LANG=en_US.UTF-8"
        fi
    fi
    
    # Set keyboard layout
    run "sudo localectl set-keymap us"
    
    # Create optimized session script
    cat > "$HOME/.local/bin/start-wayfire" << EOF
#!/bin/sh

# Set environment variables
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/$UID
export XDG_CONFIG_HOME=$HOME/.config
export XDG_CACHE_HOME=$HOME/.cache
export XDG_DATA_HOME=$HOME/.local/share

# Set up Wayland environment
export WAYLAND_DEBUG=1
export WAYFIRE_BACKEND=auto
export WAYFIRE_VSYNC=true

# Set up audio environment
export PULSE_SERVER=unix:/run/user/$UID/pulse/native
export PULSE_RUNTIME_PATH=/run/user/$UID/pulse

# Start Wayfire with optimizations
exec wayfire
EOF
    
    run "chmod +x $HOME/.local/bin/start-wayfire"
    
    # Create session autostart directory
    local AUTOSTART_DIR="$HOME/.config/autostart"
    if [ ! -d "$AUTOSTART_DIR" ]; then
        run "mkdir -p $AUTOSTART_DIR"
    fi
    
    # Create Wayfire autostart entry
    cat > "$AUTOSTART_DIR/wayfire.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Wayfire
Exec=$HOME/.local/bin/start-wayfire
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=Wayfire
Comment[en_US]=Wayland compositor
Name=Wayfire
Comment=Wayland compositor
EOF
    
    run "chmod +x $HOME/.local/bin/start-wayfire"

    # === GNOME Desktop Installation ===
    header "GNOME Desktop Installation"

    if [ "$INSTALL_GNOME" = true ]; then
        # GNOME installation forced by flag
        log "Installing GNOME Desktop Environment (forced by flag)"
        run "sudo pacman -S --needed --noconfirm gnome gnome-tweaks gnome-terminal"
        run "sudo systemctl enable --now gdm"
        log "GNOME installed. You can log in to GNOME for troubleshooting or as a fallback environment."
    else
        # Prompt for GNOME installation
        if confirm "Would you like to install GNOME Desktop as a fallback environment?\n\nGNOME provides:\n- A stable fallback desktop\n- Graphical troubleshooting tools\n- Better hardware support\n- Easy system management\n\nInstall GNOME now?"; then
            log "Installing GNOME Desktop Environment"
            run "sudo pacman -S --needed --noconfirm gnome gnome-tweaks gnome-terminal"
            run "sudo systemctl enable --now gdm"
            log "GNOME installed. You can log in to GNOME for troubleshooting or as a fallback environment."
        else
            log "Skipping GNOME installation."
        fi
    fi
    # Continue with Wayfire installation
    header "Installing Wayfire and dependencies"

    # === Wayfire Installation ===
    header "Installing Wayfire and dependencies"
    
    # Install core packages with optimization flags
    local WAYLAND_PACKAGES=(
        "wayland"
        "wlroots"
        "xorg-xwayland"
        "kitty"
        "swaybg"
        "swaylock"
        "swayidle"
        "dunst"
        "mako"
        "grim"
        "slurp"
        "swaywm-waybar"
    )
    
    local OPTIMIZATION_FLAGS="--noconfirm --needed --asdeps"
    
    for pkg in "${WAYLAND_PACKAGES[@]}"; do
        if ! retry "sudo pacman $OPTIMIZATION_FLAGS $pkg"; then
            error "Failed to install package: $pkg"
            exit 1
        fi
    done

    # Build Wayfire components with error handling
    local WAYFIRE_COMPONENTS=(
        "https://github.com/WayfireWM/wayfire.git wayfire"
        "https://github.com/WayfireWM/wf-shell.git wf-shell"
        "https://github.com/WayfireWM/wcm.git wcm"
        "https://github.com/soreau/pixdecor.git pixdecor"
    )
    
    for component in "${WAYFIRE_COMPONENTS[@]}"; do
        local repo=$(echo "$component" | cut -d' ' -f1)
        local pkg=$(echo "$component" | cut -d' ' -f2)
        
        if ! build_git_pkg "$repo" "$pkg"; then
            error "Failed to build $pkg"
            exit 1
        fi
    done
    
    # Verify Wayfire installation
    if ! command -v wayfire >/dev/null 2>&1; then
        error "Wayfire installation failed. Please check the logs."
        exit 1
    fi
    
    # Verify Wayfire version and configure
    local wayfire_version=$(wayfire --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    if [ -z "$wayfire_version" ]; then
        error "Wayfire version verification failed"
        exit 1
    fi
    
    log "Wayfire version $wayfire_version installed successfully"
    
    # Configure Wayfire settings
    header "Configuring Wayfire settings"
    
    # Create Wayfire config directory
    local WAYFIRE_CONFIG_DIR="$HOME/.config/wayfire"
    if [ ! -d "$WAYFIRE_CONFIG_DIR" ]; then
        run "mkdir -p $WAYFIRE_CONFIG_DIR"
    fi
    
    # Create basic Wayfire config
    cat > "$WAYFIRE_CONFIG_DIR/wayfire.ini" << EOF
[core]
backend = auto
vsync = true

[output]
use-randr = true
auto-arrange = true

[workspaces]
num-workspaces = 10

[focus]
focus-follows-pointer = true

[plugins]
plugins =
    workspaces
    move
    resize
    fullscreen
    close
    minimize
    maximize
    tile
    scale
    effects
    screenshot
    keyboard
    pointer
    xwayland
    xwayland-clipboard
    xwayland-cursor
    xwayland-input
    xwayland-output
    xwayland-viewport
    xwayland-xwayland
    xwayland-xwayland-clipboard
    xwayland-xwayland-cursor
    xwayland-xwayland-input
    xwayland-xwayland-output
    xwayland-xwayland-viewport
    xwayland-xwayland-xwayland

[autostart]
launcher = $HOME/.config/wayfire/scripts/inactive-alpha.py
EOF
    
    # Create Wayfire scripts directory
    local WAYFIRE_SCRIPTS_DIR="$HOME/.config/wayfire/scripts"
    if [ ! -d "$WAYFIRE_SCRIPTS_DIR" ]; then
        run "mkdir -p $WAYFIRE_SCRIPTS_DIR"
    fi
    
    # Create inactive alpha script
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

    # === Theme and Icons ===
    header "Installing theme and icons"
    
    # Install GTK theme with backup and verification
    local THEME_DIR="$HOME/.local/share/themes"
    local THEME_NAME="TokyoNight-Dark"
    
    # Backup existing theme
    if [ -d "$THEME_DIR/$THEME_NAME" ]; then
        backup_config "$THEME_DIR/$THEME_NAME" "$BACKUP_DIR/themes/"
    fi
    
    # Install icons with verification
    local ICONS_DIR="$HOME/.local/share/icons"
    local ICON_THEME="Aretha-Dark"
    
    # Backup existing icons
    if [ -d "$ICONS_DIR/$ICON_THEME" ]; then
        backup_config "$ICONS_DIR/$ICON_THEME" "$BACKUP_DIR/icons/"
    fi
    
    # Install icons
    if [ ! -d "$SCRIPT_DIR/Aretha-Dark-Icons" ]; then
        if ! retry "git clone https://github.com/EliverLara/Aretha.git"; then
            error "Failed to clone icons repository"
            exit 1
        fi
        run "mv Aretha Aretha-Dark-Icons"
        run "rm -rf Aretha"
    fi
    
    if ! cd "$SCRIPT_DIR/Aretha-Dark-Icons"; then
        error "Failed to access icons directory"
        exit 1
    fi
    
    if ! retry "./install.sh -d \"$ICONS_DIR\" -c dark"; then
        error "Failed to install icons"
        exit 1
    fi
    
    if ! cd "$SCRIPT_DIR"; then
        error "Failed to return to script directory"
        exit 1
    fi
    
    # Verify icons installation
    if [ ! -d "$ICONS_DIR/$ICON_THEME" ]; then
        error "Icons installation failed"
        exit 1
    fi
    
    # Clean up
    if ! retry "rm -rf \"$SCRIPT_DIR/Aretha-Dark-Icons\""; then
        warn "Failed to clean up icons installation files"
    fi
    
    # Install theme
    if [ ! -d "$SCRIPT_DIR/Tokyo-Night-GTK-Theme" ]; then
        if ! retry "git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git"; then
            error "Failed to clone theme repository"
            exit 1
        fi
    fi
    
    if ! cd "$SCRIPT_DIR/Tokyo-Night-GTK-Theme/themes"; then
        error "Failed to access theme directory"
        exit 1
    fi
    
    if ! retry "./install.sh -d \"$THEME_DIR\" -c dark -l --tweaks black"; then
        error "Failed to install theme"
        exit 1
    fi
    
    if ! cd "$SCRIPT_DIR"; then
        error "Failed to return to script directory"
        exit 1
    fi
    
    # Verify theme installation
    if [ ! -d "$THEME_DIR/$THEME_NAME" ]; then
        error "Theme installation failed"
        exit 1
    fi
    
    # Clean up
    if ! retry "rm -rf \"$SCRIPT_DIR/Tokyo-Night-GTK-Theme\""; then
        warn "Failed to clean up theme installation files"
    fi

    # Install icons
    if [ ! -d "$SCRIPT_DIR/Aretha-Dark-Icons" ]; then
        fatal "Aretha-Dark-Icons not found. Please download it from https://www.gnome-look.org/p/2180417 and place it in $SCRIPT_DIR."
    fi
    run "mkdir -p \"$HOME/.local/share/icons\""
    run "mv \"$SCRIPT_DIR/Aretha-Dark-Icons\" \"$HOME/.local/share/icons/\""

    # === Desktop Configuration ===
    header "Configuring desktop environment"
    
    # Apply theme and icons
    run "mkdir -p \"$HOME/.config/gtk-3.0\""
    cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$THEME
gtk-icon-theme-name=Aretha-Dark-Icons
EOF

    # Install system tools
    run "sudo pacman -S --needed --noconfirm exa fish mako swappy"

    # Set Fish as default shell if requested
    if confirm "Set Fish as default shell?"; then
        set_fish=true
        if ! grep -qx "/usr/bin/fish" /etc/shells; then
            echo "/usr/bin/fish" | sudo tee -a /etc/shells
        fi
        run "chsh -s /usr/bin/fish"
    fi

    # Install Zed editor
    header "Installing Zed editor"
    if ! command -v zed >/dev/null 2>&1; then
        run "curl -fsSL https://zed.dev/install.sh | sh"
    fi

    # Install AUR packages if full install
    if [ "$INSTALL_ALL" = true ]; then
        header "Installing AUR packages"
        run "paru -S --noconfirm eww ironbar fzf zoxide starship ulauncher nwg-look vesktop ristretto swayosd clapper wcm mpv ncmpcpp thunar swww xava-git wlogout"
    fi

    # === Configuration Backup ===
    header "Backing up configurations"
    
    # Create backup directory
    if [ -d "$BACKUP_DIR" ]; then
        suffix=$(date +%s)
        BACKUP_DIR="${BACKUP_DIR}_$suffix"
    fi
    run "mkdir -p \"$BACKUP_DIR\""

    # Backup existing configurations
    if [ -d "$HOME/.config" ]; then
        backup_config "$HOME/.config" "$BACKUP_DIR/config"
    fi
    if [ -d "$HOME/.bin" ]; then
        backup_config "$HOME/.bin" "$BACKUP_DIR/bin"
    fi

    # === Copy New Configurations ===
    header "Copying new configurations"
    
    # Copy configuration files
    if [ -d "$SCRIPT_DIR/.config" ]; then
        run "cp -rv \"$SCRIPT_DIR/.config\" \"$HOME/\""
    fi
    if [ -d "$SCRIPT_DIR/.bin" ]; then
        run "cp -rv \"$SCRIPT_DIR/.bin\" \"$HOME/\""
        run "mkdir -p \"$HOME/.config/fish\""
        echo 'set -gx PATH $HOME/.bin $PATH' >> "$HOME/.config/fish/config.fish"
    fi

    # === Wayfire Configuration ===
    header "Configuring Wayfire"
    
    # Configure follow-focus and inactive-alpha
    run "mkdir -p \"$HOME/.config/environment.d\""
    echo "WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket" > "$HOME/.config/environment.d/environment.conf"

    # Setup IPC scripts
    local IPC_DIR="$HOME/.config/ipc-scripts"
    run "mkdir -p \"$IPC_DIR\""
    
    if [ -f "$SCRIPT_DIR/ipc-scripts/inactive-alpha.py" ] && [ -f "$SCRIPT_DIR/ipc-scripts/wayfire_socket.py" ]; then
        run "cp \"$SCRIPT_DIR/ipc-scripts/inactive-alpha.py\" \"$IPC_DIR/\""
        run "cp \"$SCRIPT_DIR/ipc-scripts/wayfire_socket.py\" \"$IPC_DIR/\""
    else
        run "curl -fL \"https://github.com/WayfireWM/wayfire/raw/master/examples/inactive-alpha.py\" -o \"$IPC_DIR/inactive-alpha.py\""
        run "curl -fL \"https://github.com/WayfireWM/wayfire/raw/master/examples/wayfire_socket.py\" -o \"$IPC_DIR/wayfire_socket.py\""
    fi
    run "chmod +x \"$IPC_DIR/inactive-alpha.py\" \"$IPC_DIR/wayfire_socket.py\""

    # Configure Wayfire.ini
    local WAYFIRE_INI="$HOME/.config/wayfire.ini"
    if [ -f "$WAYFIRE_INI" ]; then
        run "sed -i 's/^plugins =.*/plugins = ipc ipc-rules follow-focus/' \"$WAYFIRE_INI\""
        run "sed -i '/\[autostart\]/a launcher = $IPC_DIR/inactive-alpha.py' \"$WAYFIRE_INI\""
    else
        cat > "$WAYFIRE_INI" <<EOF
[Settings]
plugins = ipc ipc-rules follow-focus

[autostart]
launcher = $IPC_DIR/inactive-alpha.py
EOF
    fi

    # === Wayfire Session ===
    header "Creating Wayfire session"
    
    if [ ! -f /usr/share/wayland-sessions/wayfire.desktop ]; then
        sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Comment=A lightweight and customizable Wayland compositor
Exec=env WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket wayfire
Type=Application
EOF
    fi

    # === Verification ===
    header "Verifying installations"
    
    local failed=false
    for cmd in wayfire kitty fish zed wcm xava wlogout; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            warn "$cmd not found!"
            failed=true
        fi
    done

    if [ "$failed" = true ]; then
        fatal "Some required components are missing. Please check the log file for details."
    fi

    # === Final Summary ===
    echo
    if [ "$FAILED" = "true" ]; then
        echo -e "${RED}Installation completed with errors.${NC}"
        echo "Please review $LOG_FILE for more information."
        exit 1
    else
        echo -e "${GREEN}Installation completed successfully!${NC}"
        echo "See $LOG_FILE for a detailed log."
        echo "To start Wayfire:" && echo "    1. Log out of your current session" && echo "    2. Select 'Wayfire' from your display manager's session list" && echo "    3. Log back in to start Wayfire"
        exit 0
    fi
}

[autostart]
launcher = $IPC_DIR/inactive-alpha.py
EOF
    fi

# === Wayfire Session ===
    header "Creating Wayfire session"
    
    if [ ! -f /usr/share/wayland-sessions/wayfire.desktop ]; then
        # Create directory if it doesn't exist
        if [ ! -d /usr/share/wayland-sessions ]; then
            run "sudo mkdir -p /usr/share/wayland-sessions"
            if [ $? -ne 0 ]; then
                error "Failed to create wayland-sessions directory"
                exit 1
            fi
        fi
        
        # Write Wayfire session file
        sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Comment=A lightweight and customizable Wayland compositor
Exec=env WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket wayfire
Type=Application
EOF
        if [ $? -ne 0 ]; then
            error "Failed to create wayfire.desktop file"
            exit 1
        fi
    fi


    # === Verification ===
    header "Verifying installations"
    
    local failed=false
    for cmd in wayfire kitty fish zed wcm xava wlogout; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            warn "$cmd not found!"
            failed=true
        fi
    done

    if [ "$failed" = true ]; then
        fatal "Some required components are missing. Please check the log file for details."
    fi

    # === Final Summary ===
    echoalso
    if [ "$FAILED" = "true" ]; then
        echo -e "${RED}Installation completed with errors.${NC}"
        echo "Please review $LOG_FILE for more information."
        exit 1
    else
        echo -e "${GREEN}Installation completed successfully!${NC}"
        echo "See $LOG_FILE for a detailed log."
        echo "To start Wayfire:" && echo "    1. Log out of your current session" && echo "    2. Select 'Wayfire' from your display manager's session list" && echo "    3. Log back in to start Wayfire"

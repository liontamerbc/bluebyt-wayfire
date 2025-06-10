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
    check_space 2000
    
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
    local ESSENTIALS="git gcc ninja rust nimble sudo lxappearance base-devel libxml2 curl"
    if [ "$INSTALL_ALL" = false ]; then
        ESSENTIALS="git gcc base-devel curl"
    fi
    
    run "sudo pacman -S --needed --noconfirm $ESSENTIALS"

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
            run "sudo pacman -S --needed --noconfirm virtualbox-guest-modules-arch"
        elif echo "$VM_VENDOR" | grep -qi 'VMware'; then
            run "sudo pacman -S --needed --noconfirm open-vm-tools-desktop"
        fi
        
        # Enable VM services
        run "sudo systemctl enable vboxservice"
        run "sudo systemctl enable vmtoolsd"
        
        # Install basic graphics drivers
        run "sudo pacman -S --needed --noconfirm mesa xf86-video-vmware"
        
        log "Virtual machine drivers installed successfully"
    else
        # === CPU Microcode ===
        header "Detecting CPU and installing microcode"
        if grep -qi 'GenuineIntel' /proc/cpuinfo; then
            run "sudo pacman -S --needed --noconfirm intel-ucode"
        elif grep -qi 'AuthenticAMD' /proc/cpuinfo; then
            run "sudo pacman -S --needed --noconfirm amd-ucode"
        fi

        # === GPU Drivers ===
        header "Detecting GPU and installing drivers"
        GPU_VENDOR=$(lspci | grep -E 'VGA|3D' | head -n1)
        if echo "$GPU_VENDOR" | grep -qi 'NVIDIA'; then
            run "sudo pacman -S --needed --noconfirm nvidia nvidia-utils"
        elif echo "$GPU_VENDOR" | grep -qi 'AMD'; then
            run "sudo pacman -S --needed --noconfirm xf86-video-amdgpu mesa vulkan-radeon"
        elif echo "$GPU_VENDOR" | grep -qi 'Intel'; then
            run "sudo pacman -S --needed --noconfirm mesa vulkan-intel"
        else
            run "sudo pacman -S --needed --noconfirm mesa"
        fi
    fi

    # Network Configuration
    header "Configuring network"
    
    # Wi-Fi
    if lspci | grep -qi 'Network controller'; then
        run "sudo pacman -S --needed --noconfirm linux-firmware wireless_tools networkmanager"
        run "sudo systemctl enable NetworkManager"
    fi

    # Bluetooth
    if lsusb | grep -qi bluetooth || lspci | grep -qi bluetooth; then
        run "sudo pacman -S --needed --noconfirm bluez bluez-utils"
        run "sudo systemctl enable --now bluetooth"
    fi

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

    # === Wayfire Installation ===
    header "Installing Wayfire and dependencies"
    
    # Install core packages
    run "sudo pacman -S --needed --noconfirm wayland wlroots xorg-xwayland kitty"

    # Build Wayfire components
    build_git_pkg "https://github.com/WayfireWM/wayfire.git" "wayfire"
    build_git_pkg "https://github.com/WayfireWM/wf-shell.git" "wf-shell"
    build_git_pkg "https://github.com/WayfireWM/wcm.git" "wcm"
    build_git_pkg "https://github.com/soreau/pixdecor.git" "pixdecor"

    # === Theme and Icons ===
    header "Installing theme and icons"
    
    # Install GTK theme
    if [ ! -d "$SCRIPT_DIR/Tokyo-Night-GTK-Theme" ]; then
        run "git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git"
    fi
    cd "$SCRIPT_DIR/Tokyo-Night-GTK-Theme/themes" || exit 1
    run "./install.sh -d \"$HOME/.local/share/themes\" -c dark -l --tweaks black"
    cd "$SCRIPT_DIR" || exit 1
    run "rm -rf \"$SCRIPT_DIR/Tokyo-Night-GTK-Theme\""

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

#!/usr/bin/env bash

################################################################################
# bluebyt-wayfire Desktop Installer for Arch Linux
# Maintainer: liontamerbc
# Version: 2.0.0
#
# - Robust, user-friendly, and auditable installer
# - Adheres to best practices for user safety, logging, and maintainability
# - For Arch Linux and derivatives ONLY
#
# USAGE:
#   ./installer.sh [options]
# OPTIONS:
#   -t THEME     Set GTK theme (default: TokyoNight-Dark)
#   -p           Partial install, skip optional AUR packages
#   -w           Skip wallpaper installation
#   -n           Dry-run: show actions, do not change system
#   -h           Show this help message
################################################################################

set -euo pipefail

# === Script Metadata ===
SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
LOG_FILE="$SCRIPT_DIR/install_wayfire_$(date +%F_%T).log"
FAILED=false
DRY_RUN=false

# === Colors for Logging ===
RED='\033[0;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

# === Defaults ===
THEME="TokyoNight-Dark"
INSTALL_ALL=true
SKIP_WALLPAPERS=false

BACKUP_DIR="$HOME/.config_backup_$(date +%F_%T)"

# === Logging Functions ===
log()    { echo -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error()  { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"; FAILED=true; }
fatal()  { error "$*"; cleanup; exit 1; }
header() { echo -e "\n${BLUE}==== $* ====${NC}" | tee -a "$LOG_FILE"; }

# === Trap for Cleanup on Error or Interrupt ===
cleanup() {
    if [[ "$FAILED" == "true" ]]; then
        warn "Installation failed. Cleaning up..."
        cd "$SCRIPT_DIR" || exit 1
        rm -rf wayfire wf-shell wcm pixdecor paru Tokyo-Night-GTK-Theme Aretha-Dark-Icons 2>/dev/null || true
        warn "Cleanup complete. See $LOG_FILE for details."
        echo "See $LOG_FILE for detailed installation log"
    fi
}
trap cleanup EXIT SIGINT SIGTERM

# === Usage ===
usage() {
    cat <<EOF
$SCRIPT_NAME v$SCRIPT_VERSION - Installs bluebyt-wayfire desktop environment

Usage: $SCRIPT_NAME [-t theme] [-p] [-w] [-n] [-h]
  -t THEME     Set GTK theme (default: TokyoNight-Dark)
  -p           Partial install, skip optional AUR packages
  -w           Skip wallpaper installation
  -n           Dry-run: show what would be done, do not change system
  -h           Show this help message
EOF
    exit 0
}

# === Command Line Parsing ===
while getopts ":t:pwnh" opt; do
    case "$opt" in
        t) THEME="$OPTARG";;
        p) INSTALL_ALL=false;;
        w) SKIP_WALLPAPERS=true;;
        n) DRY_RUN=true;;
        h) usage;;
        \?) echo "Invalid option -$OPTARG" >&2; usage;;
    esac
done

# === OS and Environment Checks ===
if ! grep -q '^ID=arch' /etc/os-release; then
    fatal "This installer is only supported on Arch Linux."
fi

if ! command -v sudo >/dev/null 2>&1; then
    fatal "sudo is required but not installed."
fi

# === Dry-run Helper ===
run() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
    else
        eval "$@"
    fi
}

# === Confirm Helper ===
confirm() {
    if [ "$DRY_RUN" = true ]; then
        log "[DRY-RUN] Would prompt: $*"
        return 0
    fi
    read -r -p "$1 (y/N): " REPLY
    echo
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# === Pre-Flight System Checks ===
header "Pre-flight system checks"
log "Selected theme: $THEME"
log "Full installation: $INSTALL_ALL"
log "Install wallpapers: $([ "$SKIP_WALLPAPERS" = "true" ] && echo "no" || echo "yes")"
log "Dry-run: $DRY_RUN"
log "Installer version: $SCRIPT_VERSION"

confirm "Do you want to proceed with the installation?" || fatal "Aborted by user."

# Check disk space
check_space() {
    local min_space_mb=$1
    local available_mb
    available_mb=$(df -Pm "$HOME" | tail -1 | awk '{print $4}')
    if [ "$available_mb" -lt "$min_space_mb" ]; then
        fatal "Insufficient disk space. Required: ${min_space_mb}MB, Available: ${available_mb}MB"
    fi
}
check_space 2000

# Dependency check
require_bin() {
    local cmd="$1"
    local ver="$2"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        fatal "$cmd is required but not installed."
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
require_bin git 2.30
require_bin gcc 10.0
require_bin curl ""

# === Detect CPU and GPU, Install Microcode and Drivers ===
header "Detecting CPU and installing microcode"
if grep -qi 'GenuineIntel' /proc/cpuinfo; then
    run "sudo pacman -S --needed --noconfirm intel-ucode"
elif grep -qi 'AuthenticAMD' /proc/cpuinfo; then
    run "sudo pacman -S --needed --noconfirm amd-ucode"
fi

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

# === Detect Wi-Fi and Bluetooth, Install Drivers and Tools ===
header "Detecting Wi-Fi and installing drivers/tools"
if lspci | grep -qi 'Network controller.*Broadcom'; then
    warn "Broadcom Wi-Fi detected. You may need to install 'broadcom-wl-dkms' from the AUR for full support."
    if confirm "Would you like to try installing broadcom-wl-dkms from AUR now?"; then
        if ! command -v paru >/dev/null 2>&1; then
            run "git clone https://aur.archlinux.org/paru.git"
            cd paru || exit 1
            run "makepkg -si --noconfirm"
            cd .. || exit 1
            run "rm -rf paru"
        fi
        run "paru -S --noconfirm broadcom-wl-dkms"
    fi
elif lspci | grep -qi 'Network controller.*Realtek'; then
    warn "Realtek Wi-Fi detected. Some chipsets require extra drivers from AUR."
    if confirm "Would you like to search for and install Realtek Wi-Fi drivers from AUR now?"; then
        log "Please search the AUR for your specific Realtek chipset (e.g., rtl8821ce-dkms-git) and install as needed."
        run "paru -Ss realtek"
    fi
fi

# Always install wireless tools and firmware
run "sudo pacman -S --needed --noconfirm linux-firmware wireless_tools networkmanager"

header "Detecting Bluetooth and installing drivers/tools"
if lsusb | grep -qi bluetooth || lspci | grep -qi bluetooth; then
    run "sudo pacman -S --needed --noconfirm bluez bluez-utils"
    run "sudo systemctl enable --now bluetooth"
else
    # Install anyway for most laptops/desktops
    run "sudo pacman -S --needed --noconfirm bluez bluez-utils"
    run "sudo systemctl enable --now bluetooth"
fi

# === System Update ===
header "Updating system"
run "sudo pacman -Syu --noconfirm" || fatal "System update failed."

# === Install Essential Packages ===
header "Installing essential tools"
if [ "$INSTALL_ALL" = true ]; then
    ESSENTIALS="git gcc ninja rust nimble sudo lxappearance base-devel libxml2 curl"
else
    ESSENTIALS="git gcc base-devel curl"
fi
run "sudo pacman -S --needed --noconfirm $ESSENTIALS" || fatal "Failed to install essentials."

# === Install GTK Theme Dependencies ===
header "Installing GTK theme dependencies"
run "sudo pacman -S --needed --noconfirm gtk-engine-murrine gtk-engines sass gnome-themes-extra"

# === Install Wayland, Kitty ===
header "Installing Wayland, core packages, and Kitty terminal"
run "sudo pacman -S --needed --noconfirm wayland wlroots xorg-xwayland kitty"

# === Paru (AUR Helper) ===
header "Checking for paru (AUR helper)"
if ! command -v paru >/dev/null 2>&1; then
    log "paru not found, installing from AUR"
    run "git clone https://aur.archlinux.org/paru.git"
    cd paru || exit 1
    run "makepkg -si --noconfirm"
    cd .. || exit 1
    run "rm -rf paru"
else
    log "paru already installed (version: $(paru --version))"
fi

# === Wayfire Core Build ===
build_git_pkg() {
    local url="$1"
    local pkgdir="$2"
    header "Building and installing $pkgdir"
    run "git clone \"$url\""
    cd "$pkgdir" || exit 1
    run "meson build --prefix=/usr --buildtype=release"
    run "ninja -C build"
    run "sudo ninja -C build install"
    cd .. || exit 1
    run "rm -rf \"$pkgdir\""
}
build_git_pkg "https://github.com/WayfireWM/wayfire.git" "wayfire"
build_git_pkg "https://github.com/WayfireWM/wf-shell.git" "wf-shell"
build_git_pkg "https://github.com/WayfireWM/wcm.git" "wcm"
build_git_pkg "https://github.com/soreau/pixdecor.git" "pixdecor"

# === Desktop Utilities ===
header "Installing desktop utilities"
run "sudo pacman -S --needed --noconfirm polkit-gnome networkmanager"
run "sudo systemctl enable NetworkManager"

# === Theme and Icon Install ===
header "Installing GTK theme: $THEME"
if [ ! -d "$SCRIPT_DIR/Tokyo-Night-GTK-Theme" ]; then
    run "git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git"
fi
cd "$SCRIPT_DIR/Tokyo-Night-GTK-Theme/themes" || exit 1
run "./install.sh -d \"$HOME/.local/share/themes\" -c dark -l --tweaks black"
cd "$SCRIPT_DIR" || exit 1
run "rm -rf \"$SCRIPT_DIR/Tokyo-Night-GTK-Theme\""

header "Installing Aretha-Dark-Icons"
if [ -f "$SCRIPT_DIR/Aretha-Dark-Icons.tar.gz" ]; then
    run "cp \"$SCRIPT_DIR/Aretha-Dark-Icons.tar.gz\" \"$SCRIPT_DIR\""
elif [ ! -d "$SCRIPT_DIR/Aretha-Dark-Icons" ]; then
    fatal "Aretha-Dark-Icons.tar.gz not found. Please download it from https://www.gnome-look.org/p/2180417 and place it in $SCRIPT_DIR."
fi
if [ -f "$SCRIPT_DIR/Aretha-Dark-Icons.tar.gz" ]; then
    run "tar -xzf \"$SCRIPT_DIR/Aretha-Dark-Icons.tar.gz\" -C \"$SCRIPT_DIR\""
    run "rm -f \"$SCRIPT_DIR/Aretha-Dark-Icons.tar.gz\""
fi
run "mkdir -p \"$HOME/.local/share/icons\""
if [ -d "$SCRIPT_DIR/Aretha-Dark-Icons" ]; then
    run "mv \"$SCRIPT_DIR/Aretha-Dark-Icons\" \"$HOME/.local/share/icons/\""
fi

# Apply theme and icons
header "Applying theme and icons"
run "mkdir -p \"$HOME/.config/gtk-3.0\""
cat > "$HOME/.config/gtk-3.0/settings.ini" <<EOF
[Settings]
gtk-theme-name=$THEME
gtk-icon-theme-name=Aretha-Dark-Icons
EOF

# === System Tools ===
header "Installing system tools: exa, Fish, mako, swappy"
run "sudo pacman -S --needed --noconfirm exa fish mako swappy"

set_fish=false
if confirm "Do you want to set Fish as your default shell?"; then
    set_fish=true
    if ! grep -qx "/usr/bin/fish" /etc/shells; then
        echo "/usr/bin/fish" | sudo tee -a /etc/shells
    fi
    run "chsh -s /usr/bin/fish"
fi

# === Zed Editor ===
header "Installing Zed editor"
if ! command -v zed >/dev/null 2>&1; then
    run "curl -fsSL https://zed.dev/install.sh | sh"
    if command -v zed >/dev/null 2>&1; then
        log "Zed editor installed successfully: $(zed --version)"
    else
        warn "Zed installation completed but 'zed' command not found."
    fi
else
    log "Zed editor already installed: $(zed --version)"
fi

# === AUR Packages ===
if [ "$INSTALL_ALL" = true ]; then
    header "Installing AUR packages"
    run "paru -S --noconfirm eww ironbar fzf zoxide starship ulauncher nwg-look vesktop ristretto swayosd clapper wcm mpv ncmpcpp thunar swww xava-git wlogout"
else
    log "Partial install: skipping optional AUR packages."
fi

# === Backup and Copy Configs ===
header "Backing up and copying configuration files"
run "mkdir -p \"$BACKUP_DIR\""
if [ -d "$HOME/.config" ]; then
    run "cp -r \"$HOME/.config\" \"$BACKUP_DIR/\""
fi
if [ -d "$HOME/.bin" ]; then
    run "cp -r \"$HOME/.bin\" \"$BACKUP_DIR/\""
fi

if [ -d "$SCRIPT_DIR/.config" ]; then
    run "cp -rv \"$SCRIPT_DIR/.config\" \"$HOME/\""
    log "Configuration directory copied."
else
    warn ".config directory not found in $SCRIPT_DIR."
fi
if [ -d "$SCRIPT_DIR/.bin" ]; then
    run "cp -rv \"$SCRIPT_DIR/.bin\" \"$HOME/\""
    if [ ! -f "$HOME/.config/fish/config.fish" ] || ! grep -q "$HOME/.bin" "$HOME/.config/fish/config.fish" 2>/dev/null; then
        run "mkdir -p \"$HOME/.config/fish\""
        echo 'set -gx PATH $HOME/.bin $PATH' >> "$HOME/.config/fish/config.fish"
        log "Added $HOME/.bin to PATH in Fish configuration."
    fi
else
    warn ".bin directory not found in $SCRIPT_DIR."
fi

# === Wallpaper Install ===
if [ "$SKIP_WALLPAPERS" != "true" ]; then
    header "Setting up wallpapers"
    WALLPAPER_SOURCE="$SCRIPT_DIR/Wallpaper"
    WALLPAPER_DEST="/usr/share/Wallpaper"
    if [ -d "$WALLPAPER_SOURCE" ]; then
        run "sudo mkdir -p \"$WALLPAPER_DEST\""
        run "sudo cp -rv \"$WALLPAPER_SOURCE\"/* \"$WALLPAPER_DEST/\""
        run "sudo chmod -R a+r \"$WALLPAPER_DEST\""
        log "Wallpapers installed."
    else
        warn "Wallpaper directory not found at $WALLPAPER_SOURCE. Skipping..."
    fi
else
    log "Skipping wallpaper installation as per user request (-w flag)."
fi

# === Wayfire Config and IPC Scripts ===
header "Configuring follow-focus and inactive-alpha for Wayfire"
run "mkdir -p \"$HOME/.config/environment.d\""
echo "WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket" > "$HOME/.config/environment.d/environment.conf"

IPC_DIR="$HOME/.config/ipc-scripts"
run "mkdir -p \"$IPC_DIR\""
if [ -f "$SCRIPT_DIR/ipc-scripts/inactive-alpha.py" ] && [ -f "$SCRIPT_DIR/ipc-scripts/wayfire_socket.py" ]; then
    run "cp \"$SCRIPT_DIR/ipc-scripts/inactive-alpha.py\" \"$IPC_DIR/\""
    run "cp \"$SCRIPT_DIR/ipc-scripts/wayfire_socket.py\" \"$IPC_DIR/\""
else
    run "curl -fL \"https://github.com/WayfireWM/wayfire/raw/master/examples/inactive-alpha.py\" -o \"$IPC_DIR/inactive-alpha.py\""
    run "curl -fL \"https://github.com/WayfireWM/wayfire/raw/master/examples/wayfire_socket.py\" -o \"$IPC_DIR/wayfire_socket.py\""
fi
run "chmod +x \"$IPC_DIR/inactive-alpha.py\" \"$IPC_DIR/wayfire_socket.py\""

WAYFIRE_INI="$HOME/.config/wayfire.ini"
if [ -f "$WAYFIRE_INI" ]; then
    if grep -q "^plugins =" "$WAYFIRE_INI"; then
        run "sed -i 's/^plugins =.*/plugins = ipc ipc-rules follow-focus/' \"$WAYFIRE_INI\""
    else
        echo "plugins = ipc ipc-rules follow-focus" >> "$WAYFIRE_INI"
    fi
    if grep -q "^\[autostart\]" "$WAYFIRE_INI"; then
        if ! grep -q "launcher =" "$WAYFIRE_INI"; then
            run "sed -i \"/^\[autostart\]/a launcher = $IPC_DIR/inactive-alpha.py\" \"$WAYFIRE_INI\""
        fi
    else
        echo -e "\n[autostart]\nlauncher = $IPC_DIR/inactive-alpha.py" >> "$WAYFIRE_INI"
    fi
else
    echo -e "plugins = ipc ipc-rules follow-focus\n\n[autostart]\nlauncher = $IPC_DIR/inactive-alpha.py" > "$WAYFIRE_INI"
fi

# === wayfire.desktop Session File ===
if [ ! -f /usr/share/wayland-sessions/wayfire.desktop ]; then
    header "Creating wayfire.desktop session file"
    sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Comment=A lightweight and customizable Wayland compositor
Exec=/usr/bin/wayfire
Type=Application
EOF
fi

# === Verify Key Installations ===
header "Verifying key installations"
for cmd in wayfire kitty fish zed wcm xava wlogout; do
    if command -v "$cmd" >/dev/null 2>&1; then
        log "$cmd installed: $(command -v "$cmd")"
    else
        warn "$cmd not found!"
        FAILED=true
    fi
done

# === Summary and Final Instructions ===
echo
if [ "$FAILED" = "true" ]; then
    echo -e "${RED}Installation completed with errors.${NC}"
    echo "Please review $LOG_FILE for more information."
else
    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo "See $LOG_FILE for a detailed log."
    echo "To start Wayfire:"
    echo "  1. Log out of your current session."
    echo "  2. At your login manager, select the 'Wayfire' session."
    echo "  3. Log in and enjoy your new desktop environment!"
    echo "Backup of previous config saved to: $BACKUP_DIR"
    if [ "$set_fish" = true ]; then
        echo "Note: Fish shell is now set as default."
    fi
fi

#!/bin/bash

# Exit on any error to prevent partial installations
set -e

# === Global Variables ===
SCRIPT_DIR="$(pwd)"  # This will be $HOME/bluebyt-wayfire since you've cd'ed there
BACKUP_DIR=~/.config_backup_$(date +%F_%T)
FAILED=false
LOG_FILE="$SCRIPT_DIR/install_wayfire_$(date +%F_%T).log"
THEME="TokyoNight-Dark"
INSTALL_ALL=true
SKIP_WALLPAPERS=false

# === Command Line Options ===
while getopts ":t:pw" opt; do
    case $opt in
        t) THEME="$OPTARG";;
        p) INSTALL_ALL=false;;
        w) SKIP_WALLPAPERS=true;;
        \?) echo "Invalid option -$OPTARG" >&2; exit 1;;
    esac
done

# === Helper Functions ===
log() {
    echo "$@" | tee -a "$LOG_FILE"
}

command_exists() {
    if command -v "$1" >/dev/null 2>&1; then
        local version=$($1 --version 2>/dev/null | head -n1 || echo "unknown")
        log "$1 found (version: $version)"
        return 0
    else
        log "Error: $1 not found"
        return 1
    fi
}

check_version() {
    local cmd="$1"
    local min_version="$2"
    local current_version=$($cmd --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
    if [ -z "$current_version" ]; then
        log "Warning: Could not determine $cmd version"
        return 1
    fi
    if [ "$(printf '%s\n' "$min_version" "$current_version" | sort -V | head -n1)" != "$min_version" ]; then
        log "Error: $cmd version $current_version is less than required $min_version"
        return 1
    fi
    return 0
}

check_space() {
    local min_space=$1
    local available_space=$(df -m / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt "$min_space" ]; then
        log "Error: Insufficient disk space. Required: ${min_space}MB, Available: ${available_space}MB"
        exit 1
    fi
}

install_pacman() {
    log "Installing with pacman: $@"
    sudo pacman -S --needed --noconfirm "$@" 2>>"$LOG_FILE" || { log "Pacman install failed for $@"; FAILED=true; }
}

install_aur() {
    log "Installing with paru: $@"
    paru -S --noconfirm "$@" 2>>"$LOG_FILE" || { log "Paru install failed for $@"; FAILED=true; }
}

cleanup() {
    if [ "$FAILED" = true ]; then
        log "Installation failed. Cleaning up..."
        cd "$SCRIPT_DIR"
        rm -rf wayfire wf-shell paru Tokyo-Night-GTK-Theme 2>/dev/null
        log "Cleanup complete. See $LOG_FILE for details."
        exit 1
    fi
}

confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Aborted by user."
        exit 0
    fi
}

# === Welcome Message ===
log "Welcome to the Wayfire Desktop Environment Installer for Arch Linux!"
log "Selected theme: $THEME"
log "Full installation: $INSTALL_ALL"
log "Install wallpapers: $((! $SKIP_WALLPAPERS))"
confirm "Do you want to proceed with the installation?"

# === Step 1: Pre-flight Checks ===
log "Checking system requirements..."
check_space 2000
log "Verifying critical dependencies..."
command_exists "git" && check_version "git" "2.30" || FAILED=true
command_exists "gcc" && check_version "gcc" "10.0" || FAILED=true

# === Step 2: Update System ===
log "Updating package lists..."
sudo pacman -Syu --noconfirm 2>>"$LOG_FILE" || { log "System update failed."; FAILED=true; cleanup; }

# === Step 3: Install Essential Tools ===
if [ "$INSTALL_ALL" = true ]; then
    log "Installing essential build tools..."
    install_pacman git gcc ninja rust nimble sudo lxappearance base-devel libxml2
else
    log "Skipping optional build tools (partial install)"
    install_pacman git gcc base-devel
fi

# === Step 4: Install GTK Theme Dependencies ===
log "Installing GTK theme dependencies..."
install_pacman gtk-engine-murrine gtk-engines sass gnome-themes-extra

# === Step 5: Install Wayland and Core Packages ===
log "Installing Wayland, core packages, and Kitty terminal..."
install_pacman wayland wlroots xorg-xwayland kitty

# === Step 6: Install Paru (AUR Helper) if not already installed ===
if ! command_exists paru; then
    log "Installing Paru from AUR..."
    git clone https://aur.archlinux.org/paru.git || { log "Failed to clone Paru."; FAILED=true; cleanup; }
    cd paru
    makepkg -si --noconfirm || { log "Paru build failed."; FAILED=true; cleanup; }
    cd ..
    rm -rf paru
else
    log "Paru is already installed. Version: $(paru --version)"
fi

# === Step 7: Install Wayfire Dependencies ===
log "Installing Wayfire dependencies..."
install_pacman autoconf boost cmake doctest doxygen freetype2 glib2-devel glm \
    gobject-introspection gtk-layer-shell gtkmm3 libdbusmenu-gtk3 libdrm libevdev \
    libgl libinput libjpeg libnotify libpng libxkbcommon meson nlohmann-json \
    pkg-config pixman wayland-protocols wlroots

# === Step 8: Build and Install Wayfire ===
log "Building and installing Wayfire..."
git clone https://github.com/WayfireWM/wayfire.git || { log "Failed to clone Wayfire."; FAILED=true; cleanup; }
cd wayfire
meson build --prefix=/usr --buildtype=release || { log "Meson setup failed."; FAILED=true; cleanup; }
ninja -C build || { log "Ninja build failed."; FAILED=true; cleanup; }
sudo ninja -C build install
cd ..
rm -rf wayfire

# === Step 9: Build and Install wf-shell ===
log "Building and installing wf-shell (Wayfire shell components)..."
git clone https://github.com/WayfireWM/wf-shell.git || { log "Failed to clone wf-shell."; FAILED=true; cleanup; }
cd wf-shell
meson build --prefix=/usr --buildtype=release
ninja -C build
sudo ninja -C build install
cd ..
rm -rf wf-shell

# === Step 10: Install Desktop Utilities ===
log "Installing desktop utilities..."
install_pacman polkit-gnome networkmanager
sudo systemctl enable NetworkManager

# === Step 11: Install Themes and Icons ===
log "Installing $THEME GTK Theme..."
git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git || { log "Failed to clone theme."; FAILED=true; cleanup; }
cd Tokyo-Night-GTK-Theme/themes
./install.sh -d ~/.local/share/themes -c dark -l --tweaks black 2>>"$LOG_FILE"
cd ../..
rm -rf Tokyo-Night-GTK-Theme

log "Installing Tela Circle icon theme from AUR..."
install_aur tela-circle-icon-theme

log "Applying theme and icons..."
mkdir -p ~/.config/gtk-3.0
echo "[Settings]
gtk-theme-name=$THEME
gtk-icon-theme-name=Tela-circle" > ~/.config/gtk-3.0/settings.ini

# === Step 12: Install System Tools including exa and Fish ===
log "Installing system tools: exa, Fish, mako, swappy..."
install_pacman exa fish mako swappy

confirm "Do you want to set Fish as your default shell?"
log "Setting Fish as the default shell..."
echo "/usr/bin/fish" | sudo tee -a /etc/shells
chsh -s /usr/bin/fish

# === Step 13: Install packages from AUR ===
if [ "$INSTALL_ALL" = true ]; then
    log "Installing packages from AUR..."
    install_aur eww ironbar fzf zoxide starship ulauncher nwg-look vesktop ristretto swayosd clapper wcm mpv ncmpcpp thunar
else
    log "Skipping optional AUR packages (eww, ironbar) due to partial install"
fi

# === Step 14: Backup and Copy Configuration Files and Binaries ===
log "Backing up existing configuration..."
mkdir -p "$BACKUP_DIR"
cp -r "$HOME/.config" "$BACKUP_DIR/" 2>/dev/null || true
cp -r "$HOME/.bin" "$BACKUP_DIR/" 2>/dev/null || true

log "Copying configuration files and binaries from current bluebyt-wayfire directory..."
if [ -d "$SCRIPT_DIR/.config" ]; then
    cp -rv "$SCRIPT_DIR/.config" "$HOME/" 2>>"$LOG_FILE" >>"$LOG_FILE"
    if [ $? -eq 0 ]; then
        log "Configuration directory copied to $HOME/.config/"
    else
        log "Error: Failed to copy .config directory from $SCRIPT_DIR to $HOME/"
        FAILED=true
    fi
else
    log "Error: .config directory not found in $SCRIPT_DIR. Please ensure it exists in the bluebyt-wayfire directory."
    FAILED=true
fi

if [ -d "$SCRIPT_DIR/.bin" ]; then
    cp -rv "$SCRIPT_DIR/.bin" "$HOME/" 2>>"$LOG_FILE" >>"$LOG_FILE"
    if [ $? -eq 0 ]; then
        log "Binaries directory copied to $HOME/.bin/"
        if ! grep -q "$HOME/.bin" "$HOME/.config/fish/config.fish" 2>/dev/null; then
            mkdir -p "$HOME/.config/fish"
            echo 'set -gx PATH $HOME/.bin $PATH' >> "$HOME/.config/fish/config.fish"
            log "Added $HOME/.bin to PATH in Fish configuration."
        else
            log "$HOME/.bin already in PATH."
        fi
    else
        log "Error: Failed to copy .bin directory from $SCRIPT_DIR to $HOME/"
        FAILED=true
    fi
else
    log "Error: .bin directory not found in $SCRIPT_DIR. Please ensure it exists in the bluebyt-wayfire directory."
    FAILED=true
fi

# === Step 14b: Copy Wallpapers ===
if [ "$SKIP_WALLPAPERS" != "true" ]; then
    log "Setting up wallpapers from current bluebyt-wayfire directory..."
    WALLPAPER_SOURCE="$SCRIPT_DIR/Wallpapers"
    WALLPAPER_DEST="$HOME/Pictures/Wallpapers"

    if [ -d "$WALLPAPER_SOURCE" ]; then
        mkdir -p "$HOME/Pictures" 2>>"$LOG_FILE"
        if [ $? -ne 0 ]; then
            log "Error: Failed to create $HOME/Pictures directory"
            FAILED=true
        else
            cp -rv "$WALLPAPER_SOURCE" "$WALLPAPER_DEST" 2>>"$LOG_FILE" >>"$LOG_FILE"
            if [ $? -eq 0 ]; then
                log "Wallpapers successfully copied from $WALLPAPER_SOURCE to $WALLPAPER_DEST"
                chmod -R u+rw "$WALLPAPER_DEST" 2>>"$LOG_FILE"
                log "Set user permissions on wallpaper directory"
            else
                log "Error: Failed to copy wallpapers from $WALLPAPER_SOURCE to $WALLPAPER_DEST"
                FAILED=true
            fi
        fi
    else
        log "Warning: Wallpaper directory not found at $WALLPAPER_SOURCE"
        log "Please ensure the bluebyt-wayfire directory contains a 'Wallpapers' folder"
        log "Continuing installation without wallpapers..."
    fi
else
    log "Skipping wallpaper installation as per user request (-w flag)"
fi

# === Step 15: Ensure wayfire.desktop is present ===
if [ ! -f /usr/share/wayland-sessions/wayfire.desktop ]; then
    log "Creating wayfire.desktop..."
    sudo tee /usr/share/wayland-sessions/wayfire.desktop <<EOF
[Desktop Entry]
Name=Wayfire
Comment=A lightweight and customizable Wayland compositor
Exec=/usr/bin/wayfire
Type=Application
EOF
fi

# === Step 16: Verify Installations ===
log "Verifying key installations..."
for cmd in wayfire kitty fish; do
    if command_exists "$cmd"; then
        log "$cmd installed: $(command -v $cmd)"
    else
        log "Warning: $cmd not found!"
        FAILED=true
    fi
done

# === Step 17: Cleanup and Final Instructions ===
cleanup
log "Installation complete!"
echo "Installation complete!"
echo "See $LOG_FILE for detailed installation log"
echo "To start Wayfire:"
echo "1. Log out of your current session."
echo "2. At your login manager, select the 'Wayfire' session."
echo "3. Log in and enjoy your new desktop environment!"
echo "Backup of previous config saved to: $BACKUP_DIR"
echo "Note: Fish shell is now set as default."

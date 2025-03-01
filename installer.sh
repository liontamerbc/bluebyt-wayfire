#!/bin/bash

# Exit on any error to prevent partial installations
set -e

# === Global Variables ===
SCRIPT_DIR="$(pwd)"
BACKUP_DIR=~/.config_backup_$(date +%F_%T)
FAILED=false

# === Helper Functions ===

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check available disk space (minimum in MB)
check_space() {
    local min_space=$1
    local available_space=$(df -m / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt "$min_space" ]; then
        echo "Error: Insufficient disk space. Required: ${min_space}MB, Available: ${available_space}MB"
        exit 1
    fi
}

# Install packages with pacman
install_pacman() {
    echo "Installing with pacman: $@"
    sudo pacman -S --needed --noconfirm "$@" || { echo "Pacman install failed for $@"; FAILED=true; }
}

# Install packages from AUR with paru
install_aur() {
    echo "Installing with paru: $@"
    paru -S --noconfirm "$@" || { echo "Paru install failed for $@"; FAILED=true; }
}

# Cleanup function for failed installations
cleanup() {
    if [ "$FAILED" = true ]; then
        echo "Installation failed. Cleaning up..."
        cd "$SCRIPT_DIR"
        rm -rf wayfire wf-shell paru Tokyo-Night-GTK-Theme 2>/dev/null
        echo "Cleanup complete. Please check errors and try again."
        exit 1
    fi
}

# Confirmation prompt
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted by user."
        exit 0
    fi
}

# === Welcome Message ===
echo "Welcome to the Wayfire Desktop Environment Installer for Arch Linux!"
echo "This script will set up Wayfire with Kitty, Fish, Starship, and other tools."
confirm "Do you want to proceed with the installation?"

# === Step 1: Pre-flight Checks ===
echo "Checking system requirements..."
check_space 2000  # Require at least 2GB free space

# === Step 2: Update System ===
echo "Updating package lists..."
sudo pacman -Syu --noconfirm || { echo "System update failed."; FAILED=true; cleanup; }

# === Step 3: Install Essential Tools ===
echo "Installing essential build tools..."
install_pacman git gcc ninja rust nimble sudo lxappearance base-devel libxml2

# === Step 4: Install GTK Theme Dependencies ===
echo "Installing GTK theme dependencies..."
install_pacman gtk-engine-murrine gtk-engines sass gnome-themes-extra

# === Step 5: Install Wayland and Core Packages ===
echo "Installing Wayland, core packages, and Kitty terminal..."
install_pacman wayland wlroots xorg-xwayland kitty

# === Step 6: Install Paru (AUR Helper) if not already installed ===
if ! command_exists paru; then
    echo "Installing Paru from AUR..."
    git clone https://aur.archlinux.org/paru.git || { echo "Failed to clone Paru."; FAILED=true; cleanup; }
    cd paru
    makepkg -si --noconfirm || { echo "Paru build failed."; FAILED=true; cleanup; }
    cd ..
    rm -rf paru
else
    echo "Paru is already installed. Version: $(paru --version)"
fi

# === Step 7: Install Wayfire Dependencies ===
echo "Installing Wayfire dependencies..."
install_pacman autoconf boost cmake doctest doxygen freetype2 glib2-devel glm \
    gobject-introspection gtk-layer-shell gtkmm3 libdbusmenu-gtk3 libdrm libevdev \
    libgl libinput libjpeg libnotify libpng libxkbcommon meson nlohmann-json \
    pkg-config pixman wayland-protocols wlroots

# === Step 8: Build and Install Wayfire ===
echo "Building and installing Wayfire..."
git clone https://github.com/WayfireWM/wayfire.git || { echo "Failed to clone Wayfire."; FAILED=true; cleanup; }
cd wayfire
meson build --prefix=/usr --buildtype=release || { echo "Meson setup failed."; FAILED=true; cleanup; }
ninja -C build || { echo "Ninja build failed."; FAILED=true; cleanup; }
sudo ninja -C build install
cd ..
rm -rf wayfire

# === Step 9: Build and Install wf-shell ===
echo "Building and installing wf-shell (Wayfire shell components)..."
git clone https://github.com/WayfireWM/wf-shell.git || { echo "Failed to clone wf-shell."; FAILED=true; cleanup; }
cd wf-shell
meson build --prefix=/usr --buildtype=release
ninja -C build
sudo ninja -C build install
cd ..
rm -rf wf-shell

# === Step 10: Install Desktop Utilities ===
echo "Installing desktop utilities..."
install_pacman polkit-gnome networkmanager
sudo systemctl enable NetworkManager

# === Step 11: Install Themes and Icons ===
echo "Installing TokyoNight-Dark GTK Theme..."
git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git || { echo "Failed to clone theme."; FAILED=true; cleanup; }
cd Tokyo-Night-GTK-Theme/themes
./install.sh -d ~/.local/share/themes -c dark -l --tweaks black
cd ../..
rm -rf Tokyo-Night-GTK-Theme

echo "Installing Tela Circle icon theme from AUR..."
install_aur tela-circle-icon-theme

# Apply theme and icons globally
echo "Applying theme and icons..."
mkdir -p ~/.config/gtk-3.0
echo "[Settings]
gtk-theme-name=TokyoNight-Dark
gtk-icon-theme-name=Tela-circle" > ~/.config/gtk-3.0/settings.ini

# === Step 12: Install System Tools including exa and Fish ===
echo "Installing system tools: exa, Fish, mako, swappy..."
install_pacman exa fish mako swappy

# Set Fish as the default shell with confirmation
confirm "Do you want to set Fish as your default shell?"
echo "Setting Fish as the default shell..."
echo "/usr/bin/fish" | sudo tee -a /etc/shells
chsh -s /usr/bin/fish

# === Step 13: Install Eww and ironbar from AUR ===
echo "Installing Eww and ironbar from AUR..."
install_aur eww ironbar

# === Step 14: Backup and Install Configuration Files and Binaries ===
echo "Backing up existing configuration..."
mkdir -p "$BACKUP_DIR"
cp -r "$HOME/.config" "$BACKUP_DIR/" 2>/dev/null || true
cp -r "$HOME/.bin" "$BACKUP_DIR/" 2>/dev/null || true

echo "Setting up configuration files and binaries from existing bluebyt-wayfire directory..."
if [ -d "bluebyt-wayfire/.config" ]; then
    cp -r "bluebyt-wayfire/.config" "$HOME/"
    echo "Configuration directory moved to $HOME/.config/"
else
    echo "Error: .config directory not found in bluebyt-wayfire. Please ensure the repo is cloned in the current directory."
    FAILED=true
fi

# Handle binaries if bin/ directory exists
if [ -d "bluebyt-wayfire/.bin" ]; then
    cp -r "bluebyt-wayfire/.bin" "$HOME/"
    echo "Binaries directory moved to $HOME/.bin/"
    # Add ~/.bin to PATH in Fish configuration if not already present
    if ! grep -q "$HOME/.bin" "$HOME/.config/fish/config.fish" 2>/dev/null; then
        mkdir -p "$HOME/.config/fish"
        echo 'set -gx PATH $HOME/.bin $PATH' >> "$HOME/.config/fish/config.fish"
        echo "Added $HOME/.bin to PATH in Fish configuration."
    else
        echo "$HOME/.bin already in PATH."
    fi
else
    echo "Error: .bin directory not found in bluebyt-wayfire. Please ensure the repo is cloned in the current directory."
    FAILED=true
fi

# === Step 15: Ensure wayfire.desktop is present ===
if [ ! -f /usr/share/wayland-sessions/wayfire.desktop ]; then
    echo "Creating wayfire.desktop..."
    sudo tee /usr/share/wayland-sessions/wayfire.desktop <<EOF
[Desktop Entry]
Name=Wayfire
Comment=A lightweight and customizable Wayland compositor
Exec=/usr/bin/wayfire
Type=Application
EOF
fi

# === Step 16: Verify Installations ===
echo "Verifying key installations..."
for cmd in wayfire kitty fish starship; do
    if command_exists "$cmd"; then
        echo "$cmd installed: $(command -v $cmd)"
    else
        echo "Warning: $cmd not found!"
        FAILED=true
    fi
done

# === Step 17: Cleanup and Final Instructions ===
cleanup  # Check if any step failed
echo "Installation complete!"
echo "To start Wayfire:"
echo "1. Log out of your current session."
echo "2. At your login manager, select the 'Wayfire' session."
echo "3. Log in and enjoy your new desktop environment!"
echo "Backup of previous config saved to: $BACKUP_DIR"
echo "Note: Fish shell and Starship prompt are now set as default."

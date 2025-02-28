#!/bin/bash

# Exit on any error to prevent partial installations
set -e

# === Helper Functions ===

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install packages with pacman
install_pacman() {
    sudo pacman -S --needed --noconfirm "$@"
}

# Install packages from AUR with paru
install_aur() {
    paru -S --noconfirm "$@"
}

# === Welcome Message ===
echo "Welcome to the Wayfire Desktop Environment Installer for Arch Linux!"
echo "This script will set up Wayfire with Kitty, Fish, Starship, and other tools."

# === Step 1: Update System ===
echo "Updating package lists..."
sudo pacman -Syu --noconfirm

# === Step 2: Install Essential Tools ===
echo "Installing essential build tools..."
install_pacman git gcc ninja rust nimble sudo lxappearance base-devel libxml2

# === Step 3: Install GTK Theme Dependencies ===
echo "Installing GTK theme dependencies..."
install_pacman gtk-engine-murrine gtk-engines sass gnome-themes-extra

# === Step 4: Install Wayland and Core Packages ===
echo "Installing Wayland, core packages, and Kitty terminal..."
install_pacman wayland wlroots xorg-xwayland kitty

# === Step 5: Install Paru (AUR Helper) if not already installed ===
if ! command_exists paru; then
    echo "Installing Paru from AUR..."
    git clone https://aur.archlinux.org/paru.git
    cd paru
    makepkg -si --noconfirm
    cd ..
    rm -rf paru
else
    echo "Paru is already installed."
fi

# === Step 6: Install Wayfire Dependencies ===
echo "Installing Wayfire dependencies..."
install_pacman autoconf boost cmake doctest doxygen freetype2 glib2-devel glm \
    gobject-introspection gtk-layer-shell gtkmm3 libdbusmenu-gtk3 libdrm libevdev \
    libgl libinput libjpeg libnotify libpng libxkbcommon meson nlohmann-json \
    pkg-config pixman wayland-protocols wlroots

# === Step 7: Build and Install Wayfire ===
echo "Building and installing Wayfire..."
git clone https://github.com/WayfireWM/wayfire.git
cd wayfire
meson build --prefix=/usr --buildtype=release || { echo "Meson setup failed. Check dependencies."; exit 1; }
ninja -C build || { echo "Ninja build failed."; exit 1; }
sudo ninja -C build install
cd ..
rm -rf wayfire

# === Step 8: Build and Install wf-shell ===
echo "Building and installing wf-shell (Wayfire shell components)..."
git clone https://github.com/WayfireWM/wf-shell.git
cd wf-shell
meson build --prefix=/usr --buildtype=release
ninja -C build
sudo ninja -C build install
cd ..
rm -rf wf-shell

# === Step 9: Install Desktop Utilities ===
echo "Installing desktop utilities..."
install_pacman polkit-gnome networkmanager
sudo systemctl enable NetworkManager

# === Step 10: Install Themes and Icons ===
echo "Installing TokyoNight-Dark GTK Theme..."
git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git
cd Tokyo-Night-GTK-Theme/themes
./install.sh -d ~/.local/share/themes -c dark -l --tweaks black
cd ../..
rm -rf Tokyo-Night-GTK-Theme

echo "Installing Tela Circle icon theme..."
git clone https://github.com/vinceliuice/Tela-circle-icon-theme.git
cd Tela-circle-icon-theme
./install.sh -a
cd ..
rm -rf Tela-circle-icon-theme

echo "Installing Aretha Dark Icons..."
git clone https://github.com/L4ki/Aretha-Plasma-Themes.git
cd Aretha-Plasma-Themes

if [ -d "Icons" ]; then
    echo "Installing Aretha Dark Icons from local repo..."
    mkdir -p ~/.icons
    cp -r Icons/* ~/.icons/
    echo "Aretha Dark Icons installed to ~/.icons"
else
    echo "Icons directory not found in Aretha-Plasma-Themes. Skipping Aretha Dark Icons installation."
fi

cd ..
rm -rf Aretha-Plasma-Themes

# Apply theme and icons globally
echo "Applying theme and icons..."
mkdir -p ~/.config/gtk-3.0
echo "[Settings]
gtk-theme-name=TokyoNight-Dark
gtk-icon-theme-name=Tela-circle" > ~/.config/gtk-3.0/settings.ini

# === Step 11: Install System Tools including exa and Fish ===
echo "Installing system tools: exa, Fish, mako, swappy..."
install_pacman exa fish mako swappy

# Set Fish as the default shell
echo "Setting Fish as the default shell..."
echo "/usr/bin/fish" | sudo tee -a /etc/shells
chsh -s /usr/bin/fish

# === Step 12: Install Eww and Ironbar from AUR ===
echo "Installing Eww from AUR..."
install_aur eww

echo "Installing Ironbar from AUR..."
install_aur ironbar-git

# === Step 13: Install Starship Prompt ===
echo "Installing Starship prompt..."
curl -sS https://starship.rs/install.sh | sh -s -- -y
mkdir -p ~/.config/fish
echo "starship init fish | source" >> ~/.config/fish/config.fish

# === Step 14: Clone Repository and Move Wallpaper Folder ===
echo "Cloning the bluebyt-wayfire repository..."
git clone https://github.com/liontamerbc/bluebyt-wayfire.git bluebyt-wayfire

if [ -d "bluebyt-wayfire/Wallpaper" ]; then
    echo "Moving Wallpaper folder to ~/Pictures..."
    mkdir -p ~/Pictures
    mv Bluebyt-Wayfire/Wallpaper ~/Pictures/
    echo "Wallpaper folder moved to ~/Pictures/Wallpaper"
else 
    echo "Warning: Wallpaper folder not found in Bluebyt-Wayfire. Skipping wallpaper setup."
fi

# === Step 15: Backup and Install Configuration Files and Binaries === 
echo "Backing up existing configuration..." 
_backup_dir=~/.config_backup_$(date +%F_%T) 
mkdir -p "$_backup_dir" 
cp -r ~/.config/* "$_backup_dir/" 2>/dev/null || true 

if [ -d "bluebyt-wayfire/config" ]; then 
    mkdir -p ~/.config 
    cp -r bluebyt-wayfire/config/* ~/.config/
else 
    echo "Warning: Configuration directory not found in bluebyt-wayfire. Skipping config setup." 
fi 

if [ ! -f /usr/share/wayland-sessions/wayfire.desktop ]; then 
sudo tee /usr/share/wayland-sessions/wayfire.desktop <<EOF 
[Desktop Entry] Name=Wayfire Comment=A lightweight customizable Wayland compositor Exec=/usr/bin/wayfire Type=Application EOF fi 

rm Bluebyt repo.


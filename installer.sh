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

# Prompt user for yes/no input
prompt_yes_no() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer yes (y) or no (n)." ;;
        esac
    done
}

# === Welcome Message ===
echo "Welcome to the Wayfire Desktop Environment Installer for Arch Linux!"
echo "This script will set up Wayfire with a customized desktop experience based on your wayfire-dots fork."

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
echo "Installing Wayland and core packages..."
install_pacman wayland wlroots xorg-xwayland

# Prompt for terminal emulator choice
if prompt_yes_no "Would you like to install a terminal emulator (weston-terminal or alacritty)?"; then
    echo "Which terminal would you like to install?"
    echo "1) weston-terminal"
    echo "2) alacritty"
    read -p "Enter your choice (1 or 2, or press Enter for none): " term_choice
    case $term_choice in
        1) install_pacman weston-terminal ;;
        2) install_pacman alacritty ;;
        *) echo "Skipping terminal emulator installation." ;;
    esac
fi

# === Step 5: Install Paru (AUR Helper) ===
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

# === Step 9: Install Wayfire Plugins ===
if prompt_yes_no "Install wayfire-plugins-extra for additional features?"; then
    echo "Building and installing wayfire-plugins-extra..."
    git clone https://github.com/WayfireWM/wayfire-plugins-extra.git
    cd wayfire-plugins-extra
    meson build --prefix=/usr --buildtype=release
    ninja -C build
    sudo ninja -C build install
    cd ..
    rm -rf wayfire-plugins-extra
fi

# === Step 10: Install Desktop Utilities ===
echo "Installing desktop utilities..."
install_pacman polkit-gnome networkmanager
sudo systemctl enable NetworkManager

# === Step 11: Install wf-recorder ===
if prompt_yes_no "Install wf-recorder for screen recording?"; then
    echo "Building and installing wf-recorder..."
    git clone https://github.com/ammen99/wf-recorder.git
    cd wf-recorder
    meson build --prefix=/usr --buildtype=release
    ninja -C build
    sudo ninja -C build install
    cd ..
    rm -rf wf-recorder
fi

# === Step 12: Install Themes and Icons ===
echo "Installing TokyoNight-Dark GTK Theme..."
git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git
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

# === Step 13: Install Optional Tools ===
if prompt_yes_no "Install optional system tools (fish shell, mako notifications, etc.)?"; then
    echo "Installing optional tools..."
    install_pacman fish mako swappy
    if prompt_yes_no "Set Fish as your default shell?"; then
        echo "/usr/bin/fish" | sudo tee -a /etc/shells
        chsh -s /usr/bin/fish
    fi
fi

# === Step 14: Install Starship Prompt ===
if prompt_yes_no "Install Starship prompt for a customizable shell experience?"; then
    echo "Installing Starship prompt..."
    curl -sS https://starship.rs/install.sh | sh -s -- -y
    mkdir -p ~/.config/fish
    echo "starship init fish | source" >> ~/.config/fish/config.fish
fi

# === Step 15: Backup and Install Configuration Files and Binaries ===
echo "Backing up existing configuration..."
_backup_dir=~/.config_backup_$(date +%F_%T)
mkdir -p "$_backup_dir"
cp -r ~/.config/* "$_backup_dir/" 2>/dev/null || true

echo "Cloning and setting up configuration files and binaries..."
git clone https://github.com/bluebyt/wayfire-dots.git
if [ -d "wayfire-dots/config" ]; then
    mkdir -p ~/.config
    cp -r wayfire-dots/config/* ~/.config/
    echo "Configuration files placed in ~/.config/"
else
    echo "Warning: Configuration directory not found in wayfire-dots. Skipping config setup."
fi

# Handle binaries if bin/ directory exists
if [ -d "wayfire-dots/bin" ]; then
    echo "Setting up binaries in ~/.bin/..."
    mv wayfire-dots/bin wayfire-dots/.bin
    mkdir -p ~/.bin
    cp -r wayfire-dots/.bin/* ~/.bin/
    # Add ~/.bin to PATH in shell configuration
    if [ -f ~/.bashrc ]; then
        echo 'export PATH="$HOME/.bin:$PATH"' >> ~/.bashrc
    elif [ -f ~/.zshrc ]; then
        echo 'export PATH="$HOME/.bin:$PATH"' >> ~/.zshrc
    elif [ -f ~/.config/fish/config.fish ]; then
        echo 'set -gx PATH $HOME/.bin $PATH' >> ~/.config/fish/config.fish
    fi
    echo "Binaries have been placed in ~/.bin/ and added to your PATH."
else
    echo "No bin/ directory found in wayfire-dots. Skipping binary setup."
fi

if [ -f "wayfire-dots/wayfire.desktop" ]; then
    sudo mkdir -p /usr/share/wayland-sessions
    sudo cp wayfire-dots/wayfire.desktop /usr/share/wayland-sessions/
    echo "Wayfire session file installed to /usr/share/wayland-sessions/"
else
    echo "Warning: wayfire.desktop not found. You may need to configure your login manager manually."
fi
rm -rf wayfire-dots

# === Step 16: Final Instructions ===
echo "Installation complete!"
echo "To start Wayfire:"
echo "1. Log out of your current session."
echo "2. At your login manager (e.g., GDM, LightDM), select the 'Wayfire' session."
echo "3. Log in and enjoy your new desktop environment!"
echo "Note: If Wayfire isn't listed, ensure /usr/share/wayland-sessions/wayfire.desktop exists."
echo "If you installed binaries, you may need to restart your shell or source your config file (e.g., 'source ~/.bashrc') to use them."

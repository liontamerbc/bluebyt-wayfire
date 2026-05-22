#!/bin/bash

# Exit on any error
set -e

# Colors
GREEN='\033[1;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. Ensure system is updated
log "Updating system..."
sudo pacman -Syu --noconfirm

# 2. Install basic build tools if missing
sudo pacman -S --needed --noconfirm base-devel git

# 3. Bootstrap AUR helper (paru) if not installed
if ! command -v paru &> /dev/null; then
    log "Installing paru (AUR helper)..."
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/paru
fi

# 4. Install Core Packages
log "Installing dependencies..."
sudo pacman -S --needed --noconfirm wayfire kitty fish wcm git gcc ninja rust sudo lxappearance base-devel curl pciutils meson bc mako swappy ufw

# 5. Install AUR Packages (The "Bluebyt" components)
log "Installing AUR components..."
paru -S --needed --noconfirm ironbar-git eww-wayland-git tokyonight-gtk-theme-git tela-circle-icon-theme-git swayosd-git lite-xl ulauncher grimshot-pv-git ncmpcpp xava

# 6. Apply configurations
log "Applying configurations..."
mkdir -p "$HOME/.config/wayfire"
if [ ! -d "/tmp/bluebyt-wayfire" ]; then
    git clone https://github.com/liontamerbc/bluebyt-wayfire.git /tmp/bluebyt-wayfire
fi
cp -r /tmp/bluebyt-wayfire/.config/* "$HOME/.config/"

# 7. Create Session Entry
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Comment=Wayland Compositor
Exec=wayfire
Type=Application
EOF

log "Installation complete!"
log "Log out and select 'Wayfire' from your login screen."

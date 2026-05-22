#!/bin/bash

# Ensure non-interactive and rootless operation
set -e
export PACMAN_OPTS="--noconfirm --needed"

# Colors
GREEN='\033[1;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 1. Update system
log "Updating system..."
sudo pacman -Syu $PACMAN_OPTS

# 2. Install Core Dependencies
log "Installing dependencies..."
sudo pacman -S $PACMAN_OPTS wayfire kitty fish wcm git gcc ninja rust sudo lxappearance base-devel curl pciutils meson bc mako swappy ufw

# 3. Install AUR Packages (The "Bluebyt" components)
log "Installing AUR components..."
paru -S $PACMAN_OPTS ironbar-git eww-wayland-git tokyonight-gtk-theme-git tela-circle-icon-theme-git swayosd-git lite-xl ulauncher grimshot-pv-git ncmpcpp xava

# 4. Setup Wayfire Configuration
log "Applying configurations..."
mkdir -p "$HOME/.config/wayfire"
# Directly download the configs to avoid copy-paste corruption
git clone https://github.com/liontamerbc/bluebyt-wayfire.git /tmp/bluebyt-temp
cp -r /tmp/bluebyt-temp/.config/* "$HOME/.config/"

# 5. Create Session Entry
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Comment=Wayland Compositor
Exec=wayfire
Type=Application
EOF

# 6. Finalize
log "Installation complete!"
log "1. Log out."
log "2. Select 'Wayfire' at the login screen."
log "3. Enjoy your new desktop."

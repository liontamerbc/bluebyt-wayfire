#!/bin/bash

# Exit on any error
set -e

# Setup colors
RED='\033[0;31m'
GREEN='\033[1;32m'
NC='\033[0m'

echo -e "${GREEN}Starting Installation...${NC}"

# Check for root/sudo
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Please run as a regular user, not root.${NC}"
    exit 1
fi

# 1. Update and Install Core Packages
echo "Installing packages..."
sudo pacman -Syu --noconfirm
# Removed wlogout and xava as they are AUR-only and break scripts
sudo pacman -S --needed --noconfirm wayfire kitty fish wcm git gcc ninja rust sudo lxappearance base-devel curl pciutils meson bc

# 2. Setup Config Directory
mkdir -p "$HOME/.config/wayfire"

# 3. Create Wayfire Config
cat > "$HOME/.config/wayfire/wayfire.ini" << EOF
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
EOF

# 4. Setup Desktop Session
echo "Configuring session..."
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/wayfire.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Wayfire
Comment=Wayland Compositor
Exec=wayfire
Type=Application
EOF

echo -e "${GREEN}Installation finished successfully!${NC}"
echo "Log out and select 'Wayfire' from your login screen."

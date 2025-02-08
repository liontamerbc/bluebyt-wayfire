#!/bin/bash

set -e  # Exit on error

# Install dependencies
sudo pacman -Syu --noconfirm freetype2 glm libdrm libevdev libgl libinput \
    libjpeg libpng libxkbcommon libxml2 pixman wayland-protocols wlroots \
    meson cmake doctest doxygen nlohmann-json libnotify base-devel pkg-config \
    autoconf gobject-introspection gtk-layer-shell scour libdbusmenu-gtk3 gtkmm3 glib2-devel

# Install Wayfire
cd ~
git clone https://github.com/WayfireWM/wf-install
cd wf-install
./install.sh --prefix /opt/wayfire --stream master

# Install Pixdecor
cd ~
git clone https://github.com/soreau/pixdecor.git
cd pixdecor
PKG_CONFIG_PATH=/opt/wayfire/lib/pkgconfig meson setup build --prefix=/opt/wayfire
ninja -C build
ninja -C build install

# Install TokyoNight GTK Theme
cd ~
git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme
cd Tokyo-Night-GTK-Theme
./install.sh -d ~/.local/share/themes -c dark -l --tweaks black

# Install Tela Circle Icon Theme
cd ~
git clone https://github.com/vinceliuice/Tela-circle-icon-theme
cd Tela-circle-icon-theme
./install.sh

# Install SwayOSD
cd ~
git clone https://github.com/ErikReider/SwayOSD
cd SwayOSD
meson setup build
ninja -C build
meson install -C build

# Install additional tools
sudo pacman -S --noconfirm fish starship mako ulauncher swappy xava ironbar lite-xl

# Download and install Caskaydia Cove Nerd Font
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -LO https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/CascadiaCode.zip
unzip CascadiaCode.zip && rm CascadiaCode.zip

# Configure environment for Wayfire
echo "WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket" | sudo tee /etc/environment

# Final message
echo "Installation complete! Reboot your system to apply changes."

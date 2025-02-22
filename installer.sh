#!/bin/bash

# Update package lists
sudo pacman -Syu --noconfirm

### Install essential tools
sudo pacman -S --noconfirm git gcc ninja rust nimble sudo lxappearance

# Install base-devel group (required for makepkg)
sudo pacman -S --noconfirm --needed base-devel

# Install GTK theme dependencies
sudo pacman -S --noconfirm gtk-engine-murrine gtk-engines sass gnome-themes-extra

### Install dependencies
sudo pacman -S --noconfirm wayland wlroots xorg-xwayland weston-terminal alacritty freetype2 glm libdrm libevdev libgl libinput libjpeg libpng libxkbcommon pixman wayland-protocols meson cmake doctest doxygen nlohmann-json libnotify pkg-config autoconf gobject-introspection gtk-layer-shell scour libdbusmenu-gtk3 gtkmm3 glib2-devel boost

## Install Paru from AUR
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si --noconfirm
cd

## Install Wayfire
git clone https://github.com/WayfireWM/wayfire.git
cd wayfire
meson build --prefix=/usr --buildtype=release
sudo ninja -C build
sudo ninja -C build install
cd

# Wayfire extra steps
mkdir -p ~/.config/wayfire
cp wayfire.ini ~/.config/wayfire/
echo "[Desktop Entry]
Name=Wayfire
Exec=Wayfire
Type=Application" | sudo tee /usr/share/wayland-sessions/wayfire.desktop
cd

## Install wf-shell
git clone https://github.com/WayfireWM/wf-shell.git
cd wf-shell
meson build --prefix=/usr --buildtype=release
ninja -C build
sudo ninja -C build install
cd

## Install Pixdecor
git clone https://github.com/soreau/pixdecor.git
cd pixdecor
PKG_CONFIG_PATH=/opt/wayfire/lib/pkgconfig meson setup build --prefix=/opt/wayfire
ninja -C build
ninja -C build install
cd

# Install Ironbar
paru -S --noconfirm ironbar

# Install Eww
git clone https://github.com/elkowar/eww.git
cd eww
cargo build --release --no-default-features --features=wayland
cd

# Install additional Pacman packages
sudo pacman -S --noconfirm mako fish lite-xl swappy thunar

# Install TokyoNight-Dark GTK Theme
git clone https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme.git
cd Tokyo-Night-GTK-Theme
./install.sh -d ~/.local/share/themes -c dark -l --tweaks black
sudo mv ~/.local/share/themes/Tokyo-Night-GTK-Theme ~/.themes
cd

# Install Tela Circle Icons (or Aretha-Dark-Icons)
paru -S tela-circle-icon-theme --noconfirm

# Install other AUR packages
paru -S swayosd grimshot xava-git ncmpcpp mpd-git wcm wezterm blueman thunar nwg-look vesktop ristretto zed clapper --noconfirm

## Install Fish Shell
echo "/usr/bin/fish" | sudo tee -a /etc/shells
chsh -s /usr/bin/fish

## Starship Prompt
sudo mkdir -p Starship
cd Starship
curl -sS https://starship.rs/install.sh | sh
echo "starship init fish | source" >> ~/.config/fish/config.fish
cd

## Install Catnap
git clone https://github.com/iinsertNameHere/catnap.git
cd catnap
nimble install catnip
cd

## Install Ulauncher
git clone https://aur.archlinux.org/ulauncher.git
cd ulauncher
makepkg -is --noconfirm
cd

## Install Nerd Font
sudo pacman -S --noconfirm $(pacman -Sgq nerd-fonts)

# Backup your config
cp -r ~/.config ~/.config_backup

# Clone Bluebyt's dots
git clone http://github.com/bluebyt/wayfire-dots


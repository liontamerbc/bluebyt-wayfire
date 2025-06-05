# Bluebyt Wayfire Desktop Dots

**Wayfire-dots** is a collection of configuration files, scripts, and themes tailored for the [Wayfire](https://github.com/WayfireWM/wayfire) 3D Wayland compositor, designed for an elegant and productive desktop experience on Arch Linux.

---

## About

- **Installer Included:** This project provides a robust, user-friendly installer script for Arch Linux, automating the setup of Wayfire, essential utilities, and all configuration files.
- **Universal Config Paths:** All configuration paths in `wf-shell.ini` and `wayfire.ini` use environment-agnostic placeholders for seamless out-of-the-box use.
- **Automatic Wallpaper & Config Setup:** Wallpapers are copied to `/usr/share/Wallpaper`, and configuration/bin directories are properly dot-prefixed to match Linux conventions.
- **Reference:** For more information, see the [Wayfire wiki](https://github.com/WayfireWM/wayfire/wiki).

---

## Screenshots

**Wayfire with Pixdecor**
![Screenshot: Wayfire with Pixdecor](https://github.com/user-attachments/assets/6ce465da-e8a9-45d5-a87c-8932cd7ae366)

**GTK4 Apps, Aretha-Dark-Icons, and Pixdecor**
![Screenshot: GTK4, Pixdecor](https://github.com/user-attachments/assets/58606e37-6f79-4ad9-b1cf-20cef66b1213)

[▶️ Install Wayfire on Youtube](https://youtu.be/abtU54uMXH0)

---

## Included Components

- [Wayfire](https://github.com/WayfireWM/wayfire) – 3D Wayland compositor
- [Pixdecor](https://github.com/soreau/pixdecor) – Wayfire decorator with antialiased corners and animations
- [Ironbar](https://github.com/JakeStanger/ironbar) – Powerful GTK bar for wlroots compositors
- [eww](https://github.com/elkowar/eww) – Widget framework (left panel)
- [Mako](https://github.com/emersion/mako) – Notification daemon
- [Tokyonight-Dark](https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme) – GTK theme
- [Tela-circle-icon-theme](https://github.com/vinceliuice/Tela-circle-icon-theme) or [Aretha-Dark-Icons](https://www.gnome-look.org/p/2180417)
- [Fish shell](https://github.com/fish-shell/fish-shell) – Command line shell
- [Starship prompt](https://starship.rs/) – Customizable prompt
- [Catnip](https://github.com/iinsertNameHere/catnip) – System fetch tool
- [SwayOSD](https://github.com/ErikReider/SwayOSD) – On-screen display for common actions
- [Lite XL](https://lite-xl.com/) – Lightweight extensible text editor
- [Ulauncher](https://ulauncher.io/) – Application launcher
- [Grimshot-pv](https://github.com/ferdiebergado/grimshot-pv) – Screenshot preview script
- [Xava](https://github.com/nikp123/xava) – Audio visualizer
- [ncmpcpp](https://github.com/ncmpcpp/ncmpcpp) – Terminal music player
- [Swappy](https://github.com/jtheoof/swappy) – Wayland snapshot & editor tool
- **Font:** Caskaydiacove Nerd Font

---

## Prerequisites

- Arch Linux installed (minimal or with your preferred desktop environment).
- [Install Arch Linux (video)](https://www.youtube.com/watch?v=8nlo7LewC5Q)

---

## Quick Install (Recommended)

```sh
git clone https://github.com/liontamerbc/bluebyt-wayfire.git
cd bluebyt-wayfire
./installer.sh
```

- The installer will prompt for options and automate all steps, including configs, themes, and wallpapers.

---

## Manual Installation (Alternative)

### 1. Install Dependencies

```sh
sudo pacman -S freetype2 glm libdrm libevdev libgl libinput libjpeg libpng libxkbcommon libxml2 pixman wayland-protocols wlroots meson cmake doctest doxygen nlohmann-json libnotify base-devel pkg-config autoconf gobject-introspection gtk-layer-shell scour libdbusmenu-gtk3 gtkmm3 glib2-devel boost
```

### 2. Build and Install Wayfire

```sh
git clone https://github.com/WayfireWM/wf-install
cd wf-install
./install.sh --prefix /opt/wayfire --stream master
```

### 3. Install Pixdecor

```sh
git clone https://github.com/soreau/pixdecor.git
cd pixdecor
PKG_CONFIG_PATH=/opt/wayfire/lib/pkgconfig meson setup build --prefix=/opt/wayfire
ninja -C build
ninja -C build install
```

---

## Configuration

- Edit your configs at `$HOME/.config/wayfire.ini` and `$HOME/.config/wf-shell.ini` as needed.
- The installer will back up existing configs.

---

## Running Wayfire

1. Log out of your current session.
2. At your login manager (e.g., GDM), select the "Wayfire" session.
3. Log in to start your new desktop environment.

---

## Follow Focus and Inactive Alpha

1. Create the environment config file:
    ```sh
    echo 'WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket' > ~/.config/environment.d/environment.conf
    ```
2. Download or copy the scripts [inactive-alpha.py](https://github.com/WayfireWM/wayfire/raw/master/examples/inactive-alpha.py) and [wayfire_socket.py](https://github.com/WayfireWM/wayfire/raw/master/examples/wayfire_socket.py) to `~/.config/ipc-scripts/`.
3. Edit your `$HOME/.config/wayfire.ini` and add:
    ```
    plugins = ipc ipc-rules follow-focus
    [autostart]
    launcher = ~/.config/ipc-scripts/inactive-alpha.py
    ```
4. Make sure both scripts are executable:
    ```sh
    chmod +x ~/.config/ipc-scripts/inactive-alpha.py ~/.config/ipc-scripts/wayfire_socket.py
    ```

---

## Credits & Resources

- [Bluebyt (Bruno) – Workflow video](https://youtu.be/5dzgKCZbSlA)
- See the [Wayfire wiki](https://github.com/WayfireWM/wayfire/wiki) for more documentation.

---

Enjoy your new Wayfire desktop!

# Bluebyt Wayfire Desktop Dots

**Wayfire-dots** is a complete, elegant, and highly customizable desktop setup for the [Wayfire](https://github.com/WayfireWM/wayfire) 3D Wayland compositor. This project delivers a beautiful workflow, curated themes, and a suite of tools for power users and Linux enthusiasts.

---

## ✨ Features

- **One-Click Installer:** Automates setup on Arch Linux, including dependencies, utilities, and all configurations.
- **Universal Config Paths:** Uses environment-agnostic placeholders in config files for seamless portability.
- **Automatic Wallpapers & Dotfiles:** Installs wallpapers and dotfiles to proper system locations.
- **Curated Experience:** Every detail, from themes to scripts, is chosen for performance and beauty.
- **Actively Maintained:** Regularly updated with new features and improvements.

---

## 📸 Screenshots

**Wayfire with Pixdecor**

![Wayfire with Pixdecor](https://github.com/user-attachments/assets/6ce465da-e8a9-45d5-a87c-8932cd7ae366)

**GTK4 Apps, Aretha-Dark-Icons, and Pixdecor**

![GTK4, Pixdecor](https://github.com/user-attachments/assets/58606e37-6f79-4ad9-b1cf-20cef66b1213)

[▶️ Install Wayfire on Youtube](https://youtu.be/abtU54uMXH0)

---

## 🧩 Included Components

- [Wayfire](https://github.com/WayfireWM/wayfire) – 3D Wayland compositor
- [Pixdecor](https://github.com/soreau/pixdecor) – Antialiased window decorations
- [Ironbar](https://github.com/JakeStanger/ironbar) – Powerful GTK status bar
- [eww](https://github.com/elkowar/eww) – Interactive widgets (left panel)
- [Mako](https://github.com/emersion/mako) – Notification daemon
- [Tokyonight-Dark](https://github.com/Fausto-Korpsvart/Tokyo-Night-GTK-Theme) – GTK theme
- [Tela-circle-icon-theme](https://github.com/vinceliuice/Tela-circle-icon-theme) or [Aretha-Dark-Icons](https://www.gnome-look.org/p/2180417)
- [Fish shell](https://github.com/fish-shell/fish-shell) & [Starship](https://starship.rs/) prompt
- [Catnip](https://github.com/iinsertNameHere/catnip) – System fetch tool
- [SwayOSD](https://github.com/ErikReider/SwayOSD) – On-screen display
- [Lite XL](https://lite-xl.com/) – Lightweight extensible text editor
- [Ulauncher](https://ulauncher.io/) – Application launcher
- [Grimshot-pv](https://github.com/ferdiebergado/grimshot-pv) – Screenshot preview
- [Xava](https://github.com/nikp123/xava) – Audio visualizer
- [ncmpcpp](https://github.com/ncmpcpp/ncmpcpp) – Terminal music player
- [Swappy](https://github.com/jtheoof/swappy) – Wayland snapshot & editor
- **Font:** Caskaydiacove Nerd Font

---

## 🖥️ Prerequisites

- Arch Linux installed (minimal or with your preferred desktop environment).
- [Install Arch Linux (video)](https://www.youtube.com/watch?v=8nlo7LewC5Q)

---

## 🚀 Quick Start

**Recommended: Automated Installer**

```sh
git clone https://github.com/liontamerbc/bluebyt-wayfire.git
cd bluebyt-wayfire
./installer.sh
```

The installer guides you through all steps, including configs, themes, and wallpapers.

---

## 📝 Manual Installation

### 1. Install Dependencies

```sh
sudo pacman -S freetype2 glm libdrm libevdev libgl libinput libjpeg libpng libxkbcommon libxml2 pixman wayland-protocols wlroots meson cmake doctest doxygen nlohmann-json libnotify base-devel pkg-config
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

## ⚙️ Configuration

- Configs are stored in `$HOME/.config/wayfire.ini` and `$HOME/.config/wf-shell.ini`.
- The installer will back up your existing configs.

---

## ▶️ Usage

1. Log out of your current session.
2. At your login manager (e.g., GDM), select the "Wayfire" session.
3. Log in and enjoy your new desktop environment!

---

## 🎨 Advanced: Follow Focus & Inactive Alpha

1. Create the environment config file:
    ```sh
    echo 'WAYFIRE_SOCKET=/tmp/wayfire-wayland-1.socket' > ~/.config/environment.d/environment.conf
    ```
2. Download [inactive-alpha.py](https://github.com/WayfireWM/wayfire/raw/master/examples/inactive-alpha.py) and [wayfire_socket.py](https://github.com/WayfireWM/wayfire/raw/master/examples/wayfire_socket.py) to `~/.config/ipc-scripts`.
3. Edit your `$HOME/.config/wayfire.ini`:

    ```
    plugins = ipc ipc-rules follow-focus
    [autostart]
    launcher = ~/.config/ipc-scripts/inactive-alpha.py
    ```

4. Make scripts executable:
    ```sh
    chmod +x ~/.config/ipc-scripts/inactive-alpha.py ~/.config/ipc-scripts/wayfire_socket.py
    ```

---

## 🙏 Credits & Resources

- [Bluebyt (Bruno) – Workflow video](https://youtu.be/5dzgKCZbSlA)
- [`@bluebyt/Wayfire-dots.git`](https://github.com/bluebyt/Wayfire-dots.git)
- [Wayfire wiki](https://github.com/WayfireWM/wayfire/wiki) for more documentation and troubleshooting.

---

## 💬 Support & Feedback

- Open an issue or pull request on this repository for bugs, feature requests, or improvements.
- Contributions are welcome!

---

## 🔗 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

Enjoy your new Wayfire desktop!

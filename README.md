# Bluebyt Wayfire Desktop Dots

**Wayfire-dots** is a complete, elegant, and highly customizable desktop setup for the [Wayfire](https://github.com/WayfireWM/wayfire) 3D Wayland compositor. This project delivers a beautiful workflow, curated themes, and a suite of tools for power users and Linux enthusiasts.

---

## ✨ Features

- **One-Click Installer:** Automates setup on Arch Linux, including all dependencies, drivers (CPU, GPU, Wi-Fi, Bluetooth), utilities, and configurations.
- **Optional GNOME Fallback:** The installer gives you the option to automatically install the GNOME desktop (with `-g` or `--gnome`) as a robust fallback and troubleshooting environment.
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

---

## 🚀 Quick Start

**Recommended: Automated Installer**

```sh
git clone https://github.com/liontamerbc/bluebyt-wayfire.git
cd bluebyt-wayfire
./installer.sh
```

### GNOME Desktop Option

You can install GNOME as a fallback desktop by passing the `-g` or `--gnome` option:

```sh
./installer.sh -g        # or
./installer.sh --gnome
```

This is **highly recommended for new setups** or if you want a reliable troubleshooting environment.

---

## 📝 Manual Installation

Although the installer automates most hardware detection and driver installation, here is a summary of what it does for reference:

### 1. Install Dependencies

Including build tools, libraries, and core packages for Wayfire and all included utilities.

### 2. Build and Install Wayfire, wf-shell, wcm, and Pixdecor

Clones and builds from source:
- [Wayfire](https://github.com/WayfireWM/wayfire)
- [wf-shell](https://github.com/WayfireWM/wf-shell)
- [wcm](https://github.com/WayfireWM/wcm)
- [Pixdecor](https://github.com/soreau/pixdecor)

### 3. Install GPU, CPU, Wi-Fi, and Bluetooth Drivers

- Detects Intel/AMD CPUs and installs microcode.
- Detects NVIDIA, AMD, or Intel GPUs and installs the appropriate drivers.
- Detects common Broadcom/Realtek Wi-Fi chipsets and guides AUR driver installation if needed.
- Installs `networkmanager`, `wireless_tools`, and `linux-firmware`.
- Installs `bluez` and `bluez-utils`, and enables Bluetooth.

### 4. Theme, Icons, and Configurations

- Installs your chosen GTK theme and icon set.
- Applies theme and icons via config.
- Copies all config files, scripts, and dotfiles to your home directory.

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

## 💡 Why install GNOME as a fallback?

Wayfire is a powerful compositor, but a minimal system may leave you without a graphical fallback if something goes wrong.  
**The installer allows you to automatically install GNOME (`-g` or `--gnome`) as a stable, full-featured desktop for troubleshooting and recovery.**

**Benefits:**
- Reliable fallback: Always be able to log into a working desktop if Wayfire fails.
- Graphical tools for system/network/bluetooth/display.
- Improved hardware support (drivers, firmware).
- Safe for experimentation: you can always return to GNOME if you break your Wayfire config.

---

## 🎨 Advanced: Follow Focus & Inactive Alpha

These features are now fully automated by the installer:

- Sets up the required environment variable.
- Downloads and configures `inactive-alpha.py` and `wayfire_socket.py`.
- Updates your `wayfire.ini` with the correct plugins and autostart entries.
- Makes all scripts executable.

No manual action required.

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

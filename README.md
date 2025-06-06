# Bluebyt Wayfire Desktop Dots

**Wayfire-dots** is a complete, elegant, and highly customizable desktop setup for the [Wayfire](https://github.com/WayfireWM/wayfire) 3D Wayland compositor. This project delivers a beautiful workflow, curated themes, and a suite of tools for power users and Linux enthusiasts.

---

## ✨ Features

- **One-Click Installer:** Automates setup on Arch Linux, including all dependencies, drivers, utilities, and configurations.
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

---

## 📝 Manual Installation

Here's a summary of what the installer does:

1. Installs dependencies and core packages
2. Builds Wayfire and essential components from source
3. Installs GPU, CPU, Wi-Fi, and Bluetooth drivers
4. Sets up themes, icons, and configurations

For detailed installation steps, see the [Wayfire wiki](https://github.com/WayfireWM/wayfire/wiki).

---

## ⚙️ Configuration

- Configs are stored in `$HOME/.config/wayfire.ini` and `$HOME/.config/wf-shell.ini`.
- The installer will back up your existing configs.

## 🔧 System-Specific Changes

The configuration files may need adjustments based on your specific system setup. Here are the key files that might require modifications:

1. **`wayfire.ini`**
   - Display configuration (resolution, refresh rate)
   - GPU-specific settings
   - Input device settings
   - Performance optimizations

2. **`wf-shell.ini`**
   - Workspace layout
   - Window management rules
   - Input device bindings
   - Theme and appearance settings

The installer automatically handles hardware-specific configurations, including:
- GPU driver installation
- Wi-Fi driver installation
- Bluetooth setup
- System-specific dependencies

These files are automatically backed up by the installer, so you can safely experiment with changes. If you need to revert to default settings, simply restore from the backup.

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

The installer automatically configures these features, including:
- Environment variable setup
- Required script installation
- Plugin configuration
- Script permissions

No manual action required.

---

## 🙏 Credits & Resources

- [Bluebyt (Bruno) – Workflow video](https://youtu.be/5dzgKCZbSlA)
- [Wayfire wiki](https://github.com/WayfireWM/wayfire/wiki) for more documentation and troubleshooting.
- [`@bluebyt/Wayfire-dots.git`](https://github.com/bluebyt/Wayfire-dots.git)

---

## 💬 Support & Feedback

- Open an issue or pull request on this repository for bugs, feature requests, or improvements.
- Contributions are welcome!

---

## 🔗 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

Enjoy your new Wayfire desktop!

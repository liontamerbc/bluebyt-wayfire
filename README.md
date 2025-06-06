# Bluebyt Wayfire Desktop Dots

**Wayfire-dots** is a complete, elegant, and highly customizable desktop setup for the [Wayfire](https://github.com/WayfireWM/wayfire) 3D Wayland compositor. This project delivers a beautiful workflow, curated themes, and a suite of tools for power users and Linux enthusiasts.

---

## ✨ Features

- **One-Click Installer:** Automates setup on Arch Linux, including all dependencies, drivers, utilities, and configurations.
- **Universal Config Paths:** Uses environment-agnostic placeholders for seamless portability.
- **Curated Experience:** Every detail, from themes to scripts, is chosen for performance and beauty.
- **Actively Maintained:** Regular updates with new features and improvements.

---

## 🚀 Quick Start

```sh
git clone https://github.com/liontamerbc/bluebyt-wayfire.git
cd bluebyt-wayfire
./installer.sh
```

The installer will ask if you want to install GNOME as a fallback desktop during the installation process.

---

## ▶️ Usage

1. Log out of your current session.
2. At your login manager (e.g., GDM), select the "Wayfire" session.
3. Log in and enjoy your new desktop environment!

---

## 💡 Why install GNOME as a fallback?

Wayfire is a powerful compositor, but a minimal system may leave you without a graphical fallback if something goes wrong. The installer will ask if you want to install GNOME as a stable, full-featured desktop for troubleshooting and recovery. You can also use the `-g` or `--gnome` flag to automatically enable GNOME installation:

```sh
./installer.sh -g        # Short flag
./installer.sh --gnome   # Long flag
```

**Benefits:**
- Reliable fallback: Always be able to log into a working desktop if Wayfire fails.
- Graphical tools for system/network/bluetooth/display.
- Improved hardware support (drivers, firmware).
- Safe for experimentation: you can always return to GNOME if you break your Wayfire config.

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

## 📸 Screenshots

**Wayfire with Pixdecor**

![Wayfire with Pixdecor](https://github.com/user-attachments/assets/6ce465da-e8a9-45d5-a87c-8932cd7ae366)

**GTK4 Apps, Aretha-Dark-Icons, and Pixdecor**

![GTK4, Pixdecor](https://github.com/user-attachments/assets/58606e37-6f79-4ad9-b1cf-20cef66b1213)

[▶️ Install Wayfire on Youtube](https://youtu.be/abtU54uMXH0)

---

## ⚙️ Configuration

The installer will back up your existing configs and store them in:
- `$HOME/.config/wayfire.ini`
- `$HOME/.config/wf-shell.ini`

These files may need adjustments based on your system setup:

1. **`wayfire.ini`**
   - Display configuration
   - GPU settings
   - Input devices
   - Performance

2. **`wf-shell.ini`**
   - Workspace layout
   - Window management
   - Input bindings
   - Theme settings

The installer automatically handles hardware-specific configurations, including:
- GPU drivers
- Wi-Fi
- Bluetooth
- System dependencies

These files are automatically backed up by the installer, so you can safely experiment with changes. If you need to revert to default settings, simply restore from the backup.

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
- [Wayfire wiki](https://github.com/WayfireWM/wayfire/wiki) for documentation and troubleshooting
- Original [Wayfire-dots](https://github.com/bluebyt/Wayfire-dots.git)

---

## 💬 Support & Feedback

- Open an issue or pull request on this repository for bugs, feature requests, or improvements.
- Contributions are welcome!

---

## 🔗 License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

Enjoy your new Wayfire desktop!

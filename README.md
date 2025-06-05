# bluebyt-wayfire Desktop Installer for Arch Linux

A robust, user-friendly, and auditable installer for the bluebyt-wayfire desktop environment on **Arch Linux** and derivatives.  
This script supports both interactive and automated installations, with optional GNOME fallback and comprehensive hardware/configuration handling.

---

## Features

- 🖥️ **Wayfire, wf-shell, wcm, and pixdecor** – Built from latest sources
- 🎨 **TokyoNight-Dark GTK theme** and **Aretha-Dark-Icons**
- 🗂 **Config and dotfiles** management
- 🦾 **Optional GNOME desktop install** for fallback/troubleshooting
- 🛠️ **Automatic driver and firmware install** (Intel, AMD, NVIDIA, Realtek, Broadcom, Bluetooth, etc.)
- 🌐 **NetworkManager**, **bluetooth**, and other desktop utilities
- 🐟 **Fish shell** (optionally set as default), **starship** prompt integration
- 🖼️ **Wallpaper** support
- ⚙️ **AUR helper (paru)** bootstrapping, AUR packages (optional)
- 📝 **Dry-run mode** and **non-interactive mode** (`--yes`)
- 🛡 **Automatic backup** of previous configs
- 🧹 **Cleanup on failure**
- ✅ **Final verification and helpful summary**

---

## Usage

```sh
./installer.sh [options]
```

### Options

| Option            | Description                                                         |
|-------------------|---------------------------------------------------------------------|
| `-t THEME`        | Set GTK theme (default: TokyoNight-Dark)                            |
| `-p`              | Partial install, skip optional AUR packages                         |
| `-w`              | Skip wallpaper installation                                         |
| `-n`              | Dry-run: show actions, do not change system                         |
| `-g`, `--gnome`   | **Install GNOME desktop before Wayfire**                            |
| `-y`, `--yes`     | Answer yes to all prompts (non-interactive, for automation/scripts) |
| `-h`              | Show help message                                                   |

---

## Example

**Just Wayfire (default theme):**
```sh
./installer.sh
```

**With GNOME fallback:**
```sh
./installer.sh -g
# or
./installer.sh --gnome
```

**Non-interactive full install with custom theme:**
```sh
./installer.sh -g -y -t Adwaita-dark
```

**Dry-run preview:**
```sh
./installer.sh -n
```

---

## Why Install GNOME First?

Installing GNOME before Wayfire is **strongly recommended** for most users, especially on a fresh Arch Linux setup, for several reasons:

1. **Reliable Fallback:** GNOME provides a stable desktop for troubleshooting if Wayfire fails to start or you encounter hardware/configuration issues.
2. **Easier Troubleshooting:** GNOME includes graphical tools for managing network, bluetooth, drivers, display settings, etc.
3. **Automatic Hardware Support:** GNOME brings in a wide array of drivers, firmware, and utilities for better hardware compatibility.
4. **Smooth User Experience:** GNOME sets up user accounts, permissions, and session management, reducing headaches.
5. **Safe Experimentation:** With GNOME as a backup, you can freely experiment with Wayfire knowing you can always log into a working desktop.

---

## Requirements

- Arch Linux or derivative (Manjaro, EndeavourOS, etc.)
- Internet connection
- `sudo` privileges
- ~2GB available disk space

---

## Notes

- **Aretha-Dark-Icons:** Download `Aretha-Dark-Icons.tar.gz` from [gnome-look.org](https://www.gnome-look.org/p/2180417) and place it in the same directory as the script before running.
- **Wallpaper:** Place wallpapers in a `Wallpaper` subdirectory next to the script, if desired.
- **Custom dotfiles:** Place your `.config` and `.bin` in the script directory for copying, or edit the script for alternate sources.

---

## FAQ

**Q: Does this set screen resolution automatically?**  
A: No, Wayfire will auto-detect most displays, but you may need to use `wcm` (Wayfire Config Manager) to set resolution and scaling.

**Q: Do I need to install GNOME?**  
A: Not required, but highly recommended for troubleshooting and fallback, especially on fresh installs.

**Q: What does dry-run do?**  
A: It prints all actions the script would take, but makes no changes—great for previewing.

**Q: Is this script idempotent?**  
A: It backs up existing configs and removes build directories as needed, but always review and understand changes for your system.

---

## Troubleshooting

- If you experience issues, review the log file (e.g., `install_wayfire_2025-06-05_15:23:30.log`).
- For driver/firmware issues, refer to the script’s output and Arch Wiki.
- If you end up with a black screen after login, use GNOME or a TTY to fix configs.

---

## License

MIT (see `LICENSE` file)

---

**Enjoy your bluebyt-wayfire experience!**
